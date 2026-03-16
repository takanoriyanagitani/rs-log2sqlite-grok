#!/bin/sh

wtg=rs-log2sqlite-grok-wasi:0.1.0

acontainer="/usr/local/bin/container"
adir="/usr/local/bin"

build_apple_wasi() {
    test -x "${acontainer}" || exec env abin="${acontainer}" sh -c '
        echo apple container "${abin}" missing.
        exit 1
    '

    PATH="${adir}:${PATH}"

	container image inspect "${wtg}" |
		jq --raw-output '.[].name' |
		fgrep -q "$wtg" &&
		return

	echo building image "${wtg}"...

	container \
		build \
		--file ./Dockerfile \
		--platform linux/arm64 \
		--progress plain \
		--tag "${wtg}" \
		.
}

build_apple_wasi
