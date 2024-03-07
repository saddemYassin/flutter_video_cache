import 'package:app_minimizer/app_minimizer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_video_cache/flutter_video_cache.dart';
import 'package:flutter_video_cache_example/app_video_controller.dart';
import 'package:flutter_video_cache_example/data.dart';
import 'package:flutter_video_cache_example/full_page_video.dart';
import 'package:flutter_video_cache_example/videos_download_manager.dart';

class VideosList extends StatefulWidget {
  const VideosList({super.key});

  @override
  State<VideosList> createState() => _VideosListState();
}

class _VideosListState extends State<VideosList> with WidgetsBindingObserver {


  late List<VideoStream<AppVideoController>> videos;

  int lastVisitedPage = 0;


  String _cacheKeyExtractor(String url) {
      final String name = url.split('/').last;
      // replace special chars
      final String cleanName = name.replaceAll(RegExp(r'[^\w\s]'), '_');
      return cleanName;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if(state == AppLifecycleState.inactive) {
      if(videos[lastVisitedPage].playable.isPlaying){
        videos[lastVisitedPage].pause();
      }

    }
    if(state == AppLifecycleState.hidden){
      if(videos[lastVisitedPage].playable.isPlaying){
        videos[lastVisitedPage].pause();
      }

    }
    if(state == AppLifecycleState.paused){
      if(videos[lastVisitedPage].playable.isPlaying){
        await videos[lastVisitedPage].pause();
      }
    }
    if(state == AppLifecycleState.resumed){
        videos[lastVisitedPage].play();
    }
    if(state == AppLifecycleState.detached){
      if(videos[lastVisitedPage].playable.isPlaying){
        videos[lastVisitedPage].pause();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    videos = Data.videos.map((e) => VideoStream<AppVideoController>(url: e, playable: AppVideoController(),cacheKey: _cacheKeyExtractor(e))).toList();
    for(int i = 0; i < videos.length; i++){
        if(i == 0){
          VideosDownloadManager.cacheVideo(videos[i], Priority.veryHigh);
          continue;
        }
        if(i < 4){
          VideosDownloadManager.cacheVideo(videos[i], Priority.high);
          continue;
        }
        if(i < 8){
          VideosDownloadManager.cacheVideo(videos[i], Priority.medium);
          continue;
        }
        VideosDownloadManager.cacheVideo(videos[i], Priority.low);
      }
  }


  PageController pageController = PageController();

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
        itemCount: videos.length,
        controller: pageController,
        onPageChanged: (index){
          lastVisitedPage = index;
          VideosDownloadManager.cacheVideo(videos[index], Priority.veryHigh);
          if(videos.length > index + 2){
            VideosDownloadManager.cacheVideo(videos[index + 2], Priority.high);
          }
        },
        itemBuilder: (context, index) => FullPageVideo(videoStream: videos[index],index: index),
    );
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }
}
