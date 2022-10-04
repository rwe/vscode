#!/usr/bin/env bash
set -e

if [[ "$OSTYPE" == darwin* ]]; then
	realpath() { [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"; }
else
	realpath() { readlink -f "$1"; }
fi

ROOT="$(dirname "$(dirname "$(realpath "$0")")")"
cd "$ROOT"

# Node modules
test -d node_modules || yarn

# Get electron
yarn electron

VSCODECRASHDIR="$ROOT/.build/crashes"

if [[ "$OSTYPE" == darwin* ]]; then
	NAME="$(node -p "require('./product.json').nameLong")"
	CODE="./.build/electron/$NAME.app/Contents/MacOS/Electron"
else
	NAME="$(node -p "require('./product.json').applicationName")"
	CODE=".build/electron/$NAME"
	# --disable-dev-shm-usage: when run on docker containers where size of /dev/shm
	# partition < 64MB which causes OOM failure for chromium compositor that uses the partition for shared memory
	LINUX_EXTRA_ARGS=(--disable-dev-shm-usage)
fi

# Unit Tests
if [[ "$OSTYPE" == darwin* ]]; then
	ulimit -n 4096 ; \
		ELECTRON_ENABLE_LOGGING=1 \
		"$CODE" \
		test/unit/electron/index.js --crash-reporter-directory="$VSCODECRASHDIR" "$@"
else
		ELECTRON_ENABLE_LOGGING=1 \
		"$CODE" \
		test/unit/electron/index.js --crash-reporter-directory="$VSCODECRASHDIR" "${LINUX_EXTRA_ARGS[@]}" "$@"
fi
