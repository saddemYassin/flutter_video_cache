

class Utils {

  /// Returns the file size in bytes from the progress and the downloaded bytes
  ///
  /// Total file size = downloaded bytes / progress * 100
  /// returns 0 if progress is 0
  static double calculateFileSizeFromProgressAndDownloadedBytes({required int progress, required int downloadedBytes}) {
    if(progress == 0) {
      return 0;
    }
    return downloadedBytes / progress * 100;
  }

}