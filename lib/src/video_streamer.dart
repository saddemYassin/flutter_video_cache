import 'dart:async';
import 'dart:io';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:flutter_video_cache/src/consts.dart';
import 'package:flutter_video_cache/src/downloader_manager.dart';
import 'package:flutter_video_cache/src/media_metadata_utils.dart';
import 'package:flutter_video_cache/src/models/exceptions/file_not_exist_exception.dart';
import 'package:flutter_video_cache/src/models/media_metadata.dart';
import 'package:flutter_video_cache/src/models/playable_interface.dart';
import 'package:flutter_video_cache/src/utils.dart';

class VideoStream<T extends PlayableInterface> {

  /// A playable object that can be played/paused depends on data status on [dataFile]
  final T? playable;

  /// The data file where the video/audio is stored
  File? _dataFile;

  /// The file downloader manager
  final DownloadManager _downloaderManager = DownloadManager.instance;

  /// The total duration of the media
  int _mediaDurationInSeconds = 0;

  /// The number of seconds of the loaded media inside [_dataFile]
  int _loadedMediaDurationInSeconds = 0;

  /// True if the media is initialized
  ///
  /// [_dataFile] is created
  bool _mediaInitialized = false;

  /// A timer to check if the media can start playing
  Timer? playingCheckTimer;

  /// True if the video/audio can start playing
  ///
  /// true if we can read metadata of [_dataFile]
  bool _canStartPlaying = false;

  /// True if [play] is called and it's paused due to not enough data
  bool _waitingForData = false;

  /// The total length of [_dataFile]
  double _fileTotalLength = 0;

  /// A list of callback that should be called by [onProgress]
  final List<void Function({required int percentage,required int loadedSeconds,required int loadedBytes})> _onProgressCallbacks = [];

  Completer<void>? _initCompleter;

  /// The [_downloaderManager] task key
  late final String cacheKey;

  /// The media remote url
  final String url;

  VideoStream({required this.url,this.playable, String? cacheKey}){
    if(cacheKey == null){
      this.cacheKey = url;
    }
  }



  /// Returns true if the playable is initialized & _mediaInitialized & _canStartPlaying
  bool get isInitialized => (playable?.isInitialized ?? false) && _mediaInitialized && _canStartPlaying;

  /// Prepares the video/audio to be played and start/resume precaching video
  Future<void> initialize() async {
    assert(playable != null, "playable can't be null");
    playable!.initialize();
    _initCompleter = Completer();
    preCache();
    return _initCompleter!.future;
  }

  /// Start pre-caching the video/audio
  Future<void> preCache() async {
    // call [_downloaderManager.startDownload(url,onProgress, cacheKey)] and get filePath
    String filePath = await _downloaderManager.startDownload(url, onProgress, key: cacheKey);
    // init [_dataFile]
    if(_dataFile != null) {
      _dataFile = File(filePath);
    }
    // check if [_dataFile] exists

    if(!_dataFile!.existsSync()) {
      throw const FileNotExistsException('File should exist and created by the downloadManager');
    }
    _mediaInitialized = true;
  }

  /// Pause pre-caching the video/audio
  void pausePreCaching(){
    _downloaderManager.pauseDownload(cacheKey);
  }

  /// Resume pre-caching the video/audio
  void resumePreCaching(){
    _downloaderManager.resumeDownload(cacheKey);
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

  /// Plays the video
  Future<void> play() async {
    if(_canStartPlaying && !_waitingForData && playable != null) {
      _setFutureCheckForEnoughDataTimer();
      preCache();
      playable?.play();
    } else {
      //set _needToPlay to true
      _waitingForData = true;
      preCache();
    }
  }

  void pause() {
    /// set _needToPlay to false
    _waitingForData = false;
    playingCheckTimer?.cancel();
    playable?.pause();
  }

  /// Sets up a timer to periodically check for enough data during media playback.
  /// The timer is started when playback begins and is paused if the current position
  /// exceeds [_loadedMediaDurationInSeconds - mediaThreshHoldInSeconds].
  ///
  /// This method uses a [Timer.periodic] to check the conditions periodically and
  /// pauses the media playback if necessary. Additionally, it sets the [_waitingForData]
  /// flag to true when pausing due to insufficient data.
  ///
  /// Note: This method is intended for internal use and assumes the existence of
  /// [playable], [_loadedMediaDurationInSeconds], [mediaThreshHoldInSeconds], and [_waitingForData].
  ///
  /// Throws: Throws an exception if there is an issue retrieving the current playable position.
  void _setFutureCheckForEnoughDataTimer() async {
    if(playable != null){
      int currentPlayablePosition = await playable!.getCurrentPosition();

      /// set timer when start playing and pause it if current seconds > [_loadedMediaDurationInSeconds] - [mediaThreshHoldInSeconds]
      playingCheckTimer = Timer.periodic(Duration(seconds: _loadedMediaDurationInSeconds - currentPlayablePosition - mediaThreshHoldInSeconds), (timer) async {
        int currentPlayablePosition = await playable!.getCurrentPosition();
        if(_loadedMediaDurationInSeconds < currentPlayablePosition + mediaThreshHoldInSeconds && (playable?.isPlaying ?? false)) {
          playable?.pause();
          _waitingForData = true;
          timer.cancel();
          return;
        }
        timer.cancel();
        _setFutureCheckForEnoughDataTimer();
      });
    }
  }


  /// Callback method invoked during the progress of file download.
  ///
  /// Parameters:
  ///   - [progress] : The progress value indicating the advancement of file download %.
  ///
  /// Note: This method updates various internal variables, checks for metadata,
  /// and invokes registered progress callbacks.
  void onProgress(int progress) async {
    // Set _fileTotalLength value if not already set.
    if (_fileTotalLength == 0) {
      _fileTotalLength = Utils.calculateFileSizeFromProgressAndDownloadedBytes(
        progress: progress,
        downloadedBytes: _dataFile!.lengthSync(),
      );
    }

    // If playback hasn't started yet, search for metadata in the file.
    if (!_canStartPlaying) {
      // Retrieve metadata from the file.
      MediaMetadata? metadata = await MediaMetadataUtils.retrieveMetadataFromFile(_dataFile!);

      // If metadata is unavailable, return early.
      if (metadata == null) {
        return;
      }

      // Set _canStartPlaying to true and update _mediaDurationInSeconds from metadata.
      _canStartPlaying = true;
      _mediaDurationInSeconds = metadata.duration;

      // Check if _initCompleter is not null, complete it with null.
      if (_initCompleter != null) {
        _initCompleter!.complete();
      }
    }

    // Update [_loadedMediaDurationInSeconds] based on the progress.
    _loadedMediaDurationInSeconds = ((_fileTotalLength / _mediaDurationInSeconds!) * progress).toInt();

    // Get the current playable position.
    int currentPlayablePosition = await playable?.getCurrentPosition() ?? 0;

    // Check if waiting for data and if it's time to resume playback.
    if (_waitingForData) {
      if (_loadedMediaDurationInSeconds > currentPlayablePosition + mediaThreshHoldInSeconds) {
        _waitingForData = false;
        play();
      }
    }

    // Invoke registered progress callbacks.
    for (var callback in _onProgressCallbacks) {
      callback(percentage: progress, loadedSeconds: _loadedMediaDurationInSeconds, loadedBytes: _fileTotalLength.toInt());
    }
  }





}