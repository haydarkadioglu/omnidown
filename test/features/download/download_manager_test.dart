import 'package:flutter_test/flutter_test.dart';
import 'package:vid_donw/features/download/services/download_manager.dart';

void main() {
  test('manager starts empty', () {
    final manager = DownloadManager();
    expect(manager.tasks, isEmpty);
  });
}
