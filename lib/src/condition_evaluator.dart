/// Evaluates a parsed [ExpiryCondition] against a [ProjectContext] and a
/// clock. Pure Dart — no IO — so it can be tested with an in-memory
/// [ProjectContext].
library;

import 'package:pub_semver/pub_semver.dart';

import 'expiry_condition.dart';

/// Snapshot of the enclosing project's version-relevant state.
///
/// Constructed by `ProjectContextLoader` from `pubspec.yaml` / `pubspec.lock`,
/// or in tests directly.
final class ProjectContext {
  const ProjectContext({
    this.projectVersion,
    this.lockedPackages = const {},
    this.sdkLowerBound,
    this.flutterLowerBound,
  });

  /// `pubspec.yaml` top-level `version`, or `null` if unset.
  final Version? projectVersion;

  /// `pubspec.lock` resolved versions, keyed by package name.
  final Map<String, Version> lockedPackages;

  /// Lower bound of `environment.sdk`, or `null` if unset / unbounded.
  final Version? sdkLowerBound;

  /// Lower bound of `environment.flutter`, or `null` if unset / unbounded.
  final Version? flutterLowerBound;
}

/// The outcome of evaluating a condition.
sealed class ConditionOutcome {
  const ConditionOutcome();
}

/// The condition is currently satisfied — the TODO should be reported.
///
/// [detail] is a short human-readable fragment describing why (e.g.
/// `"provider is now 6.1.2"`, `"expired on 2020/01/01"`).
final class ConditionMet extends ConditionOutcome {
  const ConditionMet(this.detail);
  final String detail;
}

/// The condition is well-formed but not yet satisfied.
const ConditionOutcome conditionNotMet = _NotMet();

final class _NotMet extends ConditionOutcome {
  const _NotMet();
}

/// The condition cannot be evaluated (referent missing, unbounded range,
/// etc.). Reported by the `unresolved_todo_condition` rule.
final class ConditionUnresolved extends ConditionOutcome {
  const ConditionUnresolved(this.reason);

  /// A short human-readable fragment describing the gap (e.g.
  /// `"provider is not in pubspec.lock"`).
  final String reason;
}

/// Evaluates [condition] against [context] at [today] (day granularity in
/// local time).
///
/// Returns [ConditionMet] when the TODO should be reported, `conditionNotMet`
/// when the condition is well-formed but hasn't triggered, or
/// [ConditionUnresolved] when the referent is missing.
ConditionOutcome evaluateCondition(
  ExpiryCondition condition,
  ProjectContext context,
  DateTime today,
) => switch (condition) {
  DateCondition(:final date) =>
    date.isBefore(_dayOf(today))
        ? ConditionMet('expired on ${_formatDate(date)}')
        : conditionNotMet,
  ProjectVersionCondition() => evaluateVersionCondition(condition, context),
  DependencyVersionCondition() => evaluateVersionCondition(condition, context),
  SdkVersionCondition() => evaluateVersionCondition(condition, context),
  FlutterVersionCondition() => evaluateVersionCondition(condition, context),
};

/// Evaluates a non-date [condition] without requiring a clock.
ConditionOutcome evaluateVersionCondition(
  ExpiryCondition condition,
  ProjectContext context,
) => switch (condition) {
  DateCondition() => throw ArgumentError.value(
    condition,
    'condition',
    'must be a version condition',
  ),
  ProjectVersionCondition(:final op, :final target) => _evaluateVersion(
    op: op,
    target: target,
    actual: context.projectVersion,
    missingReason: 'pubspec.yaml does not declare a version',
    metPrefix: 'project version is now',
  ),
  DependencyVersionCondition(:final packageName, :final op, :final target) =>
    _evaluateVersion(
      op: op,
      target: target,
      actual: context.lockedPackages[packageName],
      missingReason: '$packageName is not in pubspec.lock',
      metPrefix: '$packageName is now',
    ),
  SdkVersionCondition(:final op, :final target) => _evaluateVersion(
    op: op,
    target: target,
    actual: context.sdkLowerBound,
    missingReason: 'pubspec.yaml environment.sdk has no lower bound',
    metPrefix: 'Dart SDK constraint is now',
  ),
  FlutterVersionCondition(:final op, :final target) => _evaluateVersion(
    op: op,
    target: target,
    actual: context.flutterLowerBound,
    missingReason: 'pubspec.yaml environment.flutter has no lower bound',
    metPrefix: 'Flutter constraint is now',
  ),
};

ConditionOutcome _evaluateVersion({
  required VersionOp op,
  required Version target,
  required Version? actual,
  required String missingReason,
  required String metPrefix,
}) {
  if (actual == null) return ConditionUnresolved(missingReason);
  if (op.isMetBy(actual, target)) return ConditionMet('$metPrefix $actual');
  return conditionNotMet;
}

DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

String _formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.day.toString().padLeft(2, '0')}';
