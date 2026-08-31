# flutter_style_expiring_todos

[![pub version](https://img.shields.io/pub/v/flutter_style_expiring_todos.svg)](https://pub.dev/packages/flutter_style_expiring_todos)
[![CI](https://github.com/keigomichi/flutter_style_expiring_todos/actions/workflows/ci.yaml/badge.svg)](https://github.com/keigomichi/flutter_style_expiring_todos/actions/workflows/ci.yaml)

An analyzer plugin that enforces Flutter-style TODO comments with optional
expiry conditions — `// TODO(username)[condition]: message` — and reports TODOs
when their conditions are met.

## Overview

TODO comments can outlive their relevance. Add a date or version condition to
a TODO, and this plugin reports it in your IDE and CI as soon as that condition
is met.

The plugin extends the official
[`flutter_style_todos`](https://dart.dev/tools/linter-rules/flutter_style_todos)
lint. Existing conditionless Flutter-style TODOs continue to work, while the
extended form adds expiry conditions for dates, the project version,
dependencies, and the Dart and Flutter SDKs.

## Diagnostics

All diagnostics are enabled by default and can be configured individually.

| Rule | Reports |
| --- | --- |
| `flutter_style_expiring_todos` | TODO comments that do not follow the expected format |
| `expired_todo` | Well-formed TODOs whose date or version condition has been met |
| `unresolved_todo_condition` | TODOs whose condition cannot be resolved |

`flutter_style_expiring_todos` and `unresolved_todo_condition` report defects
in the comment itself. `expired_todo` reacts to time and package state, so it
can be disabled when those changes should not fail CI.

## Install

The plugin requires **Dart 3.11+ / Flutter 3.38+**.

Add it under the top-level `plugins:` section of `analysis_options.yaml`, then
disable the official `flutter_style_todos` lint. The official lint rejects the
conditional syntax, whereas this plugin accepts both forms.

### Minimal configuration

```yaml
plugins:
  flutter_style_expiring_todos: 0.1.0

linter:
  rules:
    flutter_style_todos: false
```

### Optional: configure individual diagnostics

Use this complete alternative configuration when you need to control
diagnostics individually. Do not add it alongside the minimal
`flutter_style_expiring_todos: 0.1.0` declaration above.

```yaml
plugins:
  flutter_style_expiring_todos:
    version: 0.1.0
    diagnostics:
      flutter_style_expiring_todos: true
      expired_todo: true
      unresolved_todo_condition: true

linter:
  rules:
    flutter_style_todos: false
```

Set a diagnostic to `false` to disable it. Restart the analysis server after
adding or changing plugin configuration (for example, **Dart: Restart Analysis
Server** in VS Code).

## TODO syntax

Two forms are accepted:

```dart
// TODO(username): message                  <- Flutter style; never expires
// TODO(username)[condition, ...]: message  <- one or more expiry conditions
```

- A username must match `[a-zA-Z0-9][-a-zA-Z0-9.]*`.
- In the conditional form, `)` and `[` must be adjacent. Conditions are
  separated by `,`, optionally followed by one space; no whitespace is allowed
  inside a condition.
- Either form may end with an issue URL: `, https://...`.

```dart
// Valid:
// TODO(alice): migrate to the new API
// TODO(alice)[2026/12/31]: remove this fallback
// TODO(alice)[>=2.0.0]: drop this shim once we ship 2.0
// TODO(alice)[provider@>=7.0.0]: use the new provider API
// TODO(alice)[2026/12/31, provider@>=7.0.0]: whichever comes first
// TODO(alice)[2026/12/31]: track issue, https://github.com/org/repo/issues/42

// Invalid (flutter_style_expiring_todos):
// TODO: no username
// Todo(alice): lowercase keyword
// TODO(alice) missing colon
// TODO(alice) [2026/12/31]: space before bracket
// TODO(alice)[< 1.0.0]: unsupported operator
// TODO(alice)[2026/2/3]: date not zero-padded
// TODO(alice)[2026/02/30]: date does not exist
// TODO(alice)[2026/12/31, 2027/01/01]: two dates are not allowed
```

## Conditions

Conditions are written inside `[...]`. Only `>` and `>=` comparison operators
are accepted. Versions use semver: `1` and `5.3` mean `1.0.0` and `5.3.0`, and
pre-releases sort below their corresponding release.

| Condition | Syntax | Resolves against | Reports when |
| --- | --- | --- | --- |
| **Date** | `[YYYY/MM/DD]` | Local time, at day granularity | The day after the date |
| **Project version** | `[>=1.0.0]`, `[>2]` | Top-level `version:` in `pubspec.yaml` | The project reaches the version |
| **Dependency version** | `[name@>=version]` | Resolved version in `pubspec.lock` | The dependency reaches the version |
| **Dart SDK** | `[sdk@>=version]` | Lower bound of `environment.sdk` | The lower bound reaches the version |
| **Flutter SDK** | `[flutter@>=version]` | Lower bound of `environment.flutter` | The lower bound reaches the version |

Multiple conditions can be separated by `,`. Each is evaluated independently
and can produce its own diagnostic. A date and a project-version condition may
each appear at most once; conditions for different dependencies may be
repeated.

### Evaluation details

- A date is valid on its due date and expires on the following local day.
- Version conditions use strict (`>`) or inclusive (`>=`) semver precedence.
- SDK and Flutter environment constraints are ranges. Their lower bounds are
  used: `^3.11.0` resolves to `3.11.0` and `>=3.10.0 <4.0.0` resolves to
  `3.10.0`.
- An unbounded-below environment constraint such as `any` has no lower bound.

### Unresolved conditions

`unresolved_todo_condition` reports the following cases:

- A dependency is absent from `pubspec.lock`.
- A project-version condition has no top-level `version:`.
- An SDK or Flutter condition has no matching environment entry or no lower
  bound.

Files outside a pub package (with no ancestor `pubspec.yaml`) silently skip
version conditions.

## Compatibility and scope

`flutter_style_expiring_todos` is compatible with the official
`flutter_style_todos` rule, except that it additionally accepts
`// TODO(username)[condition, ...]: message`. Disable the official lint to
avoid it reporting that extended form.

The design is based on
[`eslint-plugin-unicorn/expiring-todo-comments`](https://github.com/sindresorhus/eslint-plugin-unicorn/blob/main/docs/rules/expiring-todo-comments.md),
using pub equivalents: resolved dependency versions from `pubspec.lock` and
SDK lower bounds from `pubspec.yaml`. Its `[+package]` and `[-package]`
conditions are not currently implemented.

## CI

Plugin diagnostics use **INFO** severity, matching `flutter_style_todos`. Make
them fail CI with:

```sh
dart analyze --fatal-infos
```

If date or version expiry should not fail CI, replace the plugin declaration
with a configuration that disables `expired_todo`:

```yaml
plugins:
  flutter_style_expiring_todos:
    version: 0.1.0
    diagnostics:
      expired_todo: false
```

`flutter_style_expiring_todos` and `unresolved_todo_condition` remain enabled.
This setting affects both CI and the IDE. In a pub workspace, configure each
package from its own `analysis_options.yaml` as needed.

## Command-line usage

The package also includes a CLI that recursively scans Dart files and prints
expired TODOs in a compact, CI-friendly format inspired by
[`reminder-lint`](https://github.com/CyberAgent/reminder-lint):

```sh
dart run :flutter_style_expiring_todos_cli check-expired-todos
```

```text
./lib/main.dart:12 // TODO(alice)[2026/07/20]: remove fallback
```

The command exits with status `1` when at least one expired TODO is found and
`0` otherwise. Pass one or more files or directories to limit the scan:

```sh
dart run :flutter_style_expiring_todos_cli check-expired-todos \
  lib test/example.dart
```

Only `.dart` files are scanned. `.dart_tool`, `.git`, `.idea`, `.vscode`, and
`build` directories are skipped. `--date YYYY/MM/DD` overrides the evaluation
date, which is useful for deterministic checks.

```sh
dart run :flutter_style_expiring_todos_cli check-expired-todos \
  --date 2026/07/23 lib
```

By default, each finding includes only the source line containing the TODO.
Use `--code-lines` to include more lines starting at the TODO, stopping at the
end of the file when fewer lines remain:

```sh
dart run :flutter_style_expiring_todos_cli check-expired-todos \
  --code-lines 3 lib
```

```text
./lib/main.dart:12 // TODO(alice)[2026/07/20]: remove fallback
    return legacyFallback();
    }
```

Run the CLI without a command to list available commands, or show detailed
help for the scanner command:

```sh
dart run :flutter_style_expiring_todos_cli
dart run :flutter_style_expiring_todos_cli help check-expired-todos
```

When invoking the executable from another package, use the fully qualified
target
`flutter_style_expiring_todos:flutter_style_expiring_todos_cli` instead of the
leading-colon shorthand.

## Suppress a diagnostic

Diagnostic codes are namespaced by the plugin name:

```dart
// ignore: flutter_style_expiring_todos/expired_todo
// TODO(alice)[2020/01/01]: grandfathered in, tracked elsewhere
```

`// ignore_for_file: flutter_style_expiring_todos/expired_todo` works too.

## Limitations

- Only a TODO at the start of a comment is recognized.
- Block comments are exempt from format validation, matching
  `flutter_style_todos`. A valid dated TODO at the start of a block comment is
  still expiry-checked.
- TODOs on inner lines of multi-line block comments are not detected.
- Only the first TODO in a comment is detected.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development, verification, and
compatibility-suite maintenance.

## License

MIT — see [LICENSE](LICENSE).

`test/compatibility/flutter_style_todos_official_test.dart` is ported from the
Dart SDK and retains its BSD-3-Clause copyright header.
