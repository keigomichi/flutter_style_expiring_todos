/// Command that scans Dart files for expired TODO comments.
library;

import 'dart:io';

import 'package:args/command_runner.dart';

import '../../expired_todo_scanner.dart';
import '../utils/file_system_utils.dart';

final _datePattern = RegExp(r'^(\d{4})/(\d{2})/(\d{2})$');

/// Scans Dart files for expired Flutter-style TODO comments.
final class CheckExpiredTodosCommand extends Command<int> {
  CheckExpiredTodosCommand({
    Directory? workingDirectory,
    DateTime? now,
    StringSink? out,
    StringSink? err,
  }) : _workingDirectory = workingDirectory,
       _now = now,
       _out = out ?? stdout,
       _err = err ?? stderr {
    argParser.addOption(
      'date',
      valueHelp: 'YYYY/MM/DD',
      help: 'Evaluate date conditions on this date.',
    );
  }

  final Directory? _workingDirectory;
  final DateTime? _now;
  final StringSink _out;
  final StringSink _err;

  @override
  String get name => 'check-expired-todos';

  @override
  String get description =>
      'Print expired TODO comments as "path:line excerpt".';

  @override
  String get invocation =>
      '${runner!.executableName} $name [options] [path ...]';

  @override
  void printUsage() => _out.writeln(usage);

  @override
  int run() {
    final dateArgument = argResults!['date'] as String?;
    final evaluationDate = dateArgument == null
        ? null
        : _parseDate(dateArgument);
    if (dateArgument != null && evaluationDate == null) {
      _err.writeln('Invalid date: $dateArgument');
      _err.writeln('Expected YYYY/MM/DD.');
      return 2;
    }

    return _scan(
      argResults!.rest,
      workingDirectory: _workingDirectory,
      now: evaluationDate ?? _now,
      out: _out,
      err: _err,
    );
  }
}

int _scan(
  List<String> arguments, {
  Directory? workingDirectory,
  DateTime? now,
  required StringSink out,
  required StringSink err,
}) {
  final root = (workingDirectory ?? Directory.current).absolute;
  final paths = arguments.toList();
  if (paths.isEmpty) paths.add('.');
  final filesByPath = <String, File>{};
  late final List<ExpiredTodoFinding> findings;
  try {
    for (final path in paths) {
      final entityPath = resolvePath(root, path);
      final type = FileSystemEntity.typeSync(entityPath, followLinks: false);
      switch (type) {
        case FileSystemEntityType.file:
          if (entityPath.endsWith('.dart')) {
            filesByPath[entityPath] = File(entityPath);
          }
        case FileSystemEntityType.directory:
          for (final file in dartFilesUnder(Directory(entityPath))) {
            filesByPath[file.absolute.path] = file;
          }
        case FileSystemEntityType.link:
        case FileSystemEntityType.notFound:
        case FileSystemEntityType.pipe:
        case FileSystemEntityType.unixDomainSock:
          err.writeln('Path does not exist or is not readable: $path');
          return 2;
      }
    }

    final files = filesByPath.values.toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    findings = scanExpiredTodos(files, today: now ?? DateTime.now());
  } on FileSystemException catch (error) {
    err.writeln(error.message);
    return 2;
  }

  for (final finding in findings) {
    out.writeln(
      '${displayPath(finding.path, root)}:${finding.line} '
      '${finding.excerpt}',
    );
  }
  return findings.isEmpty ? 0 : 1;
}

DateTime? _parseDate(String value) {
  final match = _datePattern.firstMatch(value);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}
