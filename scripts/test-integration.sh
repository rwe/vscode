#!/usr/bin/env bash
set -e

if [[ "$OSTYPE" == darwin* ]]; then
	realpath() { [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"; }
	ROOT="$(dirname "$(dirname "$(realpath "$0")")")"
else
	ROOT="$(dirname "$(dirname "$(readlink -f "$0")")")"
	# --disable-dev-shm-usage: when run on docker containers where size of /dev/shm
	# partition < 64MB which causes OOM failure for chromium compositor that uses the partition for shared memory
	LINUX_EXTRA_ARGS=(--disable-dev-shm-usage)
fi

tmp_dirs=()
cleanup_tmp_dirs() {
	if [ ${#tmp_dirs[@]} != 0 ]; then
		rm -rf "${tmp_dirs[@]}"
	fi
}
trap cleanup_tmp_dirs EXIT

VSCODEUSERDATADIR="$(mktemp -d 2>/dev/null)"
tmp_dirs+=("${VSCODEUSERDATADIR}")

VSCODECRASHDIR="$ROOT/.build/crashes"
VSCODELOGSDIR="$ROOT/.build/logs/integration-tests"

cd "$ROOT"

# Figure out which Electron to use for running tests
if [ -z "$INTEGRATION_TEST_ELECTRON_PATH" ]
then
	INTEGRATION_TEST_ELECTRON_PATH='./scripts/code.sh'

	echo 'Running integration tests out of sources.'
else
	export VSCODE_CLI=1
	export ELECTRON_ENABLE_LOGGING=1

	echo "Running integration tests with '$INTEGRATION_TEST_ELECTRON_PATH' as build."
fi

echo "Storing crash reports into '$VSCODECRASHDIR'."
echo "Storing log files into '$VSCODELOGSDIR'."


# Tests standalone (AMD)

echo
echo '### node.js integration tests'
echo
# The following glob is intentionally literal.
./scripts/test.sh --runGlob '**/*.integrationTest.js' "$@"


# Tests in the extension host

API_TESTS_EXTRA_ARGS=(
	--disable-telemetry
	--skip-welcome
	--skip-release-notes
	--crash-reporter-directory="$VSCODECRASHDIR"
	--logsPath="$VSCODELOGSDIR"
	--no-cached-data
	--disable-updates
	--disable-keytar
	--disable-extensions
	--disable-workspace-trust
	--user-data-dir="$VSCODEUSERDATADIR"
)

if [ -z "$INTEGRATION_TEST_APP_NAME" ]; then
	kill_app() { true; }
else
	kill_app() { killall "$INTEGRATION_TEST_APP_NAME" || true; }
fi

echo
echo '### API tests (folder)'
echo
"$INTEGRATION_TEST_ELECTRON_PATH" "${LINUX_EXTRA_ARGS[@]}" "$ROOT/extensions/vscode-api-tests/testWorkspace" --enable-proposed-api=vscode.vscode-api-tests --extensionDevelopmentPath="$ROOT/extensions/vscode-api-tests" --extensionTestsPath="$ROOT/extensions/vscode-api-tests/out/singlefolder-tests" "${API_TESTS_EXTRA_ARGS[@]}"
kill_app

echo
echo '### API tests (workspace)'
echo
"$INTEGRATION_TEST_ELECTRON_PATH" "${LINUX_EXTRA_ARGS[@]}" "$ROOT/extensions/vscode-api-tests/testworkspace.code-workspace" --enable-proposed-api=vscode.vscode-api-tests --extensionDevelopmentPath="$ROOT/extensions/vscode-api-tests" --extensionTestsPath="$ROOT/extensions/vscode-api-tests/out/workspace-tests" "${API_TESTS_EXTRA_ARGS[@]}"
kill_app

echo
echo '### Colorize tests'
echo
"$INTEGRATION_TEST_ELECTRON_PATH" "${LINUX_EXTRA_ARGS[@]}" "$ROOT/extensions/vscode-colorize-tests/test" --extensionDevelopmentPath="$ROOT/extensions/vscode-colorize-tests" --extensionTestsPath="$ROOT/extensions/vscode-colorize-tests/out" "${API_TESTS_EXTRA_ARGS[@]}"
kill_app

echo
echo '### TypeScript tests'
echo
"$INTEGRATION_TEST_ELECTRON_PATH" "${LINUX_EXTRA_ARGS[@]}" "$ROOT/extensions/typescript-language-features/test-workspace" --extensionDevelopmentPath="$ROOT/extensions/typescript-language-features" --extensionTestsPath="$ROOT/extensions/typescript-language-features/out/test/unit" "${API_TESTS_EXTRA_ARGS[@]}"
kill_app

echo
echo '### Markdown tests'
echo
"$INTEGRATION_TEST_ELECTRON_PATH" "${LINUX_EXTRA_ARGS[@]}" "$ROOT/extensions/markdown-language-features/test-workspace" --extensionDevelopmentPath="$ROOT/extensions/markdown-language-features" --extensionTestsPath="$ROOT/extensions/markdown-language-features/out/test" "${API_TESTS_EXTRA_ARGS[@]}"
kill_app

echo
echo '### Emmet tests'
echo
"$INTEGRATION_TEST_ELECTRON_PATH" "${LINUX_EXTRA_ARGS[@]}" "$ROOT/extensions/emmet/test-workspace" --extensionDevelopmentPath="$ROOT/extensions/emmet" --extensionTestsPath="$ROOT/extensions/emmet/out/test" "${API_TESTS_EXTRA_ARGS[@]}"
kill_app

git_tmp_dir="$(mktemp -d 2>/dev/null)"
tmp_dirs+=("${git_tmp_dir}")
echo
echo '### Git tests'
echo
"$INTEGRATION_TEST_ELECTRON_PATH" "${LINUX_EXTRA_ARGS[@]}" "${git_tmp_dir}" --extensionDevelopmentPath="$ROOT/extensions/git" --extensionTestsPath="$ROOT/extensions/git/out/test" "${API_TESTS_EXTRA_ARGS[@]}"
kill_app

ipynb_tmp_dir="$(mktemp -d 2>/dev/null)"
tmp_dirs+=("${ipynb_tmp_dir}")
echo
echo '### Ipynb tests'
echo
"$INTEGRATION_TEST_ELECTRON_PATH" "${LINUX_EXTRA_ARGS[@]}" "${ipynb_tmp_dir}" --extensionDevelopmentPath="$ROOT/extensions/ipynb" --extensionTestsPath="$ROOT/extensions/ipynb/out/test" "${API_TESTS_EXTRA_ARGS[@]}"
kill_app

conf_tmp_dir="$(mktemp -d 2>/dev/null)"
tmp_dirs+=("${conf_tmp_dir}")
echo
echo '### Configuration editing tests'
echo
"$INTEGRATION_TEST_ELECTRON_PATH" "${LINUX_EXTRA_ARGS[@]}" "${conf_tmp_dir}" --extensionDevelopmentPath="$ROOT/extensions/configuration-editing" --extensionTestsPath="$ROOT/extensions/configuration-editing/out/test" "${API_TESTS_EXTRA_ARGS[@]}"
kill_app


# Tests standalone (CommonJS)

echo
echo '### CSS tests'
echo
cd "$ROOT/extensions/css-language-features/server" && "$ROOT/scripts/node-electron.sh" test/index.js

echo
echo '### HTML tests'
echo
cd "$ROOT/extensions/html-language-features/server" && "$ROOT/scripts/node-electron.sh" test/index.js
