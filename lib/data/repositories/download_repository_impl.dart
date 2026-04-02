import 'package:vid_donw/data/local/download_history_db.dart';
import 'package:vid_donw/domain/models/download_task.dart';

class DownloadRepositoryImpl {
  DownloadRepositoryImpl({DownloadHistoryDb? db}) : _db = db ?? DownloadHistoryDb();

  final DownloadHistoryDb _db;

  Future<void> save(DownloadTask task) => _db.upsert(task);
  Future<List<DownloadTask>> history() => _db.all();
}
