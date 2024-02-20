import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:dio_http2_adapter/dio_http2_adapter.dart';
import 'package:flutter_video_cache/src/media_metadata_utils.dart';
import 'package:flutter_video_cache/src/models/download_task.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// Manages the downloading of MP4 files, including progress tracking and database management.
class Mp4FileDownloader {
  /// An instance of Dio for making HTTP requests.
  late Dio dio;

  /// A database instance for data storage.
  late Database _db;

  Database get database => _db;

  /// A directory where to save downloaded files
  late Directory saveDir;

  /// A map to save recent modified tasks on memory (without access to db everytime)
  final Map<String, DownloadTask> _tasks = <String, DownloadTask>{};

  /// A map to manage cancel tokens for asynchronous operations.
  ///
  /// This map associates unique identifiers (e.g., request keys) with
  /// CancelToken instances, allowing for cancellation of specific operations.
  final Map<String, CancelToken> _cancelTokens = <String, CancelToken>{};


  final List<void Function({required String url, required String taskId, required double progress, required int total, required int status})> _callbacks = [];


  static const metadataExpectedSize = 50000;


  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;


  static final Mp4FileDownloader _instance = Mp4FileDownloader._internal();

  /// Factory constructor to obtain the singleton instance of [Mp4FileDownloader].
  factory Mp4FileDownloader() {
    return _instance;
  }

  /// Internal constructor for the singleton instance.
  ///
  /// This constructor initializes the Dio instance with logging and HTTP2 support,
  /// and it initializes the database.
  Mp4FileDownloader._internal() {
    dio = Dio();
    dio.interceptors.add(LogInterceptor(responseBody: true));
    dio.httpClientAdapter = Http2Adapter(ConnectionManager(
      idleTimeout: const Duration(seconds: 10),
      onClientCreate: (_, config) => config.onBadCertificate = (_) => true,
    ));
  }


  /// Initializes the database and directory for tracking download information.
  ///
  /// This method initializes the save directory for downloaded videos, opens the database,
  /// and creates a "Downloads" table if it doesn't already exist. The table stores information
  /// about each download, including URL, save path, progress, total size, and status.
  ///
  /// Throws: May throw exceptions if there are issues during database initialization.
  Future<void> init() async {
    if(!_isInitialized) {
      var applicationDocumentsDirectory = await getApplicationDocumentsDirectory();
      saveDir = Directory('${applicationDocumentsDirectory.path}/video_downloads');
      if(!saveDir.existsSync()) {
        await saveDir.create(recursive: true);
      }
      // Retrieve the path for the database file.
      final databasesPath = await getDatabasesPath();
      final path = p.join(databasesPath, 'downloads.db');

      // Open the database and create the "Downloads" table if it doesn't exist.
      _db = await openDatabase(path, version: 1, onCreate: (Database db, int version) async {
        await db.execute('''
      CREATE TABLE IF NOT EXISTS Downloads (
        ${DownloadTaskPropertiesKeys.taskId} INTEGER PRIMARY KEY,
        ${DownloadTaskPropertiesKeys.url} TEXT,
        ${DownloadTaskPropertiesKeys.filePath} TEXT,
        ${DownloadTaskPropertiesKeys.progress} INTEGER,
        ${DownloadTaskPropertiesKeys.startDownload} INTEGER,
        ${DownloadTaskPropertiesKeys.endDownload} INTEGER,
        ${DownloadTaskPropertiesKeys.totalSize} INTEGER,
        ${DownloadTaskPropertiesKeys.createdAt} INTEGER,
        ${DownloadTaskPropertiesKeys.status} INTEGER
      )
    ''');
      });
      List<Map<String,dynamic>> results = await getDownloads();
      List<DownloadTask> tasksList = (results.map((e) => DownloadTask.fromMap(e)).toSet().toList());
      _tasks.addAll(tasksList.asMap().map((key, value) => MapEntry(value.url, value)));
      for(var k in _tasks.keys){
        print('log ${_tasks[k]!.url}:: ${_tasks[k]!.status}, ${_tasks[k]}');
        if([DownloaderTaskStatus.enqueued,DownloaderTaskStatus.running].contains(_tasks[k]!.status)) {
          if(_tasks[k]!.totalSize > 0 && _tasks[k]!.totalSize == _tasks[k]!.startDownload + _tasks[k]!.endDownload) {
            _tasks[k]!.status = DownloaderTaskStatus.complete;
            _updateDownloadStatus(_tasks[k]!.url, DownloaderTaskStatus.complete);
            continue;
          }
          _tasks[k]!.status = DownloaderTaskStatus.paused;
          _updateDownloadStatus(_tasks[k]!.url, DownloaderTaskStatus.paused);
        }
      }
      _isInitialized = true;
    }
  }


