enum DownloadStatus { queued, running, merging, completed, failed, cancelled }

class DownloadTask {
  DownloadTask({
    required this.id,
    required this.sourceUrl,
    required this.title,
    required this.formatLabel,
    required this.outputPath,
    this.errorMessage,
    this.progress = 0,
    this.status = DownloadStatus.queued,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String sourceUrl;
  final String title;
  final String formatLabel;
  final String outputPath;
  final DateTime createdAt;
  String? errorMessage;
  double progress;
  DownloadStatus status;
}
