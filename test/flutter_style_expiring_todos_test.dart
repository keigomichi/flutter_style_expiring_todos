import 'package:flutter_style_expiring_todos/flutter_style_expiring_todos.dart';
import 'package:flutter_style_expiring_todos/main.dart' as entrypoint;
import 'package:test/test.dart';

void main() {
  test('exports the plugin class used by the analysis server entrypoint', () {
    expect(entrypoint.plugin, isA<FlutterStyleExpiringTodosPlugin>());
    expect(entrypoint.plugin.name, 'flutter_style_expiring_todos');
  });
}
