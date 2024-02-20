

import 'package:flutter/material.dart';
import 'package:flutter_video_cache_example/app_video_controller.dart';
import 'package:flutter_video_cache_example/vlc_player_with_controls.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

class VideoPlayerWidget extends StatelessWidget {
  const VideoPlayerWidget({
    super.key,
    required this.videoController,
    required this.aspectRatio
  });

  final AppVideoController videoController;

  final double aspectRatio;


  @override
  Widget build(BuildContext context) {
    if(videoController.controller == null){
      return Container();
    }
    return AppPlayerWithControls(
      controller: videoController,
      aspectRatio: aspectRatio,
      showControls: true,
    );
  }
}
