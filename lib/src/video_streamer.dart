import 'dart:async';
import 'dart:io';
import 'package:flutter_video_cache/src/downloader_manager.dart';
import 'package:flutter_video_cache/src/models/playable_interface.dart';

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

  /// True if the video/audio can start playing
  ///
  /// true if we can read metadata of [_dataFile]
  bool _canStartPlaying = false;

  /// True if [play] is called and it's paused due to not enough data
  bool _waitingForData = false;

  /// The total length of [_dataFile]
  int _fileTotalLength = 0;

  /// A list of callback that should be called by [onProgress]
  final List<Function({int percentage, int seconds, int bytes})> _onProgressCallbacks = [];

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



  /// TODO a getter to Returns true if the playable is initialized & _mediaInitialized & _canStartPlaying


  Future<void> initialize() async {
    /// TODO set the process of init:
        /// TODO init playable
        /// TODO #0 start precaching the video until the min duration is obtained by the [onProgress] process and give value to completer and return the complete.future
  }

  /// Start pre-caching the video/audio
  void startPreCachingVideo(){
    /// TODO #2 call [_downloaderManager.startDownload(url,onProgress, cacheKey)] and get filePath
    /// TODO init [_dataFile]
    /// TODO check #3 if [_dataFile] exists
    if(false) /// TODO #3 false
    {
      /// TODO create file
      /// TODO see with sabri !!!!

    }
    /// TODO set [_mediaInitialized] to true
  }

  /// Pause pre-caching the video/audio
  void pausePreCachingVideo(){
    /// TODO call [_downloaderManager.pauseDownload(cacheKey)]
  }

  /// Resume pre-caching the video/audio
  void resumePreCachingVideo(){
    /// TODO call [_downloaderManager.resumeDownload(cacheKey)]
  }

  void preCacheNSeconds(int seconds){
    /// TODO call [_downloaderManager.startDownload]
    /// TODO add a callback to [_onProgressCallbacks] to check if the number of seconds are obtained to stop the pre-caching by calling [pausePreCachingVideo]
  }

  /// Plays the video
  void play() {
    if(_canStartPlaying) {
      _waitingForData = true;
      /// /* TODO #1 set timer when start playing and pause it if current seconds > [_loadedMediaDurationInSeconds] - [mediaThreshHoldInSeconds]*/
      /// TODO get current player seconds
      /// TODO call if there no enough data [startPreCachingVideo()]

      playable?.play();
    } else {
      /// TODO set _needToPlay to true
      // TODO call [startPreCachingVideo()]
    }
  }

  void pause() {
    /// TODO set _needToPlay to false
    playable?.pause();
  }



  /// TODO A callback to listen to file download progress executed by [_downloaderManager]
  void onProgress(int progress) {
    if(_fileTotalLength == 0){
      /// TODO set _fileTotalLength
    }
    if(!_canStartPlaying) {
      /// TODO #3 search metadata in file
      /// TODO by sabri return; !true #3
      if(true) /// TODO #3 is true
      {
        /// TODO make _canStartPlaying true
        /// TODO set _mediaDurationInSeconds from metadata
        /// TODO check if (initCompleter is not null) execute complete and give it null(see #0).
      } else {
        return;
      }

    }
    /// TODO update
    /// TODO update [_loadedMediaDurationInSeconds] = [_totalFileLength] / [mediaDurationInSeconds] * progress
    /// TODO update other variables
    /// TODO #2 check if current_seconds < [_loadedMediaDurationInSeconds] - [mediaThreshHoldInSeconds]
    /// TODO if #2 is true && [_needToPlay] then call [play()]b
  }





}