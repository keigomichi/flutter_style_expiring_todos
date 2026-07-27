// Copyright (c) 2022, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Reflective test methods keep the official SDK test names.
// ignore_for_file: non_constant_identifier_names

// This file is ported from the Dart SDK's flutter_style_todos tests:
//   dart-lang/sdk @ c6444fd86f62eb9b3b2885d10916293aa98b43b8
//   pkg/linter/test/rules/flutter_style_todos_test.dart
// It verifies that `flutter_style_expiring_todos` is fully compatible with
// the official `flutter_style_todos` rule. The only intentional divergence
// is the extended form `// TODO(username)[condition, ...]: message`, which
// the official rule rejects and this plugin accepts. The official suite
// contains no such cases, so every test below is expected to match
// verbatim.

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:flutter_style_expiring_todos/src/rules/flutter_style_expiring_todos.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../support/diagnostics.dart' as diagnostics;

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(FlutterStyleTodosOfficialTest);
  });
}

@reflectiveTest
class FlutterStyleTodosOfficialTest
    extends diagnostics.AnalysisRuleTestWithoutTodo {
  @override
  void setUp() {
    rule = FlutterStyleExpiringTodos();
    super.setUp();
  }

  // TODO(srawlins): line "// TODO(somebody): something,
  // github.com/flutter/flutter" currently isn't recognized as a
  // bad pattern, should the URI part be validated or should this
  // be an acceptable case
  test_badPatterns() async {
    await assertDiagnostics(
      r'''
// TODO something
// Todo something
// todo something
// TODO(somebody) something
// TODO: something
// Todo(somebody): something
// todo(somebody): something
// ToDo(somebody): something
// TODO(somebody): something, github.com/flutter/flutter
// ToDo(somebody): something, https://github.com/flutter/flutter
''',
      [
        lint(0, 17),
        error(diagnostics.todo, 3, 14),
        lint(18, 17),
        lint(36, 17),
        lint(54, 27),
        error(diagnostics.todo, 57, 24),
        lint(82, 18),
        error(diagnostics.todo, 85, 15),
        lint(101, 28),
        lint(130, 28),
        lint(159, 28),
        error(diagnostics.todo, 191, 53),
        lint(245, 64),
      ],
    );
  }

  test_badUsername_comma() async {
    await assertDiagnostics(r'// TODO(user1,user2): bla', [
      lint(0, 25),
      error(diagnostics.todo, 3, 22),
    ]);
  }

  test_badUsername_extraSymbols() async {
    await assertDiagnostics(r'// TODO(#12357): bla', [
      lint(0, 20),
      error(diagnostics.todo, 3, 17),
    ]);
  }

  test_charactersBeforeTODO() async {
    await assertDiagnostics(
      r'''
// comment TODO(user): bla
/// final todo = Todo(name: 'test todo', description: 'todo description');
/// Something interesting. TODO(someone): this is an ugly test case.
''',
      [error(diagnostics.todo, 11, 15), error(diagnostics.todo, 129, 41)],
    );
  }

  test_docComment() async {
    await assertDiagnostics(r'/// TODO(user): bla', [
      lint(0, 19),
      error(diagnostics.todo, 4, 15),
    ]);
  }

  test_extraColon() async {
    await assertDiagnostics(r'// TODO:(user): bla', [
      lint(0, 19),
      error(diagnostics.todo, 3, 16),
    ]);
  }

  test_justTodo() async {
    await assertDiagnostics(r'// TODO', [
      lint(0, 7),
      error(diagnostics.todo, 3, 4),
    ]);
  }

  test_justTodo_noLeadingSpace() async {
    await assertDiagnostics(r'//TODO', [
      lint(0, 6),
      error(diagnostics.todo, 2, 4),
    ]);
  }

  test_missingColon() async {
    await assertDiagnostics(r'// TODO(user) bla', [
      lint(0, 17),
      error(diagnostics.todo, 3, 14),
    ]);
  }

  test_missingMessage() async {
    await assertDiagnostics(
      r'''
//TODO(somebody):
// TODO(somebody):
''',
      [
        lint(0, 17),
        error(diagnostics.todo, 2, 15),
        lint(18, 18),
        error(diagnostics.todo, 21, 15),
      ],
    );
  }

  test_missingParens() async {
    await assertDiagnostics(r'// TODO: bla', [
      lint(0, 12),
      error(diagnostics.todo, 3, 9),
    ]);
  }

  test_properFormat() async {
    await assertDiagnostics(
      r'''
// TODO(somebody): something
''',
      [error(diagnostics.todo, 3, 25)],
    );
  }

  test_properFormat_dottedUsername() async {
    await assertDiagnostics(r'// TODO(user.name): bla', [
      error(diagnostics.todo, 3, 20),
    ]);
  }

  test_properFormat_hyphenatedUsername() async {
    await assertDiagnostics(r'// TODO(user-name): bla', [
      error(diagnostics.todo, 3, 20),
    ]);
  }

  test_properFormat_multipleSeriesOfSlashes() async {
    await assertDiagnostics(
      r'''
// // TODO(somebody): something
''',
      [error(diagnostics.todo, 6, 25)],
    );
  }

  test_properFormat_noLeadingSpace() async {
    await assertDiagnostics(
      r'''
//TODO(somebody): something
''',
      [error(diagnostics.todo, 2, 25)],
    );
  }

  test_properFormat_simpleUsername() async {
    await assertDiagnostics(r'// TODO(username): bla', [
      error(diagnostics.todo, 3, 19),
    ]);
  }

  test_properFormat_withComma() async {
    await assertDiagnostics(
      r'''
// TODO(somebody): something, https://github.com/flutter/flutter
''',
      [error(diagnostics.todo, 3, 61)],
    );
  }

  test_slashStar() async {
    await assertDiagnostics(r'/* TODO bla */', [error(diagnostics.todo, 3, 8)]);
  }

  test_slashStarStar() async {
    await assertDiagnostics(r'/** TODO bla **/', [
      error(diagnostics.todo, 4, 10),
    ]);
  }

  test_spaceBeforeColon() async {
    await assertDiagnostics(r'// TODO(user) : bla', [
      lint(0, 19),
      error(diagnostics.todo, 3, 16),
    ]);
  }
}
