#!/usr/bin/perl
# My Perl "system" homebrew replacement functions

# TODO:
# - add POD-style documentation
# - write some test suite

package Sh;

require Exporter;
@ISA=qw(Exporter);
@EXPORT=qw(sh *sh_err 
           *sh_ev *sh_failed *sh_sig
           *sh_core *sh_errno *sh_cmd
           esh *sh_stderr *sh_stdout
           read_headers zip
           unshellwords
           shellwords sQ
           *verbose);

use warnings;
use strict;

use File::Temp;

our $verbose=1;
our $no_act=0;

# return values
our ($sh_err, $sh_cmd);
our ($sh_ev, $sh_failed, $sh_sig, $sh_core, $sh_errno);

sub unshellwords;

# 'system' replacement. When evaluated in void context, takes care of
# dying on error, etc. When evaluated in array or scalar context,
# returns zero on any failure condition; these can be distinguished
# with $sh_ev, $sh_failed, $sh_sig. So, if you want to just get the
# exit status, be sure to observe the return value so that we aren't
# executing in void context ($_=sh... for instance), then check that
# $sh_failed and $sh_sig are both zero; then the exit status will be
# in $sh_ev.
sub sh {
  local $1;
  my (@args) = @_;
  my $cmd;

  if (@args>1) {
#    $cmd = join(" ", map {sh_quote $_} @args);
    $cmd = unshellwords @args;
  } else {
    $cmd = $args[0];
  }
  # 15 Mar 2016: I guess we do this because embedded newlines are
  # not recognized in double quotes in shell
  my $secret = "58ihaipX1";
  $cmd =~ s/\\\\/$secret/g;
  $cmd =~ s/\\\n/'\n'/g;
  $cmd =~ s/$secret/\\\\/g;
  return if !$cmd;
  warn "$cmd\n" if $verbose;
  $sh_cmd = $cmd;
  unless($no_act) {
    do {
      local $SIG{__WARN__}=sub{};
      system($cmd);
    };

    ($sh_ev, $sh_failed, $sh_sig, $sh_core, $sh_errno) =
        ($?>>8, $?==-1, $? & 127, !!($? & 128), $!);
    
    if ($sh_failed) {
      $sh_err = "Failed to execute: $sh_errno";
    } elsif ($sh_sig) {
      $sh_err = "Died with signal $sh_sig".($sh_core?", dumped core":"");
    } elsif ($sh_ev) {
      $sh_err = "Exit value $sh_ev";
    } else {
      $sh_err = undef;
    }

    return !($sh_ev || $sh_failed || $sh_sig) if(defined(wantarray));
    
    # void context, take care of the error ourselves:
    die "$sh_err: $cmd\n" if defined($sh_err);
  }
}

# run a shell command, store its stdout and stderr in variables
our ($sh_stderr, $sh_stdout);
sub esh ($) {
  my $cmd = shift;
  my $efh = new File::Temp(UNLINK=>1); # removed by destructor
  my $efname = $efh->filename;
  my $ofh = new File::Temp(UNLINK=>1);
  my $ofname = $ofh->filename;
  $sh_stderr = undef;
  $sh_stdout = undef;
  $_=sh "$cmd 2>\Q$efname\E >\Q$ofname\E";
  open IN, '<', $ofname;
  $sh_stdout = join("",<IN>);
  close IN;
  open EIN, '<', $efname;
  $sh_stderr = join("",<EIN>);
  close EIN;
  return $_ if(defined(wantarray));
  die "$sh_stderr" if !$_;
}


# my %esc_codes = (
#     'n' => "\n",
#     't' => "\t",
#     'r' => "\r"
#   );

# my %esc_rev = (
#     "\n" => 'n',
#     "\t" => 't',
#     "\r" => 'r',
#     "\\" => '\\'
#   );

# sub unescape {
#   my ($v)=@_;
#   $v =~ s/(?<!\\)(\\(.))/$esc_codes{$2} || $2/gex;
#   return $v;
# }

# sub escape {
#   my ($v)=@_;
#   my $old = $v;
#   $v =~ s/([\n\r\t\\])/"\\".$esc_rev{$1}/gex;
#   $old eq (unescape $v) or die "internal error";
#   return $v;
# }

