SHELL=/bin/bash
MOSESROOT = /home/mmachace/mosesdecoder
TOKENIZER = $(MOSESROOT)/scripts/tokenizer/tokenizer.perl

.PHONY: all clean

all: hmm7

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

# Foneticky slovnik (+ oprava chyby d ě -> dj e)
dict: words
	cat $< \
		| scripts/vyslov.sh \
		| sed "s/d ě/dj e/g" \
		> $@
	echo "silence sil" >> $@

# Prevod do slovniho MLF formatu
words.mlf: sentences-clean
	cat $< | scripts/toMLF.bash > $@

# Prevod do fonetickeho MLF formatu
phones0.mlf: words.mlf dict mkphones0.led
	HLEd \
		-l '*' \
		-d dict \
		-i $@ \
		mkphones0.led \
		$<

# Seznam zvukovych souboru ke kodovani
codestr.scp: data-train
	scripts/genScp.bash $< | sort -t- -k3n > $@

# Kodovani zvukovych souboru do mfc formatu
coded_sounds: codestr.scp config
	HCopy \
		-T 1 \
		-C config \
		-S $< \
		> $@

# Seznam zakodovanych souboru
train.scp: codestr.scp
	cat $< | cut "-d " -f2 > $@

# Pocatecni parametry prototypu
hmm0: config1 train.scp proto coded_sounds
	rm -rf $@; mkdir $@
	HCompV \
		-T 1 \
		-C config1 \
		-f 0.01 \
		-m \
		-S train.scp \
		-M $@ \
		proto

# Globalni informace
hmm0/macros: hmm0
	head -n 3 $</proto > $@
	cat $</vFloors >> $@

# Pocatecni parametry pro kazdy fonem
hmm0/hmmdefs: hmm0 monophones0
	echo "" > $@
	while read monophone; do \
		cat $</proto \
			| tail -n+4 \
			| sed "s/proto/$$monophone/g" \
			>> $@; \
	done < monophones0 

hmm1: hmm0 hmm0/macros hmm0/hmmdefs config1 phones0.mlf train.scp monophones0
	rm -rf $@; mkdir $@
	HERest \
		-T 1 \
		-C config1 \
		-I phones0.mlf \
		-t 250.0 150.0 1000.0 \
		-S train.scp \
		-H $</macros \
		-H $</hmmdefs \
		-M $@ \
		monophones0

hmm2: hmm1 config1 phones0.mlf train.scp monophones0
	rm -rf $@; mkdir $@
	HERest \
		-T 1 \
		-C config1 \
		-I phones0.mlf \
		-t 250.0 150.0 1000.0 \
		-S train.scp \
		-H $</macros \
		-H $</hmmdefs \
		-M $@ \
		monophones0

hmm3: hmm2 config1 phones0.mlf train.scp monophones0
	rm -rf $@; mkdir $@
	HERest \
		-T 1 \
		-C config1 \
		-I phones0.mlf \
		-t 250.0 150.0 1000.0 \
		-S train.scp \
		-H $</macros \
		-H $</hmmdefs \
		-M $@ \
		monophones0

hmm4: hmm3 sp_state
	rm -rf $@
	cp -r $< $@
	cat sp_state >> $@/hmmdefs

hmm5: hmm4 sil.hed monophones1
	rm -rf $@; mkdir $@
	HHEd \
		-H $</macros \
		-H $</hmmdefs \
		-M $@ \
		sil.hed \
		monophones1

# Prevod do fonetickeho MLF formatu (tentokrat i s sp)
phones1.mlf: words.mlf dict mkphones1.led
	HLEd \
		-l '*' \
		-d dict \
		-i $@ \
		mkphones1.led \
		$<

hmm6: hmm5 config1 phones1.mlf train.scp monophones1
	rm -rf $@; mkdir $@
	HERest \
		-T 1 \
		-C config1 \
		-I phones1.mlf \
		-t 250.0 150.0 1000.0 \
		-S train.scp \
		-H $</macros \
		-H $</hmmdefs \
		-M $@ \
		monophones1

hmm7: hmm6 config1 phones1.mlf train.scp monophones1
	rm -rf $@; mkdir $@
	HERest \
		-T 1 \
		-C config1 \
		-I phones1.mlf \
		-t 250.0 150.0 1000.0 \
		-S train.scp \
		-H $</macros \
		-H $</hmmdefs \
		-M $@ \
		monophones1

# Kontrola: Foneticky prepis
aligned.mlf: hmm7 config1 words.mlf train.scp dict monophones1
	HVite \
		-T 1 \
		-l '*' \
		-o SWT \
		-b silence \
		-C config1 \
		-a \
		-H $</macros \
		-H $</hmmdefs \
		-i $@ \
		-m \
		-t 250.0 \
		-I words.mlf \
		-S train.scp \
		-y lab \
		dict \
		monophones1

# Vyfiltrovany seznam vet
train-filtered.scp: aligned.mlf
	cat $< \
		| grep "^\".*\"$$" \
		| sed "s/\"//g" \
		| sed "s/\*/data-train/" \
		| sed "s/lab/mfc/" \
		> $@

hmm8: hmm7 config1 aligned.mlf train-filtered.scp monophones1
	rm -rf $@; mkdir $@
	HERest \
		-T 1 \
		-C config1 \
		-I aligned.mlf \
		-t 250.0 150.0 1000.0 \
		-S train-filtered.scp \
		-H $</macros \
		-H $</hmmdefs \
		-M $@ \
		monophones1

hmm9: hmm8 config1 aligned.mlf train-filtered.scp monophones1
	rm -rf $@; mkdir $@
	HERest \
		-T 1 \
		-C config1 \
		-I aligned.mlf \
		-t 250.0 150.0 1000.0 \
		-S train-filtered.scp \
		-H $</macros \
		-H $</hmmdefs \
		-M $@ \
		monophones1

clean:
	rm -rf sentences-clean words dict *.mlf data-train/*.mfc *.scp hmm* coded_sounds aligned.mlf
