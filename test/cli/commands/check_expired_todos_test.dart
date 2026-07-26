import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_style_expiring_todos/src/cli/commands/check_expired_todos.dart';
import 'package:test/test.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'check_expired_todos_command_',
    );
    File('${temporaryDirectory.path}/pubspec.yaml').writeAsStringSync('''
name: fixture
version: 1.0.0
''');
  });

  tearDown(() {
    temporaryDirectory.deleteSync(recursive: true);
  });

  test('has the expected command metadata', () {
    final command = CheckExpiredTodosCommand();

    expect(command.name, 'check-expired-todos');
    expect(command.description, contains('expired TODO'));
    expect(command.argParser.options, contains('date'));
  });

  test('prints findings and returns one', () async {
    Directory('${temporaryDirectory.path}/lib').createSync();
    File(
      '${temporaryDirectory.path}/lib/main.dart',
    ).writeAsStringSync('// TODO(alice)[2020/01/01]: remove fallback\n');
    final output = StringBuffer();

    final code = await _runCommand(
      const [],
      workingDirectory: temporaryDirectory,
      now: DateTime(2026, 7, 23),
      out: output,
    );

    expect(code, 1);
    expect(
      output.toString(),
      './lib/main.dart:1 // TODO(alice)[2020/01/01]: remove fallback\n',
    );
  });

  test('returns zero when no TODO is expired', () async {
    File(
      '${temporaryDirectory.path}/main.dart',
    ).writeAsStringSync('// TODO(alice)[2099/01/01]: future\n');

    final code = await _runCommand(
      const [],
      workingDirectory: temporaryDirectory,
      now: DateTime(2026, 7, 23),
    );

    expect(code, 0);
  });

  test('uses the date option instead of the injected current date', () async {
    File(
      '${temporaryDirectory.path}/main.dart',
    ).writeAsStringSync('// TODO(alice)[2026/07/22]: expired\n');

    final code = await _runCommand(
      const ['--date', '2026/07/23'],
      workingDirectory: temporaryDirectory,
      now: DateTime(2020),
    );

    expect(code, 1);
  });

  test('scans each supplied path once', () async {
    Directory('${temporaryDirectory.path}/lib').createSync();
    Directory('${temporaryDirectory.path}/test').createSync();
    File(
      '${temporaryDirectory.path}/lib/main.dart',
    ).writeAsStringSync('// TODO(alice)[2020/01/01]: lib TODO\n');
    File(
      '${temporaryDirectory.path}/test/main_test.dart',
    ).writeAsStringSync('// TODO(bob)[2020/01/01]: test TODO\n');
    final output = StringBuffer();

    final code = await _runCommand(
      [
        'lib',
        'lib/main.dart',
        '${temporaryDirectory.path}/lib/../lib/main.dart',
        'test/main_test.dart',
      ],
      workingDirectory: temporaryDirectory,
      now: DateTime(2026, 7, 23),
      out: output,
    );

    expect(code, 1);
    expect('./lib/main.dart:1'.allMatches(output.toString()), hasLength(1));
    expect(
      './test/main_test.dart:1'.allMatches(output.toString()),
      hasLength(1),
    );
  });

  test('rejects an invalid date', () async {
    final errors = StringBuffer();

    final code = await _runCommand(
      const ['--date', '2026/02/30'],
      workingDirectory: temporaryDirectory,
      err: errors,
    );

    expect(code, 2);
    expect(errors.toString(), contains('Invalid date: 2026/02/30'));
    expect(errors.toString(), contains('Expected YYYY/MM/DD'));
  });

  test('rejects a path that does not exist', () async {
    final errors = StringBuffer();

    final code = await _runCommand(
      const ['missing'],
      workingDirectory: temporaryDirectory,
      err: errors,
    );

    expect(code, 2);
    expect(errors.toString(), contains('Path does not exist'));
  });
}

Future<int?> _runCommand(
  List<String> arguments, {
  required Directory workingDirectory,
  DateTime? now,
  StringSink? out,
  StringSink? err,
}) {
  final runner = CommandRunner<int>('test_cli', 'Test CLI')
    ..addCommand(
      CheckExpiredTodosCommand(
        workingDirectory: workingDirectory,
        now: now,
        out: out ?? StringBuffer(),
        err: err ?? StringBuffer(),
      ),
    );
  return runner.run(['check-expired-todos', ...arguments]);
}
