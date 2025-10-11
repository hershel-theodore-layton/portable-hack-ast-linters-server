///// src/all_files.hack /////
namespace HTL\PhaLintersServer {
/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{Keyset, Str, Vec};
use function glob;

function all_files(
  string $project_root,
  keyset<string> $base_directories,
  int $directory_search_depth,
)[defaults]: keyset<string> {
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
}
///// src/all_linters.hack /////
namespace HTL\PhaLintersServer {
/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */


use namespace HTL\PhaLinters;

function all_linters(string $license_header)[]: vec<LintFunction> {
  $known_pragma_prefixes = keyset['PhaLinters'];

  $linters = vec[
    PhaLinters\async_function_and_method_linter<>,
    PhaLinters\camel_cased_methods_underscored_functions_linter<>,
    PhaLinters\concat_merge_or_union_expression_can_be_simplified_linter<>,
    PhaLinters\context_list_must_be_explicit_linter<>,
    PhaLinters\count_expression_can_be_simplified_linter<>,
    PhaLinters\dont_await_in_a_loop_linter<>,
    PhaLinters\dont_create_forwarding_lambdas_linter<>,
    PhaLinters\dont_discard_new_expressions_linter<>,
    PhaLinters\dont_use_asio_join_linter<>,
    PhaLinters\final_or_abstract_classes_linter<>,
    PhaLinters\generated_file_may_not_be_modified_manually_linter<>,
    PhaLinters\getter_method_could_have_a_context_list_linter<>,
    PhaLinters\group_use_statement_alphabetization_linter<>,
    PhaLinters\group_use_statements_linter<>,
    PhaLinters\lambda_parameter_list_parentheses_can_be_removed_linter<>,
    PhaLinters\must_use_braces_for_control_flow_linter<>,
    PhaLinters\namespace_private_symbol_linter<>,
    PhaLinters\namespace_private_use_clause_linter<>,
    PhaLinters\no_elseif_linter<>,
    PhaLinters\no_empty_statements_linter<>,
    PhaLinters\no_final_method_in_final_classes_linter<>,
    PhaLinters\no_newline_at_start_of_control_flow_block_linter<>,
    PhaLinters\no_php_equality_linter<>,
    PhaLinters\no_string_interpolation_linter<>,
    PhaLinters\pragma_could_not_be_parsed_linter<>,
    PhaLinters\prefer_lambdas_linter<>,
    PhaLinters\prefer_require_once_linter<>,
    PhaLinters\prefer_single_quoted_string_literals_linter<>,
    PhaLinters\shout_case_enum_members_linter<>,
    PhaLinters\solitary_escape_sequences_should_be_disambiguated_linter<>,
    PhaLinters\unreachable_code_linter<>,
    PhaLinters\unused_pipe_variable_linter<>,
    PhaLinters\unused_use_clause_linter<>,
    PhaLinters\unused_variable_linter<>,
    PhaLinters\use_statement_with_as_linter<>,
    PhaLinters\use_statement_with_leading_backslash_linter<>,
    PhaLinters\use_statement_without_kind_linter<>,
    PhaLinters\variable_name_must_be_lowercase_linter<>,
    PhaLinters\whitespace_linter<>,
  ];

  $linters[] = ($script, $_, $_, $_, $pragma_map) ==>
    PhaLinters\pragma_prefix_unknown_linter(
      $script,
      $pragma_map,
      $known_pragma_prefixes,
    );

  $linters[] = ($script, $_, $_, $_, $pragma_map) ==>
    PhaLinters\license_header_linter($script, $pragma_map, $license_header);

  $linters[] = ($script, $syntax_index, $_, $_, $pragma_map) ==>
    PhaLinters\shape_type_additional_field_intent_should_be_explicit_linter(
      $script,
      $syntax_index,
      $pragma_map,
      '/*_*/',
    );

  return $linters;
}
}
///// src/lib/LintFunction.hack /////
namespace HTL\PhaLintersServer {
/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */


use namespace HTL\{Pha, PhaLinters};

type LintFunction = (function(
  Pha\Script,
  Pha\SyntaxIndex,
  Pha\TokenIndex,
  Pha\Resolver,
  Pha\PragmaMap,
)[]: vec<PhaLinters\LintError>);
}
///// src/lib/encode_errors_as_human_readable_text.hack /////
namespace HTL\PhaLintersServer {
/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Str, Vec};
use namespace HTL\PhaLinters;

function encode_errors_as_human_readable_text(
  dict<string, vec<PhaLinters\LintError>> $lint_errors,
)[]: string {
  if (C\is_empty($lint_errors)) {
    return "No errors!\n";
  }

  $errors_remaining = Str\format(
    "%d lint-error%s remaining...\n",
    C\count($lint_errors),
    C\count($lint_errors) > 1 ? 's' : '',
  );

  return Vec\map_with_key(
    $lint_errors,
    ($path, $errors) ==> Vec\map($errors, $e ==> $e->toString().' of '.$path)
      |> Str\join($$, "\n\n"),
  )
    |> Str\join($$, "\n\n").$errors_remaining."\n";
}
}
///// src/lib/encode_errors_as_vscode_compatible_json.hack /////
namespace HTL\PhaLintersServer {
/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */


use namespace HH\Lib\Vec;
use namespace HTL\{Pha, PhaLinters};
use const JSON_UNESCAPED_SLASHES, JSON_UNESCAPED_UNICODE;

function encode_errors_as_vscode_compatible_json(
  dict<string, vec<PhaLinters\LintError>> $lint_errors,
)[]: string {
  $_json_encode_error = null;
  return Vec\map_with_key(
    $lint_errors,
    ($path, $errs) ==> Vec\map(
      $errs,
      $e ==> shape(
        'severity' => 2,
        'path' => $path,
        'message' => $e->getLinterNameWithoutNamespaceAndLinter(),
        'range' => to_vscode_range($e->getPosition()),
        'source' => 'Portable Hack AST Linters Server',
        'relatedInformation' => vec[shape(
          'location' => shape(
            'range' => to_vscode_range($e->getPosition()),
          ),
          'message' => $e->getDescription(),
        )],
        'autofix' => $e->getPatches()
          |> $$ is null
            ? vec[]
            : Pha\_Private\patch_set_reveal($$)->getReplacements()
          |> Vec\map(
            $$,
            $r ==> shape(
              'range' => to_vscode_range($r->getPosition()),
              'replaceWith' => $r->getText(),
            ),
          ),
      ),
    ),
  )
    |> Vec\flatten($$)
    |> \json_encode_pure(
      $$,
      inout $_json_encode_error,
      JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE,
    );
}
}
///// src/lib/lint_all_files.hack /////
namespace HTL\PhaLintersServer {
/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Dict, File};
use namespace HTL\{Pha, PhaLinters};

async function lint_all_files_async(
  string $project_root,
  vec<LintFunction> $lint_functions,
  keyset<string> $base_directories,
  int $directory_search_depth = 60,
)[defaults]: Awaitable<dict<string, vec<PhaLinters\LintError>>> {
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
}
///// src/lib/lint_hack_code.hack /////
namespace HTL\PhaLintersServer {
/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */


use namespace HH\Lib\Vec;
use namespace HTL\{Pha, PhaLinters};

function lint_hack_code(
  string $code,
  inout Pha\Context $ctx,
  vec<LintFunction> $lint_functions,
)[]: vec<PhaLinters\LintError> {
  list($script, $ctx) = Pha\parse($code, $ctx);
  $syntax_index = Pha\create_syntax_kind_index($script);
  $token_index = Pha\create_token_kind_index($script);
  $resolver = Pha\create_name_resolver($script, $syntax_index, $token_index);
  $pragma_map = Pha\create_pragma_map($script, $syntax_index);

  return Vec\map(
    $lint_functions,
    $l ==> $l($script, $syntax_index, $token_index, $resolver, $pragma_map),
  )
    |> Vec\flatten($$)
    |> Vec\filter($$, $e ==> !$e->isIgnored());
}
}
///// src/lib/snif_license_header_async.hack /////
namespace HTL\PhaLintersServer {
/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, File, IO, Vec};
use function glob, is_file, is_readable;

async function snif_license_header_async(
  string $project_root,
)[defaults]: Awaitable<?string> {
  $path = C\find<string>(
    Vec\concat(
      glob($project_root.'/src/*.hack'),
      glob($project_root.'/src/*/*.hack'),
    ),
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
}
///// src/lib/to_vscode_range.hack /////
namespace HTL\PhaLintersServer {
/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */


use namespace HTL\Pha;

function to_vscode_range(Pha\LineAndColumnNumbers $x)[]: shape(
  'start' => shape('line' => int, 'character' => int /*_*/),
  'end' => shape('line' => int, 'character' => int /*_*/),
  /*_*/
) {
  return shape(
    'start' => shape(
      'line' => $x->getStartLine(),
      'character' => $x->getStartColumn(),
    ),
    'end' => shape(
      'line' => $x->getEndLine(),
      'character' => $x->getEndColumn(),
    ),
  );
}
}
///// src/main.hack /////
namespace HTL\PhaLintersServer {
/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */


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
}
///// vendor/hershel-theodore-layton/portable-hack-ast-extras/src/PragmaMap.hack /////
namespace HTL\Pha {
/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */


use namespace HH\Lib\Vec;

final class PragmaMap {
  public function __construct(
    private vec<(Syntax, LineAndColumnNumbers, vec<string>)> $pragmas,
  )[] {}

  public function getOverlappingPragmas(
    LineAndColumnNumbers $target,
  )[]: vec<vec<string>> {
    return Vec\filter(
      $this->pragmas,
      $t ==> $target->getEndLine() >= $t[1]->getStartLine() &&
        $target->getStartLine() <= $t[1]->getEndLine(),
    )
      |> Vec\map($$, $t ==> $t[2]);
  }

  public function getAllPragmas(
  )[]: vec<(Syntax, LineAndColumnNumbers, vec<string>)> {
    return $this->pragmas;
  }
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-extras/src/_Private/NameResolver.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Str, Vec};
use namespace HTL\Pha;

final class NameResolver {
  /**
   * Generated by scanning public sources and printing distinct parent kinds.
   * Then, by reasoning about the ancestors, determine the kind.
   */
  private (function(Pha\Node)[]: bool)
    $isAsIsContext,
    $isFunctionContext,
    $isQualifiedName,
    $isTypeContext,
    $isValidName,
    $isXhp;

  public function __construct(
    Pha\Script $script,
    private vec<NamespaceResolution> $namespaceResolution,
    private dict<NodeId, string> $resolvedNames,
    private dict<string, string> $aliasedNamespaces,
    private keyset<string> $autoImportedFunctions,
    private keyset<string> $autoImportedTypes,
  )[] {
    $this->isAsIsContext =
      Pha\create_syntax_matcher($script, Pha\KIND_PREFIXED_STRING);
    $this->isFunctionContext = Pha\create_syntax_matcher(
      $script,
      Pha\KIND_FUNCTION_CALL_EXPRESSION,
      Pha\KIND_FUNCTION_POINTER_EXPRESSION,
    );
    $this->isQualifiedName =
      Pha\create_syntax_matcher($script, Pha\KIND_QUALIFIED_NAME);
    $this->isTypeContext = Pha\create_syntax_matcher(
      $script,
      Pha\KIND_CONSTRUCTOR_CALL,
      Pha\KIND_GENERIC_TYPE_SPECIFIER,
      Pha\KIND_SCOPE_RESOLUTION_EXPRESSION,
      Pha\KIND_SIMPLE_TYPE_SPECIFIER,
      Pha\KIND_TYPE_PARAMETER,
    );
    $this->isValidName = Pha\create_matcher(
      $script,
      vec[Pha\KIND_QUALIFIED_NAME],
      vec[Pha\KIND_NAME, Pha\KIND_XHP_CLASS_NAME, Pha\KIND_XHP_ELEMENT_NAME],
      vec[],
    );
    $this->isXhp = Pha\create_token_matcher(
      $script,
      Pha\KIND_XHP_CLASS_NAME,
      Pha\KIND_XHP_ELEMENT_NAME,
    );
  }

  public function bubbleQualifiedName(
    Pha\Node $name,
    vec<Pha\Syntax> $ancestors,
  )[]: Pha\Node {
    return C\find($ancestors, $this->isQualifiedName) ?? $name;
  }

  public function resolveName(
    Pha\Node $name,
    vec<Pha\Syntax> $ancestors,
    string $compressed_code,
  )[]: (string, NillableSyntax) {
    $parent = $ancestors[0];
    if (!($this->isValidName)($name)) {
      return tuple($compressed_code, NIL);
    }

    // xhp names are a special case, they use `:` as a namespace separator.
    // By making those names look like regular qualified names,
    // we can treat them as normal names for the purposes of resolving names.
    $compressed_code = Str\replace($compressed_code, ':', '\\');

    if (Str\starts_with($compressed_code, '\\')) {
      return tuple(Str\strip_prefix($compressed_code, '\\'), NIL);
    }

    if (($this->isAsIsContext)($parent)) {
      return tuple($compressed_code, NIL);
    }

    $resolved_name = idx($this->resolvedNames, node_get_id($name));
    if ($resolved_name is nonnull) {
      return tuple($resolved_name, NIL);
    }

    $kind = $this->determineKind($name, $parent, $compressed_code);

    if ($kind === UseKind::TYPE && static::isBuiltinType($compressed_code)) {
      return tuple($compressed_code, NIL);
    }

    if ($kind === UseKind::CONST && static::isBuiltinConst($compressed_code)) {
      return tuple($compressed_code, NIL);
    }

    $parts = Str\split($compressed_code, '\\');
    $first_part = $parts[0];
    $suffix = Vec\slice($parts, 1) |> Str\join($$, '\\') |> '\\'.$$;
    $original_namespace =
      C\findx($this->namespaceResolution, $n ==> $n->isInRange($name));

    for (
      $namespace = $original_namespace;
      $namespace is nonnull;
      $namespace = $namespace->getParent()
    ) {
      $use = idx($namespace->getUses(), $kind, vec[])
        |> C\find($$, $u ==> $u->getLocalName() === $first_part);

      if ($use is nonnull) {
        return tuple(
          $kind === UseKind::NAMESPACE
            ? $use->getPrefix().$suffix
            : $use->getPrefix().$use->getPreAliasName(),
          $use->getClause(),
        );
      }
    }

    if ($kind === UseKind::NAMESPACE) {
      $aliassed_namespace = idx($this->aliasedNamespaces, $first_part);
      if ($aliassed_namespace is nonnull) {
        return tuple($aliassed_namespace.$suffix, NIL);
      }
    }

    if (
      $kind === UseKind::FUNCTION &&
      C\contains_key($this->autoImportedFunctions, $first_part)
    ) {
      return tuple($first_part, NIL);
    }

    if (
      $kind === UseKind::TYPE &&
      C\contains_key($this->autoImportedTypes, $first_part)
    ) {
      return tuple($first_part, NIL);
    }

    return tuple($original_namespace->getName().$compressed_code, NIL);
  }

  private function determineKind(
    Pha\Node $node,
    Pha\Syntax $parent,
    string $compressed_code,
  )[]: UseKind {
    if (($this->isQualifiedName)($node)) {
      return UseKind::NAMESPACE;
    }

    if (($this->isXhp)($node)) {
      return Str\contains($compressed_code, '\\')
        ? UseKind::NAMESPACE
        : UseKind::TYPE;
    }

    if (($this->isFunctionContext)($parent)) {
      return UseKind::FUNCTION;
    }

    if (($this->isTypeContext)($parent)) {
      return UseKind::TYPE;
    }

    return UseKind::CONST;
  }

  private static function isBuiltinConst(string $const_name)[]: bool {
    return
      Str\starts_with($const_name, '__') && Str\ends_with($const_name, '__');
  }

  private static function isBuiltinType(string $type_name)[]: bool {
    return $type_name === '_' ||
      Str\starts_with($type_name, '__') ||
      C\contains(BUILTIN_CONTEXT_NAMES, $type_name);
  }
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-extras/src/_Private/implementation_types/Resolver.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */


newtype Resolver = NameResolver;

function resolver_hide(NameResolver $resolver)[]: Resolver {
  return $resolver;
}

function resolver_reveal(Resolver $resolver)[]: NameResolver {
  return $resolver;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-extras/src/_Private/namespace_resolution/AUTO_IMPORTED_FUNCTIONS.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */


// @see https://github.com/facebook/hhvm/blob/09f6283fcdbdac9b4ec19768d809ee7d2012e612/hphp/hack/src/parser/hh_autoimport.ml
const keyset<string> AUTO_IMPORTED_FUNCTIONS = keyset[
  'asio_get_current_context_idx',
  'asio_get_running_in_context',
  'asio_get_running',
  'class_meth',
  'darray',
  'dict',
  // Added by hand
  'die',
  // Added by hand
  'exit',
  'fun',
  'heapgraph_create',
  'heapgraph_dfs_edges',
  'heapgraph_dfs_nodes',
  'heapgraph_edge',
  'heapgraph_foreach_edge',
  'heapgraph_foreach_node',
  'heapgraph_foreach_root',
  'heapgraph_node_in_edges',
  'heapgraph_node_out_edges',
  'heapgraph_node',
  'heapgraph_stats',
  'idx',
  'idx_readonly',
  'inst_meth',
  'invariant_callback_register',
  'invariant_violation',
  'invariant',
  'is_darray',
  'is_dict',
  'is_keyset',
  'is_varray',
  'is_vec',
  'keyset',
  'meth_caller',
  'objprof_get_data',
  'objprof_get_paths',
  'server_warmup_status',
  'thread_mark_stack',
  'thread_memory_stats',
  'type_structure',
  'type_structure_for_alias',
  'varray',
  'vec',
  'xenon_get_data',
];
}
///// vendor/hershel-theodore-layton/portable-hack-ast-extras/src/_Private/namespace_resolution/AUTO_IMPORTED_TYPES.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */


// @see https://github.com/facebook/hhvm/blob/09f6283fcdbdac9b4ec19768d809ee7d2012e612/hphp/hack/src/parser/hh_autoimport.ml
const keyset<string> AUTO_IMPORTED_TYPES = keyset[
  'AnyArray',
  'AsyncFunctionWaitHandle',
  'AsyncGenerator',
  'AsyncGeneratorWaitHandle',
  'AsyncIterator',
  'AsyncKeyedIterator',
  'Awaitable',
  'AwaitAllWaitHandle',
  'classname',
  'Collection',
  'ConcurrentWaitHandle',
  'ConditionWaitHandle',
  'Container',
  'darray',
  'dict',
  'ExternalThreadEventWaitHandle',
  'IMemoizeParam',
  'UNSAFESingletonMemoizeParam',
  'ImmMap',
  'ImmSet',
  'ImmVector',
  'InvariantException',
  'Iterable',
  'Iterator',
  'KeyedContainer',
  'KeyedIterable',
  'KeyedIterator',
  'KeyedTraversable',
  'keyset',
  'Map',
  'ObjprofObjectStats',
  'ObjprofPathsStats',
  'ObjprofStringStats',
  'Pair',
  'RescheduleWaitHandle',
  'ResumableWaitHandle',
  'Set',
  'Shapes',
  'SleepWaitHandle',
  'StaticWaitHandle',
  'supportdyn',
  'Traversable',
  'typename',
  'TypeStructure',
  'TypeStructureKind',
  'varray_or_darray',
  'varray',
  'vec_or_dict',
  'vec',
  'Vector',
  'WaitableWaitHandle',
  'XenonSample',
];
}
///// vendor/hershel-theodore-layton/portable-hack-ast-extras/src/_Private/namespace_resolution/BUILTIN_CONTEXT_NAMES.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */


// @see https://github.com/facebook/hhvm/blob/09f6283fcdbdac9b4ec19768d809ee7d2012e612/hphp/hack/src/parser/hh_autoimport.ml
const vec<string> BUILTIN_CONTEXT_NAMES = vec[
  'defaults',
  'write_props',
  'leak_safe',
  'leak_safe_shallow',
  'leak_safe_local',
  'zoned',
  'zoned_shallow',
  'zoned_local',
  'zoned_with',
  'read_globals',
  'globals',
  'rx',
  'rx_shallow',
  'rx_local',
];
}
///// vendor/hershel-theodore-layton/portable-hack-ast-extras/src/_Private/namespace_resolution/NamespaceResolution.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */


use namespace HTL\Pha;

final class NamespaceResolution {
  private NodeId $startsAt;
  private NodeId $endsAt;

  public function __construct(
    Pha\Syntax $starts_at,
    Pha\Node $ends_at,
    private string $name,
    private dict<UseKind, vec<UseInfo>> $uses,
    private ?NamespaceResolution $parent,
  )[] {
    $this->startsAt = node_get_id($starts_at);
    $this->endsAt = node_get_id($ends_at);
  }

  public function getName()[]: string {
    return $this->parent is null
      ? $this->name
      : $this->parent->getName().$this->name;
  }

  public function getParent()[]: ?NamespaceResolution {
    return $this->parent;
  }

  public function getUses()[]: dict<UseKind, vec<UseInfo>> {
    return $this->uses;
  }

  public function isInRange(Pha\Node $node)[]: bool {
    return
      node_is_between_or_at_boundary($node, $this->startsAt, $this->endsAt);
  }
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-extras/src/_Private/namespace_resolution/UseInfo.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */


use namespace HTL\Pha;

final class UseInfo {
  public function __construct(
    private UseKind $kind,
    private Pha\Syntax $clause,
    private string $prefix,
    private string $localName,
    private string $preAliasName,
  )[] {}

  public function getClause()[]: Pha\Syntax {
    return $this->clause;
  }

  public function getKind()[]: UseKind {
    return $this->kind;
  }

  public function getLocalName()[]: string {
    return $this->localName;
  }

  public function getPreAliasName()[]: string {
    return $this->preAliasName;
  }

  public function getPrefix()[]: string {
    return $this->prefix;
  }
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-extras/src/_Private/namespace_resolution/UseKind.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */


enum UseKind: int {
  CONST = 0;
  FUNCTION = 1;
  NAMESPACE = 2;
  TYPE = 3;
  NONE = 4;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-extras/src/_Private/three_way_zip.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Math};

function three_way_zip<T1, T2, T3>(
  Traversable<T1> $first,
  Traversable<T2> $second,
  Traversable<T3> $third,
)[]: vec<(T1, T2, T3)> {
  $one = vec($first);
  $two = vec($second);
  $three = vec($third);

  $result = vec[];
  $lesser_count = Math\minva(C\count($one), C\count($two), C\count($three));

  for ($i = 0; $i < $lesser_count; ++$i) {
    $result[] = tuple($one[$i], $two[$i], $three[$i]);
  }

  return $result;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-extras/src/create_name_resolver.hack /////
namespace HTL\Pha {
/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Dict, Str, Vec};
use type HTL\Pha\_Private\{NameResolver, NamespaceResolution, UseInfo, UseKind};

/**
 * @param $aliased_namespaces When using the `hhvm.aliased_namespaces` ini +
 * `auto_namespace_map` hhconfig settings, some default namespaces are used.
 * So for example, mapping `Vec` to `HH\Lib\Vec` acts as if every file started
 * with `if (!exists(use clause "Vec")) use namespace HH\Lib\Vec as Vec;`.
 * You can pass the result of `\ini_get("hhvm.aliased_namespaces")` to make
 * `resolve_names` take your pre resolved names into account.
 *
 * @param $auto_imported_functions a list of functions that are available in any
 * hack file without an explicit use clause. If your hhvm version has different
 * auto imported names, and you care, you can pass a different list of names.
 *
 * @param $auto_imported_types a list of types that are available in any
 * hack file without an explicit use clause. If your hhvm version has different
 * auto imported names, and you care, you can pass a different list of names.
 */
function create_name_resolver(
  Script $script,
  SyntaxIndex $syntax_index,
  TokenIndex $token_index,
  dict<string, string> $aliased_namespaces = dict[],
  ?keyset<string> $auto_imported_functions = null,
  ?keyset<string> $auto_imported_types = null,
)[]: Resolver {
  $auto_imported_functions ??= _Private\AUTO_IMPORTED_FUNCTIONS;
  $auto_imported_types ??= _Private\AUTO_IMPORTED_TYPES;

  $is_const = create_token_matcher($script, KIND_CONST);
  $is_function = create_token_matcher($script, KIND_FUNCTION);
  $is_function_declaration_header =
    create_syntax_matcher($script, KIND_FUNCTION_DECLARATION_HEADER);
  $is_methodish_declaration =
    create_syntax_matcher($script, KIND_METHODISH_DECLARATION);
  $is_missing = create_syntax_matcher($script, KIND_MISSING);
  $is_namespace = create_token_matcher($script, KIND_NAMESPACE);
  $is_namespace_body = create_syntax_matcher($script, KIND_NAMESPACE_BODY);
  $is_namespace_declaration_header =
    create_syntax_matcher($script, KIND_NAMESPACE_DECLARATION_HEADER);
  $is_namespace_group_use_declaration =
    create_syntax_matcher($script, KIND_NAMESPACE_GROUP_USE_DECLARATION);
  $is_namespace_use_clause =
    create_syntax_matcher($script, KIND_NAMESPACE_USE_CLAUSE);
  $is_namespace_use_or_group_use_declaration = create_syntax_matcher(
    $script,
    KIND_NAMESPACE_USE_DECLARATION,
    KIND_NAMESPACE_GROUP_USE_DECLARATION,
  );
  $is_qualfied_name = create_syntax_matcher($script, KIND_QUALIFIED_NAME);
  $is_type = create_token_matcher($script, KIND_TYPE);

  $get_function_name = create_member_accessor($script, MEMBER_FUNCTION_NAME);
  $get_namespace_body = create_member_accessor($script, MEMBER_NAMESPACE_BODY);
  $get_namespace_declarations =
    create_member_accessor($script, MEMBER_NAMESPACE_DECLARATIONS)
    |> returns_syntax($$);
  $get_namespace_group_use_prefix =
    create_member_accessor($script, MEMBER_NAMESPACE_GROUP_USE_PREFIX);
  $get_namespace_header =
    create_member_accessor($script, MEMBER_NAMESPACE_HEADER)
    |> returns_syntax($$);
  $get_namespace_name = create_member_accessor($script, MEMBER_NAMESPACE_NAME);
  $get_namespace_use_clauses = create_member_accessor(
    $script,
    MEMBER_NAMESPACE_USE_CLAUSES,
    MEMBER_NAMESPACE_GROUP_USE_CLAUSES,
  )
    |> returns_syntax($$);
  $get_namespace_use_alias =
    create_member_accessor($script, MEMBER_NAMESPACE_USE_ALIAS);
  $get_namespace_use_name =
    create_member_accessor($script, MEMBER_NAMESPACE_USE_NAME);
  $get_namespace_use_kind = create_member_accessor(
    $script,
    MEMBER_NAMESPACE_USE_KIND,
    MEMBER_NAMESPACE_GROUP_USE_KIND,
  );

  $namespaces = () ==> {
    $declaration_list =
      node_get_first_childx($script, SCRIPT_NODE) |> as_syntax($$);

    $to_use_infos = $uses ==> Vec\map($uses, $use ==> {
      $use = as_syntax($use);
      $kind = $get_namespace_use_kind($use);
      if ($is_const($kind)) {
        $kind = UseKind::CONST;
      } else if ($is_function($kind)) {
        $kind = UseKind::FUNCTION;
      } else if ($is_namespace($kind)) {
        $kind = UseKind::NAMESPACE;
      } else if ($is_type($kind)) {
        $kind = UseKind::TYPE;
      } else {
        $kind = UseKind::NONE;
      }

      if ($is_namespace_group_use_declaration($use)) {
        $prefix = $get_namespace_group_use_prefix($use)
          |> node_get_code_compressed($script, $$);
      } else {
        $prefix = '';
      }

      $make_use_infos_for_kind = $kind ==> $get_namespace_use_clauses($use)
        |> list_get_items_of_children($script, $$)
        |> Vec\map($$, as_syntax<>)
        |> Vec\map(
          $$,
          $clause ==> {
            $use_name_text = $get_namespace_use_name($clause)
              |> node_get_code_compressed($script, $$);

            $last_part = Str\split($use_name_text, '\\') |> C\lastx($$);

            $alias = $get_namespace_use_alias($clause);
            if ($is_missing($alias)) {
              $local_name = $last_part;
            } else {
              $local_name = node_get_code_compressed($script, $alias);
            }

            return new UseInfo(
              $kind,
              $clause,
              $kind === UseKind::NAMESPACE
                ? $prefix.$use_name_text
                : Str\strip_suffix($prefix.$use_name_text, $last_part),
              $local_name,
              $last_part,
            );
          },
        );

      return $kind === UseKind::NONE
        ? Vec\concat(
            vec[$make_use_infos_for_kind(UseKind::NAMESPACE)],
            vec[$make_use_infos_for_kind(UseKind::TYPE)],
          )
          |> Vec\flatten($$)
        : $make_use_infos_for_kind($kind);
    })
      |> Vec\flatten($$)
      |> Dict\group_by($$, $u ==> $u->getKind());

    $namespace_blocks =
      index_get_nodes_by_kind($syntax_index, KIND_NAMESPACE_DECLARATION)
      |> Vec\map($$, $n ==> {
        $scope = $get_namespace_body($n)
          |> $is_namespace_body($$)
            ? as_syntax($$) |> $get_namespace_declarations($$)
            : $declaration_list;

        $uses = node_get_children($script, $scope)
          |> Vec\filter($$, $is_namespace_use_or_group_use_declaration);

        $name = $get_namespace_header($n)
          |> $get_namespace_name($$)
          |> node_get_code_compressed($script, $$).'\\';

        return shape(
          'namespace' =>
            $is_namespace_body($get_namespace_body($n)) ? $n : SCRIPT_NODE,
          'scope' => $scope,
          'uses' => $to_use_infos($uses),
          'name' => $name,
        );
      });

    if (C\is_empty($namespace_blocks)) {
      $namespace_blocks = vec[
        shape(
          'namespace' => SCRIPT_NODE,
          'scope' => $declaration_list,
          'uses' => $to_use_infos(
            node_get_children($script, $declaration_list)
              |> Vec\filter($$, $is_namespace_use_or_group_use_declaration),
          ),
          'name' => '',
        ),
      ];
    }

    $namespaces = dict[];

    foreach ($namespace_blocks as $block) {
      $parent = C\find(
        node_get_ancestors($script, $block['namespace']),
        $a ==> C\contains_key($namespaces, node_get_source_order($a)),
      )
        |> $$ is null ? null : $namespaces[node_get_source_order($$)];

      $namespaces[node_get_source_order($block['namespace'])] =
        new NamespaceResolution(
          $block['scope'],
          node_get_last_descendant_or_self($script, $block['scope']),
          $block['name'],
          $block['uses'],
          $parent,
        );
    }

    return Vec\reverse($namespaces);
  }();

  $get_closest_namespace = $node ==>
    C\find($namespaces, $n ==> $n->isInRange($node));

  $is_a_parent_that_should_be_resolved_as_is = create_syntax_matcher(
    $script,
    KIND_CONTEXT_CONST_DECLARATION,
    KIND_ENUMERATOR,
    KIND_ENUM_CLASS_ENUMERATOR,
    KIND_MARKUP_SUFFIX,
    KIND_MEMBER_SELECTION_EXPRESSION,
    KIND_NAMESPACE_GROUP_USE_DECLARATION,
    KIND_NAMESPACE_USE_CLAUSE,
    KIND_QUALIFIED_NAME,
    KIND_SAFE_MEMBER_SELECTION_EXPRESSION,
    KIND_SCOPE_RESOLUTION_EXPRESSION,
    KIND_TYPE_PARAMETER,
  );

  $get_a_member_that_should_be_resolved_as_is = create_member_accessor(
    $script,
    MEMBER_CONTEXT_CONST_NAME,
    MEMBER_ENUM_CLASS_ENUMERATOR_NAME,
    MEMBER_ENUMERATOR_NAME,
    MEMBER_MARKUP_SUFFIX_NAME,
    MEMBER_MEMBER_NAME,
    MEMBER_NAMESPACE_GROUP_USE_PREFIX,
    MEMBER_NAMESPACE_USE_ALIAS,
    MEMBER_SAFE_MEMBER_NAME,
    MEMBER_SCOPE_RESOLUTION_NAME,
    MEMBER_TYPE_NAME,
  );

  // Many places where a name token can appear don't need to be resolved,
  // for example `$x->noNeedToResolveThisUseAsIs`.
  $should_be_resolved_as_is = ($grand_parent, $parent, $node) ==>
    $is_a_parent_that_should_be_resolved_as_is($parent) &&
      $get_a_member_that_should_be_resolved_as_is($parent) === $node ||
    // This check needs to be performed separately, because KIND_NAMESPACE_USE_CLAUSE
    // has two members that need to be resolved as-is, alias and name.
    // You therefore can't include this in the member accessor.
    $is_namespace_use_clause($parent) &&
      $get_namespace_use_name($parent) === $node ||
    // Function names are resolved using local rules, but method names are as-is.
    $is_methodish_declaration($grand_parent) &&
      $is_function_declaration_header($parent) &&
      $get_function_name($parent) === $node ||
    // Namespace declarations that aren't namespace blocks don't inherit prefixes.
    $is_namespace_declaration_header($parent) &&
      !$is_namespace_body($get_namespace_body($grand_parent));

  $is_a_parent_that_should_be_resolved_locally = create_syntax_matcher(
    $script,
    KIND_ALIAS_DECLARATION,
    KIND_CLASSISH_DECLARATION,
    KIND_CONTEXT_ALIAS_DECLARATION,
    KIND_CONSTANT_DECLARATOR,
    KIND_ENUM_CLASS_DECLARATION,
    KIND_ENUM_DECLARATION,
    KIND_FUNCTION_DECLARATION_HEADER,
    KIND_NAMESPACE_DECLARATION_HEADER,
    KIND_TYPE_CONST_DECLARATION,
  );

  $get_a_member_that_should_be_resolved_locally = create_member_accessor(
    $script,
    MEMBER_ALIAS_NAME,
    MEMBER_CLASSISH_NAME,
    MEMBER_CTX_ALIAS_NAME,
    MEMBER_CONSTANT_DECLARATOR_NAME,
    MEMBER_ENUM_CLASS_NAME,
    MEMBER_ENUM_NAME,
    MEMBER_FUNCTION_NAME,
    MEMBER_NAMESPACE_NAME,
    MEMBER_TYPE_CONST_NAME,
  );

  // In declarations, the declared name should be resolved in the local namespace.
  // `namespace A; function b(): void {}` is `\A\b`.
  $should_be_resolved_with_local_rules = ($parent, $node) ==>
    $is_a_parent_that_should_be_resolved_locally($parent) &&
    $get_a_member_that_should_be_resolved_locally($parent) === $node;

  $resolve_name = $n ==> {
    $name_text = node_get_code_compressed($script, $n);
    $parent = node_get_parent($script, $n) |> as_syntax($$);
    $grand_parent = syntax_get_parent($script, $parent);

    if ($should_be_resolved_as_is($grand_parent, $parent, $n)) {
      return $name_text;
    }

    if ($should_be_resolved_with_local_rules($parent, $n)) {
      return $get_closest_namespace($n)
        |> $$ is null ? $name_text : $$->getName().$name_text;
    }

    return null;
  };

  return index_get_nodes_by_kind($token_index, KIND_NAME)
    |> Vec\map(
      $$,
      $n ==> node_get_ancestors($script, $n)
        |> C\find($$, $is_qualfied_name) ?? $n,
    )
    |> Vec\unique_by($$, node_get_id<>)
    |> Dict\pull($$, $resolve_name, node_get_id<>)
    |> Dict\filter_nulls($$)
    |> new NameResolver(
      $script,
      $namespaces,
      $$,
      $aliased_namespaces,
      $auto_imported_functions,
      $auto_imported_types,
    )
    |> _Private\resolver_hide($$);
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-extras/src/create_pragma_map.hack /////
namespace HTL\Pha {
/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Str, Vec};

function create_pragma_map(
  Script $script,
  SyntaxIndex $syntax_index,
)[]: PragmaMap {
  $source = node_get_code($script, SCRIPT_NODE);

  $is_expression_statement =
    create_syntax_matcher($script, KIND_EXPRESSION_STATEMENT);

  $get_function_call_arguments =
    create_member_accessor($script, MEMBER_FUNCTION_CALL_ARGUMENT_LIST)
    |> returns_syntax($$);
  $get_function_call_receiver =
    create_member_accessor($script, MEMBER_FUNCTION_CALL_RECEIVER);
  $get_constructor_arguments =
    create_member_accessor($script, MEMBER_CONSTRUCTOR_CALL_ARGUMENT_LIST)
    |> returns_syntax($$);
  $get_constructor_type =
    create_member_accessor($script, MEMBER_CONSTRUCTOR_CALL_TYPE);
  $get_vec_members =
    create_member_accessor($script, MEMBER_VECTOR_INTRINSIC_MEMBERS)
    |> returns_syntax($$);

  $parse_arguments = $node_list ==>
    list_get_items_of_children($script, $node_list)
    |> Vec\map($$, $a ==> node_get_code_compressed($script, $a));

  $parse_attributes = () ==> {
    $pragma_to_scope = $p ==> syntax_get_parent($script, $p)
      |> syntax_get_parent($script, $$)
      |> syntax_get_parent($script, $$)
      |> syntax_get_parent($script, $$)
      |> node_get_source_range($script, $$)
      |> source_range_to_line_and_column_numbers($script, $$);

    $pragmas = index_get_nodes_by_kind($syntax_index, KIND_CONSTRUCTOR_CALL)
      |> Vec\filter(
        $$,
        $c ==> $get_constructor_type($c)
          |> node_get_code_compressed($script, $$) === 'Pragmas',
      );

    $effects = Vec\map(
      $pragmas,
      $p ==> $get_constructor_arguments($p)
        |> list_get_items_of_children($script, $$)
        |> Vec\map(
          $$,
          $vec ==>
            as_syntax($vec) |> $get_vec_members($$) |> $parse_arguments($$),
        ),
    );

    $out = vec[];
    foreach ($pragmas as $i => $pragma) {
      $scope = $pragma_to_scope($pragma);
      foreach ($effects[$i] as $effect) {
        $out[] = tuple($pragma, $scope, $effect);
      }
    }

    return $out;
  };

  $parse_directives = () ==> {
    $pragma_to_scope = $p ==> node_get_ancestors($script, $p)
      |> C\find($$, $is_expression_statement) ?? $p
      |> node_get_source_range($script, $$)
      |> source_range_to_line_and_column_numbers($script, $$)
      |> new LineAndColumnNumbers(
        $$->getStartLine(),
        $$->getStartColumn(),
        $$->getEndLine() + 1,
        $$->getEndColumn(),
      );

    $pragmas =
      index_get_nodes_by_kind($syntax_index, KIND_FUNCTION_CALL_EXPRESSION)
      |> Vec\filter(
        $$,
        $f ==> $get_function_call_receiver($f)
          |> node_get_code_compressed($script, $$) === 'pragma',
      );

    $effects = Vec\map(
      $pragmas,
      $p ==> $get_function_call_arguments($p) |> $parse_arguments($$),
    );

    return _Private\three_way_zip(
      $pragmas,
      Vec\map($pragmas, $pragma_to_scope),
      $effects,
    );
  };

  $pragma_lines = vec[];

  if (Str\contains($source, 'use type HTL\\Pragma\\Pragmas;')) {
    $pragma_lines = $parse_attributes();
  }

  if (Str\contains($source, 'use function HTL\\Pragma\\pragma;')) {
    $pragma_lines = Vec\concat($pragma_lines, $parse_directives());
  }

  return new PragmaMap($pragma_lines);
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-extras/src/public_types.hack /////
namespace HTL\Pha {
/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */


type Resolver = _Private\Resolver;
}
///// vendor/hershel-theodore-layton/portable-hack-ast-extras/src/resolve_name.hack /////
namespace HTL\Pha {
/** portable-hack-ast-extras is MIT licensed, see /LICENSE. */


function resolve_name(
  Resolver $resolver,
  Script $script,
  NillableNode $node,
)[]: string {
  return resolve_name_and_use_clause($resolver, $script, $node)[0];
}

function resolve_name_and_use_clause(
  Resolver $resolver,
  Script $script,
  NillableNode $node,
)[]: (string, NillableSyntax) {
  if ($node === NIL) {
    return tuple('', NIL);
  }

  $node = _Private\cast_away_nil($node);

  $resolver = _Private\resolver_reveal($resolver);
  $ancestors = node_get_syntax_ancestors($script, $node);
  $node = $resolver->bubbleQualifiedName($node, $ancestors);
  $compressed_code = node_get_code_compressed($script, $node);

  return $resolver->resolveName($node, $ancestors, $compressed_code);
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/LintError.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Str, Vec};
use namespace HTL\Pha;

final class LintError {
  public function __construct(
    private string $linterName,
    private string $description,
    private Pha\Node $blamedNode,
    private Pha\LineAndColumnNumbers $position,
    private string $code,
    private bool $isIgnored,
    private ?Pha\Patches $patches,
  )[] {}

  public static function create(
    Pha\Script $script,
    Pha\PragmaMap $pragma_map,
    Pha\Node $blamed_node,
    string $linter_name,
    string $description,
  )[]: this {
    return static::createWithPatches(
      $script,
      $pragma_map,
      $blamed_node,
      $linter_name,
      $description,
      null,
    );
  }

  public static function createWithPatches(
    Pha\Script $script,
    Pha\PragmaMap $pragma_map,
    Pha\Node $blamed_node,
    string $linter_name,
    string $description,
    ?Pha\Patches $patches,
  )[]: this {
    $position = Pha\node_get_line_and_column_numbers($script, $blamed_node);
    return new static(
      $linter_name,
      $description,
      $blamed_node,
      $position,
      Pha\node_get_code($script, $blamed_node),
      static::isIgnoredImpl($pragma_map, $position, $linter_name),
      $patches,
    );
  }

  /**
   * Identical to `::create()`, but indicates that the option to add patches
   * was considered and not taken, instead of not being implemented (just yet).
   */
  public static function createWithoutPatches(
    Pha\Script $script,
    Pha\PragmaMap $pragma_map,
    Pha\Node $blamed_node,
    string $linter_name,
    string $description,
  )[]: this {
    return static::createWithPatches(
      $script,
      $pragma_map,
      $blamed_node,
      $linter_name,
      $description,
      null,
    );
  }

  public function getBlamedNode()[]: Pha\Node {
    return $this->blamedNode;
  }

  public function getDescription()[]: string {
    return $this->description;
  }

  public function getLinterName()[]: string {
    return $this->linterName;
  }

  public function getLinterNameWithoutNamespaceAndLinter()[]: string {
    return static::stripLinterSuffix($this->linterName);
  }

  public function getPatches()[]: ?Pha\Patches {
    return $this->patches;
  }

  public function getPosition()[]: Pha\LineAndColumnNumbers {
    return $this->position;
  }

  public function isIgnored()[]: bool {
    return $this->isIgnored;
  }

  public function toString()[]: string {
    return Str\format(
      "Error(%s): %s\n-----\n%s\n-----\nOn line: %d",
      $this->getLinterName(),
      $this->getDescription(),
      $this->code,
      $this->position->getEndLine(),
    );
  }

  private static function isIgnoredImpl(
    Pha\PragmaMap $pragma_map,
    Pha\LineAndColumnNumbers $position,
    string $linter_name,
  )[]: bool {
    return $pragma_map->getOverlappingPragmas($position)
      |> Vec\filter(
        $$,
        $p ==> Str\trim($p[0], '"\'')
          |> $$ === 'PhaLinters' || $$ === 'HTL\PhaLinters',
      )
      |> Vec\flatten($$)
      |> Vec\map($$, $str ==> Str\trim($str, '"\''))
      |> Vec\filter($$, $str ==> Str\starts_with($str, 'fixme:'))
      |> Vec\map($$, $str ==> Str\strip_prefix($str, 'fixme:'))
      |> C\contains($$, static::stripLinterSuffix($linter_name));
  }

  private static function stripLinterSuffix(string $linter_name)[]: string {
    return Str\split($linter_name, '\\')
      |> C\lastx($$)
      |> Str\strip_suffix($$, '_linter')
      |> Str\strip_suffix($$, 'Linter');
  }
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/async_function_and_method_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{Str, Vec};
use namespace HTL\Pha;

function async_function_and_method_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  Pha\TokenIndex $_,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
  ?vec<string> $allowed_suffixes = null,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $get_return_type =
    Pha\create_member_accessor($script, Pha\MEMBER_FUNCTION_TYPE);

  $is_async = $decl ==> $get_return_type($decl)
    |> Support\get_first_token($script, $$)
    |> Pha\token_get_text($script, Pha\as_token_or_nil($$)) === 'Awaitable';

  return Support\enforce_naming(
    $script,
    $syntax_index,
    ($name, $decl) ==> $is_async($decl) &&
      !Str\ends_with($name, '_async') &&
      !Str\ends_with($name, '_asyncx'),
    ($name, $decl) ==> $is_async($decl) &&
      !Str\starts_with($name, 'test') &&
      !Str\ends_with($name, 'Async') &&
      !Str\ends_with($name, 'Asyncx'),
    $allowed_suffixes,
  )
    |> Vec\map(
      $$,
      $n ==> LintError::create(
        $script,
        $pragma_map,
        $n,
        $linter,
        'Please use an async suffix (_async, _asyncx, Async, or Asyncx).',
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/camel_cased_methods_underscored_functions_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Regex, Str, Vec};
use namespace HTL\Pha;

function camel_cased_methods_underscored_functions_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  Pha\TokenIndex $_,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
  ?vec<string> $allowed_suffixes = null,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $get_return_type =
    Pha\create_member_accessor($script, Pha\MEMBER_FUNCTION_TYPE);

  $is_factory_func = ($decl, string $name) ==> $get_return_type($decl)
    |> Pha\node_get_code($script, $$)
    |> Str\trim($$)
    |> Str\split($$, '\\')
    |> C\last($$) ?? ''
    |> Str\split($$, '<', 2)
    |> C\first($$) === $name;

  return Support\enforce_naming(
    $script,
    $syntax_index,
    ($name, $decl) ==> !Str\starts_with($name, '__') &&
      !Regex\matches($name, re'/^[a-z0-9_]+$/') &&
      !$is_factory_func($decl, $name),
    ($name, $decl) ==> {
      return !C\any(
        vec['__', 'test_', 'provide_'],
        $prefix ==> Str\starts_with($name, $prefix),
      ) &&
        !Regex\matches($name, re'/^[a-z][a-zA-Z0-9]*$/') &&
        !$is_factory_func($decl, $name);
    },
    $allowed_suffixes,
  )
    |> Vec\map(
      $$,
      $n ==> LintError::create(
        $script,
        $pragma_map,
        $n,
        $linter,
        'Methods must use camelCase() and functions must use snake_case().',
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/dont_await_in_a_loop_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Vec};
use namespace HTL\Pha;

function dont_await_in_a_loop_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $_,
  Pha\TokenIndex $token_index,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  // Only includes possible direct statement parents of the await expression.
  // Those marked with `// (...)` indicate that the await must be a expression
  // inside of the parens, not the body, since these structures usually have
  // a statement list `{}` as their body. If you do something like:
  // `if (...) await x;` this fails to hold.
  $is_statement = Pha\create_syntax_matcher(
    $script,
    Pha\KIND_DO_STATEMENT, // (...)
    Pha\KIND_ECHO_STATEMENT,
    Pha\KIND_EXPRESSION_STATEMENT,
    Pha\KIND_FOR_STATEMENT, // (...)
    Pha\KIND_FOREACH_STATEMENT, // (...)
    Pha\KIND_IF_STATEMENT, // (...)
    Pha\KIND_RETURN_STATEMENT,
    Pha\KIND_SWITCH_STATEMENT, // (...)
    Pha\KIND_THROW_STATEMENT,
    Pha\KIND_USING_STATEMENT_BLOCK_SCOPED, // (...)
    Pha\KIND_USING_STATEMENT_FUNCTION_SCOPED, // (...)
    Pha\KIND_WHILE_STATEMENT, // (...)
  );
  $is_boundary = Pha\create_syntax_matcher(
    $script,
    Pha\KIND_ANONYMOUS_FUNCTION,
    Pha\KIND_AWAITABLE_CREATION_EXPRESSION,
    Pha\KIND_FUNCTION_DECLARATION,
    Pha\KIND_LAMBDA_EXPRESSION,
    Pha\KIND_METHODISH_DECLARATION,
    Pha\KIND_DO_STATEMENT,
    Pha\KIND_FOR_STATEMENT,
    Pha\KIND_FOREACH_STATEMENT,
    Pha\KIND_WHILE_STATEMENT,
  );
  $is_loop = Pha\create_syntax_matcher(
    $script,
    Pha\KIND_DO_STATEMENT,
    Pha\KIND_FOR_STATEMENT,
    Pha\KIND_FOREACH_STATEMENT,
    Pha\KIND_WHILE_STATEMENT,
  );
  $is_terminal_statement = Pha\create_syntax_matcher(
    $script,
    Pha\KIND_RETURN_STATEMENT,
    Pha\KIND_THROW_STATEMENT,
  );
  $is_prefix_unary_expression =
    Pha\create_syntax_matcher($script, Pha\KIND_PREFIX_UNARY_EXPRESSION);
  $is_for_or_foreach_statement = Pha\create_syntax_matcher(
    $script,
    Pha\KIND_FOR_STATEMENT,
    Pha\KIND_FOREACH_STATEMENT,
  );

  $get_non_looping_part_of_loop = Pha\create_member_accessor(
    $script,
    Pha\MEMBER_FOR_INITIALIZER,
    Pha\MEMBER_FOREACH_COLLECTION,
  );

  return Vec\filter(
    Pha\index_get_nodes_by_kind($token_index, Pha\KIND_AWAIT),
    $await ==> {
      if (!$is_prefix_unary_expression(Pha\node_get_parent($script, $await))) {
        return false;
      }

      $boundary = Pha\node_get_syntax_ancestors($script, $await)
        |> C\findx($$, $is_boundary);

      if (
        !$is_loop($boundary) ||
        $is_for_or_foreach_statement($boundary) &&
          C\contains(
            Pha\node_get_ancestors($script, $await),
            $get_non_looping_part_of_loop($boundary),
          )
      ) {
        return false;
      }

      $statement = Pha\node_get_ancestors($script, $await)
        |> C\findx($$, $is_statement);

      // Allow an await in a loop if the this block ends with a
      // return or throw statement, since no effective parrallism is lost.
      return Pha\node_get_parent($script, $statement)
        |> Pha\node_get_children($script, $$)
        |> Vec\slice($$, C\find_key($$, $n ==> $n === $statement) as nonnull)
        |> !C\any($$, $is_terminal_statement);
    },
  )
    |> Vec\map(
      $$,
      $await_token ==> LintError::createWithoutPatches(
        $script,
        $pragma_map,
        // Blame the whole expression, not just the token.
        Pha\token_get_parent($script, $await_token),
        $linter,
        'Do not await in a loop.',
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/dont_create_forwarding_lambdas_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Vec};
use namespace HTL\Pha;

function dont_create_forwarding_lambdas_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  Pha\TokenIndex $_,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
  shape(
    ?'no_error_for_lambdas_with_typed_parameters_or_return' => bool,
    /*_*/
  ) $options = shape(),
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $ignore_typed_lambdas =
    $options['no_error_for_lambdas_with_typed_parameters_or_return'] ?? false;

  $is_await = Pha\create_token_matcher($script, Pha\KIND_AWAIT);
  $is_decorated_expression =
    Pha\create_syntax_matcher($script, Pha\KIND_DECORATED_EXPRESSION);
  $is_dot_dot_dot = Pha\create_token_matcher($script, Pha\KIND_DOT_DOT_DOT);
  $is_function_call_expression =
    Pha\create_syntax_matcher($script, Pha\KIND_FUNCTION_CALL_EXPRESSION);
  $is_inout = Pha\create_token_matcher($script, Pha\KIND_INOUT);
  $is_name_or_var = Pha\create_matcher(
    $script,
    vec[Pha\KIND_QUALIFIED_NAME, Pha\KIND_VARIABLE_SYNTAX],
    vec[Pha\KIND_NAME],
    vec[],
  );
  $is_parent_or_self =
    Pha\create_token_matcher($script, Pha\KIND_SELF, Pha\KIND_PARENT);
  $is_prefix_unary_expression =
    Pha\create_syntax_matcher($script, Pha\KIND_PREFIX_UNARY_EXPRESSION);
  $is_scope_resolution_expression =
    Pha\create_syntax_matcher($script, Pha\KIND_SCOPE_RESOLUTION_EXPRESSION);
  $is_variable_expression =
    Pha\create_syntax_matcher($script, Pha\KIND_VARIABLE_SYNTAX);

  $get_argument_list =
    Pha\create_member_accessor($script, Pha\MEMBER_FUNCTION_CALL_ARGUMENT_LIST)
    |> Pha\returns_syntax($$);
  $get_function_receiver =
    Pha\create_member_accessor($script, Pha\MEMBER_FUNCTION_CALL_RECEIVER);
  $get_lambda_async =
    Pha\create_member_accessor($script, Pha\MEMBER_LAMBDA_ASYNC);
  $get_lambda_body =
    Pha\create_member_accessor($script, Pha\MEMBER_LAMBDA_BODY);
  $get_lambda_parameters =
    Pha\create_member_accessor($script, Pha\MEMBER_LAMBDA_PARAMETERS)
    |> Pha\returns_syntax($$);
  $get_lambda_return_type =
    Pha\create_member_accessor($script, Pha\MEMBER_LAMBDA_TYPE);
  $get_lambda_signature =
    Pha\create_member_accessor($script, Pha\MEMBER_LAMBDA_SIGNATURE);
  $get_parameter_call_convention =
    Pha\create_member_accessor($script, Pha\MEMBER_PARAMETER_CALL_CONVENTION);
  $get_parameter_default_value =
    Pha\create_member_accessor($script, Pha\MEMBER_PARAMETER_DEFAULT_VALUE);
  $get_parameter_name =
    Pha\create_member_accessor($script, Pha\MEMBER_PARAMETER_NAME);
  $get_parameter_type =
    Pha\create_member_accessor($script, Pha\MEMBER_PARAMETER_TYPE);
  $get_unary_operator =
    Pha\create_member_accessor($script, Pha\MEMBER_PREFIX_UNARY_OPERATOR);
  $get_unary_operand =
    Pha\create_member_accessor($script, Pha\MEMBER_PREFIX_UNARY_OPERAND);
  $get_scope_resolution_qualifier =
    Pha\create_member_accessor($script, Pha\MEMBER_SCOPE_RESOLUTION_QUALIFIER);

  $is_typed_lambda = ($sig, $parameters) ==>
    C\any($parameters, $p ==> !Pha\is_missing($get_parameter_type($p))) ||
    !Pha\is_missing($get_lambda_return_type($sig));

  $convert_parameters = $parameters ==> Vec\map(
    $parameters,
    $p ==> shape(
      'name' => $get_parameter_name($p)
        |> Support\get_last_token($script, $$)
        |> Pha\token_get_text($script, $$),
      'call_conv' => $get_parameter_name($p)
        |> Support\get_last_token($script, $$)
        |> Support\get_previous_token($script, $$)
        |> $is_dot_dot_dot($$)
          ? Support\CallingCovention::VARIADIC
          : (
              !Pha\is_missing($get_parameter_call_convention($p))
                ? Support\CallingCovention::INOUT
                : Support\CallingCovention::PLAIN
            ),
      'has_default' => !Pha\is_missing($get_parameter_default_value($p)),
    ),
  );

  $extract_qualifying_argument_list = $call ==> {
    if (!$is_function_call_expression($call)) {
      return Pha\NIL;
    }
    $call = Pha\as_syntax($call);

    $receiver = $get_function_receiver($call);
    if (
      $is_name_or_var($receiver) ||
      (
        $is_scope_resolution_expression($receiver) &&
        !$is_parent_or_self(
          Pha\as_syntax($receiver) |> $get_scope_resolution_qualifier($$),
        )
      )
    ) {
      return $get_argument_list($call);
    }

    return Pha\NIL;
  };

  $get_lambda_argument_list = $lambda ==> {
    $body = $get_lambda_body($lambda);

    if (!Pha\is_syntax($body)) {
      return Pha\NIL;
    }

    $body = Pha\as_syntax($body);

    if (Pha\is_missing($get_lambda_async($lambda))) {
      return $extract_qualifying_argument_list($body);
    }

    if (
      !$is_prefix_unary_expression($body) ||
      !$is_await($get_unary_operator($body))
    ) {
      return Pha\NIL;
    }

    return $extract_qualifying_argument_list($get_unary_operand($body));
  };

  $get_parameters = $lambda ==> {
    $sig = $get_lambda_signature($lambda);

    if (Pha\is_token($sig)) {
      return vec[shape(
        'name' => Pha\token_get_text($script, Pha\as_token($sig)),
        'call_conv' => Support\CallingCovention::PLAIN,
        'has_default' => false,
      )];
    }

    $sig = Pha\as_syntax($sig);
    $parameters = $get_lambda_parameters($sig)
      |> Pha\list_get_items_of_children($script, $$)
      |> Vec\map($$, Pha\as_syntax<>);

    if ($ignore_typed_lambdas && $is_typed_lambda($sig, $parameters)) {
      return vec[shape(
        'name' => 'Lambda with typehint, okay. (Given a fake default param.)',
        'has_default' => true,
        'call_conv' => Support\CallingCovention::OTHER,
      )];
    }

    return $convert_parameters($parameters);
  };

  $get_arguments = $argument_list ==> Vec\map(
    Pha\list_get_items_of_children($script, $argument_list),
    $a ==> {
      $first_token = Support\get_first_token($script, $a);
      $call_conv = $is_decorated_expression($a)
        ? (
            $is_inout($first_token)
              ? Support\CallingCovention::INOUT
              : Support\CallingCovention::VARIADIC
          )
        : (
            $is_variable_expression($a)
              ? Support\CallingCovention::PLAIN
              : Support\CallingCovention::OTHER
          );

      return shape(
        'name' =>
          Pha\token_get_text($script, Support\get_last_token($script, $a)),
        'call_conv' => $call_conv,
      );
    },
  );

  return Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_LAMBDA_EXPRESSION)
    |> Vec\filter($$, $lambda ==> {
      $argument_list = $get_lambda_argument_list($lambda);

      if ($argument_list === Pha\NIL) {
        return false;
      }

      $argument_list = Pha\as_nonnil($argument_list);
      $params = $get_parameters($lambda);

      if (
        C\any($params, $p ==> $p['has_default']) ||
        C\count(Pha\node_get_children($script, $argument_list)) !==
          C\count($params)
      ) {
        return false;
      }

      $args = $get_arguments(Pha\as_nonnil($argument_list));

      foreach ($args as $i => $a) {
        $p = $params[$i];
        if ($p['call_conv'] !== $a['call_conv'] || $p['name'] !== $a['name']) {
          return false;
        }
      }

      return true;
    })
    |> Vec\map(
      $$,
      $lambda ==> LintError::create(
        $script,
        $pragma_map,
        $lambda,
        $linter,
        'This lambda just forwards to the inner function. '.
        'Pass the inner function directly instead.',
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/dont_discard_new_expressions_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\Vec;
use namespace HTL\Pha;

function dont_discard_new_expressions_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  Pha\TokenIndex $_,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $is_object_creation_expression =
    Pha\create_syntax_matcher($script, Pha\KIND_OBJECT_CREATION_EXPRESSION);

  $get_expression = Pha\create_member_accessor(
    $script,
    Pha\MEMBER_EXPRESSION_STATEMENT_EXPRESSION,
  );

  return
    Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_EXPRESSION_STATEMENT)
    |> Vec\filter(
      $$,
      $e ==> $get_expression($e) |> $is_object_creation_expression($$),
    )
    |> Vec\map(
      $$,
      $stmt ==> LintError::createWithPatches(
        $script,
        $pragma_map,
        $stmt,
        $linter,
        'You are ignoring the new object. Please use it or assign it to `$_`.',
        Pha\patches($script, Pha\patch_node(
          $stmt,
          '$_ = '.
          Pha\node_get_code_without_leading_or_trailing_trivia($script, $stmt),
          shape('trivia' => Pha\RetainTrivia::BOTH),
        )),
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/dont_use_asio_join_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Vec};
use namespace HTL\Pha;

function dont_use_asio_join_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $_,
  Pha\TokenIndex $token_index,
  Pha\Resolver $resolver,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $is_qualified_name =
    Pha\create_syntax_matcher($script, Pha\KIND_QUALIFIED_NAME);

  return Pha\index_get_nodes_by_kind($token_index, Pha\KIND_NAME)
    |> Vec\map(
      $$,
      $n ==>
        C\find(Pha\node_get_ancestors($script, $n), $is_qualified_name) ?? $n,
    )
    |> Vec\unique_by($$, Pha\node_get_id<>)
    |> Vec\filter(
      $$,
      $n ==>
        Pha\resolve_name($resolver, $script, $n) |> $$ === 'HH\\Asio\\join',
    )
    |> Vec\map(
      $$,
      $n ==> LintError::createWithoutPatches(
        $script,
        $pragma_map,
        $n,
        $linter,
        "Don't use Asio\join().",
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/final_or_abstract_classes_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Vec};
use namespace HTL\Pha;

function final_or_abstract_classes_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  Pha\TokenIndex $_,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $is_class = Pha\create_token_matcher($script, Pha\KIND_CLASS);
  $is_abstract_or_final =
    Pha\create_token_matcher($script, Pha\KIND_ABSTRACT, Pha\KIND_FINAL);

  $get_class_name =
    Pha\create_member_accessor($script, Pha\MEMBER_CLASSISH_NAME);
  $get_class_keyword =
    Pha\create_member_accessor($script, Pha\MEMBER_CLASSISH_KEYWORD);
  $get_classish_modifiers =
    Pha\create_member_accessor($script, Pha\MEMBER_CLASSISH_MODIFIERS);

  return
    Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_CLASSISH_DECLARATION)
    |> Vec\filter(
      $$,
      $c ==> $is_class($get_class_keyword($c)) &&
        (
          $get_classish_modifiers($c)
          |> Pha\node_get_children($script, $$)
          |> !C\any($$, $is_abstract_or_final)
        ),
    )
    |> Vec\map(
      $$,
      $c ==> LintError::createWithPatches(
        $script,
        $pragma_map,
        $get_class_name($c),
        $linter,
        'Classes should be abstract or final.',
        Pha\patches($script, Pha\patch_node(
          $c,
          'final '.
          Pha\node_get_code_without_leading_or_trailing_trivia($script, $c),
          shape('trivia' => Pha\RetainTrivia::BOTH),
        )),
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/group_use_statement_alphabetization_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Vec};
use namespace HTL\Pha;

function group_use_statement_alphabetization_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  Pha\TokenIndex $_,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $get_clauses =
    Pha\create_member_accessor($script, Pha\MEMBER_NAMESPACE_GROUP_USE_CLAUSES)
    |> Pha\returns_syntax($$);

  $get_use_name =
    Pha\create_member_accessor($script, Pha\MEMBER_NAMESPACE_USE_NAME);

  $get_uses_to_be_sorted = $group_use ==> $get_clauses($group_use)
    |> Pha\list_get_items_of_children($script, $$);

  $autofix = $group_use ==> {
    $old_order = $get_uses_to_be_sorted($group_use);
    $new_order = Vec\sort_by(
      $old_order,
      $c ==> Pha\as_syntax($c)
        |> $get_use_name($$)
        |> Pha\node_get_code_compressed($script, $$),
    );
    return Vec\zip($old_order, $new_order)
      |> Vec\map(
        $$,
        $tuple ==> vec[
          Pha\patch_node(
            $tuple[0],
            Pha\node_get_code_without_leading_or_trailing_trivia(
              $script,
              $tuple[1],
            ),
            shape('trivia' => Pha\RetainTrivia::BOTH),
          ),
        ],
      )
      |> Vec\flatten($$)
      |> Pha\patches($script, ...$$);
  };

  return Pha\index_get_nodes_by_kind(
    $syntax_index,
    Pha\KIND_NAMESPACE_GROUP_USE_DECLARATION,
  )
    |> Vec\filter(
      $$,
      $group_use ==> $get_uses_to_be_sorted($group_use)
        |> Vec\map(
          $$,
          $clause ==> Pha\as_syntax($clause)
            |> $get_use_name($$)
            |> Pha\node_get_code_compressed($script, $$),
        )
        |> !C\is_sorted($$),
    )
    |> Vec\map(
      $$,
      $group_use ==> LintError::createWithPatches(
        $script,
        $pragma_map,
        $group_use,
        $linter,
        'Group use clauses should be sorted alphabetically.',
        $autofix($group_use),
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/group_use_statements_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Dict, Str, Vec};
use namespace HTL\Pha;

function group_use_statements_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  Pha\TokenIndex $_,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  // If you have multiple namespaces per file, "why else use namespace blocks?",
  // this linter will ignore this file. This is no better than hhast, which will
  // report errors and suggest fixes that change the semantics: hhvm/hhast#307.
  // I have decided that I won't add in logic to support namespace nesting.
  // I won't object to a PR that adds this support.
  if (
    C\any(Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_NAMESPACE_BODY))
  ) {
    return vec[];
  }

  $is_const = Pha\create_token_matcher($script, Pha\KIND_CONST);
  $is_function = Pha\create_token_matcher($script, Pha\KIND_FUNCTION);
  $is_name = Pha\create_token_matcher($script, Pha\KIND_NAME);
  $is_namespace = Pha\create_token_matcher($script, Pha\KIND_NAMESPACE);
  $is_type = Pha\create_token_matcher($script, Pha\KIND_TYPE);

  $get_kind = Pha\create_member_accessor(
    $script,
    Pha\MEMBER_NAMESPACE_USE_KIND,
    Pha\MEMBER_NAMESPACE_GROUP_USE_KIND,
  );

  $get_grouped_prefix =
    Pha\create_member_accessor($script, Pha\MEMBER_NAMESPACE_GROUP_USE_PREFIX);
  $get_clauses =
    Pha\create_member_accessor($script, Pha\MEMBER_NAMESPACE_USE_CLAUSES)
    |> Pha\returns_syntax($$);
  $get_clause_name =
    Pha\create_member_accessor($script, Pha\MEMBER_NAMESPACE_USE_NAME);

  $no_prefix = '';
  $parse_clause_prefix = $clause ==> {
    $name = $get_clause_name($clause);
    if ($is_name($name)) {
      return $no_prefix;
    }

    return Pha\node_get_code_compressed($script, $name)
      |> Str\split($$, '\\')
      |> Vec\slice($$, 0, C\count($$) - 1)
      |> Str\join($$, '\\');
  };

  $parse_group_prefix = $use ==> $get_grouped_prefix($use)
    |> Pha\node_get_code_compressed($script, $$)
    |> Str\strip_suffix($$, '\\');

  $get_kind_as_enum = $use ==> $get_kind($use)
    |> $is_const($$)
      ? Support\UseKind::CONST
      : (
          $is_function($$)
            ? Support\UseKind::FUNCTION
            : (
                $is_namespace($$)
                  ? Support\UseKind::NAMESPACE
                  : (
                      $is_type($$)
                        ? Support\UseKind::TYPE
                        : Support\UseKind::NONE
                    )
              )
        );

  $use_clauses = Pha\index_get_nodes_by_kind(
    $syntax_index,
    Pha\KIND_NAMESPACE_USE_DECLARATION,
  )
    |> Dict\group_by($$, $get_kind_as_enum)
    |> Dict\map(
      $$,
      $uses ==> Vec\map(
        $uses,
        $u ==> Pha\as_syntax($u)
          |> $get_clauses($$)
          |> Pha\list_get_items_of_children($script, $$),
      )
        |> Vec\flatten($$)
        |> Vec\map($$, Pha\as_syntax<>),
    );

  $grouped_uses = Pha\index_get_nodes_by_kind(
    $syntax_index,
    Pha\KIND_NAMESPACE_GROUP_USE_DECLARATION,
  )
    |> Dict\group_by($$, $get_kind_as_enum);

  // Just give up if the script contains any use clauses without a kind.
  if (
    C\contains_key($use_clauses, Support\UseKind::NONE) ||
    C\contains_key($grouped_uses, Support\UseKind::NONE)
  ) {
    return vec[];
  }

  return Vec\map(Support\REAL_USE_KINDS, $kind ==> {
    $prefixes = Vec\concat(
      idx($use_clauses, $kind, vec[])
        |> Vec\map($$, $x ==> tuple($x, $parse_clause_prefix($x))),
      idx($grouped_uses, $kind, vec[])
        |> Vec\map($$, $x ==> tuple($x, $parse_group_prefix($x))),
    );

    $seen_prefixes = keyset[];
    foreach ($prefixes as list($node, $prefix)) {
      if ($prefix === $no_prefix) {
        continue;
      }

      if (C\contains_key($seen_prefixes, $prefix)) {
        yield $node;
      }

      $seen_prefixes[] = $prefix;
    }
  })
    |> Vec\map($$, vec<>)
    |> Vec\flatten($$)
    |> Vec\map(
      $$,
      $n ==> LintError::create(
        $script,
        $pragma_map,
        $n,
        $linter,
        'This use directive can be grouped with a previous use directive.',
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/license_header_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Str};
use namespace HTL\Pha;

function license_header_linter(
  Pha\Script $script,
  Pha\PragmaMap $pragma_map,
  string $expected_license_header,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $is_markup_section =
    Pha\create_syntax_matcher($script, Pha\KIND_MARKUP_SECTION);

  $first_thing = Pha\node_get_first_childx($script, Pha\SCRIPT_NODE)
    |> Pha\node_get_children($script, $$)
    |> C\findx($$, $n ==> !$is_markup_section($n));

  return Pha\node_get_descendants($script, $first_thing)
    |> C\any(
      $$,
      $n ==> Pha\is_trivium($n) &&
        Str\contains(Pha\node_get_code($script, $n), $expected_license_header),
    )
      ? vec[]
      : vec[LintError::createWithPatches(
        $script,
        $pragma_map,
        C\firstx($$),
        $linter,
        'Expected the find your license header at the top of this file: '.
        $expected_license_header,
        Pha\patches($script, Pha\patch_node(
          $first_thing,
          $expected_license_header.
          "\n".
          Pha\node_get_code($script, $first_thing),
        )),
      )];
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/must_use_braces_for_control_flow_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\Vec;
use namespace HTL\Pha;

function must_use_braces_for_control_flow_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  Pha\TokenIndex $_,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $is_compound_statement_or_if_statement = Pha\create_syntax_matcher(
    $script,
    Pha\KIND_COMPOUND_STATEMENT,
    Pha\KIND_IF_STATEMENT,
  );

  $get_body = Pha\create_member_accessor(
    $script,
    Pha\MEMBER_DO_BODY,
    Pha\MEMBER_ELSE_STATEMENT,
    Pha\MEMBER_IF_STATEMENT,
    Pha\MEMBER_FOR_BODY,
    Pha\MEMBER_FOREACH_BODY,
    Pha\MEMBER_WHILE_BODY,
  );

  $is_braceless = $node ==>
    $get_body($node) |> !$is_compound_statement_or_if_statement($$);

  return Vec\concat(
    Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_DO_STATEMENT),
    Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_ELSE_CLAUSE),
    Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_IF_STATEMENT),
    Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_FOR_STATEMENT),
    Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_FOREACH_STATEMENT),
    Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_WHILE_STATEMENT),
  )
    |> Vec\filter($$, $is_braceless)
    |> Vec\map(
      $$,
      $n ==> LintError::createWithPatches(
        $script,
        $pragma_map,
        $n,
        $linter,
        'Use curly braces {} for control flow.',
        Pha\patches($script, Pha\patch_node(
          $get_body($n),
          $get_body($n)
            |> Pha\node_get_code($script, $$)
            |> "{\n ".$$.'}',
        )),
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/namespace_private_symbol_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Str, Vec};
use namespace HTL\Pha;

/**
 * This linter complements namespace_private_use_clause_linter.
 * That linter gives an early notice if the namespace use declaration imports
 * something private from a namespace you don't share a prefix with.
 * This is still valuable for a quicker feedback loop.
 *
 * This linter does the heavy lifting and scans through the body of your code
 * to see if you are using qualified names to "outsmart" the first linter.
 */
function namespace_private_symbol_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  Pha\TokenIndex $token_index,
  Pha\Resolver $resolver,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $is_namespace_declaration =
    Pha\create_syntax_matcher($script, Pha\KIND_NAMESPACE_DECLARATION);
  $is_qualified_name =
    Pha\create_syntax_matcher($script, Pha\KIND_QUALIFIED_NAME);

  $get_namespace_header =
    Pha\create_member_accessor($script, Pha\MEMBER_NAMESPACE_HEADER)
    |> Pha\returns_syntax($$);
  $get_namespace_name =
    Pha\create_member_accessor($script, Pha\MEMBER_NAMESPACE_NAME);

  $main_namespace =
    Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_NAMESPACE_DECLARATION)
    |> C\first($$);

  return Pha\index_get_nodes_by_kind($token_index, Pha\KIND_NAME)
    |> Vec\map(
      $$,
      $n ==>
        C\find(Pha\node_get_ancestors($script, $n), $is_qualified_name) ?? $n,
    )
    |> Vec\unique_by($$, Pha\node_get_id<>)
    |> Vec\filter(
      $$,
      $n ==> {
        $name = Pha\resolve_name($resolver, $script, $n);

        $public_and_private_part = Str\split($name, '\\__Private', 2)
          |> C\count($$) !== 1 ? $$ : Str\split(C\onlyx($$), '\\_Private', 2);

        if (C\count($public_and_private_part) === 1) {
          return false;
        }

        $nearest_namespace = C\find(
          Pha\node_get_syntax_ancestors($script, $n),
          $is_namespace_declaration,
        ) ??
          $main_namespace;

        if ($nearest_namespace is null) {
          return true;
        }

        $namespace_prefix = $get_namespace_header($nearest_namespace)
          |> $get_namespace_name($$)
          |> Pha\resolve_name($resolver, $script, $$)
          |> Str\split($$, '\\')
          |> C\firstx($$);

        return !Str\starts_with($name, $namespace_prefix);
      },
    )
    |> Vec\map(
      $$,
      $n ==> LintError::createWithoutPatches(
        $script,
        $pragma_map,
        $n,
        $linter,
        'This constant/function/type comes from a private namespace. '.
        'This namespace does not share a common prefix with your current namespace.',
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/namespace_private_use_clause_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Str, Vec};
use namespace HTL\Pha;

/**
 * This linter is but one part of namespace_private_linter.
 * It detects use clauses that access foreign `_Private` (or `__Private`)
 * namespaces, but will not scan the expressions / statements for references
 * formed with qualified names.
 *
 * ```
 * namespace A\AThing;
 * use namespace A\Something\_Private; // << allowed
 * use namespace B\_Private; // << lint error
 *
 * const int X = B\_Private\X; // << Ignored
 * const int FROM_C = _Private\X; // << Ignored
 * ```
 */
function namespace_private_use_clause_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  Pha\TokenIndex $_,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  // If you have multiple namespaces per file, "why else use namespace blocks?",
  // this linter will ignore this file. I won't object to a PR that adds this support.
  if (
    C\any(Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_NAMESPACE_BODY))
  ) {
    return vec[];
  }

  $is_name = Pha\create_token_matcher($script, Pha\KIND_NAME);

  $get_namespace_name =
    Pha\create_member_accessor($script, Pha\MEMBER_NAMESPACE_NAME);

  $current_namespace = Pha\index_get_nodes_by_kind(
    $syntax_index,
    Pha\KIND_NAMESPACE_DECLARATION_HEADER,
  )
    |> C\first($$); // C\only() does not exist, and C\onlyx() would throw for 0.

  if ($current_namespace is null) {
    $namespace_prefix = '';
  } else {
    $name = $get_namespace_name($current_namespace);

    if ($is_name($name)) {
      $namespace_prefix =
        Pha\as_token($name) |> Pha\token_get_text($script, $$);
    } else {
      $namespace_prefix = Pha\as_syntax($name)
        |> Pha\node_get_code_compressed($script, $$)
        |> Str\split($$, '\\')[0];
    }
  }

  return Support\get_flattened_namespace_uses(
    $script,
    Pha\index_get_nodes_by_kind(
      $syntax_index,
      Pha\KIND_NAMESPACE_USE_DECLARATION,
    ),
    Pha\index_get_nodes_by_kind(
      $syntax_index,
      Pha\KIND_NAMESPACE_GROUP_USE_DECLARATION,
    ),
  )
    |> Vec\flatten($$)
    |> Vec\filter($$, $v ==> {
      list(, $use_text) = $v;
      $public_and_private_part = Str\split($use_text, '\\__Private', 2)
        |> C\count($$) !== 1 ? $$ : Str\split(C\onlyx($$), '\\_Private', 2);
      return C\count($public_and_private_part) > 1 &&
        !Str\starts_with($public_and_private_part[0], $namespace_prefix);
    })
    |> Vec\map(
      $$,
      $v ==> LintError::createWithoutPatches(
        $script,
        $pragma_map,
        $v[0],
        $linter,
        'This use declaration includes a private namespace. '.
        'This namespace does not share a common prefix with your current namespace.',
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/no_elseif_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\Vec;
use namespace HTL\Pha;

function no_elseif_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $_,
  Pha\TokenIndex $token_index,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  return Vec\map(
    Pha\index_get_nodes_by_kind($token_index, Pha\KIND_ELSEIF),
    $f ==> LintError::createWithPatches(
      $script,
      $pragma_map,
      $f,
      $linter,
      'Use else if instead of elseif. '.
      'This syntax will be removed in a future version of hhvm.',
      Pha\patches($script, Pha\patch_node(
        $f,
        'else if',
        shape('trivia' => Pha\RetainTrivia::BOTH),
      )),
    ),
  );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/no_empty_statements_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{Str, Vec};
use namespace HTL\Pha;

function no_empty_statements_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  Pha\TokenIndex $_,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $is_always_empty_expression = Pha\create_syntax_matcher(
    $script,
    Pha\KIND_ANONYMOUS_FUNCTION,
    Pha\KIND_CAST_EXPRESSION,
    Pha\KIND_COLLECTION_LITERAL_EXPRESSION,
    Pha\KIND_DARRAY_INTRINSIC_EXPRESSION,
    Pha\KIND_DICTIONARY_INTRINSIC_EXPRESSION,
    Pha\KIND_IS_EXPRESSION,
    Pha\KIND_ISSET_EXPRESSION,
    Pha\KIND_KEYSET_INTRINSIC_EXPRESSION,
    Pha\KIND_LAMBDA_EXPRESSION,
    Pha\KIND_LITERAL,
    Pha\KIND_MISSING,
    Pha\KIND_NAME_EXPRESSION,
    Pha\KIND_SUBSCRIPT_EXPRESSION,
    Pha\KIND_VECTOR_INTRINSIC_EXPRESSION,
    Pha\KIND_VARIABLE_SYNTAX,
    Pha\KIND_VARRAY_INTRINSIC_EXPRESSION,
  );

  $is_binary_expression =
    Pha\create_syntax_matcher($script, Pha\KIND_BINARY_EXPRESSION);

  $is_parenthesized_expression =
    Pha\create_syntax_matcher($script, Pha\KIND_PARENTHESIZED_EXPRESSION);

  $is_side_effecty_operator = Pha\create_token_matcher(
    $script,
    Pha\KIND_AMPERSAND_EQUAL,
    Pha\KIND_BAR_EQUAL,
    Pha\KIND_CARAT_EQUAL,
    Pha\KIND_DOT_EQUAL,
    Pha\KIND_EQUAL,
    Pha\KIND_GREATER_THAN_GREATER_THAN_EQUAL,
    Pha\KIND_LESS_THAN_LESS_THAN_EQUAL,
    Pha\KIND_MINUS_EQUAL,
    Pha\KIND_PERCENT_EQUAL,
    Pha\KIND_PLUS_EQUAL,
    Pha\KIND_QUESTION_QUESTION_EQUAL,
    Pha\KIND_SLASH_EQUAL,
    Pha\KIND_STAR_EQUAL,
    Pha\KIND_STAR_STAR_EQUAL,
    // The `|>` operator has no side-effect, but this common idiom needs to be ok.
    // `some_cumbersome_expr |> side_effecty_function($$);`
    // This is preferred when this results in easier to read code.
    // Is is not always possible to use a discard statement `$_ = ...`,
    // since the type of this expression may be void.
    // Assigned void to `$_` is not allowed.
    Pha\KIND_BAR_GREATER_THAN,
  );

  $get_binop_operator =
    Pha\create_member_accessor($script, Pha\MEMBER_BINARY_OPERATOR);

  $get_expression = Pha\create_member_accessor(
    $script,
    Pha\MEMBER_EXPRESSION_STATEMENT_EXPRESSION,
  );

  $get_parenthesized_expression_expression = Pha\create_member_accessor(
    $script,
    Pha\MEMBER_PARENTHESIZED_EXPRESSION_EXPRESSION,
  );

  $expression_is_empty = $node ==> {
    while ($is_parenthesized_expression($node)) {
      $node = $get_parenthesized_expression_expression(Pha\as_syntax($node));
    }

    return $is_always_empty_expression($node) ||
      (
        $is_binary_expression($node) &&
        (
          $node
          |> Pha\as_syntax($$)
          |> $get_binop_operator($$)
          |> !$is_side_effecty_operator($$)
        )
      );
  };

  return
    Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_EXPRESSION_STATEMENT)
    |> Vec\map($$, $get_expression)
    |> Vec\filter($$, $expression_is_empty)
    |> Vec\map(
      $$,
      $expr ==> LintError::createWithPatches(
        $script,
        $pragma_map,
        $expr,
        $linter,
        'You are not using the result of this expression. '.
        'You can silence this warning by assigning it to `$_`.',
        Pha\node_get_code_without_leading_or_trailing_trivia($script, $expr)
          // a `;` is an empty statement, but `$_ = ;` is not a valid statement.
          |> Str\trim($$) !== ''
            ? Pha\patches($script, Pha\patch_node(
              $expr,
              '$_ = '.$$,
              shape('trivia' => Pha\RetainTrivia::BOTH),
            ))
            : null,
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/no_final_method_in_final_classes_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Vec};
use namespace HTL\Pha;

function no_final_method_in_final_classes_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  Pha\TokenIndex $_,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $is_classish_declaration =
    Pha\create_syntax_matcher($script, Pha\KIND_CLASSISH_DECLARATION);
  $is_final = Pha\create_token_matcher($script, Pha\KIND_FINAL);

  $get_classish_modifiers =
    Pha\create_member_accessor($script, Pha\MEMBER_CLASSISH_MODIFIERS);
  $get_method_function_decl = Pha\create_member_accessor(
    $script,
    Pha\MEMBER_METHODISH_FUNCTION_DECL_HEADER,
  )
    |> Pha\returns_syntax($$);
  $get_function_modifiers =
    Pha\create_member_accessor($script, Pha\MEMBER_FUNCTION_MODIFIERS);
  $get_function_name =
    Pha\create_member_accessor($script, Pha\MEMBER_FUNCTION_NAME);

  $any_child_is_final = $node ==>
    C\any(Pha\node_get_children($script, $node), $is_final);

  return
    Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_METHODISH_DECLARATION)
    |> Vec\filter(
      $$,
      $method ==> (
        $get_method_function_decl($method)
        |> $get_function_modifiers($$)
        |> $any_child_is_final($$)
      ) &&
        (
          Pha\node_get_syntax_ancestors($script, $method)
          |> C\findx($$, $is_classish_declaration)
          |> $get_classish_modifiers($$)
          |> $any_child_is_final($$)
        ),
    )
    |> Vec\map(
      $$,
      $f ==> LintError::createWithPatches(
        $script,
        $pragma_map,
        $get_method_function_decl($f) |> $get_function_name($$),
        $linter,
        'Remove the final keyword. The surrounding class is already final.',
        Pha\patches(
          $script,
          $get_method_function_decl($f)
            |> $get_function_modifiers($$)
            |> Pha\node_get_children($script, $$)
            |> C\findx($$, $is_final)
            |> Pha\patch_node(
              $$,
              '',
              shape('trivia' => Pha\RetainTrivia::LEADING),
            ),
        ),
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/no_newline_at_start_of_control_flow_block_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\Vec;
use namespace HTL\Pha;

function no_newline_at_start_of_control_flow_block_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  Pha\TokenIndex $_,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $is_eol = Pha\create_trivium_matcher($script, Pha\KIND_END_OF_LINE);
  $is_function_body = Pha\create_syntax_matcher(
    $script,
    Pha\KIND_FUNCTION_DECLARATION,
    Pha\KIND_LAMBDA_EXPRESSION,
    Pha\KIND_METHODISH_DECLARATION,
  );

  $get_closing_curly =
    Pha\create_member_accessor($script, Pha\MEMBER_COMPOUND_RIGHT_BRACE);
  $get_statements =
    Pha\create_member_accessor($script, Pha\MEMBER_COMPOUND_STATEMENTS);

  $get_first_statement_or_closing_curly = $compound ==>
    $get_statements($compound)
    |> Pha\node_get_first_child($script, $$)
    |> $$ === Pha\NIL ? $get_closing_curly($compound) : Pha\as_nonnil($$);

  return Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_COMPOUND_STATEMENT)
    |> Vec\filter(
      $$,
      $stmt ==> Pha\node_get_parent($script, $stmt) |> !$is_function_body($$),
    )
    |> Vec\map(
      $$,
      $stmt ==> $get_first_statement_or_closing_curly($stmt)
        |> Support\get_first_token($script, $$)
        |> Pha\node_get_first_child($script, $$),
    )
    |> Vec\filter($$, $is_eol)
    |> Vec\map($$, Pha\as_nonnil<>)
    |> Vec\map(
      $$,
      $eol ==> LintError::createWithPatches(
        $script,
        $pragma_map,
        Pha\as_nonnil($eol),
        $linter,
        'Control flow blocks may not start with an empty line.',
        Pha\patches($script, Pha\patch_node($eol, '')),
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/no_php_equality_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\Vec;
use namespace HTL\Pha;

function no_php_equality_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $_,
  Pha\TokenIndex $token_index,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $is_eq = Pha\create_token_matcher($script, Pha\KIND_EQUAL_EQUAL);

  return Vec\concat(
    Pha\index_get_nodes_by_kind($token_index, Pha\KIND_EQUAL_EQUAL),
    Pha\index_get_nodes_by_kind($token_index, Pha\KIND_EXCLAMATION_EQUAL),
  )
    |> Vec\map(
      $$,
      $n ==> LintError::createWithPatches(
        $script,
        $pragma_map,
        $n,
        $linter,
        'Do not use `==` or `!=`. '.
        'The behaviors of these operators are difficult to explain.',
        Pha\patches(
          $script,
          Pha\patch_node(
            $n,
            $is_eq($n) ? '===' : '!==',
            shape('trivia' => Pha\RetainTrivia::BOTH),
          ),
        ),
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/no_string_interpolation_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\Vec;
use namespace HTL\Pha;

function no_string_interpolation_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $_,
  Pha\TokenIndex $token_index,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  return Vec\concat(
    Pha\index_get_nodes_by_kind(
      $token_index,
      Pha\KIND_DOUBLE_QUOTED_STRING_LITERAL_HEAD,
    ),
    Pha\index_get_nodes_by_kind(
      $token_index,
      Pha\KIND_HEREDOC_STRING_LITERAL_HEAD,
    ),
  )
    |> Vec\map(
      $$,
      $h ==> LintError::create(
        $script,
        $pragma_map,
        Pha\node_get_parent($script, $h),
        $linter,
        'Avoid string interpolation, consider concatenation or Str\\format(...).',
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/prefer_lambdas_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\Vec;
use namespace HTL\Pha;

function prefer_lambdas_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  Pha\TokenIndex $_,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  return Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_ANONYMOUS_FUNCTION)
    |> Vec\map(
      $$,
      $f ==> LintError::create(
        $script,
        $pragma_map,
        $f,
        $linter,
        'Prefer `() ==> {}` lambdas over `function () {}`.',
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/prefer_require_once_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{Str, Vec};
use namespace HTL\Pha;

function prefer_require_once_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  Pha\TokenIndex $_,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $is_require_once = Pha\create_token_matcher($script, Pha\KIND_REQUIRE_ONCE);
  $get_require_keyword =
    Pha\create_member_accessor($script, Pha\MEMBER_INCLUSION_REQUIRE)
    |> Pha\returns_token($$);

  return
    Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_INCLUSION_EXPRESSION)
    |> Vec\map($$, $get_require_keyword)
    |> Vec\filter($$, $require_token ==> !$is_require_once($require_token))
    |> Vec\map(
      $$,
      $n ==> LintError::createWithPatches(
        $script,
        $pragma_map,
        Pha\node_get_parent($script, $n),
        $linter,
        Str\format(
          'Use require_once instead of %s.',
          Pha\token_get_text($script, $n),
        ),
        Pha\patches(
          $script,
          Pha\patch_node(
            $n,
            'require_once',
            shape('trivia' => Pha\RetainTrivia::BOTH),
          ),
        ),
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/prefer_single_quoted_string_literals_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Str, Vec};
use namespace HTL\Pha;

function prefer_single_quoted_string_literals_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $_,
  Pha\TokenIndex $token_index,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  // hackfmt-ignore
  $escape_sequences = vec[
    '\\e', // ansi escape
    '\\f', // form feed
    '\\t', // horizontal tab
    '\\r', // carriage return
    '\\n', // newline
    '\\u', // unicode codepoint
    '\\v', // vertical tab
    '\\x', // hex
    "'", // single quote,
    '\$', // anti-variable interpolation
    '\\0', '\\1', '\\2', '\\3', '\\4', '\\5', '\\6', '\\7' // octal
  ];

  return Pha\index_get_nodes_by_kind(
    $token_index,
    Pha\KIND_DOUBLE_QUOTED_STRING_LITERAL,
  )
    |> Vec\map(
      $$,
      $t ==> shape(
        'node' => $t,
        'contents' => Pha\token_get_text($script, $t)
          |> Str\strip_prefix($$, '"')
          |> Str\strip_suffix($$, '"'),
      ),
    )
    |> Vec\filter(
      $$,
      $shape ==>
        !C\any($escape_sequences, $e ==> Str\contains($shape['contents'], $e)),
    )
    |> Vec\map(
      $$,
      $shape ==> LintError::createWithPatches(
        $script,
        $pragma_map,
        $shape['node'],
        $linter,
        'This could be a single quoted string.',
        Pha\patches(
          $script,
          Pha\patch_node(
            $shape['node'],
            "'".$shape['contents']."'",
            shape('trivia' => Pha\RetainTrivia::BOTH),
          ),
        ),
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/shout_case_enum_members_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{Str, Vec};
use namespace HTL\Pha;

function shout_case_enum_members_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  Pha\TokenIndex $_,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $get_enumerator =
    Pha\create_member_accessor($script, Pha\MEMBER_ENUMERATOR_NAME)
    |> Pha\returns_token($$);

  return Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_ENUMERATOR)
    |> Vec\filter(
      $$,
      $e ==> $get_enumerator($e)
        |> Pha\token_get_text($script, $$)
        |> Str\uppercase($$) !== $$,
    )
    |> Vec\map(
      $$,
      $e ==> LintError::create(
        $script,
        $pragma_map,
        $e,
        $linter,
        'Rename this enum member to SHOUT_CASE.',
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/unreachable_code_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\Vec;
use namespace HTL\Pha;

function unreachable_code_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  Pha\TokenIndex $_,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $node_is_list = Pha\create_syntax_matcher($script, Pha\KIND_NODE_LIST);
  $creates_unreachable_code = $stmt ==> Pha\node_get_parent($script, $stmt)
    |> $node_is_list($$) && Pha\node_get_last_child($script, $$) !== $stmt;

  return Vec\concat(
    Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_BREAK_STATEMENT),
    Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_CONTINUE_STATEMENT),
    Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_RETURN_STATEMENT),
    Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_THROW_STATEMENT),
  )
    |> Vec\filter($$, $creates_unreachable_code)
    |> Vec\map(
      $$,
      $n ==> LintError::createWithoutPatches(
        $script,
        $pragma_map,
        $n,
        $linter,
        'The code after this statement is unreachable.',
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/unused_pipe_variable_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Vec};
use namespace HTL\Pha;

function unused_pipe_variable_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  Pha\TokenIndex $_,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $is_dollar_dollar = Pha\create_token_matcher($script, Pha\KIND_DOLLAR_DOLLAR);
  $is_pipe_arrow = Pha\create_token_matcher($script, Pha\KIND_BAR_GREATER_THAN);

  $get_binop_operator =
    Pha\create_member_accessor($script, Pha\MEMBER_BINARY_OPERATOR);
  $get_binop_rhs =
    Pha\create_member_accessor($script, Pha\MEMBER_BINARY_RIGHT_OPERAND);

  $is_pipe_expression = $binop ==>
    $get_binop_operator($binop) |> $is_pipe_arrow($$);

  $rhs_uses_dollar_dollar = $binop ==> $get_binop_rhs($binop)
    |> Pha\node_get_descendants($script, $$)
    |> C\any($$, $is_dollar_dollar);

  return Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_BINARY_EXPRESSION)
    |> Vec\filter(
      $$,
      $expr ==> $is_pipe_expression($expr) && !$rhs_uses_dollar_dollar($expr),
    )
    |> Vec\map(
      $$,
      $n ==> LintError::createWithoutPatches(
        $script,
        $pragma_map,
        $n,
        $linter,
        'You did not use the $$ variable on the right hand side of the `|>`.',
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/unused_use_clause_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Keyset, Vec};
use namespace HTL\Pha;

function unused_use_clause_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  Pha\TokenIndex $token_index,
  Pha\Resolver $resolver,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $used_clauses = Vec\concat(
    Pha\index_get_nodes_by_kind($token_index, Pha\KIND_NAME),
    Pha\index_get_nodes_by_kind($token_index, Pha\KIND_XHP_CLASS_NAME),
    Pha\index_get_nodes_by_kind($token_index, Pha\KIND_XHP_ELEMENT_NAME),
  )
    |> Vec\map(
      $$,
      $n ==> Pha\resolve_name_and_use_clause($resolver, $script, $n)[1],
    )
    |> Vec\filter($$, $c ==> $c !== Pha\NIL)
    |> Vec\map($$, Pha\as_syntax<>)
    |> Keyset\map($$, Pha\node_get_id<>);

  return
    Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_NAMESPACE_USE_CLAUSE)
    |> Vec\filter(
      $$,
      $c ==> !C\contains_key($used_clauses, Pha\node_get_id($c)),
    )
    |> Vec\map(
      $$,
      $c ==> LintError::create(
        $script,
        $pragma_map,
        $c,
        $linter,
        'This use clause is not used.',
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/unused_variable_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Dict, Math, Str, Vec};
use namespace HTL\Pha;

// This linter implements unused_variable_linter.
//
// It also doubles as unused_parameter_linter.
// It also triples as unused_lambda_parameter_linter.
//
// These linters are all variations on a theme.
function unused_variable_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $_,
  Pha\TokenIndex $token_index,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $build_matcher = ($first, ...$rest) ==>
    Pha\create_syntax_matcher($script, $first, ...$rest);

  $is_abstract = Pha\create_token_matcher($script, Pha\KIND_ABSTRACT);
  $is_assignment_operator = Support\assignment_operator_matcher($script);
  $is_binary_expression = $build_matcher(Pha\KIND_BINARY_EXPRESSION);
  $is_classish_declaration = $build_matcher(Pha\KIND_CLASSISH_DECLARATION);
  $is_decl_header = $build_matcher(Pha\KIND_FUNCTION_DECLARATION_HEADER);
  $is_foreach = $build_matcher(Pha\KIND_FOREACH_STATEMENT);
  $is_interface = Pha\create_token_matcher($script, Pha\KIND_INTERFACE);
  $is_lambda = $build_matcher(Pha\KIND_LAMBDA_EXPRESSION);
  $is_lambda_signature = $build_matcher(Pha\KIND_LAMBDA_SIGNATURE);
  $is_list_expression = $build_matcher(Pha\KIND_LIST_EXPRESSION);
  $is_member_selection_expression =
    $build_matcher(Pha\KIND_MEMBER_SELECTION_EXPRESSION);
  $is_methodish_declaration = $build_matcher(Pha\KIND_METHODISH_DECLARATION);
  $is_parameter_declaration = $build_matcher(Pha\KIND_PARAMETER_DECLARATION);
  $is_plus_plus_or_minus_minus =
    Pha\create_token_matcher($script, Pha\KIND_PLUS_PLUS, Pha\KIND_MINUS_MINUS);
  $is_scope = $build_matcher(
    Pha\KIND_FUNCTION_DECLARATION,
    Pha\KIND_LAMBDA_EXPRESSION,
    Pha\KIND_METHODISH_DECLARATION,
  );
  $is_unary_expression = $build_matcher(
    Pha\KIND_PREFIX_UNARY_EXPRESSION,
    Pha\KIND_POSTFIX_UNARY_EXPRESSION,
  );

  $get_binop_operator =
    Pha\create_member_accessor($script, Pha\MEMBER_BINARY_OPERATOR);
  $get_class_keyword =
    Pha\create_member_accessor($script, Pha\MEMBER_CLASSISH_KEYWORD);
  $get_foreach_key =
    Pha\create_member_accessor($script, Pha\MEMBER_FOREACH_KEY);
  $get_foreach_value =
    Pha\create_member_accessor($script, Pha\MEMBER_FOREACH_VALUE);
  $get_method_decl_header = Pha\create_member_accessor(
    $script,
    Pha\MEMBER_METHODISH_FUNCTION_DECL_HEADER,
  )
    |> Pha\returns_syntax($$);
  $get_func_decl_header_modifiers =
    Pha\create_member_accessor($script, Pha\MEMBER_FUNCTION_MODIFIERS);
  $get_lambda_signature =
    Pha\create_member_accessor($script, Pha\MEMBER_LAMBDA_SIGNATURE);
  $get_list_expr_members =
    Pha\create_member_accessor($script, Pha\MEMBER_LIST_MEMBERS);
  $get_parameter_name =
    Pha\create_member_accessor($script, Pha\MEMBER_PARAMETER_NAME);
  $get_parameter_visibility =
    Pha\create_member_accessor($script, Pha\MEMBER_PARAMETER_VISIBILITY);
  $get_unary_operator = Pha\create_member_accessor(
    $script,
    Pha\MEMBER_PREFIX_UNARY_OPERATOR,
    Pha\MEMBER_POSTFIX_UNARY_OPERATOR,
  );

  $is_assignment_expression = $node ==> $is_binary_expression($node) &&
    $is_assignment_operator($get_binop_operator($node));

  $is_promoted_contructor_parameter = (Pha\Token $token) ==>
    Pha\node_get_syntax_ancestors($script, $token)
    |> C\find($$, $is_parameter_declaration)
    |> $$ is nonnull && !Pha\is_missing($get_parameter_visibility($$));

  // Assignments to members are not local to the function.
  // This assignment should be classified as a use of `$v`: `$v->prop = 0`.
  $assignment_has_non_local_effects = (
    Pha\Syntax $assignment,
    Pha\Token $var,
  ) ==> Pha\node_get_syntax_ancestors($script, $var)
    |> Support\vec_take_while_inclusive($$, $node ==> $node !== $assignment)
    |> C\any($$, $is_member_selection_expression);

  $inout_scopes = Pha\index_get_nodes_by_kind($token_index, Pha\KIND_INOUT)
    |> Vec\map(
      $$,
      $i ==> Pha\token_get_parent($script, $i)
        |> !$is_parameter_declaration($$)
          ? null
          : shape(
              'name' => $get_parameter_name($$)
                |> Pha\node_get_code_compressed($script, $$),
              'scope' =>
                C\findx(Pha\node_get_ancestors($script, $$), $is_scope),
            ),
    )
    |> Vec\filter_nulls($$)
    |> Dict\group_by($$, $shape ==> $shape['name'])
    |> Dict\map($$, $shapes ==> Vec\map($shapes, $s ==> $s['scope']));

  $classify_use = ($variable): ?Support\TUnusedVariableLinterUsage ==> {
    $ret = shape(
      'is_assignment' => false,
      'param_of_func' => Pha\NIL,
      'param_of_lambda' => Pha\NIL,
      'scopes' => vec[],
      'var' => $variable,
      'var_name' => Pha\token_get_text($script, $variable),
    );

    $is_param =
      $is_parameter_declaration(Pha\node_get_parent($script, $variable));

    $assigns_to_var_local = ($loop_node): bool ==> $is_foreach($loop_node) &&
      (
        $get_foreach_key($loop_node) === $variable ||
        $get_foreach_value($loop_node) === $variable
      ) ||
      (
        $is_assignment_expression($loop_node) &&
        Support\get_first_token($script, $loop_node) === $variable &&
        !$assignment_has_non_local_effects($loop_node, $variable)
      ) ||
      (
        $is_unary_expression($loop_node) &&
        $is_plus_plus_or_minus_minus($get_unary_operator($loop_node))
      ) ||
      (
        $is_list_expression($loop_node) &&
        // Only mark `$a` and `$c` as assigned: `$list($a[$b], $c)`
        C\any(
          $get_list_expr_members($loop_node)
            |> Pha\node_get_children($script, $$),
          $mem ==> Support\get_first_token($script, $mem) === $variable,
        )
      );

    foreach (Pha\node_get_syntax_ancestors($script, $variable) as $node) {
      if ($assigns_to_var_local($node)) {
        $ret['is_assignment'] = true;
      } else if ($is_decl_header($node)) {
        // Very uncommon, let's ignore it. Nasty oversight
        // `function foo((function(int): int) $lambda = $a ==> $a)`.
        if (!C\is_empty($ret['scopes'])) {
          return null;
        }
        $ret['param_of_func'] = $node;
      } else if ($is_lambda_signature($node)) {
        $ret['param_of_lambda'] = Pha\syntax_get_parent($script, $node);
      } else if (
        $is_lambda($node) && $get_lambda_signature($node) === $variable
      ) {
        $ret['param_of_lambda'] = $node;
      }

      if ($is_scope($node)) {
        $ret['scopes'][] = $node;
        // Any assignment to a inout variable should be treated as a use.
        // Reason being, they have effects on the outer scopes / the caller.
        if (
          !$is_param &&
          C\contains(idx($inout_scopes, $ret['var_name'], vec[]), $node)
        ) {
          $ret['is_assignment'] = false;
        }
      }
    }

    return C\is_empty($ret['scopes']) ? null : $ret;
  };

  $apply_shadowing_rules = (
    vec<Support\TUnusedVariableLinterUsage> $usages,
  ): vec<Support\TUnusedVariableLinterAfterShadowing> ==> {
    $lambda_params =
      Vec\filter($usages, $u ==> $u['param_of_lambda'] !== Pha\NIL)
      |> Vec\map(
        $$,
        $u ==> shape(
          'lambda' => Pha\as_nonnil($u['param_of_lambda']),
          'var_name' => $u['var_name'],
        ),
      )
      // Sorting by index DESC, so inner lambdas appear before outer lambdas.
      // `$x ==> $x ==> $x + $y`, where the outer $x is shadowed by the second $x.
      // The outer $x goes unused and should probably have been $y.
      // The above expression closes over a $y in function scope.
      |> Vec\sort_by($$, $u ==> -Pha\node_get_source_order($u['lambda']));

    return Vec\map(
      $usages,
      $u ==> shape(
        'is_assignment' => $u['is_assignment'] ||
          $u['param_of_func'] !== Pha\NIL ||
          $u['param_of_lambda'] !== Pha\NIL,
        'owners' => C\find(
          $lambda_params,
          $l ==> $l['var_name'] === $u['var_name'] &&
            C\contains(
              Pha\node_get_ancestors($script, $u['var']),
              $l['lambda'],
            ),
        )
          |> Shapes::idx($$, 'lambda')
          |> $$ is null ? $u['scopes'] : vec[$$],
        'var' => $u['var'],
        'var_name' => $u['var_name'],
      ),
    );
  };

  $is_abstract_scope = $owner ==> {
    if (!$is_methodish_declaration($owner)) {
      return false;
    }

    $classish = Pha\node_get_syntax_ancestors($script, $owner)
      |> C\findx($$, $is_classish_declaration);

    return $is_interface($get_class_keyword($classish)) ||
      C\any(
        $get_method_decl_header($owner)
          |> $get_func_decl_header_modifiers($$)
          |> Pha\node_get_children($script, $$),
        $is_abstract,
      );
  };

  list($assignments, $usages) =
    Pha\index_get_nodes_by_kind($token_index, Pha\KIND_VARIABLE_TOKEN)
    |> Vec\map($$, $classify_use)
    |> Vec\filter_nulls($$)
    |> Vec\filter($$, $u ==> $u['var_name'] !== '$this')
    |> $apply_shadowing_rules($$)
    |> Vec\partition($$, $u ==> $u['is_assignment']);

  $usages_by_name = Dict\group_by($usages, $u ==> $u['var_name']);

  $is_unused = (Support\TUnusedVariableLinterAfterShadowing $a) ==>
    !Str\starts_with($a['var_name'], '$_') &&
    !$is_promoted_contructor_parameter($a['var']) &&
    !C\any($a['owners'], $is_abstract_scope) &&
    !C\any(
      idx($usages_by_name, $a['var_name'], vec[]),
      $u ==> C\contains(
        $u['owners'],
        // Picking the maximum owner (the inmost lambda), because of this code:
        // $b = 4;
        // () ==> { $b = 5; } // << This $b assignment is unused.
        // use_of($b);
        Math\max_by($a['owners'], Pha\node_get_source_order<>),
      ),
    );

  return Vec\filter($assignments, $is_unused)
    |> Vec\map(
      $$,
      $a ==> LintError::createWithPatches(
        $script,
        $pragma_map,
        Pha\token_get_parent($script, $a['var']),
        $linter,
        'This variable is unused.',
        Pha\patches($script, Pha\patch_node(
          $a['var'],
          Pha\token_get_text($script, $a['var'])
            |> Str\strip_prefix($$, '$')
            |> '$_'.$$,
          shape('trivia' => Pha\RetainTrivia::BOTH),
        )),
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/use_statement_with_as_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\Vec;
use namespace HTL\Pha;

function use_statement_with_as_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  Pha\TokenIndex $_,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $get_as = Pha\create_member_accessor($script, Pha\MEMBER_NAMESPACE_USE_AS);
  $has_as = $n ==> $get_as($n) |> !Pha\is_missing($$);

  return
    Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_NAMESPACE_USE_CLAUSE)
    |> Vec\filter($$, $has_as)
    |> Vec\map(
      $$,
      $n ==> LintError::create(
        $script,
        $pragma_map,
        $n,
        $linter,
        'Use statements may not use the `as` keyword.',
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/use_statement_with_leading_backslash_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\Vec;
use namespace HTL\Pha;

function use_statement_with_leading_backslash_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  Pha\TokenIndex $_,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $is_backslash = Pha\create_token_matcher($script, Pha\KIND_BACKSLASH);

  $get_leading_backslash = $node ==> Support\get_first_token($script, $node);
  $get_prefix = Pha\create_member_accessor(
    $script,
    Pha\MEMBER_NAMESPACE_USE_NAME,
    Pha\MEMBER_NAMESPACE_GROUP_USE_PREFIX,
  );

  return Vec\concat(
    Pha\index_get_nodes_by_kind(
      $syntax_index,
      Pha\KIND_NAMESPACE_GROUP_USE_DECLARATION,
    ),
    Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_NAMESPACE_USE_CLAUSE),
  )
    |> Vec\map($$, $n ==> $get_prefix($n) |> $get_leading_backslash($$))
    |> Vec\filter($$, $is_backslash)
    |> Vec\map(
      $$,
      $n ==> Pha\as_nonnil($n)
        |> LintError::createWithPatches(
          $script,
          $pragma_map,
          $$,
          $linter,
          'The leading backslashes in use declarations do not have an effect. '.
          'You may remove them.',
          Pha\patches(
            $script,
            Pha\patch_node(
              $$,
              '',
              shape('trivia' => Pha\RetainTrivia::LEADING),
            ),
          ),
        ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/use_statement_without_kind_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\Vec;
use namespace HTL\Pha;

function use_statement_without_kind_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  Pha\TokenIndex $_,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $get_kind = Pha\create_member_accessor(
    $script,
    Pha\MEMBER_NAMESPACE_USE_KIND,
    Pha\MEMBER_NAMESPACE_GROUP_USE_KIND,
  );

  $kind_is_missing = $use_clause ==>
    $get_kind($use_clause) |> Pha\is_missing($$);

  return Vec\concat(
    Pha\index_get_nodes_by_kind(
      $syntax_index,
      Pha\KIND_NAMESPACE_USE_DECLARATION,
    ),
    Pha\index_get_nodes_by_kind(
      $syntax_index,
      Pha\KIND_NAMESPACE_GROUP_USE_DECLARATION,
    ),
  )
    |> Vec\filter($$, $kind_is_missing)
    |> Vec\map(
      $$,
      $n ==> LintError::createWithoutPatches(
        $script,
        $pragma_map,
        $n,
        $linter,
        'Must use namespace kind (`type` or `namespace`).',
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/hhast_adapted/whitespace_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\C;
use namespace HTL\Pha;

// This linter implements no_white_space_at_end_of_line_linter.
//
// It also doubles as consistent_line_endings_linter.
// In a unix line ending world, `\r\n` is whitespace at eol, since `\r` is whitespace.
//
// It also triples as must_have_newline_at_end_of_file_linter.
//
// It also quadruples as dont_have_two_empty_lines_in_a_row_linter.
// We are already looking at all the trivia, let's just cram this in here too.
function whitespace_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $_,
  Pha\TokenIndex $_,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $trivia = Pha\script_get_trivia($script);
  $errors = vec[];

  $line_counter = 0;
  $prev_whitespace = false;

  foreach ($trivia as $trivium) {
    $kind = Pha\node_get_kind($script, $trivium);
    $text = Pha\node_get_code($script, $trivium);
    $is_eol = $kind === Pha\KIND_END_OF_LINE;

    // #region dont_have_two_empty_lines_in_a_row_linter
    $is_eof_trivium = $text === '';

    $is_line = (int)$is_eol | (int)$is_eof_trivium;
    $line_counter = $line_counter * $is_line + $is_line;

    if ($line_counter > 2 && !$is_eof_trivium) {
      $errors[] = LintError::create(
        $script,
        $pragma_map,
        $trivium,
        $linter,
        'Too many newlines in a row.',
      );
    }
    // #endregion

    // #region no_whitespace_at_end_of_line_linter | consistent_line_endings_linter
    if ($is_eol && ($prev_whitespace || $text !== "\n")) {
      $errors[] = LintError::create(
        $script,
        $pragma_map,
        $trivium,
        $linter,
        'There is whitespace before the end of this line.',
      );
    }

    $prev_whitespace = $kind === Pha\KIND_WHITESPACE;
    // #endregion
  }

  // #region must_have_newline_at_end_of_file_linter
  if ($line_counter === 1) {
    $errors[] = LintError::create(
      $script,
      $pragma_map,
      C\lastx($trivia),
      $linter,
      'Files must end with one or more newlines.',
    );
  }
  // #endregion

  return $errors;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/pha_native/concat_merge_or_union_expression_can_be_simplified_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Str, Vec};
use namespace HTL\Pha;

function concat_merge_or_union_expression_can_be_simplified_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  Pha\TokenIndex $_,
  Pha\Resolver $resolver,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $get_argument_list =
    Pha\create_member_accessor($script, Pha\MEMBER_FUNCTION_CALL_ARGUMENT_LIST)
    |> Pha\returns_syntax($$);
  $get_call_receiver =
    Pha\create_member_accessor($script, Pha\MEMBER_FUNCTION_CALL_RECEIVER);

  $resolve_function_name = $call ==> $get_call_receiver($call)
    |> Pha\resolve_name($resolver, $script, $$);

  $is_decorated_expression =
    Pha\create_syntax_matcher($script, Pha\KIND_DECORATED_EXPRESSION);

  $is_concat_merge_or_union = $call ==> $resolve_function_name($call)
    |> $$ === 'HH\Lib\Dict\merge' ||
      $$ === 'HH\Lib\Keyset\union' ||
      $$ === 'HH\Lib\Vec\concat';

  $simplified_call = dict[
    'HH\Lib\Dict\merge' => 'dict',
    'HH\Lib\Keyset\union' => 'keyset',
    'HH\Lib\Vec\concat' => 'vec',
  ];

  return Pha\index_get_nodes_by_kind(
    $syntax_index,
    Pha\KIND_FUNCTION_CALL_EXPRESSION,
  )
    |> Vec\filter($$, $call ==> {
      if (!$is_concat_merge_or_union($call)) {
        return false;
      }

      return $get_argument_list($call)
        |> Pha\list_get_items_of_children($script, $$)
        |> C\count($$) === 1 && !$is_decorated_expression($$[0]);
    })
    |> Vec\map(
      $$,
      $call ==> $resolve_function_name($call)
        |> LintError::createWithPatches(
          $script,
          $pragma_map,
          $call,
          $linter,
          Str\format(
            'This call to %s(...) can be simplified to %s(...). '.
            'If the type of the first argument is already %s, '.
            'you do not need to call any function.',
            $$,
            $simplified_call[$$],
            $simplified_call[$$],
          ),
          Pha\patches(
            $script,
            Pha\patch_node(
              $get_call_receiver($call),
              $simplified_call[$$],
              shape('trivia' => Pha\RetainTrivia::BOTH),
            ),
          ),
        ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/pha_native/context_list_must_be_explicit_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\Vec;
use namespace HTL\Pha;

function context_list_must_be_explicit_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  Pha\TokenIndex $_,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $get_contexts = Pha\create_member_accessor(
    $script,
    Pha\MEMBER_FUNCTION_CONTEXTS,
    Pha\MEMBER_CLOSURE_CONTEXTS,
  );

  return Vec\concat(
    Pha\index_get_nodes_by_kind(
      $syntax_index,
      Pha\KIND_FUNCTION_DECLARATION_HEADER,
    ),
    Pha\index_get_nodes_by_kind(
      $syntax_index,
      Pha\KIND_CLOSURE_TYPE_SPECIFIER, //
    ),
  )
    |> Vec\filter($$, $func ==> Pha\is_missing($get_contexts($func)))
    |> Vec\map(
      $$,
      $func ==> LintError::createWithPatches(
        $script,
        $pragma_map,
        $func,
        $linter,
        'This function implicitly uses `[defaults]`. '.
        'If this is intentional, please specify as such. '.
        'If not, please provide a more restrictive context list.',
        Pha\patches(
          $script,
          Pha\patch_node(
            $get_contexts($func),
            '[defaults]',
            shape('trivia' => Pha\RetainTrivia::BOTH),
          ),
        ),
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/pha_native/context_list_must_be_explicit_on_io_functions_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Vec};
use namespace HTL\Pha;

function context_list_must_be_explicit_on_io_functions_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  Pha\TokenIndex $_,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $is_async = Pha\create_token_matcher($script, Pha\KIND_ASYNC);
  $is_await = Pha\create_token_matcher($script, Pha\KIND_AWAIT);

  $get_contexts =
    Pha\create_member_accessor($script, Pha\MEMBER_FUNCTION_CONTEXTS);
  $get_function_modifiers =
    Pha\create_member_accessor($script, Pha\MEMBER_FUNCTION_MODIFIERS);

  return Pha\index_get_nodes_by_kind(
    $syntax_index,
    Pha\KIND_FUNCTION_DECLARATION_HEADER,
  )
    |> Vec\filter($$, $func ==> {
      if (!Pha\is_missing($get_contexts($func))) {
        return false;
      }

      $modifiers =
        $get_function_modifiers($func) |> Pha\node_get_children($script, $$);

      if (!C\any($modifiers, $is_async)) {
        return false;
      }

      return Pha\node_get_parent($script, $func)
        |> Pha\node_get_descendants($script, $$)
        |> C\any($$, $is_await);
    })
    |> Vec\map(
      $$,
      $func ==> LintError::createWithPatches(
        $script,
        $pragma_map,
        $func,
        $linter,
        'This function performs I/O (it contains await), '.
        'so this is likely a good candidate for `[defaults]`.'.
        'If this lint is wrong, add the proper context list.',
        Pha\patches(
          $script,
          Pha\patch_node(
            $get_contexts($func),
            '[defaults]',
            shape('trivia' => Pha\RetainTrivia::BOTH),
          ),
        ),
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/pha_native/count_expression_can_be_simplified_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{Str, Vec};
use namespace HTL\Pha;

function count_expression_can_be_simplified_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  Pha\TokenIndex $_,
  Pha\Resolver $resolver,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $is_binop = Pha\create_syntax_matcher($script, Pha\KIND_BINARY_EXPRESSION);
  $is_equality = Pha\create_token_matcher(
    $script,
    Pha\KIND_EQUAL_EQUAL,
    Pha\KIND_EQUAL_EQUAL_EQUAL,
  );
  $is_exclamation = Pha\create_token_matcher($script, Pha\KIND_EXCLAMATION);
  $is_greater_than = Pha\create_token_matcher($script, Pha\KIND_GREATER_THAN);
  $is_greater_than_or_equal =
    Pha\create_token_matcher($script, Pha\KIND_GREATER_THAN_EQUAL);
  $is_inequality = Pha\create_token_matcher(
    $script,
    Pha\KIND_EXCLAMATION_EQUAL,
    Pha\KIND_EXCLAMATION_EQUAL_EQUAL,
  );
  $is_less_than = Pha\create_token_matcher($script, Pha\KIND_LESS_THAN);
  $is_less_than_or_greater =
    Pha\create_token_matcher($script, Pha\KIND_LESS_THAN_EQUAL);
  $is_prefix_unary_expression =
    Pha\create_syntax_matcher($script, Pha\KIND_PREFIX_UNARY_EXPRESSION);

  $get_argument_list =
    Pha\create_member_accessor($script, Pha\MEMBER_FUNCTION_CALL_ARGUMENT_LIST);
  $get_binop_lhs =
    Pha\create_member_accessor($script, Pha\MEMBER_BINARY_LEFT_OPERAND);
  $get_binop_operator =
    Pha\create_member_accessor($script, Pha\MEMBER_BINARY_OPERATOR);
  $get_binop_rhs =
    Pha\create_member_accessor($script, Pha\MEMBER_BINARY_RIGHT_OPERAND);
  $get_call_receiver =
    Pha\create_member_accessor($script, Pha\MEMBER_FUNCTION_CALL_RECEIVER);
  $get_prefix_operator =
    Pha\create_member_accessor($script, Pha\MEMBER_PREFIX_UNARY_OPERATOR);

  $is_c_count = $call ==> $get_call_receiver($call)
    |> Pha\resolve_name($resolver, $script, $$) === 'HH\Lib\C\count';

  $is_logical_not = $n ==> $is_prefix_unary_expression($n) &&
    $is_exclamation($get_prefix_operator($n));

  $classify_cmp_kind = $n ==> {
    if ($is_equality($n)) {
      return Support\ComparisonKind::EQUALS;
    }
    if ($is_inequality($n)) {
      return Support\ComparisonKind::NOT_EQUALS;
    }
    if ($is_less_than($n)) {
      return Support\ComparisonKind::LESS_THAN;
    }
    if ($is_less_than_or_greater($n)) {
      return Support\ComparisonKind::LESS_THAN_OR_EQUAL;
    }
    if ($is_greater_than($n)) {
      return Support\ComparisonKind::GREATER_THAN;
    }
    if ($is_greater_than_or_equal($n)) {
      return Support\ComparisonKind::GREATER_THAN_OR_EQUAL;
    }
    return null;
  };

  $get_error = ($parent, $call) ==> {
    $replace_with = $function_name ==> Pha\patches($script, Pha\patch_node(
      $parent,
      Str\format(
        '%s(%s)',
        $function_name,
        Pha\node_get_code($script, $get_argument_list($call)),
      ),
      shape('trivia' => Pha\RetainTrivia::BOTH),
    ));

    if ($is_logical_not($parent)) {
      return tuple(
        '!C\count(...) is equivalent to C\is_empty(...)',
        $replace_with('C\\is_empty'),
      );
    }

    if (!$is_binop($parent)) {
      return tuple('', null);
    }

    $cmp_kind = $classify_cmp_kind($get_binop_operator($parent));

    if ($cmp_kind is null) {
      return tuple('', null);
    }

    // Need this because of yoda conditions `0 === C\count(...)`.
    // In Hack, `C\count(...) === 0` is canonical.
    $is_canonical = $get_binop_lhs($parent) === $call;
    $cmp = $is_canonical ? $get_binop_rhs($parent) : $get_binop_lhs($parent)
      |> Pha\node_get_code_compressed($script, $$);

    if (!$is_canonical) {
      switch ($cmp_kind) {
        case Support\ComparisonKind::EQUALS:
        case Support\ComparisonKind::NOT_EQUALS:
          break;
        case Support\ComparisonKind::LESS_THAN:
          $cmp_kind = Support\ComparisonKind::GREATER_THAN;
          break;
        case Support\ComparisonKind::LESS_THAN_OR_EQUAL:
          $cmp_kind = Support\ComparisonKind::GREATER_THAN_OR_EQUAL;
          break;
        case Support\ComparisonKind::GREATER_THAN:
          $cmp_kind = Support\ComparisonKind::LESS_THAN;
          break;
        case Support\ComparisonKind::GREATER_THAN_OR_EQUAL:
          $cmp_kind = Support\ComparisonKind::LESS_THAN_OR_EQUAL;
      }
    }

    if ($cmp === '0') {
      switch ($cmp_kind) {
        case Support\ComparisonKind::EQUALS:
          return tuple(
            'C\count(...) === 0 is equivalent to C\is_empty(...)',
            $replace_with('C\\is_empty'),
          );

        case Support\ComparisonKind::NOT_EQUALS:
          return tuple(
            'C\count(...) !== 0 is equivalent to !C\is_empty(...)',
            $replace_with('!C\\is_empty'),
          );
        case Support\ComparisonKind::LESS_THAN:
          return tuple(
            'C\count(...) < 0 is always false, counts are never negative',
            null,
          );
        case Support\ComparisonKind::LESS_THAN_OR_EQUAL:
          return tuple(
            'C\count(...) <= 0 is equivalent to C\is_empty(...)',
            $replace_with('C\\is_empty'),
          );
        case Support\ComparisonKind::GREATER_THAN:
          return tuple(
            'C\count(...) > 0 is equivalent to !C\is_empty(...)',
            $replace_with('!C\\is_empty'),
          );
        case Support\ComparisonKind::GREATER_THAN_OR_EQUAL:
          return tuple(
            'C\count(...) >= 0 is always true, counts are never negative',
            null,
          );
      }
    }

    if ($cmp !== '1') {
      return tuple('', null);
    }

    switch ($cmp_kind) {
      case Support\ComparisonKind::EQUALS:
      case Support\ComparisonKind::NOT_EQUALS:
        return tuple('', null);
      case Support\ComparisonKind::LESS_THAN:
        return tuple(
          'C\count(...) < 1 is equivalent to C\is_empty(...)',
          $replace_with('C\\is_empty'),
        );
      case Support\ComparisonKind::LESS_THAN_OR_EQUAL:
      case Support\ComparisonKind::GREATER_THAN:
        return tuple('', null);
      case Support\ComparisonKind::GREATER_THAN_OR_EQUAL:
        return tuple(
          'C\count(...) >= 1 is equivalent to !C\is_empty(...)',
          $replace_with('!C\\is_empty'),
        );
    }
  };

  return Pha\index_get_nodes_by_kind(
    $syntax_index,
    Pha\KIND_FUNCTION_CALL_EXPRESSION,
  )
    |> Vec\filter($$, $is_c_count)
    |> Vec\map(
      $$,
      $c ==> Pha\syntax_get_parent($script, $c)
        |> shape('node' => $$, 'error' => $get_error($$, $c)),
    )
    |> Vec\filter($$, $e ==> $e['error'][0] !== '')
    |> Vec\map(
      $$,
      $e ==> LintError::createWithPatches(
        $script,
        $pragma_map,
        $e['node'],
        $linter,
        Str\format('This expression can be simplified, %s.', $e['error'][0]),
        $e['error'][1],
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/pha_native/generated_file_may_not_be_modified_manually_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HTL\Pha;

function generated_file_may_not_be_modified_manually_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $_,
  Pha\TokenIndex $_,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $digest = Support\extract_digest($script, $pragma_map);

  return $digest is null || $digest['embedded'] === $digest['hashed']
    ? vec[]
    : vec[LintError::createWithoutPatches(
      $script,
      $pragma_map,
      Pha\SCRIPT_NODE,
      $linter,
      'This file was generated with a code generator and should not be edited by hand.',
    )];
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/pha_native/getter_method_could_have_a_context_list_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{Regex, Vec};
use namespace HTL\Pha;

function getter_method_could_have_a_context_list_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  Pha\TokenIndex $_,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $get_compound_statement_statements =
    Pha\create_member_accessor($script, Pha\MEMBER_COMPOUND_STATEMENTS);
  $get_function_contexts =
    Pha\create_member_accessor($script, Pha\MEMBER_FUNCTION_CONTEXTS);
  $get_function_name =
    Pha\create_member_accessor($script, Pha\MEMBER_FUNCTION_NAME);
  $get_method_decl_header = Pha\create_member_accessor(
    $script,
    Pha\MEMBER_METHODISH_FUNCTION_DECL_HEADER,
  )
    |> Pha\returns_syntax($$);
  $get_method_body =
    Pha\create_member_accessor($script, Pha\MEMBER_METHODISH_FUNCTION_BODY);
  $get_return_expression =
    Pha\create_member_accessor($script, Pha\MEMBER_RETURN_EXPRESSION);

  $is_compound_statement =
    Pha\create_syntax_matcher($script, Pha\KIND_COMPOUND_STATEMENT);
  $is_return_statement =
    Pha\create_syntax_matcher($script, Pha\KIND_RETURN_STATEMENT);

  return
    Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_METHODISH_DECLARATION)
    |> Vec\filter($$, $m ==> {
      $header = $get_method_decl_header($m);

      if (!Pha\is_missing($get_function_contexts($header))) {
        return false;
      }

      $function_name = $get_function_name($header)
        |> Pha\node_get_code_compressed($script, $$);

      if (!Regex\matches($function_name, re'/^(get|has|is)[A-Z]/')) {
        return false;
      }

      $method_body = $get_method_body($m);

      if (!$is_compound_statement($method_body)) {
        return false;
      }

      $first_statement = $method_body
        |> Pha\as_syntax($$)
        |> $get_compound_statement_statements($$)
        |> Pha\node_get_first_child($script, $$);

      if (!$is_return_statement($first_statement)) {
        return false;
      }

      return $first_statement
        |> Pha\as_syntax($$)
        |> $get_return_expression($$)
        |> Pha\node_get_code_compressed($script, $$)
        // This is a rather crude heuristic.
        // It matches `$this->it`, `$this->it as Type`, and `$this->it is Type`.
        // The idea is to have little false positives.
        // A false negative, such as `$this->it < 6` is fine.
        // This could be a getter, but maybe this is simple
        // as an implementation detail, who knows?
        |> Regex\matches($$, re'/^\$this->(\w)+$/');
    })
    |> Vec\map(
      $$,
      $method_decl_header ==> LintError::createWithPatches(
        $script,
        $pragma_map,
        $method_decl_header,
        $linter,
        'This method is heuristically a simple getter. '.
        'Simple getters can be marked pure using the `[]` syntax. '.
        "The current heuristic is rather crude:\n".
        " - method name looks like getIt, hasIt, or isIt\n".
        " - method body is a single return statement accessing a property on \$this\n".
        'If you have a common false positive, please improve this heuristic.',
        Pha\patches(
          $script,
          Pha\patch_node(
            $method_decl_header
              |> $get_method_decl_header($$)
              |> $get_function_contexts($$),
            '[]',
            shape('trivia' => Pha\RetainTrivia::BOTH),
          ),
        ),
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/pha_native/lambda_parameter_list_parentheses_can_be_removed_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Vec};
use namespace HTL\Pha;

function lambda_parameter_list_parentheses_can_be_removed_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  Pha\TokenIndex $_,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $is_decorated_expression =
    Pha\create_syntax_matcher($script, Pha\KIND_DECORATED_EXPRESSION);
  $is_dot_dot_dot = Pha\create_token_matcher($script, Pha\KIND_DOT_DOT_DOT);

  $get_colon = Pha\create_member_accessor($script, Pha\MEMBER_LAMBDA_COLON);
  $get_contexts =
    Pha\create_member_accessor($script, Pha\MEMBER_LAMBDA_CONTEXTS);
  $get_parameters =
    Pha\create_member_accessor($script, Pha\MEMBER_LAMBDA_PARAMETERS)
    |> Pha\returns_syntax($$);

  $get_parameter_attribute =
    Pha\create_member_accessor($script, Pha\MEMBER_PARAMETER_ATTRIBUTE);
  $get_parameter_call_conv =
    Pha\create_member_accessor($script, Pha\MEMBER_PARAMETER_CALL_CONVENTION);
  $get_parameter_default_value =
    Pha\create_member_accessor($script, Pha\MEMBER_PARAMETER_DEFAULT_VALUE);
  $get_parameter_name =
    Pha\create_member_accessor($script, Pha\MEMBER_PARAMETER_NAME);
  $get_parameter_readonly =
    Pha\create_member_accessor($script, Pha\MEMBER_PARAMETER_READONLY);
  $get_parameter_type =
    Pha\create_member_accessor($script, Pha\MEMBER_PARAMETER_TYPE);

  return Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_LAMBDA_SIGNATURE)
    |> Vec\filter($$, $sig ==> {
      $params = $get_parameters($sig)
        |> Pha\list_get_items_of_children($script, $$);

      if (C\count($params) !== 1) {
        return false;
      }

      $param = Pha\as_syntax($params[0]);

      if (
        C\any(
          vec[
            $get_parameter_attribute,
            $get_parameter_call_conv,
            $get_parameter_default_value,
            $get_parameter_readonly,
            $get_parameter_type,
          ],
          $getter ==> !Pha\is_missing($getter($param)),
        )
      ) {
        return false;
      }

      if ($get_parameter_name($param) |> $is_decorated_expression($$)) {
        return false;
      }

      if (
        $get_parameter_name($param)
        |> Support\get_last_token($script, $$)
        |> Support\get_previous_token($script, $$)
        |> $is_dot_dot_dot($$)
      ) {
        return false;
      }

      return
        Pha\is_missing($get_colon($sig)) && Pha\is_missing($get_contexts($sig));
    })
    |> Vec\map(
      $$,
      $sig ==> LintError::createWithPatches(
        $script,
        $pragma_map,
        $sig,
        $linter,
        'The parentheses around this lambda parameter are redundant and can be removed.',
        Pha\patches($script, Pha\patch_node(
          $sig,
          $get_parameters($sig)
            |> Pha\list_get_items_of_children($script, $$)[0]
            |> Pha\node_get_code($script, $$),
          shape('trivia' => Pha\RetainTrivia::BOTH),
        )),
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/pha_native/pragma_could_not_be_parsed_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Str, Vec};
use namespace HTL\Pha;

function pragma_could_not_be_parsed_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $_,
  Pha\TokenIndex $_,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $is_attribute_specification = Pha\create_syntax_matcher(
    $script,
    Pha\KIND_FILE_ATTRIBUTE_SPECIFICATION,
    Pha\KIND_OLD_ATTRIBUTE_SPECIFICATION,
  );
  $is_call_expression =
    Pha\create_syntax_matcher($script, Pha\KIND_FUNCTION_CALL_EXPRESSION);

  $get_attributes = Pha\create_member_accessor(
    $script,
    Pha\MEMBER_FILE_ATTRIBUTE_SPECIFICATION_ATTRIBUTES,
    Pha\MEMBER_OLD_ATTRIBUTE_SPECIFICATION_ATTRIBUTES,
  )
    |> Pha\returns_syntax($$);
  $get_constructor_call_argument_list = Pha\create_member_accessor(
    $script,
    Pha\MEMBER_CONSTRUCTOR_CALL_ARGUMENT_LIST,
  )
    |> Pha\returns_syntax($$);

  $create_autofix = $pragma ==> {
    if ($is_call_expression($pragma)) {
      $parent = Pha\node_get_parent($script, $pragma);
      return Pha\patch_node(
        $parent,
        '',
        shape('trivia' => Pha\RetainTrivia::NEITHER),
      );
    }

    $noop_patch = Pha\patch_node($pragma, Pha\node_get_code($script, $pragma));

    $has_exactly_one_argument = $get_constructor_call_argument_list($pragma)
      |> Pha\list_get_items_of_children($script, $$)
      |> C\count($$) === 1;

    if (!$has_exactly_one_argument) {
      return $noop_patch;
    }

    $specification = Pha\node_get_syntax_ancestors($script, $pragma)
      |> C\findx($$, $is_attribute_specification);

    $is_exclusively_a_pragma = $get_attributes($specification)
      |> Pha\list_get_items_of_children($script, $$)
      |> C\count($$) === 1;

    return $is_exclusively_a_pragma
      ? Pha\patch_node(
          $specification,
          '',
          shape('trivia' => Pha\RetainTrivia::LEADING),
        )
      : Pha\patch_node(Pha\node_get_parent($script, $pragma), '');
  };

  return $pragma_map->getAllPragmas()
    |> Vec\filter(
      $$,
      $p ==> idx($p[2], 0, '')
        |> Str\trim($$, '"\'')
        |> $$ === 'PhaLinters' || $$ === 'HTL\PhaLinters',
    )
    |> Vec\filter(
      $$,
      $t ==> Vec\drop($t[2], 1)
        |> Vec\map($$, $str ==> Str\trim($str, '"\''))
        |> C\find(
          $$,
          $str ==> !(
            Str\starts_with($str, 'digest:') || Str\starts_with($str, 'fixme:')
          ),
        ) is nonnull,
    )
    |> Vec\map(
      $$,
      $p ==> LintError::createWithPatches(
        $script,
        $pragma_map,
        $p[0],
        $linter,
        'Your version of PhaLinters only supports digest:hash and fixme:linter_name',
        Pha\patches($script, $create_autofix($p[0])),
      ),
    );

}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/pha_native/pragma_prefix_unknown_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Str, Vec};
use namespace HTL\Pha;

function pragma_prefix_unknown_linter(
  Pha\Script $script,
  Pha\PragmaMap $pragma_map,
  keyset<string> $known_pragma_prefixes,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  return $pragma_map->getAllPragmas()
    |> Vec\filter(
      $$,
      $p ==> $p[2][0]
        |> Str\trim($$, '"\'')
        |> !C\contains_key($known_pragma_prefixes, $$),
    )
    |> Vec\map(
      $$,
      $p ==> LintError::create(
        $script,
        $pragma_map,
        $p[0],
        $linter,
        'This pragma prefix is not known. '.
        'Known prefixes: '.
        Str\join($known_pragma_prefixes, ', '),
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/pha_native/shape_type_additional_field_intent_should_be_explicit_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Str, Vec};
use namespace HTL\Pha;

function shape_type_additional_field_intent_should_be_explicit_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  Pha\PragmaMap $pragma_map,
  string $closed_shape_marker,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $get_shape_fields =
    Pha\create_member_accessor($script, Pha\MEMBER_SHAPE_TYPE_FIELDS)
    |> Pha\returns_syntax($$);
  $get_shape_left_paren =
    Pha\create_member_accessor($script, Pha\MEMBER_SHAPE_TYPE_LEFT_PAREN);
  $get_shape_right_paren =
    Pha\create_member_accessor($script, Pha\MEMBER_SHAPE_TYPE_RIGHT_PAREN);
  $get_shape_ellipsis =
    Pha\create_member_accessor($script, Pha\MEMBER_SHAPE_TYPE_ELLIPSIS);

  return
    Pha\index_get_nodes_by_kind($syntax_index, Pha\KIND_SHAPE_TYPE_SPECIFIER)
    |> Vec\filter($$, $shape ==> {
      if (!Pha\is_missing($get_shape_ellipsis($shape))) {
        return false;
      }

      $right_paren = $get_shape_right_paren($shape);

      $token_before_right_paren = $get_shape_fields($shape)
        |> Pha\node_get_children($script, $$)
        |> C\last($$)
        |> $$ is nonnull
          ? Support\get_last_token($script, $$)
          : $get_shape_left_paren($shape);

      return !C\any(
        vec[$token_before_right_paren, $right_paren],
        $x ==> Pha\node_get_code($script, $x)
          |> Str\contains($$, $closed_shape_marker),
      );
    })
    |> Vec\map(
      $$,
      $shape ==> LintError::createWithPatches(
        $script,
        $pragma_map,
        $shape,
        $linter,
        'The intent of whether this shape accepts additional fields is not expliticly expressed. '.
        'If you intended to accept these fields, and any number of unspecified fields, '.
        'add `, ...` after the last field. If you can not want to accept additional fields, add '.
        $closed_shape_marker.
        ' before the closing parenthesis.',
        Pha\patches(
          $script,
          Pha\patch_node(
            $get_shape_right_paren($shape),
            $closed_shape_marker.
            "\n".
            Pha\node_get_code($script, $get_shape_right_paren($shape)),
            shape('trivia' => Pha\RetainTrivia::NEITHER),
          ),
        ),
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/pha_native/solitary_escape_sequences_should_be_disambiguated_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Str, Vec};
use namespace HTL\Pha;

function solitary_escape_sequences_should_be_disambiguated_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $_,
  Pha\TokenIndex $token_index,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $escape_chars = keyset['e', 'f', 't', 'r', 'n', 'u', 'v', 'x'];

  return Pha\index_get_nodes_by_kind(
    $token_index,
    Pha\KIND_SINGLE_QUOTED_STRING_LITERAL,
  )
    |> Vec\map(
      $$,
      $str ==> shape(
        'node' => $str,
        'contents' => Pha\token_get_text($script, $str)
          |> Str\strip_prefix($$, "'")
          |> Str\strip_suffix($$, "'"),
      ),
    )
    |> Vec\filter($$, $shape ==> {
      $contents = $shape['contents'];
      return Str\length($contents) === 2 &&
        $contents[0] === '\\' &&
        (
          C\contains_key($escape_chars, $contents[1]) ||
          \ctype_digit($contents[1])
        );
    })
    |> Vec\map(
      $$,
      $shape ==> LintError::createWithPatches(
        $script,
        $pragma_map,
        $shape['node'],
        $linter,
        'This string literal represents the literal text '.
        $shape['contents'].
        '. The escape sequence is not evaluated. This string could be confused '.
        'for a character literal (which evaluates the escape sequence) by '.
        'developers with experience in another language with C heritage. To '.
        'avoid this confusion, please add a leading backslash to make this '.
        'string visually distinct from character literals from other languages.',
        Pha\patches(
          $script,
          Pha\patch_node(
            $shape['node'],
            "'".Str\replace($shape['contents'], '\\', '\\\\')."'",
            shape('trivia' => Pha\RetainTrivia::BOTH),
          ),
        ),
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/linters/pha_native/variable_name_must_be_lowercase_linter.hack /////
namespace HTL\PhaLinters {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Str, Vec};
use namespace HTL\Pha;

function variable_name_must_be_lowercase_linter(
  Pha\Script $script,
  Pha\SyntaxIndex $_,
  Pha\TokenIndex $token_index,
  Pha\Resolver $_,
  Pha\PragmaMap $pragma_map,
)[]: vec<LintError> {
  $linter = __FUNCTION__;

  $is_methodish_declaration =
    Pha\create_syntax_matcher($script, Pha\KIND_METHODISH_DECLARATION);
  $is_property_declarator =
    Pha\create_syntax_matcher($script, Pha\KIND_PROPERTY_DECLARATOR);
  $is_scope_resolution_expression =
    Pha\create_syntax_matcher($script, Pha\KIND_SCOPE_RESOLUTION_EXPRESSION);

  $get_methodish_declaration_header = Pha\create_member_accessor(
    $script,
    Pha\MEMBER_METHODISH_FUNCTION_DECL_HEADER,
  )
    |> Pha\returns_syntax($$);
  $get_parameter_list =
    Pha\create_member_accessor($script, Pha\MEMBER_FUNCTION_PARAMETER_LIST)
    |> Pha\returns_syntax($$);
  $get_parameter_name =
    Pha\create_member_accessor($script, Pha\MEMBER_PARAMETER_NAME)
    |> Pha\returns_token($$);
  $get_parameter_visibility =
    Pha\create_member_accessor($script, Pha\MEMBER_PARAMETER_VISIBILITY);

  return Pha\index_get_nodes_by_kind($token_index, Pha\KIND_VARIABLE_TOKEN)
    |> Vec\filter($$, $var ==> {
      $var_name = Pha\token_get_text($script, $var);
      if ($var_name === Str\lowercase($var_name)) {
        return false;
      }

      $parent = Pha\token_get_parent($script, $var);

      if (
        $is_property_declarator($parent) ||
        $is_scope_resolution_expression($parent) &&
          Pha\node_get_last_childx($script, $parent) === $var
      ) {
        return false;
      }

      $method_decl = Pha\node_get_syntax_ancestors($script, $var)
        |> C\find($$, $is_methodish_declaration);

      if ($method_decl is null) {
        return true;
      }

      // __construct(private typename $camelCase) { validate($camelCase); }
      return $get_methodish_declaration_header($method_decl)
        |> $get_parameter_list($$)
        |> Pha\list_get_items_of_children($script, $$)
        |> !C\any($$, $param ==> {
          $param = Pha\as_syntax($param);
          $param_name =
            $get_parameter_name($param) |> Pha\token_get_text($script, $$);
          return $param_name === $var_name &&
            !Pha\is_missing($get_parameter_visibility($param));
        });
    })
    |> Vec\map(
      $$,
      $var ==> LintError::create(
        $script,
        $pragma_map,
        $var,
        $linter,
        'Local variables should be $snake_case and may therefore not contain uppercase letters.',
      ),
    );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/support/CallingConvention.hack /////
namespace HTL\PhaLinters\Support {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


enum CallingCovention: int {
  PLAIN = 0;
  INOUT = 1;
  VARIADIC = 2;
  OTHER = 3;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/support/ComparisonKind.hack /////
namespace HTL\PhaLinters\Support {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


enum ComparisonKind: int {
  EQUALS = 0;
  NOT_EQUALS = 1;
  LESS_THAN = 2;
  LESS_THAN_OR_EQUAL = 3;
  GREATER_THAN = 4;
  GREATER_THAN_OR_EQUAL = 5;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/support/TUnusedVariableLinterUsage.hack /////
namespace HTL\PhaLinters\Support {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HTL\Pha;

type TUnusedVariableLinterUsage = shape(
  'is_assignment' => bool,
  'param_of_func' => Pha\NillableSyntax,
  'param_of_lambda' => Pha\NillableSyntax,
  'scopes' => vec<Pha\Syntax>,
  'var' => Pha\Token,
  'var_name' => string,
  /*_*/
);
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/support/TUnusedVariableLinterUsageAfterShadowing.hack /////
namespace HTL\PhaLinters\Support {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HTL\Pha;

type TUnusedVariableLinterAfterShadowing = shape(
  'is_assignment' => bool,
  'owners' => vec<Pha\Syntax>,
  'var' => Pha\Token,
  'var_name' => string,
  /*_*/
);
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/support/UseKind.hack /////
namespace HTL\PhaLinters\Support {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


enum UseKind: int {
  CONST = 0;
  FUNCTION = 1;
  NAMESPACE = 2;
  TYPE = 3;
  NONE = 4;
}

const vec<UseKind> REAL_USE_KINDS =
  vec[UseKind::CONST, UseKind::FUNCTION, UseKind::NAMESPACE, UseKind::TYPE];
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/support/dict_merge_by_concatting_values.hack /////
namespace HTL\PhaLinters\Support {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Vec};

function dict_merge_by_concatting_values<Tk as arraykey, Tv>(
  KeyedTraversable<Tk, vec<Tv>> $first,
  KeyedTraversable<Tk, Container<Tv>> ...$rest
)[]: dict<Tk, vec<Tv>> {
  $out = dict($first);

  foreach ($rest as $r) {
    foreach ($r as $k => $vs) {
      if (C\contains_key($out, $k)) {
        $out[$k] = Vec\concat($out[$k], $vs);
      } else {
        $out[$k] = vec($vs);
      }
    }
  }

  return $out;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/support/enforce_naming.hack /////
namespace HTL\PhaLinters\Support {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Str, Vec};
use namespace HTL\Pha;

function enforce_naming(
  Pha\Script $script,
  Pha\SyntaxIndex $syntax_index,
  (function(string, Pha\Syntax)[_]: bool) $function_name_func,
  (function(string, Pha\Syntax)[_]: bool) $method_name_func,
  ?vec<string> $allowed_suffixes = null,
)[ctx $function_name_func, ctx $method_name_func]: vec<Pha\Syntax> {
  $allowed_suffixes ??= vec[
    '__DEPRECATED',
    '__DO_NOT_USE',
    '__UNTYPED',
    '__UNSAFE',
    '_DEPRECATED',
    '_DO_NOT_USE',
    '_UNTYPED',
    '_UNSAFE',
  ];

  $is_function_declaration =
    Pha\create_syntax_matcher($script, Pha\KIND_FUNCTION_DECLARATION);

  $get_function_name =
    Pha\create_member_accessor($script, Pha\MEMBER_FUNCTION_NAME)
    |> Pha\returns_token($$);

  $get_function_name_as_text = $decl ==> $get_function_name($decl)
    |> Pha\token_get_text($script, $$)
    |> C\reduce($allowed_suffixes, Str\strip_suffix<>, $$);

  list($function_decls, $method_decls) = Pha\index_get_nodes_by_kind(
    $syntax_index,
    Pha\KIND_FUNCTION_DECLARATION_HEADER,
  )
    |> Vec\partition(
      $$,
      $h ==> $is_function_declaration(Pha\node_get_parent($script, $h)),
    );

  return Vec\concat(
    Vec\filter(
      $function_decls,
      $d ==> $function_name_func($get_function_name_as_text($d), $d),
    ),
    Vec\filter(
      $method_decls,
      $d ==> $method_name_func($get_function_name_as_text($d), $d),
    ),
  );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/support/extract_digest.hack /////
namespace HTL\PhaLinters\Support {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Str};
use namespace HTL\Pha;
use function sha1;

function extract_digest(
  Pha\Script $script,
  Pha\PragmaMap $pragma_map,
)[]: ?shape(
  'pragma' => Pha\Syntax,
  'embedded' => string,
  'hashed' => string,
  /*_*/
) {
  list($pragma, $digest) = $pragma_map->getAllPragmas()
    |> C\find(
      $$,
      $p ==> C\count($p[2]) === 2 &&
        (
          Str\trim($p[2][0], '"\'')
          |> $$ === 'PhaLinters' || $$ === 'HTL\\PhaLinters'
        ) &&
        (Str\trim($p[2][1], '"\'') |> Str\starts_with($$, 'digest:')),
    )
    |> $$ is nonnull
      ? tuple(
          $$[0],
          Str\trim($$[2][1], '"\'') |> Str\strip_prefix($$, 'digest:'),
        )
      : tuple(null, '');

  if ($pragma is null) {
    return null;
  }

  return Pha\node_get_code($script, Pha\SCRIPT_NODE)
    |> Str\replace($$, $digest, '')
    |> sha1($$)
    |> Str\slice($$, 0, 20)
    |> shape('pragma' => $pragma, 'embedded' => $digest, 'hashed' => $$);
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/support/get_first_token.hack /////
namespace HTL\PhaLinters\Support {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\C;
use namespace HTL\Pha;

function get_first_token(
  Pha\Script $script,
  Pha\NillableNode $node,
)[]: Pha\NillableToken {
  return Pha\as_token_or_nil(
    !Pha\is_token($node)
      ? Pha\node_get_descendants($script, $node)
        |> C\find($$, Pha\is_token<>) ?? Pha\NIL
      : $node,
  );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/support/get_flattened_namespace_uses.hack /////
namespace HTL\PhaLinters\Support {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{Dict, Vec};
use namespace HTL\Pha;

function get_flattened_namespace_uses(
  Pha\Script $script,
  vec<Pha\Syntax> $use_declarations,
  vec<Pha\Syntax> $group_use_declarations,
)[]: dict<UseKind, vec<(Pha\Syntax, string)>> {
  $is_const = Pha\create_token_matcher($script, Pha\KIND_CONST);
  $is_function = Pha\create_token_matcher($script, Pha\KIND_FUNCTION);
  $is_namespace = Pha\create_token_matcher($script, Pha\KIND_NAMESPACE);
  $is_type = Pha\create_token_matcher($script, Pha\KIND_TYPE);

  $get_kind = Pha\create_member_accessor(
    $script,
    Pha\MEMBER_NAMESPACE_USE_KIND,
    Pha\MEMBER_NAMESPACE_GROUP_USE_KIND,
  );

  $get_grouped_prefix =
    Pha\create_member_accessor($script, Pha\MEMBER_NAMESPACE_GROUP_USE_PREFIX);
  $get_clauses = Pha\create_member_accessor(
    $script,
    Pha\MEMBER_NAMESPACE_USE_CLAUSES,
    Pha\MEMBER_NAMESPACE_GROUP_USE_CLAUSES,
  )
    |> Pha\returns_syntax($$);
  $get_clause_name =
    Pha\create_member_accessor($script, Pha\MEMBER_NAMESPACE_USE_NAME);

  $parse_clause = $clause ==>
    $get_clause_name($clause) |> Pha\node_get_code_compressed($script, $$);

  $parse_group_prefix = $use ==> $get_grouped_prefix($use)
    |> Pha\node_get_code_compressed($script, $$);

  $get_kind_as_enum = $use ==> $get_kind($use)
    |> $is_const($$)
      ? UseKind::CONST
      : (
          $is_function($$)
            ? UseKind::FUNCTION
            : (
                $is_namespace($$)
                  ? UseKind::NAMESPACE
                  : ($is_type($$) ? UseKind::TYPE : UseKind::NONE)
              )
        );

  $use_clauses = Dict\group_by($use_declarations, $get_kind_as_enum)
    |> Dict\map(
      $$,
      $uses ==> Vec\map(
        $uses,
        $u ==> Pha\as_syntax($u)
          |> $get_clauses($$)
          |> Pha\list_get_items_of_children($script, $$),
      )
        |> Vec\flatten($$)
        |> Vec\map(
          $$,
          $c ==> Pha\as_syntax($c) |> tuple($$, $parse_clause($$)),
        ),
    );

  $grouped_uses = Dict\group_by($group_use_declarations, $get_kind_as_enum)
    |> Dict\map(
      $$,
      $v ==> Vec\map($v, $u ==> {
        $prefix = $parse_group_prefix($u);
        return $get_clauses($u)
          |> Pha\list_get_items_of_children($script, $$)
          |> Vec\map(
            $$,
            $c ==>
              Pha\as_syntax($c) |> tuple($$, $prefix.'\\'.$parse_clause($$)),
          );
      })
        |> Vec\flatten($$),
    );

  return dict_merge_by_concatting_values($use_clauses, $grouped_uses);
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/support/get_last_token.hack /////
namespace HTL\PhaLinters\Support {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Vec};
use namespace HTL\Pha;

function get_last_token(
  Pha\Script $script,
  Pha\NillableNode $node,
)[]: Pha\NillableToken {
  return Pha\as_token_or_nil(
    !Pha\is_token($node)
      ? Pha\node_get_descendants($script, $node)
        |> Vec\reverse($$)
        |> C\find($$, Pha\is_token<>) ?? Pha\NIL
      : $node,
  );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/support/get_previous_token.hack /////
namespace HTL\PhaLinters\Support {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HTL\Pha;

function get_previous_token(
  Pha\Script $script,
  Pha\NillableNode $node,
)[]: Pha\NillableToken {
  if ($node === Pha\NIL) {
    return Pha\NIL_TOKEN;
  }

  $family = Pha\as_nonnil($node)
    |> Pha\node_get_parent($script, $$)
    |> Pha\node_get_descendants($script, $$);

  $previous_token = Pha\NIL_TOKEN;
  foreach ($family as $f) {
    if ($f === $node) {
      break;
    }

    if (Pha\is_token($f)) {
      $previous_token = Pha\as_token($f);
    }
  }

  return $previous_token;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/support/insert_digest.hack /////
namespace HTL\PhaLinters\Support {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{Str};
use namespace HTL\Pha;

function insert_digest(
  Pha\Script $script,
  Pha\PragmaMap $pragma_map,
)[]: string {
  $example = "<<file: Pragmas(vec['PhaLinters', 'digest:'])>>";
  $digest = extract_digest($script, $pragma_map);

  invariant(
    $digest is nonnull,
    'The source should contain a pragma attribute with an empty digest, got none. Example: %s',
    $example,
  );
  invariant(
    $digest['embedded'] === '',
    'The embedded pragma directive should not specify a digest, got %s. Example: %s',
    $digest['embedded'],
    $example,
  );

  return Pha\node_get_code($script, $digest['pragma'])
    |> Str\replace($$, 'digest:', 'digest:'.$digest['hashed'])
    |> Pha\patches($script, Pha\patch_node($digest['pragma'], $$))
    |> Pha\patches_apply($$);
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/support/is_assignment_operator.hack /////
namespace HTL\PhaLinters\Support {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


use namespace HTL\Pha;

function assignment_operator_matcher(Pha\Script $script)[]: (function(
  Pha\NillableNode,
)[]: bool) {
  return Pha\create_token_matcher(
    $script,
    Pha\KIND_AMPERSAND_EQUAL,
    Pha\KIND_BAR_EQUAL,
    Pha\KIND_CARAT_EQUAL,
    Pha\KIND_DOT_EQUAL,
    Pha\KIND_EQUAL,
    Pha\KIND_GREATER_THAN_GREATER_THAN_EQUAL,
    Pha\KIND_LESS_THAN_LESS_THAN_EQUAL,
    Pha\KIND_MINUS_EQUAL,
    Pha\KIND_PERCENT_EQUAL,
    Pha\KIND_PLUS_EQUAL,
    Pha\KIND_QUESTION_QUESTION_EQUAL,
    Pha\KIND_SLASH_EQUAL,
    Pha\KIND_STAR_EQUAL,
    Pha\KIND_STAR_STAR_EQUAL,
  );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast-linters/src/support/vec_take_while_inclusive.hack /////
namespace HTL\PhaLinters\Support {
/** portable-hack-ast-linters is MIT licensed, see /LICENSE. */


/**
 * Returns a new vec with all elements up until and including the first element
 * for which the does not predicate hold.
 * If the predicate holds for all elements, all elements are returned.
 *
 * ```
 * $nums = vec[1, 2, 3, 4, 5, 6, 7];
 * vec_take_while_inclusive($nums, $n ==> $n !== 4); // vec[1, 2, 3, 4]
 * ```
 */
function vec_take_while_inclusive<T>(
  Traversable<T> $traversable,
  (function(T)[_]: bool) $predicate,
)[ctx $predicate]: vec<T> {
  $out = vec[];

  foreach ($traversable as $el) {
    $out[] = $el;
    if (!$predicate($el)) {
      return $out;
    }
  }

  return $out;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/Kind.hack /////
namespace HTL\Pha {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


newtype Kind as string = string;
newtype SyntaxKind as Kind = Kind;
newtype TokenKind as Kind = Kind;
newtype TriviumKind as Kind = Kind;

function syntax_kind_from_kind(Kind $kind)[]: SyntaxKind {
  return $kind;
}

function syntax_kind_from_string(string $str)[]: SyntaxKind {
  return $str;
}

function token_kind_from_kind(Kind $kind)[]: TokenKind {
  return $kind;
}

function token_kind_from_string(string $str)[]: TokenKind {
  return $str;
}

function trivium_kind_from_kind(Kind $kind)[]: TriviumKind {
  return $kind;
}

function trivium_kind_from_string(string $str)[]: TriviumKind {
  return $str;
}

// Missing the codegen...
const SyntaxKind KIND_NAME_EXPRESSION = 'name_expression';
const SyntaxKind KIND_NODE_LIST = 'node_list';
const SyntaxKind KIND_MISSING = 'missing';

const TriviumKind KIND_DELIMITED_COMMENT = 'delimited_comment';
const TriviumKind KIND_END_OF_LINE = 'end_of_line';
const TriviumKind KIND_FALL_THROUGH_COMMENT = 'fall_through';
const TriviumKind KIND_FIX_ME = 'fix_me';
const TriviumKind KIND_IGNORE_ERROR = 'ignore_error';
const TriviumKind KIND_SINGLE_LINE_COMMENT = 'single_line_comment';
const TriviumKind KIND_TOKEN_TEXT = 'token_text';
const TriviumKind KIND_WHITESPACE = 'whitespace';

// #region GENERATED CODE DO NOT EDIT BY HAND!
// This code was generated by bin/codegen_kind_constants.hack 817ea043fead078084eeca0cd0ab151c69a1006b

const SyntaxKind KIND_ALIAS_DECLARATION = 'alias_declaration';
const SyntaxKind KIND_ANONYMOUS_CLASS = 'anonymous_class';
const SyntaxKind KIND_ANONYMOUS_FUNCTION = 'anonymous_function';
const SyntaxKind KIND_ANONYMOUS_FUNCTION_USE_CLAUSE = 'anonymous_function_use_clause';
const SyntaxKind KIND_AS_EXPRESSION = 'as_expression';
const SyntaxKind KIND_ATTRIBUTE_SYNTAX = 'attribute';
const SyntaxKind KIND_ATTRIBUTE_SPECIFICATION = 'attribute_specification';
const SyntaxKind KIND_ATTRIBUTIZED_SPECIFIER = 'attributized_specifier';
const SyntaxKind KIND_AWAITABLE_CREATION_EXPRESSION = 'awaitable_creation_expression';
const SyntaxKind KIND_BINARY_EXPRESSION = 'binary_expression';
const SyntaxKind KIND_BRACED_EXPRESSION = 'braced_expression';
const SyntaxKind KIND_BREAK_STATEMENT = 'break_statement';
const SyntaxKind KIND_CASE_LABEL = 'case_label';
const SyntaxKind KIND_CASE_TYPE_DECLARATION = 'case_type_declaration';
const SyntaxKind KIND_CASE_TYPE_VARIANT = 'case_type_variant';
const SyntaxKind KIND_CAST_EXPRESSION = 'cast_expression';
const SyntaxKind KIND_CATCH_CLAUSE = 'catch_clause';
const SyntaxKind KIND_CLASSISH_BODY = 'classish_body';
const SyntaxKind KIND_CLASSISH_DECLARATION = 'classish_declaration';
const SyntaxKind KIND_CLASSNAME_TYPE_SPECIFIER = 'classname_type_specifier';
const SyntaxKind KIND_CLASS_PTR_TYPE_SPECIFIER = 'class_ptr_type_specifier';
const SyntaxKind KIND_CLOSURE_PARAMETER_TYPE_SPECIFIER = 'closure_parameter_type_specifier';
const SyntaxKind KIND_CLOSURE_TYPE_SPECIFIER = 'closure_type_specifier';
const SyntaxKind KIND_COLLECTION_LITERAL_EXPRESSION = 'collection_literal_expression';
const SyntaxKind KIND_COMPOUND_STATEMENT = 'compound_statement';
const SyntaxKind KIND_CONCURRENT_STATEMENT = 'concurrent_statement';
const SyntaxKind KIND_CONDITIONAL_EXPRESSION = 'conditional_expression';
const SyntaxKind KIND_CONSTANT_DECLARATOR = 'constant_declarator';
const SyntaxKind KIND_CONSTRUCTOR_CALL = 'constructor_call';
const SyntaxKind KIND_CONSTRUCTOR_PATTERN = 'constructor_pattern';
const SyntaxKind KIND_CONST_DECLARATION = 'const_declaration';
const SyntaxKind KIND_CONTEXTS = 'contexts';
const SyntaxKind KIND_CONTEXT_ALIAS_DECLARATION = 'context_alias_declaration';
const SyntaxKind KIND_CONTEXT_CONSTRAINT = 'context_constraint';
const SyntaxKind KIND_CONTEXT_CONST_DECLARATION = 'context_const_declaration';
const SyntaxKind KIND_CONTINUE_STATEMENT = 'continue_statement';
const SyntaxKind KIND_CTX_IN_REFINEMENT = 'ctx_in_refinement';
const SyntaxKind KIND_DARRAY_INTRINSIC_EXPRESSION = 'darray_intrinsic_expression';
const SyntaxKind KIND_DARRAY_TYPE_SPECIFIER = 'darray_type_specifier';
const SyntaxKind KIND_DECLARE_LOCAL_STATEMENT = 'declare_local_statement';
const SyntaxKind KIND_DECORATED_EXPRESSION = 'decorated_expression';
const SyntaxKind KIND_DEFAULT_LABEL = 'default_label';
const SyntaxKind KIND_DEFINE_EXPRESSION = 'define_expression';
const SyntaxKind KIND_DICTIONARY_INTRINSIC_EXPRESSION = 'dictionary_intrinsic_expression';
const SyntaxKind KIND_DICTIONARY_TYPE_SPECIFIER = 'dictionary_type_specifier';
const SyntaxKind KIND_DO_STATEMENT = 'do_statement';
const SyntaxKind KIND_ECHO_STATEMENT = 'echo_statement';
const SyntaxKind KIND_ELEMENT_INITIALIZER = 'element_initializer';
const SyntaxKind KIND_ELSEIF_CLAUSE = 'elseif_clause';
const SyntaxKind KIND_ELSE_CLAUSE = 'else_clause';
const SyntaxKind KIND_EMBEDDED_BRACED_EXPRESSION = 'embedded_braced_expression';
const SyntaxKind KIND_EMBEDDED_MEMBER_SELECTION_EXPRESSION = 'embedded_member_selection_expression';
const SyntaxKind KIND_EMBEDDED_SUBSCRIPT_EXPRESSION = 'embedded_subscript_expression';
const SyntaxKind KIND_END_OF_FILE = 'end_of_file';
const SyntaxKind KIND_ENUMERATOR = 'enumerator';
const SyntaxKind KIND_ENUM_ATOM_EXPRESSION = 'enum_atom_expression';
const SyntaxKind KIND_ENUM_CLASS_DECLARATION = 'enum_class_declaration';
const SyntaxKind KIND_ENUM_CLASS_ENUMERATOR = 'enum_class_enumerator';
const SyntaxKind KIND_ENUM_CLASS_LABEL_EXPRESSION = 'enum_class_label_expression';
const SyntaxKind KIND_ENUM_DECLARATION = 'enum_declaration';
const SyntaxKind KIND_ENUM_USE = 'enum_use';
const SyntaxKind KIND_ERROR_SYNTAX = 'error_syntax';
const SyntaxKind KIND_ETSPLICE_EXPRESSION = 'eTSplice_expression';
const SyntaxKind KIND_EVAL_EXPRESSION = 'eval_expression';
const SyntaxKind KIND_EXPRESSION_STATEMENT = 'expression_statement';
const SyntaxKind KIND_FIELD_INITIALIZER = 'field_initializer';
const SyntaxKind KIND_FIELD_SPECIFIER = 'field_specifier';
const SyntaxKind KIND_FILE_ATTRIBUTE_SPECIFICATION = 'file_attribute_specification';
const SyntaxKind KIND_FINALLY_CLAUSE = 'finally_clause';
const SyntaxKind KIND_FOREACH_STATEMENT = 'foreach_statement';
const SyntaxKind KIND_FOR_STATEMENT = 'for_statement';
const SyntaxKind KIND_FUNCTION_CALL_EXPRESSION = 'function_call_expression';
const SyntaxKind KIND_FUNCTION_CTX_TYPE_SPECIFIER = 'function_ctx_type_specifier';
const SyntaxKind KIND_FUNCTION_DECLARATION = 'function_declaration';
const SyntaxKind KIND_FUNCTION_DECLARATION_HEADER = 'function_declaration_header';
const SyntaxKind KIND_FUNCTION_POINTER_EXPRESSION = 'function_pointer_expression';
const SyntaxKind KIND_GENERIC_TYPE_SPECIFIER = 'generic_type_specifier';
const SyntaxKind KIND_IF_STATEMENT = 'if_statement';
const SyntaxKind KIND_INCLUSION_DIRECTIVE = 'inclusion_directive';
const SyntaxKind KIND_INCLUSION_EXPRESSION = 'inclusion_expression';
const SyntaxKind KIND_INTERSECTION_TYPE_SPECIFIER = 'intersection_type_specifier';
const SyntaxKind KIND_ISSET_EXPRESSION = 'isset_expression';
const SyntaxKind KIND_IS_EXPRESSION = 'is_expression';
const SyntaxKind KIND_KEYSET_INTRINSIC_EXPRESSION = 'keyset_intrinsic_expression';
const SyntaxKind KIND_KEYSET_TYPE_SPECIFIER = 'keyset_type_specifier';
const SyntaxKind KIND_LAMBDA_EXPRESSION = 'lambda_expression';
const SyntaxKind KIND_LAMBDA_SIGNATURE = 'lambda_signature';
const SyntaxKind KIND_LIKE_TYPE_SPECIFIER = 'like_type_specifier';
const SyntaxKind KIND_LIST_EXPRESSION = 'list_expression';
const SyntaxKind KIND_LIST_ITEM = 'list_item';
const SyntaxKind KIND_LITERAL = 'literal';
const SyntaxKind KIND_MARKUP_SECTION = 'markup_section';
const SyntaxKind KIND_MARKUP_SUFFIX = 'markup_suffix';
const SyntaxKind KIND_MATCH_STATEMENT = 'match_statement';
const SyntaxKind KIND_MATCH_STATEMENT_ARM = 'match_statement_arm';
const SyntaxKind KIND_MEMBER_SELECTION_EXPRESSION = 'member_selection_expression';
const SyntaxKind KIND_METHODISH_DECLARATION = 'methodish_declaration';
const SyntaxKind KIND_METHODISH_TRAIT_RESOLUTION = 'methodish_trait_resolution';
const SyntaxKind KIND_MODULE_DECLARATION = 'module_declaration';
const SyntaxKind KIND_MODULE_EXPORTS = 'module_exports';
const SyntaxKind KIND_MODULE_IMPORTS = 'module_imports';
const SyntaxKind KIND_MODULE_MEMBERSHIP_DECLARATION = 'module_membership_declaration';
const SyntaxKind KIND_MODULE_NAME = 'module_name';
const SyntaxKind KIND_NAMEOF_EXPRESSION = 'nameof_expression';
const SyntaxKind KIND_NAMESPACE_BODY = 'namespace_body';
const SyntaxKind KIND_NAMESPACE_DECLARATION = 'namespace_declaration';
const SyntaxKind KIND_NAMESPACE_DECLARATION_HEADER = 'namespace_declaration_header';
const SyntaxKind KIND_NAMESPACE_EMPTY_BODY = 'namespace_empty_body';
const SyntaxKind KIND_NAMESPACE_GROUP_USE_DECLARATION = 'namespace_group_use_declaration';
const SyntaxKind KIND_NAMESPACE_USE_CLAUSE = 'namespace_use_clause';
const SyntaxKind KIND_NAMESPACE_USE_DECLARATION = 'namespace_use_declaration';
const SyntaxKind KIND_NULLABLE_AS_EXPRESSION = 'nullable_as_expression';
const SyntaxKind KIND_NULLABLE_TYPE_SPECIFIER = 'nullable_type_specifier';
const SyntaxKind KIND_OBJECT_CREATION_EXPRESSION = 'object_creation_expression';
const SyntaxKind KIND_OLD_ATTRIBUTE_SPECIFICATION = 'old_attribute_specification';
const SyntaxKind KIND_PACKAGE_DECLARATION = 'package_declaration';
const SyntaxKind KIND_PACKAGE_EXPRESSION = 'package_expression';
const SyntaxKind KIND_PACKAGE_INCLUDES = 'package_includes';
const SyntaxKind KIND_PACKAGE_USES = 'package_uses';
const SyntaxKind KIND_PARAMETER_DECLARATION = 'parameter_declaration';
const SyntaxKind KIND_PARENTHESIZED_EXPRESSION = 'parenthesized_expression';
const SyntaxKind KIND_PIPE_VARIABLE = 'pipe_variable';
const SyntaxKind KIND_POSTFIX_UNARY_EXPRESSION = 'postfix_unary_expression';
const SyntaxKind KIND_PREFIXED_CODE_EXPRESSION = 'prefixed_code_expression';
const SyntaxKind KIND_PREFIXED_STRING = 'prefixed_string';
const SyntaxKind KIND_PREFIX_UNARY_EXPRESSION = 'prefix_unary_expression';
const SyntaxKind KIND_PROPERTY_DECLARATION = 'property_declaration';
const SyntaxKind KIND_PROPERTY_DECLARATOR = 'property_declarator';
const SyntaxKind KIND_QUALIFIED_NAME = 'qualified_name';
const SyntaxKind KIND_RECORD_CREATION_EXPRESSION = 'record_creation_expression';
const SyntaxKind KIND_RECORD_DECLARATION = 'record_declaration';
const SyntaxKind KIND_RECORD_FIELD = 'record_field';
const SyntaxKind KIND_REFINEMENT_PATTERN = 'refinement_pattern';
const SyntaxKind KIND_REIFIED_TYPE_ARGUMENT = 'reified_type_argument';
const SyntaxKind KIND_REQUIRE_CLAUSE = 'require_clause';
const SyntaxKind KIND_REQUIRE_CLAUSE_CONSTRAINT = 'require_clause_constraint';
const SyntaxKind KIND_RETURN_STATEMENT = 'return_statement';
const SyntaxKind KIND_SAFE_MEMBER_SELECTION_EXPRESSION = 'safe_member_selection_expression';
const SyntaxKind KIND_SCOPE_RESOLUTION_EXPRESSION = 'scope_resolution_expression';
const SyntaxKind KIND_SCRIPT = 'script';
const SyntaxKind KIND_SHAPE_EXPRESSION = 'shape_expression';
const SyntaxKind KIND_SHAPE_TYPE_SPECIFIER = 'shape_type_specifier';
const SyntaxKind KIND_SIMPLE_INITIALIZER = 'simple_initializer';
const SyntaxKind KIND_SIMPLE_TYPE_SPECIFIER = 'simple_type_specifier';
const SyntaxKind KIND_SOFT_TYPE_SPECIFIER = 'soft_type_specifier';
const SyntaxKind KIND_SUBSCRIPT_EXPRESSION = 'subscript_expression';
const SyntaxKind KIND_SWITCH_FALLTHROUGH = 'switch_fallthrough';
const SyntaxKind KIND_SWITCH_SECTION = 'switch_section';
const SyntaxKind KIND_SWITCH_STATEMENT = 'switch_statement';
const SyntaxKind KIND_THROW_STATEMENT = 'throw_statement';
const SyntaxKind KIND_TRAIT_USE = 'trait_use';
const SyntaxKind KIND_TRAIT_USE_ALIAS_ITEM = 'trait_use_alias_item';
const SyntaxKind KIND_TRAIT_USE_CONFLICT_RESOLUTION = 'trait_use_conflict_resolution';
const SyntaxKind KIND_TRAIT_USE_PRECEDENCE_ITEM = 'trait_use_precedence_item';
const SyntaxKind KIND_TRY_STATEMENT = 'try_statement';
const SyntaxKind KIND_TUPLE_EXPRESSION = 'tuple_expression';
const SyntaxKind KIND_TUPLE_OR_UNION_OR_INTERSECTION_ELEMENT_TYPE_SPECIFIER = 'tuple_or_union_or_intersection_element_type_specifier';
const SyntaxKind KIND_TUPLE_TYPE_EXPLICIT_SPECIFIER = 'tuple_type_explicit_specifier';
const SyntaxKind KIND_TUPLE_TYPE_SPECIFIER = 'tuple_type_specifier';
const SyntaxKind KIND_TYPE_ARGUMENTS = 'type_arguments';
const SyntaxKind KIND_TYPE_CONSTANT = 'type_constant';
const SyntaxKind KIND_TYPE_CONSTRAINT = 'type_constraint';
const SyntaxKind KIND_TYPE_CONST_DECLARATION = 'type_const_declaration';
const SyntaxKind KIND_TYPE_IN_REFINEMENT = 'type_in_refinement';
const SyntaxKind KIND_TYPE_PARAMETER = 'type_parameter';
const SyntaxKind KIND_TYPE_PARAMETERS = 'type_parameters';
const SyntaxKind KIND_TYPE_REFINEMENT = 'type_refinement';
const SyntaxKind KIND_UNION_TYPE_SPECIFIER = 'union_type_specifier';
const SyntaxKind KIND_UNSET_STATEMENT = 'unset_statement';
const SyntaxKind KIND_UPCAST_EXPRESSION = 'upcast_expression';
const SyntaxKind KIND_USING_STATEMENT_BLOCK_SCOPED = 'using_statement_block_scoped';
const SyntaxKind KIND_USING_STATEMENT_FUNCTION_SCOPED = 'using_statement_function_scoped';
const SyntaxKind KIND_VARIABLE_SYNTAX = 'variable';
const SyntaxKind KIND_VARIABLE_PATTERN = 'variable_pattern';
const SyntaxKind KIND_VARIADIC_PARAMETER = 'variadic_parameter';
const SyntaxKind KIND_VARRAY_INTRINSIC_EXPRESSION = 'varray_intrinsic_expression';
const SyntaxKind KIND_VARRAY_TYPE_SPECIFIER = 'varray_type_specifier';
const SyntaxKind KIND_VECTOR_INTRINSIC_EXPRESSION = 'vector_intrinsic_expression';
const SyntaxKind KIND_VECTOR_TYPE_SPECIFIER = 'vector_type_specifier';
const SyntaxKind KIND_WHERE_CLAUSE = 'where_clause';
const SyntaxKind KIND_WHERE_CONSTRAINT = 'where_constraint';
const SyntaxKind KIND_WHILE_STATEMENT = 'while_statement';
const SyntaxKind KIND_XHP_CATEGORY_DECLARATION = 'xhp_category_declaration';
const SyntaxKind KIND_XHP_CHILDREN_DECLARATION = 'xhp_children_declaration';
const SyntaxKind KIND_XHP_CHILDREN_PARENTHESIZED_LIST = 'xhp_children_parenthesized_list';
const SyntaxKind KIND_XHP_CLASS_ATTRIBUTE = 'xhp_class_attribute';
const SyntaxKind KIND_XHP_CLASS_ATTRIBUTE_DECLARATION = 'xhp_class_attribute_declaration';
const SyntaxKind KIND_XHP_CLOSE = 'xhp_close';
const SyntaxKind KIND_XHP_ENUM_TYPE = 'xhp_enum_type';
const SyntaxKind KIND_XHP_EXPRESSION = 'xhp_expression';
const SyntaxKind KIND_XHP_LATEINIT = 'XHP_lateinit';
const SyntaxKind KIND_XHP_OPEN = 'xhp_open';
const SyntaxKind KIND_XHP_REQUIRED = 'xhp_required';
const SyntaxKind KIND_XHP_SIMPLE_ATTRIBUTE = 'xhp_simple_attribute';
const SyntaxKind KIND_XHP_SIMPLE_CLASS_ATTRIBUTE = 'XHP_simple_class_attribute';
const SyntaxKind KIND_XHP_SPREAD_ATTRIBUTE = 'xhp_spread_attribute';
const SyntaxKind KIND_YIELD_BREAK_STATEMENT = 'yield_break_statement';
const SyntaxKind KIND_YIELD_EXPRESSION = 'yield_expression';

const TokenKind KIND_ABSTRACT = 'abstract';
const TokenKind KIND_AMPERSAND = '&';
const TokenKind KIND_AMPERSAND_AMPERSAND = '&&';
const TokenKind KIND_AMPERSAND_EQUAL = '&=';
const TokenKind KIND_ARRAYKEY = 'arraykey';
const TokenKind KIND_AS = 'as';
const TokenKind KIND_ASYNC = 'async';
const TokenKind KIND_AT = '@';
const TokenKind KIND_ATTRIBUTE_TOKEN = 'attribute';
const TokenKind KIND_AWAIT = 'await';
const TokenKind KIND_BACKSLASH = '\\';
const TokenKind KIND_BACKTICK = '`';
const TokenKind KIND_BAR = '|';
const TokenKind KIND_BAR_BAR = '||';
const TokenKind KIND_BAR_EQUAL = '|=';
const TokenKind KIND_BAR_GREATER_THAN = '|>';
const TokenKind KIND_BINARY = 'binary';
const TokenKind KIND_BINARY_LITERAL = 'binary_literal';
const TokenKind KIND_BOOL = 'bool';
const TokenKind KIND_BOOLEAN = 'boolean';
const TokenKind KIND_BOOLEAN_LITERAL = 'boolean_literal';
const TokenKind KIND_BREAK = 'break';
const TokenKind KIND_CARAT = '^';
const TokenKind KIND_CARAT_EQUAL = '^=';
const TokenKind KIND_CASE = 'case';
const TokenKind KIND_CATCH = 'catch';
const TokenKind KIND_CATEGORY = 'category';
const TokenKind KIND_CHILDREN = 'children';
const TokenKind KIND_CLASS = 'class';
const TokenKind KIND_CLASSNAME = 'classname';
const TokenKind KIND_CLONE = 'clone';
const TokenKind KIND_COLON = ':';
const TokenKind KIND_COLON_COLON = '::';
const TokenKind KIND_COMMA = ',';
const TokenKind KIND_CONCURRENT = 'concurrent';
const TokenKind KIND_CONST = 'const';
const TokenKind KIND_CONSTRUCT = '__construct';
const TokenKind KIND_CONTINUE = 'continue';
const TokenKind KIND_CTX = 'ctx';
const TokenKind KIND_DARRAY = 'darray';
const TokenKind KIND_DECIMAL_LITERAL = 'decimal_literal';
const TokenKind KIND_DEFAULT = 'default';
const TokenKind KIND_DEFINE = 'define';
const TokenKind KIND_DICT = 'dict';
const TokenKind KIND_DO = 'do';
const TokenKind KIND_DOLLAR = '$';
const TokenKind KIND_DOLLAR_DOLLAR = '$$';
const TokenKind KIND_DOT = '.';
const TokenKind KIND_DOT_DOT_DOT = '...';
const TokenKind KIND_DOT_EQUAL = '.=';
const TokenKind KIND_DOUBLE = 'double';
const TokenKind KIND_DOUBLE_QUOTED_STRING_LITERAL = 'double_quoted_string_literal';
const TokenKind KIND_DOUBLE_QUOTED_STRING_LITERAL_HEAD = 'double_quoted_string_literal_head';
const TokenKind KIND_DOUBLE_QUOTED_STRING_LITERAL_TAIL = 'double_quoted_string_literal_tail';
const TokenKind KIND_ECHO = 'echo';
const TokenKind KIND_ELSE = 'else';
const TokenKind KIND_ELSEIF = 'elseif';
const TokenKind KIND_EMPTY = 'empty';
const TokenKind KIND_ENDFOR = 'endfor';
const TokenKind KIND_ENDFOREACH = 'endforeach';
const TokenKind KIND_ENDIF = 'endif';
const TokenKind KIND_ENDSWITCH = 'endswitch';
const TokenKind KIND_ENDWHILE = 'endwhile';
const TokenKind KIND_END_OF_FILE_TOKEN = 'end_of_file';
const TokenKind KIND_ENUM = 'enum';
const TokenKind KIND_EQUAL = '=';
const TokenKind KIND_EQUAL_EQUAL = '==';
const TokenKind KIND_EQUAL_EQUAL_EQUAL = '===';
const TokenKind KIND_EQUAL_EQUAL_GREATER_THAN = '==>';
const TokenKind KIND_EQUAL_GREATER_THAN = '=>';
const TokenKind KIND_ERROR_TOKEN = 'error_token';
const TokenKind KIND_EVAL = 'eval';
const TokenKind KIND_EXCLAMATION = '!';
const TokenKind KIND_EXCLAMATION_EQUAL = '!=';
const TokenKind KIND_EXCLAMATION_EQUAL_EQUAL = '!==';
const TokenKind KIND_EXPORTS = 'exports';
const TokenKind KIND_EXTENDS = 'extends';
const TokenKind KIND_FALLTHROUGH = 'fallthrough';
const TokenKind KIND_FILE = 'file';
const TokenKind KIND_FINAL = 'final';
const TokenKind KIND_FINALLY = 'finally';
const TokenKind KIND_FLOAT = 'float';
const TokenKind KIND_FLOATING_LITERAL = 'floating_literal';
const TokenKind KIND_FOR = 'for';
const TokenKind KIND_FOREACH = 'foreach';
const TokenKind KIND_FROM = 'from';
const TokenKind KIND_FUNCTION = 'function';
const TokenKind KIND_GLOBAL = 'global';
const TokenKind KIND_GREATER_THAN = '>';
const TokenKind KIND_GREATER_THAN_EQUAL = '>=';
const TokenKind KIND_GREATER_THAN_GREATER_THAN = '>>';
const TokenKind KIND_GREATER_THAN_GREATER_THAN_EQUAL = '>>=';
const TokenKind KIND_HASH = '#';
const TokenKind KIND_HASHBANG = 'hashbang';
const TokenKind KIND_HEREDOC_STRING_LITERAL = 'heredoc_string_literal';
const TokenKind KIND_HEREDOC_STRING_LITERAL_HEAD = 'heredoc_string_literal_head';
const TokenKind KIND_HEREDOC_STRING_LITERAL_TAIL = 'heredoc_string_literal_tail';
const TokenKind KIND_HEXADECIMAL_LITERAL = 'hexadecimal_literal';
const TokenKind KIND_IF = 'if';
const TokenKind KIND_IMPLEMENTS = 'implements';
const TokenKind KIND_IMPORTS = 'imports';
const TokenKind KIND_INCLUDE = 'include';
const TokenKind KIND_INCLUDE_ONCE = 'include_once';
const TokenKind KIND_INOUT = 'inout';
const TokenKind KIND_INSTANCEOF = 'instanceof';
const TokenKind KIND_INSTEADOF = 'insteadof';
const TokenKind KIND_INT = 'int';
const TokenKind KIND_INTEGER = 'integer';
const TokenKind KIND_INTERFACE = 'interface';
const TokenKind KIND_INTERNAL = 'internal';
const TokenKind KIND_IS = 'is';
const TokenKind KIND_ISSET = 'isset';
const TokenKind KIND_KEYSET = 'keyset';
const TokenKind KIND_LATEINIT = 'lateinit';
const TokenKind KIND_LEFT_BRACE = '{';
const TokenKind KIND_LEFT_BRACKET = '[';
const TokenKind KIND_LEFT_PAREN = '(';
const TokenKind KIND_LESS_THAN = '<';
const TokenKind KIND_LESS_THAN_EQUAL = '<=';
const TokenKind KIND_LESS_THAN_EQUAL_GREATER_THAN = '<=>';
const TokenKind KIND_LESS_THAN_LESS_THAN = '<<';
const TokenKind KIND_LESS_THAN_LESS_THAN_EQUAL = '<<=';
const TokenKind KIND_LESS_THAN_QUESTION = '<?';
const TokenKind KIND_LESS_THAN_SLASH = '</';
const TokenKind KIND_LET = 'let';
const TokenKind KIND_LIST = 'list';
const TokenKind KIND_MATCH = 'match';
const TokenKind KIND_MINUS = '-';
const TokenKind KIND_MINUS_EQUAL = '-=';
const TokenKind KIND_MINUS_GREATER_THAN = '->';
const TokenKind KIND_MINUS_MINUS = '--';
const TokenKind KIND_MIXED = 'mixed';
const TokenKind KIND_MODULE = 'module';
const TokenKind KIND_NAME = 'name';
const TokenKind KIND_NAMEOF = 'nameof';
const TokenKind KIND_NAMESPACE = 'namespace';
const TokenKind KIND_NEW = 'new';
const TokenKind KIND_NEWCTX = 'newctx';
const TokenKind KIND_NEWTYPE = 'newtype';
const TokenKind KIND_NORETURN = 'noreturn';
const TokenKind KIND_NOWDOC_STRING_LITERAL = 'nowdoc_string_literal';
const TokenKind KIND_NULL_LITERAL = 'null';
const TokenKind KIND_NUM = 'num';
const TokenKind KIND_OBJECT = 'object';
const TokenKind KIND_OCTAL_LITERAL = 'octal_literal';
const TokenKind KIND_OPTIONAL = 'optional';
const TokenKind KIND_PACKAGE = 'package';
const TokenKind KIND_PARENT = 'parent';
const TokenKind KIND_PERCENT = '%';
const TokenKind KIND_PERCENT_EQUAL = '%=';
const TokenKind KIND_PLUS = '+';
const TokenKind KIND_PLUS_EQUAL = '+=';
const TokenKind KIND_PLUS_PLUS = '++';
const TokenKind KIND_PRINT = 'print';
const TokenKind KIND_PRIVATE = 'private';
const TokenKind KIND_PROTECTED = 'protected';
const TokenKind KIND_PUBLIC = 'public';
const TokenKind KIND_QUESTION = '?';
const TokenKind KIND_QUESTION_AS = '?as';
const TokenKind KIND_QUESTION_COLON = '?:';
const TokenKind KIND_QUESTION_MINUS_GREATER_THAN = '?->';
const TokenKind KIND_QUESTION_QUESTION = '??';
const TokenKind KIND_QUESTION_QUESTION_EQUAL = '??=';
const TokenKind KIND_READONLY = 'readonly';
const TokenKind KIND_REAL = 'real';
const TokenKind KIND_RECORD = 'recordname';
const TokenKind KIND_RECORD_DEC = 'record';
const TokenKind KIND_REIFY = 'reify';
const TokenKind KIND_REQUIRE = 'require';
const TokenKind KIND_REQUIRED = 'required';
const TokenKind KIND_REQUIRE_ONCE = 'require_once';
const TokenKind KIND_RESOURCE = 'resource';
const TokenKind KIND_RETURN = 'return';
const TokenKind KIND_RIGHT_BRACE = '}';
const TokenKind KIND_RIGHT_BRACKET = ']';
const TokenKind KIND_RIGHT_PAREN = ')';
const TokenKind KIND_SELF = 'self';
const TokenKind KIND_SEMICOLON = ';';
const TokenKind KIND_SHAPE = 'shape';
const TokenKind KIND_SINGLE_QUOTED_STRING_LITERAL = 'single_quoted_string_literal';
const TokenKind KIND_SLASH = '/';
const TokenKind KIND_SLASH_EQUAL = '/=';
const TokenKind KIND_SLASH_GREATER_THAN = '/>';
const TokenKind KIND_STAR = '*';
const TokenKind KIND_STAR_EQUAL = '*=';
const TokenKind KIND_STAR_STAR = '**';
const TokenKind KIND_STAR_STAR_EQUAL = '**=';
const TokenKind KIND_STATIC = 'static';
const TokenKind KIND_STRING = 'string';
const TokenKind KIND_STRING_LITERAL_BODY = 'string_literal_body';
const TokenKind KIND_SUPER = 'super';
const TokenKind KIND_SWITCH = 'switch';
const TokenKind KIND_THIS = 'this';
const TokenKind KIND_THROW = 'throw';
const TokenKind KIND_TILDE = '~';
const TokenKind KIND_TRAIT = 'trait';
const TokenKind KIND_TRY = 'try';
const TokenKind KIND_TUPLE = 'tuple';
const TokenKind KIND_TYPE = 'type';
const TokenKind KIND_UNSET = 'unset';
const TokenKind KIND_UPCAST = 'upcast';
const TokenKind KIND_USE = 'use';
const TokenKind KIND_USING = 'using';
const TokenKind KIND_VAR = 'var';
const TokenKind KIND_VARIABLE_TOKEN = 'variable';
const TokenKind KIND_VARRAY = 'varray';
const TokenKind KIND_VEC = 'vec';
const TokenKind KIND_VOID = 'void';
const TokenKind KIND_WHERE = 'where';
const TokenKind KIND_WHILE = 'while';
const TokenKind KIND_WITH = 'with';
const TokenKind KIND_XHP = 'xhp';
const TokenKind KIND_XHP_BODY = 'XHP_body';
const TokenKind KIND_XHP_CATEGORY_NAME = 'XHP_category_name';
const TokenKind KIND_XHP_CLASS_NAME = 'XHP_class_name';
const TokenKind KIND_XHP_COMMENT = 'XHP_comment';
const TokenKind KIND_XHP_ELEMENT_NAME = 'XHP_element_name';
const TokenKind KIND_XHP_STRING_LITERAL = 'XHP_string_literal';
const TokenKind KIND_YIELD = 'yield';
// #endregion
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/LineAndColumnNumbers.hack /////
namespace HTL\Pha {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


/**
 * The start of the first trivium of a file is at line(0), col(0).
 * A column is determined by the place of the cursor, not the start of the byte.
 * A node consisting of a single byte is one column large.
 * The end column of a node with no text is the same as its start column.
 * Newlines are considered to be the last column of a line.
 */
final class LineAndColumnNumbers {
  public function __construct(
    private int $startLine,
    private int $startColumn,
    private int $endLine,
    private int $endColumn,
  )[] {}

  public function getStartLine()[]: int {
    return $this->startLine;
  }

  public function getStartLineOneBased()[]: int {
    return $this->startLine + 1;
  }

  public function getStartColumn()[]: int {
    return $this->startColumn;
  }

  public function getStartColumnOneBased()[]: int {
    return $this->startColumn + 1;
  }

  public function getEndLine()[]: int {
    return $this->endLine;
  }

  public function getEndLineOneBased()[]: int {
    return $this->endLine + 1;
  }

  public function getEndColumn()[]: int {
    return $this->endColumn;
  }

  public function getEndColumnOneBased()[]: int {
    return $this->endColumn + 1;
  }

  public function getStart()[]: (int, int) {
    return tuple($this->startLine, $this->startColumn);
  }

  public function getStartOneBased()[]: (int, int) {
    return
      tuple($this->getStartLineOneBased(), $this->getStartColumnOneBased());
  }

  public function getEnd()[]: (int, int) {
    return tuple($this->endLine, $this->endColumn);
  }

  public function getEndOneBased()[]: (int, int) {
    return tuple($this->getEndLineOneBased(), $this->getEndColumnOneBased());
  }
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/Member.hack /////
namespace HTL\Pha {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


newtype Member = (SyntaxKind, string);

function member_from_tuple((SyntaxKind, string) $tuple)[]: Member {
  return $tuple;
}

function member_to_tuple(Member $member)[]: (SyntaxKind, string) {
  return $member;
}

function member_get_name(Member $member)[]: string {
  return $member[1];
}

function member_get_syntax_kind(Member $member)[]: SyntaxKind {
  return $member[0];
}

// #region GENERATED CODE DO NOT EDIT BY HAND!
// This code was generated by bin/codegen_kind_constants.hack 817ea043fead078084eeca0cd0ab151c69a1006b

const Member MEMBER_ALIAS_ATTRIBUTE_SPEC = tuple(KIND_ALIAS_DECLARATION, 'alias_attribute_spec');
const Member MEMBER_ALIAS_CONSTRAINT = tuple(KIND_ALIAS_DECLARATION, 'alias_constraint');
const Member MEMBER_ALIAS_EQUAL = tuple(KIND_ALIAS_DECLARATION, 'alias_equal');
const Member MEMBER_ALIAS_GENERIC_PARAMETER = tuple(KIND_ALIAS_DECLARATION, 'alias_generic_parameter');
const Member MEMBER_ALIAS_KEYWORD = tuple(KIND_ALIAS_DECLARATION, 'alias_keyword');
const Member MEMBER_ALIAS_MODIFIERS = tuple(KIND_ALIAS_DECLARATION, 'alias_modifiers');
const Member MEMBER_ALIAS_MODULE_KW_OPT = tuple(KIND_ALIAS_DECLARATION, 'alias_module_kw_opt');
const Member MEMBER_ALIAS_NAME = tuple(KIND_ALIAS_DECLARATION, 'alias_name');
const Member MEMBER_ALIAS_SEMICOLON = tuple(KIND_ALIAS_DECLARATION, 'alias_semicolon');
const Member MEMBER_ALIAS_TYPE = tuple(KIND_ALIAS_DECLARATION, 'alias_type');
const Member MEMBER_ANONYMOUS_ASYNC_KEYWORD = tuple(KIND_ANONYMOUS_FUNCTION, 'anonymous_async_keyword');
const Member MEMBER_ANONYMOUS_ATTRIBUTE_SPEC = tuple(KIND_ANONYMOUS_FUNCTION, 'anonymous_attribute_spec');
const Member MEMBER_ANONYMOUS_BODY = tuple(KIND_ANONYMOUS_FUNCTION, 'anonymous_body');
const Member MEMBER_ANONYMOUS_CLASS_ARGUMENT_LIST = tuple(KIND_ANONYMOUS_CLASS, 'anonymous_class_argument_list');
const Member MEMBER_ANONYMOUS_CLASS_BODY = tuple(KIND_ANONYMOUS_CLASS, 'anonymous_class_body');
const Member MEMBER_ANONYMOUS_CLASS_CLASS_KEYWORD = tuple(KIND_ANONYMOUS_CLASS, 'anonymous_class_class_keyword');
const Member MEMBER_ANONYMOUS_CLASS_EXTENDS_KEYWORD = tuple(KIND_ANONYMOUS_CLASS, 'anonymous_class_extends_keyword');
const Member MEMBER_ANONYMOUS_CLASS_EXTENDS_LIST = tuple(KIND_ANONYMOUS_CLASS, 'anonymous_class_extends_list');
const Member MEMBER_ANONYMOUS_CLASS_IMPLEMENTS_KEYWORD = tuple(KIND_ANONYMOUS_CLASS, 'anonymous_class_implements_keyword');
const Member MEMBER_ANONYMOUS_CLASS_IMPLEMENTS_LIST = tuple(KIND_ANONYMOUS_CLASS, 'anonymous_class_implements_list');
const Member MEMBER_ANONYMOUS_CLASS_LEFT_PAREN = tuple(KIND_ANONYMOUS_CLASS, 'anonymous_class_left_paren');
const Member MEMBER_ANONYMOUS_CLASS_RIGHT_PAREN = tuple(KIND_ANONYMOUS_CLASS, 'anonymous_class_right_paren');
const Member MEMBER_ANONYMOUS_COLON = tuple(KIND_ANONYMOUS_FUNCTION, 'anonymous_colon');
const Member MEMBER_ANONYMOUS_CTX_LIST = tuple(KIND_ANONYMOUS_FUNCTION, 'anonymous_ctx_list');
const Member MEMBER_ANONYMOUS_FUNCTION_KEYWORD = tuple(KIND_ANONYMOUS_FUNCTION, 'anonymous_function_keyword');
const Member MEMBER_ANONYMOUS_LEFT_PAREN = tuple(KIND_ANONYMOUS_FUNCTION, 'anonymous_left_paren');
const Member MEMBER_ANONYMOUS_PARAMETERS = tuple(KIND_ANONYMOUS_FUNCTION, 'anonymous_parameters');
const Member MEMBER_ANONYMOUS_READONLY_RETURN = tuple(KIND_ANONYMOUS_FUNCTION, 'anonymous_readonly_return');
const Member MEMBER_ANONYMOUS_RIGHT_PAREN = tuple(KIND_ANONYMOUS_FUNCTION, 'anonymous_right_paren');
const Member MEMBER_ANONYMOUS_STATIC_KEYWORD = tuple(KIND_ANONYMOUS_FUNCTION, 'anonymous_static_keyword');
const Member MEMBER_ANONYMOUS_TYPE = tuple(KIND_ANONYMOUS_FUNCTION, 'anonymous_type');
const Member MEMBER_ANONYMOUS_TYPE_PARAMETERS = tuple(KIND_ANONYMOUS_FUNCTION, 'anonymous_type_parameters');
const Member MEMBER_ANONYMOUS_USE = tuple(KIND_ANONYMOUS_FUNCTION, 'anonymous_use');
const Member MEMBER_ANONYMOUS_USE_KEYWORD = tuple(KIND_ANONYMOUS_FUNCTION_USE_CLAUSE, 'anonymous_use_keyword');
const Member MEMBER_ANONYMOUS_USE_LEFT_PAREN = tuple(KIND_ANONYMOUS_FUNCTION_USE_CLAUSE, 'anonymous_use_left_paren');
const Member MEMBER_ANONYMOUS_USE_RIGHT_PAREN = tuple(KIND_ANONYMOUS_FUNCTION_USE_CLAUSE, 'anonymous_use_right_paren');
const Member MEMBER_ANONYMOUS_USE_VARIABLES = tuple(KIND_ANONYMOUS_FUNCTION_USE_CLAUSE, 'anonymous_use_variables');
const Member MEMBER_AS_LEFT_OPERAND = tuple(KIND_AS_EXPRESSION, 'as_left_operand');
const Member MEMBER_AS_OPERATOR = tuple(KIND_AS_EXPRESSION, 'as_operator');
const Member MEMBER_AS_RIGHT_OPERAND = tuple(KIND_AS_EXPRESSION, 'as_right_operand');
const Member MEMBER_ATTRIBUTE_AT = tuple(KIND_ATTRIBUTE_SYNTAX, 'attribute_at');
const Member MEMBER_ATTRIBUTE_ATTRIBUTE_NAME = tuple(KIND_ATTRIBUTE_SYNTAX, 'attribute_attribute_name');
const Member MEMBER_ATTRIBUTE_SPECIFICATION_ATTRIBUTES = tuple(KIND_ATTRIBUTE_SPECIFICATION, 'attribute_specification_attributes');
const Member MEMBER_ATTRIBUTIZED_SPECIFIER_ATTRIBUTE_SPEC = tuple(KIND_ATTRIBUTIZED_SPECIFIER, 'attributized_specifier_attribute_spec');
const Member MEMBER_ATTRIBUTIZED_SPECIFIER_TYPE = tuple(KIND_ATTRIBUTIZED_SPECIFIER, 'attributized_specifier_type');
const Member MEMBER_AWAITABLE_ASYNC = tuple(KIND_AWAITABLE_CREATION_EXPRESSION, 'awaitable_async');
const Member MEMBER_AWAITABLE_ATTRIBUTE_SPEC = tuple(KIND_AWAITABLE_CREATION_EXPRESSION, 'awaitable_attribute_spec');
const Member MEMBER_AWAITABLE_COMPOUND_STATEMENT = tuple(KIND_AWAITABLE_CREATION_EXPRESSION, 'awaitable_compound_statement');
const Member MEMBER_BINARY_LEFT_OPERAND = tuple(KIND_BINARY_EXPRESSION, 'binary_left_operand');
const Member MEMBER_BINARY_OPERATOR = tuple(KIND_BINARY_EXPRESSION, 'binary_operator');
const Member MEMBER_BINARY_RIGHT_OPERAND = tuple(KIND_BINARY_EXPRESSION, 'binary_right_operand');
const Member MEMBER_BRACED_EXPRESSION_EXPRESSION = tuple(KIND_BRACED_EXPRESSION, 'braced_expression_expression');
const Member MEMBER_BRACED_EXPRESSION_LEFT_BRACE = tuple(KIND_BRACED_EXPRESSION, 'braced_expression_left_brace');
const Member MEMBER_BRACED_EXPRESSION_RIGHT_BRACE = tuple(KIND_BRACED_EXPRESSION, 'braced_expression_right_brace');
const Member MEMBER_BREAK_KEYWORD = tuple(KIND_BREAK_STATEMENT, 'break_keyword');
const Member MEMBER_BREAK_SEMICOLON = tuple(KIND_BREAK_STATEMENT, 'break_semicolon');
const Member MEMBER_CASE_COLON = tuple(KIND_CASE_LABEL, 'case_colon');
const Member MEMBER_CASE_EXPRESSION = tuple(KIND_CASE_LABEL, 'case_expression');
const Member MEMBER_CASE_KEYWORD = tuple(KIND_CASE_LABEL, 'case_keyword');
const Member MEMBER_CASE_TYPE_AS = tuple(KIND_CASE_TYPE_DECLARATION, 'case_type_as');
const Member MEMBER_CASE_TYPE_ATTRIBUTE_SPEC = tuple(KIND_CASE_TYPE_DECLARATION, 'case_type_attribute_spec');
const Member MEMBER_CASE_TYPE_BOUNDS = tuple(KIND_CASE_TYPE_DECLARATION, 'case_type_bounds');
const Member MEMBER_CASE_TYPE_CASE_KEYWORD = tuple(KIND_CASE_TYPE_DECLARATION, 'case_type_case_keyword');
const Member MEMBER_CASE_TYPE_EQUAL = tuple(KIND_CASE_TYPE_DECLARATION, 'case_type_equal');
const Member MEMBER_CASE_TYPE_GENERIC_PARAMETER = tuple(KIND_CASE_TYPE_DECLARATION, 'case_type_generic_parameter');
const Member MEMBER_CASE_TYPE_MODIFIERS = tuple(KIND_CASE_TYPE_DECLARATION, 'case_type_modifiers');
const Member MEMBER_CASE_TYPE_NAME = tuple(KIND_CASE_TYPE_DECLARATION, 'case_type_name');
const Member MEMBER_CASE_TYPE_SEMICOLON = tuple(KIND_CASE_TYPE_DECLARATION, 'case_type_semicolon');
const Member MEMBER_CASE_TYPE_TYPE_KEYWORD = tuple(KIND_CASE_TYPE_DECLARATION, 'case_type_type_keyword');
const Member MEMBER_CASE_TYPE_VARIANT_BAR = tuple(KIND_CASE_TYPE_VARIANT, 'case_type_variant_bar');
const Member MEMBER_CASE_TYPE_VARIANT_TYPE = tuple(KIND_CASE_TYPE_VARIANT, 'case_type_variant_type');
const Member MEMBER_CASE_TYPE_VARIANT_WHERE_CLAUSE = tuple(KIND_CASE_TYPE_VARIANT, 'case_type_variant_where_clause');
const Member MEMBER_CASE_TYPE_VARIANTS = tuple(KIND_CASE_TYPE_DECLARATION, 'case_type_variants');
const Member MEMBER_CAST_LEFT_PAREN = tuple(KIND_CAST_EXPRESSION, 'cast_left_paren');
const Member MEMBER_CAST_OPERAND = tuple(KIND_CAST_EXPRESSION, 'cast_operand');
const Member MEMBER_CAST_RIGHT_PAREN = tuple(KIND_CAST_EXPRESSION, 'cast_right_paren');
const Member MEMBER_CAST_TYPE = tuple(KIND_CAST_EXPRESSION, 'cast_type');
const Member MEMBER_CATCH_BODY = tuple(KIND_CATCH_CLAUSE, 'catch_body');
const Member MEMBER_CATCH_KEYWORD = tuple(KIND_CATCH_CLAUSE, 'catch_keyword');
const Member MEMBER_CATCH_LEFT_PAREN = tuple(KIND_CATCH_CLAUSE, 'catch_left_paren');
const Member MEMBER_CATCH_RIGHT_PAREN = tuple(KIND_CATCH_CLAUSE, 'catch_right_paren');
const Member MEMBER_CATCH_TYPE = tuple(KIND_CATCH_CLAUSE, 'catch_type');
const Member MEMBER_CATCH_VARIABLE = tuple(KIND_CATCH_CLAUSE, 'catch_variable');
const Member MEMBER_CLASS_PTR_KEYWORD = tuple(KIND_CLASS_PTR_TYPE_SPECIFIER, 'class_ptr_keyword');
const Member MEMBER_CLASS_PTR_LEFT_ANGLE = tuple(KIND_CLASS_PTR_TYPE_SPECIFIER, 'class_ptr_left_angle');
const Member MEMBER_CLASS_PTR_RIGHT_ANGLE = tuple(KIND_CLASS_PTR_TYPE_SPECIFIER, 'class_ptr_right_angle');
const Member MEMBER_CLASS_PTR_TRAILING_COMMA = tuple(KIND_CLASS_PTR_TYPE_SPECIFIER, 'class_ptr_trailing_comma');
const Member MEMBER_CLASS_PTR_TYPE = tuple(KIND_CLASS_PTR_TYPE_SPECIFIER, 'class_ptr_type');
const Member MEMBER_CLASSISH_ATTRIBUTE = tuple(KIND_CLASSISH_DECLARATION, 'classish_attribute');
const Member MEMBER_CLASSISH_BODY = tuple(KIND_CLASSISH_DECLARATION, 'classish_body');
const Member MEMBER_CLASSISH_BODY_ELEMENTS = tuple(KIND_CLASSISH_BODY, 'classish_body_elements');
const Member MEMBER_CLASSISH_BODY_LEFT_BRACE = tuple(KIND_CLASSISH_BODY, 'classish_body_left_brace');
const Member MEMBER_CLASSISH_BODY_RIGHT_BRACE = tuple(KIND_CLASSISH_BODY, 'classish_body_right_brace');
const Member MEMBER_CLASSISH_EXTENDS_KEYWORD = tuple(KIND_CLASSISH_DECLARATION, 'classish_extends_keyword');
const Member MEMBER_CLASSISH_EXTENDS_LIST = tuple(KIND_CLASSISH_DECLARATION, 'classish_extends_list');
const Member MEMBER_CLASSISH_IMPLEMENTS_KEYWORD = tuple(KIND_CLASSISH_DECLARATION, 'classish_implements_keyword');
const Member MEMBER_CLASSISH_IMPLEMENTS_LIST = tuple(KIND_CLASSISH_DECLARATION, 'classish_implements_list');
const Member MEMBER_CLASSISH_KEYWORD = tuple(KIND_CLASSISH_DECLARATION, 'classish_keyword');
const Member MEMBER_CLASSISH_MODIFIERS = tuple(KIND_CLASSISH_DECLARATION, 'classish_modifiers');
const Member MEMBER_CLASSISH_NAME = tuple(KIND_CLASSISH_DECLARATION, 'classish_name');
const Member MEMBER_CLASSISH_TYPE_PARAMETERS = tuple(KIND_CLASSISH_DECLARATION, 'classish_type_parameters');
const Member MEMBER_CLASSISH_WHERE_CLAUSE = tuple(KIND_CLASSISH_DECLARATION, 'classish_where_clause');
const Member MEMBER_CLASSISH_XHP = tuple(KIND_CLASSISH_DECLARATION, 'classish_xhp');
const Member MEMBER_CLASSNAME_KEYWORD = tuple(KIND_CLASSNAME_TYPE_SPECIFIER, 'classname_keyword');
const Member MEMBER_CLASSNAME_LEFT_ANGLE = tuple(KIND_CLASSNAME_TYPE_SPECIFIER, 'classname_left_angle');
const Member MEMBER_CLASSNAME_RIGHT_ANGLE = tuple(KIND_CLASSNAME_TYPE_SPECIFIER, 'classname_right_angle');
const Member MEMBER_CLASSNAME_TRAILING_COMMA = tuple(KIND_CLASSNAME_TYPE_SPECIFIER, 'classname_trailing_comma');
const Member MEMBER_CLASSNAME_TYPE = tuple(KIND_CLASSNAME_TYPE_SPECIFIER, 'classname_type');
const Member MEMBER_CLOSURE_COLON = tuple(KIND_CLOSURE_TYPE_SPECIFIER, 'closure_colon');
const Member MEMBER_CLOSURE_CONTEXTS = tuple(KIND_CLOSURE_TYPE_SPECIFIER, 'closure_contexts');
const Member MEMBER_CLOSURE_FUNCTION_KEYWORD = tuple(KIND_CLOSURE_TYPE_SPECIFIER, 'closure_function_keyword');
const Member MEMBER_CLOSURE_INNER_LEFT_PAREN = tuple(KIND_CLOSURE_TYPE_SPECIFIER, 'closure_inner_left_paren');
const Member MEMBER_CLOSURE_INNER_RIGHT_PAREN = tuple(KIND_CLOSURE_TYPE_SPECIFIER, 'closure_inner_right_paren');
const Member MEMBER_CLOSURE_OUTER_LEFT_PAREN = tuple(KIND_CLOSURE_TYPE_SPECIFIER, 'closure_outer_left_paren');
const Member MEMBER_CLOSURE_OUTER_RIGHT_PAREN = tuple(KIND_CLOSURE_TYPE_SPECIFIER, 'closure_outer_right_paren');
const Member MEMBER_CLOSURE_PARAMETER_CALL_CONVENTION = tuple(KIND_CLOSURE_PARAMETER_TYPE_SPECIFIER, 'closure_parameter_call_convention');
const Member MEMBER_CLOSURE_PARAMETER_ELLIPSIS = tuple(KIND_CLOSURE_PARAMETER_TYPE_SPECIFIER, 'closure_parameter_ellipsis');
const Member MEMBER_CLOSURE_PARAMETER_LIST = tuple(KIND_CLOSURE_TYPE_SPECIFIER, 'closure_parameter_list');
const Member MEMBER_CLOSURE_PARAMETER_OPTIONAL = tuple(KIND_CLOSURE_PARAMETER_TYPE_SPECIFIER, 'closure_parameter_optional');
const Member MEMBER_CLOSURE_PARAMETER_PRE_ELLIPSIS = tuple(KIND_CLOSURE_PARAMETER_TYPE_SPECIFIER, 'closure_parameter_pre_ellipsis');
const Member MEMBER_CLOSURE_PARAMETER_READONLY = tuple(KIND_CLOSURE_PARAMETER_TYPE_SPECIFIER, 'closure_parameter_readonly');
const Member MEMBER_CLOSURE_PARAMETER_TYPE = tuple(KIND_CLOSURE_PARAMETER_TYPE_SPECIFIER, 'closure_parameter_type');
const Member MEMBER_CLOSURE_READONLY_KEYWORD = tuple(KIND_CLOSURE_TYPE_SPECIFIER, 'closure_readonly_keyword');
const Member MEMBER_CLOSURE_READONLY_RETURN = tuple(KIND_CLOSURE_TYPE_SPECIFIER, 'closure_readonly_return');
const Member MEMBER_CLOSURE_RETURN_TYPE = tuple(KIND_CLOSURE_TYPE_SPECIFIER, 'closure_return_type');
const Member MEMBER_CLOSURE_TYPE_PARAMETERS = tuple(KIND_CLOSURE_TYPE_SPECIFIER, 'closure_type_parameters');
const Member MEMBER_COLLECTION_LITERAL_INITIALIZERS = tuple(KIND_COLLECTION_LITERAL_EXPRESSION, 'collection_literal_initializers');
const Member MEMBER_COLLECTION_LITERAL_LEFT_BRACE = tuple(KIND_COLLECTION_LITERAL_EXPRESSION, 'collection_literal_left_brace');
const Member MEMBER_COLLECTION_LITERAL_NAME = tuple(KIND_COLLECTION_LITERAL_EXPRESSION, 'collection_literal_name');
const Member MEMBER_COLLECTION_LITERAL_RIGHT_BRACE = tuple(KIND_COLLECTION_LITERAL_EXPRESSION, 'collection_literal_right_brace');
const Member MEMBER_COMPOUND_LEFT_BRACE = tuple(KIND_COMPOUND_STATEMENT, 'compound_left_brace');
const Member MEMBER_COMPOUND_RIGHT_BRACE = tuple(KIND_COMPOUND_STATEMENT, 'compound_right_brace');
const Member MEMBER_COMPOUND_STATEMENTS = tuple(KIND_COMPOUND_STATEMENT, 'compound_statements');
const Member MEMBER_CONCURRENT_KEYWORD = tuple(KIND_CONCURRENT_STATEMENT, 'concurrent_keyword');
const Member MEMBER_CONCURRENT_STATEMENT = tuple(KIND_CONCURRENT_STATEMENT, 'concurrent_statement');
const Member MEMBER_CONDITIONAL_ALTERNATIVE = tuple(KIND_CONDITIONAL_EXPRESSION, 'conditional_alternative');
const Member MEMBER_CONDITIONAL_COLON = tuple(KIND_CONDITIONAL_EXPRESSION, 'conditional_colon');
const Member MEMBER_CONDITIONAL_CONSEQUENCE = tuple(KIND_CONDITIONAL_EXPRESSION, 'conditional_consequence');
const Member MEMBER_CONDITIONAL_QUESTION = tuple(KIND_CONDITIONAL_EXPRESSION, 'conditional_question');
const Member MEMBER_CONDITIONAL_TEST = tuple(KIND_CONDITIONAL_EXPRESSION, 'conditional_test');
const Member MEMBER_CONST_ATTRIBUTE_SPEC = tuple(KIND_CONST_DECLARATION, 'const_attribute_spec');
const Member MEMBER_CONST_DECLARATORS = tuple(KIND_CONST_DECLARATION, 'const_declarators');
const Member MEMBER_CONST_KEYWORD = tuple(KIND_CONST_DECLARATION, 'const_keyword');
const Member MEMBER_CONST_MODIFIERS = tuple(KIND_CONST_DECLARATION, 'const_modifiers');
const Member MEMBER_CONST_SEMICOLON = tuple(KIND_CONST_DECLARATION, 'const_semicolon');
const Member MEMBER_CONST_TYPE_SPECIFIER = tuple(KIND_CONST_DECLARATION, 'const_type_specifier');
const Member MEMBER_CONSTANT_DECLARATOR_INITIALIZER = tuple(KIND_CONSTANT_DECLARATOR, 'constant_declarator_initializer');
const Member MEMBER_CONSTANT_DECLARATOR_NAME = tuple(KIND_CONSTANT_DECLARATOR, 'constant_declarator_name');
const Member MEMBER_CONSTRAINT_KEYWORD = tuple(KIND_TYPE_CONSTRAINT, 'constraint_keyword');
const Member MEMBER_CONSTRAINT_TYPE = tuple(KIND_TYPE_CONSTRAINT, 'constraint_type');
const Member MEMBER_CONSTRUCTOR_CALL_ARGUMENT_LIST = tuple(KIND_CONSTRUCTOR_CALL, 'constructor_call_argument_list');
const Member MEMBER_CONSTRUCTOR_CALL_LEFT_PAREN = tuple(KIND_CONSTRUCTOR_CALL, 'constructor_call_left_paren');
const Member MEMBER_CONSTRUCTOR_CALL_RIGHT_PAREN = tuple(KIND_CONSTRUCTOR_CALL, 'constructor_call_right_paren');
const Member MEMBER_CONSTRUCTOR_CALL_TYPE = tuple(KIND_CONSTRUCTOR_CALL, 'constructor_call_type');
const Member MEMBER_CONSTRUCTOR_PATTERN_CONSTRUCTOR = tuple(KIND_CONSTRUCTOR_PATTERN, 'constructor_pattern_constructor');
const Member MEMBER_CONSTRUCTOR_PATTERN_LEFT_PAREN = tuple(KIND_CONSTRUCTOR_PATTERN, 'constructor_pattern_left_paren');
const Member MEMBER_CONSTRUCTOR_PATTERN_MEMBERS = tuple(KIND_CONSTRUCTOR_PATTERN, 'constructor_pattern_members');
const Member MEMBER_CONSTRUCTOR_PATTERN_RIGHT_PAREN = tuple(KIND_CONSTRUCTOR_PATTERN, 'constructor_pattern_right_paren');
const Member MEMBER_CONTEXT_CONST_CONST_KEYWORD = tuple(KIND_CONTEXT_CONST_DECLARATION, 'context_const_const_keyword');
const Member MEMBER_CONTEXT_CONST_CONSTRAINT = tuple(KIND_CONTEXT_CONST_DECLARATION, 'context_const_constraint');
const Member MEMBER_CONTEXT_CONST_CTX_KEYWORD = tuple(KIND_CONTEXT_CONST_DECLARATION, 'context_const_ctx_keyword');
const Member MEMBER_CONTEXT_CONST_CTX_LIST = tuple(KIND_CONTEXT_CONST_DECLARATION, 'context_const_ctx_list');
const Member MEMBER_CONTEXT_CONST_EQUAL = tuple(KIND_CONTEXT_CONST_DECLARATION, 'context_const_equal');
const Member MEMBER_CONTEXT_CONST_MODIFIERS = tuple(KIND_CONTEXT_CONST_DECLARATION, 'context_const_modifiers');
const Member MEMBER_CONTEXT_CONST_NAME = tuple(KIND_CONTEXT_CONST_DECLARATION, 'context_const_name');
const Member MEMBER_CONTEXT_CONST_SEMICOLON = tuple(KIND_CONTEXT_CONST_DECLARATION, 'context_const_semicolon');
const Member MEMBER_CONTEXT_CONST_TYPE_PARAMETERS = tuple(KIND_CONTEXT_CONST_DECLARATION, 'context_const_type_parameters');
const Member MEMBER_CONTEXTS_LEFT_BRACKET = tuple(KIND_CONTEXTS, 'contexts_left_bracket');
const Member MEMBER_CONTEXTS_RIGHT_BRACKET = tuple(KIND_CONTEXTS, 'contexts_right_bracket');
const Member MEMBER_CONTEXTS_TYPES = tuple(KIND_CONTEXTS, 'contexts_types');
const Member MEMBER_CONTINUE_KEYWORD = tuple(KIND_CONTINUE_STATEMENT, 'continue_keyword');
const Member MEMBER_CONTINUE_SEMICOLON = tuple(KIND_CONTINUE_STATEMENT, 'continue_semicolon');
const Member MEMBER_CTX_ALIAS_AS_CONSTRAINT = tuple(KIND_CONTEXT_ALIAS_DECLARATION, 'ctx_alias_as_constraint');
const Member MEMBER_CTX_ALIAS_ATTRIBUTE_SPEC = tuple(KIND_CONTEXT_ALIAS_DECLARATION, 'ctx_alias_attribute_spec');
const Member MEMBER_CTX_ALIAS_CONTEXT = tuple(KIND_CONTEXT_ALIAS_DECLARATION, 'ctx_alias_context');
const Member MEMBER_CTX_ALIAS_EQUAL = tuple(KIND_CONTEXT_ALIAS_DECLARATION, 'ctx_alias_equal');
const Member MEMBER_CTX_ALIAS_GENERIC_PARAMETER = tuple(KIND_CONTEXT_ALIAS_DECLARATION, 'ctx_alias_generic_parameter');
const Member MEMBER_CTX_ALIAS_KEYWORD = tuple(KIND_CONTEXT_ALIAS_DECLARATION, 'ctx_alias_keyword');
const Member MEMBER_CTX_ALIAS_NAME = tuple(KIND_CONTEXT_ALIAS_DECLARATION, 'ctx_alias_name');
const Member MEMBER_CTX_ALIAS_SEMICOLON = tuple(KIND_CONTEXT_ALIAS_DECLARATION, 'ctx_alias_semicolon');
const Member MEMBER_CTX_CONSTRAINT_CTX_LIST = tuple(KIND_CONTEXT_CONSTRAINT, 'ctx_constraint_ctx_list');
const Member MEMBER_CTX_CONSTRAINT_KEYWORD = tuple(KIND_CONTEXT_CONSTRAINT, 'ctx_constraint_keyword');
const Member MEMBER_CTX_IN_REFINEMENT_CONSTRAINTS = tuple(KIND_CTX_IN_REFINEMENT, 'ctx_in_refinement_constraints');
const Member MEMBER_CTX_IN_REFINEMENT_CTX_LIST = tuple(KIND_CTX_IN_REFINEMENT, 'ctx_in_refinement_ctx_list');
const Member MEMBER_CTX_IN_REFINEMENT_EQUAL = tuple(KIND_CTX_IN_REFINEMENT, 'ctx_in_refinement_equal');
const Member MEMBER_CTX_IN_REFINEMENT_KEYWORD = tuple(KIND_CTX_IN_REFINEMENT, 'ctx_in_refinement_keyword');
const Member MEMBER_CTX_IN_REFINEMENT_NAME = tuple(KIND_CTX_IN_REFINEMENT, 'ctx_in_refinement_name');
const Member MEMBER_CTX_IN_REFINEMENT_TYPE_PARAMETERS = tuple(KIND_CTX_IN_REFINEMENT, 'ctx_in_refinement_type_parameters');
const Member MEMBER_DARRAY_COMMA = tuple(KIND_DARRAY_TYPE_SPECIFIER, 'darray_comma');
const Member MEMBER_DARRAY_INTRINSIC_EXPLICIT_TYPE = tuple(KIND_DARRAY_INTRINSIC_EXPRESSION, 'darray_intrinsic_explicit_type');
const Member MEMBER_DARRAY_INTRINSIC_KEYWORD = tuple(KIND_DARRAY_INTRINSIC_EXPRESSION, 'darray_intrinsic_keyword');
const Member MEMBER_DARRAY_INTRINSIC_LEFT_BRACKET = tuple(KIND_DARRAY_INTRINSIC_EXPRESSION, 'darray_intrinsic_left_bracket');
const Member MEMBER_DARRAY_INTRINSIC_MEMBERS = tuple(KIND_DARRAY_INTRINSIC_EXPRESSION, 'darray_intrinsic_members');
const Member MEMBER_DARRAY_INTRINSIC_RIGHT_BRACKET = tuple(KIND_DARRAY_INTRINSIC_EXPRESSION, 'darray_intrinsic_right_bracket');
const Member MEMBER_DARRAY_KEY = tuple(KIND_DARRAY_TYPE_SPECIFIER, 'darray_key');
const Member MEMBER_DARRAY_KEYWORD = tuple(KIND_DARRAY_TYPE_SPECIFIER, 'darray_keyword');
const Member MEMBER_DARRAY_LEFT_ANGLE = tuple(KIND_DARRAY_TYPE_SPECIFIER, 'darray_left_angle');
const Member MEMBER_DARRAY_RIGHT_ANGLE = tuple(KIND_DARRAY_TYPE_SPECIFIER, 'darray_right_angle');
const Member MEMBER_DARRAY_TRAILING_COMMA = tuple(KIND_DARRAY_TYPE_SPECIFIER, 'darray_trailing_comma');
const Member MEMBER_DARRAY_VALUE = tuple(KIND_DARRAY_TYPE_SPECIFIER, 'darray_value');
const Member MEMBER_DECLARE_LOCAL_COLON = tuple(KIND_DECLARE_LOCAL_STATEMENT, 'declare_local_colon');
const Member MEMBER_DECLARE_LOCAL_INITIALIZER = tuple(KIND_DECLARE_LOCAL_STATEMENT, 'declare_local_initializer');
const Member MEMBER_DECLARE_LOCAL_KEYWORD = tuple(KIND_DECLARE_LOCAL_STATEMENT, 'declare_local_keyword');
const Member MEMBER_DECLARE_LOCAL_SEMICOLON = tuple(KIND_DECLARE_LOCAL_STATEMENT, 'declare_local_semicolon');
const Member MEMBER_DECLARE_LOCAL_TYPE = tuple(KIND_DECLARE_LOCAL_STATEMENT, 'declare_local_type');
const Member MEMBER_DECLARE_LOCAL_VARIABLE = tuple(KIND_DECLARE_LOCAL_STATEMENT, 'declare_local_variable');
const Member MEMBER_DECORATED_EXPRESSION_DECORATOR = tuple(KIND_DECORATED_EXPRESSION, 'decorated_expression_decorator');
const Member MEMBER_DECORATED_EXPRESSION_EXPRESSION = tuple(KIND_DECORATED_EXPRESSION, 'decorated_expression_expression');
const Member MEMBER_DEFAULT_COLON = tuple(KIND_DEFAULT_LABEL, 'default_colon');
const Member MEMBER_DEFAULT_KEYWORD = tuple(KIND_DEFAULT_LABEL, 'default_keyword');
const Member MEMBER_DEFINE_ARGUMENT_LIST = tuple(KIND_DEFINE_EXPRESSION, 'define_argument_list');
const Member MEMBER_DEFINE_KEYWORD = tuple(KIND_DEFINE_EXPRESSION, 'define_keyword');
const Member MEMBER_DEFINE_LEFT_PAREN = tuple(KIND_DEFINE_EXPRESSION, 'define_left_paren');
const Member MEMBER_DEFINE_RIGHT_PAREN = tuple(KIND_DEFINE_EXPRESSION, 'define_right_paren');
const Member MEMBER_DICTIONARY_INTRINSIC_EXPLICIT_TYPE = tuple(KIND_DICTIONARY_INTRINSIC_EXPRESSION, 'dictionary_intrinsic_explicit_type');
const Member MEMBER_DICTIONARY_INTRINSIC_KEYWORD = tuple(KIND_DICTIONARY_INTRINSIC_EXPRESSION, 'dictionary_intrinsic_keyword');
const Member MEMBER_DICTIONARY_INTRINSIC_LEFT_BRACKET = tuple(KIND_DICTIONARY_INTRINSIC_EXPRESSION, 'dictionary_intrinsic_left_bracket');
const Member MEMBER_DICTIONARY_INTRINSIC_MEMBERS = tuple(KIND_DICTIONARY_INTRINSIC_EXPRESSION, 'dictionary_intrinsic_members');
const Member MEMBER_DICTIONARY_INTRINSIC_RIGHT_BRACKET = tuple(KIND_DICTIONARY_INTRINSIC_EXPRESSION, 'dictionary_intrinsic_right_bracket');
const Member MEMBER_DICTIONARY_TYPE_KEYWORD = tuple(KIND_DICTIONARY_TYPE_SPECIFIER, 'dictionary_type_keyword');
const Member MEMBER_DICTIONARY_TYPE_LEFT_ANGLE = tuple(KIND_DICTIONARY_TYPE_SPECIFIER, 'dictionary_type_left_angle');
const Member MEMBER_DICTIONARY_TYPE_MEMBERS = tuple(KIND_DICTIONARY_TYPE_SPECIFIER, 'dictionary_type_members');
const Member MEMBER_DICTIONARY_TYPE_RIGHT_ANGLE = tuple(KIND_DICTIONARY_TYPE_SPECIFIER, 'dictionary_type_right_angle');
const Member MEMBER_DO_BODY = tuple(KIND_DO_STATEMENT, 'do_body');
const Member MEMBER_DO_CONDITION = tuple(KIND_DO_STATEMENT, 'do_condition');
const Member MEMBER_DO_KEYWORD = tuple(KIND_DO_STATEMENT, 'do_keyword');
const Member MEMBER_DO_LEFT_PAREN = tuple(KIND_DO_STATEMENT, 'do_left_paren');
const Member MEMBER_DO_RIGHT_PAREN = tuple(KIND_DO_STATEMENT, 'do_right_paren');
const Member MEMBER_DO_SEMICOLON = tuple(KIND_DO_STATEMENT, 'do_semicolon');
const Member MEMBER_DO_WHILE_KEYWORD = tuple(KIND_DO_STATEMENT, 'do_while_keyword');
const Member MEMBER_ECHO_EXPRESSIONS = tuple(KIND_ECHO_STATEMENT, 'echo_expressions');
const Member MEMBER_ECHO_KEYWORD = tuple(KIND_ECHO_STATEMENT, 'echo_keyword');
const Member MEMBER_ECHO_SEMICOLON = tuple(KIND_ECHO_STATEMENT, 'echo_semicolon');
const Member MEMBER_ELEMENT_ARROW = tuple(KIND_ELEMENT_INITIALIZER, 'element_arrow');
const Member MEMBER_ELEMENT_KEY = tuple(KIND_ELEMENT_INITIALIZER, 'element_key');
const Member MEMBER_ELEMENT_VALUE = tuple(KIND_ELEMENT_INITIALIZER, 'element_value');
const Member MEMBER_ELSE_KEYWORD = tuple(KIND_ELSE_CLAUSE, 'else_keyword');
const Member MEMBER_ELSE_STATEMENT = tuple(KIND_ELSE_CLAUSE, 'else_statement');
const Member MEMBER_ELSEIF_CONDITION = tuple(KIND_ELSEIF_CLAUSE, 'elseif_condition');
const Member MEMBER_ELSEIF_KEYWORD = tuple(KIND_ELSEIF_CLAUSE, 'elseif_keyword');
const Member MEMBER_ELSEIF_LEFT_PAREN = tuple(KIND_ELSEIF_CLAUSE, 'elseif_left_paren');
const Member MEMBER_ELSEIF_RIGHT_PAREN = tuple(KIND_ELSEIF_CLAUSE, 'elseif_right_paren');
const Member MEMBER_ELSEIF_STATEMENT = tuple(KIND_ELSEIF_CLAUSE, 'elseif_statement');
const Member MEMBER_EMBEDDED_BRACED_EXPRESSION_EXPRESSION = tuple(KIND_EMBEDDED_BRACED_EXPRESSION, 'embedded_braced_expression_expression');
const Member MEMBER_EMBEDDED_BRACED_EXPRESSION_LEFT_BRACE = tuple(KIND_EMBEDDED_BRACED_EXPRESSION, 'embedded_braced_expression_left_brace');
const Member MEMBER_EMBEDDED_BRACED_EXPRESSION_RIGHT_BRACE = tuple(KIND_EMBEDDED_BRACED_EXPRESSION, 'embedded_braced_expression_right_brace');
const Member MEMBER_EMBEDDED_MEMBER_NAME = tuple(KIND_EMBEDDED_MEMBER_SELECTION_EXPRESSION, 'embedded_member_name');
const Member MEMBER_EMBEDDED_MEMBER_OBJECT = tuple(KIND_EMBEDDED_MEMBER_SELECTION_EXPRESSION, 'embedded_member_object');
const Member MEMBER_EMBEDDED_MEMBER_OPERATOR = tuple(KIND_EMBEDDED_MEMBER_SELECTION_EXPRESSION, 'embedded_member_operator');
const Member MEMBER_EMBEDDED_SUBSCRIPT_INDEX = tuple(KIND_EMBEDDED_SUBSCRIPT_EXPRESSION, 'embedded_subscript_index');
const Member MEMBER_EMBEDDED_SUBSCRIPT_LEFT_BRACKET = tuple(KIND_EMBEDDED_SUBSCRIPT_EXPRESSION, 'embedded_subscript_left_bracket');
const Member MEMBER_EMBEDDED_SUBSCRIPT_RECEIVER = tuple(KIND_EMBEDDED_SUBSCRIPT_EXPRESSION, 'embedded_subscript_receiver');
const Member MEMBER_EMBEDDED_SUBSCRIPT_RIGHT_BRACKET = tuple(KIND_EMBEDDED_SUBSCRIPT_EXPRESSION, 'embedded_subscript_right_bracket');
const Member MEMBER_END_OF_FILE_TOKEN = tuple(KIND_END_OF_FILE, 'end_of_file_token');
const Member MEMBER_ENUM_ATOM_EXPRESSION = tuple(KIND_ENUM_ATOM_EXPRESSION, 'enum_atom_expression');
const Member MEMBER_ENUM_ATOM_HASH = tuple(KIND_ENUM_ATOM_EXPRESSION, 'enum_atom_hash');
const Member MEMBER_ENUM_ATTRIBUTE_SPEC = tuple(KIND_ENUM_DECLARATION, 'enum_attribute_spec');
const Member MEMBER_ENUM_BASE = tuple(KIND_ENUM_DECLARATION, 'enum_base');
const Member MEMBER_ENUM_CLASS_ATTRIBUTE_SPEC = tuple(KIND_ENUM_CLASS_DECLARATION, 'enum_class_attribute_spec');
const Member MEMBER_ENUM_CLASS_BASE = tuple(KIND_ENUM_CLASS_DECLARATION, 'enum_class_base');
const Member MEMBER_ENUM_CLASS_CLASS_KEYWORD = tuple(KIND_ENUM_CLASS_DECLARATION, 'enum_class_class_keyword');
const Member MEMBER_ENUM_CLASS_COLON = tuple(KIND_ENUM_CLASS_DECLARATION, 'enum_class_colon');
const Member MEMBER_ENUM_CLASS_ELEMENTS = tuple(KIND_ENUM_CLASS_DECLARATION, 'enum_class_elements');
const Member MEMBER_ENUM_CLASS_ENUM_KEYWORD = tuple(KIND_ENUM_CLASS_DECLARATION, 'enum_class_enum_keyword');
const Member MEMBER_ENUM_CLASS_ENUMERATOR_EQUAL = tuple(KIND_ENUM_CLASS_ENUMERATOR, 'enum_class_enumerator_equal');
const Member MEMBER_ENUM_CLASS_ENUMERATOR_INITIAL_VALUE = tuple(KIND_ENUM_CLASS_ENUMERATOR, 'enum_class_enumerator_initial_value');
const Member MEMBER_ENUM_CLASS_ENUMERATOR_INITIALIZER = tuple(KIND_ENUM_CLASS_ENUMERATOR, 'enum_class_enumerator_initializer');
const Member MEMBER_ENUM_CLASS_ENUMERATOR_MODIFIERS = tuple(KIND_ENUM_CLASS_ENUMERATOR, 'enum_class_enumerator_modifiers');
const Member MEMBER_ENUM_CLASS_ENUMERATOR_NAME = tuple(KIND_ENUM_CLASS_ENUMERATOR, 'enum_class_enumerator_name');
const Member MEMBER_ENUM_CLASS_ENUMERATOR_SEMICOLON = tuple(KIND_ENUM_CLASS_ENUMERATOR, 'enum_class_enumerator_semicolon');
const Member MEMBER_ENUM_CLASS_ENUMERATOR_TYPE = tuple(KIND_ENUM_CLASS_ENUMERATOR, 'enum_class_enumerator_type');
const Member MEMBER_ENUM_CLASS_EXTENDS = tuple(KIND_ENUM_CLASS_DECLARATION, 'enum_class_extends');
const Member MEMBER_ENUM_CLASS_EXTENDS_LIST = tuple(KIND_ENUM_CLASS_DECLARATION, 'enum_class_extends_list');
const Member MEMBER_ENUM_CLASS_LABEL_EXPRESSION = tuple(KIND_ENUM_CLASS_LABEL_EXPRESSION, 'enum_class_label_expression');
const Member MEMBER_ENUM_CLASS_LABEL_HASH = tuple(KIND_ENUM_CLASS_LABEL_EXPRESSION, 'enum_class_label_hash');
const Member MEMBER_ENUM_CLASS_LABEL_QUALIFIER = tuple(KIND_ENUM_CLASS_LABEL_EXPRESSION, 'enum_class_label_qualifier');
const Member MEMBER_ENUM_CLASS_LEFT_BRACE = tuple(KIND_ENUM_CLASS_DECLARATION, 'enum_class_left_brace');
const Member MEMBER_ENUM_CLASS_MODIFIERS = tuple(KIND_ENUM_CLASS_DECLARATION, 'enum_class_modifiers');
const Member MEMBER_ENUM_CLASS_NAME = tuple(KIND_ENUM_CLASS_DECLARATION, 'enum_class_name');
const Member MEMBER_ENUM_CLASS_RIGHT_BRACE = tuple(KIND_ENUM_CLASS_DECLARATION, 'enum_class_right_brace');
const Member MEMBER_ENUM_COLON = tuple(KIND_ENUM_DECLARATION, 'enum_colon');
const Member MEMBER_ENUM_ENUMERATORS = tuple(KIND_ENUM_DECLARATION, 'enum_enumerators');
const Member MEMBER_ENUM_KEYWORD = tuple(KIND_ENUM_DECLARATION, 'enum_keyword');
const Member MEMBER_ENUM_LEFT_BRACE = tuple(KIND_ENUM_DECLARATION, 'enum_left_brace');
const Member MEMBER_ENUM_MODIFIERS = tuple(KIND_ENUM_DECLARATION, 'enum_modifiers');
const Member MEMBER_ENUM_NAME = tuple(KIND_ENUM_DECLARATION, 'enum_name');
const Member MEMBER_ENUM_RIGHT_BRACE = tuple(KIND_ENUM_DECLARATION, 'enum_right_brace');
const Member MEMBER_ENUM_TYPE = tuple(KIND_ENUM_DECLARATION, 'enum_type');
const Member MEMBER_ENUM_USE_CLAUSES = tuple(KIND_ENUM_DECLARATION, 'enum_use_clauses');
const Member MEMBER_ENUM_USE_KEYWORD = tuple(KIND_ENUM_USE, 'enum_use_keyword');
const Member MEMBER_ENUM_USE_NAMES = tuple(KIND_ENUM_USE, 'enum_use_names');
const Member MEMBER_ENUM_USE_SEMICOLON = tuple(KIND_ENUM_USE, 'enum_use_semicolon');
const Member MEMBER_ENUMERATOR_EQUAL = tuple(KIND_ENUMERATOR, 'enumerator_equal');
const Member MEMBER_ENUMERATOR_NAME = tuple(KIND_ENUMERATOR, 'enumerator_name');
const Member MEMBER_ENUMERATOR_SEMICOLON = tuple(KIND_ENUMERATOR, 'enumerator_semicolon');
const Member MEMBER_ENUMERATOR_VALUE = tuple(KIND_ENUMERATOR, 'enumerator_value');
const Member MEMBER_ERROR_ERROR = tuple(KIND_ERROR_SYNTAX, 'error_error');
const Member MEMBER_ET_SPLICE_EXPRESSION_DOLLAR = tuple(KIND_ETSPLICE_EXPRESSION, 'et_splice_expression_dollar');
const Member MEMBER_ET_SPLICE_EXPRESSION_EXPRESSION = tuple(KIND_ETSPLICE_EXPRESSION, 'et_splice_expression_expression');
const Member MEMBER_ET_SPLICE_EXPRESSION_LEFT_BRACE = tuple(KIND_ETSPLICE_EXPRESSION, 'et_splice_expression_left_brace');
const Member MEMBER_ET_SPLICE_EXPRESSION_RIGHT_BRACE = tuple(KIND_ETSPLICE_EXPRESSION, 'et_splice_expression_right_brace');
const Member MEMBER_EVAL_ARGUMENT = tuple(KIND_EVAL_EXPRESSION, 'eval_argument');
const Member MEMBER_EVAL_KEYWORD = tuple(KIND_EVAL_EXPRESSION, 'eval_keyword');
const Member MEMBER_EVAL_LEFT_PAREN = tuple(KIND_EVAL_EXPRESSION, 'eval_left_paren');
const Member MEMBER_EVAL_RIGHT_PAREN = tuple(KIND_EVAL_EXPRESSION, 'eval_right_paren');
const Member MEMBER_EXPRESSION_STATEMENT_EXPRESSION = tuple(KIND_EXPRESSION_STATEMENT, 'expression_statement_expression');
const Member MEMBER_EXPRESSION_STATEMENT_SEMICOLON = tuple(KIND_EXPRESSION_STATEMENT, 'expression_statement_semicolon');
const Member MEMBER_FALLTHROUGH_KEYWORD = tuple(KIND_SWITCH_FALLTHROUGH, 'fallthrough_keyword');
const Member MEMBER_FALLTHROUGH_SEMICOLON = tuple(KIND_SWITCH_FALLTHROUGH, 'fallthrough_semicolon');
const Member MEMBER_FIELD_ARROW = tuple(KIND_FIELD_SPECIFIER, 'field_arrow');
const Member MEMBER_FIELD_INITIALIZER_ARROW = tuple(KIND_FIELD_INITIALIZER, 'field_initializer_arrow');
const Member MEMBER_FIELD_INITIALIZER_NAME = tuple(KIND_FIELD_INITIALIZER, 'field_initializer_name');
const Member MEMBER_FIELD_INITIALIZER_VALUE = tuple(KIND_FIELD_INITIALIZER, 'field_initializer_value');
const Member MEMBER_FIELD_NAME = tuple(KIND_FIELD_SPECIFIER, 'field_name');
const Member MEMBER_FIELD_QUESTION = tuple(KIND_FIELD_SPECIFIER, 'field_question');
const Member MEMBER_FIELD_TYPE = tuple(KIND_FIELD_SPECIFIER, 'field_type');
const Member MEMBER_FILE_ATTRIBUTE_SPECIFICATION_ATTRIBUTES = tuple(KIND_FILE_ATTRIBUTE_SPECIFICATION, 'file_attribute_specification_attributes');
const Member MEMBER_FILE_ATTRIBUTE_SPECIFICATION_COLON = tuple(KIND_FILE_ATTRIBUTE_SPECIFICATION, 'file_attribute_specification_colon');
const Member MEMBER_FILE_ATTRIBUTE_SPECIFICATION_KEYWORD = tuple(KIND_FILE_ATTRIBUTE_SPECIFICATION, 'file_attribute_specification_keyword');
const Member MEMBER_FILE_ATTRIBUTE_SPECIFICATION_LEFT_DOUBLE_ANGLE = tuple(KIND_FILE_ATTRIBUTE_SPECIFICATION, 'file_attribute_specification_left_double_angle');
const Member MEMBER_FILE_ATTRIBUTE_SPECIFICATION_RIGHT_DOUBLE_ANGLE = tuple(KIND_FILE_ATTRIBUTE_SPECIFICATION, 'file_attribute_specification_right_double_angle');
const Member MEMBER_FINALLY_BODY = tuple(KIND_FINALLY_CLAUSE, 'finally_body');
const Member MEMBER_FINALLY_KEYWORD = tuple(KIND_FINALLY_CLAUSE, 'finally_keyword');
const Member MEMBER_FOR_BODY = tuple(KIND_FOR_STATEMENT, 'for_body');
const Member MEMBER_FOR_CONTROL = tuple(KIND_FOR_STATEMENT, 'for_control');
const Member MEMBER_FOR_END_OF_LOOP = tuple(KIND_FOR_STATEMENT, 'for_end_of_loop');
const Member MEMBER_FOR_FIRST_SEMICOLON = tuple(KIND_FOR_STATEMENT, 'for_first_semicolon');
const Member MEMBER_FOR_INITIALIZER = tuple(KIND_FOR_STATEMENT, 'for_initializer');
const Member MEMBER_FOR_KEYWORD = tuple(KIND_FOR_STATEMENT, 'for_keyword');
const Member MEMBER_FOR_LEFT_PAREN = tuple(KIND_FOR_STATEMENT, 'for_left_paren');
const Member MEMBER_FOR_RIGHT_PAREN = tuple(KIND_FOR_STATEMENT, 'for_right_paren');
const Member MEMBER_FOR_SECOND_SEMICOLON = tuple(KIND_FOR_STATEMENT, 'for_second_semicolon');
const Member MEMBER_FOREACH_ARROW = tuple(KIND_FOREACH_STATEMENT, 'foreach_arrow');
const Member MEMBER_FOREACH_AS = tuple(KIND_FOREACH_STATEMENT, 'foreach_as');
const Member MEMBER_FOREACH_AWAIT_KEYWORD = tuple(KIND_FOREACH_STATEMENT, 'foreach_await_keyword');
const Member MEMBER_FOREACH_BODY = tuple(KIND_FOREACH_STATEMENT, 'foreach_body');
const Member MEMBER_FOREACH_COLLECTION = tuple(KIND_FOREACH_STATEMENT, 'foreach_collection');
const Member MEMBER_FOREACH_KEY = tuple(KIND_FOREACH_STATEMENT, 'foreach_key');
const Member MEMBER_FOREACH_KEYWORD = tuple(KIND_FOREACH_STATEMENT, 'foreach_keyword');
const Member MEMBER_FOREACH_LEFT_PAREN = tuple(KIND_FOREACH_STATEMENT, 'foreach_left_paren');
const Member MEMBER_FOREACH_RIGHT_PAREN = tuple(KIND_FOREACH_STATEMENT, 'foreach_right_paren');
const Member MEMBER_FOREACH_VALUE = tuple(KIND_FOREACH_STATEMENT, 'foreach_value');
const Member MEMBER_FUNCTION_ATTRIBUTE_SPEC = tuple(KIND_FUNCTION_DECLARATION, 'function_attribute_spec');
const Member MEMBER_FUNCTION_BODY = tuple(KIND_FUNCTION_DECLARATION, 'function_body');
const Member MEMBER_FUNCTION_CALL_ARGUMENT_LIST = tuple(KIND_FUNCTION_CALL_EXPRESSION, 'function_call_argument_list');
const Member MEMBER_FUNCTION_CALL_ENUM_ATOM = tuple(KIND_FUNCTION_CALL_EXPRESSION, 'function_call_enum_atom');
const Member MEMBER_FUNCTION_CALL_ENUM_CLASS_LABEL = tuple(KIND_FUNCTION_CALL_EXPRESSION, 'function_call_enum_class_label');
const Member MEMBER_FUNCTION_CALL_LEFT_PAREN = tuple(KIND_FUNCTION_CALL_EXPRESSION, 'function_call_left_paren');
const Member MEMBER_FUNCTION_CALL_RECEIVER = tuple(KIND_FUNCTION_CALL_EXPRESSION, 'function_call_receiver');
const Member MEMBER_FUNCTION_CALL_RIGHT_PAREN = tuple(KIND_FUNCTION_CALL_EXPRESSION, 'function_call_right_paren');
const Member MEMBER_FUNCTION_CALL_TYPE_ARGS = tuple(KIND_FUNCTION_CALL_EXPRESSION, 'function_call_type_args');
const Member MEMBER_FUNCTION_COLON = tuple(KIND_FUNCTION_DECLARATION_HEADER, 'function_colon');
const Member MEMBER_FUNCTION_CONTEXTS = tuple(KIND_FUNCTION_DECLARATION_HEADER, 'function_contexts');
const Member MEMBER_FUNCTION_CTX_TYPE_KEYWORD = tuple(KIND_FUNCTION_CTX_TYPE_SPECIFIER, 'function_ctx_type_keyword');
const Member MEMBER_FUNCTION_CTX_TYPE_VARIABLE = tuple(KIND_FUNCTION_CTX_TYPE_SPECIFIER, 'function_ctx_type_variable');
const Member MEMBER_FUNCTION_DECLARATION_HEADER = tuple(KIND_FUNCTION_DECLARATION, 'function_declaration_header');
const Member MEMBER_FUNCTION_KEYWORD = tuple(KIND_FUNCTION_DECLARATION_HEADER, 'function_keyword');
const Member MEMBER_FUNCTION_LEFT_PAREN = tuple(KIND_FUNCTION_DECLARATION_HEADER, 'function_left_paren');
const Member MEMBER_FUNCTION_MODIFIERS = tuple(KIND_FUNCTION_DECLARATION_HEADER, 'function_modifiers');
const Member MEMBER_FUNCTION_NAME = tuple(KIND_FUNCTION_DECLARATION_HEADER, 'function_name');
const Member MEMBER_FUNCTION_PARAMETER_LIST = tuple(KIND_FUNCTION_DECLARATION_HEADER, 'function_parameter_list');
const Member MEMBER_FUNCTION_POINTER_RECEIVER = tuple(KIND_FUNCTION_POINTER_EXPRESSION, 'function_pointer_receiver');
const Member MEMBER_FUNCTION_POINTER_TYPE_ARGS = tuple(KIND_FUNCTION_POINTER_EXPRESSION, 'function_pointer_type_args');
const Member MEMBER_FUNCTION_READONLY_RETURN = tuple(KIND_FUNCTION_DECLARATION_HEADER, 'function_readonly_return');
const Member MEMBER_FUNCTION_RIGHT_PAREN = tuple(KIND_FUNCTION_DECLARATION_HEADER, 'function_right_paren');
const Member MEMBER_FUNCTION_TYPE = tuple(KIND_FUNCTION_DECLARATION_HEADER, 'function_type');
const Member MEMBER_FUNCTION_TYPE_PARAMETER_LIST = tuple(KIND_FUNCTION_DECLARATION_HEADER, 'function_type_parameter_list');
const Member MEMBER_FUNCTION_WHERE_CLAUSE = tuple(KIND_FUNCTION_DECLARATION_HEADER, 'function_where_clause');
const Member MEMBER_GENERIC_ARGUMENT_LIST = tuple(KIND_GENERIC_TYPE_SPECIFIER, 'generic_argument_list');
const Member MEMBER_GENERIC_CLASS_TYPE = tuple(KIND_GENERIC_TYPE_SPECIFIER, 'generic_class_type');
const Member MEMBER_IF_CONDITION = tuple(KIND_IF_STATEMENT, 'if_condition');
const Member MEMBER_IF_ELSE_CLAUSE = tuple(KIND_IF_STATEMENT, 'if_else_clause');
const Member MEMBER_IF_ELSEIF_CLAUSES = tuple(KIND_IF_STATEMENT, 'if_elseif_clauses');
const Member MEMBER_IF_KEYWORD = tuple(KIND_IF_STATEMENT, 'if_keyword');
const Member MEMBER_IF_LEFT_PAREN = tuple(KIND_IF_STATEMENT, 'if_left_paren');
const Member MEMBER_IF_RIGHT_PAREN = tuple(KIND_IF_STATEMENT, 'if_right_paren');
const Member MEMBER_IF_STATEMENT = tuple(KIND_IF_STATEMENT, 'if_statement');
const Member MEMBER_INCLUSION_EXPRESSION = tuple(KIND_INCLUSION_DIRECTIVE, 'inclusion_expression');
const Member MEMBER_INCLUSION_FILENAME = tuple(KIND_INCLUSION_EXPRESSION, 'inclusion_filename');
const Member MEMBER_INCLUSION_REQUIRE = tuple(KIND_INCLUSION_EXPRESSION, 'inclusion_require');
const Member MEMBER_INCLUSION_SEMICOLON = tuple(KIND_INCLUSION_DIRECTIVE, 'inclusion_semicolon');
const Member MEMBER_INTERSECTION_LEFT_PAREN = tuple(KIND_INTERSECTION_TYPE_SPECIFIER, 'intersection_left_paren');
const Member MEMBER_INTERSECTION_RIGHT_PAREN = tuple(KIND_INTERSECTION_TYPE_SPECIFIER, 'intersection_right_paren');
const Member MEMBER_INTERSECTION_TYPES = tuple(KIND_INTERSECTION_TYPE_SPECIFIER, 'intersection_types');
const Member MEMBER_IS_LEFT_OPERAND = tuple(KIND_IS_EXPRESSION, 'is_left_operand');
const Member MEMBER_IS_OPERATOR = tuple(KIND_IS_EXPRESSION, 'is_operator');
const Member MEMBER_IS_RIGHT_OPERAND = tuple(KIND_IS_EXPRESSION, 'is_right_operand');
const Member MEMBER_ISSET_ARGUMENT_LIST = tuple(KIND_ISSET_EXPRESSION, 'isset_argument_list');
const Member MEMBER_ISSET_KEYWORD = tuple(KIND_ISSET_EXPRESSION, 'isset_keyword');
const Member MEMBER_ISSET_LEFT_PAREN = tuple(KIND_ISSET_EXPRESSION, 'isset_left_paren');
const Member MEMBER_ISSET_RIGHT_PAREN = tuple(KIND_ISSET_EXPRESSION, 'isset_right_paren');
const Member MEMBER_KEYSET_INTRINSIC_EXPLICIT_TYPE = tuple(KIND_KEYSET_INTRINSIC_EXPRESSION, 'keyset_intrinsic_explicit_type');
const Member MEMBER_KEYSET_INTRINSIC_KEYWORD = tuple(KIND_KEYSET_INTRINSIC_EXPRESSION, 'keyset_intrinsic_keyword');
const Member MEMBER_KEYSET_INTRINSIC_LEFT_BRACKET = tuple(KIND_KEYSET_INTRINSIC_EXPRESSION, 'keyset_intrinsic_left_bracket');
const Member MEMBER_KEYSET_INTRINSIC_MEMBERS = tuple(KIND_KEYSET_INTRINSIC_EXPRESSION, 'keyset_intrinsic_members');
const Member MEMBER_KEYSET_INTRINSIC_RIGHT_BRACKET = tuple(KIND_KEYSET_INTRINSIC_EXPRESSION, 'keyset_intrinsic_right_bracket');
const Member MEMBER_KEYSET_TYPE_KEYWORD = tuple(KIND_KEYSET_TYPE_SPECIFIER, 'keyset_type_keyword');
const Member MEMBER_KEYSET_TYPE_LEFT_ANGLE = tuple(KIND_KEYSET_TYPE_SPECIFIER, 'keyset_type_left_angle');
const Member MEMBER_KEYSET_TYPE_RIGHT_ANGLE = tuple(KIND_KEYSET_TYPE_SPECIFIER, 'keyset_type_right_angle');
const Member MEMBER_KEYSET_TYPE_TRAILING_COMMA = tuple(KIND_KEYSET_TYPE_SPECIFIER, 'keyset_type_trailing_comma');
const Member MEMBER_KEYSET_TYPE_TYPE = tuple(KIND_KEYSET_TYPE_SPECIFIER, 'keyset_type_type');
const Member MEMBER_LAMBDA_ARROW = tuple(KIND_LAMBDA_EXPRESSION, 'lambda_arrow');
const Member MEMBER_LAMBDA_ASYNC = tuple(KIND_LAMBDA_EXPRESSION, 'lambda_async');
const Member MEMBER_LAMBDA_ATTRIBUTE_SPEC = tuple(KIND_LAMBDA_EXPRESSION, 'lambda_attribute_spec');
const Member MEMBER_LAMBDA_BODY = tuple(KIND_LAMBDA_EXPRESSION, 'lambda_body');
const Member MEMBER_LAMBDA_COLON = tuple(KIND_LAMBDA_SIGNATURE, 'lambda_colon');
const Member MEMBER_LAMBDA_CONTEXTS = tuple(KIND_LAMBDA_SIGNATURE, 'lambda_contexts');
const Member MEMBER_LAMBDA_FUNCTION_KEYWORD = tuple(KIND_LAMBDA_SIGNATURE, 'lambda_function_keyword');
const Member MEMBER_LAMBDA_LEFT_PAREN = tuple(KIND_LAMBDA_SIGNATURE, 'lambda_left_paren');
const Member MEMBER_LAMBDA_PARAMETERS = tuple(KIND_LAMBDA_SIGNATURE, 'lambda_parameters');
const Member MEMBER_LAMBDA_READONLY_RETURN = tuple(KIND_LAMBDA_SIGNATURE, 'lambda_readonly_return');
const Member MEMBER_LAMBDA_RIGHT_PAREN = tuple(KIND_LAMBDA_SIGNATURE, 'lambda_right_paren');
const Member MEMBER_LAMBDA_SIGNATURE = tuple(KIND_LAMBDA_EXPRESSION, 'lambda_signature');
const Member MEMBER_LAMBDA_TYPE = tuple(KIND_LAMBDA_SIGNATURE, 'lambda_type');
const Member MEMBER_LAMBDA_TYPE_PARAMETERS = tuple(KIND_LAMBDA_SIGNATURE, 'lambda_type_parameters');
const Member MEMBER_LIKE_TILDE = tuple(KIND_LIKE_TYPE_SPECIFIER, 'like_tilde');
const Member MEMBER_LIKE_TYPE = tuple(KIND_LIKE_TYPE_SPECIFIER, 'like_type');
const Member MEMBER_LIST_ITEM = tuple(KIND_LIST_ITEM, 'list_item');
const Member MEMBER_LIST_KEYWORD = tuple(KIND_LIST_EXPRESSION, 'list_keyword');
const Member MEMBER_LIST_LEFT_PAREN = tuple(KIND_LIST_EXPRESSION, 'list_left_paren');
const Member MEMBER_LIST_MEMBERS = tuple(KIND_LIST_EXPRESSION, 'list_members');
const Member MEMBER_LIST_RIGHT_PAREN = tuple(KIND_LIST_EXPRESSION, 'list_right_paren');
const Member MEMBER_LIST_SEPARATOR = tuple(KIND_LIST_ITEM, 'list_separator');
const Member MEMBER_LITERAL_EXPRESSION = tuple(KIND_LITERAL, 'literal_expression');
const Member MEMBER_MARKUP_HASHBANG = tuple(KIND_MARKUP_SECTION, 'markup_hashbang');
const Member MEMBER_MARKUP_SUFFIX = tuple(KIND_MARKUP_SECTION, 'markup_suffix');
const Member MEMBER_MARKUP_SUFFIX_LESS_THAN_QUESTION = tuple(KIND_MARKUP_SUFFIX, 'markup_suffix_less_than_question');
const Member MEMBER_MARKUP_SUFFIX_NAME = tuple(KIND_MARKUP_SUFFIX, 'markup_suffix_name');
const Member MEMBER_MATCH_STATEMENT_ARM_ARROW = tuple(KIND_MATCH_STATEMENT_ARM, 'match_statement_arm_arrow');
const Member MEMBER_MATCH_STATEMENT_ARM_BODY = tuple(KIND_MATCH_STATEMENT_ARM, 'match_statement_arm_body');
const Member MEMBER_MATCH_STATEMENT_ARM_PATTERN = tuple(KIND_MATCH_STATEMENT_ARM, 'match_statement_arm_pattern');
const Member MEMBER_MATCH_STATEMENT_ARMS = tuple(KIND_MATCH_STATEMENT, 'match_statement_arms');
const Member MEMBER_MATCH_STATEMENT_EXPRESSION = tuple(KIND_MATCH_STATEMENT, 'match_statement_expression');
const Member MEMBER_MATCH_STATEMENT_KEYWORD = tuple(KIND_MATCH_STATEMENT, 'match_statement_keyword');
const Member MEMBER_MATCH_STATEMENT_LEFT_BRACE = tuple(KIND_MATCH_STATEMENT, 'match_statement_left_brace');
const Member MEMBER_MATCH_STATEMENT_LEFT_PAREN = tuple(KIND_MATCH_STATEMENT, 'match_statement_left_paren');
const Member MEMBER_MATCH_STATEMENT_RIGHT_BRACE = tuple(KIND_MATCH_STATEMENT, 'match_statement_right_brace');
const Member MEMBER_MATCH_STATEMENT_RIGHT_PAREN = tuple(KIND_MATCH_STATEMENT, 'match_statement_right_paren');
const Member MEMBER_MEMBER_NAME = tuple(KIND_MEMBER_SELECTION_EXPRESSION, 'member_name');
const Member MEMBER_MEMBER_OBJECT = tuple(KIND_MEMBER_SELECTION_EXPRESSION, 'member_object');
const Member MEMBER_MEMBER_OPERATOR = tuple(KIND_MEMBER_SELECTION_EXPRESSION, 'member_operator');
const Member MEMBER_METHODISH_ATTRIBUTE = tuple(KIND_METHODISH_DECLARATION, 'methodish_attribute');
const Member MEMBER_METHODISH_FUNCTION_BODY = tuple(KIND_METHODISH_DECLARATION, 'methodish_function_body');
const Member MEMBER_METHODISH_FUNCTION_DECL_HEADER = tuple(KIND_METHODISH_DECLARATION, 'methodish_function_decl_header');
const Member MEMBER_METHODISH_SEMICOLON = tuple(KIND_METHODISH_DECLARATION, 'methodish_semicolon');
const Member MEMBER_METHODISH_TRAIT_ATTRIBUTE = tuple(KIND_METHODISH_TRAIT_RESOLUTION, 'methodish_trait_attribute');
const Member MEMBER_METHODISH_TRAIT_EQUAL = tuple(KIND_METHODISH_TRAIT_RESOLUTION, 'methodish_trait_equal');
const Member MEMBER_METHODISH_TRAIT_FUNCTION_DECL_HEADER = tuple(KIND_METHODISH_TRAIT_RESOLUTION, 'methodish_trait_function_decl_header');
const Member MEMBER_METHODISH_TRAIT_NAME = tuple(KIND_METHODISH_TRAIT_RESOLUTION, 'methodish_trait_name');
const Member MEMBER_METHODISH_TRAIT_SEMICOLON = tuple(KIND_METHODISH_TRAIT_RESOLUTION, 'methodish_trait_semicolon');
const Member MEMBER_MODULE_DECLARATION_ATTRIBUTE_SPEC = tuple(KIND_MODULE_DECLARATION, 'module_declaration_attribute_spec');
const Member MEMBER_MODULE_DECLARATION_EXPORTS = tuple(KIND_MODULE_DECLARATION, 'module_declaration_exports');
const Member MEMBER_MODULE_DECLARATION_IMPORTS = tuple(KIND_MODULE_DECLARATION, 'module_declaration_imports');
const Member MEMBER_MODULE_DECLARATION_KEYWORD = tuple(KIND_MODULE_DECLARATION, 'module_declaration_keyword');
const Member MEMBER_MODULE_DECLARATION_LEFT_BRACE = tuple(KIND_MODULE_DECLARATION, 'module_declaration_left_brace');
const Member MEMBER_MODULE_DECLARATION_MODULE_KEYWORD = tuple(KIND_MODULE_DECLARATION, 'module_declaration_module_keyword');
const Member MEMBER_MODULE_DECLARATION_NAME = tuple(KIND_MODULE_DECLARATION, 'module_declaration_name');
const Member MEMBER_MODULE_DECLARATION_NEW_KEYWORD = tuple(KIND_MODULE_DECLARATION, 'module_declaration_new_keyword');
const Member MEMBER_MODULE_DECLARATION_RIGHT_BRACE = tuple(KIND_MODULE_DECLARATION, 'module_declaration_right_brace');
const Member MEMBER_MODULE_EXPORTS_EXPORTS = tuple(KIND_MODULE_EXPORTS, 'module_exports_exports');
const Member MEMBER_MODULE_EXPORTS_EXPORTS_KEYWORD = tuple(KIND_MODULE_EXPORTS, 'module_exports_exports_keyword');
const Member MEMBER_MODULE_EXPORTS_LEFT_BRACE = tuple(KIND_MODULE_EXPORTS, 'module_exports_left_brace');
const Member MEMBER_MODULE_EXPORTS_RIGHT_BRACE = tuple(KIND_MODULE_EXPORTS, 'module_exports_right_brace');
const Member MEMBER_MODULE_IMPORTS_IMPORTS = tuple(KIND_MODULE_IMPORTS, 'module_imports_imports');
const Member MEMBER_MODULE_IMPORTS_IMPORTS_KEYWORD = tuple(KIND_MODULE_IMPORTS, 'module_imports_imports_keyword');
const Member MEMBER_MODULE_IMPORTS_LEFT_BRACE = tuple(KIND_MODULE_IMPORTS, 'module_imports_left_brace');
const Member MEMBER_MODULE_IMPORTS_RIGHT_BRACE = tuple(KIND_MODULE_IMPORTS, 'module_imports_right_brace');
const Member MEMBER_MODULE_MEMBERSHIP_DECLARATION_MODULE_KEYWORD = tuple(KIND_MODULE_MEMBERSHIP_DECLARATION, 'module_membership_declaration_module_keyword');
const Member MEMBER_MODULE_MEMBERSHIP_DECLARATION_NAME = tuple(KIND_MODULE_MEMBERSHIP_DECLARATION, 'module_membership_declaration_name');
const Member MEMBER_MODULE_MEMBERSHIP_DECLARATION_SEMICOLON = tuple(KIND_MODULE_MEMBERSHIP_DECLARATION, 'module_membership_declaration_semicolon');
const Member MEMBER_MODULE_NAME_PARTS = tuple(KIND_MODULE_NAME, 'module_name_parts');
const Member MEMBER_NAMEOF_KEYWORD = tuple(KIND_NAMEOF_EXPRESSION, 'nameof_keyword');
const Member MEMBER_NAMEOF_TARGET = tuple(KIND_NAMEOF_EXPRESSION, 'nameof_target');
const Member MEMBER_NAMESPACE_BODY = tuple(KIND_NAMESPACE_DECLARATION, 'namespace_body');
const Member MEMBER_NAMESPACE_DECLARATIONS = tuple(KIND_NAMESPACE_BODY, 'namespace_declarations');
const Member MEMBER_NAMESPACE_GROUP_USE_CLAUSES = tuple(KIND_NAMESPACE_GROUP_USE_DECLARATION, 'namespace_group_use_clauses');
const Member MEMBER_NAMESPACE_GROUP_USE_KEYWORD = tuple(KIND_NAMESPACE_GROUP_USE_DECLARATION, 'namespace_group_use_keyword');
const Member MEMBER_NAMESPACE_GROUP_USE_KIND = tuple(KIND_NAMESPACE_GROUP_USE_DECLARATION, 'namespace_group_use_kind');
const Member MEMBER_NAMESPACE_GROUP_USE_LEFT_BRACE = tuple(KIND_NAMESPACE_GROUP_USE_DECLARATION, 'namespace_group_use_left_brace');
const Member MEMBER_NAMESPACE_GROUP_USE_PREFIX = tuple(KIND_NAMESPACE_GROUP_USE_DECLARATION, 'namespace_group_use_prefix');
const Member MEMBER_NAMESPACE_GROUP_USE_RIGHT_BRACE = tuple(KIND_NAMESPACE_GROUP_USE_DECLARATION, 'namespace_group_use_right_brace');
const Member MEMBER_NAMESPACE_GROUP_USE_SEMICOLON = tuple(KIND_NAMESPACE_GROUP_USE_DECLARATION, 'namespace_group_use_semicolon');
const Member MEMBER_NAMESPACE_HEADER = tuple(KIND_NAMESPACE_DECLARATION, 'namespace_header');
const Member MEMBER_NAMESPACE_KEYWORD = tuple(KIND_NAMESPACE_DECLARATION_HEADER, 'namespace_keyword');
const Member MEMBER_NAMESPACE_LEFT_BRACE = tuple(KIND_NAMESPACE_BODY, 'namespace_left_brace');
const Member MEMBER_NAMESPACE_NAME = tuple(KIND_NAMESPACE_DECLARATION_HEADER, 'namespace_name');
const Member MEMBER_NAMESPACE_RIGHT_BRACE = tuple(KIND_NAMESPACE_BODY, 'namespace_right_brace');
const Member MEMBER_NAMESPACE_SEMICOLON = tuple(KIND_NAMESPACE_EMPTY_BODY, 'namespace_semicolon');
const Member MEMBER_NAMESPACE_USE_ALIAS = tuple(KIND_NAMESPACE_USE_CLAUSE, 'namespace_use_alias');
const Member MEMBER_NAMESPACE_USE_AS = tuple(KIND_NAMESPACE_USE_CLAUSE, 'namespace_use_as');
const Member MEMBER_NAMESPACE_USE_CLAUSE_KIND = tuple(KIND_NAMESPACE_USE_CLAUSE, 'namespace_use_clause_kind');
const Member MEMBER_NAMESPACE_USE_CLAUSES = tuple(KIND_NAMESPACE_USE_DECLARATION, 'namespace_use_clauses');
const Member MEMBER_NAMESPACE_USE_KEYWORD = tuple(KIND_NAMESPACE_USE_DECLARATION, 'namespace_use_keyword');
const Member MEMBER_NAMESPACE_USE_KIND = tuple(KIND_NAMESPACE_USE_DECLARATION, 'namespace_use_kind');
const Member MEMBER_NAMESPACE_USE_NAME = tuple(KIND_NAMESPACE_USE_CLAUSE, 'namespace_use_name');
const Member MEMBER_NAMESPACE_USE_SEMICOLON = tuple(KIND_NAMESPACE_USE_DECLARATION, 'namespace_use_semicolon');
const Member MEMBER_NULLABLE_AS_LEFT_OPERAND = tuple(KIND_NULLABLE_AS_EXPRESSION, 'nullable_as_left_operand');
const Member MEMBER_NULLABLE_AS_OPERATOR = tuple(KIND_NULLABLE_AS_EXPRESSION, 'nullable_as_operator');
const Member MEMBER_NULLABLE_AS_RIGHT_OPERAND = tuple(KIND_NULLABLE_AS_EXPRESSION, 'nullable_as_right_operand');
const Member MEMBER_NULLABLE_QUESTION = tuple(KIND_NULLABLE_TYPE_SPECIFIER, 'nullable_question');
const Member MEMBER_NULLABLE_TYPE = tuple(KIND_NULLABLE_TYPE_SPECIFIER, 'nullable_type');
const Member MEMBER_OBJECT_CREATION_NEW_KEYWORD = tuple(KIND_OBJECT_CREATION_EXPRESSION, 'object_creation_new_keyword');
const Member MEMBER_OBJECT_CREATION_OBJECT = tuple(KIND_OBJECT_CREATION_EXPRESSION, 'object_creation_object');
const Member MEMBER_OLD_ATTRIBUTE_SPECIFICATION_ATTRIBUTES = tuple(KIND_OLD_ATTRIBUTE_SPECIFICATION, 'old_attribute_specification_attributes');
const Member MEMBER_OLD_ATTRIBUTE_SPECIFICATION_LEFT_DOUBLE_ANGLE = tuple(KIND_OLD_ATTRIBUTE_SPECIFICATION, 'old_attribute_specification_left_double_angle');
const Member MEMBER_OLD_ATTRIBUTE_SPECIFICATION_RIGHT_DOUBLE_ANGLE = tuple(KIND_OLD_ATTRIBUTE_SPECIFICATION, 'old_attribute_specification_right_double_angle');
const Member MEMBER_PACKAGE_DECLARATION_ATTRIBUTE_SPEC = tuple(KIND_PACKAGE_DECLARATION, 'package_declaration_attribute_spec');
const Member MEMBER_PACKAGE_DECLARATION_INCLUDES = tuple(KIND_PACKAGE_DECLARATION, 'package_declaration_includes');
const Member MEMBER_PACKAGE_DECLARATION_LEFT_BRACE = tuple(KIND_PACKAGE_DECLARATION, 'package_declaration_left_brace');
const Member MEMBER_PACKAGE_DECLARATION_NAME = tuple(KIND_PACKAGE_DECLARATION, 'package_declaration_name');
const Member MEMBER_PACKAGE_DECLARATION_PACKAGE_KEYWORD = tuple(KIND_PACKAGE_DECLARATION, 'package_declaration_package_keyword');
const Member MEMBER_PACKAGE_DECLARATION_RIGHT_BRACE = tuple(KIND_PACKAGE_DECLARATION, 'package_declaration_right_brace');
const Member MEMBER_PACKAGE_DECLARATION_USES = tuple(KIND_PACKAGE_DECLARATION, 'package_declaration_uses');
const Member MEMBER_PACKAGE_EXPRESSION_KEYWORD = tuple(KIND_PACKAGE_EXPRESSION, 'package_expression_keyword');
const Member MEMBER_PACKAGE_EXPRESSION_NAME = tuple(KIND_PACKAGE_EXPRESSION, 'package_expression_name');
const Member MEMBER_PACKAGE_INCLUDES_INCLUDE_KEYWORD = tuple(KIND_PACKAGE_INCLUDES, 'package_includes_include_keyword');
const Member MEMBER_PACKAGE_INCLUDES_INCLUDES = tuple(KIND_PACKAGE_INCLUDES, 'package_includes_includes');
const Member MEMBER_PACKAGE_INCLUDES_LEFT_BRACE = tuple(KIND_PACKAGE_INCLUDES, 'package_includes_left_brace');
const Member MEMBER_PACKAGE_INCLUDES_RIGHT_BRACE = tuple(KIND_PACKAGE_INCLUDES, 'package_includes_right_brace');
const Member MEMBER_PACKAGE_USES_LEFT_BRACE = tuple(KIND_PACKAGE_USES, 'package_uses_left_brace');
const Member MEMBER_PACKAGE_USES_RIGHT_BRACE = tuple(KIND_PACKAGE_USES, 'package_uses_right_brace');
const Member MEMBER_PACKAGE_USES_USE_KEYWORD = tuple(KIND_PACKAGE_USES, 'package_uses_use_keyword');
const Member MEMBER_PACKAGE_USES_USES = tuple(KIND_PACKAGE_USES, 'package_uses_uses');
const Member MEMBER_PARAMETER_ATTRIBUTE = tuple(KIND_PARAMETER_DECLARATION, 'parameter_attribute');
const Member MEMBER_PARAMETER_CALL_CONVENTION = tuple(KIND_PARAMETER_DECLARATION, 'parameter_call_convention');
const Member MEMBER_PARAMETER_DEFAULT_VALUE = tuple(KIND_PARAMETER_DECLARATION, 'parameter_default_value');
const Member MEMBER_PARAMETER_ELLIPSIS = tuple(KIND_PARAMETER_DECLARATION, 'parameter_ellipsis');
const Member MEMBER_PARAMETER_NAME = tuple(KIND_PARAMETER_DECLARATION, 'parameter_name');
const Member MEMBER_PARAMETER_OPTIONAL = tuple(KIND_PARAMETER_DECLARATION, 'parameter_optional');
const Member MEMBER_PARAMETER_PARAMETER_END = tuple(KIND_PARAMETER_DECLARATION, 'parameter_parameter_end');
const Member MEMBER_PARAMETER_PRE_ELLIPSIS = tuple(KIND_PARAMETER_DECLARATION, 'parameter_pre_ellipsis');
const Member MEMBER_PARAMETER_READONLY = tuple(KIND_PARAMETER_DECLARATION, 'parameter_readonly');
const Member MEMBER_PARAMETER_TYPE = tuple(KIND_PARAMETER_DECLARATION, 'parameter_type');
const Member MEMBER_PARAMETER_VISIBILITY = tuple(KIND_PARAMETER_DECLARATION, 'parameter_visibility');
const Member MEMBER_PARENTHESIZED_EXPRESSION_EXPRESSION = tuple(KIND_PARENTHESIZED_EXPRESSION, 'parenthesized_expression_expression');
const Member MEMBER_PARENTHESIZED_EXPRESSION_LEFT_PAREN = tuple(KIND_PARENTHESIZED_EXPRESSION, 'parenthesized_expression_left_paren');
const Member MEMBER_PARENTHESIZED_EXPRESSION_RIGHT_PAREN = tuple(KIND_PARENTHESIZED_EXPRESSION, 'parenthesized_expression_right_paren');
const Member MEMBER_PIPE_VARIABLE_EXPRESSION = tuple(KIND_PIPE_VARIABLE, 'pipe_variable_expression');
const Member MEMBER_POSTFIX_UNARY_OPERAND = tuple(KIND_POSTFIX_UNARY_EXPRESSION, 'postfix_unary_operand');
const Member MEMBER_POSTFIX_UNARY_OPERATOR = tuple(KIND_POSTFIX_UNARY_EXPRESSION, 'postfix_unary_operator');
const Member MEMBER_PREFIX_UNARY_OPERAND = tuple(KIND_PREFIX_UNARY_EXPRESSION, 'prefix_unary_operand');
const Member MEMBER_PREFIX_UNARY_OPERATOR = tuple(KIND_PREFIX_UNARY_EXPRESSION, 'prefix_unary_operator');
const Member MEMBER_PREFIXED_CODE_BODY = tuple(KIND_PREFIXED_CODE_EXPRESSION, 'prefixed_code_body');
const Member MEMBER_PREFIXED_CODE_EXPRESSION = tuple(KIND_PREFIXED_CODE_EXPRESSION, 'prefixed_code_expression');
const Member MEMBER_PREFIXED_CODE_LEFT_BACKTICK = tuple(KIND_PREFIXED_CODE_EXPRESSION, 'prefixed_code_left_backtick');
const Member MEMBER_PREFIXED_CODE_PREFIX = tuple(KIND_PREFIXED_CODE_EXPRESSION, 'prefixed_code_prefix');
const Member MEMBER_PREFIXED_CODE_RIGHT_BACKTICK = tuple(KIND_PREFIXED_CODE_EXPRESSION, 'prefixed_code_right_backtick');
const Member MEMBER_PREFIXED_STRING_NAME = tuple(KIND_PREFIXED_STRING, 'prefixed_string_name');
const Member MEMBER_PREFIXED_STRING_STR = tuple(KIND_PREFIXED_STRING, 'prefixed_string_str');
const Member MEMBER_PROPERTY_ATTRIBUTE_SPEC = tuple(KIND_PROPERTY_DECLARATION, 'property_attribute_spec');
const Member MEMBER_PROPERTY_DECLARATORS = tuple(KIND_PROPERTY_DECLARATION, 'property_declarators');
const Member MEMBER_PROPERTY_INITIALIZER = tuple(KIND_PROPERTY_DECLARATOR, 'property_initializer');
const Member MEMBER_PROPERTY_MODIFIERS = tuple(KIND_PROPERTY_DECLARATION, 'property_modifiers');
const Member MEMBER_PROPERTY_NAME = tuple(KIND_PROPERTY_DECLARATOR, 'property_name');
const Member MEMBER_PROPERTY_SEMICOLON = tuple(KIND_PROPERTY_DECLARATION, 'property_semicolon');
const Member MEMBER_PROPERTY_TYPE = tuple(KIND_PROPERTY_DECLARATION, 'property_type');
const Member MEMBER_QUALIFIED_NAME_PARTS = tuple(KIND_QUALIFIED_NAME, 'qualified_name_parts');
const Member MEMBER_RECORD_ATTRIBUTE_SPEC = tuple(KIND_RECORD_DECLARATION, 'record_attribute_spec');
const Member MEMBER_RECORD_CREATION_LEFT_BRACKET = tuple(KIND_RECORD_CREATION_EXPRESSION, 'record_creation_left_bracket');
const Member MEMBER_RECORD_CREATION_MEMBERS = tuple(KIND_RECORD_CREATION_EXPRESSION, 'record_creation_members');
const Member MEMBER_RECORD_CREATION_RIGHT_BRACKET = tuple(KIND_RECORD_CREATION_EXPRESSION, 'record_creation_right_bracket');
const Member MEMBER_RECORD_CREATION_TYPE = tuple(KIND_RECORD_CREATION_EXPRESSION, 'record_creation_type');
const Member MEMBER_RECORD_EXTENDS_KEYWORD = tuple(KIND_RECORD_DECLARATION, 'record_extends_keyword');
const Member MEMBER_RECORD_EXTENDS_OPT = tuple(KIND_RECORD_DECLARATION, 'record_extends_opt');
const Member MEMBER_RECORD_FIELD_INIT = tuple(KIND_RECORD_FIELD, 'record_field_init');
const Member MEMBER_RECORD_FIELD_NAME = tuple(KIND_RECORD_FIELD, 'record_field_name');
const Member MEMBER_RECORD_FIELD_SEMI = tuple(KIND_RECORD_FIELD, 'record_field_semi');
const Member MEMBER_RECORD_FIELD_TYPE = tuple(KIND_RECORD_FIELD, 'record_field_type');
const Member MEMBER_RECORD_FIELDS = tuple(KIND_RECORD_DECLARATION, 'record_fields');
const Member MEMBER_RECORD_KEYWORD = tuple(KIND_RECORD_DECLARATION, 'record_keyword');
const Member MEMBER_RECORD_LEFT_BRACE = tuple(KIND_RECORD_DECLARATION, 'record_left_brace');
const Member MEMBER_RECORD_MODIFIER = tuple(KIND_RECORD_DECLARATION, 'record_modifier');
const Member MEMBER_RECORD_NAME = tuple(KIND_RECORD_DECLARATION, 'record_name');
const Member MEMBER_RECORD_RIGHT_BRACE = tuple(KIND_RECORD_DECLARATION, 'record_right_brace');
const Member MEMBER_REFINEMENT_PATTERN_COLON = tuple(KIND_REFINEMENT_PATTERN, 'refinement_pattern_colon');
const Member MEMBER_REFINEMENT_PATTERN_SPECIFIER = tuple(KIND_REFINEMENT_PATTERN, 'refinement_pattern_specifier');
const Member MEMBER_REFINEMENT_PATTERN_VARIABLE = tuple(KIND_REFINEMENT_PATTERN, 'refinement_pattern_variable');
const Member MEMBER_REIFIED_TYPE_ARGUMENT_REIFIED = tuple(KIND_REIFIED_TYPE_ARGUMENT, 'reified_type_argument_reified');
const Member MEMBER_REIFIED_TYPE_ARGUMENT_TYPE = tuple(KIND_REIFIED_TYPE_ARGUMENT, 'reified_type_argument_type');
const Member MEMBER_REQUIRE_CONSTRAINT_KEYWORD = tuple(KIND_REQUIRE_CLAUSE_CONSTRAINT, 'require_constraint_keyword');
const Member MEMBER_REQUIRE_CONSTRAINT_NAME = tuple(KIND_REQUIRE_CLAUSE_CONSTRAINT, 'require_constraint_name');
const Member MEMBER_REQUIRE_CONSTRAINT_OPERATOR = tuple(KIND_REQUIRE_CLAUSE_CONSTRAINT, 'require_constraint_operator');
const Member MEMBER_REQUIRE_CONSTRAINT_SEMICOLON = tuple(KIND_REQUIRE_CLAUSE_CONSTRAINT, 'require_constraint_semicolon');
const Member MEMBER_REQUIRE_CONSTRAINT_THIS = tuple(KIND_REQUIRE_CLAUSE_CONSTRAINT, 'require_constraint_this');
const Member MEMBER_REQUIRE_KEYWORD = tuple(KIND_REQUIRE_CLAUSE, 'require_keyword');
const Member MEMBER_REQUIRE_KIND = tuple(KIND_REQUIRE_CLAUSE, 'require_kind');
const Member MEMBER_REQUIRE_NAME = tuple(KIND_REQUIRE_CLAUSE, 'require_name');
const Member MEMBER_REQUIRE_SEMICOLON = tuple(KIND_REQUIRE_CLAUSE, 'require_semicolon');
const Member MEMBER_RETURN_EXPRESSION = tuple(KIND_RETURN_STATEMENT, 'return_expression');
const Member MEMBER_RETURN_KEYWORD = tuple(KIND_RETURN_STATEMENT, 'return_keyword');
const Member MEMBER_RETURN_SEMICOLON = tuple(KIND_RETURN_STATEMENT, 'return_semicolon');
const Member MEMBER_SAFE_MEMBER_NAME = tuple(KIND_SAFE_MEMBER_SELECTION_EXPRESSION, 'safe_member_name');
const Member MEMBER_SAFE_MEMBER_OBJECT = tuple(KIND_SAFE_MEMBER_SELECTION_EXPRESSION, 'safe_member_object');
const Member MEMBER_SAFE_MEMBER_OPERATOR = tuple(KIND_SAFE_MEMBER_SELECTION_EXPRESSION, 'safe_member_operator');
const Member MEMBER_SCOPE_RESOLUTION_NAME = tuple(KIND_SCOPE_RESOLUTION_EXPRESSION, 'scope_resolution_name');
const Member MEMBER_SCOPE_RESOLUTION_OPERATOR = tuple(KIND_SCOPE_RESOLUTION_EXPRESSION, 'scope_resolution_operator');
const Member MEMBER_SCOPE_RESOLUTION_QUALIFIER = tuple(KIND_SCOPE_RESOLUTION_EXPRESSION, 'scope_resolution_qualifier');
const Member MEMBER_SCRIPT_DECLARATIONS = tuple(KIND_SCRIPT, 'script_declarations');
const Member MEMBER_SHAPE_EXPRESSION_FIELDS = tuple(KIND_SHAPE_EXPRESSION, 'shape_expression_fields');
const Member MEMBER_SHAPE_EXPRESSION_KEYWORD = tuple(KIND_SHAPE_EXPRESSION, 'shape_expression_keyword');
const Member MEMBER_SHAPE_EXPRESSION_LEFT_PAREN = tuple(KIND_SHAPE_EXPRESSION, 'shape_expression_left_paren');
const Member MEMBER_SHAPE_EXPRESSION_RIGHT_PAREN = tuple(KIND_SHAPE_EXPRESSION, 'shape_expression_right_paren');
const Member MEMBER_SHAPE_TYPE_ELLIPSIS = tuple(KIND_SHAPE_TYPE_SPECIFIER, 'shape_type_ellipsis');
const Member MEMBER_SHAPE_TYPE_FIELDS = tuple(KIND_SHAPE_TYPE_SPECIFIER, 'shape_type_fields');
const Member MEMBER_SHAPE_TYPE_KEYWORD = tuple(KIND_SHAPE_TYPE_SPECIFIER, 'shape_type_keyword');
const Member MEMBER_SHAPE_TYPE_LEFT_PAREN = tuple(KIND_SHAPE_TYPE_SPECIFIER, 'shape_type_left_paren');
const Member MEMBER_SHAPE_TYPE_RIGHT_PAREN = tuple(KIND_SHAPE_TYPE_SPECIFIER, 'shape_type_right_paren');
const Member MEMBER_SIMPLE_INITIALIZER_EQUAL = tuple(KIND_SIMPLE_INITIALIZER, 'simple_initializer_equal');
const Member MEMBER_SIMPLE_INITIALIZER_VALUE = tuple(KIND_SIMPLE_INITIALIZER, 'simple_initializer_value');
const Member MEMBER_SIMPLE_TYPE_SPECIFIER = tuple(KIND_SIMPLE_TYPE_SPECIFIER, 'simple_type_specifier');
const Member MEMBER_SOFT_AT = tuple(KIND_SOFT_TYPE_SPECIFIER, 'soft_at');
const Member MEMBER_SOFT_TYPE = tuple(KIND_SOFT_TYPE_SPECIFIER, 'soft_type');
const Member MEMBER_SUBSCRIPT_INDEX = tuple(KIND_SUBSCRIPT_EXPRESSION, 'subscript_index');
const Member MEMBER_SUBSCRIPT_LEFT_BRACKET = tuple(KIND_SUBSCRIPT_EXPRESSION, 'subscript_left_bracket');
const Member MEMBER_SUBSCRIPT_RECEIVER = tuple(KIND_SUBSCRIPT_EXPRESSION, 'subscript_receiver');
const Member MEMBER_SUBSCRIPT_RIGHT_BRACKET = tuple(KIND_SUBSCRIPT_EXPRESSION, 'subscript_right_bracket');
const Member MEMBER_SWITCH_EXPRESSION = tuple(KIND_SWITCH_STATEMENT, 'switch_expression');
const Member MEMBER_SWITCH_KEYWORD = tuple(KIND_SWITCH_STATEMENT, 'switch_keyword');
const Member MEMBER_SWITCH_LEFT_BRACE = tuple(KIND_SWITCH_STATEMENT, 'switch_left_brace');
const Member MEMBER_SWITCH_LEFT_PAREN = tuple(KIND_SWITCH_STATEMENT, 'switch_left_paren');
const Member MEMBER_SWITCH_RIGHT_BRACE = tuple(KIND_SWITCH_STATEMENT, 'switch_right_brace');
const Member MEMBER_SWITCH_RIGHT_PAREN = tuple(KIND_SWITCH_STATEMENT, 'switch_right_paren');
const Member MEMBER_SWITCH_SECTION_FALLTHROUGH = tuple(KIND_SWITCH_SECTION, 'switch_section_fallthrough');
const Member MEMBER_SWITCH_SECTION_LABELS = tuple(KIND_SWITCH_SECTION, 'switch_section_labels');
const Member MEMBER_SWITCH_SECTION_STATEMENTS = tuple(KIND_SWITCH_SECTION, 'switch_section_statements');
const Member MEMBER_SWITCH_SECTIONS = tuple(KIND_SWITCH_STATEMENT, 'switch_sections');
const Member MEMBER_THROW_EXPRESSION = tuple(KIND_THROW_STATEMENT, 'throw_expression');
const Member MEMBER_THROW_KEYWORD = tuple(KIND_THROW_STATEMENT, 'throw_keyword');
const Member MEMBER_THROW_SEMICOLON = tuple(KIND_THROW_STATEMENT, 'throw_semicolon');
const Member MEMBER_TRAIT_USE_ALIAS_ITEM_ALIASED_NAME = tuple(KIND_TRAIT_USE_ALIAS_ITEM, 'trait_use_alias_item_aliased_name');
const Member MEMBER_TRAIT_USE_ALIAS_ITEM_ALIASING_NAME = tuple(KIND_TRAIT_USE_ALIAS_ITEM, 'trait_use_alias_item_aliasing_name');
const Member MEMBER_TRAIT_USE_ALIAS_ITEM_KEYWORD = tuple(KIND_TRAIT_USE_ALIAS_ITEM, 'trait_use_alias_item_keyword');
const Member MEMBER_TRAIT_USE_ALIAS_ITEM_MODIFIERS = tuple(KIND_TRAIT_USE_ALIAS_ITEM, 'trait_use_alias_item_modifiers');
const Member MEMBER_TRAIT_USE_CONFLICT_RESOLUTION_CLAUSES = tuple(KIND_TRAIT_USE_CONFLICT_RESOLUTION, 'trait_use_conflict_resolution_clauses');
const Member MEMBER_TRAIT_USE_CONFLICT_RESOLUTION_KEYWORD = tuple(KIND_TRAIT_USE_CONFLICT_RESOLUTION, 'trait_use_conflict_resolution_keyword');
const Member MEMBER_TRAIT_USE_CONFLICT_RESOLUTION_LEFT_BRACE = tuple(KIND_TRAIT_USE_CONFLICT_RESOLUTION, 'trait_use_conflict_resolution_left_brace');
const Member MEMBER_TRAIT_USE_CONFLICT_RESOLUTION_NAMES = tuple(KIND_TRAIT_USE_CONFLICT_RESOLUTION, 'trait_use_conflict_resolution_names');
const Member MEMBER_TRAIT_USE_CONFLICT_RESOLUTION_RIGHT_BRACE = tuple(KIND_TRAIT_USE_CONFLICT_RESOLUTION, 'trait_use_conflict_resolution_right_brace');
const Member MEMBER_TRAIT_USE_KEYWORD = tuple(KIND_TRAIT_USE, 'trait_use_keyword');
const Member MEMBER_TRAIT_USE_NAMES = tuple(KIND_TRAIT_USE, 'trait_use_names');
const Member MEMBER_TRAIT_USE_PRECEDENCE_ITEM_KEYWORD = tuple(KIND_TRAIT_USE_PRECEDENCE_ITEM, 'trait_use_precedence_item_keyword');
const Member MEMBER_TRAIT_USE_PRECEDENCE_ITEM_NAME = tuple(KIND_TRAIT_USE_PRECEDENCE_ITEM, 'trait_use_precedence_item_name');
const Member MEMBER_TRAIT_USE_PRECEDENCE_ITEM_REMOVED_NAMES = tuple(KIND_TRAIT_USE_PRECEDENCE_ITEM, 'trait_use_precedence_item_removed_names');
const Member MEMBER_TRAIT_USE_SEMICOLON = tuple(KIND_TRAIT_USE, 'trait_use_semicolon');
const Member MEMBER_TRY_CATCH_CLAUSES = tuple(KIND_TRY_STATEMENT, 'try_catch_clauses');
const Member MEMBER_TRY_COMPOUND_STATEMENT = tuple(KIND_TRY_STATEMENT, 'try_compound_statement');
const Member MEMBER_TRY_FINALLY_CLAUSE = tuple(KIND_TRY_STATEMENT, 'try_finally_clause');
const Member MEMBER_TRY_KEYWORD = tuple(KIND_TRY_STATEMENT, 'try_keyword');
const Member MEMBER_TUPLE_EXPRESSION_ITEMS = tuple(KIND_TUPLE_EXPRESSION, 'tuple_expression_items');
const Member MEMBER_TUPLE_EXPRESSION_KEYWORD = tuple(KIND_TUPLE_EXPRESSION, 'tuple_expression_keyword');
const Member MEMBER_TUPLE_EXPRESSION_LEFT_PAREN = tuple(KIND_TUPLE_EXPRESSION, 'tuple_expression_left_paren');
const Member MEMBER_TUPLE_EXPRESSION_RIGHT_PAREN = tuple(KIND_TUPLE_EXPRESSION, 'tuple_expression_right_paren');
const Member MEMBER_TUPLE_LEFT_PAREN = tuple(KIND_TUPLE_TYPE_SPECIFIER, 'tuple_left_paren');
const Member MEMBER_TUPLE_OR_UNION_OR_INTERSECTION_ELEMENT_ELLIPSIS = tuple(KIND_TUPLE_OR_UNION_OR_INTERSECTION_ELEMENT_TYPE_SPECIFIER, 'tuple_or_union_or_intersection_element_ellipsis');
const Member MEMBER_TUPLE_OR_UNION_OR_INTERSECTION_ELEMENT_OPTIONAL = tuple(KIND_TUPLE_OR_UNION_OR_INTERSECTION_ELEMENT_TYPE_SPECIFIER, 'tuple_or_union_or_intersection_element_optional');
const Member MEMBER_TUPLE_OR_UNION_OR_INTERSECTION_ELEMENT_PRE_ELLIPSIS = tuple(KIND_TUPLE_OR_UNION_OR_INTERSECTION_ELEMENT_TYPE_SPECIFIER, 'tuple_or_union_or_intersection_element_pre_ellipsis');
const Member MEMBER_TUPLE_OR_UNION_OR_INTERSECTION_ELEMENT_TYPE = tuple(KIND_TUPLE_OR_UNION_OR_INTERSECTION_ELEMENT_TYPE_SPECIFIER, 'tuple_or_union_or_intersection_element_type');
const Member MEMBER_TUPLE_RIGHT_PAREN = tuple(KIND_TUPLE_TYPE_SPECIFIER, 'tuple_right_paren');
const Member MEMBER_TUPLE_TYPE_KEYWORD = tuple(KIND_TUPLE_TYPE_EXPLICIT_SPECIFIER, 'tuple_type_keyword');
const Member MEMBER_TUPLE_TYPE_LEFT_ANGLE = tuple(KIND_TUPLE_TYPE_EXPLICIT_SPECIFIER, 'tuple_type_left_angle');
const Member MEMBER_TUPLE_TYPE_RIGHT_ANGLE = tuple(KIND_TUPLE_TYPE_EXPLICIT_SPECIFIER, 'tuple_type_right_angle');
const Member MEMBER_TUPLE_TYPE_TYPES = tuple(KIND_TUPLE_TYPE_EXPLICIT_SPECIFIER, 'tuple_type_types');
const Member MEMBER_TUPLE_TYPES = tuple(KIND_TUPLE_TYPE_SPECIFIER, 'tuple_types');
const Member MEMBER_TYPE_ARGUMENTS_LEFT_ANGLE = tuple(KIND_TYPE_ARGUMENTS, 'type_arguments_left_angle');
const Member MEMBER_TYPE_ARGUMENTS_RIGHT_ANGLE = tuple(KIND_TYPE_ARGUMENTS, 'type_arguments_right_angle');
const Member MEMBER_TYPE_ARGUMENTS_TYPES = tuple(KIND_TYPE_ARGUMENTS, 'type_arguments_types');
const Member MEMBER_TYPE_ATTRIBUTE_SPEC = tuple(KIND_TYPE_PARAMETER, 'type_attribute_spec');
const Member MEMBER_TYPE_CONST_ATTRIBUTE_SPEC = tuple(KIND_TYPE_CONST_DECLARATION, 'type_const_attribute_spec');
const Member MEMBER_TYPE_CONST_EQUAL = tuple(KIND_TYPE_CONST_DECLARATION, 'type_const_equal');
const Member MEMBER_TYPE_CONST_KEYWORD = tuple(KIND_TYPE_CONST_DECLARATION, 'type_const_keyword');
const Member MEMBER_TYPE_CONST_MODIFIERS = tuple(KIND_TYPE_CONST_DECLARATION, 'type_const_modifiers');
const Member MEMBER_TYPE_CONST_NAME = tuple(KIND_TYPE_CONST_DECLARATION, 'type_const_name');
const Member MEMBER_TYPE_CONST_SEMICOLON = tuple(KIND_TYPE_CONST_DECLARATION, 'type_const_semicolon');
const Member MEMBER_TYPE_CONST_TYPE_CONSTRAINT = tuple(KIND_TYPE_CONST_DECLARATION, 'type_const_type_constraint');
const Member MEMBER_TYPE_CONST_TYPE_CONSTRAINTS = tuple(KIND_TYPE_CONST_DECLARATION, 'type_const_type_constraints');
const Member MEMBER_TYPE_CONST_TYPE_KEYWORD = tuple(KIND_TYPE_CONST_DECLARATION, 'type_const_type_keyword');
const Member MEMBER_TYPE_CONST_TYPE_PARAMETERS = tuple(KIND_TYPE_CONST_DECLARATION, 'type_const_type_parameters');
const Member MEMBER_TYPE_CONST_TYPE_SPECIFIER = tuple(KIND_TYPE_CONST_DECLARATION, 'type_const_type_specifier');
const Member MEMBER_TYPE_CONSTANT_LEFT_TYPE = tuple(KIND_TYPE_CONSTANT, 'type_constant_left_type');
const Member MEMBER_TYPE_CONSTANT_RIGHT_TYPE = tuple(KIND_TYPE_CONSTANT, 'type_constant_right_type');
const Member MEMBER_TYPE_CONSTANT_SEPARATOR = tuple(KIND_TYPE_CONSTANT, 'type_constant_separator');
const Member MEMBER_TYPE_CONSTRAINTS = tuple(KIND_TYPE_PARAMETER, 'type_constraints');
const Member MEMBER_TYPE_IN_REFINEMENT_CONSTRAINTS = tuple(KIND_TYPE_IN_REFINEMENT, 'type_in_refinement_constraints');
const Member MEMBER_TYPE_IN_REFINEMENT_EQUAL = tuple(KIND_TYPE_IN_REFINEMENT, 'type_in_refinement_equal');
const Member MEMBER_TYPE_IN_REFINEMENT_KEYWORD = tuple(KIND_TYPE_IN_REFINEMENT, 'type_in_refinement_keyword');
const Member MEMBER_TYPE_IN_REFINEMENT_NAME = tuple(KIND_TYPE_IN_REFINEMENT, 'type_in_refinement_name');
const Member MEMBER_TYPE_IN_REFINEMENT_TYPE = tuple(KIND_TYPE_IN_REFINEMENT, 'type_in_refinement_type');
const Member MEMBER_TYPE_IN_REFINEMENT_TYPE_PARAMETERS = tuple(KIND_TYPE_IN_REFINEMENT, 'type_in_refinement_type_parameters');
const Member MEMBER_TYPE_NAME = tuple(KIND_TYPE_PARAMETER, 'type_name');
const Member MEMBER_TYPE_PARAM_PARAMS = tuple(KIND_TYPE_PARAMETER, 'type_param_params');
const Member MEMBER_TYPE_PARAMETERS_LEFT_ANGLE = tuple(KIND_TYPE_PARAMETERS, 'type_parameters_left_angle');
const Member MEMBER_TYPE_PARAMETERS_PARAMETERS = tuple(KIND_TYPE_PARAMETERS, 'type_parameters_parameters');
const Member MEMBER_TYPE_PARAMETERS_RIGHT_ANGLE = tuple(KIND_TYPE_PARAMETERS, 'type_parameters_right_angle');
const Member MEMBER_TYPE_REFINEMENT_KEYWORD = tuple(KIND_TYPE_REFINEMENT, 'type_refinement_keyword');
const Member MEMBER_TYPE_REFINEMENT_LEFT_BRACE = tuple(KIND_TYPE_REFINEMENT, 'type_refinement_left_brace');
const Member MEMBER_TYPE_REFINEMENT_MEMBERS = tuple(KIND_TYPE_REFINEMENT, 'type_refinement_members');
const Member MEMBER_TYPE_REFINEMENT_RIGHT_BRACE = tuple(KIND_TYPE_REFINEMENT, 'type_refinement_right_brace');
const Member MEMBER_TYPE_REFINEMENT_TYPE = tuple(KIND_TYPE_REFINEMENT, 'type_refinement_type');
const Member MEMBER_TYPE_REIFIED = tuple(KIND_TYPE_PARAMETER, 'type_reified');
const Member MEMBER_TYPE_VARIANCE = tuple(KIND_TYPE_PARAMETER, 'type_variance');
const Member MEMBER_UNION_LEFT_PAREN = tuple(KIND_UNION_TYPE_SPECIFIER, 'union_left_paren');
const Member MEMBER_UNION_RIGHT_PAREN = tuple(KIND_UNION_TYPE_SPECIFIER, 'union_right_paren');
const Member MEMBER_UNION_TYPES = tuple(KIND_UNION_TYPE_SPECIFIER, 'union_types');
const Member MEMBER_UNSET_KEYWORD = tuple(KIND_UNSET_STATEMENT, 'unset_keyword');
const Member MEMBER_UNSET_LEFT_PAREN = tuple(KIND_UNSET_STATEMENT, 'unset_left_paren');
const Member MEMBER_UNSET_RIGHT_PAREN = tuple(KIND_UNSET_STATEMENT, 'unset_right_paren');
const Member MEMBER_UNSET_SEMICOLON = tuple(KIND_UNSET_STATEMENT, 'unset_semicolon');
const Member MEMBER_UNSET_VARIABLES = tuple(KIND_UNSET_STATEMENT, 'unset_variables');
const Member MEMBER_UPCAST_LEFT_OPERAND = tuple(KIND_UPCAST_EXPRESSION, 'upcast_left_operand');
const Member MEMBER_UPCAST_OPERATOR = tuple(KIND_UPCAST_EXPRESSION, 'upcast_operator');
const Member MEMBER_UPCAST_RIGHT_OPERAND = tuple(KIND_UPCAST_EXPRESSION, 'upcast_right_operand');
const Member MEMBER_USING_BLOCK_AWAIT_KEYWORD = tuple(KIND_USING_STATEMENT_BLOCK_SCOPED, 'using_block_await_keyword');
const Member MEMBER_USING_BLOCK_BODY = tuple(KIND_USING_STATEMENT_BLOCK_SCOPED, 'using_block_body');
const Member MEMBER_USING_BLOCK_EXPRESSIONS = tuple(KIND_USING_STATEMENT_BLOCK_SCOPED, 'using_block_expressions');
const Member MEMBER_USING_BLOCK_LEFT_PAREN = tuple(KIND_USING_STATEMENT_BLOCK_SCOPED, 'using_block_left_paren');
const Member MEMBER_USING_BLOCK_RIGHT_PAREN = tuple(KIND_USING_STATEMENT_BLOCK_SCOPED, 'using_block_right_paren');
const Member MEMBER_USING_BLOCK_USING_KEYWORD = tuple(KIND_USING_STATEMENT_BLOCK_SCOPED, 'using_block_using_keyword');
const Member MEMBER_USING_FUNCTION_AWAIT_KEYWORD = tuple(KIND_USING_STATEMENT_FUNCTION_SCOPED, 'using_function_await_keyword');
const Member MEMBER_USING_FUNCTION_EXPRESSION = tuple(KIND_USING_STATEMENT_FUNCTION_SCOPED, 'using_function_expression');
const Member MEMBER_USING_FUNCTION_SEMICOLON = tuple(KIND_USING_STATEMENT_FUNCTION_SCOPED, 'using_function_semicolon');
const Member MEMBER_USING_FUNCTION_USING_KEYWORD = tuple(KIND_USING_STATEMENT_FUNCTION_SCOPED, 'using_function_using_keyword');
const Member MEMBER_VARIABLE_EXPRESSION = tuple(KIND_VARIABLE_SYNTAX, 'variable_expression');
const Member MEMBER_VARIABLE_PATTERN_VARIABLE = tuple(KIND_VARIABLE_PATTERN, 'variable_pattern_variable');
const Member MEMBER_VARIADIC_PARAMETER_CALL_CONVENTION = tuple(KIND_VARIADIC_PARAMETER, 'variadic_parameter_call_convention');
const Member MEMBER_VARIADIC_PARAMETER_ELLIPSIS = tuple(KIND_VARIADIC_PARAMETER, 'variadic_parameter_ellipsis');
const Member MEMBER_VARIADIC_PARAMETER_TYPE = tuple(KIND_VARIADIC_PARAMETER, 'variadic_parameter_type');
const Member MEMBER_VARRAY_INTRINSIC_EXPLICIT_TYPE = tuple(KIND_VARRAY_INTRINSIC_EXPRESSION, 'varray_intrinsic_explicit_type');
const Member MEMBER_VARRAY_INTRINSIC_KEYWORD = tuple(KIND_VARRAY_INTRINSIC_EXPRESSION, 'varray_intrinsic_keyword');
const Member MEMBER_VARRAY_INTRINSIC_LEFT_BRACKET = tuple(KIND_VARRAY_INTRINSIC_EXPRESSION, 'varray_intrinsic_left_bracket');
const Member MEMBER_VARRAY_INTRINSIC_MEMBERS = tuple(KIND_VARRAY_INTRINSIC_EXPRESSION, 'varray_intrinsic_members');
const Member MEMBER_VARRAY_INTRINSIC_RIGHT_BRACKET = tuple(KIND_VARRAY_INTRINSIC_EXPRESSION, 'varray_intrinsic_right_bracket');
const Member MEMBER_VARRAY_KEYWORD = tuple(KIND_VARRAY_TYPE_SPECIFIER, 'varray_keyword');
const Member MEMBER_VARRAY_LEFT_ANGLE = tuple(KIND_VARRAY_TYPE_SPECIFIER, 'varray_left_angle');
const Member MEMBER_VARRAY_RIGHT_ANGLE = tuple(KIND_VARRAY_TYPE_SPECIFIER, 'varray_right_angle');
const Member MEMBER_VARRAY_TRAILING_COMMA = tuple(KIND_VARRAY_TYPE_SPECIFIER, 'varray_trailing_comma');
const Member MEMBER_VARRAY_TYPE = tuple(KIND_VARRAY_TYPE_SPECIFIER, 'varray_type');
const Member MEMBER_VECTOR_INTRINSIC_EXPLICIT_TYPE = tuple(KIND_VECTOR_INTRINSIC_EXPRESSION, 'vector_intrinsic_explicit_type');
const Member MEMBER_VECTOR_INTRINSIC_KEYWORD = tuple(KIND_VECTOR_INTRINSIC_EXPRESSION, 'vector_intrinsic_keyword');
const Member MEMBER_VECTOR_INTRINSIC_LEFT_BRACKET = tuple(KIND_VECTOR_INTRINSIC_EXPRESSION, 'vector_intrinsic_left_bracket');
const Member MEMBER_VECTOR_INTRINSIC_MEMBERS = tuple(KIND_VECTOR_INTRINSIC_EXPRESSION, 'vector_intrinsic_members');
const Member MEMBER_VECTOR_INTRINSIC_RIGHT_BRACKET = tuple(KIND_VECTOR_INTRINSIC_EXPRESSION, 'vector_intrinsic_right_bracket');
const Member MEMBER_VECTOR_TYPE_KEYWORD = tuple(KIND_VECTOR_TYPE_SPECIFIER, 'vector_type_keyword');
const Member MEMBER_VECTOR_TYPE_LEFT_ANGLE = tuple(KIND_VECTOR_TYPE_SPECIFIER, 'vector_type_left_angle');
const Member MEMBER_VECTOR_TYPE_RIGHT_ANGLE = tuple(KIND_VECTOR_TYPE_SPECIFIER, 'vector_type_right_angle');
const Member MEMBER_VECTOR_TYPE_TRAILING_COMMA = tuple(KIND_VECTOR_TYPE_SPECIFIER, 'vector_type_trailing_comma');
const Member MEMBER_VECTOR_TYPE_TYPE = tuple(KIND_VECTOR_TYPE_SPECIFIER, 'vector_type_type');
const Member MEMBER_WHERE_CLAUSE_CONSTRAINTS = tuple(KIND_WHERE_CLAUSE, 'where_clause_constraints');
const Member MEMBER_WHERE_CLAUSE_KEYWORD = tuple(KIND_WHERE_CLAUSE, 'where_clause_keyword');
const Member MEMBER_WHERE_CONSTRAINT_LEFT_TYPE = tuple(KIND_WHERE_CONSTRAINT, 'where_constraint_left_type');
const Member MEMBER_WHERE_CONSTRAINT_OPERATOR = tuple(KIND_WHERE_CONSTRAINT, 'where_constraint_operator');
const Member MEMBER_WHERE_CONSTRAINT_RIGHT_TYPE = tuple(KIND_WHERE_CONSTRAINT, 'where_constraint_right_type');
const Member MEMBER_WHILE_BODY = tuple(KIND_WHILE_STATEMENT, 'while_body');
const Member MEMBER_WHILE_CONDITION = tuple(KIND_WHILE_STATEMENT, 'while_condition');
const Member MEMBER_WHILE_KEYWORD = tuple(KIND_WHILE_STATEMENT, 'while_keyword');
const Member MEMBER_WHILE_LEFT_PAREN = tuple(KIND_WHILE_STATEMENT, 'while_left_paren');
const Member MEMBER_WHILE_RIGHT_PAREN = tuple(KIND_WHILE_STATEMENT, 'while_right_paren');
const Member MEMBER_XHP_ATTRIBUTE_ATTRIBUTES = tuple(KIND_XHP_CLASS_ATTRIBUTE_DECLARATION, 'xhp_attribute_attributes');
const Member MEMBER_XHP_ATTRIBUTE_DECL_INITIALIZER = tuple(KIND_XHP_CLASS_ATTRIBUTE, 'xhp_attribute_decl_initializer');
const Member MEMBER_XHP_ATTRIBUTE_DECL_NAME = tuple(KIND_XHP_CLASS_ATTRIBUTE, 'xhp_attribute_decl_name');
const Member MEMBER_XHP_ATTRIBUTE_DECL_REQUIRED = tuple(KIND_XHP_CLASS_ATTRIBUTE, 'xhp_attribute_decl_required');
const Member MEMBER_XHP_ATTRIBUTE_DECL_TYPE = tuple(KIND_XHP_CLASS_ATTRIBUTE, 'xhp_attribute_decl_type');
const Member MEMBER_XHP_ATTRIBUTE_KEYWORD = tuple(KIND_XHP_CLASS_ATTRIBUTE_DECLARATION, 'xhp_attribute_keyword');
const Member MEMBER_XHP_ATTRIBUTE_SEMICOLON = tuple(KIND_XHP_CLASS_ATTRIBUTE_DECLARATION, 'xhp_attribute_semicolon');
const Member MEMBER_XHP_BODY = tuple(KIND_XHP_EXPRESSION, 'xhp_body');
const Member MEMBER_XHP_CATEGORY_CATEGORIES = tuple(KIND_XHP_CATEGORY_DECLARATION, 'xhp_category_categories');
const Member MEMBER_XHP_CATEGORY_KEYWORD = tuple(KIND_XHP_CATEGORY_DECLARATION, 'xhp_category_keyword');
const Member MEMBER_XHP_CATEGORY_SEMICOLON = tuple(KIND_XHP_CATEGORY_DECLARATION, 'xhp_category_semicolon');
const Member MEMBER_XHP_CHILDREN_EXPRESSION = tuple(KIND_XHP_CHILDREN_DECLARATION, 'xhp_children_expression');
const Member MEMBER_XHP_CHILDREN_KEYWORD = tuple(KIND_XHP_CHILDREN_DECLARATION, 'xhp_children_keyword');
const Member MEMBER_XHP_CHILDREN_LIST_LEFT_PAREN = tuple(KIND_XHP_CHILDREN_PARENTHESIZED_LIST, 'xhp_children_list_left_paren');
const Member MEMBER_XHP_CHILDREN_LIST_RIGHT_PAREN = tuple(KIND_XHP_CHILDREN_PARENTHESIZED_LIST, 'xhp_children_list_right_paren');
const Member MEMBER_XHP_CHILDREN_LIST_XHP_CHILDREN = tuple(KIND_XHP_CHILDREN_PARENTHESIZED_LIST, 'xhp_children_list_xhp_children');
const Member MEMBER_XHP_CHILDREN_SEMICOLON = tuple(KIND_XHP_CHILDREN_DECLARATION, 'xhp_children_semicolon');
const Member MEMBER_XHP_CLOSE = tuple(KIND_XHP_EXPRESSION, 'xhp_close');
const Member MEMBER_XHP_CLOSE_LEFT_ANGLE = tuple(KIND_XHP_CLOSE, 'xhp_close_left_angle');
const Member MEMBER_XHP_CLOSE_NAME = tuple(KIND_XHP_CLOSE, 'xhp_close_name');
const Member MEMBER_XHP_CLOSE_RIGHT_ANGLE = tuple(KIND_XHP_CLOSE, 'xhp_close_right_angle');
const Member MEMBER_XHP_ENUM_KEYWORD = tuple(KIND_XHP_ENUM_TYPE, 'xhp_enum_keyword');
const Member MEMBER_XHP_ENUM_LEFT_BRACE = tuple(KIND_XHP_ENUM_TYPE, 'xhp_enum_left_brace');
const Member MEMBER_XHP_ENUM_LIKE = tuple(KIND_XHP_ENUM_TYPE, 'xhp_enum_like');
const Member MEMBER_XHP_ENUM_RIGHT_BRACE = tuple(KIND_XHP_ENUM_TYPE, 'xhp_enum_right_brace');
const Member MEMBER_XHP_ENUM_VALUES = tuple(KIND_XHP_ENUM_TYPE, 'xhp_enum_values');
const Member MEMBER_XHP_LATEINIT_AT = tuple(KIND_XHP_LATEINIT, 'xhp_lateinit_at');
const Member MEMBER_XHP_LATEINIT_KEYWORD = tuple(KIND_XHP_LATEINIT, 'xhp_lateinit_keyword');
const Member MEMBER_XHP_OPEN = tuple(KIND_XHP_EXPRESSION, 'xhp_open');
const Member MEMBER_XHP_OPEN_ATTRIBUTES = tuple(KIND_XHP_OPEN, 'xhp_open_attributes');
const Member MEMBER_XHP_OPEN_LEFT_ANGLE = tuple(KIND_XHP_OPEN, 'xhp_open_left_angle');
const Member MEMBER_XHP_OPEN_NAME = tuple(KIND_XHP_OPEN, 'xhp_open_name');
const Member MEMBER_XHP_OPEN_RIGHT_ANGLE = tuple(KIND_XHP_OPEN, 'xhp_open_right_angle');
const Member MEMBER_XHP_REQUIRED_AT = tuple(KIND_XHP_REQUIRED, 'xhp_required_at');
const Member MEMBER_XHP_REQUIRED_KEYWORD = tuple(KIND_XHP_REQUIRED, 'xhp_required_keyword');
const Member MEMBER_XHP_SIMPLE_ATTRIBUTE_EQUAL = tuple(KIND_XHP_SIMPLE_ATTRIBUTE, 'xhp_simple_attribute_equal');
const Member MEMBER_XHP_SIMPLE_ATTRIBUTE_EXPRESSION = tuple(KIND_XHP_SIMPLE_ATTRIBUTE, 'xhp_simple_attribute_expression');
const Member MEMBER_XHP_SIMPLE_ATTRIBUTE_NAME = tuple(KIND_XHP_SIMPLE_ATTRIBUTE, 'xhp_simple_attribute_name');
const Member MEMBER_XHP_SIMPLE_CLASS_ATTRIBUTE_TYPE = tuple(KIND_XHP_SIMPLE_CLASS_ATTRIBUTE, 'xhp_simple_class_attribute_type');
const Member MEMBER_XHP_SPREAD_ATTRIBUTE_EXPRESSION = tuple(KIND_XHP_SPREAD_ATTRIBUTE, 'xhp_spread_attribute_expression');
const Member MEMBER_XHP_SPREAD_ATTRIBUTE_LEFT_BRACE = tuple(KIND_XHP_SPREAD_ATTRIBUTE, 'xhp_spread_attribute_left_brace');
const Member MEMBER_XHP_SPREAD_ATTRIBUTE_RIGHT_BRACE = tuple(KIND_XHP_SPREAD_ATTRIBUTE, 'xhp_spread_attribute_right_brace');
const Member MEMBER_XHP_SPREAD_ATTRIBUTE_SPREAD_OPERATOR = tuple(KIND_XHP_SPREAD_ATTRIBUTE, 'xhp_spread_attribute_spread_operator');
const Member MEMBER_YIELD_BREAK_BREAK = tuple(KIND_YIELD_BREAK_STATEMENT, 'yield_break_break');
const Member MEMBER_YIELD_BREAK_KEYWORD = tuple(KIND_YIELD_BREAK_STATEMENT, 'yield_break_keyword');
const Member MEMBER_YIELD_BREAK_SEMICOLON = tuple(KIND_YIELD_BREAK_STATEMENT, 'yield_break_semicolon');
const Member MEMBER_YIELD_KEYWORD = tuple(KIND_YIELD_EXPRESSION, 'yield_keyword');
const Member MEMBER_YIELD_OPERAND = tuple(KIND_YIELD_EXPRESSION, 'yield_operand');
// #endregion
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/NodeElaboratedGroup.hack /////
namespace HTL\Pha {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


enum NodeElaboratedGroup: int {
  SYNTAX = 0;
  TOKEN = 1;
  TRIVIUM = 2;
  LIST = 3;
  MISSING = 4;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/NodeGroup.hack /////
namespace HTL\Pha {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


enum NodeGroup: int {
  SYNTAX = 0;
  TOKEN = 1;
  TRIVIUM = 2;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/PhaException.hack /////
namespace HTL\Pha {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use type Exception;

/**
 * The exception thrown for all the known reachable error states.
 * If an other exception is thrown from this library,
 * this is a bug and you may report it as such.
 */
interface PhaException {
  require extends Exception;
  public function getMessage()[]: string;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/RetainTrivia.hack /////
namespace HTL\Pha {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


enum RetainTrivia: int {
  NEITHER = 0;
  LEADING = 1;
  TRAILING = 2;
  BOTH = 3;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/Index.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Vec};
use namespace HTL\Pha;

final class Index<Tnode as Node, Tkind as Kind> {
  /**
   * @param $nodes are sorted by kind, then sub sorted by source order.
   * @param $ranges values are (start, length).
   *   The order is interned string numeric order, but this is not relied upon.
   */
  public function __construct(
    private ParseContext $ctx,
    private Pha\NodeGroup $group,
    private vec<Tnode> $nodes,
    private dict<InternedString<Tkind>, (int, int)> $ranges,
  )[] {}

  /**
   * The returned nodes are in source order.
   */
  public function getByKind(Tkind $kind)[]: vec<Tnode> {
    switch ($this->group) {
      case Pha\NodeGroup::SYNTAX:
        $interned = Pha\syntax_kind_from_kind($kind)
          |> $this->ctx->getSyntaxKinds()->internOrMax($$);
        break;
      case Pha\NodeGroup::TOKEN:
        $interned = Pha\token_kind_from_kind($kind)
          |> $this->ctx->getTokenKinds()->internOrMax($$);
        break;
      case Pha\NodeGroup::TRIVIUM:
        $interned = Pha\trivium_kind_from_kind($kind)
          |> $this->ctx->getTriviumKinds()->internOrMax($$);
    }

    return idx($this->ranges, $interned)
      |> $$ is null ? vec[] : Vec\slice($this->nodes, $$[0], $$[1]);
  }

  /**
   * Careful, `Tnode_` ought to be `Syntax`, `Token`, or `Trivium`, not /just/
   * `Node`, but there is no way to enforce this.
   * If `Tnode_` is `Syntax`, please exclude the LIST and MISSING nodes.
   * `$group` has to belong together with `Tnode_` and `Tkind_`.
   */
  public static function create<Tnode_ as Node, <<__Explicit>> Tkind_ as Kind>(
    ParseContext $ctx,
    Pha\NodeGroup $group,
    vec<Tnode_> $nodes,
  )[]: Index<Tnode_, Tkind_> {
    if (C\is_empty($nodes)) {
      return new Index<Tnode_, Tkind_>($ctx, $group, vec[], dict[]);
    }

    $sorted = Vec\sort_by($nodes, node_get_index_mask<>);
    $ranges = dict[];
    $last_interned = node_get_interned_kind<Tkind_>(C\firstx($sorted));
    $start_range = 0;

    // This $i is just the loop counter, I need it to outlive the loop.
    // A foreach ($sorted as $i => $node) would be more expressive, but
    // HHClientLinter warns about the shadowing, so a manual `++$i` it is...
    $i = 0;
    foreach ($sorted as $node) {
      $interned = node_get_interned_kind<Tkind_>($node);
      if ($interned !== $last_interned) {
        $ranges[$last_interned] = tuple($start_range, $i - $start_range);
        $start_range = $i;
        $last_interned = $interned;
      }
      ++$i;
    }

    $ranges[$last_interned] = tuple($start_range, $i - $start_range + 1);

    return new Index<Tnode_, Tkind_>($ctx, $group, $sorted, $ranges);
  }
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/InternedStringStorage.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Dict};

final class InternedStringStorage<T as Kind> {
  private vec<T> $items;
  private dict<T, int> $flipped;
  private int $size;

  /**
   * @param $items is keyed by interned string (0..n-1).
   */
  public function __construct(
    private keyset<T> $asKeyset,
    private (function(string)[]: T) $castFunc,
  )[] {
    $this->items = vec($this->asKeyset);
    $this->flipped = Dict\flip($this->items);
    $this->size = C\count($this->items);
  }

  public function asKeyset()[]: keyset<T> {
    return $this->asKeyset;
  }

  public function asVec()[]: vec<string> {
    return $this->items;
  }

  public function fromInterned(InternedString<T> $interned)[]: T {
    return
      $this->items[interned_string_to_int($interned)] |> ($this->castFunc)($$);
  }

  public function intern(T $string)[]: InternedString<T> {
    return interned_string_from_int<T>($this->flipped[$string]);
  }

  public function internOrMax(T $string)[]: InternedString<T> {
    return interned_string_from_int<T>(
      idx($this->flipped, $string, MAX_INTERNED_STRING),
    );
  }

  public function isOfSameSize(keyset<string> $new_names)[]: bool {
    return $this->size === C\count($new_names);
  }
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/ParseContext.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use namespace HH\Lib\Str;
use namespace HTL\Pha;
use function gettype;

final class ParseContext {
  public function __construct(
    private Structs $structs,
    private InternedStringStorage<SyntaxKind> $syntaxKinds,
    private InternedStringStorage<TokenKind> $tokenKinds,
    private InternedStringStorage<TriviumKind> $triviumKinds,
  )[] {}

  public function getStructs()[]: Structs {
    return $this->structs;
  }

  public function getSyntaxKinds()[]: InternedStringStorage<SyntaxKind> {
    return $this->syntaxKinds;
  }

  public function getTokenKinds()[]: InternedStringStorage<TokenKind> {
    return $this->tokenKinds;
  }

  public function getTriviumKinds()[]: InternedStringStorage<TriviumKind> {
    return $this->triviumKinds;
  }

  public function upgradeIfNeeded(
    dict<SyntaxKind, vec<Member>> $new_member_names,
    keyset<TokenKind> $new_token_kinds,
    keyset<TriviumKind> $new_trivium_kinds,
  )[]: ParseContext {
    $structs = $this->structs;
    $syntax_kinds = $this->syntaxKinds;
    $token_kinds = $this->tokenKinds;
    $trivium_kinds = $this->triviumKinds;

    $upgrade_needed = false;

    if (!$structs->isOfSameSize($new_member_names)) {
      $upgrade_needed = true;
      $structs = new Structs($new_member_names);
      $syntax_kinds = $structs->asInternedStrings();
    }

    if (!$token_kinds->isOfSameSize($new_token_kinds)) {
      $upgrade_needed = true;
      $token_kinds = new InternedStringStorage<TokenKind>(
        $new_token_kinds,
        Pha\token_kind_from_string<>,
      );
    }

    if (!$trivium_kinds->isOfSameSize($new_trivium_kinds)) {
      $upgrade_needed = true;
      $trivium_kinds = new InternedStringStorage<TriviumKind>(
        $new_trivium_kinds,
        Pha\trivium_kind_from_string<>,
      );
    }

    return $upgrade_needed
      ? new ParseContext($structs, $syntax_kinds, $token_kinds, $trivium_kinds)
      : $this;
  }

  // #region Materialization
  const string VERSION = 'VERSION';
  const int VERSION_NUMBER = 2;
  const string STRUCTS = 'STRUCTS';
  const string SYNTAX_KINDS = 'SYNTAX_KINDS';
  const string TOKEN_KINDS = 'TOKEN_KINDS';
  const string TRIVIUM_KINDS = 'TRIVIUM_KINDS';

  // Memoize because this value can be shared across many scripts.
  <<__Memoize>>
  public function getMaterializationHash()[]: string {
    return $this->dematerialize()
      |> static::toHashable($$)
      |> \sha1($$, false);
  }

  // Memoize because this value can be shared across many scripts.
  <<__Memoize>>
  public function dematerialize()[]: dict<arraykey, mixed> {
    return dict[
      static::VERSION => static::VERSION_NUMBER,
      static::STRUCTS => $this->structs->dematerialize(),
      static::SYNTAX_KINDS => $this->syntaxKinds->asVec(),
      static::TOKEN_KINDS => $this->tokenKinds->asVec(),
      static::TRIVIUM_KINDS => $this->triviumKinds->asVec(),
    ];
  }

  public static function materialize(dict<arraykey, mixed> $raw)[]: this {
    $version = idx($raw, static::VERSION, -1);
    enforce(
      $version === static::VERSION_NUMBER,
      'Could not materialize this Context, '.
      'it was dematerialized with a later version of this library.',
    );

    try {
      return new static(
        $raw[static::STRUCTS] |> Structs::materialize($$ as dict<_, _>),
        $raw[static::SYNTAX_KINDS]
          |> as_vec_of_syntax_kind($$)
          |> keyset($$)
          |> new InternedStringStorage($$, Pha\syntax_kind_from_string<>),
        $raw[static::TOKEN_KINDS]
          |> as_vec_of_token_kind($$)
          |> keyset($$)
          |> new InternedStringStorage($$, Pha\token_kind_from_string<>),
        $raw[static::TRIVIUM_KINDS]
          |> as_vec_of_trivium_kind($$)
          |> keyset($$)
          |> new InternedStringStorage($$, Pha\trivium_kind_from_string<>),
      );
    } catch (\Exception $e) {
      throw
        new PhaException('Could not materialize Context.', $e->getCode(), $e);
    }
  }

  /**
   * The encoding does not need to make sense, as long as it is not ambiguous.
   * json_encode_pure is wasn't available in 4.102, so something inline was done.
   * Changing this breaks backwards compatibility with VERSION=2 serialization.
   * This can be removed when VERSION=3 comes around.
   *
   * The encoding will look a little like json, but instead of quoting strings,
   * they will be encoded as `s<length><bytes>`. This is not ambiguous with
   * anything, since no json construct starts with an `s`.
   */
  private static function toHashable(mixed $mixed)[]: string {
    if ($mixed is string) {
      return 's' . Str\length($mixed) . $mixed;
    } else if ($mixed is int) {
      return (string)$mixed;
    } else if ($mixed is dict<_, _>) {
      $out = '{';
      foreach ($mixed as $k => $v) {
        $out .= static::toHashable($k) . ':' . static::toHashable($v) . ',';
      }
      $out .= '}';

      return $out;
    } else if ($mixed is vec<_>) {
      $out = '[';
      foreach ($mixed as $v) {
        $out .= static::toHashable($v) . ',';
      }
      $out .= ']';

      return $out;
    } else if ($mixed is AnyArray<_, _>) {
      $out = '{?';
      foreach ($mixed as $k => $v) {
        $out .= static::toHashable($k) . ':' . static::toHashable($v) . ',';
      }
      $out .= '?}';

      return $out;
    }

    invariant_violation('Unhandled type: %s', gettype($mixed));
  }
  // #endregion
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/PatchNode.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Str};
use namespace HTL\Pha;

final class PatchNode {
  public function __construct(
    private Pha\Node $node,
    private string $text,
    private Pha\RetainTrivia $retainTrivia,
  )[] {
    // Missing nodes don't have tokens, which means they can't have trivia either.
    // The algorithm for slicing leading and trailing trivia depends on tokens.
    // By special casing it here, we remove a special case from the algorithm.
    if (Pha\is_missing($node)) {
      $this->retainTrivia = Pha\RetainTrivia::NEITHER;
    }

    if (
      $this->retainTrivia !== Pha\RetainTrivia::NEITHER && Pha\is_trivium($node)
    ) {
      throw new PhaException(Str\format(
        'You may not replace a trivium with %s::%s set. '.
        'This instruction does not make sense.',
        (string)Pha\RetainTrivia::class,
        Pha\RetainTrivia::getNames()[$retainTrivia],
      ));
    }
  }

  public function toReplacement(Script $script)[]: Replacement {
    if ($this->retainTrivia === Pha\RetainTrivia::NEITHER) {
      $source_range = Pha\node_get_source_range($script, $this->node);
      return new Replacement(
        Pha\source_range_to_line_and_column_numbers($script, $source_range),
        $source_range,
        $this->text,
      );
    }

    list($keep_leading, $keep_trailing) =
      retain_trivia_keep_leading_and_trailing($this->retainTrivia);

    $descendants = Pha\node_get_descendants($script, $this->node);

    $start_node = $keep_leading
      ? C\findx(
          $descendants,
          $d ==> Pha\is_trivium($d) &&
            Pha\node_get_kind($script, $d) === Pha\KIND_TOKEN_TEXT,
        )
      : $this->node;

    $end_node = $keep_trailing
      ? find_lastx(
          $descendants,
          $d ==> Pha\is_trivium($d) &&
            Pha\node_get_kind($script, $d) === Pha\KIND_TOKEN_TEXT,
        )
      : $this->node;

    $start = Pha\node_get_source_range($script, $start_node)
      |> source_range_reveal($$)[0];

    $end = Pha\node_get_source_range($script, $end_node)
      |> source_range_reveal($$)[1];

    $source_range = source_range_hide(tuple($start, $end));

    return new Replacement(
      Pha\source_range_to_line_and_column_numbers($script, $source_range),
      $source_range,
      $this->text,
    );
  }
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/PatchSet.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Str, Vec};
use namespace HTL\Pha;

final class PatchSet {
  private vec<Replacement> $replacements;

  public function __construct(
    private string $beforeText,
    vec<Replacement> $replacements,
  )[] {
    $this->replacements =
      Vec\sort_by($replacements, $r ==> $r->getStartOffset());
    $shifted = Vec\drop($this->replacements, 1);
    $with_next = Vec\zip($this->replacements, $shifted);

    foreach ($with_next as list($cur, $next)) {
      if (Pha\source_range_overlaps($cur->getRange(), $next->getRange())) {
        throw new PhaException(
          Str\format(
            "The following two patches conflict:\n - %s\n%s\n - %s\n%s",
            Pha\source_range_format($cur->getRange()),
            $cur->getText(),
            Pha\source_range_format($next->getRange()),
            $next->getText(),
          ),
        );
      }
    }
  }

  public function apply()[]: string {
    if (C\is_empty($this->replacements)) {
      return $this->beforeText;
    }

    $out = '';
    $read_start = 0;

    foreach ($this->replacements as $replacement) {
      invariant(
        $read_start is nonnull,
        'Only the last patch may have an open end.',
      );
      $out .= Str\slice(
        $this->beforeText,
        $read_start,
        source_byte_offset_to_int($replacement->getStartOffset()) - $read_start,
      );

      $out .= $replacement->getText();
      $read_start = $replacement->getEndOffset()
        |> $$ is null ? null : source_byte_offset_to_int($$);
    }

    if ($read_start is null) {
      return $out;
    }

    return $out.Str\slice($this->beforeText, $read_start);
  }

  public function cayBeCombinedWith(PatchSet $other)[]: bool {
    return $this->beforeText === $other->beforeText;
  }

  public function getBeforeText()[]: string {
    return $this->beforeText;
  }

  public function getReplacements()[]: vec<Replacement> {
    return $this->replacements;
  }
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/PhaException.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use namespace HTL\Pha;
use type Exception;

final class PhaException extends Exception implements Pha\PhaException {
  <<__Override>>
  public function getMessage()[]: string {
    return $this->message;
  }
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/Replacement.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use namespace HTL\Pha;

final class Replacement {
  public function __construct(
    private Pha\LineAndColumnNumbers $lineAndColumnNumbers,
    private SourceRange $range,
    private string $text,
  )[] {}

  public function getPosition()[]: Pha\LineAndColumnNumbers {
    return $this->lineAndColumnNumbers;
  }

  public function getEndOffset()[]: ?SourceByteOffset {
    return $this->range |> source_range_reveal($$)[1];
  }

  public function getRange()[]: SourceRange {
    return $this->range;
  }

  public function getStartOffset()[]: SourceByteOffset {
    return $this->range |> source_range_reveal($$)[0];
  }

  public function getText()[]: string {
    return $this->text;
  }
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/Structs.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Dict, Keyset, Vec};
use namespace HTL\Pha;

final class Structs {
  private int $size;
  public function __construct(
    private dict<SyntaxKind, vec<Member>> $rawMembers,
  )[] {
    $this->size = C\count($rawMembers);
  }

  public function asInternedStrings()[]: InternedStringStorage<SyntaxKind> {
    return new InternedStringStorage<SyntaxKind>(
      Keyset\keys($this->rawMembers),
      Pha\syntax_kind_from_string<>,
    );
  }

  public function getRaw()[]: dict<SyntaxKind, vec<Member>> {
    return $this->rawMembers;
  }

  public function isOfSameSize(dict<string, vec<Member>> $new_members)[]: bool {
    return $this->size === C\count($new_members);
  }

  //#region Materialization
  const string VERSION = 'VERSION';
  const int VERSION_NUMBER = 2;
  const string MEMBERS = 'MEMBERS';

  public function dematerialize()[]: dict<arraykey, mixed> {
    return dict[
      static::VERSION => static::VERSION_NUMBER,
      static::MEMBERS => Vec\flatten($this->rawMembers),
    ];
  }

  public static function materialize(dict<arraykey, mixed> $raw)[]: this {
    enforce(
      idx($raw, static::VERSION) === static::VERSION_NUMBER,
      'Could not materialize these Structs, '.
      'they were dematerialized with a later version of this library.',
    );

    return $raw[static::MEMBERS]
      |> as_vec_of_member($$)
      |> Dict\group_by($$, Pha\member_get_syntax_kind<>)
      |> new static($$);
  }
  //#endregion
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/TranslationUnit.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{Str, Vec};

final class TranslationUnit {
  const SOME_LARGE_JUMP = 64;

  private vec<SourceByteOffset> $lineBreaks;
  /**
   * @param $sourceOrder is keyed by NodeId (0..n-1).
   * @param $siblings is keyed by SiblingId (0..n-1).
   * @param $listSizes only contains the sizes of lists 255 and above.
   */
  public function __construct(
    private vec<Node> $sourceOrder,
    private vec<Node> $siblings,
    private dict<NodeId, int> $listSizes,
    private string $sourceText,
    private ParseContext $ctx,
  )[] {
    $line_breaks = vec[source_byte_offset_from_int(0)];

    $byte = 0;
    foreach (Str\split($sourceText, "\n") as $line) {
      $byte += Str\length($line) + 1;
      $line_breaks[] = source_byte_offset_from_int($byte);
    }

    $this->lineBreaks = $line_breaks;
  }

  public function cutSourceOrder(
    NodeId $from,
    NodeId $to_inclusive,
  )[]: vec<Node> {
    $from = node_id_to_int($from);
    $to_inclusive = node_id_to_int($to_inclusive);
    return Vec\slice($this->sourceOrder, $from, $to_inclusive - $from + 1);
  }

  public function cutSourceRange(SourceRange $range)[]: string {
    list($from, $to_exclusive) = source_range_reveal($range);
    $from = source_byte_offset_to_int($from);
    $to_exclusive =
      $to_exclusive is null ? null : source_byte_offset_to_int($to_exclusive);
    return $to_exclusive is null
      ? Str\slice($this->sourceText, $from)
      : Str\slice($this->sourceText, $from, $to_exclusive - $from);
  }

  public function getLineBreaks()[]: vec<SourceByteOffset> {
    return $this->lineBreaks;
  }

  public function getNodeById(NodeId $node_id)[]: NillableNode {
    return idx($this->sourceOrder, node_id_to_int($node_id), NIL);
  }

  public function getNodeByIdx(NodeId $node_id)[]: Node {
    return $this->sourceOrder[node_id_to_int($node_id)];
  }

  public function getNodeBySiblingId(SiblingId $sibling_id)[]: NillableNode {
    return idx($this->siblings, sibling_id_to_int($sibling_id), NIL);
  }

  public function getNodeBySiblingIdx(SiblingId $sibling_id)[]: Node {
    return $this->siblings[sibling_id_to_int($sibling_id)];
  }

  public function getParseContext()[]: ParseContext {
    return $this->ctx;
  }

  public function getSourceOrder()[]: vec<Node> {
    return $this->sourceOrder;
  }

  /**
   * Careful, if `$node` is not a `LIST` or `MISSING`, you'll get junk.
   */
  public function listGetSize(Syntax $syntax)[]: int {
    $stored_length = node_get_field_1($syntax);
    return $stored_length < FIELD_1_MASK
      ? $stored_length
      : $this->listSizes[node_get_id($syntax)];
  }

  public function sliceSiblings(SiblingId $start, int $length)[]: vec<Node> {
    return Vec\slice($this->siblings, sibling_id_to_int($start), $length);
  }

  // #region Materialization
  const string VERSION = 'VERSION';
  const int VERSION_NUMBER = 2;
  const string SOURCE_ORDER = 'SOURCE_ORDER';
  const string SIBLINGS = 'SIBLINGS';
  const string LIST_SIZES = 'LIST_SIZES';
  const string SOURCE_TEXT = 'SOURCE_TEXT';
  const string CONTEXT_ID = 'CONTEXT_ID';

  public function dematerialize()[]: ReadyToSerializeScript {
    return shape(
      'script' => dict[
        static::VERSION => static::VERSION_NUMBER,
        static::SOURCE_ORDER => $this->sourceOrder,
        static::SIBLINGS => $this->siblings,
        static::LIST_SIZES => $this->listSizes,
        static::SOURCE_TEXT => $this->sourceText,
        static::CONTEXT_ID => $this->ctx->getMaterializationHash(),
      ],
      'context' => $this->ctx->dematerialize(),
      'context_hash' => $this->ctx->getMaterializationHash(),
    );
  }

  public static function materialize(
    dict<arraykey, mixed> $raw,
    ParseContext $ctx,
  )[]: TranslationUnit {
    enforce(
      idx($raw, static::VERSION) === static::VERSION_NUMBER,
      'Could not materialize this Script, '.
      'it was dematerialized with a different version of this library.',
    );
    enforce(
      $ctx->getMaterializationHash() === $raw[static::CONTEXT_ID],
      'The Context and the Script do not belong together.',
    );

    try {
      return new static(
        $raw['SOURCE_ORDER'] |> as_vec_of_node($$),
        $raw['SIBLINGS'] |> as_vec_of_node($$),
        $raw['LIST_SIZES'] |> as_dict_of_node_id_to_int($$),
        $raw['SOURCE_TEXT'] as string,
        $ctx,
      );
    } catch (\Exception $e) {
      throw new PhaException(
        'Failed to materialize this Script.',
        $e->getCode(),
        $e,
      );
    }
  }
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/aliasses.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use namespace HTL\Pha;

type Kind = Pha\Kind;
type Member = Pha\Member;
type TokenKind = Pha\TokenKind;
type TriviumKind = Pha\TriviumKind;
type SyntaxKind = Pha\SyntaxKind;
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/enforce.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use namespace HH\Lib\Str;
use function vsprintf;

/**
 * Think `invariant(...)`, but for `PhaException` instead.
 * Side note: `invariant()` only evaluates the `$format` and `$args`
 * arguments if `$assertion` is false.
 * If the evaluation is computationally expensive,
 * use `if (!$assertion) { ... }` instead.
 */
function enforce(
  bool $assertion,
  Str\SprintfFormatString $format,
  mixed ...$args
)[]: void {
  if (!$assertion) {
    throw new PhaException(vsprintf($format, $args));
  }
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/grammatical_nth.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


function grammatical_nth(int $n)[]: string {
  // Can't just use NumberFormatter, because it has no contexts.
  $last_two_digits = $n % 100;

  if (
    $last_two_digits === 11 ||
    $last_two_digits === 12 ||
    $last_two_digits === 13
  ) {
    return $n.'th';
  }

  $last_digit = $n % 10;

  if ($last_digit === 1) {
    return $n.'st';
  } else if ($last_digit === 2) {
    return $n.'nd';
  } else if ($last_digit === 3) {
    return $n.'rd';
  }

  return $n.'th';
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/hsl/find_last.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use namespace HH\Lib\C;

/**
 * Semantically equivalent to `Vec\reverse($container) |> C\find($$, $predicate)`,
 * but without the runtime overhead of reversing the vec first.
 */
function find_lastx<T>(
  vec<T> $container,
  (function(T)[_]: bool) $predicate,
)[ctx $predicate]: T {
  for ($i = C\count($container) - 1; $i >= 0; --$i) {
    $el = $container[$i];
    if ($predicate($el)) {
      return $el;
    }
  }

  invariant_violation('%s: Could\'t find the target value.', __FUNCTION__);
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/implemenation_types/Context.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


newtype Context = ParseContext;

function context_hide(ParseContext $ctx)[]: Context {
  return $ctx;
}

function context_reveal(Context $ctx)[]: ParseContext {
  return $ctx;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/implemenation_types/IndexMask.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


newtype IndexMask as arraykey = int;

function index_mask_from_int(int $int)[]: IndexMask {
  return $int;
}

function index_mask_to_int(IndexMask $index_mask)[]: int {
  return $index_mask;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/implemenation_types/InternedString.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


newtype InternedString<+T> as arraykey = int;

function interned_string_from_int<<<__Explicit>> T>(
  int $int,
)[]: InternedString<T> {
  return $int;
}

function interned_string_recast_t<<<__Explicit>> T>(
  InternedString<mixed> $interned_string,
)[]: InternedString<T> {
  return $interned_string;
}

function interned_string_to_int(InternedString<mixed> $interned_string)[]: int {
  return $interned_string;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/implemenation_types/KindIdentity.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


newtype KindIdentity as arraykey = int;

function kind_identity_from_int(int $int)[]: KindIdentity {
  return $int;
}

function kind_identity_to_int(KindIdentity $kind_identity)[]: int {
  return $kind_identity;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/implemenation_types/Node.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use namespace HH\Lib\Math;

<<__Sealed(Maybe::class)>>
interface Taggable {}
<<__Sealed(Any::class, SyntaxTag::class, TokenTag::class, TriviumTag::class)>>
interface Maybe<+T as Any> extends Taggable {}
<<__Sealed(SyntaxTag::class, TokenTag::class, TriviumTag::class)>>
interface Any extends Maybe<Any> {}
<<__Sealed()>>
interface SyntaxTag extends Maybe<SyntaxTag>, Any {}
<<__Sealed()>>
interface TokenTag extends Maybe<TokenTag>, Any {}
<<__Sealed()>>
interface TriviumTag extends Maybe<TriviumTag>, Any {}

newtype Tagged<+T as Taggable> = int;

type Node = Tagged<Any>;
type Syntax = Tagged<SyntaxTag>;
type Token = Tagged<TokenTag>;
type Trivium = Tagged<TriviumTag>;
type NillableNode = Tagged<Maybe<Any>>;
type NillableSyntax = Tagged<Maybe<SyntaxTag>>;
type NillableToken = Tagged<Maybe<TokenTag>>;
type NillableTrivium = Tagged<Maybe<TriviumTag>>;

const NillableSyntax NIL = 0;
const NillableSyntax NIL_SYNTAX = 0;
const NillableToken NIL_TOKEN = 0;
const NillableTrivium NIL_TRIVIUM = 0;
const Syntax SCRIPT_NODE = Math\INT64_MIN;

function cast_away_nil<T as Any>(Tagged<Maybe<T>> $t)[]: Tagged<T> {
  return $t;
}

function node_from_int(int $int)[]: Node {
  return $int;
}

function node_to_int(NillableNode $node)[]: int {
  return $node;
}

function nodes_from_ints(vec<int> $ints)[]: vec<Node> {
  return $ints;
}

function nodes_to_ints(vec<NillableNode> $nodes)[]: vec<int> {
  return $nodes;
}

function syntax_from_int(int $int)[]: Syntax {
  return $int;
}

function syntax_from_node(NillableNode $node)[]: Syntax {
  return $node;
}

function syntaxes_from_nodes(vec<NillableNode> $nodes)[]: vec<Syntax> {
  return $nodes;
}

function token_from_int(int $int)[]: Token {
  return $int;
}

function token_from_node(NillableNode $node)[]: Token {
  return $node;
}

function tokens_from_nodes(vec<NillableNode> $nodes)[]: vec<Token> {
  return $nodes;
}

function trivia_from_nodes(vec<NillableNode> $nodes)[]: vec<Trivium> {
  return $nodes;
}

function trivium_from_int(int $int)[]: Trivium {
  return $int;
}

function trivium_from_node(NillableNode $node)[]: Trivium {
  return $node;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/implemenation_types/NodeId.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


newtype NodeId as arraykey = int;

function node_id_add(NodeId $node_id, int $n)[]: NodeId {
  return $node_id + $n;
}

function node_id_diff(NodeId $a, NodeId $b)[]: NodeId {
  invariant(
    $a >= $b,
    '%s expected arguments to be ordered from large to small',
    __FUNCTION__,
  );

  return $a - $b;
}

function node_id_to_int(NodeId $node_id)[]: int {
  return $node_id;
}

function node_id_from_int(int $node_id)[]: NodeId {
  return $node_id;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/implemenation_types/Patch.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


newtype Patch = PatchNode;

function patch_node_hide(PatchNode $patch_node)[]: Patch {
  return $patch_node;
}

function patch_node_reveal(Patch $patch)[]: PatchNode {
  return $patch;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/implemenation_types/Patches.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


newtype Patches = PatchSet;

function patch_set_hide(PatchSet $patch_set)[]: Patches {
  return $patch_set;
}

function patch_set_reveal(Patches $patches)[]: PatchSet {
  return $patches;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/implemenation_types/ReadyToSerialize.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


/**
 * You are not allowed to observe the `mixed` values, aside from serializing them.
 * I wanted to perform the serialization myself, but `\fb_compact_unserialize()`
 * can not be called from a pure context.
 * This means I am leaving the actual encoding up to you, the caller. :)
 *
 * The serialized 'context' may be the same across some scripts.
 * You'd do well to deduplicate those before storing them.
 * You can use the 'context_hash' for this.
 */
type ReadyToSerializeContext = shape(
  'context' => dict<arraykey, mixed>,
  'context_hash' => string,
  ...
);

type ReadyToSerializeScript = shape(
  'script' => dict<arraykey, mixed>,
  'context' => dict<arraykey, mixed>,
  'context_hash' => string,
  ...
);
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/implemenation_types/Script.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


newtype Script = TranslationUnit;

function translation_unit_hide(TranslationUnit $tu)[]: Script {
  return $tu;
}

function translation_unit_reveal(Script $script)[]: TranslationUnit {
  return $script;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/implemenation_types/SearchIndex.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


newtype KindIndex<Tnode as Node, Tkind as Kind> = Index<Tnode, Tkind>;

function index_hide<Tnode as Node, Tkind as Kind>(
  Index<Tnode, Tkind> $index,
)[]: KindIndex<Tnode, Tkind> {
  return $index;
}

function index_reveal<Tnode as Node, Tkind as Kind>(
  KindIndex<Tnode, Tkind> $index,
)[]: Index<Tnode, Tkind> {
  return $index;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/implemenation_types/SiblingId.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


newtype SiblingId as arraykey = int;

function sibling_id_add(SiblingId $sibling_id, int $n)[]: SiblingId {
  return $sibling_id + $n;
}

function sibling_id_to_int(SiblingId $sibling_id)[]: int {
  return $sibling_id;
}

function sibling_id_from_int(int $int)[]: SiblingId {
  return $int;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/implemenation_types/SourceByteOffset.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


newtype SourceByteOffset = int;

function source_byte_offset_from_int(int $int)[]: SourceByteOffset {
  return $int;
}

function source_byte_offset_to_int(SourceByteOffset $offset)[]: int {
  return $offset;
}

function source_byte_offset_is_less_than(
  SourceByteOffset $a,
  SourceByteOffset $b,
)[]: bool {
  return $a < $b;
}

function source_byte_offset_is_less_than_or_equal(
  SourceByteOffset $a,
  SourceByteOffset $b,
)[]: bool {
  return $a < $b;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/implemenation_types/SourceRange.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


newtype SourceRange = (SourceByteOffset, ?SourceByteOffset);

function source_range_hide(
  (SourceByteOffset, ?SourceByteOffset) $range,
)[]: SourceRange {
  return $range;
}

function source_range_reveal(
  SourceRange $range,
)[]: (SourceByteOffset, ?SourceByteOffset) {
  return $range;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/parsing/Intermediate.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use namespace HTL\Pha;

final class Intermediate {
  public function __construct(
    private IntermediateGroup $group,
    private int $id,
    private int $parentId,
    private Kind $kind,
    private ?int $textLength = null,
    private ?int $tokenTextTriviumOffset = null,
  )[] {}

  public function getGroup()[]: IntermediateGroup {
    return $this->group;
  }

  public function getGroupName()[]: string {
    return IntermediateGroup::getNames()[$this->group];
  }

  public function getId()[]: int {
    return $this->id;
  }

  public function getParentId()[]: int {
    return $this->parentId;
  }

  public function getSyntaxKind()[]: SyntaxKind {
    invariant(
      $this->group === IntermediateGroup::SYNTAX,
      '%s can not be called on a %s.',
      __FUNCTION__,
      $this->getGroupName(),
    );
    return $this->kind |> Pha\syntax_kind_from_kind($$);
  }

  public function getTokenKind()[]: TokenKind {
    invariant(
      $this->group === IntermediateGroup::TOKEN,
      '%s can not be called on a %s.',
      __FUNCTION__,
      $this->getGroupName(),
    );
    return $this->kind |> Pha\token_kind_from_kind($$);
  }

  public function getTriviumKind()[]: TriviumKind {
    invariant(
      $this->group === IntermediateGroup::TRIVIUM,
      '%s can not be called on a %s.',
      __FUNCTION__,
      $this->getGroupName(),
    );
    return $this->kind |> Pha\trivium_kind_from_kind($$);
  }

  public function getTextLength()[]: ?int {
    return $this->textLength;
  }

  public function getTextLengthx()[]: int {
    invariant(
      $this->textLength is nonnull,
      '%s (%s) has no text',
      $this->kind,
      $this->getGroupName(),
    );
    return $this->textLength;
  }

  public function getTokenTextTriviumOffset()[]: ?int {
    return $this->tokenTextTriviumOffset;
  }

  public function getTokenTextTriviumOffsetx()[]: int {
    invariant(
      $this->tokenTextTriviumOffset is nonnull,
      '%s (%s) has no token text trivium offset',
      $this->kind,
      $this->getGroupName(),
    );
    return $this->tokenTextTriviumOffset;
  }
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/parsing/IntermediateGroup.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


enum IntermediateGroup: int {
  LIST = 0;
  MISSING = 1;
  SYNTAX = 2;
  TOKEN = 3;
  TRIVIUM = 4;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/parsing/Wrapped.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use namespace HTL\Pha;

final class Wrapped {
  public function __construct(
    private dict<arraykey, mixed> $item,
    private int $parentId,
  )[] {}

  public function getItem()[]: dict<arraykey, mixed> {
    return $this->item;
  }

  public function createList(int $id)[]: Intermediate {
    return new Intermediate(
      IntermediateGroup::LIST,
      $id,
      $this->parentId,
      Pha\KIND_NODE_LIST,
    );
  }

  public function createMissing(int $id)[]: Intermediate {
    return new Intermediate(
      IntermediateGroup::MISSING,
      $id,
      $this->parentId,
      Pha\KIND_MISSING,
    );
  }

  public function createSyntax(int $id, SyntaxKind $kind)[]: Intermediate {
    return
      new Intermediate(IntermediateGroup::SYNTAX, $id, $this->parentId, $kind);
  }

  public function createToken(
    int $pid,
    TokenKind $kind,
    int $number_of_leading,
  )[]: Intermediate {
    return new Intermediate(
      IntermediateGroup::TOKEN,
      $pid,
      $this->parentId,
      $kind,
      null,
      $number_of_leading + 1,
    );
  }
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/parsing/create_intermediate_list.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use namespace HH\Lib\Vec;

function create_intermediate_list(
  Wrapped $next,
  int $id,
)[]: (Intermediate, vec<Wrapped>) {
  $list = $next->getItem();

  // Could be a dict or a vec, depending on json_decode() options...
  // This is a square bracket array literal in the json,
  // but the default for `\json_decode()` remains to create a dict.
  // If users decode from `HH\ffp_parse_string_native(...)` and json_decode()
  // with `\JSON_DECODE_HACK_ARRAYS`, we'd see vecs here.
  $elements = $list['elements'] as Container<_>;
  $intermediate = $next->createList($id);
  $children = Vec\map($elements, $el ==> new Wrapped($el as dict<_, _>, $id));

  return tuple($intermediate, $children);
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/parsing/create_intermediate_missing.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


function create_intermediate_missing(Wrapped $next, int $id)[]: Intermediate {
  return $next->createMissing($id);
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/parsing/create_intermediate_syntax.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use namespace HTL\Pha;

function create_intermediate_syntax(
  Wrapped $next,
  int $id,
)[]: (Intermediate, vec<Wrapped>) {
  $syntax = $next->getItem();

  $intermediate = $next->createSyntax(
    $id,
    Pha\syntax_kind_from_string($syntax['kind'] as string),
  );

  $children = vec[];
  foreach ($syntax as $key => $el) {
    if ($key === 'kind') {
      continue;
    }

    $children[] = new Wrapped($el as dict<_, _>, $id);
  }

  return tuple($intermediate, $children);
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/parsing/create_intermediate_token.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Str};
use namespace HTL\Pha;

function create_intermediate_token(
  Wrapped $next,
  int $id,
)[]: (Intermediate, vec<Intermediate>) {
  $token = $next->getItem()['token'] as dict<_, _>;
  $leading_raw = $token['leading'] as dict<_, _>;
  $trailing_raw = $token['trailing'] as dict<_, _>;

  $intermediate = $next->createToken(
    $id,
    Pha\token_kind_from_string($token['kind'] as string),
    C\count($leading_raw),
  );

  $count = 1;
  $leading = create_intermediate_trivia($id, $count, $leading_raw);
  $count += C\count($leading_raw);

  $synthetic_token_text_trivium = new Intermediate(
    IntermediateGroup::TRIVIUM,
    $id + $count,
    $id,
    Pha\KIND_TOKEN_TEXT,
    Str\length($token['text'] as string),
  );
  ++$count;

  $trailing = create_intermediate_trivia($id, $count, $trailing_raw);

  $trivia = vec[];

  foreach ($leading as $trivium) {
    $trivia[] = $trivium;
  }

  $trivia[] = $synthetic_token_text_trivium;

  foreach ($trailing as $trivium) {
    $trivia[] = $trivium;
  }

  return tuple($intermediate, $trivia);
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/parsing/create_intermediate_trivia.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use namespace HH\Lib\Str;
use namespace HTL\Pha;

function create_intermediate_trivia(
  int $id,
  int $count,
  dict<arraykey, mixed> $trivia,
)[]: vec<Intermediate> {
  $out = vec[];

  foreach ($trivia as $trivium) {
    $trivium as dict<_, _>;
    $out[] = new Intermediate(
      IntermediateGroup::TRIVIUM,
      $id + $count,
      $id,
      Pha\trivium_kind_from_string($trivium['kind'] as string),
      Str\length($trivium['text'] as string),
    );
    ++$count;
  }

  return $out;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/parsing/create_intermediates.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Vec};
use namespace HTL\Pha;

function create_intermediates(
  dict<arraykey, mixed> $parse_tree,
  inout dict<SyntaxKind, vec<Member>> $known_member_names,
  inout keyset<TokenKind> $known_token_kinds,
  inout keyset<TriviumKind> $known_trivium_kinds,
)[]: vec<Intermediate> {
  $id = 0;
  $completed = vec[];
  $queue = vec[new Wrapped($parse_tree, $id)];
  $queue_ptr = 0;

  do {
    $to_parse = $queue[$queue_ptr];
    switch ($to_parse->getItem()['kind'] as string) {
      case 'token':
        $wrapped_nodes = vec[];
        list($token, $trivia) = create_intermediate_token($to_parse, $id);
        $intermediates = Vec\concat(vec[$token], $trivia);
        $token_kind = $token->getTokenKind();
        if (!C\contains_key($known_token_kinds, $token_kind)) {
          $known_token_kinds[] = $token_kind;
        }
        foreach ($trivia as $trivium) {
          $trivium_kind = $trivium->getTriviumKind();
          if (!C\contains_key($known_trivium_kinds, $trivium_kind)) {
            $known_trivium_kinds[] = $trivium_kind;
          }
        }
        break;
      case 'list':
        list($list, $wrapped_nodes) = create_intermediate_list($to_parse, $id);
        $intermediates = vec[$list];
        break;
      case 'missing':
        $wrapped_nodes = vec[];
        $intermediates = vec[create_intermediate_missing($to_parse, $id)];
        break;
      default /* syntax */:
        list($syntax, $wrapped_nodes) =
          create_intermediate_syntax($to_parse, $id);
        $intermediates = vec[$syntax];
        if (!C\contains_key($known_member_names, $syntax->getSyntaxKind())) {
          $new_names = vec[];

          foreach (Vec\keys($to_parse->getItem()) as $member_name) {
            if ($member_name !== 'kind') {
              $new_names[] = Pha\member_from_tuple(
                tuple($syntax->getSyntaxKind(), $member_name as string),
              );
            }
          }

          $known_member_names[$syntax->getSyntaxKind()] = $new_names;
        }
    }

    ++$queue_ptr;
    $id += C\count($intermediates);

    foreach ($intermediates as $intermediate) {
      $completed[] = $intermediate;
    }

    foreach ($wrapped_nodes as $node) {
      $queue[] = $node;
    }
  } while (C\contains_key($queue, $queue_ptr));

  return Vec\sort_by($completed, $i ==> $i->getId());
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/parsing/create_node.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use namespace HH\Lib\Math;

function create_node(
  Intermediate $node,
  int $source_order_idx,
  int $parent_idx,
  (int, int) $child_range,
  ParseContext $ctx,
  inout int $byte_offset,
)[]: Node {
  // See bin/pseudo-fields.documentation.txt
  switch ($node->getGroup()) {
    case IntermediateGroup::SYNTAX:
      $field_0 = SYNTAX_TAG;
      $field_1 = $ctx->getSyntaxKinds()->intern($node->getSyntaxKind())
        |> interned_string_to_int($$);
      $field_3 = $child_range[0];
      break;
    case IntermediateGroup::TOKEN:
      $field_0 = TOKEN_TAG;
      $field_1 = $ctx->getTokenKinds()->intern($node->getTokenKind())
        |> interned_string_to_int($$);
      $field_3 = $source_order_idx + $node->getTokenTextTriviumOffsetx();
      break;
    case IntermediateGroup::TRIVIUM:
      $field_0 = TRIVIUM_TAG;
      $field_1 = $ctx->getTriviumKinds()->intern($node->getTriviumKind())
        |> interned_string_to_int($$);
      $field_3 = $byte_offset;
      $byte_offset += $node->getTextLengthx();
      break;
    case IntermediateGroup::LIST:
      $field_0 = LIST_OR_MISSING_TAG;
      // + 1, because a range from x to x is of length 1, not 0.
      $field_1 =
        Math\minva(FIELD_1_MASK, $child_range[1] - $child_range[0] + 1);
      $field_3 = $child_range[0];
      break;
    case IntermediateGroup::MISSING:
      $field_0 = LIST_OR_MISSING_TAG;
      $field_1 = 0;
      $field_3 = 0;
  }

  $field_2 = $parent_idx;
  $field_4 = $source_order_idx;

  return node_from_int(
    ($field_0) |
      ($field_1 << 54) |
      ($field_2 << 36) |
      ($field_3 << 18) |
      $field_4,
  );
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/parsing/create_translation_unit.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Str, Vec};

function create_translation_unit(
  vec<Intermediate> $intermediates,
  string $source_text,
  ParseContext $ctx,
)[]: TranslationUnit {
  enforce(
    Str\length($source_text) < FIELD_3_MASK,
    'Implementation limit: Source may not exceed %d (0x%x) bytes, got %d.',
    FIELD_3_MASK,
    FIELD_3_MASK,
    Str\length($source_text),
  );

  enforce(
    C\count($intermediates) < FIELD_4_MASK,
    'Implementation limit: Source may not exceed %d (0x%x) nodes, got %d.',
    FIELD_4_MASK,
    FIELD_4_MASK,
    C\count($intermediates),
  );

  list($parent_ranges, $siblings_intermediates) =
    layout_siblings($intermediates);
  $source_order = layout_source_order($intermediates);

  $id_to_source_idx = Vec\fill(C\count($intermediates), 0);
  foreach ($source_order as $source_order_idx => $intermediate) {
    $id_to_source_idx[$intermediate->getId()] = $source_order_idx;
  }

  $byte_offset = 0;
  $nodes = vec[];
  $list_sizes = dict[];
  foreach ($source_order as $source_order_idx => $intermediate) {
    $range = idx($parent_ranges, $intermediate->getId(), tuple(0, 0));
    $nodes[] = create_node(
      $intermediate,
      $source_order_idx,
      $id_to_source_idx[$intermediate->getParentId()],
      $range,
      $ctx,
      inout $byte_offset,
    );

    if ($intermediate->getGroup() === IntermediateGroup::LIST) {
      // + 1, because a range from x to x is of length 1, not 0.
      $size = $range[1] - $range[0] + 1;
      if ($size >= FIELD_1_MASK) {
        $list_sizes[node_id_from_int($source_order_idx)] = $size;
      }
    }
  }

  $siblings = Vec\map(
    $siblings_intermediates,
    $x ==> $nodes[$id_to_source_idx[$x->getId()]],
  );

  return
    new TranslationUnit($nodes, $siblings, $list_sizes, $source_text, $ctx);
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/parsing/extract_ranges.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use namespace HH\Lib\C;

function extract_ranges(
  dict<int, vec<mixed>> $heritage,
)[]: dict<int, (int, int)> {
  $out = dict[];
  $start_range = 0;

  foreach ($heritage as $id => $children) {
    $past_end = $start_range + C\count($children);
    $out[$id] = tuple($start_range, $past_end - 1);
    $start_range = $past_end;
  }

  return $out;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/parsing/layout_siblings.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{Dict, Vec};

/**
 * Get the children of syntax and list nodes.
 * For other nodes, the children are implied:
 *  - Token -> All trivia are sequential
 *  - Trivium / Missing -> Has no children
 *
 * @return (dict<parent_id, (start, end)>, vec<siblings>)
 */
function layout_siblings(
  vec<Intermediate> $intermediates,
)[]: (dict<int, (int, int)>, vec<Intermediate>) {
  $heritage = Vec\filter(
    $intermediates,
    $x ==> (
      $intermediates[$x->getParentId()]->getGroup()
      |> $$ === IntermediateGroup::SYNTAX || $$ === IntermediateGroup::LIST
    ) &&
      $x->getId() !== 0,
  )
    |> Dict\group_by($$, $x ==> $x->getParentId());

  return tuple(extract_ranges($heritage), Vec\flatten($heritage));
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/parsing/layout_source_order.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Dict};

function layout_source_order(
  vec<Intermediate> $intermediates,
)[]: vec<Intermediate> {
  $parents_to_children =
    Dict\group_by($intermediates, $x ==> $x->getParentId());
  $out = vec[$intermediates[0], $intermediates[1]];

  // A `vec[]` is used as a `Stack<T>`, since we can't have `[write_props]`.
  // This makes pushing a little cumbersome, see `$stack->push($to_push)`.
  $stack = vec[tuple(1, 0)];
  $stack_ptr = 0;
  $stack_top = 0;

  do {
    list($node_id, $child_number) = $stack[$stack_ptr];
    $children = idx($parents_to_children, $node_id, vec[]);
    ++$stack[$stack_ptr][1];

    if (C\count($children) > $child_number) {
      $child = $children[$child_number];
      $out[] = $child;

      // `$stack->push($to_push)`, but without `[write_props]`
      $to_push = tuple($child->getId(), 0);
      ++$stack_ptr;
      if ($stack_ptr > $stack_top) {
        $stack[] = $to_push;
        ++$stack_top;
      } else {
        $stack[$stack_ptr] = $to_push;
      }
    } else {
      --$stack_ptr;
    }
  } while ($stack_ptr !== -1);

  return $out;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/private_node_functions.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use namespace HH\Lib\Math;
use namespace HTL\Pha;

const int FIELD_4_SIZE = 18;
const int FIELD_3_SIZE = 18;
const int FIELD_2_SIZE = 18;
const int FIELD_1_SIZE = 8;
const int FIELD_0_SIZE = 2;

const int FIELD_4_OFFSET = 0;
const int FIELD_3_OFFSET = FIELD_4_OFFSET + FIELD_4_SIZE;
const int FIELD_2_OFFSET = FIELD_3_OFFSET + FIELD_3_SIZE;
const int FIELD_1_OFFSET = FIELD_2_OFFSET + FIELD_2_SIZE;
const int FIELD_0_OFFSET = FIELD_1_OFFSET + FIELD_1_SIZE;

const int FIELD_4_MASK = (1 << FIELD_4_SIZE) - 1;
const int FIELD_3_MASK = (1 << FIELD_3_SIZE) - 1;
const int FIELD_2_MASK = (1 << FIELD_2_SIZE) - 1;
const int FIELD_1_MASK = (1 << FIELD_1_SIZE) - 1;
const int FIELD_0_MASK = (1 << FIELD_0_SIZE) - 1;

// This mask is the KindIdentity mask for non-LIST and non-MISSING nodes.
const int FIELD_01_PRE_SHIFT_MASK =
  (FIELD_0_MASK << FIELD_0_OFFSET) | (FIELD_1_MASK << FIELD_1_OFFSET);
// This mask is the IndexMask for non-LIST and non-MISSING nodes.
const int FIELD_14_PRE_SHIFT_MASK =
  (FIELD_1_MASK << FIELD_1_OFFSET) | (FIELD_4_MASK << FIELD_4_OFFSET);

const int SYNTAX_TAG = Math\INT64_MIN;
const int TOKEN_TAG = 1 << 62;
const int TRIVIUM_TAG = 0;
const int LIST_OR_MISSING_TAG = Math\INT64_MIN | (1 << 62);

const int MAX_INTERNED_STRING = FIELD_1_MASK;

/**
 * Careful, if `$kind` is `KIND_NODE_LIST` or `KIND_MISSING`, you'll get a non
 * matching identity.
 */
function create_syntax_identity(
  Script $script,
  SyntaxKind $kind,
)[]: KindIdentity {
  if ($kind === Pha\KIND_NODE_LIST || $kind === Pha\KIND_MISSING) {
    // This is a hack, these nodes don't have an identity.
    // Just return the greatest trivium kind there is.
    // If we ever get to a world with max trivia, consider this
    // a classic case of "This should never happen.".
    return TRIVIUM_TAG | (MAX_INTERNED_STRING << FIELD_1_OFFSET)
      |> kind_identity_from_int($$);
  }

  $ctx = translation_unit_reveal($script)->getParseContext();
  return $ctx->getSyntaxKinds()->internOrMax($kind)
    |> interned_string_to_int($$) << FIELD_1_OFFSET
    |> $$ | SYNTAX_TAG
    |> kind_identity_from_int($$);
}

function create_token_identity(
  Script $script,
  TokenKind $kind,
)[]: KindIdentity {
  $ctx = translation_unit_reveal($script)->getParseContext();
  return $ctx->getTokenKinds()->internOrMax($kind)
    |> interned_string_to_int($$) << FIELD_1_OFFSET
    |> $$ | TOKEN_TAG
    |> kind_identity_from_int($$);
}

function create_trivium_identity(
  Script $script,
  TriviumKind $kind,
)[]: KindIdentity {
  $ctx = translation_unit_reveal($script)->getParseContext();
  return $ctx->getTriviumKinds()->internOrMax($kind)
    |> interned_string_to_int($$) << FIELD_1_OFFSET
    |> $$ | TRIVIUM_TAG
    |> kind_identity_from_int($$);
}

/**
 * Mind the sign extension,
 * so `10`, and `11` will be `...11111110` and `...11111111` respectively.
 */
function node_get_field_0(NillableNode $node)[]: int {
  return node_to_int($node) >> FIELD_0_OFFSET;
}

function node_get_field_1(NillableNode $node)[]: int {
  return node_to_int($node) >> FIELD_1_OFFSET |> $$ & FIELD_1_MASK;
}

function node_get_field_2(NillableNode $node)[]: int {
  return node_to_int($node) >> FIELD_2_OFFSET |> $$ & FIELD_2_MASK;
}

function node_get_field_3(NillableNode $node)[]: int {
  return node_to_int($node) >> FIELD_3_OFFSET |> $$ & FIELD_3_MASK;
}

function node_get_field_4(NillableNode $node)[]: int {
  return node_to_int($node) & FIELD_4_MASK;
}

function node_get_id(Node $node)[]: NodeId {
  return node_get_field_4($node) |> node_id_from_int($$);
}

/**
 * Careful, if `$node` is `LIST` or `MISSING`, you'll get junk.
 */
function node_get_index_mask(Node $node)[]: IndexMask {
  return
    node_to_int($node) & FIELD_14_PRE_SHIFT_MASK |> index_mask_from_int($$);
}

/**
 * Careful, if `$node` is `LIST` or `MISSING`, you'll get junk.
 */
function node_get_interned_kind<<<__Explicit>> T as Kind>(
  Node $node,
)[]: InternedString<T> {
  return node_get_field_1($node) |> interned_string_from_int<T>($$);
}

/**
 * Careful, if `$node` is `LIST` or `MISSING`, you'll get junk.
 */
function node_get_kind_identity(Node $node)[]: KindIdentity {
  return
    node_to_int($node) & FIELD_01_PRE_SHIFT_MASK |> kind_identity_from_int($$);
}

/**
 * This *may* read past the end of the Node to find the very next trivium.
 * This is a very strange function, therefore private.
 */
function node_get_next_trivium(
  Script $script,
  NillableNode $node,
)[]: NillableTrivium {
  if ($node === NIL) {
    return NIL_TRIVIUM;
  }

  $tu = translation_unit_reveal($script);

  do {
    $node = cast_away_nil($node)
      |> node_get_id($$)
      |> node_id_add($$, 1)
      |> $tu->getNodeById($$);
  } while (!Pha\is_trivium($node) && $node !== NIL);

  return $node === NIL ? NIL_TRIVIUM : trivium_from_node($node);
}

function node_get_parent_id(Node $node)[]: NodeId {
  return node_get_field_2($node) |> node_id_from_int($$);
}

function node_is_between_or_at_boundary(
  Node $compare,
  NodeId $start,
  NodeId $end,
)[]: bool {
  return node_get_id($compare)
    |> node_id_to_int($$)
    |> $$ >= node_id_to_int($start) && $$ <= node_id_to_int($end);
}

function syntax_get_first_child_sibling_id(Syntax $node)[]: SiblingId {
  return node_get_field_3($node) |> sibling_id_from_int($$);
}

function trivium_get_source_byte_offset(Trivium $trivium)[]: SourceByteOffset {
  return node_get_field_3($trivium) |> source_byte_offset_from_int($$);
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/retain_trivia_keep_leading_and_trailing.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use namespace HTL\Pha;

function retain_trivia_keep_leading_and_trailing(
  Pha\RetainTrivia $retain_trivia,
)[]: (bool, bool) {
  switch ($retain_trivia) {
    case Pha\RetainTrivia::BOTH:
      return tuple(true, true);
    case Pha\RetainTrivia::NEITHER:
      return tuple(false, false);
    case Pha\RetainTrivia::LEADING:
      return tuple(true, false);
    case Pha\RetainTrivia::TRAILING:
      return tuple(false, true);
  }
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/_Private/type_assert.hack /////
namespace HTL\Pha\_Private {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use namespace HTL\Pha;

// These functions assert to AnyArray<_, _> to survive fb_compact_serialize...

function as_dict_of_node_id_to_int(mixed $raw)[]: dict<NodeId, int> {
  $out = dict[];

  foreach (($raw as AnyArray<_, _>) as $k => $v) {
    $out[node_id_from_int($k as int)] = $v as int;
  }

  return $out;
}

function as_vec_of_member(mixed $raw)[]: vec<Member> {
  $out = vec[];

  foreach (($raw as AnyArray<_, _>) as $v) {
    $v as AnyArray<_, _>;
    $out[] = Pha\member_from_tuple(
      tuple(Pha\syntax_kind_from_string($v[0] as string), $v[1] as string),
    );
  }

  return $out;
}

function as_vec_of_node(mixed $raw)[]: vec<Node> {
  $out = vec[];

  foreach (($raw as AnyArray<_, _>) as $v) {
    $out[] = node_from_int($v as int);
  }

  return $out;
}

function as_vec_of_syntax_kind(mixed $raw)[]: vec<SyntaxKind> {
  $out = vec[];

  foreach (($raw as AnyArray<_, _>) as $v) {
    $out[] = Pha\syntax_kind_from_string($v as string);
  }

  return $out;
}

function as_vec_of_token_kind(mixed $raw)[]: vec<TokenKind> {
  $out = vec[];

  foreach (($raw as AnyArray<_, _>) as $v) {
    $out[] = Pha\token_kind_from_string($v as string);
  }

  return $out;
}

function as_vec_of_trivium_kind(mixed $raw)[]: vec<TriviumKind> {
  $out = vec[];

  foreach (($raw as AnyArray<_, _>) as $v) {
    $out[] = Pha\trivium_kind_from_string($v as string);
  }

  return $out;
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/create_context.hack /////
namespace HTL\Pha {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


function create_context()[]: Context {
  return new _Private\ParseContext(
    new _Private\Structs(dict[]),
    new _Private\InternedStringStorage(keyset[], syntax_kind_from_string<>),
    new _Private\InternedStringStorage(keyset[], token_kind_from_string<>),
    new _Private\InternedStringStorage(keyset[], trivium_kind_from_string<>),
  )
    |> _Private\context_hide($$);
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/create_kind_index.hack /////
namespace HTL\Pha {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


function create_syntax_kind_index(Script $script)[]: SyntaxIndex {
  $c = _Private\translation_unit_reveal($script)->getParseContext();
  return script_get_syntaxes_without_missing_and_list($script)
    |> _Private\Index::create<Syntax, SyntaxKind>($c, NodeGroup::SYNTAX, $$)
    |> _Private\index_hide($$);
}

function create_token_kind_index(Script $script)[]: TokenIndex {
  $c = _Private\translation_unit_reveal($script)->getParseContext();
  return script_get_tokens($script)
    |> _Private\Index::create<Token, TokenKind>($c, NodeGroup::TOKEN, $$)
    |> _Private\index_hide($$);
}

function create_trivium_kind_index(Script $script)[]: TriviumIndex {
  $c = _Private\translation_unit_reveal($script)->getParseContext();
  return script_get_trivia($script)
    |> _Private\Index::create<Trivium, TriviumKind>($c, NodeGroup::TRIVIUM, $$)
    |> _Private\index_hide($$);
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/materialize.hack /////
namespace HTL\Pha {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


function dematerialize_context(Context $ctx)[]: ReadyToSerializeContext {
  return _Private\context_reveal($ctx)
    |> shape(
      'context' => $$->dematerialize(),
      'context_hash' => $$->getMaterializationHash(),
    );
}

function dematerialize_script(Script $script)[]: ReadyToSerializeScript {
  return _Private\translation_unit_reveal($script)->dematerialize();
}

function materialize_context(dict<arraykey, mixed> $dematerialized)[]: Context {
  return _Private\ParseContext::materialize($dematerialized)
    |> _Private\context_hide($$);
}

/**
 * If you provide a value that was not returned by `dematerialize_script`,
 * you are invoking undefined behavior.
 */
function materialize_script(
  dict<arraykey, mixed> $dematerialized,
  Context $ctx,
)[]: Script {
  return _Private\context_reveal($ctx)
    |> _Private\TranslationUnit::materialize($dematerialized, $$)
    |> _Private\translation_unit_hide($$);
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/node_functions.hack /////
namespace HTL\Pha {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use namespace HH\Lib\{C, Dict, Math, Str, Vec};

/**
 * @package This file contains all the functions that operate on `Node`.
 * Think of them as methods on the `Node` "class".
 *
 * Some help for searching:
 *  - All functions are in `snake_case()`. `SHOUT_CASE` things are constants.
 *  - Functions that start with `node_` will work on all Nodes,
 *    sometimes even nillable nodes.
 *  - Functions that start with `syntax_`, `token_`, or `trivium_` only work on
 *    syntaxes, tokens, and trivia (or their nillable counterparts) respectively.
 *  - `Node`, `Syntax`, `Token`, and `Trivium` are not `<<__Enforceable>>`.
 *    Replacements are provided in the form of functions.
 *    - `is`: `Pha\is_x()`
 *    - `as`: `Pha\as_x()`
 *    - `?as`: `Pha\as_x_or_nil()` will return `Pha\NIL`, not `null` on failure.
 */

/**
 * @throws Iff $node is NIL.
 */
function as_nonnil<T as _Private\Any>(
  _Private\Tagged<_Private\Maybe<T>> $node,
)[]: _Private\Tagged<T> {
  if ($node === NIL) {
    throw new _Private\PhaException(Str\format('%s got NIL', __FUNCTION__));
  }

  return _Private\cast_away_nil($node);
}

/**
 * @throws Iff $node is not Syntax.
 */
function as_syntax(NillableNode $node)[]: Syntax {
  $ret = as_syntax_or_nil($node);

  if ($ret !== NIL) {
    return _Private\cast_away_nil($ret);
  }

  throw new _Private\PhaException(Str\format(
    '%s expected a Syntax, got %s.',
    __FUNCTION__,
    node_get_group_name($node),
  ));
}

function as_syntax_or_nil(NillableNode $node)[]: NillableSyntax {
  return $node !== NIL &&
    node_get_group(_Private\cast_away_nil($node)) === NodeGroup::SYNTAX
    ? _Private\syntax_from_node($node)
    : NIL;
}

/**
 * @throws Iff $node is not Token.
 */
function as_token(NillableNode $node)[]: Token {
  $ret = as_token_or_nil($node);

  if ($ret !== NIL) {
    return _Private\cast_away_nil($ret);
  }

  throw new _Private\PhaException(Str\format(
    '%s expected a Token, got %s.',
    __FUNCTION__,
    node_get_group_name($node),
  ));
}

function as_token_or_nil(NillableNode $node)[]: NillableToken {
  return $node !== NIL &&
    node_get_group(_Private\cast_away_nil($node)) === NodeGroup::TOKEN
    ? _Private\token_from_node($node)
    : NIL_TOKEN;
}

/**
 * @throws If $node is not Trivium.
 */
function as_trivium(NillableNode $node)[]: Trivium {
  $ret = as_trivium_or_nil($node);

  if ($ret !== NIL) {
    return _Private\cast_away_nil($ret);
  }

  throw new _Private\PhaException(Str\format(
    '%s expected a Trivium, got %s.',
    __FUNCTION__,
    node_get_group_name($node),
  ));
}

function as_trivium_or_nil(NillableNode $node)[]: NillableTrivium {
  return $node !== NIL &&
    node_get_group(_Private\cast_away_nil($node)) === NodeGroup::TRIVIUM
    ? _Private\trivium_from_node($node)
    : NIL_TRIVIUM;
}

/**
 * This returns an optimized predicate that checks the kind of the node passed.
 * Don't create these matchers in a loop. That defeats the perf benefits.
 * Prefer using matchers over checking the kind if the code becomes easier to read.
 *
 * ```
 * $is_basic_math_operator = create_matcher(
 *   $script,
 *   vec[],
 *   vec[Pha\KIND_PLUS, Pha\KIND_MINUS, Pha\KIND_STAR, Pha\KIND_SLASH],
 *   vec[],
 * );
 *
 * $some_node_or_nil = ...;
 * if ($is_basic_math_operator($some_node_or_nil)) { ... }
 * ```
 */
function create_matcher(
  Script $script,
  vec<SyntaxKind> $syntax_kinds,
  vec<TokenKind> $token_kinds,
  vec<TriviumKind> $trivium_kinds,
)[]: (function(NillableNode)[]: bool) {
  $identities = Vec\concat(
    Vec\map($syntax_kinds, $k ==> _Private\create_syntax_identity($script, $k)),
    Vec\map($token_kinds, $k ==> _Private\create_token_identity($script, $k)),
    Vec\map(
      $trivium_kinds,
      $k ==> _Private\create_trivium_identity($script, $k),
    ),
  )
    |> Vec\unique($$);

  // `-1` is a `false`, since all bits are set, even those outside the mask.
  $id_0 = idx($identities, 0, -1);
  $id_1 = idx($identities, 1, -1);
  $id_2 = idx($identities, 2, -1);
  $id_3 = idx($identities, 3, -1);

  // All arms are equivalent to the `default:` arm,
  // but they don't need to iterate the $identities vec.
  $matcher = ()[] ==> {
    switch (C\count($identities)) {
      case 0:
        return ($_)[] ==> false;
      case 1:
        return ($n)[] ==> $n !== NIL &&
          (
            _Private\node_get_kind_identity(_Private\cast_away_nil($n))
            |> $$ === $id_0
          );
      case 2:
      case 3:
      case 4:
        return ($n)[] ==> $n !== NIL &&
          (
            _Private\node_get_kind_identity(_Private\cast_away_nil($n))
            |> $$ === $id_0 || $$ === $id_1 || $$ === $id_2 || $$ === $id_3
          );
      default:
        return ($n)[] ==> $n !== NIL &&
          (
            _Private\node_get_kind_identity(_Private\cast_away_nil($n))
            |> C\contains($identities, $$)
          );
    }
  }();

  $look_for_list = C\contains($syntax_kinds, KIND_NODE_LIST);
  $look_for_missing = C\contains($syntax_kinds, KIND_MISSING);

  if ($look_for_list || $look_for_missing) {
    return $n ==> {
      if ($n === NIL) {
        return false;
      }

      $n = _Private\cast_away_nil($n);

      switch (node_get_elaborated_group($n)) {
        case NodeElaboratedGroup::LIST:
          return $look_for_list;
        case NodeElaboratedGroup::MISSING:
          return $look_for_missing;
        default:
          return $matcher($n);
      }
    };
  }

  return $matcher;
}

/**
 * An alternative to `syntax_member($script, $node, $member)`.
 * This version returns a callable that takes `$node`.
 * It can also pick the "right" member to create on the fly polymorphism.
 *
 * ```
 * $get_clauses = create_member_accessor($script, dict[
 *   Pha\KIND_NAMESPACE_USE_DECLARATION => Pha\MEMBER_NAMESPACE_USE_CLAUSES,
 *   Pha\KIND_NAMESPACE_GROUP_USE_DECLARATION => Pha\MEMBER_NAMESPACE_GROUP_USE_CLAUSES,
 * ]);
 *
 * $namespace_use_or_group_use_declaration = ...;
 * $clauses = $get_clauses($namespace_use_or_group_use_declaration);
 * ```
 *
 * If you are always selecting Syntaxes, @see `returns_syntax`.
 * If you are always selecting Tokens, @see `returns_token`.
 */
function create_member_accessor(
  Script $script,
  Member ...$accessors
)[]: (function(Syntax)[]: Node) {
  $tu = _Private\translation_unit_reveal($script);
  $structs = $tu->getParseContext()->getStructs();

  $interned = Dict\pull(
    $accessors,
    $member ==> {
      $syntax_kind = member_get_syntax_kind($member);
      $members = idx($structs->getRaw(), $syntax_kind);

      if ($members is null) {
        return null;
      }

      $idx = C\find_key($members, $m ==> $member === $m);

      if ($idx is nonnull) {
        return $idx;
      }

      throw new _Private\PhaException(
        Str\format(
          '%s does not have a member named %s. Only %s does have this member.',
          $syntax_kind,
          member_get_name($member),
          member_get_syntax_kind($member),
        ),
      );
    },
    $member ==>
      _Private\create_syntax_identity($script, member_get_syntax_kind($member)),
  );

  // Optimize for the common case
  if (C\count($interned) === 1) {
    $identity = C\first_keyx($interned);
    $child_number = $interned[$identity];
    return $n ==> {
      if (
        _Private\node_get_kind_identity($n) !== $identity ||
        $child_number is null
      ) {
        throw new _Private\PhaException(Str\format(
          'No syntax accessor defined for %s.',
          node_get_kind($script, $n),
        ));
      }

      return node_get_child_at_offsetx($script, $n, $child_number);
    };
  }

  return $n ==> {
    $idx = idx($interned, _Private\node_get_kind_identity($n));

    if ($idx is null) {
      throw new _Private\PhaException(Str\format(
        'No syntax accessor defined for %s.',
        node_get_kind($script, $n),
      ));
    }

    return node_get_child_at_offsetx($script, $n, $idx);
  };
}

function create_syntax_matcher(
  Script $script,
  SyntaxKind $first,
  SyntaxKind ...$rest
)[]: (function(NillableNode)[]: bool) {
  return create_matcher($script, Vec\concat(vec[$first], $rest), vec[], vec[]);
}

function create_token_matcher(
  Script $script,
  TokenKind $first,
  TokenKind ...$rest
)[]: (function(NillableNode)[]: bool) {
  return create_matcher($script, vec[], Vec\concat(vec[$first], $rest), vec[]);
}

function create_trivium_matcher(
  Script $script,
  TriviumKind $first,
  TriviumKind ...$rest
)[]: (function(NillableNode)[]: bool) {
  return create_matcher($script, vec[], vec[], Vec\concat(vec[$first], $rest));
}

/**
 * @param $index is a `ScriptIndex`, `TokenIndex`, or a `TriviumIndex`.
 * The returned nodes are in source order.
 */
function index_get_nodes_by_kind<Tnode as Node, Tkind as Kind>(
  _Private\KindIndex<Tnode, Tkind> $index,
  Tkind $kind,
)[]: vec<Tnode> {
  return _Private\index_reveal($index)->getByKind($kind);
}

function is_missing(NillableNode $node)[]: bool {
  if ($node === NIL) {
    return false;
  }

  $node = _Private\cast_away_nil($node);

  switch (node_get_elaborated_group($node)) {
    case NodeElaboratedGroup::SYNTAX:
    case NodeElaboratedGroup::TOKEN:
    case NodeElaboratedGroup::TRIVIUM:
    case NodeElaboratedGroup::LIST:
      return false;
    case NodeElaboratedGroup::MISSING:
      return true;
  }
}

function is_syntax(NillableNode $node)[]: bool {
  if ($node === NIL) {
    return false;
  }

  $node = _Private\cast_away_nil($node);

  switch (node_get_group($node)) {
    case NodeGroup::SYNTAX:
      return true;
    case NodeGroup::TOKEN:
    case NodeGroup::TRIVIUM:
      return false;
  }
}

function is_token(NillableNode $node)[]: bool {
  if ($node === NIL) {
    return false;
  }

  $node = _Private\cast_away_nil($node);

  switch (node_get_group($node)) {
    case NodeGroup::SYNTAX:
      return false;
    case NodeGroup::TOKEN:
      return true;
    case NodeGroup::TRIVIUM:
      return false;
  }
}

function is_trivium(NillableNode $node)[]: bool {
  if ($node === NIL) {
    return false;
  }

  $node = _Private\cast_away_nil($node);

  switch (node_get_group($node)) {
    case NodeGroup::SYNTAX:
    case NodeGroup::TOKEN:
      return false;
    case NodeGroup::TRIVIUM:
      return true;
  }
}

/**
 * The children are returned in source order.
 *
 * For the purposes of this function, NIL and MISSING are treated as a list of
 * length 0. In places where you'd expect to find a zero length list in the AST,
 * for example the parameter list of a function without parameters, you'll find
 * a missing instead. This function "does what you wanted" for "missing" lists.
 *
 * @throws For all other non-list kinds or if the list contains non-list-items.
 */
function list_get_items_of_children(
  Script $script,
  NillableSyntax $node,
)[]: vec<Node> {
  if ($node === NIL) {
    return vec[];
  }

  $node = _Private\cast_away_nil($node);

  switch (node_get_elaborated_group($node)) {
    case NodeElaboratedGroup::LIST:
      break;
    case NodeElaboratedGroup::MISSING:
      return vec[];
    default:
      throw new _Private\PhaException(Str\format(
        '%s expected a list or a missing, got a %s',
        __FUNCTION__,
        node_get_kind($script, $node),
      ));
  }

  return Vec\map(
    node_get_children($script, $node),
    $list_item ==> {
      $kind = node_get_kind($script, $list_item);
      _Private\enforce(
        $kind === KIND_LIST_ITEM,
        '%s expected a list with list_items, but found a %s in the list.',
        __FUNCTION__,
        $kind,
      );

      return node_get_first_childx($script, $list_item);
    },
  );
}

/**
 * Ancestors are returned in opposite source order.
 * So the first node is the parent, the second is the grand parent, etc.
 *
 * Special case: SCRIPT_NODE is its own parent, but this function has to have a
 * termination condition. For this reason, the ancestor chain is terminated at
 * the first instance of SCRIPT_NODE.
 */
function node_get_ancestors(Script $script, NillableNode $node)[]: vec<Node> {
  if ($node === NIL) {
    return vec[];
  }

  $node = _Private\cast_away_nil($node);
  $out = vec[];

  do {
    $node = node_get_parent($script, $node);
    $out[] = $node;
  } while ($node !== SCRIPT_NODE);

  return $out;
}

/**
 * `$node->children[$offset] ?? Pha\NIL`
 * @throws Iff $index < 0.
 */
function node_get_child_at_offset(
  Script $script,
  NillableNode $node,
  int $offset,
)[]: NillableNode {
  if ($offset === 0) {
    return node_get_first_child($script, $node);
  }

  _Private\enforce(
    $offset > 0,
    '%s expected a valid offset (0 or greater), got %d.',
    __FUNCTION__,
    $offset,
  );

  if ($node === NIL) {
    return NIL;
  }

  $node = _Private\cast_away_nil($node);

  $tu = _Private\translation_unit_reveal($script);

  switch (node_get_elaborated_group($node)) {
    case NodeElaboratedGroup::SYNTAX:
    case NodeElaboratedGroup::LIST:
      $child_node = _Private\syntax_from_node($node)
        |> _Private\syntax_get_first_child_sibling_id($$)
        |> _Private\sibling_id_add($$, $offset)
        |> $tu->getNodeBySiblingId($$);

      if ($child_node === NIL) {
        return NIL;
      }

      $child_node = _Private\cast_away_nil($child_node);
      return _Private\node_get_parent_id($child_node) === node_get_id($node)
        ? $child_node
        : NIL;

    case NodeElaboratedGroup::TOKEN:
      $child_node = node_get_id($node)
        |> _Private\node_id_add($$, 1 + $offset)
        |> $tu->getNodeById($$);

      if ($child_node === NIL) {
        return NIL;
      }

      $child_node = _Private\cast_away_nil($child_node);
      return _Private\node_get_parent_id($child_node) === node_get_id($node)
        ? $child_node
        : NIL;

    case NodeElaboratedGroup::TRIVIUM:
    case NodeElaboratedGroup::MISSING:
      return NIL;
  }
}

/**
 * `$node->children[$offset]`
 * @throws Iff $n < 0 or $node has no $nth child.
 */
function node_get_child_at_offsetx(
  Script $script,
  Node $node,
  int $offset,
)[]: Node {
  $child_at_offset = node_get_child_at_offset($script, $node, $offset);

  if ($child_at_offset !== NIL) {
    return _Private\cast_away_nil($child_at_offset);
  }

  throw new _Private\PhaException(Str\format(
    '%s expected more children, the given %s has no child at offset %d (%s child).',
    __FUNCTION__,
    node_get_kind($script, $node),
    $offset,
    _Private\grammatical_nth($offset + 1),
  ));
}

/**
 * Children are returned in source code order.
 */
function node_get_children(Script $script, NillableNode $node)[]: vec<Node> {
  if ($node === NIL) {
    return vec[];
  }

  $node = _Private\cast_away_nil($node);
  $tu = _Private\translation_unit_reveal($script);

  switch (node_get_elaborated_group($node)) {
    case NodeElaboratedGroup::SYNTAX:
      $node = _Private\syntax_from_node($node);
      return $tu->sliceSiblings(
        _Private\syntax_get_first_child_sibling_id($node),
        C\count(syntax_get_members($script, $node)),
      );

    case NodeElaboratedGroup::TOKEN:
      $parent_id = node_get_id($node);
      $child_id = $parent_id;
      $children = vec[];

      for (; ; ) {
        $child_id = _Private\node_id_add($child_id, 1);
        $child = $tu->getNodeById($child_id);
        if ($child === NIL) {
          return $children;
        }

        $child = _Private\cast_away_nil($child);

        if (_Private\node_get_parent_id($child) !== $parent_id) {
          return $children;
        }

        $children[] = $child;
      }

    case NodeElaboratedGroup::LIST:
      $node = _Private\syntax_from_node($node);
      return $tu->sliceSiblings(
        _Private\syntax_get_first_child_sibling_id($node),
        $tu->listGetSize($node),
      );

    case NodeElaboratedGroup::TRIVIUM:
    case NodeElaboratedGroup::MISSING:
      return vec[];
  }
}

function node_get_code(Script $script, NillableNode $node)[]: string {
  if ($node === NIL) {
    return '';
  }

  return node_get_source_range($script, _Private\cast_away_nil($node))
    |> _Private\translation_unit_reveal($script)->cutSourceRange($$);
}

/**
 * Returns the code with all the tokens glued together, (no comments / whitespace).
 *
 * The text returned is not code that can be reparsed.
 * This canonicalizes code by stripping comments and whitespace, but in doing so
 * it removes spaces that were needed for the program to parse:
 * ```
 * return 3; // >> return3;
 * ```
 */
function node_get_code_compressed(
  Script $script,
  NillableNode $node,
)[]: string {
  if ($node === NIL) {
    return '';
  }

  $node = _Private\cast_away_nil($node);

  switch (node_get_group($node)) {
    case NodeGroup::SYNTAX:
      return node_get_descendants($script, $node)
        |> Vec\filter($$, is_token<>)
        |> Vec\map($$, $t ==> token_get_text($script, as_token($t)))
        |> Str\join($$, '');
    case NodeGroup::TOKEN:
      return token_get_text($script, as_token($node));
    case NodeGroup::TRIVIUM:
      $token = trivium_get_parent($script, as_trivium($node));
      return token_get_text_trivium($script, $token) === $node
        ? node_get_code($script, $node)
        : '';
  }
}

function node_get_code_without_leading_or_trailing_trivia(
  Script $script,
  NillableNode $node,
)[]: string {
  if ($node === NIL) {
    return '';
  }

  $node = _Private\cast_away_nil($node);

  $nodes = node_get_descendants($script, $node) ?: vec[$node];
  $first = C\find($nodes, $n ==> node_is_token_text_trivium($script, $n));

  if ($first is null) {
    return '';
  }

  $end =
    _Private\find_lastx($nodes, $n ==> node_is_token_text_trivium($script, $n))
    |> _Private\node_get_next_trivium($script, $$)
    |> $$ !== NIL
      ? _Private\cast_away_nil($$)
        |> _Private\trivium_get_source_byte_offset($$)
      : null;

  return _Private\trivium_from_node($first)
    |> _Private\trivium_get_source_byte_offset($$)
    |> _Private\source_range_hide(tuple($$, $end))
    |> _Private\translation_unit_reveal($script)->cutSourceRange($$);
}

/**
 * Descendants are returned in source order.
 */
function node_get_descendants(Script $script, NillableNode $node)[]: vec<Node> {
  if ($node === NIL) {
    return vec[];
  }

  $node = _Private\cast_away_nil($node);
  $last_descendant = node_get_last_descendant($script, $node);

  if ($last_descendant === NIL) {
    return vec[];
  }

  $last_descendant = _Private\cast_away_nil($last_descendant);
  $start = node_get_first_childx($script, $node) |> node_get_id($$);
  $to_inclusive = node_get_id($last_descendant);

  $tu = _Private\translation_unit_reveal($script);
  return $tu->cutSourceOrder($start, $to_inclusive);
}

function node_get_elaborated_group(Node $node)[]: NodeElaboratedGroup {
  switch (_Private\node_get_field_0($node)) {
    case 0:
      return NodeElaboratedGroup::TRIVIUM;
    case 1:
      return NodeElaboratedGroup::TOKEN;
    case -2:
      return NodeElaboratedGroup::SYNTAX;
    default:
      return _Private\node_get_field_1($node) === 0
        ? NodeElaboratedGroup::MISSING
        : NodeElaboratedGroup::LIST;
  }
}

function node_get_first_child(
  Script $script,
  NillableNode $node,
)[]: NillableNode {
  if ($node === NIL) {
    return NIL;
  }

  $node = _Private\cast_away_nil($node);
  $tu = _Private\translation_unit_reveal($script);

  switch (node_get_elaborated_group($node)) {
    case NodeElaboratedGroup::SYNTAX:
    case NodeElaboratedGroup::TOKEN:
    case NodeElaboratedGroup::LIST:
      return node_get_id($node)
        |> _Private\node_id_add($$, 1)
        |> $tu->getNodeByIdx($$);

    case NodeElaboratedGroup::TRIVIUM:
    case NodeElaboratedGroup::MISSING:
      return NIL;
  }
}

/**
 * @throws Iff $node has no children.
 */
function node_get_first_childx(Script $script, Node $node)[]: Node {
  $first_child = node_get_first_child($script, $node);

  if ($first_child !== NIL) {
    return _Private\cast_away_nil($first_child);
  }

  throw new _Private\PhaException(Str\format(
    '%s expected at least one child, got %s with 0 children.',
    __FUNCTION__,
    node_get_kind($script, $node),
  ));
}

function node_get_group(Node $node)[]: NodeGroup {
  switch (_Private\node_get_field_0($node)) {
    case 0:
      return NodeGroup::TRIVIUM;
    case 1:
      return NodeGroup::TOKEN;
    default:
      return NodeGroup::SYNTAX;
  }
}

function node_get_group_name(NillableNode $node)[]: string {
  if ($node === NIL) {
    return 'NIL';
  }

  switch (node_get_group(_Private\cast_away_nil($node))) {
    case NodeGroup::SYNTAX:
      return 'Syntax';
    case NodeGroup::TOKEN:
      return 'Token';
    case NodeGroup::TRIVIUM:
      return 'Trivium';
  }
}

function node_get_id(Node $node)[]: NodeId {
  return _Private\node_get_id($node);
}

function node_get_kind(Script $script, Node $node)[]: Kind {
  $tu = _Private\translation_unit_reveal($script);

  switch (node_get_elaborated_group($node)) {
    case NodeElaboratedGroup::SYNTAX:
      $kinds = $tu->getParseContext()->getSyntaxKinds();
      return _Private\node_get_interned_kind<SyntaxKind>($node)
        |> $kinds->fromInterned($$);

    case NodeElaboratedGroup::TOKEN:
      $kinds = $tu->getParseContext()->getTokenKinds();
      return _Private\node_get_interned_kind<TokenKind>($node)
        |> $kinds->fromInterned($$);

    case NodeElaboratedGroup::TRIVIUM:
      $kinds = $tu->getParseContext()->getTriviumKinds();
      return _Private\node_get_interned_kind<TriviumKind>($node)
        |> $kinds->fromInterned($$);

    case NodeElaboratedGroup::LIST:
      return KIND_NODE_LIST;
    case NodeElaboratedGroup::MISSING:
      return KIND_MISSING;
  }
}

function node_get_last_child(
  Script $script,
  NillableNode $node,
)[]: NillableNode {
  if ($node === NIL) {
    return NIL;
  }

  $node = _Private\cast_away_nil($node);
  $tu = _Private\translation_unit_reveal($script);

  switch (node_get_elaborated_group($node)) {
    case NodeElaboratedGroup::SYNTAX:
      $node = _Private\syntax_from_node($node);
      return node_get_child_at_offset(
        $script,
        $node,
        C\count(syntax_get_members($script, $node)) - 1,
      );

    case NodeElaboratedGroup::TOKEN:
      $parent_id = node_get_id($node);
      $child_id = $parent_id;
      $last_child = NIL;

      for (; ; ) {
        $child_id = _Private\node_id_add($child_id, 1);
        $child = $tu->getNodeById($child_id);
        if ($child === NIL) {
          return $last_child;
        }

        $child = _Private\cast_away_nil($child);

        if (_Private\node_get_parent_id($child) !== $parent_id) {
          return $last_child;
        }

        $last_child = $child;
      }

    case NodeElaboratedGroup::LIST:
      $node = _Private\syntax_from_node($node);
      return
        node_get_child_at_offset($script, $node, $tu->listGetSize($node) - 1);

    case NodeElaboratedGroup::TRIVIUM:
    case NodeElaboratedGroup::MISSING:
      return NIL;
  }
}

/**
 * @throws Iff $node has no children.
 */
function node_get_last_childx(Script $script, Node $node)[]: Node {
  $last_child = node_get_last_child($script, $node);

  if ($last_child !== NIL) {
    return _Private\cast_away_nil($last_child);
  }

  throw new _Private\PhaException(
    Str\format(
      '%s expected at least one child, got %s without children.',
      __FUNCTION__,
      node_get_kind($script, $node),
    ),
  );
}

function node_get_last_descendant(
  Script $script,
  NillableNode $node,
)[]: NillableNode {
  if ($node === NIL) {
    return NIL;
  }

  $node = _Private\cast_away_nil($node);

  switch (node_get_elaborated_group($node)) {
    case NodeElaboratedGroup::SYNTAX:
    case NodeElaboratedGroup::LIST:
      return node_get_last_childx($script, $node)
        |> node_get_last_descendant_or_self($script, $$);

    case NodeElaboratedGroup::TOKEN:
      return node_get_last_child($script, $node);

    case NodeElaboratedGroup::TRIVIUM:
    case NodeElaboratedGroup::MISSING:
      return NIL;
  }
}

function node_get_last_descendant_or_self(Script $script, Node $node)[]: Node {
  for (; ; ) {
    switch (node_get_elaborated_group($node)) {
      case NodeElaboratedGroup::SYNTAX:
      case NodeElaboratedGroup::LIST:
        $node = node_get_last_childx($script, $node);
        break;

      case NodeElaboratedGroup::TOKEN:
        return node_get_last_childx($script, $node);

      case NodeElaboratedGroup::TRIVIUM:
      case NodeElaboratedGroup::MISSING:
        return $node;
    }
  }
}

function node_get_line_and_column_numbers(
  Script $script,
  Node $node,
)[]: LineAndColumnNumbers {
  return node_get_source_range($script, $node)
    |> source_range_to_line_and_column_numbers($script, $$);
}

/**
 * Huh, shouldn't this return a NillableNode?
 * No, every Node is defined to have a parent.
 * The `SCRIPT_NODE` is defined to have a parent of `SCRIPT_NODE`.
 */
function node_get_parent(Script $script, Node $node)[]: Node {
  $tu = _Private\translation_unit_reveal($script);
  return _Private\node_get_parent_id($node)
    |> $tu->getNodeByIdx($$);
}

/**
 * This number can be used to sort nodes back into the order they came.
 */
function node_get_source_order(Node $node)[]: int {
  return node_get_id($node) |> _Private\node_id_to_int($$);
}

function node_get_source_range(Script $script, Node $node)[]: SourceRange {
  $node = _Private\cast_away_nil($node);

  $start = is_trivium($node)
    ? _Private\trivium_from_node($node)
    : _Private\node_get_next_trivium($script, $node);
  $end = node_get_last_descendant_or_self($script, $node)
    |> _Private\node_get_next_trivium($script, $$);

  if ($start === NIL) {
    // I am unable to imagine a script that has nodes past its last Trivium.
    // My reasoning goes:
    //  1. Every Syntax (except for Missing) has at least one member.
    //  2. Each of these members is either a Syntax or a Token.
    //  3. If the last member is a Syntax, goto 1.
    //  4. You'll now either have a Token or a missing.
    //  5. If you have a Token, it will always have a token-text-trivium.
    //  6. If you have a Missing, and there is no end-of-file token after you,
    //     what kind of mangled input have you given to the parser?
    throw new _Private\PhaException(
      'You have reached code I assumed to be unreachable.',
    );
  }

  $start_offset = _Private\cast_away_nil($start)
    |> _Private\trivium_get_source_byte_offset($$);
  $end_exclusive = $end === NIL
    ? null
    : _Private\trivium_get_source_byte_offset(_Private\cast_away_nil($end));

  return tuple($start_offset, $end_exclusive) |> _Private\source_range_hide($$);
}

/**
 * The ancestors are returned in opposite source order,
 * so parents precede grand parents, grand parents precede great grand parents.
 *
 * The returned ancestors contain only Syntaxes, any ancestors that are not
 * Syntaxes are skipped.
 *
 * @see `node_get_ancestors` for the special handling of SCRIPT_NODE.
 */
function node_get_syntax_ancestors(
  Script $script,
  NillableNode $node,
)[]: vec<Syntax> {
  if ($node === NIL) {
    return vec[];
  }

  $node = _Private\cast_away_nil($node);

  do {
    $node = node_get_parent($script, $node);
  } while (!is_syntax($node));

  $node = _Private\syntax_from_node($node);

  $out = vec[];
  $out[] = $node;

  while ($node !== SCRIPT_NODE) {
    $node = syntax_get_parent($script, $node);
    $out[] = $node;
  }

  return $out;
}

function node_is_token_text_trivium(
  Script $script,
  NillableNode $node,
)[]: bool {
  if (!is_trivium($node)) {
    return false;
  }

  return _Private\cast_away_nil($node)
    |> node_get_parent($script, $$)
    |> _Private\token_from_node($$)
    |> token_get_text_trivium($script, $$) === $node;
}

function patch_node(
  Node $node,
  string $replacement,
  shape(?'trivia' => RetainTrivia /*_*/) $options = shape(),
)[]: Patch {
  return new _Private\PatchNode(
    $node,
    $replacement,
    $options['trivia'] ?? RetainTrivia::NEITHER,
  )
    |> _Private\patch_node_hide($$);
}

/**
 * @throws If any Replacement in `$patches` overlaps with any other Replacement.
 */
function patches(Script $script, Patch ...$patches)[]: Patches {
  return Vec\map(
    $patches,
    $p ==> _Private\patch_node_reveal($p)->toReplacement($script),
  )
    |> new _Private\PatchSet(node_get_code($script, SCRIPT_NODE), $$)
    |> _Private\patch_set_hide($$);
}

function patches_apply(Patches $patches)[]: string {
  return _Private\patch_set_reveal($patches)->apply();
}

/**
 * This API will become an alias for `patches_combine($patches, $throw_on_conflict)`
 * where `$throw_on_conflict` is an argument that allows you to specify
 * a conflict resolution strategy.
 * For now, this was just easy to implement and it fulfills the basic need.
 *
 * @throws If any Replacement in `$patches` overlaps with any other Replacement.
 * @throws If `$patches` is empty.
 * @throws If any Patches in `$patches` was generated with a different source text.
 */
function patches_combine_without_conflict_resolution(
  vec<Patches> $patches,
)[]: Patches {
  _Private\enforce(
    !C\is_empty($patches),
    '%s expected Patches, but none were provided.',
    __FUNCTION__,
  );

  $first = C\firstx($patches) |> _Private\patch_set_reveal($$);

  $function_name = __FUNCTION__;

  return Vec\map($patches, $p ==> {
    $p = _Private\patch_set_reveal($p);

    _Private\enforce(
      $first->cayBeCombinedWith($p),
      '%s expected that all Patches could be combined, '.
      'but one of the Patches was created for a different Script.',
      $function_name,
    );

    return $p->getReplacements();
  })
    |> Vec\flatten($$)
    |> new _Private\PatchSet($first->getBeforeText(), $$)
    |> _Private\patch_set_hide($$);
}

/**
 * Integrate a cast on the return value into the callable.
 * Commonly used in combination with `create_member_accessor`. 
 * @example
 * ```
 * $get_function_name =
 *   Pha\create_member_accessor($script, Pha\MEMBER_FUNCTION_CALL_ARGUMENT_LIST)
 *   |> returns_syntax($$);
 * ```
 * hackfmt-ignore
 */
function returns_syntax<T>(
  (function(T)[]: NillableNode) $func,
)[]: (function(T)[]: Syntax) {
  return $x ==> $func($x) |> as_syntax($$);
}

/**
 * Integrate a cast on the return value into the callable.
 * Commonly used in combination with `create_member_accessor`. 
 * @example
 * ```
 * $get_binop_operator =
 *   Pha\create_member_accessor($script, Pha\MEMBER_BINARY_OPERATOR)
 *   |> returns_token($$);
 * ```
 * hackfmt-ignore
 */
function returns_token<T>(
  (function(T)[]: NillableNode) $func,
)[]: (function(T)[]: Token) {
  return $x ==> $func($x) |> as_token($$);
}

function script_get_syntaxes(Script $script)[]: vec<Syntax> {
  $tu = _Private\translation_unit_reveal($script);
  return $tu->getSourceOrder()
    |> Vec\filter($$, is_syntax<>)
    |> _Private\syntaxes_from_nodes($$);
}

function script_get_syntaxes_without_missing_and_list(
  Script $script,
)[]: vec<Syntax> {
  $tu = _Private\translation_unit_reveal($script);
  return $tu->getSourceOrder()
    |> Vec\filter(
      $$,
      $n ==> node_get_elaborated_group($n) === NodeElaboratedGroup::SYNTAX,
    )
    |> _Private\syntaxes_from_nodes($$);

}

function script_get_tokens(Script $script)[]: vec<Token> {
  $tu = _Private\translation_unit_reveal($script);
  return $tu->getSourceOrder()
    |> Vec\filter($$, is_token<>)
    |> _Private\tokens_from_nodes($$);
}

function script_get_trivia(Script $script)[]: vec<Trivium> {
  $tu = _Private\translation_unit_reveal($script);
  return $tu->getSourceOrder()
    |> Vec\filter($$, is_trivium<>)
    |> _Private\trivia_from_nodes($$);
}

function source_range_format(SourceRange $source_range)[]: string {
  list($start, $end) = _Private\source_range_reveal($source_range)
    |> tuple(
      _Private\source_byte_offset_to_int($$[0]),
      $$ is (mixed, nonnull) ? _Private\source_byte_offset_to_int($$[1]) : null,
    );

  return $end is null ? '['.$start.', '.'...]' : '['.$start.', '.$end.']';
}

function source_range_overlaps(SourceRange $a, SourceRange $b)[]: bool {
  $a = _Private\source_range_reveal($a);
  $b = _Private\source_range_reveal($b);

  if (_Private\source_byte_offset_is_less_than($b[0], $a[0])) {
    $tmp = $a;
    $a = $b;
    $b = $tmp;
  }

  $a_end = $a[1];

  return
    $a_end is null || _Private\source_byte_offset_is_less_than($b[0], $a_end);
}

function source_range_to_line_and_column_numbers(
  Script $script,
  SourceRange $range,
)[]: LineAndColumnNumbers {
  $breaks = _Private\translation_unit_reveal($script)->getLineBreaks();

  list($start, $end_exclusive) = _Private\source_range_reveal($range);
  $end_exclusive ??= C\lastx($breaks);

  $count = C\count($breaks);
  $i = $count - 1;

  while (_Private\source_byte_offset_is_less_than($start, $breaks[$i])) {
    // Quickly find a good place to start looking.
    $i = Math\maxva(0, $i - _Private\TranslationUnit::SOME_LARGE_JUMP);
  }

  while (
    $i < $count &&
    _Private\source_byte_offset_is_less_than_or_equal($breaks[$i], $start)
  ) {
    ++$i;
  }

  $start_line = Math\maxva(0, $i - 1);
  $start_column = _Private\source_byte_offset_to_int($start) -
    _Private\source_byte_offset_to_int($breaks[$start_line]);

  while (
    $i < $count &&
    _Private\source_byte_offset_is_less_than_or_equal(
      $breaks[$i],
      $end_exclusive,
    )
  ) {
    ++$i;
  }

  $end_line = Math\maxva(0, $i - 1);
  $end_column = _Private\source_byte_offset_to_int($end_exclusive) -
    _Private\source_byte_offset_to_int($breaks[$end_line]);

  return new LineAndColumnNumbers(
    $start_line,
    $start_column,
    $end_line,
    $end_column,
  );
}

/**
 * Member names are returned in source code order.
 */
function syntax_get_members(Script $script, Syntax $node)[]: vec<Member> {
  $tu = _Private\translation_unit_reveal($script);
  $structs = $tu->getParseContext()->getStructs();
  $kind = node_get_kind($script, $node) |> syntax_kind_from_kind($$);
  // This default is needed for List and Missing.
  // They don't get "learned" in the same way any other syntax would.
  return $structs->getRaw()[$kind] ?? vec[];
}

function syntax_get_parent(Script $script, Syntax $node)[]: Syntax {
  return node_get_parent($script, $node) |> _Private\syntax_from_node($$);
}

/**
 * @see `create_member_accessor`, which is preferred over this function.
 *      `syntax_member` rediscovers offsets with each invocation.
 *      `create_member_accessor` precomputes offsets string comparisons.
 */
function syntax_member(Script $script, Syntax $node, Member $member)[]: Node {
  $ii = 0;

  foreach (syntax_get_members($script, $node) as $m) {
    if ($m === $member) {
      return node_get_child_at_offsetx($script, $node, $ii);
    }

    ++$ii;
  }

  throw new _Private\PhaException(Str\format(
    'Expected a %s to get member %s, but got %s.',
    member_get_syntax_kind($member),
    member_get_name($member),
    node_get_kind($script, $node),
  ));
}

function token_get_parent(Script $script, Token $node)[]: Syntax {
  return node_get_parent($script, $node) |> _Private\syntax_from_node($$);
}

function token_get_text(Script $script, NillableToken $node)[]: string {
  if ($node === NIL) {
    return '';
  }

  return _Private\cast_away_nil($node)
    |> token_get_text_trivium($script, $$)
    |> node_get_code($script, $$);
}

function token_get_text_trivium(Script $script, Token $node)[]: Trivium {
  $tu = _Private\translation_unit_reveal($script);
  return _Private\node_get_field_3($node)
    |> _Private\node_id_from_int($$)
    |> $tu->getNodeByIdx($$)
    |> _Private\trivium_from_node($$);
}

function trivium_get_parent(Script $script, Trivium $node)[]: Token {
  return node_get_parent($script, $node) |> _Private\token_from_node($$);
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/parse.hack /////
namespace HTL\Pha {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


use namespace HH;

function parse(string $source, Context $ctx)[]: (Script, Context) {
  $ffp_parsed = HH\ffp_parse_string($source) as dict<_, _>;
  $parse_tree = $ffp_parsed['parse_tree'] as dict<_, _>;
  return parse_from_tree($parse_tree, $source, $ctx);
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/parse_from_tree.hack /////
namespace HTL\Pha {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


/**
 * @param $parse_tree ought to be the `$ffp_parsed['parse_tree']` of a script.
 * @see `\HH\ffp_parse_string()` and `\HH\ffp_parse_string_native()`.
 */
function parse_from_tree(
  dict<arraykey, mixed> $parse_tree,
  string $source_text,
  Context $ctx,
)[]: (Script, Context) {
  $ctx = _Private\context_reveal($ctx);
  $structs = $ctx->getStructs();
  $member_names = $structs->getRaw();
  $known_token_kinds = $ctx->getTokenKinds()->asKeyset();
  $known_trivium_kinds = $ctx->getTriviumKinds()->asKeyset();

  $intermediates = _Private\create_intermediates(
    $parse_tree,
    inout $member_names,
    inout $known_token_kinds,
    inout $known_trivium_kinds,
  );

  $ctx = $ctx->upgradeIfNeeded(
    $member_names,
    $known_token_kinds,
    $known_trivium_kinds,
  );

  $tu = _Private\create_translation_unit($intermediates, $source_text, $ctx);

  return
    tuple(_Private\translation_unit_hide($tu), _Private\context_hide($ctx));
}
}
///// vendor/hershel-theodore-layton/portable-hack-ast/src/public_types.hack /////
namespace HTL\Pha {
/** portable-hack-ast is MIT licensed, see /LICENSE. */


type Context = _Private\Context;
type NillableNode = _Private\NillableNode;
type NillableSyntax = _Private\NillableSyntax;
type NillableToken = _Private\NillableToken;
type NillableTrivium = _Private\NillableTrivium;
type Node = _Private\Node;
type NodeId = _Private\NodeId;
type Patch = _Private\Patch;
type Patches = _Private\Patches;
type Script = _Private\Script;
type ReadyToSerializeContext = _Private\ReadyToSerializeContext;
type ReadyToSerializeScript = _Private\ReadyToSerializeScript;
type SourceRange = _Private\SourceRange;
type Syntax = _Private\Syntax;
type SyntaxIndex = _Private\KindIndex<Syntax, SyntaxKind>;
type Token = _Private\Token;
type TokenIndex = _Private\KindIndex<Token, TokenKind>;
type Trivium = _Private\Trivium;
type TriviumIndex = _Private\KindIndex<Trivium, TriviumKind>;

const _Private\Syntax SCRIPT_NODE = _Private\SCRIPT_NODE;
const NillableSyntax NIL = _Private\NIL;
const NillableSyntax NIL_SYNTAX = _Private\NIL_SYNTAX;
const NillableToken NIL_TOKEN = _Private\NIL_TOKEN;
const NillableTrivium NIL_TRIVIUM = _Private\NIL_TRIVIUM;
}
///// vendor/hershel-theodore-layton/pragma/src/pragma.hack /////
namespace HTL\Pragma {
/** pragma is MIT licensed, see /LICENSE. */


/**
 * @package The `pragma(...)` directive and `<<Pragmas(...)>>`
 * attribute are a more structured way to communicate with source analyzers.
 * The typechecker looks for hh_fixme and hh_ignore_error directives.
 * HHAST looks for hhast_ignore_error, hhast_ignore_all, and hhast_fixme directives.
 *
 * I don't like the state of things, because nothings checks the comments.
 * It is unclear if a comment is a directive for something, a normal comment,
 * or worst of all, a dangling directive that is silently misinforming you.
 *
 * I am not going to change the typechecker to stop using comment for suppressions,
 * but userspace libraries are welcome to adopt this informal standard.
 *
 * There are two ways to invoke a pragma.
 *  - The `pragma('example_lib', 'strict_mode=1')` directive.
 *  - The `<<Pragmas(vec['one', 'ok=1'], vec['two', 'ok=false'])>>` attribute.
 *
 * The pragma directive accepts any number of arguments.
 * The 1st addresses a library, and the 2nd to last are implementation defined.
 * These take effect for the lines they are on and the next line.
 *
 * The attribute takes any number of vecs, each of which is a directive.
 * The scope is from attribute to closing curly brace if atop a class.
 * A file attribute `<<file: Pragmas(...)>>` affects the entire file.
 *
 * A library that uses pragma's is required to emit a diagnostic for pragmas
 * that start with the library name and that can not be parsed or are invalid.
 * This prevents broken directive and attributes from hanging around.
 *
 * You must use a canonical use statement for the pragma directive and attribute.
 * Using a Pragma namespace and using qualfied names is not allowed.
 * `use namespace HTL\Pragma; ... Pragma\pragma(...) ... <<Pragma\Pragmas(...)>>`
 * Using `use function HTL\Pragma\pragma as not_pragma` is also not allowed.
 *
 * A PragmaMap is included in `hershel-theodore-layton/portable-hack-ast-extras`.
 * A checker for aimless pragmas (where the library is not known) is included in
 * `hershel-theodore-layton/portable-hack-ast-linters`.
 */
use namespace HH;

/**
 * @param ...$_args[0] The name of the library you are targeting.
 * @param ...$_args[1..] Arguments passed to the library.
 */
function pragma(string ...$_args)[]: void {}

/**
 * Apply a set of pragmas to an entire scope.
 * Each `vec[]` is parsed as its own `pragma(...)` directive.
 */
final class Pragmas
  implements
    HH\ClassAttribute,
    HH\EnumAttribute,
    HH\EnumClassAttribute,
    HH\FunctionAttribute,
    HH\MethodAttribute,
    HH\FileAttribute {
  public vec<vec<string>> $values;

  public function __construct(vec<string> ...$values)[] {
    $this->values = vec($values);
  }
}
}