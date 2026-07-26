/// Analyzer plugin registration for Flutter-style expiring TODO rules.
library;

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'rules/expired_todo.dart';
import 'rules/flutter_style_expiring_todos.dart';
import 'rules/unresolved_todo_condition.dart';

class FlutterStyleExpiringTodosPlugin extends Plugin {
  @override
  String get name => 'flutter_style_expiring_todos';

  @override
  void register(PluginRegistry registry) {
    // All rules are warnings, enabled by default; consumers can disable
    // them individually in the `diagnostics` section of the plugin config.
    registry.registerWarningRule(FlutterStyleExpiringTodos());
    registry.registerWarningRule(ExpiredTodo());
    registry.registerWarningRule(UnresolvedTodoCondition());
  }
}
