import 'package:flutter_style_expiring_todos/src/condition_parser.dart';
import 'package:flutter_style_expiring_todos/src/expiry_condition.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

/// A table row for a [parseConditions] expectation.
final class _Case {
  const _Case(this.description, this.content, this.expected);

  final String description;
  final String content;
  final Matcher expected;
}

TypeMatcher<ConditionsOk> _ok(List<Matcher> conditions) => isA<ConditionsOk>()
    .having((r) => r.conditions, 'conditions', containsAllInOrder(conditions));

TypeMatcher<ConditionsMalformed> _bad(ConditionParseError error) =>
    isA<ConditionsMalformed>().having((r) => r.error, 'error', error);

TypeMatcher<DateCondition> _date(DateTime date) =>
    isA<DateCondition>().having((c) => c.date, 'date', date);

TypeMatcher<ProjectVersionCondition> _proj(VersionOp op, String v) =>
    isA<ProjectVersionCondition>()
        .having((c) => c.op, 'op', op)
        .having((c) => c.target, 'target', Version.parse(v));

TypeMatcher<DependencyVersionCondition> _dep(
  String name,
  VersionOp op,
  String v,
) => isA<DependencyVersionCondition>()
    .having((c) => c.packageName, 'name', name)
    .having((c) => c.op, 'op', op)
    .having((c) => c.target, 'target', Version.parse(v));

TypeMatcher<SdkVersionCondition> _sdk(VersionOp op, String v) =>
    isA<SdkVersionCondition>()
        .having((c) => c.op, 'op', op)
        .having((c) => c.target, 'target', Version.parse(v));

TypeMatcher<FlutterVersionCondition> _flutter(VersionOp op, String v) =>
    isA<FlutterVersionCondition>()
        .having((c) => c.op, 'op', op)
        .having((c) => c.target, 'target', Version.parse(v));

