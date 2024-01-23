
class DownloadException implements Exception {
  const DownloadException(this.message);
  final String message;

  @override
  String toString() => 'Download exception $message';
}