  List<DownloadTask> get downloadedTasks => _tasks.values.toList();

  /// Registers a callback function to receive progress updates during downloads.
  ///
  /// This method adds the provided callback function to the list of callbacks
  /// (_callbacks) to receive progress updates during downloads.
  ///
  /// Parameters:
  ///   - [callback]: A void function that takes three required parameters:
  ///                 - [url] : The URL of the resource being downloaded.
  ///                 - [received] : The amount of data received (downloaded) so far.
  ///                 - [total] : The total size of the resource being downloaded.
  void registerCallback(void Function({required String url,required String taskId, required double progress, required int total,required int status}) callback) {
    _callbacks.add(callback);
  }


  /// Initiates the download process for the specified [url].
  ///
  /// This method retrieves the save path, inserts an initial download entry
  /// into the "Downloads" table with status "Downloading," and starts the download
  /// using Dio. Progress updates are tracked and stored in the database.
  ///
  /// Parameters:
  ///   - [url] : The URL of the resource to be downloaded.
  ///   - [fileName] : The name of the file to be saved.
  ///
  /// Returns: A [Future] that completes with the file path of the downloaded file.
  ///
  /// Throws:
  ///   - [Exception] if the task is already started.
  ///   - May throw other exceptions if there are issues during the download.
  Future<DownloadTask> startDownload(String url,String fileName) async {
    Completer<DownloadTask>? completer = Completer();
    try {
      String savePath = _getSavePath(url,fileName);

      File file = File(savePath);


      bool fileExist = await file.exists();
      if(_tasks.containsKey(url)){

        if(_tasks[url]!.status == DownloaderTaskStatus.complete && fileExist){
          return _tasks[url]!;
        }

        if([DownloaderTaskStatus.enqueued, DownloaderTaskStatus.running].contains(_tasks[url]!.status)){
          throw Exception('Task already started');
        }

      }


      if(!fileExist){
        await file.create(recursive: true);
      }

      CancelToken cancelToken = CancelToken();
      int taskId = await _db.insert('Downloads', {
        DownloadTaskPropertiesKeys.url: url,
        DownloadTaskPropertiesKeys.filePath: savePath,
        DownloadTaskPropertiesKeys.progress: 0,
        DownloadTaskPropertiesKeys.totalSize: 0,
        DownloadTaskPropertiesKeys.startDownload: 0,
        DownloadTaskPropertiesKeys.endDownload: 0,
        DownloadTaskPropertiesKeys.createdAt: DateTime.now().millisecondsSinceEpoch,
        DownloadTaskPropertiesKeys.status: DownloaderTaskStatus.enqueued.index
      });

      _tasks[url] = DownloadTask(
          taskId: taskId.toString(),
          url: url,
          filePath: savePath,
          progress: 0,
          totalSize: 0,
          startDownload: 0,
          endDownload: 0,
          createdAt: DateTime.now(),
          status: DownloaderTaskStatus.enqueued);


      dio.download(
        url,
        file.path,
        onReceiveProgress: (received, total) async {
          double progress = (received / total * 100);
          for(var callback in _callbacks){
            callback(progress: progress,taskId: taskId.toString(),  total: total, url: url,status: DownloaderTaskStatus.running.index);
          }
          _tasks[url]!.progress = progress.toInt();
          _tasks[url]!.totalSize = total;
          _tasks[url]!.startDownload  = file.lengthSync();
          if(received == total){
            print('mp4_downloader set complete level 1 $url');
            _tasks[url]!.status = DownloaderTaskStatus.complete;
            _updateDownloadStatus(url, DownloaderTaskStatus.complete);
          }
          _updateDownloadProgressAndTotal(url, progress.toInt(), total);
          _updateStartDownload(url, _tasks[url]!.startDownload);
          if(received > metadataExpectedSize && completer != null){
            var metadata = await MediaMetadataUtils.retrieveMetadataFromFile(file);
            if(metadata == null){
              _safeCancelToken(cancelToken,'search for metadata');
              _cancelTokens.removeWhere((key, value) => key == url);
              await _downloadMetadataFromTheFileEnd(url: url,file: file,totalSize: total,startDownload: _tasks[url]!.startDownload,fromEndToDownload: metadataExpectedSize);
              metadata = await MediaMetadataUtils.retrieveMetadataFromFile(file);
              _tasks[url]!.status = DownloaderTaskStatus.paused;
              _updateDownloadStatus(url, DownloaderTaskStatus.paused);
              if(completer != null){
                _continueDownload(url);
                completer?.complete(_tasks[url]!);
                completer = null;
              }
            }

            if(completer != null){
              completer?.complete(_tasks[url]!);
              completer = null;
            }
          }

        },
        deleteOnError: false,
        cancelToken: cancelToken,
      ).then((value) {
        if(_tasks[url]!.totalSize == _tasks[url]!.startDownload + _tasks[url]!.endDownload){
          print('mp4_downloader set complete level 2 $url');
          _tasks[url]!.status = DownloaderTaskStatus.complete;
          _updateDownloadStatus(url, _tasks[url]!.status);
        }
      }).onError((error, stackTrace) {
        log('error $error');
      });
      _cancelTokens[url] = cancelToken;



      if(completer != null){
        return completer!.future;
      }
      return _tasks[url]!;
    } catch (e) {
      rethrow;
    }
  }


