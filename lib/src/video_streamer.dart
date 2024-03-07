import 'dart:async';
import 'dart:io';
import 'package:flutter_video_cache/src/consts.dart';
import 'package:flutter_video_cache/src/downloader_manager.dart';
import 'package:flutter_video_cache/src/media_metadata_utils.dart';
import 'package:flutter_video_cache/src/models/download_task.dart';
import 'package:flutter_video_cache/src/models/exceptions/file_not_exist_exception.dart';
import 'package:flutter_video_cache/src/models/exceptions/video_streamer_exception.dart';
import 'package:flutter_video_cache/src/models/media_metadata.dart';
import 'package:flutter_video_cache/src/models/playable_interface.dart';


/// A class representing a video streamer for playing media content.
///
/// This class provides functionalities for pre-caching, initializing, and playing media content through the associated [playable] object, which implements the [PlayableInterface].
class VideoStream<T extends PlayableInterface> {

  /// A playable object that can be played/paused depends on data status on [dataFile]
  final T playable;

  /// The data file where the video/audio is stored
  File? _dataFile;

  /// The file downloader manager
  final DownloadManager _downloaderManager = DownloadManager.instance;

  /// The total duration of the media
  int _mediaDurationInSeconds = 0;

  /// The [_mediaDurationInSeconds] getter
  int get mediaDurationInSeconds => _mediaDurationInSeconds;

  /// The number of seconds of the loaded media inside [_dataFile]
  int _loadedMediaDurationInSeconds = 0;

  /// The [_loadedMediaDurationInSeconds] getter
  int get loadedMediaDurationInSeconds => _loadedMediaDurationInSeconds;

  /// True if the media is initialized
  ///
  /// [_dataFile] is created
  bool _mediaInitialized = false;


  /// True if the data source is initialized
  bool _dataSourceInitialized = false;

  /// A timer to check if the media can start playing
  Timer? playingCheckTimer;

  /// True if the video/audio can start playing
  ///
  /// true if we can read metadata of [_dataFile]
  bool _canStartPlaying = false;

  /// True if [play] is called and it's paused due to not enough data
  bool _waitingForData = false;

  /// True if is precaching data
  bool _isPreCaching = false;


  /// [_isPreCaching] getter
  bool get isPreCaching => _isPreCaching;

  /// The total length of [_dataFile]
  int _totalFileSizeInBytes = 0;

  /// A list of callback that should be called by [onProgress]
  final List<void Function({required int percentage,required int loadedSeconds,required int loadedBytes})> _onProgressCallbacks = [];


  /// The [_downloaderManager] task key
  late final String cacheKey;

  /// The media remote url
  final String url;


  /// Completer used to signal completion of setting the data source.
  Completer<void>? _setDataSourceCompleter;

  /// Completer used to signal completion of initialization.
  Completer<void>? _initCompleter;

  /// Completer used to signal completion of pre-caching initialization.
  Completer<void>? _initPreCachingCompleter;

  /// Completer used to signal completion of pausing pre-caching.
  Completer<void>? _pausePreCachingCompleter;


  /// Creates a new instance of [VideoStream].
  ///
  /// This constructor initializes a [VideoStream] object with the following required parameters:
  ///
  /// * [url] : The URL of the media content to be streamed.
  /// * [playable] : The underlying library or component responsible for playback, implementing `PlayableInterface`.
  ///
  /// Additionally, an optional parameter [cacheKey] allows specifying a custom cache key for pre-cached media data.
  /// If [cacheKe] is not provided, the constructor automatically sets it to the [url].
  VideoStream({required this.url,required this.playable, String? cacheKey}){
    if(cacheKey == null){
      this.cacheKey = url;
    } else {
      this.cacheKey = cacheKey;
    }
  }

  /// Returns true if the player is initialized and ready to start playing media.
  bool get isInitialized => playable.isInitialized && _mediaInitialized && _canStartPlaying;


  /// Sets the data source for media playback asynchronously.
  ///
  /// This method ensures that the media is pre-cached before setting the data source,
  /// if the media hasn't been initialized yet. It then sets the data source using
  /// the file path obtained from [_dataFile].
  ///
  /// Note: This method assumes the existence of [_mediaInitialized], [preCache],
  /// [playable], and [_dataFile].
  ///
  /// Throws: May throw exceptions if there are issues during pre-caching or setting the data source.
  Future<void> injectDataSource() async {
    // If media is not initialized, pre-cache it before setting the data source.
    if (!_mediaInitialized) {
      _setDataSourceCompleter = Completer();
      if(!_isPreCaching){
        preCache();
      }
    }

    if(_setDataSourceCompleter != null){
      await _setDataSourceCompleter!.future;
    }


    // Set the data source for media playback using the file path.
    await playable.setDataSource(_dataFile!.path);
    _dataSourceInitialized = true;
  }


