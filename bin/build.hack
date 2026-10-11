#!/usr/bin/env hhvm
/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */
namespace HTL\PhaLintersServer;

use namespace HTL\{HH4Shim, HackCompiler};
use function chdir, chmod, dirname;

<<__EntryPoint>>
async function build_async()[defaults]: Awaitable<void> {
  chdir(__DIR__.'/..');
  $root = HH4Shim\to_mixed(dirname(__DIR__)) as string;
  $resource = await HackCompiler\compile_roots_async(
    vec[$root.'/src', $root.'/vendor'],
    vec[
      $root.'/vendor/hershel-theodore-layton/hack-compiler',
      $root.'/vendor/hershel-theodore-layton/portable-hack-ast/bin',
    ],
    HackCompiler\CompileMode::RESOURCE,
  );
  $launcher = HackCompiler\wrap_resource(
    $resource,
    HackCompiler\CompileMode::SERVER_OBSOLETE,
  );
  await HackCompiler\write_source_async(
    $resource,
    $root.'/bin/portable-hack-ast-linters-server-bundled.resource',
    shape('format' => false, 'sign' => false),
  );
  await HackCompiler\write_source_async(
    $launcher,
    $root.'/bin/pha-linters-server.sh',
    shape('format' => false, 'sign' => false),
  );
  chmod($root.'/bin/pha-linters-server.sh', 0755);
}
