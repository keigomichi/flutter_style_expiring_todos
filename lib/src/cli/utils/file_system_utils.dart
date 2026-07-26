/// File-system helpers shared by CLI commands.
library;

import 'dart:io';

const _ignoredDirectoryNames = {
  '.dart_tool',
  '.git',
  '.idea',
  '.vscode',
  'build',
};

/// Recursively yields Dart files below [directory].
///
/// Generated and editor-specific directories are skipped.
Iterable<File> dartFilesUnder(Directory directory) sync* {
  for (final entity in directory.listSync(followLinks: false)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      yield entity;
    } else if (entity is Directory &&
        !_ignoredDirectoryNames.contains(_basename(entity.path))) {
      yield* dartFilesUnder(entity);
    }
  }
}

/// Resolves [path] against [root], preserving absolute paths.
String resolvePath(Directory root, String path) {
  if (File(path).isAbsolute) return File(path).absolute.path;
  return File.fromUri(root.uri.resolveUri(Uri.file(path))).absolute.path;
}

/// Returns a CLI-friendly path relative to [root] when possible.
String displayPath(String path, Directory root) {
  final rootPath = root.path.endsWith(Platform.pathSeparator)
      ? root.path
      : '${root.path}${Platform.pathSeparator}';
  if (path.startsWith(rootPath)) {
    return './${path.substring(rootPath.length)}';
  }
  return path;
}

String _basename(String path) {
  final withoutTrailing = path.endsWith(Platform.pathSeparator)
      ? path.substring(0, path.length - 1)
      : path;
  return withoutTrailing.split(Platform.pathSeparator).last;
}
