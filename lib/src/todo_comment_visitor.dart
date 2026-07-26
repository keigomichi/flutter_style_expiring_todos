import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Walks every comment token in a compilation unit, mirroring the token walk
/// of the official `flutter_style_todos` rule.
abstract class TodoCommentVisitor extends SimpleAstVisitor<void> {
  @override
  void visitCompilationUnit(CompilationUnit node) {
    Token? token = node.beginToken;
    while (token != null) {
      // Comments are processed before the EOF break: the EOF token's
      // precedingComments hold any comments at the end of the file.
      Token? comment = token.precedingComments;
      while (comment != null) {
        checkComment(comment);
        comment = comment.next;
      }
      if (token == token.next) break; // The EOF token points at itself.
      token = token.next;
    }
  }

  void checkComment(Token comment);
}
