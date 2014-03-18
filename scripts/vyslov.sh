#!/bin/bash
scriptdir=$(dirname $0)
while read word; do
    translated=$(echo $word \
        | sed -f $scriptdir/init.scp \
        | sed -f $scriptdir/prepis.scp \
        | perl -nle "use utf8; use open qw(:std :utf8); print lc" \
        | $scriptdir/prague_pilsen.prl \
        | $scriptdir/replace_infreq.prl )
    echo $word $translated
done

