package ReadTable;

require Exporter;
@ISA=qw(Exporter);
@EXPORT=qw(read_table format_group *foot_fmt *tab_fn *curr_line);

use warnings;
use strict;

use PV;

our ($foot_fmt, $tab_fn, $curr_line, $verbose);

sub format_group {
  my ($group) = @_;
  if(defined $group) {
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
  return $str;
}

sub read_table ($$) {
  my ($callback, $tab_files) = @_;
  for my $tf (@$tab_files) {
    $tab_fn = $tf;
    -e $tab_fn or die "Table file $tab_fn does not exist\n";

    warn "Reading from $tab_fn" if $verbose;

    open IN, "<", $tab_fn or
        die "Couldn't open $tab_fn for reading\n";

    while(<IN>) {
      chomp;
      if(/^##\@\s*(.*)$/) {
        $foot_fmt = $1;
      }
      s/#.*$//;
      next if /^\s*$/;
      $curr_line = $_;
      my (@c) = split /:/, $_;
      #    pv '\@c';
      # remove spaces
      @c = map { s/^\s*(.*?)\s*$/$1/; $_ } @c;

      &$callback(@c);
    }
    close IN;
  }
}

1;