  /// Retrieves the download task and corresponding file for the specified [url].
  ///
  /// The download should be stared using [startDownload] first.
  /// This method checks whether the task is in memory (_tasks) or in the database.
  /// If the task is not found, it throws an exception.
  ///
  /// Parameters:
  ///   - [url] : The URL of the resource being downloaded.
  ///
  /// Returns: A [Future] that completes with a tuple containing the file and download task.
  ///
  /// Throws:
  ///   - [Exception] if the task is not found, already completed, or already downloading/running.
  ///   - [Exception] if the file associated with the task does not exist.
  Future<(File, DownloadTask)> _getTaskAndFileFromUrlToContinueDownload(String url) async {
    late DownloadTask currentTask;

    // Check if the task is in memory
    if (_tasks.containsKey(url)) {
      currentTask = _tasks[url]!;
    } else {
      // Retrieve the task from the database
      var taskDbObject = await _getDownload(url);
      if (taskDbObject == null) {
        throw Exception('Task not found');
      }

      currentTask = DownloadTask.fromMap(taskDbObject);
    }

    if ([DownloaderTaskStatus.enqueued, DownloaderTaskStatus.running].contains(currentTask.status)) {
      throw Exception('File already downloading/running. Cannot continue download.');
    }

    // Get the file associated with the task
    File file = File(currentTask.filePath);

    // Check if the file exists
    if (!file.existsSync()) {
      throw Exception('Cannot continue download on a non-existing file');
    }

    return (file, currentTask);
  }




