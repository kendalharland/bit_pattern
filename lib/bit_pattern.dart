library bit_pattern;

import 'package:binary/binary.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Returns a variable bit, optionally named [name].
_Variable bit([String name = '']) => bits(1, name);

/// Returns a variable 4-bit chunk, optionally named [name].
_Variable nibble([String name = '']) => bits(4, name);

/// Returns a variable 8-bit chunk, optionally named [name].
_Variable byte([String name = '']) => bits(8, name);

/// Returns a variable chunk of a [BitPattern] with [length] and [name].
///
/// Both [name] and [length] are used when converting a [BitPattern] to a
/// string.
_Variable bits(int length, [String name = '']) => new _Variable(length, name);

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
          throw const BitPatternException();
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
/// sequence can be represented using [bits].
class BitPattern {
  final _parts = <_PatternPart>[];
  final _flattened = <String>[];
  String _asString;

  int _isSetMask = 0;
  int _nonVarMask = 0;

  BitPattern(List parts) {
    _parts.addAll(parts.map((p) => new _PatternPart.from(p)));
    _parts.forEach((part) {
      _flattened.addAll(part.flattened);
    });

    _isSetMask = _IsSetMask(this);
    _nonVarMask = _NonVarMask(this);
  }

  @override
  String toString() {
    _asString ??= _computeAsString();
    return _asString;
  }

  /// The number of bits in this pattern.
  int get length => _flattened.length;

  /// Returns true iff bit [n] is 0.
  bool is0(int n) => n < length && _flattened[length - n - 1] == _FLAT0;

  /// Returns true iff bit [n] is 1.
  bool is1(int n) => n < length && _flattened[length - n - 1] == _FLAT1;

  /// Returns true iff bit [n] is variable.
  bool isVar(int n) => n < length && _flattened[length - n - 1] == _FLATV;

  /// Returns true iff [input] matches this pattern.
  ///
  /// The comparison runs in constant time with respect to [length] and only
  /// matches against the bits on the closed interval (0, [length]).
  bool matches(int input) {
    // * Let S be the result of _IsSetMask(this).
    //
    // * Let E be the result of ~(input ^ S), then bit k of E == 1 iff bit k of
    //   input == bit k of S.
    //
    // * Let N be the result of _NonVarMask(this), then N & E == N iff the
    //   non-variable bits in this pattern are identical to their counterparts
    //   in input.
    return ~(input ^ _isSetMask) & _nonVarMask == _nonVarMask;
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
      buffer.write('$part ');
    });
    return buffer.toString().trimRight();
  }
}

class BitPatternException implements Exception {
  @literal
  const BitPatternException();
}

/// Part of a [BitPattern].  Either a 1, 0 or variable length sequence.
abstract class _PatternPart {
  factory _PatternPart.from(part) {
    if (part is int) {
      assert(part == 0 || part == 1);
      return new _Bit(part);
    } else {
      assert(part is _Variable);
      return part;
    }
  }

  /// The flattened representation of this part.
  List<String> get flattened;
}

class _Bit implements _PatternPart {
  final int bit;

  /// A single-item list containing [bit] as a string.
  @override
  final List<String> flattened;

  _Bit(this.bit) : flattened = <String>['$bit'];

  @override
  String toString() => '$bit';
}

/// Represents a variable chunk of bits in a [BitPattern].
class _Variable implements _PatternPart {
  /// The number of bits in this chunk.
  final int length;

  /// The name of this chunk.
  final String name;

  /// A single-item list containing [bit] as a string.
  @override
  final List<String> flattened;

  _Variable(this.length, this.name)
      : flattened = new List.generate(length, (_) => _FLATV);

  @override
  String toString() {
    var nameStr = name == null || name.isEmpty ? '?' : name;
    if (length > 1) {
      return '$nameStr{$length}';
    } else {
      return '$nameStr';
    }
  }
}

/// Returns the "Is set mask" for [pattern].
///
/// The Is set mask is an integer whose k'th bit == 1 iff bit k of [pattern] ==
/// 1.
///
/// Examples: (v == a variable bit)
///   _IsSetMask({1,1,1,1}) == 0xF == 1111
///   _IsSetMask({1,1,v,1}) == 0xD == 1101
///   _IsSetMask({0,0,0,0}) == 0x0 == 0000
///   _IsSetMask({1,0,1,v}) == 0xA == 1010
int _IsSetMask(BitPattern pattern) {
  int mask = 0;
  for (int i = 0; i < pattern.length; i++) {
    if (pattern.is1(i)) mask = setBit(mask, i);
  }
  return mask;
}

/// Returns the "Non-variable mask" for [pattern].
///
/// The Non-variable mask is an integer whose k'th bit == 1 iff bit k of
/// [pattern] is non-variable.
///
/// Examples: (v == a variable bit)
///   _NonVarMask({1,1,1,1}) == 0xF == 1111
///   _NonVarMask({1,1,v,1}) == 0xD == 1101
///   _NonVarMask({0,0,0,0}) == 0xF == 1111
///   _NonVarMask({1,0,1,v}) == 0xE == 1110
int _NonVarMask(BitPattern pattern) {
  int mask = 0;
  for (int i = 0; i < pattern.length; i++) {
    if (!pattern.isVar(i)) mask = setBit(mask, i);
  }
  return mask;
}

/// Flattened representation of a 1 bit
const _FLAT1 = '1';

/// Flattened representation of a 0 bit
const _FLAT0 = '0';

/// Flattened representation of a variable bit
const _FLATV = 'x';

/// A measure of how specific a [BitPattern] is relative another [BitPattern].
enum _Specificity { greater, lesser, equal }
