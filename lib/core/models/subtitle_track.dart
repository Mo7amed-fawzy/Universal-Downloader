import '../utils/language_names.dart';

class SubtitleTrack {
  const SubtitleTrack({
    required this.language,
    required this.extension,
    this.name,
    this.isAutomatic = false,
    this.isTranslated = false,
  });

  final String language;
  final String extension;
  final String? name;
  final bool isAutomatic;
  final bool isTranslated;

  String get id => '${isAutomatic ? 'automatic' : 'uploaded'}:$language';

  String get label =>
      '${name ?? LanguageNames.nameFor(language)} ($language)'
      '${isTranslated
          ? ' - auto-translated'
          : isAutomatic
          ? ' - automatic'
          : ''}';
}
