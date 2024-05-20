/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */
namespace HTL\PhaLintersServer;

use namespace HH\Lib\{C, Dict, File};
use namespace HTL\{Pha, PhaLinters};

async function lint_all_files_async(
  string $project_root,
  vec<LintFunction> $lint_functions,
  keyset<string> $base_directories,
  int $directory_search_depth = 60,
): Awaitable<dict<string, vec<PhaLinters\LintError>>> {
  $paths = all_files($project_root, $base_directories, $directory_search_depth);
  $files = await Dict\map_async($paths, async $p ==> {
    $file = File\open_read_only($p);
    using $file->closeWhenDisposed();
    using $file->tryLockx(File\LockType::SHARED);
    return shape('path' => $p, 'contents' => await $file->readAllAsync());
  });

  $ctx = Pha\create_context();
  $out = dict[];

  foreach ($files as $file) {
    $contents = $file['contents'];
    $errors = lint_hack_code($contents, inout $ctx, $lint_functions);
    if (!C\is_empty($errors)) {
      $out[$file['path']] = $errors;
    }
  }

  return $out;
}
