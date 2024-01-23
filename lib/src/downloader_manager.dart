import 'package:flutter_video_cache/src/models/downloader_task.dart';

/// A singleton class

class DownloadManager {
  static final DownloadManager _instance = DownloadManager._internal();

  static DownloadManager get instance => _instance;


  /// The map to save the external downloaded task access key and the taskId in downloader package
  ///
  /// The key is the taskId given by the used downloader package
  /// The value is the key given by the developer when calling [startDownload]
  final Map<String, String> _accessMap = <String, String>{};

  /// The map to save all downloading/downloaded/ToDownload tasks
  ///
  /// The key is the key given by the developer when calling [startDownload]
  final Map<String, DownloadTask> _tasks = <String, DownloadTask>{};

  /// The map to save all downloading tasks
  ///
  /// The key is the key given by the developer when calling [startDownload]
  final Map<String, DownloadTask> _downloadingTasks = <String, DownloadTask>{};

  /// The map where save every callback that should be called by [onProgress]
  ///
  /// The key is the key given by the developer when calling [startDownload] retrieved using the [_accessMap]
  final Map<String, Function(int)> _onProgressCallbacks = <String, Function(int)>{};

  /// The list of downloaded tasks in the downloader package local database on init
  final List<DownloadTask> _inCacheDownloadedTasks = <DownloadTask>[];




  DownloadManager._internal();

  factory DownloadManager() {
    return _instance;
  }

  Future<void> init() async {
    // TODO init persistent data path
    // TODO init the downloader package
    // TODO Load all tasks from the downloader package and save them in the _inCacheDownloadedTasks
    // TODO delete every expired file
  }

  /// TODO : Returns the path of the downloaded file
  /// [key] presents an identification to the file download process and can be used to pause, resume or cancel the download
  /// [DownloadManager] should be initialized before calling this methode
  Future<String> startDownload(String url, Function(int) callback, {String fileExtension = 'mp4', String? key}) {
    /// TODO #1 check if the file is already downloaded by verifying if the url exists in the tasks inside _inCacheDownloadedTasks
    if (true) {
      /// TODO  if #1 is true
      /// TODO save the key as a value for taskId in the _accessMap (_inCacheDownloadedTasks[index].taskId: key) & fill [_tasks], [_downloadingTasks] and _onProgressCallbacks

      /// TODO resume the download of the file
      /// TODO return the path of the downloaded/downloading file
    }

    /// TODO if #1 is false enter the url to the download queue and get the taskId
    /// TODO save taskId as key and key as value in the _accessMap
    /// TODO get task from downloader package database and map it in [_downloadingTasks] & [_tasks] &  save [callback] in [_onProgressCallbacks]
    /// TODO return the downloaded/downloading file path "$_saveDir/$taskId.$fileExtension"
    return Future(() => '');
  }


  /// TODO Pauses the download of a file by given [key]
  ///
  /// [DownloadManager] should be initialized before calling this methode
  void pauseDownload(String key) {
    /// TODO get the taskId from [_accessMap] and pause the download of the file
  }

  /// TODO : Resumes the download of a file by given [key]
  void resumeDownload(String key) {
    /// TODO get the taskId from [_accessMap] and resume the download of the file
  }

  /// TODO : Cancels the download of a file by given [key]
  void cancelDownload(String key) {
    /// TODO get the taskId from [_accessMap] and cancel the download of the file
  }


  void registerProgressCallbackForTask(String taskId, Function(int, int) callback) {
    /// TODO Register callbacks for the downloader package
  }


  /// TODO methode to convert external package downloadTask to DownloaderTask
  /*DownloaderTask _mapDownloadTaskToDownloaderTask(DownloadTask task) {
    // TODO map from external model to internal model
  }*/


}