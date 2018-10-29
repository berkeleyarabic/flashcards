TABLES:=$(shell cat tables.txt)

#$(warning TABLES=$(TABLES))

ALLDEPS=$(TABLES:.tab=.pdf) \
	$(TABLES:.tab=-words.html) all-words.html \
	index.html howtostudy.html berkeleyarabic-glossary.pdf

all: $(ALLDEPS)

clean:
	rm -f $(ALLDEPS)

index.html: INDEX.md
	./run-mmd -D $<

howtostudy.html: howtostudy.md
	./run-mmd -D $<

# FHE 10 Sep 2018 This is old and not part of 'all'
pronouns.pdf : pronouns.tab pronouns.Ttex
	template-pdflatex pronouns.Ttex

%.pdf : %.tab
	./table-to-cards $<

%-words.html : %.tab
	./make-wordlist-cgi $<

all-words.html : $(TABLES)
	./make-wordlist-cgi $^ -o all

berkeleyarabic-glossary.pdf : $(TABLES)
# exclude capitals from glossary because it looks funny to have Arabic
# in wrong column
	./make-glossary --e2a --a2e -K \
		$(filter-out capitals.tab,$(TABLES)) -o berkeleyarabic \
		-t "Berkeley Arabic Glossary"

TAGS: perl/*.pm *.pl
	etags $^

# https://stackoverflow.com/questions/16467718/how-to-print-out-a-variable-in-makefile
# modified to produce zsh arrays
print-%  : ; @echo $*="(" $($*) ")"
