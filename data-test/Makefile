SHELL=/bin/bash

.PHONY: all clean

all: wdnet.lat dict.test test_vety.txt

wdnet.lat: wdnet.grm
	HParse $< $@

dict.test: dict.tst.base
	cat $< \
		| sort -u \
		| ../scripts/vyslov.sh \
		> $@

test_vety.txt: wdnet.lat dict.test
	HSGen -n 40 wdnet.lat dict.test > $@

clean:
	rm -rf test_vety.txt dict.test wdnet.lat
