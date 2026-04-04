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

  Future<ExtractorResult> extract(String url) async {
    final platform = _parserService.detectPlatform(url);
    if (platform == MediaPlatform.youtube) {
      return _extractYoutube(url, platform);
    }
    
    if (platform == MediaPlatform.twitter) {
      return await _extractTwitter(url, platform);
    }

    if (platform == MediaPlatform.tiktok) {
      return await _extractTikTok(url, platform);
    }

    if (platform == MediaPlatform.instagram) {
      return await _extractInstagram(url, platform);
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
                '\${h}p \${ext.toUpperCase()} ses+görüntü (YouTube birleşik akış, genelde ≤360p)',
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
              label: 'Ses MP3 Dönüştür (~\$kbps kbps)',
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
            label: 'Ses \$ext ~\$kbps kbps',
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
            label: '\${h}p \${ext.toUpperCase()} (yüksek kalite)',
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

  Future<ExtractorResult> _extractTwitter(String url, MediaPlatform platform) async {
    final regex = RegExp(r'status/(\d+)');
    final match = regex.firstMatch(url);
    if (match == null) throw FormatException('Geçerli bir Twitter URL\'si bulunamadı.');
    
    final tweetId = match.group(1)!;
    final apiUrl = 'https://cdn.syndication.twimg.com/tweet-result?id=\$tweetId';
    
    final response = await _dio.get(apiUrl);
    if (response.statusCode != 200) throw Exception('Twitter API hatası: \${response.statusCode}');
    
    final data = response.data;
    if (data['video'] == null || data['video']['variants'] == null) {
      throw Exception('Bu Tweet içinde video bulunamadı.');
    }

    final variants = data['video']['variants'] as List;
    final formats = <FormatOption>[];
    
    for (var i = 0; i < variants.length; i++) {
      final v = variants[i];
      if (v['type'] == 'video/mp4') {
        final bitrate = v['bitrate'] ?? 0;
        formats.add(FormatOption(
          id: 'tw-\$bitrate',
          label: 'Twitter Video (\${bitrate ~/ 1000}kbps MP4)',
          isAudioOnly: false,
          downloadUrl: v['src'],
          outputExtension: 'mp4',
        ));
      }
    }
    
    if (formats.isEmpty) throw Exception('Desteklenen video formatı bulunamadı.');
    
    formats.sort((a, b) {
      final aBit = int.tryParse(a.label.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final bBit = int.tryParse(b.label.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return bBit.compareTo(aBit);
    });

    final source = MediaSource(
      platform: platform,
      url: url,
      title: data['text']?.split('\\n').first ?? 'Twitter Video',
      thumbnailUrl: data['video']['poster'] ?? '',
    );
    return ExtractorResult(source: source, formats: formats);
  }

  Future<ExtractorResult> _extractTikTok(String url, MediaPlatform platform) async {
    // We use tikwm.com which is one of the most reliable watermark-free TikTok APIs.
    final response = await _dio.post(
      'https://www.tikwm.com/api/',
      data: {'url': url},
      options: Options(
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0 Safari/537.36'
        }
      )
    );
    
    final data = response.data;
    if (data == null || data['code'] != 0) {
      throw Exception('TikTok sunucusuna ulaşılamadı. (Gizli video olabilir)');
    }
    
    final itemInfo = data['data'];
    final playAddr = itemInfo['play'];
    final title = itemInfo['title'] ?? 'TikTok Video';
    final cover = itemInfo['cover'] ?? '';
    
    final source = MediaSource(
      platform: platform,
      url: url,
      title: title,
      thumbnailUrl: cover,
    );
    
    return ExtractorResult(source: source, formats: [
      FormatOption(
        id: 'tt-hd',
        label: 'TikTok Videosu (Filigransız HD)',
        isAudioOnly: false,
        downloadUrl: playAddr,
        outputExtension: 'mp4',
      )
    ]);
  }

  Future<ExtractorResult> _extractInstagram(String url, MediaPlatform platform) async {
    // We use saveig.app proxy. Highly reliable open REST endpoint.
    final response = await _dio.post(
      'https://saveig.app/api/ajaxSearch',
      data: 'q=\${Uri.encodeComponent(url)}&t=media&lang=en',
      options: Options(
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': '*/*',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0 Safari/537.36',
          'Origin': 'https://saveig.app',
          'Referer': 'https://saveig.app/en'
        },
      ),
    );
    
    final data = response.data;
    if (data is String) {
        final Map<String, dynamic> json = jsonDecode(data);
        final html = json['data'] as String;
        
        final regex = RegExp(r'<a[^>]*href="([^"]+)"[^>]*>.*?Download.*?</a>', caseSensitive: false);
        final match = regex.firstMatch(html);
        if (match != null) {
            String downloadUrl = match.group(1)!;
            downloadUrl = downloadUrl.replaceAll('&amp;', '&');
            
            return ExtractorResult(
                source: MediaSource(
                    platform: platform,
                    url: url,
                    title: 'Instagram Video',
                    thumbnailUrl: '', // SaveIG's response is pure HTML links, we don't scrape thumbnail to avoid parsing errors
                ),
                formats: [
                    FormatOption(
                        id: 'ig-proxy',
                        label: 'Instagram Video (MP4)',
                        isAudioOnly: false,
                        downloadUrl: downloadUrl,
                        outputExtension: 'mp4',
                    ),
                ]
            );
        }
    }
    throw Exception('Instagram videosu bulunamadı. Gizli profil olabilir veya API engeli mevcut.');
  }
}