  /// Continues the download process for the specified [url].
  ///
  /// This method retrieves the file and current download task associated with the URL.
  /// It then makes a HTTP GET request with a 'Range' header to resume the download from
  /// the last received byte. Progress updates are tracked and stored in the database.
  ///
  /// Parameters:
  ///   - [url] : The URL of the resource being downloaded.
  ///
  /// Throws: May throw exceptions if there are issues during the download process.
  Future<void> _continueDownload(String url) async {
    // Retrieve the file and current download task
    var (file, currentTask) = await _getTaskAndFileFromUrlToContinueDownload(url);

    // Create a cancel token for the HTTP request
    CancelToken cancelToken = CancelToken();

    if(currentTask.startDownload + currentTask.endDownload == currentTask.totalSize){
      print('mp4_downloader set complete level 3 $url');
      _updateDownloadStatus(url, DownloaderTaskStatus.complete);
      _tasks[url]!.status = DownloaderTaskStatus.complete;
      return;
    }

    // Make a HTTP GET request to resume the download
    var response = await dio.get<ResponseBody>(
      url,
      options: Options(
        headers: {'Range': 'bytes=${currentTask.startDownload}-${currentTask.totalSize - currentTask.endDownload}'},
        responseType: ResponseType.stream,
      ),
      cancelToken: cancelToken,
    ).onError((error, stackTrace) async {
      log('error $error');
      // return empty result
      return Response(requestOptions: RequestOptions(data: []));
    });
    _cancelTokens[url] = cancelToken;


    // Open the file in append mode
    RandomAccessFile fileAccess = file.openSync(mode: FileMode.append);
    fileAccess.setPositionSync(currentTask.startDownload);

    // Stream data to the file
    response.data?.stream.listen((bytes) {
      fileAccess.writeFromSync(bytes.toList());
      currentTask.startDownload += bytes.length;
      fileAccess.setPositionSync(currentTask.startDownload);
      _updateStartDownload(url, currentTask.startDownload);
      currentTask.progress = ((currentTask.startDownload + currentTask.endDownload) / currentTask.totalSize * 100).toInt();
      _updateDownloadProgress(url, currentTask.progress);
      for(var callback in _callbacks){
        callback(url: url,taskId: currentTask.taskId, progress: (currentTask.startDownload + currentTask.endDownload) / currentTask.totalSize * 100, total: currentTask.totalSize,status: DownloaderTaskStatus.running.index);
      }
    }).onDone(() {
      // Once download completes, update task status to 'complete' in the database
      print('mp4_downloader set complete level 4 $url');
      currentTask.status = DownloaderTaskStatus.complete;
      _updateDownloadStatus(url, currentTask.status);
      _updateDownloadProgress(url, 100);
      _cancelTokens.removeWhere((key, value) => key == url);
    });
  }



  /// Downloads metadata from the end of the file.
  ///
  /// This method retrieves metadata from the specified [url] by making a HTTP GET
  /// request with a 'Range' header to fetch data from the end of the file. It then
  /// appends the received metadata to the file and updates the end download position
  /// in the database.
  ///
  /// Parameters:
  ///   - [url] : The URL of the resource from which metadata is to be downloaded.
  ///   - [file] : The file to which the metadata will be appended.
  ///   - [totalSize] : The total size of the file.
  ///   - [startDownload] : The starting position of the download.
  ///   - [fromEndToDownload] : The amount of metadata to download from the end of the file.
  ///
  /// Throws: May throw exceptions if there are issues during the download process.
  Future<void> _downloadMetadataFromTheFileEnd({
    required String url,
    required File file,
    required int totalSize,
    required int startDownload,
    required int fromEndToDownload,
  }) async {

    // Create a cancel token for the HTTP request
    CancelToken cancelToken = CancelToken();
    _cancelTokens[url] = cancelToken;

    // Make a HTTP GET request to fetch metadata from the end of the file
    Response response = await dio.get(
      url,
      options: Options(
        headers: {'Range': 'bytes=${totalSize - fromEndToDownload}-$totalSize'},
        responseType: ResponseType.bytes,
      ),
      cancelToken: cancelToken,
    ).onError((error, stackTrace) {
      log('error $error');
      return Response(requestOptions: RequestOptions(data: []));
    });


    // Open the file in append mode and write the received metadata
    RandomAccessFile fileAccess = file.openSync(mode: FileMode.append);
    fileAccess.setPositionSync(totalSize - fromEndToDownload);
    fileAccess.writeFromSync(response.data);
    fileAccess.closeSync();

    // Log the current size of the file after downloading metadata

    _tasks[url]!.endDownload = fromEndToDownload;
    // Update the end download position in the database
    _updateEndDownload(url, fromEndToDownload);



    // Remove the cancel token from the tokens map
    _cancelTokens.removeWhere((key, value) => key == url);
  }


