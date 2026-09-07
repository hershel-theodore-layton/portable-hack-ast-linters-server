/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */
namespace HTL\PhaLintersServer;

use namespace HH\Lib\File;
use namespace HTL\{Pha, PhaLinters};

async function sign_file_async(string $path)[defaults]: Awaitable<void> {
  $file = File\open_read_write($path);
  using $file->closeWhenDisposed();
  using $file->tryLockx(File\LockType::EXCLUSIVE);
  $source = await $file->readAllAsync();
  list($script, $_) = Pha\parse($source, Pha\create_context());
  $index = Pha\create_syntax_kind_index($script);
  $pragmas = Pha\create_pragma_map($script, $index);
  $signed = PhaLinters\Support\insert_digest($script, $pragmas);
  $file->seek(0);
  $file->truncate();
  await $file->writeAllAsync($signed);
}
