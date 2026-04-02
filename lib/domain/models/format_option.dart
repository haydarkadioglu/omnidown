class FormatOption {
  const FormatOption({
    required this.id,
    required this.label,
    required this.isAudioOnly,
    this.isVideoOnly = false,
    this.downloadUrl,
    this.audioDownloadUrl,
    this.estimatedSizeBytes,
    this.outputExtension,
  });

  final String id;
  final String label;
  final bool isAudioOnly;
  /// YouTube adaptive: video without audio (player will be silent).
  final bool isVideoOnly;
  final String? downloadUrl;
  final String? audioDownloadUrl;
  final int? estimatedSizeBytes;
  /// Save as e.g. m4a, webm, mp4 (muxed / video-only).
  final String? outputExtension;
}