  /// Updates the download progress for the specified [url] in the "Downloads" table.
  ///
  /// This method is used to update the progress and total size of an ongoing download
  /// in the database. It performs a raw update query on the "Downloads" table based on
  /// the provided parameters.
  ///
  /// Parameters:
  ///   - [url] : The URL of the resource being downloaded.
  ///   - [received] : The amount of data received (downloaded) so far.
  ///   - [total] : The total size of the resource being downloaded.
  ///
  /// Throws: May throw exceptions if there are issues during the database update.
  Future<void> _updateDownloadProgressAndTotal(String url, int received, int total) async {
    await _db.rawUpdate(
      'UPDATE Downloads SET ${DownloadTaskPropertiesKeys.progress} = ?, ${DownloadTaskPropertiesKeys.totalSize} = ? WHERE ${DownloadTaskPropertiesKeys.url} = ?',
      [received, total, url],
    );
  }

  /// Updates the download progress in the database for the specified URL.
  ///
  /// This method updates the progress of a download in the "Downloads" table of the
  /// database. It sets the value of the progress column to the specified [received]
  /// value for the download identified by the given [url].
  ///
  /// Parameters:
  ///   - [url] : The URL of the download for which progress is to be updated.
  ///   - [received] : The amount of data received for the download.
  ///
  /// Throws: May throw exceptions if there are issues during the database update.
  Future<void> _updateDownloadProgress(String url, int received) async {
    // Update the progress in the database
    await _db.rawUpdate(
      'UPDATE Downloads SET ${DownloadTaskPropertiesKeys.progress} = ? WHERE ${DownloadTaskPropertiesKeys.url} = ?',
      [received, url],
    );
  }


  /// Updates the start download position in the database for the specified URL.
  ///
  /// This method updates the start download position of a download in the "Downloads"
  /// table of the database. It sets the value of the startDownload column to the specified
  /// [startDownload] value for the download identified by the given [url].
  ///
  /// Parameters:
  ///   - [url] : The URL of the download for which the start download position is to be updated.
  ///   - [startDownload] : The new start download position value.
  ///
  /// Throws: May throw exceptions if there are issues during the database update.
  Future<void> _updateStartDownload(String url, int startDownload) async {
    // Update the start download position in the database
    await _db.rawUpdate(
      'UPDATE Downloads SET ${DownloadTaskPropertiesKeys.startDownload} = ? WHERE ${DownloadTaskPropertiesKeys.url} = ?',
      [startDownload, url],
    );
  }


  /// Updates the end download position in the database for the specified URL.
  ///
  /// This method updates the end download position of a download in the "Downloads"
  /// table of the database. It sets the value of the endDownload column to the specified
  /// [endDownload] value for the download identified by the given [url].
  ///
  /// Parameters:
  ///   - [url] : The URL of the download for which the end download position is to be updated.
  ///   - [endDownload] : The new end download position value.
  ///
  /// Throws: May throw exceptions if there are issues during the database update.
  Future<void> _updateEndDownload(String url, int endDownload) async {
    // Update the end download position in the database
    await _db.rawUpdate(
      'UPDATE Downloads SET ${DownloadTaskPropertiesKeys.endDownload} = ? WHERE ${DownloadTaskPropertiesKeys.url} = ?',
      [endDownload, url],
    );
  }


  /// Updates the download status for the specified [url] in the "Downloads" table.
  ///
  /// This method is used to update the status of a download in the database. It performs
  /// a raw update query on the "Downloads" table based on the provided parameters.
  ///
  /// Parameters:
  ///   - [url] : The URL of the resource being downloaded.
  ///   - [status] : The new status to be set for the download.
  ///
  /// Throws: May throw exceptions if there are issues during the database update.
  Future<void> _updateDownloadStatus(String url, DownloaderTaskStatus status) async {
    await _db.rawUpdate('UPDATE Downloads SET ${DownloadTaskPropertiesKeys.status} = ? WHERE url = ?', [status.index, url]);
  }

