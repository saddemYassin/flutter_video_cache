
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_video_cache/flutter_video_cache.dart';
import 'package:flutter_video_cache_example/app_video_controller.dart';
import 'package:flutter_video_cache_example/cache_service.dart';
import 'package:flutter_video_cache_example/data.dart';
import 'package:flutter_video_cache_example/full_page_video.dart';

class VideosList extends StatefulWidget {
  const VideosList({super.key});

  @override
  State<VideosList> createState() => _VideosListState();
}

class _VideosListState extends State<VideosList> {


  late List<VideoStream<AppVideoController>> videos;

  late final List<double> _visibilities;


  String _cacheKeyExtractor(String url) {
      final String name = url.split('/').last;
      // replace special chars
      final String cleanName = name.replaceAll(RegExp(r'[^\w\s]'), '_');
      return cleanName;
  }

  @override
  void initState() {
    super.initState();
    videos = Data.videos.map((e) => VideoStream<AppVideoController>(url: e, playable: AppVideoController(),cacheKey: _cacheKeyExtractor(e))).toList();
    _visibilities = List<double>.filled(videos.length, 0,growable: true);
    for(int i = 0; i < videos.length; i++){
        videos[i].registerOnProgressCallback(({required int percentage,required int loadedSeconds,required int loadedBytes}) => onProgress(i,loadedSeconds));
    }
    for(int i = 0; i < videos.length; i++){
        if(i == 0){
          VideoCacheService.cacheVideo(videos[i], Priority.veryHigh);
          continue;
        }
        if(i < 3){
          VideoCacheService.cacheVideo(videos[i], Priority.high);
          continue;
        }
        if(i < 4){
          VideoCacheService.cacheVideo(videos[i], Priority.medium);
          continue;
        }
        VideoCacheService.cacheVideo(videos[i], Priority.low);
      }
  }

  void _onVisibilityChange(double visibility,int index){
    if(visibility > 0.8){
      if(index > 0 && _visibilities[index - 1] > 0){
        _visibilities[index - 1] = 0.0;
      }
      if(index < videos.length - 1 && _visibilities[index + 1] > 0){
        _visibilities[index + 1] = 0.0;
      }
      if(videos.length > index + 2){
        VideoCacheService.cacheVideo(videos[index + 2], Priority.high);
      }
    }
    _visibilities[index] = visibility;
    /*VideoCacheService.cacheVideo(videos[index], Priority.high);
    if(videos.length > index + 1){
      VideoCacheService.cacheVideo(videos[index + 1], Priority.high);
    }*/
  }




  void onProgress(int indexOfDownloadInProgressVideo,int loadedSeconds) async {
    // int indexOfVisibleVideo = _visibilities.indexWhere((element) => element > 0.5);
    /*if(indexOfVisibleVideo == -1){
      indexOfVisibleVideo = indexOfDownloadInProgressVideo;
    }
    if(_visibilities[indexOfVisibleVideo] > 0.5){
      if(videos[indexOfVisibleVideo].mediaDurationInSeconds > 0 && ( videos[indexOfVisibleVideo].loadedMediaDurationInSeconds == videos[indexOfVisibleVideo].mediaDurationInSeconds || (videos[indexOfVisibleVideo].loadedMediaDurationInSeconds - 10 >= (await videos[indexOfVisibleVideo].playable.getCurrentPosition())))){
        if(indexOfVisibleVideo + 1 < videos.length){
          if(videos[indexOfVisibleVideo + 1].loadedMediaDurationInSeconds < 5){
            print('>>> Video precache start in view level 1 at ${indexOfVisibleVideo + 1}');
            videos[indexOfVisibleVideo + 1].preCache();
          }
        }
      } else if(indexOfVisibleVideo != indexOfDownloadInProgressVideo) {
        print('>>> Video pause in view level 1 at $indexOfDownloadInProgressVideo');
        videos[indexOfDownloadInProgressVideo].pausePreCaching();
        return;
      }
    }*/
    /*if(_visibilities[indexOfDownloadInProgressVideo] < 0.5){
      if(videos[indexOfDownloadInProgressVideo].mediaDurationInSeconds > 0 && videos[indexOfDownloadInProgressVideo].loadedMediaDurationInSeconds - 8 >= (await videos[indexOfDownloadInProgressVideo].playable.getCurrentPosition())){
        print('>>> Video pause in view level 2 at $indexOfDownloadInProgressVideo');
        videos[indexOfDownloadInProgressVideo].pausePreCaching();
        if(indexOfDownloadInProgressVideo + 1 < videos.length){
          print('>>> Video precache start in view level 2 at ${indexOfVisibleVideo + 1}');
          videos[indexOfDownloadInProgressVideo + 1].preCache();
        }
      }
    }*/
  }


  @override
  Widget build(BuildContext context) {
    return PageView.builder(
        itemCount: videos.length,
        onPageChanged: (index){
          VideoCacheService.cacheVideo(videos[index], Priority.veryHigh);
          if(videos.length > index + 3){
            VideoCacheService.cacheVideo(videos[index + 2], Priority.high);
          }
        },
        itemBuilder: (context, index) => FullPageVideo(videoStream: videos[index],index: index,onVisibilityChangeCallback: _onVisibilityChange,),
    );
  }
}
