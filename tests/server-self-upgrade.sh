#!/bin/sh
# portable-hack-ast-linters-server is MIT licensed, see /LICENSE.
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"
launcher="$project_root/bin/pha-linters-server.sh"
test_dir=$(mktemp -d)
export TMPDIR="$test_dir"
server_pid=
cleanup() {
  if [ -n "$server_pid" ]; then
    kill -INT "$server_pid" 2>/dev/null || true
  fi
  rm -rf "$test_dir"
}
trap cleanup 0
trap 'exit 1' HUP INT TERM
mkdir -p "$test_dir/project/src"
touch "$test_dir/project/.hhconfig"
cat > "$test_dir/project/src/example.hack" <<'HACK'
/** Server upgrade test is MIT licensed. */
namespace SelfUpgradeTest;

function example()[]: string {
  return "double quoted";
}
HACK
cd "$test_dir/project"
if [ -n "${SERVER_TEST_PORT:-}" ]; then
  port=$SERVER_TEST_PORT
else
  cat > "$test_dir/port.hack" <<'HACK'
<<__EntryPoint>>
function choose_port()[defaults]: void {
  $error_number = 0;
  $error_message = '';
  $socket = \stream_socket_server(
    'tcp://127.0.0.1:0',
    inout $error_number,
    inout $error_message,
  );
  invariant($socket !== false, 'Could not allocate a test port.');
  $address = \stream_socket_get_name($socket, false) as string;
  echo \substr($address, \strrpos($address, ':') + 1);
}
HACK
  port=$(hhvm -dhhvm.jit=0 "$test_dir/port.hack")
fi
start_server() {
  if ! timeout 60 sh "$launcher" -e -d -p "$port" > "$test_dir/server.log" 2>&1; then
    cat "$test_dir/server.log" >&2
    exit 1
  fi
  reply=$(curl --noproxy '*' --fail --silent --max-time 5 \
    "http://127.0.0.1:$port/?__hack_compiler_handshake=test")
  case "$reply" in
    hack-compiler/1:test:*) ;;
    *) echo "Unexpected handshake: $reply" >&2; exit 1 ;;
  esac
  server_pid=${reply##*:}
  case "$server_pid" in
    ''|*[!0-9]*) echo 'Invalid server PID' >&2; exit 1 ;;
  esac
  test "$server_pid" -gt 1
  test -d "$test_dir/hack-compiler"
  test -z "$(find "$test_dir/hack-compiler" -mindepth 1 -print -quit)"
  test "$(curl --noproxy '*' --fail --silent --max-time 5 \
    "http://127.0.0.1:$port/?action=identify-yourself")" = 'HTL\PhaLintersServer'
  test "$(curl --noproxy '*' --fail --silent --max-time 5 \
    "http://127.0.0.1:$port/?action=lint-all&format=vscode-json")" != '[]'
  curl --noproxy '*' --fail --silent --max-time 5 \
    "http://127.0.0.1:$port/?action=lint-all&format=text" > "$test_dir/lint.txt"
  grep -q 'src/example.hack' "$test_dir/lint.txt"
  grep -q 'prefer_single_quoted_string_literals' "$test_dir/lint.txt"
}

start_server
previous_pid=$server_pid
start_server
test "$server_pid" != "$previous_pid"
echo 'Server self-upgrade checks passed.'