sub shell_quotemeta ($$$) {
  my ($quote, $esc_chars, $str) = @_;
  my (@c) = split('', $str);
  my (@res);
  for my $c (@c) {
    if($c !~ /$esc_chars/) {
      push @res, $c;
    } elsif($c eq "\n") {
      push @res, $quote."\$'\\n'".$quote;
    } elsif($c eq "\t") {
      push @res, $quote."\$'\\t'".$quote;
    } elsif($c eq "'" && $quote eq "'") {
      push @res, "'\\''";
    } else {
      push @res, "\\$c";
    }
  }
  return $quote.join("",@res).$quote;
}

# routine to shell quote, arguments: delimiter (",',none) for tab or
# newline, regex for characters needing escape, string

my $sq_plain = qr/[\$\(\)^#&*{}<>~"'\\|;?\[\] \n\t]/;
my $sq_single = qr/['\\\t]/;
my $sq_double = qr/[\$"\\\t]/;

# shell-quote words and join them with spaces; should be opposite of
# 'shellwords' from Text::ParseWords
sub unshellwords {
  my (@w) = @_;
  my (@l) = ();
  for my $w (@w) {
    my $n;
    if ($w =~ /^$/) {
      $n = "''";
    } else {
      if ($w !~ /$sq_plain/) {
        $n = $w;
      } elsif ($w !~ /$sq_single/) {
        $n = shell_quotemeta ("'", $sq_single, $w);
      } else {
        $n = shell_quotemeta ('"', $sq_double, $w);
      }
    }
    push @l, $n;
  }
  return join(" ", @l);
}

# Alias ("shell quote")
sub sQ { return unshellwords @_; }

#----------------------------------------------------------------
# shellwords, copied from Text::ParseWords

sub shellwords {
  my (@lines) = @_;
  my @allwords;

  foreach my $line (@lines) {
    $line =~ s/^\s+//;
    my @words = parse_line('\s+', 0, $line);
    pop @words if (@words and !defined $words[-1]);
    return() unless (@words || !length($line));
    push(@allwords, @words);
  }
  return(@allwords);
}

sub parse_line {
  my($delimiter, $keep, $line) = @_;
  my($word, @pieces);

  no warnings 'uninitialized';  # we will be testing undef strings

  while (length($line)) {
    # This pattern is optimised to be stack conservative on older perls.
    # Do not refactor without being careful and testing it on very long strings.
    # See Perl bug #42980 for an example of a stack busting input.
    $line =~ s/^
                    (?: 
                        # double quoted string
                        (")                             # $quote
                        ((?>[^\\"]*(?:\\.[^\\"]*)*))"   # $quoted 
                    |   # --OR--
                        # singe quoted string
                        (')                             # $quote
                        ((?>[^\\']*(?:\\.[^\\']*)*))'   # $quoted
                    |   # --OR--
                        # unquoted string
                        (                               # $unquoted 
                            (?:\\.|[^\\"'])*?           
                        )               
                        # followed by
                        (                               # $delim
                            \Z(?!\n)                    # EOL
                        |   # --OR--
                            (?-x:$delimiter)            # delimiter
                        |   # --OR--                    
                            (?!^)(?=["'])               # a quote
                        )  
                    )//xs or return;            # extended layout                  
                      my ($quote, $quoted, $unquoted, $delim) = (($1 ? ($1,$2) : ($3,$4)), $5, $6);

    return() unless( defined($quote) || length($unquoted) || length($delim));

    if ($keep) {
      $quoted = "$quote$quoted$quote";
    } else {
      $unquoted =~ s/\\(.)/$1/sg;
      if (defined $quote) {
        $quoted =~ s/\\(.)/$1/sg if ($quote eq '"');
      }
    }
    $word .= substr($line, 0, 0); # leave results tainted
    $word .= defined $quote ? $quoted : $unquoted;
 
    if (length($delim)) {
      push(@pieces, $word);
      push(@pieces, $delim) if ($keep eq 'delimiters');
      undef $word;
    }
    if (!length($line)) {
      push(@pieces, $word);
    }
  }
  return(@pieces);
}

# ----------------------------------------------------------------

1;
