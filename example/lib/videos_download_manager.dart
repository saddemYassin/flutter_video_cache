import 'dart:developer';

import 'package:flutter_video_cache/flutter_video_cache.dart';

/// Enum representing different priority levels for tasks.
enum Priority {
  /// Low priority.
  low,

  /// Medium priority.
  medium,

  /// High priority.
  high,

  /// Very high priority.
  veryHigh,
}

/// Manages the download and caching of video streams.
class VideosDownloadManager {
  VideosDownloadManager._();
  static final VideosDownloadManager _instance = VideosDownloadManager._();
  factory VideosDownloadManager() => _instance;


  /// Map to store video streams that are being precached.
  static final Map<String, VideoStream> _preCachingVideoStreams = <String, VideoStream>{};

  /// Map to store the priority of video streams.
  static final Map<String, Priority> _videoStreamPriority = <String, Priority>{};

  /// Map to store video streams that have been precached.
  static final Map<String, VideoStream> _precachedVideoStreams = <String, VideoStream>{};

  /// Key representing the highest priority video stream.
  static String? _veryHighPriorityVideoKey;

  /// Set of keys representing video streams with high priority.
  static final Set<String> _highPriorityVideoKey = {};

  /// Set of keys representing video streams with medium priority.
  static final Set<String> _mediumPriorityVideoKey = {};

  /// Set of keys representing video streams with low priority.
  static final Set<String> _lowPriorityVideoKey = {};

  /// Default duration in seconds for precaching a video stream.
  static const _kDefaultPrecachingSeconds = kMinSecondsToStartPlay + 2;



  /// Caches a video stream with the specified priority.
  ///
  /// The method caches the video stream based on its priority level. It checks if the video stream
  /// is already precached or if it has already reached its media duration to be considered precached.
  /// If not, it updates the priority of the video stream and adds it to the appropriate priority set.
  ///
  /// Parameters:
  ///   - [stream] : The video stream to be cached.
  ///   - [priority] : The priority level of caching for the video stream.
  static void cacheVideo(VideoStream stream, Priority priority) {
    // If the video stream is already precached, return.
    if(_precachedVideoStreams.containsKey(stream.cacheKey)){
      return;
    }

    // If the video stream has reached its media duration and matches the loaded media duration,
    // consider it precached and add it to the precached video streams.
    if(stream.mediaDurationInSeconds > 0 && stream.mediaDurationInSeconds == stream.loadedMediaDurationInSeconds){
      _precachedVideoStreams[stream.cacheKey] = stream;
      _preCachingVideoStreams.removeWhere((key, value) => key == stream.cacheKey);
      return;
    }

    // If the video stream already has a priority assigned and matches the new priority,
    // return without updating its priority.
    if(_videoStreamPriority.containsKey(stream.cacheKey)){
      if(_videoStreamPriority[stream.cacheKey] == priority){
        return;
      }
    }

    // Update the priority of the video stream based on the specified priority level.
    switch(priority){
      case Priority.low:
        _lowPriorityVideoKey.add(stream.cacheKey);
        _mediumPriorityVideoKey.remove(stream.cacheKey);
        _highPriorityVideoKey.remove(stream.cacheKey);
        if(_veryHighPriorityVideoKey == stream.cacheKey){
          _veryHighPriorityVideoKey = null;
        }
        break;
      case Priority.medium:
        _mediumPriorityVideoKey.add(stream.cacheKey);
        if(_mediumPriorityVideoKey.length > 6){
          _decreasePriority(_mediumPriorityVideoKey.last);
        }
        _lowPriorityVideoKey.remove(stream.cacheKey);
        _highPriorityVideoKey.remove(stream.cacheKey);
        if(_veryHighPriorityVideoKey == stream.cacheKey){
          _veryHighPriorityVideoKey = null;
        }
        break;
      case Priority.high:
        _highPriorityVideoKey.add(stream.cacheKey);
        if(_highPriorityVideoKey.length > 3){
          _decreasePriority(_highPriorityVideoKey.first);
        }
        _lowPriorityVideoKey.remove(stream.cacheKey);
        _mediumPriorityVideoKey.remove(stream.cacheKey);
        if(_veryHighPriorityVideoKey == stream.cacheKey){
          _veryHighPriorityVideoKey = null;
        }
        break;
      case Priority.veryHigh:
        if(_veryHighPriorityVideoKey != null){
          _decreasePriority(_veryHighPriorityVideoKey!);
        }
        _veryHighPriorityVideoKey = stream.cacheKey;
        _lowPriorityVideoKey.remove(stream.cacheKey);
        _mediumPriorityVideoKey.remove(stream.cacheKey);
        _highPriorityVideoKey.remove(stream.cacheKey);
        break;
    }

    // Assign the new priority to the video stream and add it to the pre-caching video streams.
    _videoStreamPriority[stream.cacheKey] = priority;
    _preCachingVideoStreams[stream.cacheKey] = stream;

    // Register a progress callback for the video stream.
    _preCachingVideoStreams[stream.cacheKey]!.registerOnProgressCallback(({required int loadedBytes,required int loadedSeconds,required int percentage}) {
      onProgress(loadedSeconds: loadedSeconds, key: stream.cacheKey);
    });

    // Initiate the caching process.
    cacheWorker();
  }



