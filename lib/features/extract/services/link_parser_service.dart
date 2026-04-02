import 'package:vid_donw/domain/models/media_source.dart';

class LinkParserService {
  MediaPlatform detectPlatform(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) return MediaPlatform.youtube;
    if (lower.contains('instagram.com')) return MediaPlatform.instagram;
    if (lower.contains('twitter.com') || lower.contains('x.com')) return MediaPlatform.twitter;
    if (lower.contains('facebook.com') || lower.contains('fb.watch')) return MediaPlatform.facebook;
    if (lower.contains('ok.ru')) return MediaPlatform.okru;
    if (lower.contains('tiktok.com')) return MediaPlatform.tiktok;
    return MediaPlatform.unknown;
  }

  bool isSupportedPublicUrl(String url) => detectPlatform(url) != MediaPlatform.unknown;
}
