SHELL=/bin/bash
MOSESROOT = /home/mmachace/mosesdecoder
TOKENIZER = $(MOSESROOT)/scripts/tokenizer/tokenizer.perl

.PHONY: all clean coded_sounds

all: hmm0

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
phones0.mlf: words.mlf dict mkphones0.led
	HLEd -l '*' -d dict -i $@ mkphones0.led $<

# Seznam zvukovych souboru ke kodovani
codestr.scp: data-train
	scripts/genScp.bash $< | sort -t- -k3n > $@

# Kodovani zvukovych souboru do mfc formatu
coded_sounds: codestr.scp config
	HCopy -T 1 -C config -S $<

# Seznam zakodovanych souboru
train.scp: codestr.scp
	cat $< | cut "-d " -f2 > $@

hmm0: config1 train.scp proto coded_sounds
	rm -rf $@; mkdir $@
	HCompV -T 1 -C config1 -f 0.01 -m -S train.scp -M $@ proto


clean:
	rm -rf sentences-clean words dict *.mlf data-train/*.mfc *.scp hmm*
