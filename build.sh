#!/bin/bash

cargo \
	build \
	--release \
    --bin log2sqlite-grok \
    --features log2sqlite
