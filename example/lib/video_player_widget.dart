import 'package:flutter/material.dart';
import 'package:flutter_video_cache_example/app_video_controller.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

/// A widget for displaying video content using VLC player.
class VideoPlayerWidget extends StatelessWidget {

  /// Constructs a `VideoPlayerWidget`.
  ///
  /// The [videoController] parameter is required and represents the controller
  /// for managing the video playback.
  ///
  /// The [aspectRatio] parameter is required and specifies the aspect ratio
  /// of the video.
  const VideoPlayerWidget({
    super.key,
    required this.videoController,
    required this.aspectRatio
  });

  /// The controller for managing the video playback.
  final AppVideoController videoController;

  /// The aspect ratio of the video.
  final double aspectRatio;


  @override
  Widget build(BuildContext context) {
    if(videoController.controller == null){
      return Container();
    }
    return Center(
      child: VlcPlayer(
        controller: videoController.controller!,
        aspectRatio: aspectRatio,
        virtualDisplay: false,
        placeholder:
        const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