  /// Pauses an ongoing download for the specified [url].
  ///
  /// This method checks if there is an active download associated with the given [url]
  /// and, if found, cancels the corresponding cancel token to pause the download. The
  /// download status is then updated to 'Paused' in the "Downloads" table.
  ///
  /// Parameters:
  ///   - [url] : The URL of the resource being downloaded.
  ///
  /// Note: If there is no active download for the provided [url], this method has no effect.
  ///
  /// Throws: May throw exceptions if there are issues during the database update.
  Future<void> pauseDownload(String url) async {
    if(_cancelTokens.containsKey(url)){
      _safeCancelToken(_cancelTokens[url]!, 'pause download');
      _cancelTokens.removeWhere((key, value) => key == url);
      if(_tasks.containsKey(url)){
        _tasks[url]?.updateStatus(DownloaderTaskStatus.paused);
      }
      await _updateDownloadStatus(url, DownloaderTaskStatus.paused);
    }
  }

  /// Resumes a paused download for the specified [url].
  ///
  /// This method retrieves the existing download information from the database,
  /// resumes the download using Dio with a specified range based on the progress,
  /// and updates the download status to 'Downloading' in the "Downloads" table.
  ///
  /// Parameters:
  ///   - [url]: The URL of the resource being downloaded.
  ///
  /// Throws: May throw exceptions if there are issues during the database operations or download.
  Future<void> resumeDownload(String url) async {
    await _continueDownload(url);
  }


  /// Cancels an ongoing or paused download for the specified [url].
  ///
  /// This method checks if there is an active or paused download associated with the
  /// given [url] and, if found, cancels the corresponding cancel token to stop the download.
  /// The download entry is then removed from the "Downloads" table in the database.
  ///
  /// Parameters:
  ///   - [url] : The URL of the resource being downloaded.
  ///
  /// Note: If there is no active or paused download for the provided [url], this method has no effect.
  ///
  /// Throws: May throw exceptions if there are issues during the database operations.
  Future<void> cancelDownload(String url) async {
    if(_cancelTokens.containsKey(url)){
      _safeCancelToken(_cancelTokens[url]!, 'cancel download');
      _cancelTokens.removeWhere((key, value) => key == url);
      await _db.delete('Downloads', where: 'url = ?', whereArgs: [url]);
    }
  }

  /// Retrieves a list of all downloads from the "Downloads" table in the database.
  ///
  /// Returns: A [Future] that completes with a list of maps, where each map represents
  /// the details of a download entry, including URL, save path, progress, total size, and status.
  ///
  /// Throws: May throw exceptions if there are issues during the database query.
  Future<List<Map<String, dynamic>>> getDownloads() async {
    return await _db.query('Downloads');
  }

  /// Retrieves download information for the specified [url] from the "Downloads" table.
  ///
  /// Parameters:
  ///   - [url]: The URL of the resource being downloaded.
  ///
  /// Returns: A [Future] that completes with a map representing the details of the download
  /// entry if found, or `null` if no entry exists for the provided [url].
  ///
  /// Throws: May throw exceptions if there are issues during the database query.
  Future<Map<String, dynamic>?> _getDownload(String url) async {
    List<Map<String, dynamic>> result = await _db.query('Downloads', where: 'url = ?', whereArgs: [url]);
    return result.isNotEmpty ? result.first : null;
  }

  /// Generates and returns the local save path for a download based on the [url].
  ///
  /// Parameters:
  ///   - [url]: The URL of the resource being downloaded.
  ///
  /// Returns: A [Future] that completes with a string representing the local save path.
  String _getSavePath(String url,String fileName) {
    return '${saveDir.path}/$fileName';
  }


  /// Safely cancels the cancel token associated with the given URL.
  ///
  /// This method checks if there is a cancel token associated with the provided [url].
  /// If found, it attempts to cancel the cancel token with the optional [reason].
  /// If any error occurs during cancellation, it logs the error message.
  ///
  /// Parameters:
  ///   - [cancelToken] : The cancel token to be canceled.
  ///   - [reason] : An optional reason for canceling the token.
  ///
  /// Note: This method ensures safe cancellation by handling potential errors.
  void _safeCancelToken(CancelToken cancelToken, [String reason = '']) {
    // Check if the cancel token exists for the given URL
      try {
        // Attempt to cancel the cancel token with the provided reason
        cancelToken.cancel(reason);
      } catch (e) {
        // Log any error that occurs during cancellation
        // log(e.toString());
      }
  }

}