void main() {
  group('parseConditions', () {
    group('ConditionsOk', () {
      final cases = <_Case>[
        _Case('single date', '2026/07/21', _ok([_date(DateTime(2026, 7, 21))])),
        _Case(
          'project version (>=) full form',
          '>=1.2.3',
          _ok([_proj(VersionOp.greaterOrEqual, '1.2.3')]),
        ),
        _Case(
          'project version (>) major only',
          '>2',
          _ok([_proj(VersionOp.greater, '2.0.0')]),
        ),
        _Case(
          'project version major.minor',
          '>=5.3',
          _ok([_proj(VersionOp.greaterOrEqual, '5.3.0')]),
        ),
        _Case(
          'project version pre-release',
          '>=1.0.0-beta',
          _ok([_proj(VersionOp.greaterOrEqual, '1.0.0-beta')]),
        ),
        _Case(
          'dependency version',
          'provider@>=6.0.0',
          _ok([_dep('provider', VersionOp.greaterOrEqual, '6.0.0')]),
        ),
        _Case(
          'dependency version greater',
          'riverpod@>3',
          _ok([_dep('riverpod', VersionOp.greater, '3.0.0')]),
        ),
        _Case(
          'sdk condition',
          'sdk@>=3.10.0',
          _ok([_sdk(VersionOp.greaterOrEqual, '3.10.0')]),
        ),
        _Case(
          'flutter condition',
          'flutter@>=3.38.0',
          _ok([_flutter(VersionOp.greaterOrEqual, '3.38.0')]),
        ),
        _Case(
          'two conditions with space after comma',
          '2026/07/21, provider@>=6.0.0',
          _ok([
            _date(DateTime(2026, 7, 21)),
            _dep('provider', VersionOp.greaterOrEqual, '6.0.0'),
          ]),
        ),
        _Case(
          'two conditions no space after comma',
          '2026/07/21,provider@>=6.0.0',
          _ok([
            _date(DateTime(2026, 7, 21)),
            _dep('provider', VersionOp.greaterOrEqual, '6.0.0'),
          ]),
        ),
        _Case(
          'multiple different-type version conditions',
          'sdk@>=3.10.0, flutter@>=3.38.0, provider@>=6.0.0',
          _ok([
            _sdk(VersionOp.greaterOrEqual, '3.10.0'),
            _flutter(VersionOp.greaterOrEqual, '3.38.0'),
            _dep('provider', VersionOp.greaterOrEqual, '6.0.0'),
          ]),
        ),
        _Case(
          'two dependency conditions on different packages',
          'provider@>=6.0.0, riverpod@>3',
          _ok([
            _dep('provider', VersionOp.greaterOrEqual, '6.0.0'),
            _dep('riverpod', VersionOp.greater, '3.0.0'),
          ]),
        ),
      ];

      for (final c in cases) {
        test(c.description, () {
          expect(parseConditions(c.content), c.expected);
        });
      }
    });

    test('raw text is preserved on each condition', () {
      var result = parseConditions('2026/07/21, provider@>=6.0.0');
      expect(result, isA<ConditionsOk>());
      var ok = result as ConditionsOk;
      expect(ok.conditions[0].raw, '2026/07/21');
      expect(ok.conditions[1].raw, 'provider@>=6.0.0');
    });

    group('invalidCondition', () {
      final cases = <String>[
        '',
        ' ',
        '  ',
        '2026/7/21', // non-padded date
        '2026/07', // partial date
        '<1.0.0', // unsupported operator
        '=1.0.0', // unsupported operator
        '~1.0.0', // unsupported operator
        '^1.0.0', // unsupported operator
        '1.0.0', // no operator
        '> 1.0.0', // whitespace after op
        'provider @>=6.0.0', // whitespace around @
        'provider@ >=6.0.0', // whitespace after @
        'provider@>= 6.0.0', // whitespace after op
        'Provider@>=6.0.0', // uppercase package name
        '_provider@>=6.0.0', // package name must start with lowercase letter
        '1provider@>=6.0.0', // package name must start with letter
        'provider@', // missing op+version
        'provider@>=', // missing version
        '@>=1.0.0', // missing name
        '>=', // missing version
        '>=abc', // non-numeric version
        '>=1.a.0', // non-numeric component
        '>=-beta', // pre-release without core
        '>=1-beta', // pre-release requires full X.Y.Z
        '>=1.2-beta', // pre-release requires full X.Y.Z
        '2026/07/21,', // trailing empty token
        ',2026/07/21', // leading empty token
        '2026/07/21,,provider@>=6.0.0', // double comma
        '2026/07/21,  provider@>=6.0.0', // two spaces after comma
        ' 2026/07/21', // leading whitespace
        '2026/07/21 ', // trailing whitespace
      ];

      for (final content in cases) {
        test('"$content"', () {
          expect(
            parseConditions(content),
            _bad(ConditionParseError.invalidCondition),
          );
        });
      }
    });

    group('invalidCalendarDate', () {
      const cases = <String>[
        '2026/02/30',
        '2026/13/01',
        '2027/02/29',
        '2026/07/21, 2026/02/30', // second is invalid
      ];

      for (final content in cases) {
        test('"$content"', () {
          expect(
            parseConditions(content),
            _bad(ConditionParseError.invalidCalendarDate),
          );
        });
      }
    });

    test('duplicateDate', () {
      expect(
        parseConditions('2026/07/21, 2026/07/22'),
        _bad(ConditionParseError.duplicateDate),
      );
    });

    test('duplicateProjectVersion', () {
      expect(
        parseConditions('>=1.0.0, >=2.0.0'),
        _bad(ConditionParseError.duplicateProjectVersion),
      );
    });

    test('duplicate dependency versions on different packages is allowed', () {
      expect(
        parseConditions('provider@>=1.0.0, provider@>=2.0.0'),
        isA<ConditionsOk>(),
      );
    });
  });

  group('VersionOp.isMetBy', () {
    test('> is strict', () {
      expect(
        VersionOp.greater.isMetBy(
          Version.parse('1.0.0'),
          Version.parse('1.0.0'),
        ),
        isFalse,
      );
      expect(
        VersionOp.greater.isMetBy(
          Version.parse('1.0.1'),
          Version.parse('1.0.0'),
        ),
        isTrue,
      );
    });
    test('>= includes equality', () {
      expect(
        VersionOp.greaterOrEqual.isMetBy(
          Version.parse('1.0.0'),
          Version.parse('1.0.0'),
        ),
        isTrue,
      );
      expect(
        VersionOp.greaterOrEqual.isMetBy(
          Version.parse('0.9.9'),
          Version.parse('1.0.0'),
        ),
        isFalse,
      );
    });
    test('pre-release precedes release', () {
      expect(
        VersionOp.greaterOrEqual.isMetBy(
          Version.parse('1.0.0-beta'),
          Version.parse('1.0.0'),
        ),
        isFalse,
      );
      expect(
        VersionOp.greaterOrEqual.isMetBy(
          Version.parse('1.0.0'),
          Version.parse('1.0.0-beta'),
        ),
        isTrue,
      );
    });
  });
}
