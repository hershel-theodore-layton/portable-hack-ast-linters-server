#!/bin/sh
# portable-hack-ast-linters-server is MIT licensed, see /LICENSE.
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
launcher="$project_root/bin/pha-linters-server.sh"
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
mkdir "$test_dir/stubs" "$test_dir/project"
export LAUNCHER_TEST_LOG="$test_dir/calls"
cat > "$test_dir/stubs/hhvm" <<'STUB'
#!/bin/sh
printf 'hhvm %s\n' "$*" >> "$LAUNCHER_TEST_LOG"
if [ "$1" = --hphp ]; then
  mkdir -p "$4"
  touch "$4/hhvm.hhbc"
fi
STUB
cat > "$test_dir/stubs/find" <<'STUB'
#!/bin/sh
printf 'find\n' >> "$LAUNCHER_TEST_LOG"
printf './portable-hack-ast-linters-server-bundled.resource\n'
STUB
chmod +x "$test_dir/stubs/hhvm" "$test_dir/stubs/find"
PATH="$test_dir/stubs:$PATH"
export PATH
cd "$test_dir/project"
touch .hhconfig 'bundle with spaces.resource'

assert_no_setup() {
  test ! -e "$LAUNCHER_TEST_LOG"
  test ! -e .var
  test ! -e .vscode
}

expect_failure() {
  if sh "$launcher" "$@" > "$test_dir/stdout" 2> "$test_dir/stderr"; then
    echo "Expected failure for: $*" >&2
    exit 1
  fi
  test -s "$test_dir/stderr"
  test ! -s "$test_dir/stdout"
  assert_no_setup
}

expect_failure -s -z -b 'bundle with spaces.resource'
grep -q 'Unknown option: -z' "$test_dir/stderr"
for flag in -p -b -r; do
  expect_failure "$flag"
  grep -q 'requires an argument' "$test_dir/stderr"
done
expect_failure -s -b 'bundle with spaces.resource' unexpected
expect_failure -- unexpected
for port in '' 0 65536 -1 abc 1.5 ' 80' 999999999999999999999999; do
  expect_failure -s -b 'bundle with spaces.resource' -p "$port"
  grep -q 'Port must be an integer from 1 to 65535' "$test_dir/stderr"
done
expect_failure -s -b missing.resource
expect_failure -s -r ''
expect_failure -s -b .
sh "$launcher" -h > "$test_dir/stdout" 2> "$test_dir/stderr"
grep -q 'Supported options:' "$test_dir/stdout"
test ! -s "$test_dir/stderr"
assert_no_setup

for flag in -b -r; do
  for port in 1 10641 65535; do
    sh "$launcher" "$flag" 'bundle with spaces.resource' -p "$port" > "$test_dir/stdout" 2> "$test_dir/stderr"
    grep -q "hhvm -m server -p $port " "$LAUNCHER_TEST_LOG"
    test "$(grep -c '^hhvm ' "$LAUNCHER_TEST_LOG")" -eq 2
    test "$(grep -c '^find' "$LAUNCHER_TEST_LOG")" -eq 0
    test ! -s "$test_dir/stderr"
    rm -rf .var "$LAUNCHER_TEST_LOG"
  done
done

touch portable-hack-ast-linters-server-bundled.resource
sh "$launcher" -t > "$test_dir/stdout" 2> "$test_dir/stderr"
test "$(grep -c '^find' "$LAUNCHER_TEST_LOG")" -eq 1
grep -q 'hhvm -m server -p 10641 ' "$LAUNCHER_TEST_LOG"
test ! -s "$test_dir/stderr"
echo 'Launcher option checks passed (stubbed HHVM).'
