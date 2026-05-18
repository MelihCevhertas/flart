import 'package:meta/meta.dart';

/// Detects a top-level `main(` declaration. Matches:
/// - `void main(`
/// - `Future main(`, `Future<void> main(`, `Future<int> main(`
/// - `main(` (no return type — valid in Dart)
/// - Leading whitespace tolerated (indented main).
@visibleForTesting
final RegExp mainDeclarationRegex = RegExp(
  r'^\s*(void\s+|Future(\s*<[^>]*>)?\s+)?main\s*\(',
  multiLine: true,
);

/// Matches an `import 'x';` statement at the start of a line. Code after the
/// semicolon on the same line is preserved (only the `import ...;` substring
/// is extracted).
@visibleForTesting
final RegExp importStatementRegex = RegExp(
  r"^\s*import\s+[^;]+;",
  multiLine: true,
);

/// Wraps a Dart script in a default `main` when none is present. Lets users
/// (and Claude routing examples in CLAUDE.md) write
/// `flart exec dart 'print("hi")'` instead of the boilerplate
/// `void main() => print("hi");`.
///
/// Wrapping rules:
/// - If a top-level `main(` is detected ([mainDeclarationRegex]), [code] is
///   returned unchanged.
/// - Otherwise import statements (which must stay top-level in Dart) are
///   extracted to the top, and the remaining body is wrapped in
///   `void main() async { ... }`.
///
/// Detection is a heuristic — `void main(` appearing inside a block comment
/// can produce a false positive (wrap skipped). In that case Dart fails to
/// compile with a clear error (no silent corruption). Validation
/// ([validateDartImports]) is independent and runs on the *original* code,
/// so mod-A allowlist is never bypassed.
String wrapDartIfNeeded(String code) {
  if (mainDeclarationRegex.hasMatch(code)) return code;

  final imports = <String>[];
  final body = code.replaceAllMapped(importStatementRegex, (m) {
    imports.add(m.group(0)!.trim());
    return '';
  });

  final importsBlock = imports.isEmpty ? '' : '${imports.join('\n')}\n\n';
  return '${importsBlock}void main() async {\n${body.trim()}\n}\n';
}