  /// Initializes the video streamer for playback.
  ///
  /// This method initializes the video streamer for playback. It performs the following checks and actions:
  ///
  /// 1. **Verifies Pre-Requisites:**
  /// - Checks if both [_mediaInitialized] and [_dataSourceInitialized] flags are true. These flags indicate:
  /// - [_mediaInitialized] : Successful media initialization (media metadata verified).
  /// - [_dataSourceInitialized] : Successful data source initialization (data file exists and accessible).
  /// - If any flag is false, throws a [VideoStreamerException] with the message "cannot initialize a video streamer without initializing media and data source". This ensures pre-requisites are met before proceeding.
  ///
  /// 2. **Initializes Playable Object (if necessary):**
  /// - If the [playable] object is not null and hasn't been initialized yet (`!playable.isInitialized`), calls [playable.initialize()] to perform specific initialization steps required by the playback library/object. This ensures the playable object is ready for playback.
  ///
  /// 3. **Handles Already Initialized State:**
  /// - If the streamer is already in a playable state ([_canStartPlaying] is true), the method directly returns. This avoids unnecessary initialization steps if the streamer is already prepared.
  ///
  /// 4. **Waits for Initialization Completion (if not ready):**
  /// - If the streamer is not yet ready for playback (![_canStartPlaying]), the method:
  /// - Creates a new [_initCompleter] to signal completion of initialization.
  /// - Returns the [_initCompleter] future, allowing the caller to await completion before proceeding. This enables asynchronous handling of the initialization process.
  ///
  /// Returns: A `Future<void>` that completes when the video streamer initialization is complete.
  Future<void> initialize() async {
    if(_mediaInitialized && _dataSourceInitialized) {
      if(playable != null && !playable.isInitialized){
        await playable.initialize();
      }
      if(!_canStartPlaying){
        _initCompleter = Completer();
        return _initCompleter!.future;
      }
      return;
    }
    throw const VideoStreamerException('cannot initialize a video streamer without initializing media and data source');
  }

