import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:vid_donw/domain/models/download_task.dart';

class DownloadHistoryDb {
  static const _table = 'download_history';
  Database? _db;

  Future<Database> _database() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'downloads.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE $_table(
          id TEXT PRIMARY KEY,
          source_url TEXT NOT NULL,
          title TEXT NOT NULL,
          format_label TEXT NOT NULL,
          output_path TEXT NOT NULL,
          status TEXT NOT NULL,
          progress REAL NOT NULL,
          created_at TEXT NOT NULL,
          error_message TEXT
        )
      '''),
    );
    return _db!;
  }

  Future<void> upsert(DownloadTask task) async {
    final db = await _database();
    await db.insert(_table, {
      'id': task.id,
      'source_url': task.sourceUrl,
      'title': task.title,
      'format_label': task.formatLabel,
      'output_path': task.outputPath,
      'status': task.status.name,
      'progress': task.progress,
      'created_at': task.createdAt.toIso8601String(),
      'error_message': task.errorMessage,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<DownloadTask>> all() async {
    final db = await _database();
    final rows = await db.query(_table, orderBy: 'created_at DESC');
    return rows.map((row) {
      return DownloadTask(
        id: row['id'] as String,
        sourceUrl: row['source_url'] as String,
        title: row['title'] as String,
        formatLabel: row['format_label'] as String,
        outputPath: row['output_path'] as String,
        createdAt: DateTime.tryParse(row['created_at'] as String),
        progress: (row['progress'] as num).toDouble(),
        status: DownloadStatus.values.firstWhere((s) => s.name == row['status']),
        errorMessage: row['error_message'] as String?,
      );
    }).toList();
  }
}
