import 'package:binary/binary.dart';
import 'package:bit_pattern/bit_pattern.dart';
import 'package:test/test.dart';

void main() {
  group("$BitPattern", () {
    /// A bit pattern matching the 3 data-processing instruction encodings of
    /// the ARM armv4t instruction set.
    final dataProcessing = new BitPattern([
      v(4, 'cond'), // 31 - 28
      0, // 27
      0, // 26
      v(1, 'I'), // 25
      v(4, 'opcode'), // 24 - 21
      v(1, 'S'), // 20
      v(4, 'Rn'), // 19 - 16
      v(4, 'Rd'), // 15 - 12
      v(5, 'shiftAmt'), // 11 - 7
      v(2, 'shift'), // 6 - 5
      v(1, '_'), // 4
      v(4, 'Rm') // 3 - 0
    ]);

    const nonVarBits = const <int>[27, 26];

    test('length', () {
      expect(dataProcessing.length, 32);
    });

    test('toString', () {
      expect(dataProcessing.toString(),
          'cond{4} 0 0 I opcode{4} S Rn{4} Rd{4} shiftAmt{5} shift{2} _ Rm{4}');
    });

    test('is0', () {
      for (int i = 0; i < 32; i++) {
        expect(dataProcessing.is0(i), nonVarBits.contains(i), reason: '$i');
      }
    });

    test('is1', () {
      for (int i = 0; i < 32; i++) {
        expect(dataProcessing.is1(i), false, reason: '$i');
      }
    });

    test('isVar', () {
      for (int i = 0; i < 32; i++) {
        expect(dataProcessing.isVar(i), !nonVarBits.contains(i), reason: '$i');
      }
    });

    test('matches', () {
      // Various ARM armv4t data-processing instructions.
      const matchingInstructions = const <int>[
        // adds r4, r0, r2
        0xe0904002,
        // adc  r5, r1, r3
        0xe0a15003,
        // add  r0, r0, #26
        0xe280001a,
        // cmp  r1, r0
        0xe1510000,
        // bic  r9, r9, #3
        0xe3c99003,
        // bic  r3, r3, #1
        0xe3c33001,
        // mov  pc, r2
        0xe1a0f002,
        // mov  r0, #243
        0xe3a000f3,
        // cmp  r1, #0
        0xe3510000,
        // andeq r0, r0, r8, asr r0
        0x00000058,
        // andeq r1, r0, r1, asr #6
        0x00001341,
        // cmnvs r5, r0, lsl #2
        0x61750100,
        // cmnvs r5, r0, lsl #2
        0x01100962,
        // andeq r0, r0, r9
        0x00000009,
        // tsteq r8, r6, lsl #6
        0x01180306,
      ];

      matchingInstructions.forEach((instruction) {
        expect(dataProcessing.matches(instruction), true,
            reason: instruction.toRadixString(16));
      });

      // Set bit 26
      var nonMatchingInstructions = matchingInstructions
          .map((instruction) => setBit(instruction, 26))
          .toList();

      nonMatchingInstructions.forEach((instruction) {
        expect(dataProcessing.matches(instruction), false,
            reason: instruction.toRadixString(16));
      });

      // Switch to having bit 27 set
      nonMatchingInstructions = matchingInstructions
          .map((instruction) => setBit(instruction, 27))
          .toList();

      nonMatchingInstructions.forEach((instruction) {
        expect(dataProcessing.matches(instruction), false,
            reason: instruction.toRadixString(16));
      });
    });
  });

  group('$BitPatternGroup', () {
    test('match', () {
      final patternA = new BitPattern([0, 1, 0, 1]);
      final patternB = new BitPattern([0, 0, 0, 0]);
      final patternC = new BitPattern([0, v(2, 'c'), 1]);
      final patternD = new BitPattern([0, v(3, 'd')]);

      final patternGroup = new BitPatternGroup([
        patternB,
        patternA,
        patternC,
        patternD,
      ]);

      const bitsAandCandD = 0x5; // 0101
      const bitsB = 0x0; // 0000
      const bitsCandD1 = 0x1; // 0001
      const bitsCandD2 = 0x7; // 0111
      const bitsD = 0x6; // 0110

      expect(patternGroup.match(bitsAandCandD), patternA);
      expect(patternGroup.match(bitsB), patternB);
      expect(patternGroup.match(bitsCandD1), patternC);
      expect(patternGroup.match(bitsCandD2), patternC);
      expect(patternGroup.match(bitsD), patternD);
    });
  });
}
