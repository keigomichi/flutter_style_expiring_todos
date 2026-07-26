/// Command-line interface for scanning expired Flutter-style TODO comments.
library;

import 'dart:io';

import 'package:args/command_runner.dart';

import 'src/cli/commands/check_expired_todos.dart';

export 'src/cli/commands/check_expired_todos.dart'
    show CheckExpiredTodosCommand;

/// Runs the command-line interface and returns its process exit code.
///
/// Returns `1` when expired TODOs are found and `2` for invalid input.
Future<int> run(
  List<String> arguments, {
  Directory? workingDirectory,
  DateTime? now,
  StringSink? out,
  StringSink? err,
}) async {
  final stdoutSink = out ?? stdout;
  final stderrSink = err ?? stderr;
  final runner = _FlutterStyleExpiringTodosCommandRunner(stdoutSink)
    ..addCommand(
      CheckExpiredTodosCommand(
        workingDirectory: workingDirectory,
        now: now,
        out: stdoutSink,
        err: stderrSink,
      ),
    );

  try {
    return await runner.run(arguments) ?? 0;
  } on UsageException catch (error) {
    stderrSink.writeln(error);
    return 2;
  }
}

final class _FlutterStyleExpiringTodosCommandRunner extends CommandRunner<int> {
  _FlutterStyleExpiringTodosCommandRunner(this._out)
    : super(
        'flutter_style_expiring_todos_cli',
        'Scan Dart files for expired Flutter-style TODO comments.',
      );

  final StringSink _out;

  @override
  void printUsage() => _out.writeln(usage);
}
