/// Display names for common language codes (used for audio track labels).
class LanguageNames {
  const LanguageNames._();

  static String nameFor(String? code) {
    if (code == null || code.isEmpty) return 'Unknown';
    final base = code.split('-').first.toLowerCase();
    return _names[base] ?? code;
  }

  static const Map<String, String> _names = {
    'ar': 'Arabic',
    'en': 'English',
    'fr': 'French',
    'de': 'German',
    'es': 'Spanish',
    'pt': 'Portuguese',
    'hi': 'Hindi',
    'id': 'Indonesian',
    'it': 'Italian',
    'ja': 'Japanese',
    'ko': 'Korean',
    'ru': 'Russian',
    'tr': 'Turkish',
    'zh': 'Chinese',
    'nl': 'Dutch',
    'pl': 'Polish',
    'sv': 'Swedish',
    'da': 'Danish',
    'no': 'Norwegian',
    'fi': 'Finnish',
    'el': 'Greek',
    'he': 'Hebrew',
    'th': 'Thai',
    'vi': 'Vietnamese',
    'uk': 'Ukrainian',
    'cs': 'Czech',
    'hu': 'Hungarian',
    'ro': 'Romanian',
    'bn': 'Bengali',
    'ur': 'Urdu',
    'fa': 'Persian',
    'ml': 'Malayalam',
    'ta': 'Tamil',
    'te': 'Telugu',
    'mr': 'Marathi',
    'gu': 'Gujarati',
    'kn': 'Kannada',
    'sw': 'Swahili',
    'fil': 'Filipino',
    'tl': 'Tagalog',
    'ms': 'Malay',
    'ar-EG': 'Arabic (Egypt)',
  };
}
