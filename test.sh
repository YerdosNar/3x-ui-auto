#!/bin/bash

readonly filename="test.sh"

file_init() {
    local file="$1"
    local f_ext="${file##*.}"
    local f_name="${file%.*}"

    local count=1
    local new_f="$file"

    while [ -e "$new_f" ]; do
        new_f="${f_name}_$count.${f_ext}"
        ((count++))
    done

    echo "$new_f"
}

new_file=$(file_init $filename)

echo "FILE: $filename"
echo "NEW FILE: $new_file"

touch "$new_file"

new_new_file=$(file_init $filename)
echo "NEW NEW FILE: $new_new_file"
