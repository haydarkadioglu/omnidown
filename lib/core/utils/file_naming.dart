String sanitizedFileName(String input) {
  final value = input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  return value.isEmpty ? 'download' : value;
}
