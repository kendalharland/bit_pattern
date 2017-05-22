library bit_pattern;

import 'package:binary/binary.dart';
import 'package:collection/collection.dart';

/// Returns a variable chunk of a [BitPattern] with [length] and [name].
///
/// Both [name] and [length] are used when converting a [BitPattern] to a
/// string.
_Variable v(int length, String name) => new _Variable(length, name);

/// Allows matching integer values against a collection of [BitPattern].
class BitPatternGroup {
  final Iterable<BitPattern> _patterns;

  BitPatternGroup(this._patterns);

  /// Returns the [BitPattern] that matches [bits].
  ///
  /// If no patterns match, [null] is returned.  If multiple patterns match
  /// [bits], the algorithm for determining which pattern to return is as
  /// follows:
  ///
  /// Assume we have two matched patterns A and B. Then...
  /// * If A and B have the exact same non-variable bit-pattern, a
  ///   [BitPatternException] is raised.
  /// * If the number of non-variable bits in A is greater than the number of
  ///   non-variable bits in B, A is returned.  In the reverse situation, B is
  ///   returned.
  ///
  /// Assume we have N matched patterns, where N > 2. Then we
  /// Note that it is impossible for the number of non-variable bits in A to be
  /// equal to the number of non-variable bits in B, when A and B have different
  /// non-variable bit patterns.  In this case, A or B would not have matched
  /// the given bit string.
  BitPattern match(int bits) {
    var allMatches = _patterns.where((p) => p.matches(bits)).toList();
    BitPattern matched;

    if (allMatches.isEmpty) {
      return null;
    } else if (allMatches.length > 1) {
      BitPattern champion = allMatches.removeLast();
      BitPattern challenger;

      while (allMatches.isNotEmpty) {
        challenger = allMatches.removeLast();
        var specificity = challenger._compareSpecificity(champion);
        if (specificity == _Specificity.greater) {
          champion = challenger;
        } else if (specificity == _Specificity.lesser) {
          continue;
        } else if (specificity == _Specificity.equal) {
          throw new Exception();
        }
      }
      matched = champion;
    } else {
      matched = allMatches.single;
    }

    return matched;
  }
}

/// Represents a sequence of binary digits.
///
/// The sequence may contain only 0's and 1's and variable length chunks.  The
/// pattern's indices can be queried using [is0], [is1] and [isVar], and the
/// pattern can be matched against integer values.  Variable sections in a
/// sequence can be represented using [v].
class BitPattern {
  static const _F0 = '0';
  static const _F1 = '1';
  static const _FVAR = 'v';

  final List _parts;
  final _flattened = <String>[];
  String _asString;

  BitPattern(this._parts) {
    for (var part in _parts) {
      if (part is int) {
        assert(part == 0 || part == 1);
        _flattened.add(part == 1 ? _F1 : _F0);
      } else {
        assert(part is _Variable);
        _flattened.addAll(new List.generate(part.length, (_) => _FVAR));
      }
    }
  }

  @override
  String toString() {
    _asString ??= _computeAsString();
    return _asString;
  }

  /// The number of bits in this pattern.
  int get length => _flattened.length;

  /// Returns true iff bit [n] is 0.
  bool is0(int n) => n < length && _flattened[length - n - 1] == _F0;

  /// Returns true iff bit [n] is 1.
  bool is1(int n) => n < length && _flattened[length - n - 1] == _F1;

  /// Returns true iff bit [n] is variable.
  bool isVar(int n) => n < length && _flattened[length - n - 1] == _FVAR;

  /// Returns true iff the integer [bits] matches this pattern.
  ///
  /// This pattern will only compare bits in the closed interval (0, [length]).
  bool matches(int bits) {
    for (int i = 0; i < length; i++) {
      var bit = getBit(bits, i);
      if (isVar(i)) continue;
      if (bit == 0 && !is0(i) || bit == 1 && !is1(i)) return false;
    }
    return true;
  }

  /// Computes whether this pattern is more specific than [other].
  ///
  /// Returns [_Specificity.greater] if this pattern has more non-variable bits
  /// than [other].  Returns [_Specificity.lesser] in the reverse situation.
  /// Returns [_Specificity.equal] If this pattern has the same number of
  /// non-variable bits as [other].
  _Specificity _compareSpecificity(BitPattern other) {
    bool _isNotVar(p) => p is! _Variable;

    var nonVarBits = _parts.where(_isNotVar).toList();
    var otherNonVarBits = other._parts.where(_isNotVar).toList();

    if (new ListEquality().equals(nonVarBits, otherNonVarBits)) {
      return _Specificity.equal;
    } else if (nonVarBits.length > otherNonVarBits.length) {
      return _Specificity.greater;
    } else {
      return _Specificity.lesser;
    }
  }

  String _computeAsString() {
    final buffer = new StringBuffer();

    _parts.forEach((part) {
      if (part == 0 || part == 1) {
        buffer.write('$part');
      } else {
        assert(part is _Variable);
        if (part.length > 1) {
          buffer.write('${part.name}{${part.length}}');
        } else {
          buffer.write('${part.name}');
        }
      }
      buffer.write(' ');
    });

    return buffer.toString().trimRight();
  }
}

/// Represents a variable chunk of bits in a [BitPattern].
class _Variable {
  /// The number of bits in this chunk.
  final int length;

  /// The name of this chunk.
  final String name;

  _Variable(this.length, this.name);
}

/// A measure of how specific a [BitPattern] is relative another [BitPattern].
enum _Specificity { greater, lesser, equal }
