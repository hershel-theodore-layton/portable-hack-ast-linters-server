/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */
namespace HTL\PhaLintersServer;

use namespace HTL\Pha;

function to_vscode_range(Pha\LineAndColumnNumbers $x)[]: shape(
  'start' => shape('line' => int, 'character' => int /*_*/),
  'end' => shape('line' => int, 'character' => int /*_*/),
  /*_*/
) {
  return shape(
    'start' => shape(
      'line' => $x->getStartLine(),
      'character' => $x->getStartColumn(),
    ),
    'end' => shape(
      'line' => $x->getEndLine(),
      'character' => $x->getEndColumn(),
    ),
  );
}
