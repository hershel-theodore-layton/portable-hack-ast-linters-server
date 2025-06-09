/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */
namespace HTL\PhaLintersServer\_Private;

use namespace HTL\Pha;

/**
 * Files that contain `namespace Example;` must be transformed from into
 * ```
 * namespace Example {
 * // code goes here
 * }
 * ```
 * 
 * If the file already used the `namespace Example {}` style, nothing needs
 * to happen to make this file compact-ready.
 */
function get_wrapping_namespace(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
)[]: ?string {
  $is_namespace_empty_body =
    Pha\create_syntax_matcher($script, Pha\KIND_NAMESPACE_EMPTY_BODY);

  $get_namespace_body =
    Pha\create_member_accessor($script, Pha\MEMBER_NAMESPACE_BODY);
  $get_namespace_header =
    Pha\create_member_accessor($script, Pha\MEMBER_NAMESPACE_HEADER)
    |> Pha\returns_syntax($$);
  $get_namespace_name =
    Pha\create_member_accessor($script, Pha\MEMBER_NAMESPACE_NAME);

  $wrap_with = null;

  foreach (
    Pha\index_get_nodes_by_kind(
      $syntax_index,
      Pha\KIND_NAMESPACE_DECLARATION,
    ) as $child
  ) {
    $is_file_scoped = $is_namespace_empty_body($get_namespace_body($child));
    invariant(
      $wrap_with is null || $is_file_scoped,
      'This file contains two namespaces. '.
      'Hack-compact treats `namespace %s;` as a file-scoped namespace and '.
      'does not support multiple of such namespaces in one file.',
      $wrap_with,
    );

    if ($is_file_scoped) {
      $wrap_with = $get_namespace_header($child)
        |> $get_namespace_name($$)
        |> Pha\node_get_code_without_leading_or_trailing_trivia($script, $$);
    } else {
      $wrap_with = '';
    }
  }

  return $wrap_with === '' ? null : $wrap_with;
}
