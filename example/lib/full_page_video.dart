import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_video_cache/flutter_video_cache.dart';
import 'package:flutter_video_cache_example/app_video_controller.dart';
import 'package:flutter_video_cache_example/cache_service.dart';
import 'package:flutter_video_cache_example/video_player_widget.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

class FullPageVideo extends StatefulWidget {
  const FullPageVideo({super.key,required this.videoStream,required this.index,required this.onVisibilityChangeCallback});

  final VideoStream<AppVideoController> videoStream;
  final Function(double,int) onVisibilityChangeCallback;
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
    // widget.videoStream.registerOnProgressCallback(onProgress);
    widget.videoStream.injectDataSource().then((value) {
        if(mounted){
          setState(() {
            _dataSourceInitialized = true;
          });
        }
    });


  }

  void onProgress({required int loadedBytes,required int loadedSeconds,required int percentage}) async {
      if(visibilityFraction > 0.7 && widget.videoStream.loadedMediaDurationInSeconds > (await widget.videoStream.playable.getCurrentPosition()) + 10){
        VideoCacheService.cacheVideo(widget.videoStream, Priority.high);
      }
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    // widget.videoStream.pausePreCaching();
    if(widget.videoStream.loadedMediaDurationInSeconds > 0 && widget.videoStream.loadedMediaDurationInSeconds < widget.videoStream.mediaDurationInSeconds){
      widget.videoStream.pausePreCaching();
      VideoCacheService.cacheVideo(widget.videoStream, Priority.low);
    }
    widget.videoStream.removeCallback(onProgress);
  }

  @override
  void didUpdateWidget(covariant FullPageVideo oldWidget) {
    // TODO: implement didUpdateWidget
    super.didUpdateWidget(oldWidget);
    if(widget.index != oldWidget.index){
      print('inject data source again in didUpdateWidget');
      widget.videoStream.injectDataSource();
    }
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
          widget.onVisibilityChangeCallback(visibilityFraction,widget.index);
          if(visibilityFraction > 0.7){
            VideoCacheService.cacheVideo(widget.videoStream, Priority.veryHigh);
          }
          log('>>> visibilityFraction $visibilityFraction');
          if(visibilityFraction > 0.5 && !_isInitialized){
            widget.videoStream.initialize().then((value) => setState(() {
              _isInitialized = true;
              if(visibilityFraction > 0.5){
                print('play At index ${widget.index}');
                widget.videoStream.play();
              }
            }));
            return;
          }
          if(visibility.visibleFraction > 0.5 && _isInitialized){
            print('play At index ${widget.index}');
            widget.videoStream.play();
          } else if(_isInitialized) {
            widget.videoStream.pause();
          }
        },
        child: Stack(
          children: [
            VideoPlayerWidget(videoController: widget.videoStream.playable, aspectRatio: 9/16),
            Positioned(
              bottom: 30,
              right: 30,
              child: ElevatedButton(
                onPressed: (){
                  widget.videoStream.play();
                },
                child: Text('Play ${widget.index}'),
              ),
            )
          ],
        ));
  }

}
