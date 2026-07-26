@Tags(['integration'])
library;

import 'dart:io';

import 'package:test/test.dart';

/// Runs `dart analyze` against the fixture projects in `tool/`, which load
/// this plugin by path, and asserts on the machine-format output.
///
/// The first run is slow: the analysis server resolves the plugin in a
/// synthetic package (network access required).
void main() {
  final dart = Platform.resolvedExecutable;

  Future<List<({String code, int line})>> analyze(String fixtureDir) async {
    var pubGet = await Process.run(dart, [
      'pub',
      'get',
    ], workingDirectory: fixtureDir);
    expect(pubGet.exitCode, 0, reason: 'dart pub get failed: ${pubGet.stderr}');

    var cacheDir = await Directory.systemTemp.createTemp(
      'flutter_style_expiring_todos_analyze_',
    );
    try {
      var result = await Process.run(dart, [
        'analyze',
        '--cache=${cacheDir.path}',
        '--format=machine',
        '.',
      ], workingDirectory: fixtureDir);
      expect(
        result.exitCode,
        0,
        reason:
            'dart analyze failed:\n'
            'stdout:\n${result.stdout}\n'
            'stderr:\n${result.stderr}',
      );

      // Machine format: SEVERITY|TYPE|CODE|FILE|LINE|COLUMN|LENGTH|MESSAGE
      return (result.stdout as String)
          .split('\n')
          .where((line) => line.contains('|'))
          .map((line) {
            var fields = line.split('|');
            return (code: fields[2], line: int.parse(fields[4]));
          })
          .toList();
    } finally {
      await cacheDir.delete(recursive: true);
    }
  }

  test('reports all diagnostics at the expected lines', () async {
    var diagnostics = await analyze('tool/fixture');

    expect(
      diagnostics.where((d) => d.code == 'EXPIRED_TODO').map((d) => d.line),
      [3],
    );
    expect(
      diagnostics
          .where((d) => d.code == 'FLUTTER_STYLE_EXPIRING_TODOS')
          .map((d) => d.line),
      [4],
    );
    expect(
      diagnostics
          .where((d) => d.code == 'EXPIRED_TODO_VERSION')
          .map((d) => d.line),
      [5],
    );
    expect(
      diagnostics
          .where((d) => d.code == 'UNRESOLVED_TODO_CONDITION')
          .map((d) => d.line),
      [6],
    );
  });

  test(
    'a single diagnostic can be disabled in the diagnostics section',
    () async {
      var diagnostics = await analyze('tool/fixture_disabled');

      // `expired_todo: false` turns off the whole rule — both the date code
      // and the version code.
      expect(diagnostics.where((d) => d.code == 'EXPIRED_TODO'), isEmpty);
      expect(
        diagnostics.where((d) => d.code == 'EXPIRED_TODO_VERSION'),
        isEmpty,
      );
      // The other rules stay on: they flag defects in the TODO comment
      // itself, not project state.
      expect(
        diagnostics
            .where((d) => d.code == 'FLUTTER_STYLE_EXPIRING_TODOS')
            .map((d) => d.line),
        [2],
      );
      expect(
        diagnostics
            .where((d) => d.code == 'UNRESOLVED_TODO_CONDITION')
            .map((d) => d.line),
        [4],
      );
    },
  );
}
