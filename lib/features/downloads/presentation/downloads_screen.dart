import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vid_donw/domain/models/download_task.dart';
import 'package:vid_donw/features/download/services/download_manager.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<DownloadManager>();
    final tasks = manager.tasks;
    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: tasks.isEmpty
          ? const Center(child: Text('No downloads yet'))
          : ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                final isActive = task.status == DownloadStatus.running || task.status == DownloadStatus.queued || task.status == DownloadStatus.merging;
                return ListTile(
                  title: Text(task.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_statusLabel(task.status)),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: task.progress),
                    ],
                  ),
                  trailing: isActive
                      ? IconButton(
                          onPressed: () => manager.cancelTask(task.id),
                          icon: const Icon(Icons.cancel_outlined),
                        )
                      : IconButton(
                          onPressed: task.status == DownloadStatus.failed
                              ? () => _showErrorDialog(context, task)
                              : null,
                          icon: Icon(
                            _statusIcon(task.status),
                            color: _statusColor(task.status, context),
                          ),
                        ),
                );
              },
            ),
    );
  }

  void _showErrorDialog(BuildContext context, DownloadTask task) {
    final message = (task.errorMessage == null || task.errorMessage!.trim().isEmpty)
        ? 'Unknown error'
        : task.errorMessage!;
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Download error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  String _statusLabel(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.queued:
        return 'Queued';
      case DownloadStatus.running:
        return 'Downloading...';
      case DownloadStatus.merging:
        return 'Birleştiriliyor...';
      case DownloadStatus.completed:
        return 'Done';
      case DownloadStatus.failed:
        return 'Failed';
      case DownloadStatus.cancelled:
        return 'Cancelled';
    }
  }

  IconData _statusIcon(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.completed:
        return Icons.check_circle;
      case DownloadStatus.failed:
        return Icons.error;
      case DownloadStatus.cancelled:
        return Icons.remove_circle;
      case DownloadStatus.queued:
      case DownloadStatus.running:
      case DownloadStatus.merging:
        return Icons.downloading;
    }
  }

  Color _statusColor(DownloadStatus status, BuildContext context) {
    switch (status) {
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.failed:
        return Colors.red;
      case DownloadStatus.cancelled:
        return Colors.orange;
      case DownloadStatus.queued:
      case DownloadStatus.running:
      case DownloadStatus.merging:
        return Theme.of(context).colorScheme.primary;
    }
  }
}
