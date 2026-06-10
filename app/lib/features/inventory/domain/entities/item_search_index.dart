import 'package:collection/collection.dart';
import 'item.dart';

typedef _TokenEntry = ({String token, String itemId});

class ItemSearchIndex {
  final List<_TokenEntry> _entries;
  ItemSearchIndex._(this._entries);
  factory ItemSearchIndex.build(List<Item> items) {
    final entries = <_TokenEntry>[];

    for (final item in items) {
      final tokens = item.name
          .toLowerCase()
          .trim()
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty);

      for (final token in tokens) {
        entries.add((token: token, itemId: item.id));
      }
    }

    entries.sort((a, b) => a.token.compareTo(b.token));
    return ItemSearchIndex._(entries);
  }

  Set<String> query(String rawQuery) {
    final queryTokens = rawQuery
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    if (queryTokens.isEmpty) return {};

    var result = _queryOneToken(queryTokens.first);
    for (int i = 1; i < queryTokens.length; i++) {
      result = result.intersection(_queryOneToken(queryTokens[i]));
    }
    return result;
  }

  Set<String> _queryOneToken(String prefix) {
    final lo = lowerBound<_TokenEntry>(
      _entries,
      (token: prefix, itemId: ''),
      compare: (a, b) => a.token.compareTo(b.token),
    );

    final upper = _incrementLastChar(prefix);
    final hi = lowerBound<_TokenEntry>(
      _entries,
      (token: upper, itemId: ''),
      compare: (a, b) => a.token.compareTo(b.token),
    );

    final ids = <String>{};
    for (int i = lo; i < hi; i++) {
      ids.add(_entries[i].itemId);
    }
    return ids;
  }

  static String _incrementLastChar(String s) {
    final lastCode = s.codeUnitAt(s.length - 1);
    return s.substring(0, s.length - 1) + String.fromCharCode(lastCode + 1);
  }
}