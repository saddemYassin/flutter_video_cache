
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

class DownloadTaskPropertiesKeys {
  static const String url = 'url';
  static const String taskId = 'taskId';
  static const String filePath = 'savePath';
  static const String progress = 'progress';
  static const String headers = 'headers';
  static const String status = 'status';
  static const String createdAt = 'createdAt';
  static const String totalSize = 'totalSize';
  static const String startDownload = 'startDownload';
  static const String endDownload = 'endDownload';
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
  int progress;


  /// The total downloadSize
  int totalSize;

  /// The number of bytes that have been downloaded from the start of the file
  int startDownload;

  /// The number of bytes that have been downloaded from the end of the file
  int endDownload;


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
    required this.startDownload,
    required this.endDownload,
    required this.totalSize,
    this.headers = "",
    required this.status,
    required this.createdAt
  });

  /// Updates task status
  void updateStatus(DownloaderTaskStatus status,String source) {
    this.status = status;
  }

  /// Creates an instance of DownloadTask from a map
  factory DownloadTask.fromMap(Map<String, dynamic> map) {
    return DownloadTask(
      url: map[DownloadTaskPropertiesKeys.url],
      taskId: map[DownloadTaskPropertiesKeys.taskId].toString(),
      filePath: map[DownloadTaskPropertiesKeys.filePath],
      progress: map[DownloadTaskPropertiesKeys.progress],
      headers: map[DownloadTaskPropertiesKeys.headers] ?? "",
      status: DownloaderTaskStatus.fromInt(map[DownloadTaskPropertiesKeys.status]),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map[DownloadTaskPropertiesKeys.createdAt]),
      startDownload: map[DownloadTaskPropertiesKeys.startDownload],
      endDownload: map[DownloadTaskPropertiesKeys.endDownload],
      totalSize: map[DownloadTaskPropertiesKeys.totalSize],
    );
  }

  @override
  String toString() {
    return 'DownloaderTask{url: $url, taskId: $taskId, filePath: $filePath, progress: $progress,totalSize: $totalSize, startDownload: $startDownload, endDownload: $endDownload, headers: $headers, status: $status, createdAt: $createdAt}';
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