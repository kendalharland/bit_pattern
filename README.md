bit_pattern
==
[![Build Status](https://travis-ci.org/kharland/bit_pattern.svg?branch=master)](https://travis-ci.org/kharland/bit_pattern)

Bit sequence matchers for building emulators in Dart.

## Creating a pattern
Patterns can be created from a sequence of 0s, 1s and variable length chunks.
```dart
// Create a pattern that matches any integer whose most significant byte is
// 0x6 and whose least significant byte is anything.
var pattern = new BitPattern([0, 1, 1, 0, v(4, 'lsb')]); 
```

The pattern can be used to determine whether an integer uses an equivalent bit sequence.
```dart
pattern.matches(0x60); // == true
pattern.matches(0x6F); // == true
pattern.matches(0x50); // == false
```

Patterns can be put into groups to simplify matching multiple patterns against an integer using a PatternGroup.
```dart
var pattern0x1 = new BitPattern([0, 0, 0, 1]);
var pattern0xF = new BitPattern([1, 1, 1, 1]);
var patternGroup = new BitPatternGroup([pattern0x1, pattern0xF]);

patternGroup.match(0x1) == pattern0x1; // true
patternGroup.match(0xF) == pattern0xF; // true
patternGroup.match(0x6) == null;     // true
```

If there are multiple BitPatterns in a PatternGroup that match some integer, the group with the fewest number of
non-variable bits is returned.  If two or more matched patterns have an identical number of non-variable bits, then 
these two patterns are incompatible and a BitPatternException is raised.
```dart
var pattern0xE = new BitPattern([0, 1, 1, 1]);
var patternAny1 = new BitPattern([v(4, 'any1')]);
var patternAny2 = new BitPattern([v(4, 'any2')]);
var patternGroup = new BitPatternGroup([patternAny1, pattern0xE, patternAny2]);

patternGroup.match(0xE) == pattern0xE; // true
patternGroup.match(0xF) == patternAny2; // error! Both patternAny1 and patternAny2 match!
```
