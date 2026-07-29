import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharis_app/features/onboarding/data/branch_repository.dart';

void main() {
  const fallback = Color(0xFF123456);

  test('parseHex parses #RRGGBB with full opacity', () {
    expect(Branch.parseHex('#5D3FD3', fallback), const Color(0xFF5D3FD3));
  });

  test('parseHex accepts values without a leading #', () {
    expect(Branch.parseHex('F8B537', fallback), const Color(0xFFF8B537));
  });

  test('parseHex falls back on null or invalid input', () {
    expect(Branch.parseHex(null, fallback), fallback);
    expect(Branch.parseHex('not-a-colour', fallback), fallback);
  });

  test('toHex round-trips a colour', () {
    expect(Branch.toHex(const Color(0xFF5D3FD3)), '#5D3FD3');
  });
}
