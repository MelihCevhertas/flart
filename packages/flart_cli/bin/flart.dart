import 'dart:io';

import 'package:flart_cli/runner.dart';

Future<void> main(List<String> args) async {
  final code = await runFlart(args);
  // Flush before exit — `exit` skips Dart's normal shutdown.
  await stdout.flush();
  await stderr.flush();
  exit(code);
}
