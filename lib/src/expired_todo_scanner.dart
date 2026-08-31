/// File-system scanner used by the command-line interface.
library;

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/file_system/physical_file_system.dart';

import 'condition_evaluator.dart';
import 'expiry_condition.dart';
import 'project_context_loader.dart';
import 'todo_parser.dart';

/// An expired TODO and the source excerpt that starts on its line.
final class ExpiredTodoFinding {
  const ExpiredTodoFinding({
    required this.path,
    required this.line,
    required this.excerpt,
  });

  final String path;
  final int line;
  final String excerpt;
}

/// Finds expired TODO comments in [files].
///
/// A TODO is returned once even when more than one of its conditions is met.
List<ExpiredTodoFinding> scanExpiredTodos(
  Iterable<File> files, {
  DateTime? today,
  ProjectContextLoader? loader,
  int excerptLineCount = 1,
}) {
  if (excerptLineCount < 1) {
    throw ArgumentError.value(
      excerptLineCount,
      'excerptLineCount',
      'must be a positive integer',
    );
  }
  final currentDate = today ?? DateTime.now();
  final effectiveToday = DateTime(
    currentDate.year,
    currentDate.month,
    currentDate.day,
  );
  final contextLoader = loader ?? ProjectContextLoader();
  final resourceProvider = PhysicalResourceProvider.INSTANCE;
  final findings = <ExpiredTodoFinding>[];

  for (final file in files) {
    final absoluteFile = file.absolute;
    final content = absoluteFile.readAsStringSync();
    final result = parseString(
      content: content,
      path: absoluteFile.path,
      throwIfDiagnostics: false,
    );
    final projectContext = contextLoader.loadForFile(
      resourceProvider.getFile(absoluteFile.path),
    );

    Token? token = result.unit.beginToken;
    while (token != null) {
      Token? comment = token.precedingComments;
      while (comment != null) {
        if (_isExpired(comment.lexeme, projectContext, effectiveToday)) {
          final location = result.lineInfo.getLocation(comment.offset);
          findings.add(
            ExpiredTodoFinding(
              path: absoluteFile.path,
              line: location.lineNumber,
              excerpt: _linesAt(content, location.lineNumber, excerptLineCount),
            ),
          );
        }
        comment = comment.next;
      }
      if (token == token.next) break;
      token = token.next;
    }
  }

  return findings;
}

bool _isExpired(
  String comment,
  ProjectContext? projectContext,
  DateTime today,
) {
  final parsed = parseTodo(comment);
  if (parsed is! ValidTodo) return false;

  for (final condition in parsed.conditions) {
    if (projectContext == null && condition is! DateCondition) continue;
    final outcome = evaluateCondition(
      condition,
      projectContext ?? const ProjectContext(),
      today,
    );
    if (outcome is ConditionMet) return true;
  }
  return false;
}

String _linesAt(String content, int lineNumber, int lineCount) {
  final lines = const LineSplitter().convert(content);
  final end = (lineNumber - 1 + lineCount).clamp(0, lines.length);
  return lines
      .sublist(lineNumber - 1, end)
      .map((line) => line.trimLeft())
      .join('\n');
}
