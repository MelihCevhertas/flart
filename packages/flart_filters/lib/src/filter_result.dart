import 'package:meta/meta.dart';

/// Pure output of a [CommandFilter]. Holds the compact text destined for the
/// agent, a truncation flag, and structured metadata that will be persisted
/// alongside the invocation in the savings DB.
///
/// Metadata values must be JSON-roundtrip-safe (primitive types or lists of
/// primitives) — see Plan Section 3.3.
@immutable
class FilterResult {
  final String output;
  final bool wasTruncated;
  final Map<String, Object?> metadata;

  const FilterResult({
    required this.output,
    this.wasTruncated = false,
    this.metadata = const {},
  });
}
