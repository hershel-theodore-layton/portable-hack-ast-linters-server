/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */
namespace HTL\PhaLintersServer;

use namespace HTL\{Pha, PhaLinters};

type LintFunction = (function(
  Pha\Script,
  Pha\SyntaxIndex,
  Pha\TokenIndex,
  Pha\Resolver,
  Pha\PragmaMap,
)[]: vec<PhaLinters\LintError>);
