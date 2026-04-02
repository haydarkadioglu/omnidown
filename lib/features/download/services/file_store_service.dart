import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:vid_donw/core/utils/file_naming.dart';

class FileStoreService {
  Future<Directory> downloadsDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final downloads = Directory(p.join(dir.path, 'downloads'));
    if (!await downloads.exists()) {
      await downloads.create(recursive: true);
    }
    return downloads;
  }

  Future<String> outputPath(String title, String ext) async {
    final baseDir = await downloadsDirectory();
    final fileName = '${sanitizedFileName(title)}.$ext';
    return p.join(baseDir.path, fileName);
  }
}
