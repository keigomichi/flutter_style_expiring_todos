import 'package:flutter_style_expiring_todos/flutter_style_expiring_todos_cli.dart'
    as flutter_style_expiring_todos_cli;
import 'package:test/test.dart';

void main() {
  test('lists check-expired-todos in the root help', () async {
    final output = StringBuffer();

    final code = await flutter_style_expiring_todos_cli.run(
      const [],
      out: output,
    );

    expect(code, 0);
    expect(output.toString(), contains('check-expired-todos'));
  });

  test('shows help for check-expired-todos', () async {
    final output = StringBuffer();

    final code = await flutter_style_expiring_todos_cli.run(const [
      'help',
      'check-expired-todos',
    ], out: output);

    expect(code, 0);
    expect(output.toString(), contains('--date=<YYYY/MM/DD>'));
    expect(output.toString(), contains('[path ...]'));
  });

  test('rejects an unknown command', () async {
    final errors = StringBuffer();

    final code = await flutter_style_expiring_todos_cli.run(
      const ['unknown'],
      out: StringBuffer(),
      err: errors,
    );

    expect(code, 2);
    expect(errors.toString(), contains('Could not find a command'));
  });
}
