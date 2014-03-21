#!/bin/bash

dir=$1

echo "#!MLF!#"

i=1
while read line; do
    echo "\"$dir/sentence-$i.lab\""
    echo $line | tr " " "\n" | scripts/convert-numbers.sh
    echo "."
    i=$(($i + 1))
done
