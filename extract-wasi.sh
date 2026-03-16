#!/bin/bash

wtg=rs-log2sqlite-grok-wasi:0.1.0

container() {
	/usr/local/bin/container "$@"
}

get_blob() {
	local digest=$1
	container image save "${wtg}" | tar x -O - "blobs/sha256/${digest}"
}

index_digest() {
	container image save "${wtg}" |
		tar x -O - index.json |
		jq -r '.manifests[0].digest' |
		cut -d: -f2
}

manifest_digest() {
	local idig=$(index_digest)
	get_blob "${idig}" |
		jq -r '.manifests[0].digest' |
		cut -d: -f2
}

# The files are in different layers
# log2sqlite-grok.wasm is in the first layer
# log2parsed.wasm is in the second layer

extract_file() {
	local target_file=$1
	local mdig=$(manifest_digest)
	local layers=$(get_blob "${mdig}" | jq -r '.layers[].digest' | cut -d: -f2)

	for ldig in ${layers}; do
		if get_blob "${ldig}" | zcat | tar -t | grep -q "^${target_file}$"; then
			get_blob "${ldig}" | zcat | tar x -O "${target_file}" > "${target_file}"
			return 0
		fi
	done
	return 1
}

test -f "log2sqlite-grok.wasm" || extract_file "log2sqlite-grok.wasm"
test -f "log2parsed.wasm" || extract_file "log2parsed.wasm"
