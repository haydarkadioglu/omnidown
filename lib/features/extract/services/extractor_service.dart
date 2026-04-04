import 'package:dio/dio.dart';
import 'package:vid_donw/domain/models/format_option.dart';
import 'package:vid_donw/domain/models/media_source.dart';
import 'package:vid_donw/features/extract/services/link_parser_service.dart';

class ExtractorResult {
  const ExtractorResult({required this.source, required this.formats});
  final MediaSource source;
  final List<FormatOption> formats;
}

class ExtractorService {
  ExtractorService({
    LinkParserService? parserService,
    Dio? dio,
  })  : _parserService = parserService ?? LinkParserService(),
        _dio = dio ?? Dio();

  final LinkParserService _parserService;
  final Dio _dio;

  // Your new generation Python (yt-dlp) engine!
  static const String _backendUrl = 'https://omnidownapi.haydarkadioglu.com/api/extract';

  Future<ExtractorResult> extract(String url) async {
    final platform = _parserService.detectPlatform(url);
    
    // Now we go directly to our own Python server for everything! No fallbacks.
    return await _extractFromBackend(url, platform);
  }

  Future<ExtractorResult> _extractFromBackend(String url, MediaPlatform platform) async {
    late final Response response;
    try {
      response = await _dio.get(
        _backendUrl,
        queryParameters: {'url': url},
        options: Options(
          receiveTimeout: const Duration(seconds: 25), // yt-dlp sometimes takes time for analysis
        ),
      );
    } on DioException catch (e) {
      if (e.response != null && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data.containsKey('detail')) {
          throw Exception('Backend Error: \${data['detail']}');
        }
      }
      throw Exception('Network Error: \${e.message}');
    }

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
}
