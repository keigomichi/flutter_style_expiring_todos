# flutter_style_expiring_todos_example

A minimal Dart app that shows the TODO forms accepted by
`flutter_style_expiring_todos`.

## What to look at

Open `lib/main.dart` in your IDE. You'll see three kinds of TODO comment:

| Line | Kind | What the plugin does |
| --- | --- | --- |
| `// TODO(alice): …` | Dateless, official Flutter style | Never expires; format-checked only |
| `// TODO(bob)[2099/12/31]: …` | Extended, future date | Reports `expired_todo` after the date passes |
| `// TODO(carol)[>=1.0.0]: …` | Extended, project-version condition | Reports `expired_todo_version` once the package reaches the version |

## Running

```sh
dart pub get
dart analyze --fatal-infos
```

The example's `analysis_options.yaml` declares the plugin by relative path
(`../`) so it always tracks this repository's source. In your own project,
depend on the published version instead:

```yaml
plugins:
  flutter_style_expiring_todos: 0.1.0

linter:
  rules:
    flutter_style_todos: false   # avoid conflict with this plugin
```

Restart the analysis server after adding the plugin so the analyzer picks
it up.
