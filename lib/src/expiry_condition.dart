import 'package:pub_semver/pub_semver.dart';

/// A single expiry condition inside the `[...]` segment of a TODO comment.
///
/// Conditions are independent: a TODO with multiple conditions is reported
/// once per met condition.
sealed class ExpiryCondition {
  const ExpiryCondition(this.raw);

  /// The condition's original source text, used verbatim in diagnostic
  /// messages so the user sees exactly what they wrote.
  final String raw;
}

/// A `YYYY/MM/DD` due date. Met the day after [date] in local time.
final class DateCondition extends ExpiryCondition {
  const DateCondition(super.raw, this.date);
  final DateTime date;
}

/// A version condition against the enclosing project's own `pubspec.yaml`
/// `version` field. Written as `>=1.2.3` or `>2` (no package name).
final class ProjectVersionCondition extends ExpiryCondition {
  const ProjectVersionCondition(super.raw, this.op, this.target);
  final VersionOp op;
  final Version target;
}

/// A version condition against a dependency in `pubspec.lock`. Written as
/// `<package>@>=<version>`.
final class DependencyVersionCondition extends ExpiryCondition {
  const DependencyVersionCondition(
    super.raw,
    this.packageName,
    this.op,
    this.target,
  );
  final String packageName;
  final VersionOp op;
  final Version target;
}

/// A version condition against `environment.sdk` in `pubspec.yaml`. Written
/// as `sdk@>=<version>`. Evaluates against the lower bound of the range.
final class SdkVersionCondition extends ExpiryCondition {
  const SdkVersionCondition(super.raw, this.op, this.target);
  final VersionOp op;
  final Version target;
}

/// A version condition against `environment.flutter` in `pubspec.yaml`.
/// Written as `flutter@>=<version>`. Evaluates against the lower bound.
final class FlutterVersionCondition extends ExpiryCondition {
  const FlutterVersionCondition(super.raw, this.op, this.target);
  final VersionOp op;
  final Version target;
}

/// Comparison operator supported in version conditions.
///
/// Only `>` and `>=` are accepted (mirroring eslint-plugin-unicorn's
/// `expiring-todo-comments`).
enum VersionOp {
  greater('>'),
  greaterOrEqual('>=');

  const VersionOp(this.symbol);
  final String symbol;

  /// Whether [actual] satisfies this operator against [target].
  bool isMetBy(Version actual, Version target) => switch (this) {
    VersionOp.greater => actual > target,
    VersionOp.greaterOrEqual => actual >= target,
  };
}