  /// Decreases the priority of the specified video stream.
  ///
  /// This method is called when the priority of a video stream needs to be decreased.
  /// It checks the current priority level of the video stream and adjusts it accordingly.
  /// If the priority is already at the lowest level, the method does nothing.
  ///
  /// Parameters:
  ///   - [key] : The key of the video stream whose priority needs to be decreased.
  static void _decreasePriority(String key){
    Priority priority = _videoStreamPriority[key] ?? Priority.low;
    switch(priority){
      case Priority.low:
        break;
      case Priority.medium:
        _mediumPriorityVideoKey.remove(key);
        _videoStreamPriority[key] = Priority.low;
        _lowPriorityVideoKey.add(key);
        break;
      case Priority.high:
        _highPriorityVideoKey.remove(key);
        _videoStreamPriority[key] = Priority.medium;
        _mediumPriorityVideoKey.add(key);
        if(_mediumPriorityVideoKey.length > 6){
          _decreasePriority(_mediumPriorityVideoKey.last);
        }
        break;
      case Priority.veryHigh:
        if(key == _veryHighPriorityVideoKey){
          _veryHighPriorityVideoKey = null;
        }
        _videoStreamPriority[key] = Priority.high;
        _highPriorityVideoKey.add(key);
        if(_highPriorityVideoKey.length > 3){
          _decreasePriority(_highPriorityVideoKey.last);
        }
        break;
    }
  }

  /// Removes the specified video stream from caching.
  ///
  /// This method removes the specified video stream from the pre-caching list and priority tracking.
  /// If [totally] is set to true, it removes the stream completely from pre-caching and priority tracking.
  /// Otherwise, it only removes the stream from priority tracking, allowing it to remain in the pre-caching list.
  ///
  /// Parameters:
  ///   - [stream] : The video stream to be removed from caching.
  ///   - [totally] : Indicates whether to remove the stream completely from caching (default is false).
  static void removeFromCaching(VideoStream stream,{bool totally = false}){
    if(totally){
      _preCachingVideoStreams.remove(stream.cacheKey);
       _videoStreamPriority.remove(stream.cacheKey);
    }
    if(_veryHighPriorityVideoKey == stream.cacheKey){
      _veryHighPriorityVideoKey = null;
    }
    _lowPriorityVideoKey.remove(stream.cacheKey);
    _mediumPriorityVideoKey.remove(stream.cacheKey);
    _highPriorityVideoKey.remove(stream.cacheKey);
  }

  /// Handles the progress of caching for a video stream.
  ///
  /// This method is called to handle the progress of caching for a specified video stream.
  /// It checks the caching progress and conditions based on priority levels to determine
  /// whether the stream caching should be completed.
  ///
  /// Parameters:
  ///   - [loadedSeconds] : The number of seconds loaded for the video stream.
  ///   - [key] : The cache key of the video stream being cached.
  static void onProgress({required int loadedSeconds, required String key}) {
    if(_precachedVideoStreams.containsKey(key)){
      return;
    }
    if( _preCachingVideoStreams[key]!.mediaDurationInSeconds > 0 && _preCachingVideoStreams[key]!.mediaDurationInSeconds == _preCachingVideoStreams[key]!.loadedMediaDurationInSeconds){
      _precachedVideoStreams[key] = _preCachingVideoStreams[key]!;
      removeFromCaching(_preCachingVideoStreams[key]!,totally: true);
      cacheWorker();
      return;
    }

    if(_videoStreamPriority[key] == Priority.high){
      if(_preCachingVideoStreams[key]!.mediaDurationInSeconds > 0 && (_preCachingVideoStreams[key]!.loadedMediaDurationInSeconds == _preCachingVideoStreams[key]!.mediaDurationInSeconds || _preCachingVideoStreams[key]!.loadedMediaDurationInSeconds >= _kDefaultPrecachingSeconds * 3)){
        _finishTask(key);
      }
    }
    if(_videoStreamPriority.containsKey(key) && _videoStreamPriority[key] == Priority.medium){
      if(_preCachingVideoStreams[key]!.mediaDurationInSeconds > 0 && _preCachingVideoStreams[key]!.loadedMediaDurationInSeconds >= _kDefaultPrecachingSeconds * 2){
        _finishTask(key);
      }
    }
    if(_videoStreamPriority[key] == Priority.low){
      if(_preCachingVideoStreams[key]!.mediaDurationInSeconds > 0 && _preCachingVideoStreams[key]!.loadedMediaDurationInSeconds >= _kDefaultPrecachingSeconds){
        _finishTask(key);
      }
    }
  }

