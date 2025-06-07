/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */
namespace HTL\PhaLintersServer;

use namespace HH;
use namespace HH\Lib\{C, IO, Str, Vec};
use namespace HTL\Pha;
use function dirname, file_exists;

<<__EntryPoint>>
async function main_async()[defaults]: Awaitable<void> {
  if (file_exists(dirname(__DIR__).'/.hhvmconfig.hdf')) {
    $project_root = dirname(__DIR__);
  } else {
    $project_root =
      dirname(__DIR__) |> dirname($$) |> dirname($$) |> dirname($$);
  }

  $input = IO\request_input();
  $output = IO\request_output();

  $license_header = await snif_license_header_async($project_root) ??
    '/** This project is unlicensed. No license has been granted. */';

  $lint_functions = all_linters($license_header);

  $request = HH\global_get('_REQUEST') as ?dict<_, _>;
  $argv = HH\global_get('argv') as ?vec<_>;

  $action = idx($request, 'action') ?? idx($argv, 1)
    |> $$ ?as string ?? 'lint-all';

  $format = idx($request, 'format') ?? idx($argv, 2)
    |> $$ ?as string ?? 'text';

  $directories = idx($request, 'directories') ?? idx($argv, 3)
    |> $$ ?as string ?? 'src,tests'
    |> Str\split($$, ',');

  switch ($action) {
    case 'identify-yourself':
      await $output->writeAllAsync('HTL\PhaLintersServer');
      return;
    case 'lint-all':
      $lint_errors = await lint_all_files_async(
        $project_root,
        $lint_functions,
        keyset($directories),
      );
      break;
    case 'lint-input':
      $code = await $input->readAllAsync();
      $ctx = Pha\create_context();
      $lint_errors = lint_hack_code($code, inout $ctx, $lint_functions)
        |> C\is_empty($$) ? dict[] : dict['' => $$];
      break;
    default:
      await $output->writeAllAsync(
        'Invalid mode argument, expected one of [lint-all, lint-input]',
      );
      exit(1);
  }

  switch ($format) {
    case 'text':
      await $output->writeAllAsync(
        encode_errors_as_human_readable_text($lint_errors),
      );
      exit(C\is_empty(Vec\flatten($lint_errors)) ? 0 : 1);

    case 'vscode-json':
      await $output->writeAllAsync(
        encode_errors_as_vscode_compatible_json($lint_errors),
      );
      exit(C\is_empty(Vec\flatten($lint_errors)) ? 0 : 1);

    default:
      await $output->writeAllAsync(
        'Invalid format argument, expected one of [text, vscode-json]',
      );
      exit(1);
  }
}
