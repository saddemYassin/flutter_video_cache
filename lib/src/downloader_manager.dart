import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter_downloader/flutter_downloader.dart' as external_downloader;
import 'package:flutter_video_cache/flutter_video_cache.dart';
import 'package:flutter_video_cache/src/models/downloader_task.dart';
import 'package:flutter_video_cache/src/models/exceptions/download_exception.dart';
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
  final Map<String, Function(int)> _onProgressCallbacks = <String, Function(int)>{};

  /// The list of downloaded tasks in the downloader package local database on init
  final List<DownloadTask> _inCacheDownloadedTasks = <DownloadTask>[];

  late Directory _saveDirectory;

  final ReceivePort _port = ReceivePort();


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
  Future<void> init() async {
    // Retrieve the persistent data path and set it to [_saveDirectory].
    _saveDirectory = await getApplicationDocumentsDirectory();

    // Initialize the downloader package from external_downloader.
    external_downloader.FlutterDownloader.initialize(debug: false, ignoreSsl: true);

    // Load all tasks from the downloader package and save them in [_inCacheDownloadedTasks].
    _inCacheDownloadedTasks.addAll(
      (await external_downloader.FlutterDownloader.loadTasks())
          ?.map((e) => _mapDownloadTaskToDownloaderTask(e))
          .toList() ?? [],
    );

    // TODO: Implement logic to delete every expired file.

    // Register the port with IsolateNameServer and set up a listener for task updates.
    IsolateNameServer.registerPortWithName(_port.sendPort, 'downloader_send_port');
    _port.listen((dynamic data) {
      String id = data[0];
      DownloaderTaskStatus status = DownloaderTaskStatus.fromInt(data[1]);
      int progress = data[2];

      if (_accessMap[id] != null) {
        // Invoke progress callbacks if available.
        if (_onProgressCallbacks[_accessMap[id]] != null) {
          _onProgressCallbacks[_accessMap[id]]!(progress);
        }

        // Update task status and manage downloading tasks.
        if (_tasks[_accessMap[id]] != null) {
          _tasks[_accessMap[id]]!.updateStatus(status);
          if (_tasks[_accessMap[id]]!.status == DownloaderTaskStatus.running) {
            _downloadingTasks[_accessMap[id]!] = _tasks[_accessMap[id]]!;
          } else {
            _downloadingTasks.remove(_accessMap[id]);
          }
        }
      }
    });

    // Register the download callback.
    external_downloader.FlutterDownloader.registerCallback(downloadCallback);
  }


  /// Returns the path of the downloaded file
  /// [key] presents an identification to the file download process and can be used to pause, resume or cancel the download
  /// [DownloadManager] should be initialized before calling this methode
  Future<String> startDownload(String url, Function(int) callback, {String fileExtension = 'mp4', String? key}) async {
    assert(external_downloader.FlutterDownloader.initialized, 'You must call init before calling this methode');
    //check if the file is already downloaded by verifying if the url exists in the tasks inside _inCacheDownloadedTasks
    int indexOfTask = _inCacheDownloadedTasks.indexWhere((element) => element.url == url);
    if (indexOfTask != -1) {
      // save the key as a value for taskId in the _accessMap (_inCacheDownloadedTasks[index].taskId: key) & fill [_tasks], [_downloadingTasks] and _onProgressCallbacks
      _accessMap[_inCacheDownloadedTasks[indexOfTask].taskId] = key ?? url;
      // resume the download of the file
      _tasks[key ?? url] = _inCacheDownloadedTasks[indexOfTask];
      external_downloader.FlutterDownloader.resume(taskId: _accessMap[key ?? url]!);
      _onProgressCallbacks[key ?? url] = callback;
      return _inCacheDownloadedTasks[indexOfTask].filePath;
    }

    // enter the url to the download queue and get the taskId
    String fileName = '${key ?? DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    String? taskId = await external_downloader.FlutterDownloader.enqueue(
        url: url,
        savedDir: _saveDirectory.path,
        fileName: fileName,
        showNotification: false,
        openFileFromNotification: false,
    );
    if(taskId == null) throw Exception('Failed to start download: taskId not found');

    // save taskId as key and key as value in the _accessMap
    _accessMap[key ?? url] = taskId;
    _tasks[key ?? url] = DownloadTask(
        taskId: taskId,
        url: url,
        createdAt: DateTime.now(),
        filePath: '${_saveDirectory.path}/$fileName',
        progress: 0,
        status: DownloaderTaskStatus.enqueued
    );
    _onProgressCallbacks[key ?? url] = callback;
    return _tasks[key ?? url]!.filePath;
  }


  /// Pauses the download of a file by given [key]
  ///
  /// [DownloadManager] should be initialized before calling this methode
  void pauseDownload(String key) {
    assert(external_downloader.FlutterDownloader.initialized, 'You must call init before calling this methode');
    if(!_accessMap.containsKey(key) || _accessMap[key] == null){
      throw const DownloadException('cannot pause non started download');
    }
    external_downloader.FlutterDownloader.pause(taskId: _accessMap[key]!);
  }

  /// Resumes the download of a file by given [key]
  void resumeDownload(String key) {
    assert(external_downloader.FlutterDownloader.initialized, 'You must call init before calling this methode');
    if(!_accessMap.containsKey(key) || _accessMap[key] == null){
      throw const DownloadException('cannot resume non started download');
    }
    external_downloader.FlutterDownloader.resume(taskId: _accessMap[key]!);
  }

  /// Cancel the download of a file by given [key]
  void cancelDownload(String key) {
    assert(external_downloader.FlutterDownloader.initialized, 'You must call init before calling this methode');
    if(!_accessMap.containsKey(key) || _accessMap[key] == null){
      throw const DownloadException('cannot cancel non started download');
    }
    external_downloader.FlutterDownloader.cancel(taskId: _accessMap[key]!);
  }

  /// Register callbacks for the downloader package
  void registerProgressCallbackForTask(String taskId, Function(int) callback) {
    _onProgressCallbacks[taskId] = callback;
  }


  /// Converts external package downloadTask to DownloaderTask
  DownloadTask _mapDownloadTaskToDownloaderTask(external_downloader.DownloadTask task) {
    return DownloadTask(
      url: task.url,
      taskId: task.taskId,
      filePath: '${task.savedDir}/${(task.filename ?? task.taskId)}',
      progress: task.progress,
      status: DownloaderTaskStatus.fromInt(task.status.index),
      createdAt: DateTime.fromMillisecondsSinceEpoch(task.timeCreated * 1000),
    );
  }


  /// A callback method used by the downloader package to provide download progress updates.
  ///
  /// Parameters:
  ///   - [id] : The unique identifier of the download task.
  ///   - [status] : The status of the download task.
  ///   - [progress] : The progress value indicating the advancement of the download.
  ///
  /// This method is annotated with `@pragma('vm:entry-point')` to indicate it as
  /// the entry point for Dart VM.
  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    // Lookup the send port by name.
    final SendPort? send = IsolateNameServer.lookupPortByName('downloader_send_port');

    // Send the download progress update to the registered port.
    send?.send([id, status, progress]);
  }


}