if($doctitle =~ /^ma-unit-([\d-]+)$/) {
  $doctitle = "Mastering Arabic 1 Unit $1";
} elsif($doctitle eq "verb-conj-ktb") {
  $doctitle = "Verb Conjugations (Kataba)"
} elsif($doctitle eq "pronouns-possessives") {
  $doctitle = "Pronouns and Possessives"
} else {
  $doctitle =~ s/^bas/BAS/;
  $doctitle =~ s/^bcc/BCC/;
  $doctitle =~ s/^uc/UC/;
  $doctitle =~ s/-/ /g;
  $doctitle =~ s/(^| )(.)/$1.(ucfirst $2)/eg;
}
