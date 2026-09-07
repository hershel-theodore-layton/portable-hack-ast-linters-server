/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */
namespace HTL\PhaLintersServer;

use namespace HH\Lib\File;
use function escapeshellarg, exec;

/**
 * Prefer `HTL\PhaLinters\Support\insert_digest`, which is faster.
 * This function exists as a kludge to allow projects to sign files
 * without depending on `HTL\PhaLinters\Support\insert_digest` directly.
 * This would create circular dependencies.
 *
 * @throws InvariantException on failure
 */
async function hackfmt_and_sign_hack_source_do_not_use_async(
  string $source,
)[defaults]: Awaitable<string> {
  using $input = File\temporary_file();
  using $output = File\temporary_file();
  $input_file = $input->getHandle();
  $output_file = $output->getHandle();
  await $input_file->writeAllAsync($source);

  $command_output = vec[];
  $status = 0;
  exec(
    'hackfmt < '.
    escapeshellarg($input_file->getPath()).
    ' > '.
    escapeshellarg($output_file->getPath()),
    inout $command_output,
    inout $status,
  );
  invariant($status === 0, 'Could not format generated Hack source');

  exec(
    escapeshellarg(__DIR__.'/../bin/pha-sign-hack-source.sh').
    ' '.
    escapeshellarg($output_file->getPath()),
    inout $command_output,
    inout $status,
  );
  invariant($status === 0, 'Could not sign generated Hack source');

  return await $output_file->readAllAsync();
}
