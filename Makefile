all: letters-positions.pdf numerals.pdf \
	bcc-workbook-words.pdf ma-units-1-4.pdf ma-units-5-7.pdf \
	ma-units-9-10.pdf ma-units-11-13.pdf \
	ma-unit-14.pdf ma-unit-16.pdf \
	classroom-vocab.pdf \
	colors.pdf pronouns.pdf \
	capitals.pdf \
	verb-conj-ktb.pdf

pronouns.pdf : pronouns.tab pronouns.Ttex
	template-pdflatex pronouns.Ttex

%.pdf : %.tab
	./table-to-cards $<
