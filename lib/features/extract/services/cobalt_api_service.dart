import 'package:dio/dio.dart';
import 'package:vid_donw/domain/models/format_option.dart';
import 'package:vid_donw/domain/models/media_source.dart';

class CobaltApiService {
  CobaltApiService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.cobalt.tools',
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                  // Prevent caching
                  'Cache-Control': 'no-cache',
                },
              ),
            );

  final Dio _dio;

  Future<(MediaSource, List<FormatOption>)> extract(String url, MediaPlatform platform) async {
    try {
      final response = await _dio.post(
        '/api/json',
        data: {'url': url},
      );

      final data = response.data;
      if (data == null || data is! Map<String, dynamic>) {
        throw Exception('Geçersiz sunucu yanıtı (Cobalt)');
      }

      final status = data['status'];
      if (status == 'error') {
        throw Exception(data['text'] ?? 'Bilinmeyen Cobalt hatası');
      }

      final formats = <FormatOption>[];
      final title = 'Media from ${platform.name}';
      
      if (status == 'stream' || status == 'redirect') {
        final downloadUrl = data['url'];
        formats.add(
          FormatOption(
            id: 'cobalt-main',
            label: 'Yüksek Kalite (MP4)',
            isAudioOnly: false,
            downloadUrl: downloadUrl as String?,
            outputExtension: 'mp4',
            isVideoOnly: false,
          ),
        );
      } else if (status == 'picker') {
        final picker = data['picker'];
        if (picker is List && picker.isNotEmpty) {
          // Twitter or Instagram Carousel
          for (var i = 0; i < picker.length; i++) {
            final item = picker[i];
            if (item['type'] == 'video' || item['type'] == 'gif') {
              formats.add(
                FormatOption(
                  id: 'cobalt-pick-$i',
                  label: 'Seçenek ${i + 1} (MP4)',
                  isAudioOnly: false,
                  downloadUrl: item['url'] as String?,
                  outputExtension: 'mp4',
                  isVideoOnly: false,
                ),
              );
            }
          }
          // Fallback if no video in picker (e.g. photos)
          if (formats.isEmpty) {
            formats.add(
              FormatOption(
                id: 'cobalt-img',
                label: 'Medya/Fotoğraf (İlk Öğe)',
                isAudioOnly: false,
                downloadUrl: picker.first['url'] as String?,
                outputExtension: 'jpg',
              ),
            );
          }
        }
      }

      return (
        MediaSource(
          platform: platform,
          url: url,
          title: title,
          thumbnailUrl: '', // Could be fetched via generic metadata or Cobalt's thumbnail if available
        ),
        formats,
      );
    } catch (e) {
      if (e is DioException && e.response != null) {
        throw Exception('Cobalt Sunucu Hatası: ${e.response?.statusCode} - ${e.response?.data}');
      }
      rethrow;
    }
  }
}
