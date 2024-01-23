
/// An exception that is thrown when a file does not exist in case it should be exists.
class FileNotExistsException implements Exception {

  final String? message;
  const FileNotExistsException([this.message]);

  @override
  String toString() => message ?? 'FileNotExistsException';
}