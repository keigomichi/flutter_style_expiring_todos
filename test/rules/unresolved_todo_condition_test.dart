// Reflective test methods follow the SDK linter test naming style.
// ignore_for_file: non_constant_identifier_names

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:flutter_style_expiring_todos/src/rules/unresolved_todo_condition.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../support/diagnostics.dart' as diagnostics;

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(UnresolvedTodoConditionTest);
  });
}

@reflectiveTest
class UnresolvedTodoConditionTest extends diagnostics.AnalysisRuleTestWithoutTodo {
  @override
  void setUp() {
    rule = UnresolvedTodoCondition();
    super.setUp();
  }

  void _writePubspec({
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

  Future<void> test_dependency_absent_reported() async {
    _writePubspec(lockedDependencies: const {'other': '1.0.0'});
    await assertDiagnostics(
      r'''
// TODO(alice)[missing@>=1.0.0]: fix
''',
      [
        lint(0, 36, messageContainsAll: ['missing@>=1.0.0', 'pubspec.lock']),
        error(diagnostics.todo, 3, 33),
      ],
    );
  }

  Future<void> test_project_missingVersion_reported() async {
    _writePubspec();
    await assertDiagnostics(
      r'''
// TODO(alice)[>=1.0.0]: fix
''',
      [
        lint(0, 28, messageContainsAll: ['>=1.0.0', 'version']),
        error(diagnostics.todo, 3, 25),
      ],
    );
  }

  Future<void> test_sdk_missingLowerBound_reported() async {
    // The `any` constraint has no lower bound.
    _writePubspec(sdk: 'any');
    await assertDiagnostics(
      r'''
// TODO(alice)[sdk@>=3.10.0]: fix
''',
      [
        lint(0, 33, messageContainsAll: ['sdk@>=3.10.0']),
        error(diagnostics.todo, 3, 30),
      ],
    );
  }

  Future<void> test_flutter_absent_reported() async {
    _writePubspec(sdk: '^3.11.0');
    await assertDiagnostics(
      r'''
// TODO(alice)[flutter@>=3.38.0]: fix
''',
      [
        lint(0, 37, messageContainsAll: ['flutter@>=3.38.0']),
        error(diagnostics.todo, 3, 34),
      ],
    );
  }

  Future<void> test_dependency_resolved_notReported() async {
    _writePubspec(lockedDependencies: const {'provider': '5.0.0'});
    await assertDiagnostics(
      r'''
// TODO(alice)[provider@>=6.0.0]: fix
''',
      [error(diagnostics.todo, 3, 34)],
    );
  }

  Future<void> test_dateCondition_notReported() async {
    // Date conditions are never unresolved — the clock is always available.
    _writePubspec();
    await assertDiagnostics(
      r'''
// TODO(alice)[2099/01/01]: fix
''',
      [error(diagnostics.todo, 3, 28)],
    );
  }
}