  /// Pre-caches media content.
  ///
  /// This method initiates pre-caching of media content associated with the
  /// provided [url]. It performs the following actions:
  ///
  /// **1. Waits for initialization completion (if necessary):**
  ///   - If the [_initPreCachingCompleter] is not null, the method waits for its
  ///   future to complete. This might indicate an initialization process that
  ///   needs to finish before pre-caching.
  ///
  /// **2. Checks pre-caching status:**
  /// - If pre-caching is already in progress ([_isPreCaching] is true), the
  ///   method calls [resumePreCaching] to continue pre-caching, and exits.
  ///
  /// **3. Starts download (if data file doesn't exist):**
  ///  - Checks if the [_dataFile] has already been set.
  /// - If [_dataFile] is null, it indicates the data file hasn't been downloaded yet.
  /// - Sets [_isPreCaching] to `true` to indicate pre-caching has started.
  /// - Creates a new [_initPreCachingCompleter] to signal completion of pre-caching initialization.
  /// - Calls [_downloaderManager.startDownload] to
  ///    start downloading the media content, passing the provided [url], progress callback ([onProgress]), and [cacheKey].
  /// - Stores the downloaded file path in [_dataFile] from the [DownloadTask] object returned by the download manager.
  /// - Verifies if the downloaded file exists using [File.existsSync].
  /// - Throws a [FileNotExistsException] if the file doesn't exist.
  /// - Sets [_mediaInitialized] to `true` to indicate successful media initialization.
  ///
  /// **4. Verifies media metadata:**
  /// - Calls [verifyMediaMetadata] passing [task.totalSize] and [task.startDownload] + [task.endDownload]  to verify media metadata (details not shown in the provided code).
  ///
  /// **5. Completes pre-caching initialization:**
  /// - Calls `_completeDataSource()`, `_completeInit()`, and `_completePrecacheInit()` to signal the completion of various initialization stages within pre-caching (implementation details not shown).
  ///
  /// **6. Notifies listeners (if progress callbacks exist):**
  /// - Iterates through the [_onProgressCallbacks] list and calls each callback with the current pre-caching progress information.
  ///
  ///**7. Returns and handles exceptions:**
  /// - If no errors occur, the method returns.
  /// - In case of an exception during pre-caching:
  /// - Sets [_isPreCaching] to `false` to indicate failure.
  /// - Calls [_completePrecacheInit] to signal completion of pre-caching initialization with an error.
  /// - Calls [_completePausePreCaching] to potentially handle pausing the download.
  ///
  /// Returns: A `Future<void>` that completes when the pre-caching operation is complete.
  Future<void> preCache() async {
    if(_initPreCachingCompleter != null){
      await _initPreCachingCompleter!.future;
    }
    if(!_isPreCaching){
      // call [_downloaderManager.startDownload(url,onProgress, cacheKey)] and get filePath
      if(_dataFile == null) {
        _isPreCaching = true;
        _initPreCachingCompleter = Completer();
        try {
          DownloadTask task = await _downloaderManager.startDownload(url, onProgress, key: cacheKey);
          // init [_dataFile]
          _dataFile == null ? _dataFile = File(task.filePath) : null;
          // check if [_dataFile] exists

          if(!_dataFile!.existsSync()) {
            throw const FileNotExistsException('File should exist and created by the downloadManager');
          }
          _mediaInitialized = true;

          // verify metadata and _canStartPlay is true if metadata exist
          await verifyMediaMetadata(task.totalSize,task.startDownload + task.endDownload);

          _completeDataSource();
          _completeInit();
          _completePrecacheInit();

          // Notify listeners if the there's already a [_onProgressCallbacks]
          for(var callback in _onProgressCallbacks){
            callback(percentage: _mediaDurationInSeconds == 0 ? 0 : _loadedMediaDurationInSeconds ~/ _mediaDurationInSeconds * 100, loadedSeconds: _loadedMediaDurationInSeconds, loadedBytes: task.startDownload + task.endDownload);
          }

          return;
        } catch(e) {
          _isPreCaching = false;
          _completePrecacheInit(withError: true);
          _completePausePreCaching();
          /// TODO send en event to the [videoStreamer] consumer
          return;
        }
      }
      resumePreCaching();
    }
  }


  /// Pauses pre-caching of media content.
  ///
  /// This method pauses pre-caching of media content associated with the
  /// provided [cacheKey]. It performs the following actions:
  ///
  /// 1. **Waits for pending pause completion (if necessary):**
  ///   - If the [_pausePreCachingCompleter] is not null, the method waits for its
  ///     future to complete. This might indicate a previous pause operation
  ///     that needs to finish before initiating a new pause.
  ///
  /// 2. **Checks pre-caching status:**
  ///   - If pre-caching is not already in progress ([_isPreCaching] is false), the
  ///     method returns immediately.
  ///
  /// 3. **Creates a new pause completer:**
  ///   - Creates a new [_pausePreCachingCompleter] instance to signal completion
  ///     of the current pause operation.
  ///
  /// 4. **Sets pre-caching flag:**
  ///   - Sets the [_isPreCaching] flag to `false` to indicate that pre-caching
  ///     is paused.
  ///
  /// 5. **Waits for initialization (if necessary):**
  ///   - If the [_initPreCachingCompleter] is not null and not yet completed, the
  ///     method awaits its future to complete. This might indicate an initialization
  ///     process that needs to finish before pausing download.
  ///
  /// 6. **Pauses download:**
  ///   - Calls [_downloaderManager.pauseDownload] to pause downloading
  ///     pre-cache data using the provided `cacheKey`.
  ///
  /// 7. **Completes pause operation:**
  ///   - Calls the [_completePausePreCaching] method to signal completion of
  ///     the pause operation (implementation details not shown).
  ///
  /// 8. **Handles exceptions:**
  ///   - In case of an exception during pausing, the method sets [_isPreCaching]
  ///     back to `true` to indicate potential issues and potentially logs or
  ///     handles the error based on the specific exception type.
  ///
  /// Returns: A `Future<void>` that completes when the pause pre-caching operation is complete.
  Future<void> pausePreCaching() async {
    if(_pausePreCachingCompleter != null){
      await _pausePreCachingCompleter!.future;
    }
    if(!_isPreCaching) return;
    try {
      _pausePreCachingCompleter = Completer();
      _isPreCaching = false;
      if(_initPreCachingCompleter != null && !_initPreCachingCompleter!.isCompleted){
        await _initPreCachingCompleter!.future;
      }
      await _downloaderManager.pauseDownload(cacheKey);
      _completePausePreCaching();
    }catch(e){
      _isPreCaching = true;
    }
  }


