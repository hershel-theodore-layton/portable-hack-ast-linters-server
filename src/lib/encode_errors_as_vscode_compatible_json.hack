/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */
namespace HTL\PhaLintersServer;

use namespace HH\Lib\Vec;
use namespace HTL\PhaLinters;
use const JSON_UNESCAPED_SLASHES, JSON_UNESCAPED_UNICODE;

function encode_errors_as_vscode_compatible_json(
  dict<string, vec<PhaLinters\LintError>> $lint_errors,
)[]: string {
  $_json_encode_error = null;
  return Vec\map_with_key(
    $lint_errors,
    ($path, $errs) ==> Vec\map(
      $errs,
      $e ==> shape(
        'start' => shape(
          'line' => $e->getPosition()->getStartLine(),
          'character' => $e->getPosition()->getStartColumn(),
        ),
        'end' => shape(
          'line' => $e->getPosition()->getEndLine(),
          'character' => $e->getPosition()->getEndColumn(),
        ),
      )
        |> shape(
          'severity' => 2,
          'path' => $path,
          'message' => $e->getLinterNameWithoutNamespaceAndLinter(),
          'range' => $$,
          'source' => 'Portable Hack AST Linters Server',
          'relatedInformation' => vec[shape(
            'location' => shape(
              'range' => $$,
            ),
            'message' => $e->getDescription(),
          )],
        ),
    ),
  )
    |> Vec\flatten($$)
    |> \json_encode_pure(
      $$,
      inout $_json_encode_error,
      JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE,
    );
}
