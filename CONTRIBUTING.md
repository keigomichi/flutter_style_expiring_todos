# Contributing

Thanks for contributing to `flutter_style_expiring_todos`.

## Requirements

Use Dart 3.11 or later. CI runs the test suite against both the minimum
supported SDK (3.11.0) with the lowest allowed dependencies and the latest
stable SDK with the latest allowed dependencies. Formatting runs once on the
latest stable SDK so that a single formatter defines the expected result.

This repository is a published package, so `pubspec.lock` is not committed.
CI validates the dependency range declared in `pubspec.yaml` instead of
reproducing one locked dependency graph.

## Set up and verify

From the repository root, resolve the latest allowed dependencies and run the
normal checks:

```sh
dart pub upgrade
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos lib test
dart test
```

The `tool/fixture` projects intentionally contain analyzer violations for
integration tests, so analysis is scoped to `lib` and `test`.

Keep user-facing documentation in [README.md](README.md) up to date.

## Pull request titles

Pull request titles follow the Conventional Commits format because squash
merges become the commit history used by Release Please:

```text
<type>[optional scope][!]: <description>
```

Use one of these types:

- `feat` for a new user-facing feature.
- `fix` for a user-facing bug fix.
- `perf` for a user-facing performance improvement.
- `revert` for reverting a prior change.
- `build`, `chore`, `ci`, `docs`, `refactor`, `style`, or `test` for changes
  that do not need their own release note.

Add `!` before the colon, or a `BREAKING CHANGE:` footer, for a breaking
change. Scopes are optional.

## Release validation

CI verifies every pull request with both the lowest and latest allowed
dependencies. It also runs a publish dry run. To perform the same release
validation locally:

```sh
dart pub downgrade
dart analyze --fatal-infos lib test
dart test
dart pub upgrade
dart pub publish --dry-run
```

Do not update the top-level `version` in `pubspec.yaml` or released sections in
`CHANGELOG.md` as part of a normal pull request. Release Please owns those
changes and keeps the release manifest in sync.

After releasable changes reach `main`, Release Please creates or updates a
release pull request. Merging that pull request creates the version tag and
GitHub Release. The tag then publishes the same version to pub.dev through
GitHub Actions using OIDC. Do not run `dart pub publish` manually for later
versions.

## Official compatibility suite

`test/compatibility/flutter_style_todos_official_test.dart` is ported from the
Dart SDK's `flutter_style_todos` tests:

- Source: [dart-lang/sdk](https://github.com/dart-lang/sdk) at
  `c6444fd86f62eb9b3b2885d10916293aa98b43b8`,
  `pkg/linter/test/rules/flutter_style_todos_test.dart`.
- License: BSD-3-Clause. Keep the original copyright header in the ported
  file.

When updating the compatibility suite, re-diff it against the upstream source,
preserve the original test names and copyright header, and confirm that the
official cases continue to pass unchanged. The conditional
`// TODO(username)[condition, ...]: message` form is intentionally outside the
official suite because the official rule rejects it.
