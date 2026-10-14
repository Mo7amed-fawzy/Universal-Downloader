enum AudioOutputFormat { mp3, m4a, flac }

extension AudioOutputFormatDetails on AudioOutputFormat {
  String get id => switch (this) {
    AudioOutputFormat.mp3 => 'mp3',
    AudioOutputFormat.m4a => 'm4a',
    AudioOutputFormat.flac => 'flac',
  };

  String get label => id.toUpperCase();

  static AudioOutputFormat? fromId(String? id) => switch (id) {
    'mp3' => AudioOutputFormat.mp3,
    'm4a' => AudioOutputFormat.m4a,
    'flac' => AudioOutputFormat.flac,
    _ => null,
  };
}
