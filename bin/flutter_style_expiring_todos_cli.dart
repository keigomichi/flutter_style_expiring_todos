import 'dart:io';

import 'package:flutter_style_expiring_todos/flutter_style_expiring_todos_cli.dart'
    as flutter_style_expiring_todos_cli;

Future<void> main(List<String> arguments) async {
  exitCode = await flutter_style_expiring_todos_cli.run(arguments);
}
