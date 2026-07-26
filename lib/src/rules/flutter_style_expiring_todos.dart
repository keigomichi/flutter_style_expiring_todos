import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/error.dart';

import '../todo_comment_visitor.dart';
import '../todo_parser.dart';

/// Enforces the Flutter TODO format, additionally accepting one or more
/// expiry conditions in brackets:
/// `// TODO(username): message` or
/// `// TODO(username)[condition, ...]: message`.
class FlutterStyleExpiringTodos extends AnalysisRule {
  static const LintCode code = LintCode(
    'flutter_style_expiring_todos',
    "TODO comment doesn't follow the expected format.",
    correctionMessage:
        "Try using '// TODO(username): message' or "
        "'// TODO(username)[condition, ...]: message'.",
  );

  FlutterStyleExpiringTodos()
    : super(
        name: 'flutter_style_expiring_todos',
        description:
            'Use Flutter-style TODO comments: '
            "'// TODO(username): message' or "
            "'// TODO(username)[condition, ...]: message'.",
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addCompilationUnit(this, _Visitor(this));
  }
}

class _Visitor extends TodoCommentVisitor {
  _Visitor(this.rule);

  final FlutterStyleExpiringTodos rule;

  @override
  void checkComment(Token comment) {
    if (invalidTodo(comment.lexeme)) {
      rule.reportAtToken(comment);
    }
  }
}
