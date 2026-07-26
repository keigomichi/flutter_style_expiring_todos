import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/error.dart';

import '../condition_evaluator.dart';
import '../expiry_condition.dart';
import '../project_context_loader.dart';
import '../todo_comment_visitor.dart';
import '../todo_parser.dart';

/// Reports TODO comments whose expiry condition references something that
/// cannot be resolved (e.g. a dependency missing from `pubspec.lock`, an
/// unbounded `environment.sdk` range, a `pubspec.yaml` without a `version`).
///
/// Complements `expired_todo`: `expired_todo` only fires when a condition is
/// definitively **met**, so silent unresolved conditions would go unnoticed
/// without this rule.
class UnresolvedTodoCondition extends AnalysisRule {
  static const LintCode code = LintCode(
    'unresolved_todo_condition',
    "TODO condition '{0}' cannot be evaluated: {1}.",
    correctionMessage:
        'Ensure the referenced version is declared, or remove the '
        'condition.',
  );

  UnresolvedTodoCondition({ProjectContextLoader? loader})
    : _loader = loader ?? ProjectContextLoader(),
      super(
        name: 'unresolved_todo_condition',
        description:
            'TODO expiry conditions must reference values that can be '
            'resolved from pubspec.yaml or pubspec.lock.',
      );

  final ProjectContextLoader _loader;

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    var packageRoot = context.package?.root;
    var projectContext = packageRoot != null
        ? _loader.loadForPackage(packageRoot)
        : _loader.loadForFile(context.definingUnit.file);
    registry.addCompilationUnit(this, _Visitor(this, projectContext));
  }
}

class _Visitor extends TodoCommentVisitor {
  _Visitor(this.rule, this.projectContext);

  final UnresolvedTodoCondition rule;
  final ProjectContext? projectContext;

  @override
  void checkComment(Token comment) {
    if (projectContext == null) return;
    if (parseTodo(comment.lexeme) case ValidTodo(
      :final conditions,
    ) when conditions.isNotEmpty) {
      for (var condition in conditions) {
        // Date conditions never go unresolved — they're evaluated against
        // the clock, which is always available.
        if (condition is DateCondition) continue;
        var outcome = evaluateVersionCondition(condition, projectContext!);
        if (outcome is ConditionUnresolved) {
          rule.reportAtToken(
            comment,
            arguments: [condition.raw, outcome.reason],
          );
        }
      }
    }
  }
}
