import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vid_donw/domain/models/format_option.dart';
import 'package:vid_donw/domain/models/media_source.dart';
import 'package:vid_donw/features/download/services/download_manager.dart';
import 'package:vid_donw/features/extract/services/extractor_service.dart';
import 'package:vid_donw/features/extract/services/link_parser_service.dart';
import 'package:vid_donw/app/theme_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _urlController = TextEditingController();
  final _extractorService = ExtractorService();
  final _linkParser = LinkParserService();
  List<FormatOption> _formats = const [];
  MediaSource? _source;
  String _title = '';
  bool _isFetching = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  bool _looksLikePlaceholderFormats(List<FormatOption> formats) {
    if (formats.length != 4) return false;
    final ids = formats.map((f) => f.id).toSet();
    return ids.contains('1080p') && ids.contains('mp3');
  }

  Future<void> _analyze() async {
    final url = _urlController.text.trim();
    if (!_linkParser.isSupportedPublicUrl(url)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unsupported or invalid URL')));
      return;
    }

    setState(() => _isFetching = true);
    ExtractorResult? result;
    try {
      result = await _extractorService.extract(url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fetch failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
    if (!mounted || result == null) return;
    final extracted = result;
    setState(() {
      _formats = extracted.formats;
      _source = extracted.source;
      _title = extracted.source.title;
    });
    if (!mounted) return;
    if (_looksLikePlaceholderFormats(extracted.formats)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Gerçek kalite listesi alınamadı (1080p/MP3 şablonu). '
            'Uygulamayı tam yeniden derleyin (Stop → flutter run) veya YouTube Music yerine youtube.com linki deneyin.',
          ),
          duration: Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _startDownload(FormatOption format) async {
    final manager = context.read<DownloadManager>();
    await manager.enqueue(
      sourceUrl: _urlController.text.trim(),
      title: _title.isEmpty ? 'download' : _title,
      format: format,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Queued: ${format.label}')));
  }

  Widget _previewPlaceholder() {
    return Container(
      height: 140,
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.ondemand_video, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 8),
          Text(
            'Önizleme yok',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isInitialState = _source == null && _formats.isEmpty && !_isFetching;

    return Scaffold(
      appBar: AppBar(
        title: const Text('OmniDown'),
        actions: [
          IconButton(
            icon: Icon(themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => context.read<ThemeProvider>().toggleTheme(),
          ),
        ],
      ),
      body: isInitialState
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: 100,
                        width: 100,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _urlController,
                    enabled: !_isFetching,
                    decoration: const InputDecoration(
                      labelText: 'Media URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _isFetching ? null : _analyze,
                    child: _isFetching
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text('Loading…'),
                            ],
                          )
                        : const Text('Fetch Qualities'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isFetching) const LinearProgressIndicator(),
            TextField(
              controller: _urlController,
              enabled: !_isFetching,
              decoration: const InputDecoration(
                labelText: 'Media URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _isFetching ? null : _analyze,
              child: _isFetching
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('Loading…'),
                      ],
                    )
                  : const Text('Fetch Qualities'),
            ),
            const SizedBox(height: 16),
            if (_source != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _source!.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text('Platform: ${_source!.platform.name.toUpperCase()}'),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _source!.thumbnailUrl.isNotEmpty
                            ? Image.network(
                                _source!.thumbnailUrl,
                                height: 140,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _previewPlaceholder(),
                              )
                            : _previewPlaceholder(),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _source!.url,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_formats.isNotEmpty) const Text('Choose quality', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_formats.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _formats.length,
                itemBuilder: (context, index) {
                  final format = _formats[index];
                  return Card(
                    child: ListTile(
                      title: Text(format.label),
                      trailing: FilledButton.tonal(
                        onPressed: () => _startDownload(format),
                        child: const Text('Download'),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
