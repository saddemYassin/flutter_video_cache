import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_video_cache/flutter_video_cache.dart';
import 'package:flutter_video_cache_example/app_video_controller.dart';
import 'package:flutter_video_cache_example/video_player_widget.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

class FullPageVideo extends StatefulWidget {
  const FullPageVideo({super.key,required this.videoStream,required this.index,required this.onPageCreatedCallback});

  final VideoStream<AppVideoController> videoStream;
  final Function(int) onPageCreatedCallback;
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
    widget.onPageCreatedCallback(widget.index);
    widget.videoStream.setDataSource().then((value) {
      log('>>> set data source');
      setState(() {
        _dataSourceInitialized = true;
      });
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
          log('>>> visibilityFraction $visibilityFraction');
          if(visibilityFraction > 0.5 && !_isInitialized){
            widget.videoStream.initialize().then((value) => setState(() {
              _isInitialized = true;
              log('>>> is init');
              if(visibilityFraction > 0.5){
                log('>>> play');
                widget.videoStream.play();
              }
            }));
            return;
          }
          if(visibility.visibleFraction > 0.5 && _isInitialized){
            log('>>> play');
            log('level 2');
            widget.videoStream.play();
          } else if(_isInitialized){
            widget.videoStream.pause();
          }
        },
        child: VideoPlayerWidget(videoController: widget.videoStream.playable, aspectRatio: 16/9));
  }

}
