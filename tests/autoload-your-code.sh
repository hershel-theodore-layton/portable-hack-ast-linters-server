#!/bin/sh
# portable-hack-ast-linters-server is MIT licensed, see /LICENSE.
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
bundle="$project_root/bin/portable-hack-ast-linters-server-bundled.resource"
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
cat > "$test_dir/inclusions.hack" <<'HACK'
/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */
namespace AutoloadTest;

function bootstrap()[defaults]: void {
  require_once 'vendor/autoload.hack';
}
HACK
if hhvm "$bundle" lint-input text < "$test_dir/inclusions.hack" > "$test_dir/lint.txt"; then
  echo 'An inclusion directive should fail lint' >&2
  exit 1
fi
grep -q 'autoload_your_code' "$test_dir/lint.txt"
cat > "$test_dir/bootstrap.hack" <<'HACK'
/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */
namespace AutoloadTest;

use type HTL\Pragma\Pragmas;

<<file: Pragmas(vec['PhaLinters', 'fixme:autoload_your_code'])>>

function bootstrap()[defaults]: void {
  require_once 'vendor/autoload.hack';
}
HACK
hhvm "$bundle" lint-input text < "$test_dir/bootstrap.hack"
echo 'Autoload suppression checks passed.'
