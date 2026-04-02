import 'dart:io';

class FfmpegService {
  Future<void> convertToMp3(String inputPath, String outputPath) async {
    // Placeholder conversion. Replace with real FFmpeg bridge in production.
    final input = File(inputPath);
    if (!await input.exists()) return;
    await input.copy(outputPath);
  }
}
