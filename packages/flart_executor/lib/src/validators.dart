/// Mod-A Dart import rule check (Plan Section 4.4).
///
/// Returns `null` when [code] passes the rule, otherwise an actionable error
/// message. Rejects:
/// - `import 'package:...'` — no pubspec, can't resolve packages
/// - `import '../foo.dart'` or `import './foo.dart'` — script lives in a
///   tmp dir, project-relative paths don't make sense
///
/// `dart:*` imports are allowed. Detection is line-based: leading whitespace
/// is fine, anything in a comment or string literal is ignored because the
/// regex anchors to the start of a line followed by the `import` keyword.
String? validateDartImports(String code) {
  final pattern = RegExp(
    r"""^\s*import\s+['"](package:|\.\./|\./)""",
    multiLine: true,
  );
  if (!pattern.hasMatch(code)) return null;
  return 'flart exec dart: package: and relative imports not supported in mod A.\n'
      'Allowed: dart:core, dart:io, dart:convert, dart:async, dart:math, dart:typed_data.\n'
      'Use bash/python for tasks that need project dependencies.';
}
