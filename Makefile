TABLES=letters-positions.tab numerals.tab \
	bcc-workbook-words.tab ma-unit-1-4.tab ma-unit-5-7.tab \
	ma-unit-9-10.tab ma-unit-11-13.tab \
	ma-unit-14.tab ma-unit-16.tab \
	classroom-vocab.tab \
	colors.tab pronouns-possessives.tab \
	capitals.tab \
	verb-conj-ktb.tab

all: $(TABLES:.tab=.pdf) \
	$(TABLES:.tab=-words.html) all-words.html \
	index.html all-glossary.pdf

clean:
	rm -f $(TABLES:.tab=.pdf) \
		$(TABLES:.tab=-words.html) all-words.html \
		index.html

index.html: INDEX.md
	./run-mmd -D $<

# FHE 10 Sep 2018 This is old and not part of 'all'
pronouns.pdf : pronouns.tab pronouns.Ttex
	template-pdflatex pronouns.Ttex

%.pdf : %.tab
	./table-to-cards $<

%-words.html : %.tab
	./make-wordlist $<

all-words.html : $(TABLES)
	./make-wordlist $^ -o all

all-glossary.pdf : $(TABLES)
	./make-glossary --e2a --a2e -K \
		$(filter-out capitals.tab,$(TABLES)) -o all

TAGS:
	etags perl/*.pm