  /// Resumes pre-caching of media content.
  ///
  /// This method resumes pre-caching of media content associated with the
  /// provided [cacheKey]. It performs the following actions:
  ///
  /// 1. Checks if pre-caching is already in progress, and returns immediately
  ///    if it is.
  /// 2. Sets the [_isPreCaching] flag to `true` to indicate pre-caching is ongoing.
  /// 3. If the [_initPreCachingCompleter] is not null and not completed,
  ///    waits for its future to complete. This might indicate an initialization
  ///    process that needs to finish before resuming pre-caching.
  /// 4. If the [_pausePreCachingCompleter] is not null and not completed,
  ///    waits for its future to complete. This might indicate a previously
  ///    paused pre-caching operation that needs to be resumed.
  /// 5. Calls [_downloaderManager.resumeDownload] to resume downloading
  ///    pre-cache data using the provided `cacheKey`.
  /// 6. In case of an exception during pre-caching, sets [_isPreCaching] to
  ///    `false` to indicate failure.
  ///
  /// Returns: A `Future<void>` that completes when the resume pre-caching operation
  /// is complete.
  Future<void> resumePreCaching() async {
    if(isPreCaching) return;
    try {
      _isPreCaching = true;
      if(_initPreCachingCompleter != null && !_initPreCachingCompleter!.isCompleted){
        await _initPreCachingCompleter!.future;
      }
      if(_pausePreCachingCompleter != null && !_pausePreCachingCompleter!.isCompleted){
        await _pausePreCachingCompleter!.future;
      }
      await _downloaderManager.resumeDownload(cacheKey);
    }catch(e){
      _isPreCaching = false;
    }
  }


  /// Pre-caches data for a specified duration in seconds.
  /// This method asynchronously pre-caches data and adds a callback to [_onProgressCallbacks].
  /// The callback checks if the required number of seconds is obtained to stop pre-caching
  /// by calling [pausePreCachingVideo].
  ///
  /// Parameters:
  ///   - [seconds] : The duration in seconds for pre-caching to continue.
  ///
  /// Returns: A [Future] with no value.
  Future<void> preCacheNSeconds(int seconds) async {
    await preCache();
    // add a callback to [_onProgressCallbacks] to check if the number of seconds are obtained to stop the pre-caching by calling [pausePreCachingVideo]
    int index = _onProgressCallbacks.length;
    _onProgressCallbacks.add(({required int percentage, required int loadedSeconds, required int loadedBytes}) {
      if(loadedSeconds >= seconds ){
        pausePreCaching();
        _onProgressCallbacks.removeAt(index);
      }
    });
  }

  /// Plays media content.
  ///
  /// This method plays media content, but only if certain conditions are met:
  ///
  /// 1. Both media and data source must be initialized.
  /// 2. Playback is not currently waiting for data.
  /// 3. Media duration is greater than zero.
  /// 4. Either:
  ///    - Enough data is loaded (greater than [kMinSecondsToStartPlay] + [kMediaThreshHoldInSeconds]).
  ///    - All media is loaded ([_loadedMediaDurationInSeconds] equals [_mediaDurationInSeconds]).
  ///
  /// If these conditions are met, the method:
  /// 1. Sets a timer to check for sufficient data in the future.
  /// 2. If pre-caching is not already in progress, it calls `preCache()` to pre-load data.
  /// 3. Starts playback using [playable.play].
  ///
  /// Otherwise, the method:
  /// 1. Sets [_waitingForData] to `true` to indicate waiting for data.
  /// 2. Calls [preCache] to start pre-loading data.
  ///
  /// Returns: A `Future<void>` that completes when the play operation is complete.
  Future<void> play() async {
    assert(_dataSourceInitialized && isInitialized, 'Media and data source must be initialized before playing');
    if(_canStartPlaying && !_waitingForData && _mediaDurationInSeconds > 0 && (_loadedMediaDurationInSeconds > kMinSecondsToStartPlay || _loadedMediaDurationInSeconds == _mediaDurationInSeconds)) {
      _setFutureCheckForEnoughDataTimer();
      if(!_isPreCaching){
        preCache();
      }
      playable.play();
    } else {
      //set _waitingForData to true
      _waitingForData = true;
      preCache();
    }
  }

