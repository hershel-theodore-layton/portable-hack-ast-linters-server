/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */
namespace HTL\PhaLintersServer;

use namespace HH\Lib\Vec;
use namespace HTL\{Pha, PhaLinters};
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
        'severity' => 2,
        'path' => $path,
        'message' => $e->getLinterNameWithoutNamespaceAndLinter(),
        'range' => to_vscode_range($e->getPosition()),
        'source' => 'Portable Hack AST Linters Server',
        'relatedInformation' => vec[shape(
          'location' => shape(
            'range' => to_vscode_range($e->getPosition()),
          ),
          'message' => $e->getDescription(),
        )],
        'autofix' => $e->getPatches()
          |> $$ is null
            ? vec[]
            : Pha\_Private\patch_set_reveal($$)->getReplacements()
          |> Vec\map(
            $$,
            $r ==> shape(
              'range' => to_vscode_range($r->getPosition()),
              'replaceWith' => $r->getText(),
            ),
          ),
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
