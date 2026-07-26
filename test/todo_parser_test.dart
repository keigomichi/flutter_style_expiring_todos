import 'package:flutter_style_expiring_todos/src/expiry_condition.dart';
import 'package:flutter_style_expiring_todos/src/todo_parser.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

Version _v(String s) => Version.parse(s);

/// A table row for a [parseTodo] expectation.
final class _Case {
  const _Case(this.description, this.content, this.expected);

  final String description;
  final String content;
  final Matcher expected;
}

TypeMatcher<ValidTodo> _valid({
  Object? username,
  Object? message,
  Object? url = _unset,
}) {
  var matcher = isA<ValidTodo>();
  if (username != null) {
    matcher = matcher.having((t) => t.username, 'username', username);
  }
  if (message != null) {
    matcher = matcher.having((t) => t.message, 'message', message);
  }
  if (!identical(url, _unset)) {
    matcher = matcher.having((t) => t.url, 'url', url);
  }
  return matcher;
}

const Object _unset = Object();

final Matcher _badFormat = isA<MalformedTodo>().having(
  (t) => t.reason,
  'reason',
  MalformedTodoReason.badFormat,
);

final Matcher _invalidCalendarDate = isA<MalformedTodo>().having(
  (t) => t.reason,
  'reason',
  MalformedTodoReason.invalidCalendarDate,
);

final Matcher _invalidCondition = isA<MalformedTodo>().having(
  (t) => t.reason,
  'reason',
  MalformedTodoReason.invalidCondition,
);

final Matcher _duplicateCondition = isA<MalformedTodo>().having(
  (t) => t.reason,
  'reason',
  MalformedTodoReason.duplicateCondition,
);

final Matcher _notTodo = isA<NotTodo>();

