package ReadTable;

require Exporter;
@ISA=qw(Exporter);
@EXPORT=qw(read_vocab_table format_group *foot_fmt *tab_fn *curr_line);

use warnings;
use strict;

use String::Unquotemeta;
use PV;

our ($foot_fmt, $tab_fn, $curr_line, $verbose);

our $secret = sprintf("%08x",rand(16**8));

sub format_group {
  my ($group) = @_;
  if(defined $group) {
    # XXX move this to foot_fmt.pl
    $group =~ s/([+*-]+)$/\$^{$1}\$/;
  } else {
    $group = "";
  }
  if(!defined($foot_fmt)) {
    return "";
  }
  my ($str) = $foot_fmt;
#  pv '$str';
  $str =~ s/%g/$group/g;
  # remove leading and trailing space
  $str =~ s/^\s+//g;
  $str =~ s/\s+$//g;
  return $str;
}

# FHE 16 Sep 2018 the properties field is the 5th column of tables, it
# was introduced to add indexing hints, see make-glossary
sub parse_props ($) {
  my ($p) = @_;
  my (@l) = split /;/, $p;
  my (%props) = ();
  for my $kv (@l) {
    $kv =~ /^\s*(\w+)\s*=(.*)$/ or die "Malformed key-value \"$kv\" in $p, $tab_fn line $.";
    my ($k,$v) = ($1,$2);
    $props{$k} = $v;
  }
  return \%props;
}

sub read_vocab_table ($$) {
  my ($callback, $tab_files) = @_;
  for my $tf (@$tab_files) {
    $tab_fn = $tf;
    -e $tab_fn or die "Table file $tab_fn does not exist\n";

    warn "Reading from $tab_fn\n" if $verbose;

    open IN, "<:encoding(UTF-8)", $tab_fn or
        die "Couldn't open $tab_fn for reading\n";

    while(<IN>) {
      chomp;
      if(/^##\@\s*(.*)$/) {
        $foot_fmt = $1;
      }
      s/#.*$//;
      next if /^\s*$/;
      $curr_line = $_;

      $curr_line =~ s/\\\\/$secret/g;
      # split on :, not following \
      my (@c) = split /(?<!\\):/, $_;
      if(@c>5) {
        print "$_\n";
        die "Too many fields";
      }

      # restore \\, and unquote escapes
      @c = map { s/$secret/\\\\/g; unquotemeta $_ } @c;
      # remove spaces
      @c = map { s/^\s*(.*?)\s*$/$1/; $_ } @c;

      # at this point we make assumptions about table columns, this
      # code could be moved to another routine
      my ($arabic,$english,$group,$notes,$props) = @c;
      my ($foot) = format_group $group;
      my ($artransl);
      if($arabic =~ /^(.*?)\s*\|\|\s*(.*)$/) {
        ($arabic, $artransl) = ($1, $2);
      }
      my $pdict = {};
      if(length($props)) {
        $pdict = parse_props $props;
#        pv '$pdict';
      }
      
      &$callback($arabic,$artransl,$english,$foot,$notes,$pdict);
    }
    close IN;
  }
}

1;
