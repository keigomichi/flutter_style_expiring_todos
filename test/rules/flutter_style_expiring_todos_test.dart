// Reflective test methods follow the SDK linter test naming style.
// ignore_for_file: non_constant_identifier_names

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:flutter_style_expiring_todos/src/rules/flutter_style_expiring_todos.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../support/diagnostics.dart' as diagnostics;

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(FlutterStyleExpiringTodosTest);
  });
}

@reflectiveTest
class FlutterStyleExpiringTodosTest
    extends diagnostics.AnalysisRuleTestWithoutTodo {
  @override
  void setUp() {
    rule = FlutterStyleExpiringTodos();
    super.setUp();
  }

  Future<void> test_officialForm_valid() async {
    await assertDiagnostics(
      r'''
// TODO(alice): fix
''',
      [error(diagnostics.todo, 3, 16)],
    );
  }

  Future<void> test_extendedForm_valid() async {
    await assertDiagnostics(
      r'''
// TODO(alice)[2026/07/21]: fix
''',
      [error(diagnostics.todo, 3, 28)],
    );
  }

  Future<void> test_spaceBeforeBracket_reported() async {
    // The `)` and `[` must be adjacent.
    await assertDiagnostics(
      r'''
// TODO(alice) [2026/07/21]: fix
''',
      [lint(0, 32), error(diagnostics.todo, 3, 29)],
    );
  }

  Future<void> test_extendedForm_withUrl_valid() async {
    await assertDiagnostics(
      r'''
// TODO(alice)[2026/07/21]: fix, https://github.com/org/repo/issues/123
''',
      [error(diagnostics.todo, 3, 68)],
    );
  }

  Future<void> test_extendedForm_invalidCalendarDate() async {
    await assertDiagnostics(
      r'''
// TODO(alice)[2026/02/30]: fix
''',
      [lint(0, 31), error(diagnostics.todo, 3, 28)],
    );
  }

  Future<void> test_extendedForm_nonPaddedDate() async {
    await assertDiagnostics(
      r'''
// TODO(alice)[2026/7/1]: fix
''',
      [lint(0, 29), error(diagnostics.todo, 3, 26)],
    );
  }

  Future<void> test_missingUsername() async {
    await assertDiagnostics(
      r'''
// TODO: fix
''',
      [lint(0, 12), error(diagnostics.todo, 3, 9)],
    );
  }

  Future<void> test_lowercaseTodo() async {
    await assertDiagnostics(
      r'''
// todo(alice): fix
''',
      [lint(0, 19)],
    );
  }

  Future<void> test_docComment() async {
    await assertDiagnostics(
      r'''
/// TODO(alice): fix
''',
      [lint(0, 20), error(diagnostics.todo, 4, 16)],
    );
  }

  Future<void> test_blockComment_notChecked() async {
    await assertDiagnostics(
      r'''
/* TODO bla */
''',
      [error(diagnostics.todo, 3, 8)],
    );
  }

  Future<void> test_blockComment_extendedForm_notChecked() async {
    await assertDiagnostics(
      r'''
/* TODO(alice)[2026/02/30]: fix */
''',
      [error(diagnostics.todo, 3, 28)],
    );
  }

  Future<void> test_commentAtEndOfFile() async {
    await assertDiagnostics(
      r'''
void f() {}

// TODO bad
''',
      [lint(13, 11), error(diagnostics.todo, 16, 8)],
    );
  }
}
