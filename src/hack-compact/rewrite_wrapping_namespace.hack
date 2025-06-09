/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */
namespace HTL\PhaLintersServer\_Private;

use namespace HH\Lib\{C, Str};
use namespace HTL\Pha;

function rewrite_with_wrapping_namespace(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  ?string $wrapping_namespace,
)[]: string {
  if ($wrapping_namespace is null) {
    return Pha\node_get_code($script, Pha\SCRIPT_NODE);
  }

  return
    Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_NAMESPACE_DECLARATION)
    |> C\onlyx($$)
    |> Pha\patch_node($$, '', shape('trivia' => Pha\RetainTrivia::BOTH))
    |> Pha\patches($script, $$)
    |> Pha\patches_apply($$)
    |> Str\format(
      "namespace %s {\n%s\n}",
      $wrapping_namespace,
      Str\trim($$, "\n"),
    );
}
