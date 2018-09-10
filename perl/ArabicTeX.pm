package ArabicTeX;

require Exporter;
@ISA=qw(Exporter);
@EXPORT=qw(tex_fixup arabic_fixup);

use warnings;
use strict;

use Encode;
use PV;

# FHE 05 Jul 2018 todo: rename this

# FHE 08 Jul 2018 todo: fix parenthesis problems. what we need to do:
# split text into words, on whitespace. join consecutive words if they
# contain arabic characters, and wrap them with \ta, defined in
# arab_fc_common

# regex for multi-character words
our $c = qr/[\p{Arabic}\.\/,\(\)]/;
# regex for single-character words
our $c1 = qr/[\p{Arabic}]/;

sub tex_fixup {
  local $_ = shift;
  s/\b"/''/g; s/"\b/``/g;
  s/_/\\_/g;
  $_;
}

# our arabic regex matches all-punctuation words; exclude these
sub wrap_if_arabic {
  local $_ = shift;
  /$c1/ ? "\\ta{$_}" : $_;
}

# FHE 09 Jul 2018 old version, worked badly on arabic words joined by
# punctuation and spaces
sub arabic_fixup1 {
  local $_ = shift;
  $_ = decode('utf-8', $_);
  $_ = tex_fixup $_;
#  my $c = qr/[\p{Bidi_Class=r}\.]/;
  #  my $c = qr/\p{Arabic}/;

  s/($c(?:$c| )*$c|$c1)/@{[wrap_if_arabic $1]}/g;
  $_ = encode('utf-8', $_);
  $_;
}

# FHE 09 Jul 2018 new version, split into words and join consecutive
# words of same language. FHE 10 Sep 2018 XXX need to clean this up by
# splitting parts into more general function
sub arabic_fixup {
  local $_ = shift;
  die "undefined argument in arabic_fixup" if !defined $_;
  $_ = decode('utf-8', $_);
  $_ = tex_fixup $_;
  # assuming OK to lose whitespace info
  my (@w) = split /\s+/, $_;
  my (@ls) = map {/$c1/?"arabic":
                      (/[a-zA-Z]/?
                       "english":
                       "")} @w;
  my @j = ([]);
  # @j is an array of arrays, each element is a string of consecutive
  # same-language words of @w
  my $last_l = "";
  for my $i (0..$#w) {
    if($i==0
       || $ls[$i] eq ""
       || $last_l eq ""
       || $ls[$i] eq $last_l
        ) {
      # combine two consecutive language-segments if one or the other
      # is "" or if they are the same language
      push @{$j[$#j]}, $w[$i];
      $last_l = $last_l || $ls[$i];
    } else {
      # otherwise start a new language
      push @j, [$w[$i]];
      $last_l = $ls[$i];
    }
  }
  # pv '\@w';
  # pv '\@ls';
  # pv '\@j';
  my $res = join(" ", map { wrap_if_arabic(join(" ", @$_)) } @j);
  # pv '\@ls';
  # pv '\@w';
  # pv '\@j';
  # pv '$res';
  $res = encode('utf-8', $res);
  $res;
}

