import 'dart:io';

import 'package:flutter_style_expiring_todos/src/cli/utils/file_system_utils.dart';
import 'package:test/test.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'cli_file_system_utils_',
    );
  });

  tearDown(() {
    temporaryDirectory.deleteSync(recursive: true);
  });

  group('dartFilesUnder', () {
    test('recursively yields only Dart files', () {
      Directory(
        '${temporaryDirectory.path}/lib/nested',
      ).createSync(recursive: true);
      final mainFile = File('${temporaryDirectory.path}/lib/main.dart')
        ..writeAsStringSync('');
      final nestedFile = File(
        '${temporaryDirectory.path}/lib/nested/child.dart',
      )..writeAsStringSync('');
      File('${temporaryDirectory.path}/lib/readme.md').writeAsStringSync('');

      final paths = dartFilesUnder(
        temporaryDirectory,
      ).map((file) => file.path).toSet();

      expect(paths, {mainFile.path, nestedFile.path});
    });

    test('skips generated and editor-specific directories', () {
      const ignoredNames = ['.dart_tool', '.git', '.idea', '.vscode', 'build'];
      for (final name in ignoredNames) {
        Directory('${temporaryDirectory.path}/$name').createSync();
        File(
          '${temporaryDirectory.path}/$name/ignored.dart',
        ).writeAsStringSync('');
      }
      final included = File('${temporaryDirectory.path}/included.dart')
        ..writeAsStringSync('');

      final files = dartFilesUnder(temporaryDirectory).toList();

      expect(files.map((file) => file.path), [included.path]);
    });
  });

  group('resolvePath', () {
    test('resolves a relative path against the root', () {
      final resolved = resolvePath(temporaryDirectory, 'lib/main.dart');

      expect(
        resolved,
        File('${temporaryDirectory.path}/lib/main.dart').absolute.path,
      );
    });

    test('preserves an absolute path', () {
      final absolutePath = File(
        '${temporaryDirectory.path}/lib/main.dart',
      ).absolute.path;

      expect(resolvePath(temporaryDirectory, absolutePath), absolutePath);
    });
  });

  group('displayPath', () {
    test('formats a path below the root as a dot-relative path', () {
      final path = File(
        '${temporaryDirectory.path}/lib/main.dart',
      ).absolute.path;

      expect(
        displayPath(path, temporaryDirectory.absolute),
        './lib${Platform.pathSeparator}main.dart',
      );
    });

    test('preserves a path outside the root', () {
      final path = File(
        '${temporaryDirectory.parent.path}/outside.dart',
      ).absolute.path;

      expect(displayPath(path, temporaryDirectory.absolute), path);
    });
  });
}
