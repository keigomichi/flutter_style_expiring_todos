/// Parses the `[...]` segment of an extended TODO comment into a list of
/// [ExpiryCondition]s. Pure Dart — no analyzer or IO dependency, so it can be
/// exhaustively unit-tested against raw strings.
library;

import 'package:pub_semver/pub_semver.dart';

import 'expiry_condition.dart';

/// The result of parsing one bracket segment.
sealed class ConditionParseResult {
  const ConditionParseResult();
}

/// Success: an ordered, deduplicated-safe list of conditions.
final class ConditionsOk extends ConditionParseResult {
  const ConditionsOk(this.conditions);
  final List<ExpiryCondition> conditions;
}

/// Failure with a reason.
final class ConditionsMalformed extends ConditionParseResult {
  const ConditionsMalformed(this.error);
  final ConditionParseError error;
}

/// Reasons a `[...]` segment can fail to parse.
enum ConditionParseError {
  /// A condition doesn't match any known form (syntax noise, unsupported
  /// operator, whitespace inside a condition, etc.).
  invalidCondition,

  /// The segment matched the date shape but the date doesn't exist on the
  /// calendar (e.g. `2026/02/30`).
  invalidCalendarDate,

  /// Two or more date conditions in the same TODO.
  duplicateDate,

  /// Two or more project-version conditions in the same TODO.
  duplicateProjectVersion,
}

// A condition is `token ("," " "? token)*`. Whitespace inside a token is not
// allowed. Empty tokens (leading/trailing comma, `,,`) are invalid.
final RegExp _splitter = RegExp(r', ?');

final RegExp _dateRe = RegExp(r'^(\d{4})/(\d{2})/(\d{2})$');
final RegExp _packageVersionRe = RegExp(r'^([a-z][a-z0-9_]*)@(>=?)(.+)$');
final RegExp _projectVersionRe = RegExp(r'^(>=?)(.+)$');
final RegExp _versionRe = RegExp(
  r'^(\d+)(?:\.(\d+)(?:\.(\d+)((?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?))?)?$',
);

/// Parses [content] — the raw text inside `[...]` — into conditions.
ConditionParseResult parseConditions(String content) {
  // No leading/trailing whitespace: the wrapping regex disallows a space
  // right after `[` or before `]`, but we still need to reject `[a, ]`
  // (trailing empty token) and `[ a,b]` etc. defensively.
  if (content.isEmpty || content != content.trim()) {
    return const ConditionsMalformed(ConditionParseError.invalidCondition);
  }
  var tokens = content.split(_splitter);
  var conditions = <ExpiryCondition>[];
  var dateCount = 0;
  var projectVersionCount = 0;
  for (var token in tokens) {
    if (token.isEmpty || token != token.trim()) {
      return const ConditionsMalformed(ConditionParseError.invalidCondition);
    }
    var parsed = _parseSingle(token);
    if (parsed == null) {
      return const ConditionsMalformed(ConditionParseError.invalidCondition);
    }
    switch (parsed) {
      case _InvalidDate():
        return const ConditionsMalformed(
          ConditionParseError.invalidCalendarDate,
        );
      case _Parsed(:final condition):
        if (condition is DateCondition) dateCount++;
        if (condition is ProjectVersionCondition) projectVersionCount++;
        conditions.add(condition);
    }
  }
  if (dateCount > 1) {
    return const ConditionsMalformed(ConditionParseError.duplicateDate);
  }
  if (projectVersionCount > 1) {
    return const ConditionsMalformed(
      ConditionParseError.duplicateProjectVersion,
    );
  }
  return ConditionsOk(conditions);
}

sealed class _SingleParse {}

final class _Parsed extends _SingleParse {
  _Parsed(this.condition);
  final ExpiryCondition condition;
}

final class _InvalidDate extends _SingleParse {}

_SingleParse? _parseSingle(String token) {
  var dateMatch = _dateRe.firstMatch(token);
  if (dateMatch != null) {
    var year = int.parse(dateMatch.group(1)!);
    var month = int.parse(dateMatch.group(2)!);
    var day = int.parse(dateMatch.group(3)!);
    var date = DateTime(year, month, day);
    // DateTime normalizes overflow (2026/02/30 -> 2026/03/02); a mismatch
    // after the round-trip means the date doesn't exist.
    if (date.year != year || date.month != month || date.day != day) {
      return _InvalidDate();
    }
    return _Parsed(DateCondition(token, date));
  }
  var pkgMatch = _packageVersionRe.firstMatch(token);
  if (pkgMatch != null) {
    var name = pkgMatch.group(1)!;
    var op = _opFromSymbol(pkgMatch.group(2)!);
    var version = _parseVersion(pkgMatch.group(3)!);
    if (version == null) return null;
    return _Parsed(switch (name) {
      'sdk' => SdkVersionCondition(token, op, version),
      'flutter' => FlutterVersionCondition(token, op, version),
      _ => DependencyVersionCondition(token, name, op, version),
    });
  }
  var projMatch = _projectVersionRe.firstMatch(token);
  if (projMatch != null) {
    var op = _opFromSymbol(projMatch.group(1)!);
    var version = _parseVersion(projMatch.group(2)!);
    if (version == null) return null;
    return _Parsed(ProjectVersionCondition(token, op, version));
  }
  return null;
}

VersionOp _opFromSymbol(String s) => switch (s) {
  '>' => VersionOp.greater,
  '>=' => VersionOp.greaterOrEqual,
  _ => throw ArgumentError.value(s, 's', 'unreachable: regex captured op'),
};

/// Parses a version accepting `X`, `X.Y`, and `X.Y.Z[+/-suffix]`. Missing
/// minor/patch default to 0. Pre-release and build suffixes require the full
/// `X.Y.Z` form.
Version? _parseVersion(String s) {
  var match = _versionRe.firstMatch(s);
  if (match == null) return null;
  var major = match.group(1)!;
  var minor = match.group(2) ?? '0';
  var patch = match.group(3) ?? '0';
  var suffix = match.group(4) ?? '';
  try {
    return Version.parse('$major.$minor.$patch$suffix');
  } on FormatException {
    return null;
  }
}