void main() {
  group('parseTodo', () {
    group('ValidTodo', () {
      final cases = <_Case>[
        _Case(
          'extended form with message and url',
          '// TODO(alice)[2026/07/21]: fix, https://github.com/org/repo/issues/123',
          _valid(
            username: 'alice',
            message: 'fix',
            url: 'https://github.com/org/repo/issues/123',
          ),
        ),
        _Case(
          'extended form without url',
          '// TODO(alice)[2026/07/21]: fix',
          _valid(username: 'alice', message: 'fix', url: null),
        ),
        _Case(
          'official (dateless) form',
          '// TODO(alice): fix',
          _valid(username: 'alice', url: null),
        ),
        _Case(
          'official form, generic username',
          '// TODO(somebody): something',
          _valid(username: 'somebody', message: 'something'),
        ),
        _Case(
          'username with dots',
          '// TODO(user.name): bla',
          _valid(username: 'user.name', message: 'bla'),
        ),
        _Case(
          'username with hyphens',
          '// TODO(user-name): bla',
          _valid(username: 'user-name', message: 'bla'),
        ),
        _Case(
          'no space after //',
          '//TODO(somebody): something',
          _valid(username: 'somebody', message: 'something'),
        ),
        _Case(
          'official form with trailing url',
          '// TODO(somebody): something, https://github.com/flutter/flutter',
          _valid(
            message: 'something',
            url: 'https://github.com/flutter/flutter',
          ),
        ),
        _Case(
          'trailing non-http(s) link stays in the message',
          '// TODO(somebody): something, github.com/flutter/flutter',
          _valid(message: 'something, github.com/flutter/flutter', url: null),
        ),
        _Case(
          'empty message with trailing space',
          '// TODO(somebody): ',
          _valid(message: ''),
        ),
        _Case(
          'real leap day',
          '// TODO(a)[2028/02/29]: leap',
          _valid(username: 'a'),
        ),
        _Case(
          'single-line block comment, extended form',
          '/* TODO(a)[2026/07/21]: block */',
          _valid(message: 'block'),
        ),
        _Case(
          'single-line block comment, official form',
          '/* TODO(a): block */',
          _valid(),
        ),
        _Case(
          'multi-line block comment keeps only the first line',
          '/* TODO(a)[2020/01/01]: first\n more\n*/',
          _valid(message: 'first'),
        ),
        _Case(
          'CRLF block comment trims the trailing carriage return',
          '/* TODO(a)[2020/01/01]: fix\r\n rest */',
          _valid(message: 'fix'),
        ),
        _Case(
          'project version condition',
          '// TODO(alice)[>=1.0.0]: fix',
          _valid(username: 'alice', message: 'fix'),
        ),
        _Case(
          'dependency version condition',
          '// TODO(alice)[provider@>=6.0.0]: fix',
          _valid(username: 'alice', message: 'fix'),
        ),
        _Case(
          'sdk condition',
          '// TODO(alice)[sdk@>=3.10.0]: fix',
          _valid(username: 'alice', message: 'fix'),
        ),
        _Case(
          'flutter condition',
          '// TODO(alice)[flutter@>=3.38.0]: fix',
          _valid(username: 'alice', message: 'fix'),
        ),
        _Case(
          'date and dependency combined',
          '// TODO(alice)[2026/07/21, provider@>=6.0.0]: fix',
          _valid(username: 'alice', message: 'fix'),
        ),
      ];

      for (final c in cases) {
        test(c.description, () {
          expect(parseTodo(c.content), c.expected);
        });
      }
    });

    group('MalformedTodo badFormat', () {
      final cases = <_Case>[
        _Case('no username', '// TODO: fix', _badFormat),
        _Case('no colon', '// TODO something', _badFormat),
        _Case('bare TODO', '// TODO', _badFormat),
        _Case('bare TODO without space', '//TODO', _badFormat),
        _Case(
          'missing colon after parens',
          '// TODO(somebody) something',
          _badFormat,
        ),
        _Case('space before colon', '// TODO(user) : bla', _badFormat),
        _Case('colon before parens', '// TODO:(user): bla', _badFormat),
        _Case(
          'no trailing space after colon',
          '// TODO(somebody):',
          _badFormat,
        ),
        _Case(
          'no trailing space, no space after //',
          '//TODO(somebody):',
          _badFormat,
        ),
        _Case('lowercase todo', '// todo(a)[2026/07/21]: x', _badFormat),
        _Case('capitalized Todo', '// Todo(somebody): something', _badFormat),
        _Case('mixed-case ToDo', '// ToDo(somebody): something', _badFormat),
        _Case('two usernames', '// TODO(user1,user2): bla', _badFormat),
        _Case('issue number as username', '// TODO(#12357): bla', _badFormat),
        _Case(
          'space between ) and [',
          '// TODO(alice) [2026/07/21]: fix',
          _badFormat,
        ),
        _Case(
          'missing colon after ]',
          '// TODO(alice)[2026/07/21] fix',
          _badFormat,
        ),
        _Case('date without username', '// TODO[2026/07/21]: fix', _badFormat),
        _Case('doc comment (three slashes)', '/// TODO(user): bla', _badFormat),
        _Case(
          'block comment without accepted form',
          '/* TODO bla */',
          _badFormat,
        ),
        _Case(
          'doc block comment without accepted form',
          '/** TODO bla **/',
          _badFormat,
        ),
      ];

      for (final c in cases) {
        test(c.description, () {
          expect(parseTodo(c.content), c.expected);
        });
      }
    });

    group('MalformedTodo invalidCondition', () {
      // The extended shape matches (username, brackets, colon, message), but
      // the `[...]` contents can't be parsed as a condition list.
      final cases = <_Case>[
        _Case(
          'date missing the year',
          '// TODO(a)[07/21]: x',
          _invalidCondition,
        ),
        _Case(
          'date not zero-padded',
          '// TODO(a)[2026/7/1]: x',
          _invalidCondition,
        ),
        _Case(
          'spaces inside brackets',
          '// TODO(alice)[ 2026/07/21 ]: fix',
          _invalidCondition,
        ),
        _Case(
          'unsupported operator',
          '// TODO(alice)[<1.0.0]: fix',
          _invalidCondition,
        ),
        _Case(
          'whitespace after operator',
          '// TODO(alice)[>= 1.0.0]: fix',
          _invalidCondition,
        ),
        _Case(
          'uppercase package name',
          '// TODO(alice)[Provider@>=6.0.0]: fix',
          _invalidCondition,
        ),
        _Case(
          'trailing comma',
          '// TODO(alice)[2026/07/21,]: fix',
          _invalidCondition,
        ),
      ];

      for (final c in cases) {
        test(c.description, () {
          expect(parseTodo(c.content), c.expected);
        });
      }
    });

    group('MalformedTodo duplicateCondition', () {
      final cases = <_Case>[
        _Case(
          'two dates',
          '// TODO(a)[2026/07/21, 2026/12/31]: x',
          _duplicateCondition,
        ),
        _Case(
          'two project versions',
          '// TODO(a)[>=1.0.0, >=2.0.0]: x',
          _duplicateCondition,
        ),
      ];

      for (final c in cases) {
        test(c.description, () {
          expect(parseTodo(c.content), c.expected);
        });
      }
    });

    group('MalformedTodo invalidCalendarDate', () {
      final cases = <_Case>[
        _Case(
          'February 30th',
          '// TODO(a)[2026/02/30]: x',
          _invalidCalendarDate,
        ),
        _Case('month 13', '// TODO(a)[2026/13/01]: x', _invalidCalendarDate),
        _Case(
          'leap day in a non-leap year',
          '// TODO(a)[2027/02/29]: x',
          _invalidCalendarDate,
        ),
      ];

      for (final c in cases) {
        test(c.description, () {
          expect(parseTodo(c.content), c.expected);
        });
      }
    });

    group('NotTodo', () {
      final cases = <_Case>[
        _Case('ordinary comment', '// ordinary comment', _notTodo),
        _Case('TODO not at the start', '// comment TODO(user): bla', _notTodo),
        _Case(
          'second // breaks the trigger',
          '// // TODO(somebody): something',
          _notTodo,
        ),
        _Case('regular block comment', '/* regular block */', _notTodo),
      ];

      for (final c in cases) {
        test(c.description, () {
          expect(parseTodo(c.content), c.expected);
        });
      }
    });
  });

  group('ValidTodo.conditions', () {
    test('official form has empty conditions', () {
      var todo = parseTodo('// TODO(alice): fix') as ValidTodo;
      expect(todo.conditions, isEmpty);
    });
    test('date-only condition', () {
      var todo = parseTodo('// TODO(alice)[2026/07/21]: fix') as ValidTodo;
      expect(todo.conditions, [isA<DateCondition>()]);
    });
    test('mixed conditions preserve order', () {
      var todo =
          parseTodo(
                '// TODO(a)[2026/07/21, provider@>=6.0.0, sdk@>=3.10.0]: fix',
              )
              as ValidTodo;
      expect(todo.conditions, hasLength(3));
      expect(todo.conditions[0], isA<DateCondition>());
      expect(
        todo.conditions[1],
        isA<DependencyVersionCondition>().having(
          (c) => c.packageName,
          'name',
          'provider',
        ),
      );
      expect(todo.conditions[2], isA<SdkVersionCondition>());
    });
    test('project version target parses correctly', () {
      var todo = parseTodo('// TODO(a)[>=1.2.3]: fix') as ValidTodo;
      expect(todo.conditions, [
        isA<ProjectVersionCondition>()
            .having((c) => c.op, 'op', VersionOp.greaterOrEqual)
            .having((c) => c.target, 'target', _v('1.2.3')),
      ]);
    });
  });

  group('invalidTodo', () {
    const reported = <String>[
      '// TODO: fix',
      '/// TODO(user): bla',
      '// TODO(a)[2026/02/30]: x',
      '// todo(x): y',
    ];
    const notReported = <String>[
      '// TODO(alice): fix',
      '// TODO(alice)[2026/07/21]: fix',
      '// ordinary comment',
      '// // TODO(somebody): something',
      // Block comments are never reported by the format rule: the trigger
      // only matches `//` comments.
      '/* TODO bla */',
      '/* TODO(a)[2020/01/01]: x */',
    ];

    for (final content in reported) {
      test('reports "$content"', () {
        expect(invalidTodo(content), isTrue);
      });
    }
    for (final content in notReported) {
      test('does not report "$content"', () {
        expect(invalidTodo(content), isFalse);
      });
    }
  });

  group('isTodoTrigger', () {
    const triggering = <String>['// TODO x', '//todo x', '/// TODO x'];
    const nonTriggering = <String>['/* TODO x */', '// x TODO'];

    for (final content in triggering) {
      test('triggers on "$content"', () {
        expect(isTodoTrigger(content), isTrue);
      });
    }
    for (final content in nonTriggering) {
      test('does not trigger on "$content"', () {
        expect(isTodoTrigger(content), isFalse);
      });
    }
  });
}
