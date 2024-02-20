import 'dart:developer';

import 'package:flutter_video_cache/flutter_video_cache.dart';

enum Priority { low, medium, high, veryHigh }

class VideoCacheService {
  VideoCacheService._();
  static final VideoCacheService _instance = VideoCacheService._();
  factory VideoCacheService() => _instance;


  static final Map<String, VideoStream> _preCachingVideoStreams = <String, VideoStream>{};

  static final Map<String, Priority> _videoStreamPriority = <String, Priority>{};

  static final Map<String, VideoStream> _precachedVideoStreams = <String, VideoStream>{};

  static String? _veryHighPriorityVideoKey;
  static final Set<String> _highPriorityVideoKey = {};
  static final Set<String> _mediumPriorityVideoKey = {};
  static final Set<String> _lowPriorityVideoKey = {};

  static const _kDefaultPrecachingSeconds = kMediaThreshHoldInSeconds + kMinSecondsToStartPlay + 2;
  
  
  
  static void cacheVideo(VideoStream stream, Priority priority) {
    print('> stream cache key ${stream.cacheKey} set priority ${priority.name}');
    if(_precachedVideoStreams.containsKey(stream.cacheKey)){
      return;
    }
    if(stream.mediaDurationInSeconds > 0 && stream.mediaDurationInSeconds == stream.loadedMediaDurationInSeconds){
      _precachedVideoStreams[stream.cacheKey] = stream;
      _preCachingVideoStreams.removeWhere((key, value) => key == stream.cacheKey);
      return;
    }
    if(_videoStreamPriority.containsKey(stream.cacheKey)){
      if(_videoStreamPriority[stream.cacheKey] == priority){
        return;
      }
    }

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
          _decreasePriority(_mediumPriorityVideoKey.first);
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

    _videoStreamPriority[stream.cacheKey] = priority;
    _preCachingVideoStreams[stream.cacheKey] = stream;
    _preCachingVideoStreams[stream.cacheKey]!.registerOnProgressCallback(({required int loadedBytes,required int loadedSeconds,required int percentage}) {
      onProgress(loadedSeconds: loadedSeconds, key: stream.cacheKey);
    });
    cacheWorker();
  }

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
          _decreasePriority(_mediumPriorityVideoKey.first);
        }
        break;
      case Priority.veryHigh:
        if(key == _veryHighPriorityVideoKey){
          _veryHighPriorityVideoKey = null;
        }
        _videoStreamPriority[key] = Priority.high;
        _highPriorityVideoKey.add(key);
        if(_highPriorityVideoKey.length > 3){
          _decreasePriority(_highPriorityVideoKey.first);
        }
        break;
    }
  }

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

  static void onProgress({required int loadedSeconds, required String key}) {
    // print('>> OnProgress key $key $loadedSeconds');
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
      if(_preCachingVideoStreams[key]!.mediaDurationInSeconds > 0 && _preCachingVideoStreams[key]!.loadedMediaDurationInSeconds == _preCachingVideoStreams[key]!.mediaDurationInSeconds && _preCachingVideoStreams[key]!.loadedMediaDurationInSeconds >= _kDefaultPrecachingSeconds * 3){
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

  static void cacheWorker() {
    // Precache very high priority and pause other
    print('_precachedVideoStreams ${_precachedVideoStreams.keys.length} ${_precachedVideoStreams.keys.toList()}');
    print('_preCachingVideoStreams ${_preCachingVideoStreams.keys.length}');
    print('>>> keys ${_preCachingVideoStreams.keys.toList()}');
    print('>>> Prio');
    print('>>> loaded ${_preCachingVideoStreams.values.map((e) => '[${e.cacheKey} : ${_videoStreamPriority[e.cacheKey]} : ${e.loadedMediaDurationInSeconds}] > ').toList()}');
    if(_veryHighPriorityVideoKey != null){
      _startPreCacheByKey(_veryHighPriorityVideoKey!);
      for(var high in _highPriorityVideoKey){
        _pausePreCacheByKey(high);
      }
      for(var normal in _mediumPriorityVideoKey){
        _pausePreCacheByKey(normal);
      }
      for(var low in _lowPriorityVideoKey){
        _pausePreCacheByKey(low);
      }
      return;
    }

    // Precache high priority and pause other
    if(_highPriorityVideoKey.isNotEmpty){
      for(int i = 0; i < _highPriorityVideoKey.length; i++){
        if(i == 0){
          _startPreCacheByKey(_highPriorityVideoKey.first);
          continue;
        }
        _pausePreCacheByKey(_highPriorityVideoKey.elementAt(i));
      }
      for(var normal in _mediumPriorityVideoKey){
        _pausePreCacheByKey(normal);
      }
      for(var low in _lowPriorityVideoKey){
        _pausePreCacheByKey(low);
      }
      return;
    }

    // Precache medium priority and pause other
    if(_mediumPriorityVideoKey.isNotEmpty){
      for(var medium in _mediumPriorityVideoKey){
        _startPreCacheByKey(medium);
      }
      for(var low in _lowPriorityVideoKey){
        _pausePreCacheByKey(low);
      }
      return;
    }

    // Precache low priority
    for(var low in _lowPriorityVideoKey){
      _startPreCacheByKey(low);
    }
  }

  static void _startPreCacheByKey(String key) {
    if(_preCachingVideoStreams.containsKey(key) && !_preCachingVideoStreams[key]!.isPreCaching){
      _preCachingVideoStreams[key]!.preCache();
    }
  }

  static void _pausePreCacheByKey(String key){
    if(_preCachingVideoStreams.containsKey(key) && _preCachingVideoStreams[key]!.isPreCaching){
      _preCachingVideoStreams[key]!.pausePreCaching();
    }
  }


  static void _finishTask(String key){
    _pausePreCacheByKey(key);
    removeFromCaching(_preCachingVideoStreams[key]!);
    cacheWorker();
  }
}