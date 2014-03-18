#!/bin/bash

dir=$1

for file in $dir/*.wav; do 
    new_file=$(echo $file | sed "s/\.wav$/\.mfc/")
    echo $file $new_file
done
