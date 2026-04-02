import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:vid_donw/data/repositories/download_repository_impl.dart';
import 'package:vid_donw/domain/models/download_task.dart';
import 'package:vid_donw/domain/models/format_option.dart';
import 'package:vid_donw/features/download/services/file_store_service.dart';

class DownloadManager extends ChangeNotifier {
  DownloadManager({
    DownloadRepositoryImpl? repository,
    FileStoreService? fileStore,
    Dio? dio,
  })  : _repository = repository ?? DownloadRepositoryImpl(),
        _fileStore = fileStore ?? FileStoreService(),
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(minutes: 3),
                followRedirects: true,
                headers: {
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                  'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
                  'Accept-Language': 'en-US,en;q=0.5',
                },
              ),
            );

  final DownloadRepositoryImpl _repository;
  final FileStoreService _fileStore;
  final Dio _dio;
  final Uuid _uuid = const Uuid();
  final Map<String, CancelToken> _tokens = {};

  final List<DownloadTask> _tasks = [];
  List<DownloadTask> get tasks => List.unmodifiable(_tasks);
  List<DownloadTask> get history => tasks.where((t) => t.status != DownloadStatus.running && t.status != DownloadStatus.queued).toList();

  Future<void> bootstrap() async {
    final existing = await _repository.history();
    for (final task in existing) {
      if (task.status == DownloadStatus.queued || task.status == DownloadStatus.running) {
        task.status = DownloadStatus.failed;
        task.errorMessage = 'Previous app session ended before this download finished.';
      }
      if (task.status == DownloadStatus.completed) {
        final file = File(task.outputPath);
        final exists = await file.exists();
        final size = exists ? await file.length() : 0;
        if (!exists || size == 0) {
          task.status = DownloadStatus.failed;
          task.errorMessage = 'Downloaded file is missing or empty.';
        }
      }
    }
    _tasks
      ..clear()
      ..addAll(existing);
    notifyListeners();
  }

  Future<void> enqueue({
    required String sourceUrl,
    required String title,
    required FormatOption format,
  }) async {
    final extension = format.outputExtension ?? (format.isAudioOnly ? 'm4a' : 'mp4');
    final path = await _fileStore.outputPath(title, extension);
    final task = DownloadTask(
      id: _uuid.v4(),
      sourceUrl: sourceUrl,
      title: title,
      formatLabel: format.label,
      outputPath: path,
    );
    _tasks.insert(0, task);
    await _safeSave(task);
    notifyListeners();
    unawaited(_runTask(task, format));
  }

  Future<void> _runTask(DownloadTask task, FormatOption format) async {
    final token = CancelToken();
    _tokens[task.id] = token;
    task.status = DownloadStatus.running;
    notifyListeners();

    try {
      final downloadUrl = format.downloadUrl ?? task.sourceUrl;
      if (format.downloadUrl == null && !_looksLikeDirectFile(downloadUrl)) {
        throw const FormatException(
          'This URL is a social page link, not a direct media file. '
          'Extractor integration is required for YouTube/Instagram/TikTok links.',
        );
      }

      if (format.isAudioOnly && format.downloadUrl == null) {
        throw UnsupportedError(
          'This audio format is not available yet (needs stream URL or MP3 encoder).',
        );
      }

      final tempOutputVideo = '${task.outputPath}.temp.mp4';
      final tempOutputAudio = '${task.outputPath}.temp.m4a';
      final finalOutput = task.outputPath;

      final needsMerge = format.audioDownloadUrl != null;

      if (needsMerge) {
        double videoProgress = 0;
        double audioProgress = 0;

        await Future.wait([
          _dio.download(
            downloadUrl,
            tempOutputVideo,
            cancelToken: token,
            onReceiveProgress: (received, total) {
              if (total > 0) {
                videoProgress = received / total;
                task.progress = (videoProgress + audioProgress) / 2;
                notifyListeners();
              }
            },
          ),
          _dio.download(
            format.audioDownloadUrl!,
            tempOutputAudio,
            cancelToken: token,
            onReceiveProgress: (received, total) {
              if (total > 0) {
                audioProgress = received / total;
                task.progress = (videoProgress + audioProgress) / 2;
                notifyListeners();
              }
            },
          ),
        ]);

        task.status = DownloadStatus.merging;
        task.progress = 1.0;
        notifyListeners();

        // Mux streams without re-encoding
        final session = await FFmpegKit.execute('-i "$tempOutputVideo" -i "$tempOutputAudio" -c:v copy -c:a copy "$finalOutput"');
        final returnCode = await session.getReturnCode();

        final vFile = File(tempOutputVideo);
        final aFile = File(tempOutputAudio);
        if (await vFile.exists()) await vFile.delete();
        if (await aFile.exists()) await aFile.delete();

        if (!ReturnCode.isSuccess(returnCode)) {
           throw Exception('Arka planda birleştirme başarısız oldu (Hata Kodu: ${returnCode?.getValue()})');
        }
      } else {
        await _dio.download(
          downloadUrl,
          finalOutput,
          cancelToken: token,
          onReceiveProgress: (received, total) {
            if (total > 0) {
              task.progress = received / total;
              notifyListeners();
            }
          },
        );
      }

      final output = File(finalOutput);
      if (!await output.exists() || await output.length() == 0) {
        throw const FileSystemException('Downloaded file is empty.');
      }

      final bytes = await output.openRead(0, 512).fold<List<int>>([], (p, e) => p..addAll(e));
      final header = latin1.decode(bytes, allowInvalid: true).toLowerCase();
      if (header.contains('<!doctype html') || header.contains('<html')) {
        await output.delete();
        throw const FormatException(
          'Downloaded content is a webpage, not a media file. Use a direct media URL.',
        );
      }
      if (!_looksPlayableVideo(bytes)) {
        await output.delete();
        throw const FormatException(
          'Downloaded file is not a playable video stream.',
        );
      }

      task.progress = 1;
      task.status = DownloadStatus.completed;
    } catch (e) {
      task.status = token.isCancelled ? DownloadStatus.cancelled : DownloadStatus.failed;
      task.errorMessage = e.toString();
    } finally {
      try {
        final v = File('${task.outputPath}.temp.mp4');
        final a = File('${task.outputPath}.temp.m4a');
        if (await v.exists()) await v.delete();
        if (await a.exists()) await a.delete();
      } catch (_) {}
      _tokens.remove(task.id);
      await _safeSave(task);
      notifyListeners();
    }
  }

  Future<void> cancelTask(String taskId) async {
    _tokens[taskId]?.cancel('Cancelled by user');
  }

  Future<void> _safeSave(DownloadTask task) async {
    try {
      await _repository.save(task);
    } catch (_) {
      // Keep the UI responsive even if persistence fails.
    }
  }

  bool _looksLikeDirectFile(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.mp3') ||
        lower.contains('download');
  }

  bool _looksPlayableVideo(List<int> bytes) {
    if (bytes.length < 16) return false;
    final head = latin1.decode(bytes.take(64).toList(), allowInvalid: true).toLowerCase();
    // MP4 family includes "ftyp" in file header box.
    if (head.contains('ftyp')) return true;
    // WEBM/MKV magic number: 1A 45 DF A3
    return bytes[0] == 0x1A && bytes[1] == 0x45 && bytes[2] == 0xDF && bytes[3] == 0xA3;
  }
}
