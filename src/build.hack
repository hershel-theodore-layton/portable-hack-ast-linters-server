/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */
namespace HTL\PhaLintersServer;

use namespace HH\Lib\{File, Str, Vec};
use namespace HTL\HH4Shim;
use type RecursiveDirectoryIterator, RecursiveIteratorIterator, SplFileInfo;

<<__EntryPoint>>
async function build_async()[defaults]: Awaitable<void> {
  $paths = RecursiveDirectoryIterator::SKIP_DOTS
    |> new RecursiveDirectoryIterator(\realpath(__DIR__.'/../'), $$)
    |> new RecursiveIteratorIterator($$)
    |> Vec\filter(
      $$,
      $f ==> HH4Shim\to_mixed($f) as SplFileInfo->getExtension() === 'hack',
    )
    |> Vec\map($$, $f ==> $f->getPathname());

  $files = await Vec\map_async($paths, async $path ==> {
    $file = File\open_read_only($path);
    using $file->closeWhenDisposed();
    using $file->tryLockx(File\LockType::SHARED);
    $source_text = await $file->readAllAsync();
    return _Private\SourceFile::fromPathAndSourceText(
      Str\strip_prefix($path, '/mnt/project/'),
      $source_text,
    );
  })
    |> Vec\filter(
      $$,
      $f ==> (
        !Str\contains($f->getSourceText(), '__EntryPoint') ||
        $f->getPath() === 'src/main.hack'
      ) &&
        !Str\contains($f->getPath(), 'portable-hack-ast/bin/') &&
        !Str\contains($f->getPath(), 'src/hack-compact/'),
    )
    |> Vec\sort_by($$, $f ==> $f->getPath());

  echo _Private\hack_compact($files);
}
