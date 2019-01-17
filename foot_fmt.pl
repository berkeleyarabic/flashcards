sub foot_fold {
  my ($f) = @_;
  $f =~ s/\$\^\{(.*)\}\$/$1/;
  return $f;
}

# Format card footer for word lists
sub foot_fmt {
  my ($f) = @_;
  $f = foot_fold $f;
  $f =~ s/^MA /Mastering Arabic /;
  $f =~ s/[?+*-]*$//g;
  $f =~ s/\s+$//g;
  $f =~ s/^\s+//g;
  return $f;
}

# Format card footer for index
sub foot_fmt_idx {
  my ($f) = @_;
#  $f = foot_fold $f;
  $f =~ s/^MA Unit/MA/;
  $f =~ s/^BCC Words/BCC/;
  $f =~ s/^Classroom/Class/;
  $f =~ s/Conjugations/Conj/;
  $f =~ s/^Present/Pres/;
  $f =~ s/^Possessive/Poss/;
  $f =~ s/Suffixes/Suff/;
  # $f =~ s/^MA /Mastering Arabic /;
  # $f =~ s/[?+*-]*$//g;
  return $f;
}


sub pad_digits {
  # assumes we won't have any numbers longer than 6 digits
  my ($s) = @_;
  $s =~ s/(\d+)/@{["0"x(6-length($1)).$1]}/g;
  return $s;
}

sub foot_sortable {
  my ($f) = @_;
  $f = pad_digits(foot_fold $f);
  my $order;
  $order = 1 if $f =~ /^BCC/i;
  $order = 2 if $f =~ /^MA|Mastering Arabic/i;
  $order = 3 if $f =~ /^Classroom vocab/i;
  $order = 4 if $f =~ /^Numerals/i;
  $order = 5 if $f =~ /^Pronouns/i;
  $order = 6 if $f =~ /^Possessive/i;
  $order = 7 if $f =~ /^Past Conj/i;
  $order = 8 if $f =~ /^Present Conj/i;
  $order = 9 if $f =~ /^Capitals/i;
  $order = 10 if $f =~ /^Colors/i;
  $order = 11 if $f =~ /^Weekdays/i;
  $order = 13 if $f =~ /^BAS Verbs/i;
  $order = 14 if $f =~ /^BAS Body Parts/i;
  $order = 15 if $f =~ /^BAS Countryside/i;
  $order = 20 if $f =~ /^Alphabet/i;
  unless(defined $order) {
    warn "Unrecognized footnote type $f, sorting to end";
    $order = 1000;
  }
  $f = pad_digits($order).$f;
}

sub foot_cmp {
  my ($a,$b)=@_;
  $a = foot_sortable $a;
  $b = foot_sortable $b;
  return ($a cmp $b);
}
