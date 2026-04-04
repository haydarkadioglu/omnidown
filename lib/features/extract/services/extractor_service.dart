import 'dart:convert';
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

  // Your new generation Python (yt-dlp) engine!
  static const String _backendUrl = 'https://omnidownapi.haydarkadioglu.com/api/extract';

  Future<ExtractorResult> extract(String url) async {
    final platform = _parserService.detectPlatform(url);
    
    // Now we go directly to our own Python server, which is the most robust way 
    // for both YouTube and Social Media. If an error occurs, it falls back to the local solver.
    try {
      return await _extractFromBackend(url, platform);
    } catch (e) {
      if (platform == MediaPlatform.youtube) {
        // If there is a problem with the backend (e.g. 10s limit), fall back to local YouTube engine.
        return await _extractYoutube(url, platform);
      }
      rethrow;
    }
  }

  Future<ExtractorResult> _extractFromBackend(String url, MediaPlatform platform) async {
    final response = await _dio.get(
      _backendUrl,
      queryParameters: {'url': url},
      options: Options(
        receiveTimeout: const Duration(seconds: 20), // yt-dlp sometimes takes time for analysis
      ),
    );

    final data = response.data;
    if (data == null || data['formats'] == null) {
      throw Exception('Server responded but no video formats were found.');
    }

    final formats = (data['formats'] as List).map((f) {
      return FormatOption(
        id: f['id'] ?? 'remote',
        label: f['label'] ?? 'Video',
        isAudioOnly: f['isAudioOnly'] ?? false,
        downloadUrl: f['downloadUrl'],
        outputExtension: f['outputExtension'] ?? 'mp4',
        estimatedSizeBytes: f['estimatedSizeBytes'] ?? 0,
      );
    }).toList();

    final source = MediaSource(
      platform: platform,
      url: url,
      title: data['title'] ?? 'Media File',
      thumbnailUrl: data['thumbnail'] ?? '',
    );

    return ExtractorResult(source: source, formats: formats);
  }

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

      for (final stream in manifest.muxed.sortByVideoQuality()) {
        final h = stream.videoResolution.height;
        final ext = stream.container == StreamContainer.webM ? 'webm' : 'mp4';
        formats.add(
          FormatOption(
            id: 'muxed-\${stream.tag}',
            label:
                '\${h}p \${ext.toUpperCase()} audio+video (YouTube muxed stream, usually ≤360p)',
            isAudioOnly: false,
            isVideoOnly: false,
            downloadUrl: stream.url.toString(),
            estimatedSizeBytes: stream.size.totalBytes,
            outputExtension: ext,
          ),
        );
      }

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
        
        if (stream == audios.first) {
          formats.add(
            FormatOption(
              id: 'audio-mp3-\${stream.tag}',
              label: 'Audio Convert to MP3 (~\$kbps kbps)',
              isAudioOnly: true,
              isVideoOnly: false,
              downloadUrl: stream.url.toString(),
              estimatedSizeBytes: stream.size.totalBytes,
              outputExtension: 'mp3',
            ),
          );
        }

        formats.add(
          FormatOption(
            id: 'audio-\${stream.tag}',
            label: 'Audio \$ext ~\$kbps kbps',
            isAudioOnly: true,
            isVideoOnly: false,
            downloadUrl: stream.url.toString(),
            estimatedSizeBytes: stream.size.totalBytes,
            outputExtension: ext,
          ),
        );
      }

      final seenHeights = <int>{};
      for (final stream in manifest.videoOnly.sortByVideoQuality()) {
        final h = stream.videoResolution.height;
        if (!seenHeights.add(h)) continue;
        final ext = stream.container == StreamContainer.webM ? 'webm' : 'mp4';
        formats.add(
          FormatOption(
            id: 'vonly-\${stream.tag}',
            label: '\${h}p \${ext.toUpperCase()} (high quality)',
            isAudioOnly: false,
            isVideoOnly: false, 
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

      // Validate formats to remove broken links (403 Forbidden / DioException)
      final validFormats = <FormatOption>[];
      final futures = formats.map((format) async {
        try {
          if (format.downloadUrl != null) {
            final res = await _dio.get(
              format.downloadUrl!,
              options: Options(headers: {'Range': 'bytes=0-0'}, receiveTimeout: const Duration(seconds: 3)),
            );
            if (res.statusCode != null && res.statusCode! >= 400) return;
          }
          validFormats.add(format);
        } catch (_) {
          // Ignore failing formats
        }
      });
      await Future.wait(futures);

      return ExtractorResult(
        source: source,
        formats: validFormats.isEmpty ? _formatMapper.buildDefaultOptions() : validFormats,
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
    final fallbackTitle = 'Media from \${platform.name}';
    try {
      if (platform == MediaPlatform.youtube) {
        final normalized = _normalizeYoutubePageUrl(url);
        final endpoint =
            'https://www.youtube.com/oembed?url=\${Uri.encodeComponent(normalized)}&format=json';
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
    }
    return (fallbackTitle, '');
  }
}
