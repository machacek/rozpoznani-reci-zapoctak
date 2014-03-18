SHELL=/bin/bash
MOSESROOT = /home/mmachace/mosesdecoder
TOKENIZER = $(MOSESROOT)/scripts/tokenizer/tokenizer.perl

.PHONY: all clean coded_sounds

all: phones0.mlf

# Tokenizovana a vycistena data
sentences-clean: data-train/sentences-original
	cat $< \
		| sed "s/[-'\"„“?!():–,.]//g" \
		| $(TOKENIZER) \
		| perl -nle "use utf8; use open qw(:std :utf8); print lc" \
		> $@

# Mnozina pouzitych slov
words: sentences-clean
	cat $< \
		| tr " " "\n" \
		| perl -nle "use utf8; use open qw(:std :utf8); print uc" \
		| sort -u \
		| grep -v "^[ 	]*$$" \
		| scripts/convert-numbers.sh \
		> $@

# Foneticky slovnik
dict: words
	cat $< | scripts/vyslov.sh > $@

# Prevod do slovniho MLF formatu
words.mlf: sentences-clean
	cat $< | scripts/toMLF.bash > $@

# Prevod do fonetickeho MLF formatu
phones0.mlf: words.mlf dict
	HLEd -l '*' -d dict -i $@ mkphones0.led $<

# Seznam zvukovych souboru ke kodovani
codestr.scp:
	scripts/genScp.bash data-train > $@

coded_sounds: codestr.scp
	HCopy -T 1 -C config -S $<



clean:
	rm -rf sentences-clean words dict *.mlf data-train/*.mfc codestr.scp
