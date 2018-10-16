#!/usr/bin/perl

# "Print value": display an expression, and then its value. Evaluates
# the expression in the context of the caller. Useful for debugging:
# just substitute "pv q{EXPR}" for "EXPR" when you want to examine its
# value. EXPR should be a scalar, but arrays and hashes can be made
# into scalars with [] and {}. Uses Data::Dumper to print the full
# object tree.

package PV;

require Exporter;
@ISA=qw(Exporter);
@EXPORT=qw(pv sv);

use warnings;
use strict;

our $debug = 1;

use Data::Dumper;

# an alias for Dumper
sub sv {
  my $e = shift;
  local $Data::Dumper::Indent=0;
  local $Data::Dumper::Purity=1;
  local $Data::Dumper::Terse=1;
  return Dumper($e);
}

do {
  # Declaring this in package DB results in special "eval" behavior:
  # the expression is evaluated in the first non-DB lexical scope

  package DB;

  sub pv {
    return unless $debug;
    my $e = shift;
    my ($package, $filename, $line) = caller;
    my $v = PV::sv(eval "package $package; ($e)");
    die $@ if $@;
    print STDERR "$e = $v\n";
  }
};

*pv = \&DB::pv;

