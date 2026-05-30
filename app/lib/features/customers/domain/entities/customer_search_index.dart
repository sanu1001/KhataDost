import 'package:collection/collection.dart';
import 'customer.dart';

// A record: one token from a customer's name, paired with that customer's id.
// Dart's record syntax: ({String token, String customerId})
typedef _TokenEntry = ({String token, String customerId});

class CustomerSearchIndex {
  // The flat sorted list of (token, customerId) pairs — the inverted index.
  final List<_TokenEntry> _entries;

  // Private constructor — callers must use the factory.
  CustomerSearchIndex._(this._entries);

  /// Builds the index from a list of customers.
  /// Call this whenever the customer list changes (load, add, edit, delete).
  factory CustomerSearchIndex.build(List<Customer> customers) {
    final entries = <_TokenEntry>[];

    for (final customer in customers) {
      // Normalize: lowercase, trim, split on any whitespace run, drop empties.
      // "Suresh  Sen" → ["suresh", "sen"]
      final tokens = customer.name
          .toLowerCase()
          .trim()
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty);

      for (final token in tokens) {
        entries.add((token: token, customerId: customer.id));
      }
    }

    // Sort by token — this is what makes binary search possible.
    entries.sort((a, b) => a.token.compareTo(b.token));

    return CustomerSearchIndex._(entries);
  }

  /// Returns the set of customer IDs whose name contains any token
  /// starting with [rawQuery]. Pure function — no I/O, no BLoC.
  ///
  /// Multi-word queries ("sur sen") are treated as AND:
  /// only customers matching ALL query tokens are returned.
  Set<String> query(String rawQuery) {
    // Normalize the query the same way tokens were normalized.
    final queryTokens = rawQuery
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    if (queryTokens.isEmpty) return {};

    // For each query token, find matching IDs, then intersect.
    // Single-token queries (the common case) just return _queryOneToken directly.
    var result = _queryOneToken(queryTokens.first);
    for (int i = 1; i < queryTokens.length; i++) {
      result = result.intersection(_queryOneToken(queryTokens[i]));
    }
    return result;
  }

  /// Binary search for all entries whose token starts with [prefix].
  /// Returns a Set of customer IDs (deduped automatically by Set).
  Set<String> _queryOneToken(String prefix) {
    // Lower bound: first entry with token >= prefix
    final lo = lowerBound<_TokenEntry>(
      _entries,
      (token: prefix, customerId: ''),
      compare: (a, b) => a.token.compareTo(b.token),
    );

    // Upper bound: first entry with token >= (prefix with last char + 1)
    final upper = _incrementLastChar(prefix);
    final hi = lowerBound<_TokenEntry>(
      _entries,
      (token: upper, customerId: ''),
      compare: (a, b) => a.token.compareTo(b.token),
    );

    // Collect every entry in [lo, hi) — all have tokens starting with prefix.
    final ids = <String>{};
    for (int i = lo; i < hi; i++) {
      ids.add(_entries[i].customerId);
    }
    return ids;
  }

  /// Increments the last character of [s] by one code point.
  /// "sen" → "seo", "su" → "sv", "z" → "{" (still correct for comparison).
  static String _incrementLastChar(String s) {
    final lastCode = s.codeUnitAt(s.length - 1);
    return s.substring(0, s.length - 1) + String.fromCharCode(lastCode + 1);
  }
}