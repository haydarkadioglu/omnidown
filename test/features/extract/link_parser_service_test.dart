import 'package:flutter_test/flutter_test.dart';
import 'package:vid_donw/domain/models/media_source.dart';
import 'package:vid_donw/features/extract/services/link_parser_service.dart';

void main() {
  group('LinkParserService', () {
    final service = LinkParserService();

    test('detects youtube', () {
      expect(service.detectPlatform('https://youtube.com/watch?v=abc'), MediaPlatform.youtube);
    });

    test('unknown url is not supported', () {
      expect(service.isSupportedPublicUrl('https://example.com/video.mp4'), isFalse);
    });
  });
}
