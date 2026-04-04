import 'package:vid_donw/domain/models/format_option.dart';

class FormatMapper {
  List<FormatOption> buildDefaultOptions() => const [
        FormatOption(id: '1080p', label: '1080p MP4', isAudioOnly: false, outputExtension: 'mp4'),
        FormatOption(id: '720p', label: '720p MP4', isAudioOnly: false, outputExtension: 'mp4'),
        FormatOption(id: '480p', label: '480p MP4', isAudioOnly: false, outputExtension: 'mp4'),
        FormatOption(id: 'mp3', label: 'Audio MP3', isAudioOnly: true, outputExtension: 'mp3'),
      ];
}
