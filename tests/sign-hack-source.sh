#!/bin/sh
# portable-hack-ast-linters-server is MIT licensed, see /LICENSE.
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
signer="$project_root/bin/pha-sign-hack-source.sh"
bundle="$project_root/bin/portable-hack-ast-linters-server-bundled.resource"
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
cat > "$test_dir/generated source.hack" <<'HACK'
/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */
namespace SigningTest;

use type HTL\Pragma\Pragmas;

<<file: Pragmas(vec['PhaLinters', 'digest:'])>>

function example()[]: string {
  return \strval(42);
}
HACK
cp "$test_dir/generated source.hack" "$test_dir/unsigned.hack"
"$signer" "$test_dir/generated source.hack"
expected=$(sha1sum "$test_dir/unsigned.hack" | cut -c1-20)
grep -q "digest:$expected" "$test_dir/generated source.hack"
hhvm "$bundle" lint-input text < "$test_dir/generated source.hack"
cp "$test_dir/generated source.hack" "$test_dir/signed.hack"
if "$signer" "$test_dir/generated source.hack" > /dev/null 2>&1; then
  echo 'Signing a nonempty digest should fail' >&2
  exit 1
fi
cmp "$test_dir/signed.hack" "$test_dir/generated source.hack"
printf '\n// Manual edit\n' >> "$test_dir/generated source.hack"
if hhvm "$bundle" lint-input text < "$test_dir/generated source.hack" > "$test_dir/lint.txt"; then
  echo 'A manual edit should fail lint' >&2
  exit 1
fi
grep -q 'generated_file_may_not_be_modified_manually' "$test_dir/lint.txt"
printf 'namespace NoDigest;\n' > "$test_dir/no-digest.hack"
cp "$test_dir/no-digest.hack" "$test_dir/no-digest-original.hack"
if "$signer" "$test_dir/no-digest.hack" > /dev/null 2>&1; then
  echo 'Signing without a digest pragma should fail' >&2
  exit 1
fi
cmp "$test_dir/no-digest-original.hack" "$test_dir/no-digest.hack"
if "$signer" > /dev/null 2>&1; then
  echo 'Missing filename should fail' >&2
  exit 1
fi
echo 'Signing checks passed.'
