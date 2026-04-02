import 'package:dio/dio.dart';
import 'package:vid_donw/domain/models/format_option.dart';
import 'package:vid_donw/domain/models/media_source.dart';
import 'package:vid_donw/features/extract/mappers/format_mapper.dart';
import 'package:vid_donw/features/extract/services/link_parser_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class ExtractorResult {
  const ExtractorResult({required this.source, required this.formats});
  final MediaSource source;
  final List<FormatOption> formats;
}

class ExtractorService {
  ExtractorService({
    LinkParserService? parserService,
    FormatMapper? formatMapper,
    Dio? dio,
  })  : _parserService = parserService ?? LinkParserService(),
        _formatMapper = formatMapper ?? FormatMapper(),
        _dio = dio ?? Dio(),
        _yt = YoutubeExplode();

  final LinkParserService _parserService;
  final FormatMapper _formatMapper;
  final Dio _dio;
  final YoutubeExplode _yt;

  Future<ExtractorResult> extract(String url) async {
    final platform = _parserService.detectPlatform(url);
    if (platform == MediaPlatform.youtube) {
      return _extractYoutube(url, platform);
    }

    final metadata = await _fetchMetadata(url, platform);
    final source = MediaSource(
      platform: platform,
      url: url,
      title: metadata.$1,
      thumbnailUrl: metadata.$2,
    );

    return ExtractorResult(source: source, formats: _formatMapper.buildDefaultOptions());
  }

  /// YouTube Music / regional hosts can break parsers; use standard watch URL for API calls.
  String _normalizeYoutubePageUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return url.trim();
    final host = uri.host.toLowerCase();
    if (host == 'music.youtube.com' || host.endsWith('.music.youtube.com')) {
      return uri.replace(host: 'www.youtube.com').toString();
    }
    if (host == 'm.youtube.com') {
      return uri.replace(host: 'www.youtube.com').toString();
    }
    return url.trim();
  }

  Future<ExtractorResult> _extractYoutube(String url, MediaPlatform platform) async {
    final apiUrl = _normalizeYoutubePageUrl(url);
    try {
      final video = await _yt.videos.get(apiUrl);
      final manifest = await _yt.videos.streamsClient.getManifest(video.id.value);

      final formats = <FormatOption>[];

      // Combined A+V — YouTube caps muxed around 360p30 (library note).
      for (final stream in manifest.muxed.sortByVideoQuality()) {
        final h = stream.videoResolution.height;
        final ext = stream.container == StreamContainer.webM ? 'webm' : 'mp4';
        formats.add(
          FormatOption(
            id: 'muxed-${stream.tag}',
            label:
                '${h}p ${ext.toUpperCase()} ses+görüntü (YouTube birleşik akış, genelde ≤360p)',
            isAudioOnly: false,
            isVideoOnly: false,
            downloadUrl: stream.url.toString(),
            estimatedSizeBytes: stream.size.totalBytes,
            outputExtension: ext,
          ),
        );
      }

      // Best-quality audio-only (M4A/WEBM) — playable; not MP3 without transcoding.
      final audios = manifest.audioOnly.toList()
        ..sort((a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));
        
      String? bestAudioUrl;
      int bestAudioSize = 0;
      if (audios.isNotEmpty) {
        bestAudioUrl = audios.first.url.toString();
        bestAudioSize = audios.first.size.totalBytes;
      }
      for (final stream in audios.take(4)) {
        final ext = stream.container == StreamContainer.webM ? 'webm' : 'm4a';
        final kbps = stream.bitrate.kiloBitsPerSecond.toStringAsFixed(0);
        formats.add(
          FormatOption(
            id: 'audio-${stream.tag}',
            label: 'Ses $ext ~$kbps kbps',
            isAudioOnly: true,
            isVideoOnly: false,
            downloadUrl: stream.url.toString(),
            estimatedSizeBytes: stream.size.totalBytes,
            outputExtension: ext,
          ),
        );
      }

      // High-res video-only (no audio). Needs merge with FFmpeg for single file with sound.
      final seenHeights = <int>{};
      for (final stream in manifest.videoOnly.sortByVideoQuality()) {
        final h = stream.videoResolution.height;
        if (!seenHeights.add(h)) continue;
        final ext = stream.container == StreamContainer.webM ? 'webm' : 'mp4';
        formats.add(
          FormatOption(
            id: 'vonly-${stream.tag}',
            label: '${h}p ${ext.toUpperCase()} (yüksek kalite)',
            isAudioOnly: false,
            isVideoOnly: false, // Since we will merge it, it's not truly video-only
            downloadUrl: stream.url.toString(),
            audioDownloadUrl: bestAudioUrl,
            estimatedSizeBytes: stream.size.totalBytes + bestAudioSize,
            outputExtension: ext,
          ),
        );
        if (seenHeights.length >= 8) break;
      }

      final source = MediaSource(
        platform: platform,
        url: url,
        title: video.title,
        thumbnailUrl: video.thumbnails.highResUrl,
      );

      return ExtractorResult(
        source: source,
        formats: formats.isEmpty ? _formatMapper.buildDefaultOptions() : formats,
      );
    } catch (_) {
      final metadata = await _fetchMetadata(apiUrl, platform);
      final source = MediaSource(
        platform: platform,
        url: url,
        title: metadata.$1,
        thumbnailUrl: metadata.$2,
      );
      return ExtractorResult(source: source, formats: _formatMapper.buildDefaultOptions());
    }
  }

  Future<(String, String)> _fetchMetadata(String url, MediaPlatform platform) async {
    final fallbackTitle = 'Media from ${platform.name}';
    try {
      if (platform == MediaPlatform.youtube) {
        final normalized = _normalizeYoutubePageUrl(url);
        final endpoint =
            'https://www.youtube.com/oembed?url=${Uri.encodeComponent(normalized)}&format=json';
        final response = await _dio.get(endpoint);
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final title = (data['title'] as String?)?.trim();
          final thumb = (data['thumbnail_url'] as String?)?.trim();
          return (
            (title == null || title.isEmpty) ? fallbackTitle : title,
            thumb ?? '',
          );
        }
      }
    } catch (_) {
      // Keep fallback metadata on network/parse failure.
    }
    return (fallbackTitle, '');
  }
}
