import 'package:flutter/material.dart';
import 'package:flutter_video_cache/flutter_video_cache.dart';
import 'package:flutter_video_cache_example/app_video_controller.dart';
import 'package:flutter_video_cache_example/video_player_widget.dart';
import 'package:flutter_video_cache_example/videos_download_manager.dart';
import 'package:visibility_detector/visibility_detector.dart';

class FullPageVideo extends StatefulWidget {
  const FullPageVideo({super.key,required this.videoStream,required this.index});

  final VideoStream<AppVideoController> videoStream;
  final int index;

  @override
  State<FullPageVideo> createState() => _FullPageVideoState();
}

class _FullPageVideoState extends State<FullPageVideo> {

  bool _dataSourceInitialized = false;
  bool _isInitialized = false;
  double visibilityFraction = 0;

  @override
  void initState() {
    super.initState();
    widget.videoStream.injectDataSource().then((value) {
        if(mounted){
          setState(() {
            _dataSourceInitialized = true;
          });
        }
    });


  }


  @override
  Widget build(BuildContext context) {
    if(!_dataSourceInitialized){
      return Container();
    }

    return VisibilityDetector(
        key: Key('index-${widget.index}'),
        onVisibilityChanged: (visibility){
          visibilityFraction = visibility.visibleFraction;
          if(visibilityFraction > 0.7){
            VideosDownloadManager.cacheVideo(widget.videoStream, Priority.veryHigh);
          }
          if(visibilityFraction > 0.5 && !_isInitialized){
            widget.videoStream.initialize().then((value) => setState(() {
              _isInitialized = true;
              if(visibilityFraction > 0.5){
                widget.videoStream.play();
              }
            }));
            return;
          }
          if(visibility.visibleFraction > 0.5 && _isInitialized){
            widget.videoStream.play();
          } else if(_isInitialized) {
            widget.videoStream.pause();
          }
        },
        child: VideoPlayerWidget(videoController: widget.videoStream.playable, aspectRatio: 9/16));
  }

  @override
  void dispose() {
    super.dispose();
    if(widget.videoStream.loadedMediaDurationInSeconds > 0 && widget.videoStream.loadedMediaDurationInSeconds < widget.videoStream.mediaDurationInSeconds){
      widget.videoStream.pausePreCaching();
      VideosDownloadManager.cacheVideo(widget.videoStream, Priority.low);
    }
  }

}
