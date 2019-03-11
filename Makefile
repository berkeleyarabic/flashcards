TABLES:=$(shell cat tables.txt)
GLOSS_TABLES:=$(shell cat gloss_tables.txt)

#$(warning TABLES=$(TABLES))

ALLDEPS= \
	$(TABLES:.tab=-words.html) \
	all-words.html \
	index.html howtostudy.html \
	$(TABLES:.tab=.pdf) \
	berkeleyarabic-glossary.pdf

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

all-words.html : $(GLOSS_TABLES)
	./make-wordlist-cgi $^ -o all

berkeleyarabic-glossary.pdf : $(GLOSS_TABLES)
# exclude capitals from glossary because it looks funny to have Arabic
# in wrong column
	./make-glossary --e2a --a2e -K \
		$(GLOSS_TABLES) -o berkeleyarabic \
		-t "Berkeley Arabic Glossary"

TAGS: perl/*.pm *.pl
	etags $^

# https://stackoverflow.com/questions/16467718/how-to-print-out-a-variable-in-makefile
# modified to produce zsh arrays
print-%  : ; @echo $*="(" $($*) ")"
