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

/// Reports TODO comments whose expiry condition has been met.
///
/// The date condition (`[YYYY/MM/DD]`) fires the day after the date passes
/// (day granularity, local time). Version conditions (`[>=1.0.0]`,
/// `[provider@>=6.0.0]`, `[sdk@>=3.10.0]`, `[flutter@>=3.38.0]`) fire when
/// the referenced version satisfies the comparison. When a TODO carries
/// multiple conditions, each met condition produces its own diagnostic.
class ExpiredTodo extends MultiAnalysisRule {
  /// Fires when a date condition's due date is in the past.
  static const LintCode expiredCode = LintCode(
    'expired_todo',
    'TODO expired on {0}.',
    correctionMessage: 'Try resolving the TODO, or updating its due date.',
  );

  /// Fires when a version condition has been reached.
  static const LintCode expiredVersionCode = LintCode(
    'expired_todo_version',
    "TODO version condition '{0}' is met: {1}.",
    correctionMessage:
        'Try resolving the TODO, or updating its version condition.',
  );

  ExpiredTodo({
    DateTime Function() now = DateTime.now,
    ProjectContextLoader? loader,
  }) : _now = now,
       _loader = loader ?? ProjectContextLoader(),
       super(
         name: 'expired_todo',
         description:
             'TODO comments with an expiry condition must be resolved '
             'before the condition is met.',
       );

  final DateTime Function() _now;
  final ProjectContextLoader _loader;

  @override
  List<DiagnosticCode> get diagnosticCodes => [expiredCode, expiredVersionCode];

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    var packageRoot = context.package?.root;
    ProjectContext? projectContext;
    if (packageRoot != null) {
      projectContext = _loader.loadForPackage(packageRoot);
    } else {
      projectContext = _loader.loadForFile(context.definingUnit.file);
    }
    registry.addCompilationUnit(this, _Visitor(this, projectContext));
  }
}

class _Visitor extends TodoCommentVisitor {
  _Visitor(this.rule, this.projectContext);

  final ExpiredTodo rule;

  /// `null` when the file is not inside any pub package — in that case
  /// version conditions are silently skipped (see class doc).
  final ProjectContext? projectContext;

  @override
  void checkComment(Token comment) {
    if (parseTodo(comment.lexeme) case ValidTodo(
      :final conditions,
    ) when conditions.isNotEmpty) {
      var now = rule._now();
      var today = DateTime(now.year, now.month, now.day);
      for (var condition in conditions) {
        // Version conditions require a ProjectContext; without one we can't
        // evaluate them, and we leave `unresolved_todo_condition` silent too
        // (out-of-package files aren't meant to be checked).
        if (projectContext == null && condition is! DateCondition) continue;
        var outcome = evaluateCondition(
          condition,
          projectContext ?? const ProjectContext(),
          today,
        );
        if (outcome is ConditionMet) {
          var code = condition is DateCondition
              ? ExpiredTodo.expiredCode
              : ExpiredTodo.expiredVersionCode;
          var args = condition is DateCondition
              ? [_formatDate(condition.date)]
              : [condition.raw, outcome.detail];
          rule.reportAtToken(comment, diagnosticCode: code, arguments: args);
        }
      }
    }
  }

  static String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.day.toString().padLeft(2, '0')}';
}
