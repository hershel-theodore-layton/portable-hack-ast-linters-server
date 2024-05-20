/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */
namespace HTL\PhaLintersServer;

use namespace HH\Lib\{C, Str, Vec};
use namespace HTL\PhaLinters;

function encode_errors_as_human_readable_text(
  dict<string, vec<PhaLinters\LintError>> $lint_errors,
)[]: string {
  if (C\is_empty($lint_errors)) {
    return "No errors!\n";
  }

  return Vec\map_with_key(
    $lint_errors,
    ($path, $errors) ==> Vec\map($errors, $e ==> $e->toString().' of '.$path)
      |> Str\join($$, "\n\n"),
  )
    |> Str\join($$, "\n\n")."\n";
}
