/** portable-hack-ast-linters-monolithic-checker is MIT licensed, see /LICENSE. */
namespace HTL\PortableHackAstLintersMonolithicChecker;

use namespace HTL\{Pha, PhaLinters};

type LintFunction = (function(
  Pha\Script,
  Pha\SyntaxIndex,
  Pha\TokenIndex,
  Pha\Resolver,
  Pha\PragmaMap,
)[]: vec<PhaLinters\LintError>);
