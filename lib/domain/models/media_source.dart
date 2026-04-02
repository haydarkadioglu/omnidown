enum MediaPlatform { youtube, instagram, twitter, facebook, okru, tiktok, unknown }

class MediaSource {
  const MediaSource({
    required this.platform,
    required this.url,
    required this.title,
    required this.thumbnailUrl,
  });

  final MediaPlatform platform;
  final String url;
  final String title;
  final String thumbnailUrl;
}
