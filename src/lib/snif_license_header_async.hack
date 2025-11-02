/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */
namespace HTL\PhaLintersServer;

use namespace HH\Lib\{C, File, IO, Vec};
use function glob, is_file, is_readable;

async function snif_license_header_async(
  string $project_root,
)[defaults]: Awaitable<?string> {
  $path = C\find<string>(
    Vec\concat(
      glob($project_root.'/src/*.hack') as vec<_>,
      glob($project_root.'/src/*/*.hack') as vec<_>,
    )
      |> Vec\map($$, $x ==> $x as string),
    $path ==> is_file($path) && is_readable($path),
  );

  if ($path is null) {
    return null;
  }

  $file = File\open_read_only($path);
  using $file->closeWhenDisposed();
  using $file->tryLockx(File\LockType::SHARED);

  $br = new IO\BufferedReader($file);
  return await $br->readUntilAsync('*/');
}
