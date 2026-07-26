import 'dart:io';

import 'package:flutter_style_expiring_todos/src/expired_todo_scanner.dart';
import 'package:test/test.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'flutter_style_expiring_todos_scanner_',
    );
    File('${temporaryDirectory.path}/pubspec.yaml').writeAsStringSync('''
name: fixture
version: 2.0.0
''');
  });

  tearDown(() {
    temporaryDirectory.deleteSync(recursive: true);
  });

  test('returns the source line and one-based line number', () {
    final source = File('${temporaryDirectory.path}/main.dart')
      ..writeAsStringSync('''
void main() {
  // TODO(alice)[2020/01/01]: remove fallback
}
''');

    final findings = scanExpiredTodos([source], today: DateTime(2026, 7, 23));

    expect(findings, hasLength(1));
    expect(findings.single.line, 2);
    expect(
      findings.single.excerpt,
      '// TODO(alice)[2020/01/01]: remove fallback',
    );
  });

  test('does not report a date until the following day', () {
    final source = File('${temporaryDirectory.path}/main.dart')
      ..writeAsStringSync('// TODO(alice)[2026/07/23]: keep today\n');

    expect(scanExpiredTodos([source], today: DateTime(2026, 7, 23)), isEmpty);
  });

  test('evaluates project version conditions from pubspec.yaml', () {
    final source = File('${temporaryDirectory.path}/main.dart')
      ..writeAsStringSync('// TODO(alice)[>=2.0.0]: remove compatibility\n');

    expect(
      scanExpiredTodos([source], today: DateTime(2026, 7, 23)),
      hasLength(1),
    );
  });

  test('reports a TODO once when multiple conditions are met', () {
    final source = File('${temporaryDirectory.path}/main.dart')
      ..writeAsStringSync(
        '// TODO(alice)[2020/01/01, >=2.0.0]: remove compatibility\n',
      );

    expect(
      scanExpiredTodos([source], today: DateTime(2026, 7, 23)),
      hasLength(1),
    );
  });

  test('ignores TODO-like text inside a string', () {
    final source = File('${temporaryDirectory.path}/main.dart')
      ..writeAsStringSync('''
const text = '// TODO(alice)[2020/01/01]: not a comment';
''');

    expect(scanExpiredTodos([source], today: DateTime(2026, 7, 23)), isEmpty);
  });
}
