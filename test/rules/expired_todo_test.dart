// Reflective test methods follow the SDK linter test naming style.
// ignore_for_file: non_constant_identifier_names

import 'package:analyzer/src/diagnostic/diagnostic.dart'
    as diag; // ignore: implementation_imports
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:flutter_style_expiring_todos/src/rules/expired_todo.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ExpiredTodoTest);
    defineReflectiveTests(ExpiredTodoDefaultClockTest);
    defineReflectiveTests(ExpiredTodoVersionTest);
  });
}

@reflectiveTest
class ExpiredTodoTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = ExpiredTodo(now: () => DateTime(2026, 7, 21));
    super.setUp();
  }

  Future<void> test_pastDate_reported() async {
    await assertDiagnostics(
      r'''
// TODO(alice)[2026/07/20]: fix
''',
      [
        lint(0, 31, messageContainsAll: ['2026/07/20']),
        error(diag.todo, 3, 28),
      ],
    );
  }

  Future<void> test_dueToday_notReported() async {
    await assertDiagnostics(
      r'''
// TODO(alice)[2026/07/21]: fix
''',
      [error(diag.todo, 3, 28)],
    );
  }

  Future<void> test_futureDate_notReported() async {
    await assertDiagnostics(
      r'''
// TODO(alice)[2026/07/22]: fix
''',
      [error(diag.todo, 3, 28)],
    );
  }

  Future<void> test_dateless_notReported() async {
    await assertDiagnostics(
      r'''
// TODO(alice): fix
''',
      [error(diag.todo, 3, 16)],
    );
  }

  Future<void> test_malformed_notReported() async {
    await assertDiagnostics(
      r'''
// TODO: fix
''',
      [error(diag.todo, 3, 9)],
    );
  }

  Future<void> test_invalidCalendarDate_notReported() async {
    await assertDiagnostics(
      r'''
// TODO(alice)[2026/02/30]: fix
''',
      [error(diag.todo, 3, 28)],
    );
  }

  Future<void> test_blockComment_pastDate_reported() async {
    await assertDiagnostics(
      r'''
/* TODO(alice)[2020/01/01]: fix */
''',
      [lint(0, 34), error(diag.todo, 3, 28)],
    );
  }

  Future<void> test_docComment_malformed_notReported() async {
    await assertDiagnostics(
      r'''
/// TODO(alice)[2026/07/20]: fix
''',
      [error(diag.todo, 4, 28)],
    );
  }
}

@reflectiveTest
class ExpiredTodoDefaultClockTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = ExpiredTodo();
    super.setUp();
  }

  Future<void> test_defaultClock_farPastDate_reported() async {
    await assertDiagnostics(
      r'''
// TODO(alice)[2000/01/01]: ancient
''',
      [lint(0, 35), error(diag.todo, 3, 32)],
    );
  }
}

