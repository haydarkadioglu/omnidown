import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vid_donw/features/download/services/download_manager.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<DownloadManager>();
    final history = manager.history;
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: history.isEmpty
          ? const Center(child: Text('No finished downloads yet'))
          : ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                final date = DateFormat('yyyy-MM-dd HH:mm').format(item.createdAt);
                return ListTile(
                  title: Text(item.title),
                  subtitle: Text('${item.status.name} - $date'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'open') {
                        await OpenFilex.open(item.outputPath);
                      } else if (value == 'share') {
                        await SharePlus.instance.share(ShareParams(files: [XFile(item.outputPath)]));
                      } else if (value == 'delete') {
                        final file = File(item.outputPath);
                        if (await file.exists()) await file.delete();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'open', child: Text('Open')),
                      PopupMenuItem(value: 'share', child: Text('Share')),
                      PopupMenuItem(value: 'delete', child: Text('Delete File')),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
