/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */
namespace HTL\PhaLintersServer\_Private;

use namespace HH\Lib\{Str, Vec};
use namespace HTL\Pha;

function hack_compact(vec<SourceFile> $source_files)[]: string {
  $parsed_files = vec[];
  $ctx = Pha\create_context();

  foreach ($source_files as $source_file) {
    list($script, $ctx) = Pha\parse($source_file->getSourceText(), $ctx);
    $parsed_files[] = parse_file($source_file->getPath(), $script);
  }

  return Vec\map(
    $parsed_files,
    $parsed_file ==> Str\format(
      "///// %s /////\n%s",
      $parsed_file->getPath(),
      $parsed_file->getSourceText(),
    ),
  )
    |> Str\join($$, "\n");
}

function parse_file(string $source_path, Pha\Script $script)[]: SourceFile {
  $syntax_index = Pha\create_syntax_kind_index($script);
  $source_text = rewrite_with_wrapping_namespace(
    $script,
    $syntax_index,
    get_wrapping_namespace($script, $syntax_index),
  );

  return SourceFile::fromPathAndSourceText($source_path, $source_text);
}