@reflectiveTest
class ExpiredTodoVersionTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = ExpiredTodo(now: () => DateTime(2026, 7, 21));
    super.setUp();
  }

  /// Overwrites the auto-generated pubspec.yaml and (optionally) writes a
  /// pubspec.lock so version conditions have something to resolve against.
  void _writePubspecs({
    String? projectVersion,
    Map<String, String> lockedDependencies = const {},
    String? sdk,
    String? flutter,
  }) {
    var yaml = StringBuffer('name: test\n');
    if (projectVersion != null) yaml.writeln('version: $projectVersion');
    if (sdk != null || flutter != null) {
      yaml.writeln('environment:');
      if (sdk != null) yaml.writeln('  sdk: "$sdk"');
      if (flutter != null) yaml.writeln('  flutter: "$flutter"');
    }
    newFile(testPackagePubspecPath, yaml.toString());

    if (lockedDependencies.isNotEmpty) {
      var lock = StringBuffer('packages:\n');
      lockedDependencies.forEach((name, version) {
        lock.writeln('  $name:');
        lock.writeln('    dependency: transitive');
        lock.writeln('    version: "$version"');
      });
      newFile('$testPackageRootPath/pubspec.lock', lock.toString());
    }
  }

  Future<void> test_projectVersion_reached_reported() async {
    _writePubspecs(projectVersion: '1.2.3');
    await assertDiagnostics(
      r'''
// TODO(alice)[>=1.0.0]: fix
''',
      [
        lint(
          0,
          28,
          name: 'expired_todo_version',
          messageContainsAll: ['>=1.0.0', '1.2.3'],
        ),
        error(diag.todo, 3, 25),
      ],
    );
  }

  Future<void> test_projectVersion_notReached_notReported() async {
    _writePubspecs(projectVersion: '0.9.0');
    await assertDiagnostics(
      r'''
// TODO(alice)[>=1.0.0]: fix
''',
      [error(diag.todo, 3, 25)],
    );
  }

  Future<void>
  test_projectVersion_strictGreater_atEquality_notReported() async {
    _writePubspecs(projectVersion: '1.0.0');
    await assertDiagnostics(
      r'''
// TODO(alice)[>1.0.0]: fix
''',
      [error(diag.todo, 3, 24)],
    );
  }

  Future<void> test_dependencyVersion_reached_reported() async {
    _writePubspecs(lockedDependencies: const {'provider': '6.1.2'});
    await assertDiagnostics(
      r'''
// TODO(alice)[provider@>=6.0.0]: fix
''',
      [
        lint(
          0,
          37,
          name: 'expired_todo_version',
          messageContainsAll: ['provider@>=6.0.0', '6.1.2'],
        ),
        error(diag.todo, 3, 34),
      ],
    );
  }

  Future<void> test_dependencyVersion_notReached_notReported() async {
    _writePubspecs(lockedDependencies: const {'provider': '5.0.0'});
    await assertDiagnostics(
      r'''
// TODO(alice)[provider@>=6.0.0]: fix
''',
      [error(diag.todo, 3, 34)],
    );
  }

  Future<void> test_dependencyVersion_absent_notReported() async {
    // Absent packages are unresolved, which `expired_todo` treats as silent
    // — the `unresolved_todo_condition` rule surfaces them instead.
    _writePubspecs(lockedDependencies: const {'other': '1.0.0'});
    await assertDiagnostics(
      r'''
// TODO(alice)[missing@>=1.0.0]: fix
''',
      [error(diag.todo, 3, 33)],
    );
  }

  Future<void> test_sdk_reached_reported() async {
    _writePubspecs(sdk: '^3.11.0');
    await assertDiagnostics(
      r'''
// TODO(alice)[sdk@>=3.10.0]: fix
''',
      [
        lint(
          0,
          33,
          name: 'expired_todo_version',
          messageContainsAll: ['sdk@>=3.10.0'],
        ),
        error(diag.todo, 3, 30),
      ],
    );
  }

  Future<void> test_flutter_notReached_notReported() async {
    _writePubspecs(flutter: '>=3.30.0 <4.0.0');
    await assertDiagnostics(
      r'''
// TODO(alice)[flutter@>=3.40.0]: fix
''',
      [error(diag.todo, 3, 34)],
    );
  }

  Future<void> test_combined_dateAndVersion_reportsBoth() async {
    _writePubspecs(lockedDependencies: const {'provider': '6.1.2'});
    // Both conditions met: one diagnostic per condition, both at the same
    // token location.
    await assertDiagnostics(
      r'''
// TODO(alice)[2020/01/01, provider@>=6.0.0]: fix
''',
      [
        lint(0, 49, messageContainsAll: ['2020/01/01']),
        lint(
          0,
          49,
          name: 'expired_todo_version',
          messageContainsAll: ['provider@>=6.0.0'],
        ),
        error(diag.todo, 3, 46),
      ],
    );
  }

  Future<void> test_combined_onlyDateMet_reportsOne() async {
    _writePubspecs(lockedDependencies: const {'provider': '5.0.0'});
    await assertDiagnostics(
      r'''
// TODO(alice)[2020/01/01, provider@>=6.0.0]: fix
''',
      [
        lint(0, 49, messageContainsAll: ['2020/01/01']),
        error(diag.todo, 3, 46),
      ],
    );
  }
}
