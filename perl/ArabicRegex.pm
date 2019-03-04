package ArabicRegex;

# 03 Mar 2019

# Simple tool for matching Arabic words with each other even when
# diacritics are different. This is not the same as "normalizing"
# (e.g. removing diacritics) and then comparing for equality. We want
# to make use of the information available in the diacritics and match
# only other words with compatible diacritics

# Future work:

# This is very basic at the moment. For example, in most text a shadda
# (gemination) can be elided, but if another diacritic is present then
# I think the shadda would also be present. This doesn't catch the
# case where an author disambiguates with full diacritics, and wants
# to exclude the possibility of a shadda, e.g. عَلِمَ • (ʿalima) "to
# know" will not match عَلَّمَ • (ʿallama) "to teach" although it will
# match علّم, another way of writing the same word

# Also, currently unless you match a full string (like /^$re$/), there
# is a possibility that incompatible diacritics will be added to the
# end of the word you're matching. This could be avoided with a
# negative lookahead assertion

require Exporter;
@ISA=qw(Exporter);
@EXPORT=qw(arabic_to_regex);

use warnings;
use strict;

use open (":encoding(UTF-8)", ":std" );
use Unicode::UCD 'namedseq';

# for debugging
use PV;

# if one of these appears, only another of same group can# replace it
my @excl_classes = (
  ['ARABIC FATHATAN',
   'ARABIC FATHA',
   'ARABIC LETTER SUPERSCRIPT ALEF'],
  ['ARABIC DAMMA',
   'ARABIC DAMMATAN'],
  ['ARABIC KASRATAN',
   'ARABIC KASRA'],
  ['ARABIC SUKUN']);
# these can appear anywhere
my @any_classes = ('ARABIC SHADDA',
                   'ARABIC SMALL HIGH ROUNDED ZERO');


my @any_chars = map {scalar(namedseq($_))} @any_classes;
my $anycs = join("",@any_chars);

my $exclcs = "";
my %allowed;
for my $cl (@excl_classes) {
  my @cs;
  for my $ns (@$cl) {
    my $c = namedseq($ns);
    push @cs, $c;
  }
  my $clcs = join("",@cs);
  for my $c (@cs) {
    $allowed{$c} = $clcs;
  }
  $exclcs .= $clcs;
}

sub arabic_to_regex {
  my ($str) = @_;
  my $origstr = $str;

  # why did i do this?
#  $str = quotemeta($str);

  # remove non-exclusive diacritics since they will either be present
  # or not present in a matching string
  $str =~ s/[$anycs]//g;

  # remaining diacritics are exclusive, which means that we must have
  # only one after each letter
  if($str =~ /\p{Mn}{2,}/) {
    die "Consecutive exclusive diacritics found in $origstr line $.";
  }
  # check that all remaining diacritics are known
  while($str =~ /(\p{Mn})/g) {
    defined $allowed{$1}
        or die "Found unknown diacritic $1 in $origstr line $.";
  }

  my @chrs = split("", $str);
  my $outre = "";
  while(@chrs>0) {
    my $c = $chrs[0];
    my $nc = $chrs[1] || "";
    if($c =~ /\p{L}/ && $nc !~ /\p{Mn}/) {
  # letters not followed by diacritic: match any sequence of
  # diacritics
      $outre .= $c."[".$anycs.$exclcs."]*"
    } elsif($c =~ /\p{Mn}/) {
  # letter followed by diacritic (it must be exclusive since we
  # removed the others): allow it to match compatible diacritics, as
  # well as any non-exclusives
      $outre .= "[".$allowed{$c}.$anycs."]*"
    } elsif($c =~ /\s/) {
      # any sequence of one or more spaces is matched by any sequence of
      # one or more spaces
      if($nc !~ /\s/) {
        $outre .= "\\s+";
      }
    } else {
      # match remaining characters (e.g. punctuation) verbatim (?)
      $outre .= "$c";
    }
    shift @chrs;
  }
#  pv '$outre'; warn "outre=$outre\n";
  return $outre;
}

# Zs - space
# L - letter
# Mn - nonspacing mark

# TODO
# - ligatures
#   - lam alef
#   - hamza above/below (?)

1;