  /// Pauses playback.
  ///
  /// This method pauses playback by setting [_waitingForData] to `false`,
  /// canceling the `playingCheckTimer` if it exists, and then calling
  /// [playable.pause()] to pause the underlying media player.
  ///
  /// Returns: A `Future<void>` that completes when the pause operation is complete.
  Future<void> pause() async {
    /// set _needToPlay to false
    _waitingForData = false;
    if(playingCheckTimer != null){
      playingCheckTimer!.cancel();
    }
    await playable.pause();
  }

  /// Sets up a timer to periodically check for enough data during media playback.
  /// The timer is started when playback begins and is paused if the current position
  /// exceeds [_loadedMediaDurationInSeconds] - [mediaThreshHoldInSeconds].
  ///
  /// This method uses a [Timer.periodic] to check the conditions periodically and
  /// pauses the media playback if necessary. Additionally, it sets the [_waitingForData]
  /// flag to true when pausing due to insufficient data.
  ///
  /// Note: This method is intended for internal use and assumes the existence of
  /// [playable], [_loadedMediaDurationInSeconds], [kMediaThreshHoldInSeconds], and [_waitingForData].
  ///
  /// Throws: Throws an exception if there is an issue retrieving the current playable position.
  void _setFutureCheckForEnoughDataTimer() async {
      /// set timer when start playing and pause it if current seconds > [_loadedMediaDurationInSeconds] - [mediaThreshHoldInSeconds]
      playingCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        playingCheckTimer = timer;
        int currentPlayablePosition = await playable.getCurrentPosition();
        if(mediaDurationInSeconds > _loadedMediaDurationInSeconds && mediaDurationInSeconds > currentPlayablePosition + kMediaThreshHoldInSeconds && _loadedMediaDurationInSeconds < currentPlayablePosition + kMediaThreshHoldInSeconds && playable.isPlaying) {
          playable.pause();
          _waitingForData = true;
          timer.cancel();
          return;
        }
        if(mediaDurationInSeconds > 0 && _loadedMediaDurationInSeconds >= mediaDurationInSeconds) {
          timer.cancel();
          return;
        }
        if(!playable.isPlaying){
          timer.cancel();
        }
      });

  }


  /// Completes the data source setup process.
  ///
  /// This private function signals the completion of the data source setup process,
  /// assuming it has been successful.
  ///
  /// Note: This function assumes [_setDataSourceCompleter] is not null.
  void _completeDataSource() {
    if(_setDataSourceCompleter != null){
      _setDataSourceCompleter!.complete();
      _setDataSourceCompleter = null;
    }
  }

  /// Completes the initialization process.
  ///
  /// This private function signals the completion of the initialization process,
  /// assuming it has been successful.
  ///
  /// Note: This function assumes [_initCompleter] is not null.
  void _completeInit(){
    if(_initCompleter != null){
      _initCompleter!.complete();
      _initCompleter = null;
    }
  }

  /// Completes the precaching initialization process.
  ///
  /// This private function signals the completion of the precaching initialization,
  /// either successfully or with an error.
  ///
  /// Parameters:
  ///  * [withError] (optional): A boolean flag indicating whether to complete with an error.
  ///    Defaults to `false`.
  ///
  /// Note: This function assumes [_initPreCachingCompleter] is not null.
  void _completePrecacheInit({bool withError = false}) {
    if(_initPreCachingCompleter != null) {
      withError ?  _initPreCachingCompleter!.completeError("Error init") : _initPreCachingCompleter!.complete();
      _initPreCachingCompleter = null;
    }
  }


  /// Completes the pause pre-caching operation.
  ///
  /// This method signals completion of the pause pre-caching operation by
  /// completing the [_pausePreCachingCompleter] (if it exists and hasn't already
  /// been completed). It performs the following actions:
  ///
  /// 1. **Checks completion state:**
  ///   - Verifies if the [_pausePreCachingCompleter] is not null and not yet
  ///     completed. If it's already completed, no further action is needed.
  ///
  /// 2. **Completes the completer:**
  ///   - Completes the [_pausePreCachingCompleter], indicating that the pause
  ///     operation has finished successfully.
  ///
  /// 3. **Resets the completer:**
  ///   - Sets [_pausePreCachingCompleter] to null to prepare for potential
  ///     future pause operations.
  void _completePausePreCaching(){
    if(_pausePreCachingCompleter != null && !_pausePreCachingCompleter!.isCompleted){
      _pausePreCachingCompleter!.complete();
      _pausePreCachingCompleter = null;
    }
  }


  /// Registers a callback to be invoked during the progress of media playback.
  ///
  /// Parameters:
  ///   - [callback] : A callback function that takes percentage, loaded seconds, and loaded bytes.
  ///
  /// This method adds the provided [callback] to the list of progress callbacks.
  void registerOnProgressCallback(void Function({required int percentage,required int loadedSeconds,required int loadedBytes}) callback) {
    _onProgressCallbacks.add(callback);
  }

  /// Removes a previously registered callback from the list of progress callbacks.
  ///
  /// Parameters:
  ///   - [callback] : The callback function to be removed.
  ///
  /// This method removes the specified [callback] from the list of progress callbacks.
  void removeCallback(void Function({required int percentage,required int loadedSeconds,required int loadedBytes}) callback){
    _onProgressCallbacks.remove(callback);
  }

  /// Callback method invoked during the progress of file download.
  ///
  /// Parameters:
  ///   - [progress] : The progress value indicating the advancement of file download %.
  ///
  /// Note: This method updates various internal variables, checks for metadata,
  /// and invokes registered progress callbacks.
  void onProgress(int progress,int total) async {

    if(progress == 0) return;

    if(_isPreCaching && _mediaDurationInSeconds > 0 && _mediaDurationInSeconds == _loadedMediaDurationInSeconds){
      _isPreCaching = false;
    }

    // If playback hasn't started yet, search for metadata in the file.
    if (!_canStartPlaying) {
      // Retrieve metadata from the file.
      await verifyMediaMetadata(total,progress * (total ~/ 100));

      _completeDataSource();

      // Check if _initCompleter is not null, complete it with null.
      _completeInit();
    }

    // Update [_loadedMediaDurationInSeconds] based on the progress.
    _loadedMediaDurationInSeconds = progress  * _mediaDurationInSeconds ~/ 100;

    // Get the current playable position.
    int currentPlayablePosition = await playable.getCurrentPosition();



    // Check if waiting for data and if it's time to resume playback.
    if (_waitingForData) {
      if (_loadedMediaDurationInSeconds > currentPlayablePosition + kMediaThreshHoldInToRestartPlay || _loadedMediaDurationInSeconds == _mediaDurationInSeconds) {
        _waitingForData = false;
        play();
      }
    }

    // Invoke registered progress callbacks.
    for (var callback in _onProgressCallbacks) {
      callback(percentage: progress, loadedSeconds: _loadedMediaDurationInSeconds, loadedBytes: _totalFileSizeInBytes ~/ 100 * progress);
    }
  }



  /// Verifies media metadata and updates playback state.
  ///
  /// This function retrieves media metadata using `MediaMetadataUtils.retrieveMetadataFromFile`,
  /// checks if the metadata is unavailable, and updates the internal playback state variables
  /// accordingly.
  ///
  /// Parameters:
  ///   * [totalFileSizeInBytes] : The total file size in bytes.
  ///   * [downloadedBytes] : The number of bytes downloaded so far.
  Future<void> verifyMediaMetadata(int total, int downloaded) async {
    MediaMetadata? metadata = await MediaMetadataUtils.retrieveMetadataFromFile(_dataFile!);

    // If metadata is unavailable, return early.
    if (metadata == null || metadata.duration == 0) {
      return;
    }


    // Set _canStartPlaying to true and update _mediaDurationInSeconds from metadata.
    _canStartPlaying = true;
    _mediaDurationInSeconds = metadata.duration;
    _totalFileSizeInBytes = total;
    _loadedMediaDurationInSeconds =  (downloaded / _totalFileSizeInBytes * _mediaDurationInSeconds).toInt();
    var currentPlayingPosition = await playable.getCurrentPosition();
    if(_loadedMediaDurationInSeconds > currentPlayingPosition + kMediaThreshHoldInSeconds || _loadedMediaDurationInSeconds == _mediaDurationInSeconds) {
      _waitingForData = false;
    }
  }


  @override
  String toString() {
    return 'VideoStream(playable: ${playable.runtimeType}, cacheKey: $cacheKey, url: $url, filePath: ${_dataFile?.path ?? 'Not defined yet'}, mediaDurationInSeconds: $_mediaDurationInSeconds, fileTotalLength: $_totalFileSizeInBytes, loadedMediaDurationInSeconds: $_loadedMediaDurationInSeconds, waitingForData: $_waitingForData, canStartPlaying: $_canStartPlaying)';
  }



}