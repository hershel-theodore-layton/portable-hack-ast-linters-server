/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */
namespace HTL\PhaLintersServer;

use namespace HH\Lib\Vec;
use namespace HTL\{Pha, PhaLinters};

function lint_hack_code(
  string $code,
  inout Pha\Context $ctx,
  vec<LintFunction> $lint_functions,
)[]: vec<PhaLinters\LintError> {
  list($script, $ctx) = Pha\parse($code, $ctx);
  $syntax_index = Pha\create_syntax_kind_index($script);
  $token_index = Pha\create_token_kind_index($script);
  $resolver = Pha\create_name_resolver($script, $syntax_index, $token_index);
  $pragma_map = Pha\create_pragma_map($script, $syntax_index);

  return Vec\map(
    $lint_functions,
    $l ==> $l($script, $syntax_index, $token_index, $resolver, $pragma_map),
  )
    |> Vec\flatten($$);
}
