import 'dart:io';

import 'package:flutter_video_cache/src/models/download_task.dart';
import 'package:flutter_video_cache/src/models/exceptions/download_exception.dart';
import 'package:flutter_video_cache/src/mp4_donwloader.dart';
import 'package:path_provider/path_provider.dart';

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
  final Map<String, Function(int,int)> _onProgressCallbacks = <String, Function(int,int)>{};

  /// The list of downloaded tasks in the downloader package local database on init
  final List<DownloadTask> _inCacheDownloadedTasks = <DownloadTask>[];


  final Mp4FileDownloader _mp4FileDownloader = Mp4FileDownloader();



  DownloadManager._internal();

  factory DownloadManager() {
    return _instance;
  }

  /// Asynchronously initializes the downloader and sets up necessary configurations.
  ///
  /// This method performs the following tasks:
  ///   1. Retrieves the persistent data path and sets it to [_saveDirectory].
  ///   2. Initializes the downloader package from external_downloader.
  ///   3. Loads all tasks from the downloader package and saves them in [_inCacheDownloadedTasks].
  ///   4. Registers the download callback and sets up a listener on [_port] for task updates.
  ///   5. Registers the port with IsolateNameServer.
  ///
  /// Note: This method assumes the existence of external_downloader and related classes.
  ///
  /// Throws: May throw exceptions if there are issues during initialization.
  Future<void> init({bool debug = false}) async {
    // Retrieve the persistent data path and set it to [_saveDirectory].

    await _mp4FileDownloader.init();

    // Load all tasks from the downloader package and save them in [_inCacheDownloadedTasks].
    _inCacheDownloadedTasks.addAll(_mp4FileDownloader.downloadedTasks);


    // TODO: Implement logic to delete every expired file.

    _mp4FileDownloader.registerCallback(({required String url,required String taskId, required double progress, required int total,required int status}) {

      DownloaderTaskStatus taskStatus = DownloaderTaskStatus.fromInt(status);

      if (taskId != null) {
        // Invoke progress callbacks if available.
        if (_onProgressCallbacks[taskId] != null) {
          _onProgressCallbacks[taskId]!(progress.toInt(),total);
        }

        // Update task status and manage downloading tasks.
        if (_tasks[taskId] != null) {
          _tasks[taskId]!.updateStatus(taskStatus);
          if (_tasks[taskId]!.status == DownloaderTaskStatus.running) {
            _downloadingTasks[taskId!] = _tasks[taskId]!;
          } else {
            _downloadingTasks.removeWhere((key, value) => key == taskId);
          }
        }
      }
    });

  }


  /// Returns the path of the downloaded file
  /// [key] presents an identification to the file download process and can be used to pause, resume or cancel the download
  /// [DownloadManager] should be initialized before calling this methode
  Future<DownloadTask> startDownload(String url, Function(int,int) callback, {String fileExtension = 'mp4', String? key}) async {
    assert(_mp4FileDownloader.isInitialized, 'You must call init before calling this methode');
    //check if the file is already downloaded by verifying if the url exists in the tasks inside _inCacheDownloadedTasks
    int indexOfTask = _inCacheDownloadedTasks.indexWhere((element) => element.url == url);
    if (indexOfTask != -1) {
      // save the key as a value for taskId in the _accessMap (_inCacheDownloadedTasks[index].taskId: key) & fill [_tasks], [_downloadingTasks] and _onProgressCallbacks
      _accessMap[key ?? url] = _inCacheDownloadedTasks[indexOfTask].taskId;
      // resume the download of the file
      _tasks[_inCacheDownloadedTasks[indexOfTask].taskId] = _inCacheDownloadedTasks[indexOfTask];
      // _mp4FileDownloader.resume(taskId: _accessMap[key ?? url]!);
      print('$key _tasks[_inCacheDownloadedTasks[indexOfTask].taskId]!.status ${_tasks[_inCacheDownloadedTasks[indexOfTask].taskId]!.status}');
      if(_tasks[_inCacheDownloadedTasks[indexOfTask].taskId]!.status != DownloaderTaskStatus.complete) {
        print('resume precache in video streamer $key');
        await _mp4FileDownloader.resumeDownload(url);
        _onProgressCallbacks[_inCacheDownloadedTasks[indexOfTask].taskId] = callback;
      }
      return _inCacheDownloadedTasks[indexOfTask];
    }

    // enter the url to the download queue and get the taskId
    String fileName = '${key ?? DateTime.now().millisecondsSinceEpoch}.$fileExtension';

    var task = await _mp4FileDownloader.startDownload(url, fileName);


    // save taskId as key and key as value in the _accessMap
    _accessMap[key ?? url] = task.taskId;
    _tasks[task.taskId] = task;
    _onProgressCallbacks[task.taskId] = callback;
    return _tasks[task.taskId]!;
  }


  /// Pauses the download of a file by given [key]
  ///
  /// [DownloadManager] should be initialized before calling this methode
  void pauseDownload(String key) {
    print('pause Precache in video streamer $key');
    assert(_mp4FileDownloader.isInitialized, 'You must call init before calling this methode');
    if(!_accessMap.containsKey(key) || _accessMap[key] == null){
      throw const DownloadException('cannot pause non started download');
    }
    // external_downloader.FlutterDownloader.pause(taskId: _accessMap[key]!);
    _mp4FileDownloader.pauseDownload(_tasks[_accessMap[key]!]!.url);
  }

  /// Resumes the download of a file by given [key]
  void resumeDownload(String key) {
    print('resume Precache in video streamer $key');
    assert(_mp4FileDownloader.isInitialized, 'You must call init before calling this methode');
    if(!_accessMap.containsKey(key) || _accessMap[key] == null){
      throw const DownloadException('cannot resume non started download');
    }
    // external_downloader.FlutterDownloader.resume(taskId: _accessMap[key]!);
    _mp4FileDownloader.resumeDownload(_tasks[_accessMap[key]!]!.url);
  }

  /// Cancel the download of a file by given [key]
  void cancelDownload(String key) {
    assert(_mp4FileDownloader.isInitialized, 'You must call init before calling this methode');
    if(!_accessMap.containsKey(key) || _accessMap[key] == null){
      throw const DownloadException('cannot cancel non started download');
    }
    // external_downloader.FlutterDownloader.cancel(taskId: _accessMap[key]!);
    _mp4FileDownloader.cancelDownload(_tasks[_accessMap[key]!]!.url);
  }

  /// Register callbacks for the downloader package
  void _registerProgressCallbackForTask(String taskId, Function(int,int) callback) {
    _onProgressCallbacks[taskId] = callback;
  }

}