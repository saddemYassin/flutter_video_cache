import 'package:flutter_video_cache/src/downloader_manager.dart';

/// Represents the status of a [DownloadTask].
enum DownloaderTaskStatus {
  /// Status of the task is either unknown or corrupted.
  undefined,

  /// The task is scheduled, but is not running yet.
  enqueued,

  /// The task is in progress.
  running,

  /// The task has completed successfully.
  complete,

  /// The task has failed.
  failed,

  /// The task was canceled and cannot be resumed.
  canceled,

  /// The task was paused and can be resumed
  paused;

  /// Creates a new [DownloaderTaskStatus] from an [int].
  factory DownloaderTaskStatus.fromInt(int value) {
    switch (value) {
      case 0:
        return DownloaderTaskStatus.undefined;
      case 1:
        return DownloaderTaskStatus.enqueued;
      case 2:
        return DownloaderTaskStatus.running;
      case 3:
        return DownloaderTaskStatus.complete;
      case 4:
        return DownloaderTaskStatus.failed;
      case 5:
        return DownloaderTaskStatus.canceled;
      case 6:
        return DownloaderTaskStatus.paused;
      default:
        return DownloaderTaskStatus.undefined;
    }
  }
}


/// An internal Downloader Task used by [DownloadManager]
///
/// To reduce the code changes when switching from downloader package to an other
class DownloadTask {

  /// The download url
  final String url;

  /// The task id
  final String taskId;

  /// The downloading/downloaded file path
  final String filePath;

  /// The download progress
  final int progress;

  /// The download headers
  final String headers;


  /// The task status
  DownloaderTaskStatus status;


  /// The date of creation time
  final DateTime createdAt;


  DownloadTask({
    required this.url,
    required this.taskId,
    required this.filePath,
    required this.progress,
    this.headers = "",
    required this.status,
    required this.createdAt
  });

  /// Updates task status
  void updateStatus(DownloaderTaskStatus status) {
    this.status = status;
  }

  @override
  String toString() {
    return 'DownloaderTask{url: $url, taskId: $taskId, filePath: $filePath, progress: $progress, headers: $headers, status: $status, createdAt: $createdAt}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is DownloadTask &&
              runtimeType == other.runtimeType &&
              url == other.url &&
              taskId == other.taskId &&
              filePath == other.filePath &&
              progress == other.progress &&
              headers == other.headers &&
              status == other.status &&
              createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(url.hashCode,taskId.hashCode,filePath.hashCode,progress.hashCode,headers.hashCode,status.hashCode,createdAt);

}