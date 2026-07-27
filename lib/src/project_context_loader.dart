/// Loads a [ProjectContext] from the enclosing project's `pubspec.yaml` and
/// `pubspec.lock`, using the analyzer's `File`/`Folder` abstractions so that
/// tests can run against an in-memory file system.
library;

import 'package:analyzer/file_system/file_system.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

import 'condition_evaluator.dart';

/// Reads pubspec files and caches results keyed by their modification stamps.
class ProjectContextLoader {
  final Map<String, ProjectContext?> _cache = {};

  /// Loads the context for the package that contains [file], walking up until
  /// a `pubspec.yaml` is found.
  ///
  /// Returns `null` when [file] is not inside any pub package (no
  /// `pubspec.yaml` ancestor). Version conditions in such files are silently
  /// skipped by consuming rules.
  ProjectContext? loadForFile(File file) {
    var yaml = _findPubspec(file.parent);
    if (yaml == null) return null;
    return _load(yaml);
  }

  /// Loads the context for the package rooted at [packageRoot].
  ProjectContext? loadForPackage(Folder packageRoot) {
    var yaml = packageRoot.getChild('pubspec.yaml');
    if (yaml is! File || !yaml.exists) return null;
    return _load(yaml);
  }

  File? _findPubspec(Folder start) {
    Folder folder = start;
    while (true) {
      var candidate = folder.getChild('pubspec.yaml');
      if (candidate is File && candidate.exists) return candidate;
      var parent = folder.parent;
      if (parent.path == folder.path) return null; // filesystem root
      folder = parent;
    }
  }

  ProjectContext? _load(File yamlFile) {
    var lockResource = yamlFile.parent.getChild('pubspec.lock');
    var lockFile = lockResource is File ? lockResource : null;
    var lockStamp = lockFile != null && lockFile.exists
        ? lockFile.modificationStamp
        : -1;
    var key = '${yamlFile.path}|${yamlFile.modificationStamp}|$lockStamp';
    if (_cache.containsKey(key)) return _cache[key];
    var context = _build(yamlFile, lockFile);
    _cache[key] = context;
    return context;
  }

  ProjectContext? _build(File yamlFile, File? lockFile) {
    Object? yamlDoc;
    try {
      yamlDoc = loadYaml(yamlFile.readAsStringSync());
    } on Exception {
      return null;
    }
    if (yamlDoc is! Map) return const ProjectContext();

    var projectVersion = _tryVersion(yamlDoc['version']);
    Version? sdkLower;
    Version? flutterLower;
    var env = yamlDoc['environment'];
    if (env is Map) {
      sdkLower = _lowerBound(env['sdk']);
      flutterLower = _lowerBound(env['flutter']);
    }

    var locked = <String, Version>{};
    if (lockFile != null && lockFile.exists) {
      Object? lockDoc;
      try {
        lockDoc = loadYaml(lockFile.readAsStringSync());
      } on Exception {
        lockDoc = null;
      }
      if (lockDoc is Map) {
        var packages = lockDoc['packages'];
        if (packages is Map) {
          packages.forEach((name, info) {
            if (name is String && info is Map) {
              var v = _tryVersion(info['version']);
              if (v != null) locked[name] = v;
            }
          });
        }
      }
    }

    return ProjectContext(
      projectVersion: projectVersion,
      lockedPackages: locked,
      sdkLowerBound: sdkLower,
      flutterLowerBound: flutterLower,
    );
  }

  Version? _tryVersion(Object? v) {
    if (v is! String) return null;
    try {
      return Version.parse(v);
    } on FormatException {
      return null;
    }
  }

  /// Extracts the lower bound of an `environment.sdk`/`environment.flutter`
  /// constraint. `^3.11.0` and `>=3.10.0 <4.0.0` both yield their minimum;
  /// `any` and unbounded-below constraints yield `null`.
  Version? _lowerBound(Object? v) {
    if (v is! String) return null;
    VersionConstraint constraint;
    try {
      constraint = VersionConstraint.parse(v);
    } on FormatException {
      return null;
    }
    if (constraint is VersionRange) return constraint.min;
    return null;
  }
}
