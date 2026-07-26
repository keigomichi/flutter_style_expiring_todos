import 'package:flutter_style_expiring_todos/src/condition_evaluator.dart';
import 'package:flutter_style_expiring_todos/src/expiry_condition.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

Version _v(String s) => Version.parse(s);

final Matcher _met = isA<ConditionMet>();
final Matcher _notMet = same(conditionNotMet);
final Matcher _unresolved = isA<ConditionUnresolved>();

void main() {
  final today = DateTime(2026, 7, 21);

  group('DateCondition', () {
    test('past date is met', () {
      var c = DateCondition('2020/01/01', DateTime(2020, 1, 1));
      expect(evaluateCondition(c, const ProjectContext(), today), _met);
    });
    test('today is not met', () {
      var c = DateCondition('2026/07/21', today);
      expect(evaluateCondition(c, const ProjectContext(), today), _notMet);
    });
    test('future date is not met', () {
      var c = DateCondition('2026/07/22', DateTime(2026, 7, 22));
      expect(evaluateCondition(c, const ProjectContext(), today), _notMet);
    });
    test('met detail includes the formatted date', () {
      var c = DateCondition('2020/01/01', DateTime(2020, 1, 1));
      var outcome = evaluateCondition(c, const ProjectContext(), today);
      expect((outcome as ConditionMet).detail, contains('2020/01/01'));
    });
  });

  group('ProjectVersionCondition', () {
    test('actual > target with > is met', () {
      var c = ProjectVersionCondition('>1.0.0', VersionOp.greater, _v('1.0.0'));
      var ctx = ProjectContext(projectVersion: _v('1.0.1'));
      expect(evaluateCondition(c, ctx, today), _met);
    });
    test('actual == target with > is not met', () {
      var c = ProjectVersionCondition('>1.0.0', VersionOp.greater, _v('1.0.0'));
      var ctx = ProjectContext(projectVersion: _v('1.0.0'));
      expect(evaluateCondition(c, ctx, today), _notMet);
    });
    test('actual == target with >= is met', () {
      var c = ProjectVersionCondition(
        '>=1.0.0',
        VersionOp.greaterOrEqual,
        _v('1.0.0'),
      );
      var ctx = ProjectContext(projectVersion: _v('1.0.0'));
      expect(evaluateCondition(c, ctx, today), _met);
    });
    test('pre-release does not satisfy >= release', () {
      var c = ProjectVersionCondition(
        '>=1.0.0',
        VersionOp.greaterOrEqual,
        _v('1.0.0'),
      );
      var ctx = ProjectContext(projectVersion: _v('1.0.0-beta'));
      expect(evaluateCondition(c, ctx, today), _notMet);
    });
    test('release satisfies >= pre-release', () {
      var c = ProjectVersionCondition(
        '>=1.0.0-beta',
        VersionOp.greaterOrEqual,
        _v('1.0.0-beta'),
      );
      var ctx = ProjectContext(projectVersion: _v('1.0.0'));
      expect(evaluateCondition(c, ctx, today), _met);
    });
    test('unresolved when project has no version', () {
      var c = ProjectVersionCondition(
        '>=1.0.0',
        VersionOp.greaterOrEqual,
        _v('1.0.0'),
      );
      expect(evaluateCondition(c, const ProjectContext(), today), _unresolved);
    });
  });

  group('DependencyVersionCondition', () {
    final ctx = ProjectContext(
      lockedPackages: {'provider': _v('6.1.2'), 'foo': _v('0.9.0')},
    );

    test('locked version satisfies condition', () {
      var c = DependencyVersionCondition(
        'provider@>=6.0.0',
        'provider',
        VersionOp.greaterOrEqual,
        _v('6.0.0'),
      );
      expect(evaluateCondition(c, ctx, today), _met);
    });
    test('locked version below target', () {
      var c = DependencyVersionCondition(
        'foo@>=1.0.0',
        'foo',
        VersionOp.greaterOrEqual,
        _v('1.0.0'),
      );
      expect(evaluateCondition(c, ctx, today), _notMet);
    });
    test('package absent from lock is unresolved', () {
      var c = DependencyVersionCondition(
        'missing@>=1.0.0',
        'missing',
        VersionOp.greaterOrEqual,
        _v('1.0.0'),
      );
      expect(evaluateCondition(c, ctx, today), _unresolved);
    });
    test('met detail mentions the actual locked version', () {
      var c = DependencyVersionCondition(
        'provider@>=6.0.0',
        'provider',
        VersionOp.greaterOrEqual,
        _v('6.0.0'),
      );
      var outcome = evaluateCondition(c, ctx, today) as ConditionMet;
      expect(outcome.detail, contains('provider'));
      expect(outcome.detail, contains('6.1.2'));
    });
  });

  group('SdkVersionCondition', () {
    test('lower bound satisfies condition', () {
      var c = SdkVersionCondition(
        'sdk@>=3.10.0',
        VersionOp.greaterOrEqual,
        _v('3.10.0'),
      );
      var ctx = ProjectContext(sdkLowerBound: _v('3.11.0'));
      expect(evaluateCondition(c, ctx, today), _met);
    });
    test('lower bound below target', () {
      var c = SdkVersionCondition(
        'sdk@>=3.20.0',
        VersionOp.greaterOrEqual,
        _v('3.20.0'),
      );
      var ctx = ProjectContext(sdkLowerBound: _v('3.11.0'));
      expect(evaluateCondition(c, ctx, today), _notMet);
    });
    test('missing sdk lower bound is unresolved', () {
      var c = SdkVersionCondition(
        'sdk@>=3.10.0',
        VersionOp.greaterOrEqual,
        _v('3.10.0'),
      );
      expect(evaluateCondition(c, const ProjectContext(), today), _unresolved);
    });
  });

  group('FlutterVersionCondition', () {
    test('lower bound satisfies condition', () {
      var c = FlutterVersionCondition(
        'flutter@>=3.38.0',
        VersionOp.greaterOrEqual,
        _v('3.38.0'),
      );
      var ctx = ProjectContext(flutterLowerBound: _v('3.40.0'));
      expect(evaluateCondition(c, ctx, today), _met);
    });
    test('missing flutter lower bound is unresolved', () {
      var c = FlutterVersionCondition(
        'flutter@>=3.38.0',
        VersionOp.greaterOrEqual,
        _v('3.38.0'),
      );
      expect(evaluateCondition(c, const ProjectContext(), today), _unresolved);
    });
  });
}
