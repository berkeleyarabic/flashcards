#!/usr/bin/perl
package U;

require Exporter;
@ISA=qw(Exporter);
@EXPORT=qw(dmsg vmsg nmsg
           pv sv sh *sh_err 
           *sh_ev *sh_failed *sh_sig *sh_core *sh_errno *sh_cmd
           esh *sh_stderr *sh_stdout
           min max argmin argmax
           update_best
           sum cumsum ave clean_path defor mapdef save_cwd
           lock_file unlock_file read_file write_file
           read_headers zip
           escape unescape iter *iter_num
           unshellwords
           shellwords sQ
           scale_bytes
           *verbose *debug *quiet);

use warnings;
use strict;

use File::Temp;
use Carp;

our $debug=1; # so pv works by default
our $verbose=1;
our $quiet=0;

use PV;
*pv = \&PV::pv;
*sv = \&PV::sv;
*debug = \$PV::debug; # this seems to link the two variables
# (test with: perl -MU -le '$U::debug=0; pv "1+1"')

sub dmsg { print STDERR @_, "\n" if($debug); }
sub vmsg { print STDERR @_, "\n" if $verbose; }
sub nmsg { print STDERR @_, "\n" if !$quiet; }


# old, use unshellwords or shell_quotemeta instead
sub sh_quote {
  my ($n) = shift;
  defined($n) or die "internal error";
  $n =~ s/([ \!\"\#\$\&\'\(\)\*\;\<\=\>\?\[\\\]\_\`\{\|\}\~\001-\037\177-\377])/\\$1/g;
#\`\'\"<>{}\[\]~\$&*?\#!\|; \n\t\(\)\\\001-\037\177-\377])/\\$1/g;
  return $n;
}

our ($no_act, $sh_err, $sh_cmd);
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
  # FHE 15 Mar 2016: I guess we do this because embedded newlines are
  # not recognized in double quotes in shell
  my $secret = "58ihaipX1";
  $cmd =~ s/\\\\/$secret/g;
  $cmd =~ s/\\\n/'\n'/g;
  $cmd =~ s/$secret/\\\\/g;
  return if !$cmd;
  vmsg "$cmd";
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

sub min {
  my $v = shift;
  for(@_) { $v = $_ if $_ < $v; }
  return $v;
}

sub max {
  my $v = shift;
  for(@_) { $v = $_ if $_ > $v; }
  return $v;
}

# return index of smallest element
sub argmin {
  my $n = 0;
  my $i = 0;
  my $v = shift;
  for(@_) {
    $i++;
    if($_ < $v) {
      $v = $_;
      $n = $i;
    }
  }
  return $n;
}

# return index of largest element
sub argmax {
  my $n = 0;
  my $i = 0;
  my $v = shift;
  for(@_) {
    $i++;
    if($_ > $v) {
      $v = $_;
      $n = $i;
    }
  }
  return $n;
}

sub update_best {
  my ($i, $f, $rbi, $rbf) = @_;
  if(!defined $$rbf || $f > $$rbf) {
    $$rbf = $f;
    $$rbi = $i;
  }
}

sub sum {
  my ($package, $filename, $line) = caller;
  my (@n) = @_;
  my $s = 0;
  for(@n) {
    warn "Passed undefined value to 'sum' on $filename:$line\n" if !defined($_);
    $s+=$_;
  }
  return $s;
}

sub cumsum {
  my ($package, $filename, $line) = caller;
  my (@n) = @_;
  my $s = 0;
  my @s = ($s);
  for(@n) {
    warn "Passed undefined value to 'cumsum' on $filename:$line\n" if !defined($_);
    $s+=$_;
    push @s, $s;
  }
  return @s;
}

sub ave {
  return sum(@_)/scalar(@_);
}

sub _strip_single_dots {
  while(s!(^|/)\./(.)!$1$2!g) {}
  while(s!/\.$!!g) {}
}

sub _strip_double_dots {
  while(s!^/\.\.?($|/)!/!) {};
  while(s!/[^/]+/\.\.($|/)!/!g) {};
  while(s!^[^/]+/\.\.($|/)!.$1!g) {};
}

# Return a "canonical" version of a file path. Similar to "$(cd $f;
# pwd)" in shell, but doesn't require the path to exist or be a
# directory, and keeps relative paths relative.
sub clean_path {
  $_=shift;
  my $changed=0;
  while(s!//+!/!g) {}
  _strip_single_dots;
  _strip_double_dots;
  _strip_single_dots;
  while(s!(.)/$!$1!g) {}
  return $_;
}

use File::Basename;
use Errno qw(EINTR EIO :POSIX);

sub lock_file {
  # XXX modify to optionally write and check pid
  my ($is_local, $lock) = @_;
  my $dir = dirname($lock);
  my $res;
 restart:
  if(-e $lock) {
    if($is_local) {
      open IN, '<', $lock or die "Couldn't open $lock for reading: $!";
      my $pid = join("", <IN>);
      close IN;
      $pid =~ /^\s*(\d+)\s*$/ or die "Expected pid number in $lock, found $pid";
      $pid = $1;
      if(!(kill 0, $pid) && $!{ESRCH}) {
        warn "Warning: deleting orphaned lockfile $lock from non-existent pid $pid";
        unlink $lock;
        goto restart;
      }
    }
    print "Already locked\n";
    $res = 0;
  } else {
    my $tmpf;
    do { $tmpf = "$dir/.lock.".(int rand 1000000000); } while (-e $tmpf);
    open OUT, '>', $tmpf or die "Couldn't create temporary file $tmpf: $!";
    print OUT "$$\n";
    close OUT;
    if((link $tmpf, $lock) || (stat $tmpf)[3] == 2) {
      (stat $tmpf)[3] == 2 or die "Internal error";
      $res = 1;
    } else {
      print "Couldn't take lock\n";
      $res = 0;
    }
    unlink $tmpf or die "Couldn't unlink $tmpf: $!";
  }
  return $res;
}

sub unlock_file {
  my ($lock) = @_;
  unlink $lock or die "Couldn't unlink $lock: $!";
}

sub read_file ($) {
  my ($file) = @_;
  my $data;
  open IN, '<', $file or croak "Couldn't open $file for reading: $!";
  $data = join("", <IN>);
  close IN or warn "Error closing $file: $!\n";
  return $data;
}

sub write_file ($$) {
  my ($file,$data) = @_;
  open OUT, '>', $file or croak "Couldn't open $file for writing: $!";
  print OUT $data;
  close OUT or warn "Error closing $file: $!\n";
}

sub defor ($$) {
  my ($a, $b) = @_;
  return $a if defined $a;
  return $b;
}

sub mapdef (&$) {
  my ($sub, $val) = @_;
  if(defined $val) {
    $_ = $val;
    return &$sub;
  } else {
    return undef;
  }
}

sub caller_str {
  my @c = caller 1;
  return "$c[0]::$c[1]:$c[2]";
}

do {
  use Cwd;
  sub save_cwd (&) {
    my ($b) = @_;
    my $pwd = getcwd;
      # dmsg ("start of save_cwd: ".caller_str." ".getcwd());
    if(wantarray) {
      my @res=&$b();
      chdir($pwd);
      # dmsg ("end of save_cwd (array): ".caller_str." ".getcwd());
      return @res;
    } else {
      my $res=&$b();
      chdir($pwd);
      # dmsg ("end of save_cwd: ".caller_str." ".getcwd());
      return $res;
    }
  }
};

# return a list of headers, with newlines removed
sub read_headers ($) {
  my ($f)=@_;
  my @hdr;
  local *IN;
  open IN, "<", $f or die "Couldn't open $f for reading";
  @hdr=();
  my $cur_hdr;
  while (<IN>) {
    chomp;
    if ($_ =~ /^[ \t]/) {
      warn "Bad header format: $_" unless defined $cur_hdr;
      $cur_hdr .= $_;
      next;
    }
    push @hdr, $cur_hdr if defined $cur_hdr;
    $cur_hdr=$_;
    if ($_ =~ /^$/) {
      last;
    }
  }
  close IN;
  return @hdr;
}

sub zip {
  my ($m,@r);
  $m = min map {scalar @$_} @_;
  for my $i (0..$m-1) {
    $r[$i] = [map {$_->[$i]} @_];
  }
  return @r;
}

my %esc_codes = (
    'n' => "\n",
    't' => "\t",
    'r' => "\r"
  );

my %esc_rev = (
    "\n" => 'n',
    "\t" => 't',
    "\r" => 'r',
    "\\" => '\\'
  );

sub unescape {
  my ($v)=@_;
  $v =~ s/(?<!\\)(\\(.))/$esc_codes{$2} || $2/gex;
  return $v;
}

sub escape {
  my ($v)=@_;
  my $old = $v;
  $v =~ s/([\n\r\t\\])/"\\".$esc_rev{$1}/gex;
  $old eq (unescape $v) or die "internal error";
  return $v;
}

# Call this in a loop to print a message every certain number of
# iterations
my $t0 = time();
my $t1;
our $iter_num=0;
sub iter ($) {
  my ($skip) = (@_);
  $iter_num++;
  if (($iter_num%$skip)==0) {
    $t1 = time();
    if ($t1-$t0 > 0) {
      nmsg "Row $iter_num";
      $t0 = $t1;
    }
  }
}

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

# see ln-compact
  sub scale_bytes { # http://www.perlmonks.org/?node_id=378538
    my ($size, $n) = (shift, 0);
    ++$n and $size /= 1024 until $size < 1024;
    return sprintf "%.2f %s",
    $size, (qw[ bytes KB MB GB TB ])[$n];
  }



1;
