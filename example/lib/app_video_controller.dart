import 'dart:io';
import 'package:flutter_video_cache/flutter_video_cache.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

class AppVideoController extends PlayableInterface {

  VlcPlayerController? controller;

  bool _isPlaying = false;

  
  
  @override
  Future<void> setDataSource(String filePath) async {
      if(controller != null){
        await controller!.dispose();
      }
      controller = VlcPlayerController.file(File(filePath), hwAcc: HwAcc.full,autoInitialize: false,autoPlay: false,options: VlcPlayerOptions());
  }

  
  Future<void> dispose() async {
    await controller?.dispose();
    controller = null;
  }

  @override
  Future<void> play() async {
    await controller?.play();
    _isPlaying = true;
  }

  @override
  bool get isPlaying => _isPlaying;

  @override
  Future<int> getCurrentPosition() async {
    if(controller == null) return Future.value(0);
    return (await controller!.getPosition()).inSeconds;
  }

  @override
  bool get isInitialized => controller?.value.isInitialized ?? false;

  @override
  Future<void> pause() async {
    await controller?.pause();
    _isPlaying = false;
  }

  @override
  Future<void> initialize() async {
    await controller?.initialize();
  }
}