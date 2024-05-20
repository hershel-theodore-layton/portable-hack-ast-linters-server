/** portable-hack-ast-linters-monolithic-checker is MIT licensed, see /LICENSE. */
namespace HTL\PortableHackAstLintersMonolithicChecker;

use namespace HTL\PhaLinters;

function all_linters(string $license_header)[]: vec<LintFunction> {
  $known_pragma_prefixes = keyset['PhaLinters'];

  $linters = vec[
    PhaLinters\async_function_and_method_linter<>,
    PhaLinters\camel_cased_methods_underscored_functions_linter<>,
    PhaLinters\concat_merge_or_union_expression_can_be_simplified_linter<>,
    PhaLinters\count_expression_can_be_simplified_linter<>,
    PhaLinters\dont_await_in_a_loop_linter<>,
    PhaLinters\dont_create_forwarding_lambdas_linter<>,
    PhaLinters\dont_discard_new_expressions_linter<>,
    PhaLinters\dont_use_asio_join_linter<>,
    PhaLinters\final_or_abstract_classes_linter<>,
    PhaLinters\getter_method_could_have_a_context_list_linter<>,
    PhaLinters\group_use_statement_alphabetization_linter<>,
    PhaLinters\group_use_statements_linter<>,
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

  return $linters;
}
