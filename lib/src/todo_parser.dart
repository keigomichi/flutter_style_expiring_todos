/// Parsing of TODO comments, shared by the `flutter_style_expiring_todos`
/// and `expired_todo` rules.
///
/// This library is pure Dart with no analyzer dependency so that it can be
/// unit-tested directly against comment lexeme strings.
///
/// The recognized grammar is a superset of the official `flutter_style_todos`
/// lint (dart-lang/sdk @ c6444fd86f62, pkg/linter/lib/src/rules/
/// flutter_style_todos.dart):
///
/// * Official form:  `// TODO(username): message`
/// * Extended form:  `// TODO(username)[condition, ...]: message`
///
/// Extended-form condition parsing is delegated to `condition_parser.dart`.
library;

import 'condition_parser.dart';
import 'expiry_condition.dart';

/// The result of parsing a single comment lexeme.
sealed class TodoParseResult {
  const TodoParseResult();
}

/// A TODO comment in either the official (unconditional) or extended
/// (conditional) form.
final class ValidTodo extends TodoParseResult {
  const ValidTodo({
    required this.username,
    required this.message,
    this.url,
    this.conditions = const [],
  });

  final String username;

  /// The message with any trailing `, <url>` segment stripped.
  final String message;

  /// A trailing `http(s)://` link, if present.
  final String? url;

  /// The parsed contents of the `[...]` segment, empty for the official
  /// (unconditional) form.
  final List<ExpiryCondition> conditions;
}

/// A comment that claims to be a TODO but matches neither accepted form.
final class MalformedTodo extends TodoParseResult {
  const MalformedTodo(this.reason);

  final MalformedTodoReason reason;
}

/// A comment that does not look like a TODO at all.
final class NotTodo extends TodoParseResult {
  const NotTodo();
}

enum MalformedTodoReason {
  /// Looks like a TODO but matches neither the official nor the extended form.
  badFormat,

  /// Matches the extended shape but the date does not exist on the calendar
  /// (e.g. `2026/02/30`).
  invalidCalendarDate,

  /// The `[...]` segment contains an unrecognized condition.
  invalidCondition,

  /// The `[...]` segment contains two conditions of a type that must be
  /// unique (multiple dates, or multiple project-version conditions).
  duplicateCondition,
}

// Verbatim from the official flutter_style_todos rule. Only matches `//`
// comments, so block comments never trigger the format check — this must be
// preserved for compatibility.
final RegExp _lineTrigger = RegExp(r'//+\s*TODO\b', caseSensitive: false);

final RegExp _blockTrigger = RegExp(r'/\*+\s*TODO\b', caseSensitive: false);

const String _username = r'([a-zA-Z0-9][-a-zA-Z0-9\.]*)';
// Condition contents are captured opaquely and handed to condition_parser.
// A `]` inside the segment isn't allowed by any condition form, so `[^\]\n]`
// is safe as an outer boundary.
const String _conditions = r'([^\]\n]+)';

// The official expected form is r'//\s*TODO\([a-zA-Z0-9][-a-zA-Z0-9\.]*\): '.
// Adding the `(.*)` message capture does not change what is accepted: the
// mandatory space after `):` is kept and `(.*)` matches the empty string.
// The extended form places conditions in square brackets immediately after
// `)`, with no spaces around the brackets.
final RegExp _lineOfficial = RegExp('//\\s*TODO\\($_username\\): (.*)');
final RegExp _lineExtended = RegExp(
  '//\\s*TODO\\($_username\\)\\[$_conditions\\]: (.*)',
);
final RegExp _blockOfficial = RegExp('/\\*+\\s*TODO\\($_username\\): (.*)');
final RegExp _blockExtended = RegExp(
  '/\\*+\\s*TODO\\($_username\\)\\[$_conditions\\]: (.*)',
);

final RegExp _trailingUrl = RegExp(r',\s*(https?://\S+)\s*$');

/// Whether [content] triggers the official `flutter_style_todos` TODO
/// detector. Never true for block comments.
bool isTodoTrigger(String content) => content.startsWith(_lineTrigger);

/// Whether the format rule should report [content].
///
/// Matches the official rule's `invalidTodo` semantics, except that the
/// extended form (with valid conditions) is additionally accepted.
bool invalidTodo(String content) =>
    isTodoTrigger(content) && parseTodo(content) is! ValidTodo;

/// Parses a raw comment lexeme (line, doc, or block comment).
///
/// Only a TODO at the very start of the comment is recognized, mirroring the
/// official rule's anchored matching.
TodoParseResult parseTodo(String content) {
  if (content.startsWith('/*')) {
    return _parse(
      content,
      trigger: _blockTrigger,
      extended: _blockExtended,
      official: _blockOfficial,
      isBlock: true,
    );
  }
  return _parse(
    content,
    trigger: _lineTrigger,
    extended: _lineExtended,
    official: _lineOfficial,
    isBlock: false,
  );
}

TodoParseResult _parse(
  String content, {
  required RegExp trigger,
  required RegExp extended,
  required RegExp official,
  required bool isBlock,
}) {
  // The extended form is tried first: an extended comment also fails the
  // official regex (the `[` after `)` breaks the required `): ` sequence),
  // and matching the shape first keeps condition-level errors reachable.
  var match = extended.matchAsPrefix(content);
  if (match != null) {
    var parseResult = parseConditions(match.group(2)!);
    switch (parseResult) {
      case ConditionsMalformed(:final error):
        return MalformedTodo(_reasonFor(error));
      case ConditionsOk(:final conditions):
        return _validTodo(
          match.group(1)!,
          match.group(3)!,
          isBlock: isBlock,
          conditions: conditions,
        );
    }
  }
  match = official.matchAsPrefix(content);
  if (match != null) {
    return _validTodo(match.group(1)!, match.group(2)!, isBlock: isBlock);
  }
  if (content.startsWith(trigger)) {
    return const MalformedTodo(MalformedTodoReason.badFormat);
  }
  return const NotTodo();
}

MalformedTodoReason _reasonFor(ConditionParseError error) => switch (error) {
  ConditionParseError.invalidCondition => MalformedTodoReason.invalidCondition,
  ConditionParseError.invalidCalendarDate =>
    MalformedTodoReason.invalidCalendarDate,
  ConditionParseError.duplicateDate => MalformedTodoReason.duplicateCondition,
  ConditionParseError.duplicateProjectVersion =>
    MalformedTodoReason.duplicateCondition,
};

ValidTodo _validTodo(
  String username,
  String rawMessage, {
  required bool isBlock,
  List<ExpiryCondition> conditions = const [],
}) {
  // The message capture stops at the first newline, so for a single-line
  // block comment it still carries the closing `*/`; a multi-line one may
  // carry a trailing `\r` under CRLF line endings.
  var message = rawMessage;
  if (isBlock) {
    var end = message.lastIndexOf('*/');
    if (end >= 0) message = message.substring(0, end);
  }
  message = message.trimRight();

  var urlMatch = _trailingUrl.firstMatch(message);
  if (urlMatch == null) {
    return ValidTodo(
      username: username,
      message: message,
      conditions: conditions,
    );
  }
  return ValidTodo(
    username: username,
    message: message.substring(0, urlMatch.start).trimRight(),
    url: urlMatch.group(1),
    conditions: conditions,
  );
}
