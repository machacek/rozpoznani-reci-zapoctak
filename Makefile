SHELL=/bin/bash

.PHONY: all clean data-test

all: results

# Tokenizovana a vycistena data
sentences-clean: data-train/sentences-original
	cat $< \
		| sed "s/[-'\"„“?!():–,.]/ /g" \
		| sed "s/\s\s*/ /g" \
		| sed "s/^\s*//" \
		| sed "s/\s*$$//" \
		| perl -nle "use utf8; use open qw(:std :utf8); print uc" \
		> $@

# Mnozina pouzitych slov
words: sentences-clean
	cat $< \
		| tr " " "\n" \
		| sort -u \
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
	cat $< | scripts/toMLF.bash data-train > $@

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

# Testovaci data
data-test:
	$(MAKE) -C $@	

# Seznam zvukovych souboru ke kodovani
test_codestr.scp:
	scripts/genScp.bash data-test | sort -t- -k3n > $@

# Kodovani zvukovych souboru do mfc formatu
test_coded_sounds: test_codestr.scp config
	HCopy \
		-T 1 \
		-C config \
		-S $< \
		> $@

# Seznam zakodovanych souboru
test.scp: test_codestr.scp
	cat $< | cut "-d " -f2 > $@

# Prevod do slovniho MLF formatu
test_words.mlf: data-test/test_vety_fixed.txt
	cat $< | scripts/toMLF.bash data-test > $@

# Rozpoznani vet
recout.mlf: hmm9 test.scp data-test monophones1 test_coded_sounds
	HVite \
		-T 1 \
		-C config1 \
		-H $</macros \
		-H $</hmmdefs \
		-S test.scp \
		-l 'data-test' \
		-i $@ \
		-w data-test/wdnet.lat \
		-p 0.0 \
		-s 5.0 \
		data-test/dict.test \
		monophones1

# Evaluace
results: recout.mlf test_words.mlf monophones1
	HResults \
		-I test_words.mlf \
		monophones1 \
		$< \
		| tee $@

clean:
	rm -rf sentences-clean words dict *.mlf data-train/*.mfc data-test/*.mfc *.scp hmm* coded_sounds test_coded_sounds aligned.mlf results
	$(MAKE) clean -C data-test
