
import 'package:flutter/material.dart';
import 'package:flutter_video_cache/flutter_video_cache.dart';
import 'package:flutter_video_cache_example/app_video_controller.dart';
import 'package:flutter_video_cache_example/data.dart';
import 'package:flutter_video_cache_example/full_page_video.dart';

class VideosList extends StatefulWidget {
  const VideosList({super.key});

  @override
  State<VideosList> createState() => _VideosListState();
}

class _VideosListState extends State<VideosList> {


  late List<VideoStream<AppVideoController>> videos;
  int? _lastVisitedPageIndex;

  @override
  void initState() {
    super.initState();
    videos = Data.videos.map((e) => VideoStream<AppVideoController>(url: e, playable: AppVideoController(),cacheKey: 'video-${e.hashCode}')).toList();
      videos[0].preCache();
      videos[0].registerOnProgressCallback(({required int loadedBytes,required int loadedSeconds,required int percentage}) {
        onProgress(loadedSeconds: loadedSeconds, index: 0);
      });

  }


  void onProgress({required int loadedSeconds, required int index}){
    if(_lastVisitedPageIndex != null){
      if(index == _lastVisitedPageIndex || index == _lastVisitedPageIndex! + 1){
        return;
      }
    }
    if(loadedSeconds >= 5){
      videos[index].pausePreCaching();
    }
    if(index + 1 <= videos.length - 1){
      videos[index + 1].preCache();
    }
  }

  void onPageCreatedCallback(int index){
    if(_lastVisitedPageIndex != null){
      videos[_lastVisitedPageIndex!].pausePreCaching();
    }

    if(index == _lastVisitedPageIndex){
      return;
    }

    videos[index].preCache();

    _lastVisitedPageIndex = index;
  }



  @override
  Widget build(BuildContext context) {
    return PageView.builder(
        itemCount: videos.length,
        itemBuilder: (context, index) => FullPageVideo(videoStream: videos[index],index: index,onPageCreatedCallback: onPageCreatedCallback),
    );
  }
}
