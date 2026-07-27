import 'package:analyzer/src/dart/error/todo_codes.dart'
    as analyzer_todo; // ignore: implementation_imports
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:analyzer_testing/src/analysis_rule/pub_package_resolution.dart'
    show
        ExpectedDiagnostic,
        ExpectedError; // ignore: implementation_imports

/// The analyzer's built-in diagnostic code for a standard TODO comment.
///
/// Its generated declaration moved between analyzer 9 and 14, while
/// [analyzer_todo.Todo.forKind] is available in both versions.
final todo = analyzer_todo.Todo.forKind('TODO');

/// A rule-test base that ignores the analyzer's own TODO diagnostics.
///
/// Analyzer 9 omits these diagnostics from resolved-unit results, while newer
/// analyzers include them. They are unrelated to the plugin diagnostics under
/// test, so filtering them keeps the same assertions meaningful across both.
abstract class AnalysisRuleTestWithoutTodo extends AnalysisRuleTest {
  @override
  get ignoredDiagnosticCodes => [...super.ignoredDiagnosticCodes, todo];

  @override
  Future<void> assertDiagnostics(
    String content,
    List<ExpectedDiagnostic> expectedDiagnostics,
  ) {
    return super.assertDiagnostics(
      content,
      expectedDiagnostics.where((expected) {
        return expected is! ExpectedError || expected.code != todo;
      }).toList(),
    );
  }
}