  /// Manages the caching process for video streams based on their priority levels.
  ///
  /// This method determines which video streams should be precached or paused based on their priority levels.
  /// It prioritizes precaching streams with higher priority levels and pauses streams with lower priority levels.
  static void cacheWorker() {
    // Precache very high priority streams and pause others
    if (_veryHighPriorityVideoKey != null) {
      _startPreCacheByKey(_veryHighPriorityVideoKey!);
      for (var high in _highPriorityVideoKey) {
        _pausePreCacheByKey(high);
      }
      for (var normal in _mediumPriorityVideoKey) {
        _pausePreCacheByKey(normal);
      }
      for (var low in _lowPriorityVideoKey) {
        _pausePreCacheByKey(low);
      }
      return;
    }

    // Precache high priority streams and pause others
    if (_highPriorityVideoKey.isNotEmpty) {
      for (int i = 0; i < _highPriorityVideoKey.length; i++) {
        if (i == 0) {
          _startPreCacheByKey(_highPriorityVideoKey.first);
          continue;
        }
        _pausePreCacheByKey(_highPriorityVideoKey.elementAt(i));
      }
      for (var normal in _mediumPriorityVideoKey) {
        _pausePreCacheByKey(normal);
      }
      for (var low in _lowPriorityVideoKey) {
        _pausePreCacheByKey(low);
      }
      return;
    }

    // Precache medium priority streams and pause others
    if (_mediumPriorityVideoKey.isNotEmpty) {
      for (var medium in _mediumPriorityVideoKey) {
        _startPreCacheByKey(medium);
      }
      for (var low in _lowPriorityVideoKey) {
        _pausePreCacheByKey(low);
      }
      return;
    }

    // Precache low priority streams
    for (var low in _lowPriorityVideoKey) {
      _startPreCacheByKey(low);
    }
  }


  /// Starts precaching for a video stream identified by the given [key].
  ///
  /// This method checks if the video stream exists in the preCachingVideoStreams map and if it's not already in the precaching state.
  /// If both conditions are met, it initiates the precaching process for the video stream.
  ///
  /// Parameters:
  ///   - key: The unique identifier for the video stream to start precaching.
  static void _startPreCacheByKey(String key) {
    if (_preCachingVideoStreams.containsKey(key) && !_preCachingVideoStreams[key]!.isPreCaching) {
      _preCachingVideoStreams[key]!.preCache();
    }
  }


  /// Pauses precaching for the video stream identified by the specified [key].
  ///
  /// This method checks if the video stream associated with the given key exists in the `_preCachingVideoStreams` map
  /// and if it is currently in the precaching state. If both conditions are met, the precaching process for the
  /// video stream is paused.
  ///
  /// Parameters:
  ///   - [key] : The unique identifier for the video stream whose precaching should be paused.
  static void _pausePreCacheByKey(String key){
    if(_preCachingVideoStreams.containsKey(key) && _preCachingVideoStreams[key]!.isPreCaching){
      _preCachingVideoStreams[key]!.pausePreCaching();
    }
  }

  /// Finishes the precaching task for the video stream identified by the specified [key].
  ///
  /// This method completes the precaching task for the video stream associated with the given key. It first
  /// pauses the precaching process for the video stream using the `_pausePreCacheByKey` method, then removes
  /// the video stream from the precaching map and updates the caching status using the `removeFromCaching` method.
  /// Finally, it triggers the `cacheWorker
  static void _finishTask(String key){
    _pausePreCacheByKey(key);
    removeFromCaching(_preCachingVideoStreams[key]!);
    cacheWorker();
  }
}