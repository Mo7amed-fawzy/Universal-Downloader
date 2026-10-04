import 'package:flutter_test/flutter_test.dart';
import 'package:universal_downloader/core/utils/filename_sanitizer.dart';

void main() {
  const sanitizer = FilenameSanitizer();

  test('keeps ordinary titles unchanged', () {
    expect(sanitizer.sanitize('Rick Astley - Never Gonna Give You Up'),
        'Rick Astley - Never Gonna Give You Up');
  });

  test('removes path separators', () {
    expect(sanitizer.sanitize('a/b/c'), 'a_b_c');
    expect(sanitizer.sanitize('..'), 'download');
    expect(sanitizer.sanitize('/etc/passwd'), '_etc_passwd');
  });

  test('replaces Windows and shell metacharacters', () {
    expect(sanitizer.sanitize('a:b*c?"<d>|e'), 'a_b_c___d__e');
    expect(sanitizer.sanitize(r'a\b'), 'a_b');
  });

  test('strips control characters', () {
    expect(sanitizer.sanitize('line1\nline2\t'), 'line1line2');
  });

  test('collapses whitespace and trims', () {
    expect(sanitizer.sanitize('  hello    world  '), 'hello world');
  });

  test('strips leading dots and trailing dots', () {
    expect(sanitizer.sanitize('.hidden'), 'hidden');
    expect(sanitizer.sanitize('video...'), 'video');
  });

  test('falls back to a placeholder for empty or dot-only input', () {
    expect(sanitizer.sanitize(''), 'download');
    expect(sanitizer.sanitize('...'), 'download');
    expect(sanitizer.sanitize('   '), 'download');
  });

  test('caps very long titles', () {
    final long = 'x' * 500;
    expect(sanitizer.sanitize(long).length, lessThanOrEqualTo(180));
  });

  test('empty input yields the placeholder', () {
    expect(sanitizer.sanitize(''), 'download');
  });
}
