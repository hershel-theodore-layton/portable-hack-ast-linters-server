/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */
namespace HTL\PhaLintersServer;

use namespace HH\Lib\{Keyset, Str, Vec};
use function glob;

function all_files(
  string $project_root,
  keyset<string> $base_directories,
  int $directory_search_depth,
): keyset<string> {
  return Vec\map(
    $base_directories,
    $dir ==> Vec\range(0, $directory_search_depth)
      |> Vec\map(
        $$,
        $stars ==>
          glob($project_root.'/'.$dir.Str\repeat('/*', $stars).'/*.hack'),
      ),
  )
    |> Vec\flatten($$)
    |> Vec\flatten($$)
    |> Keyset\sort($$);
}
