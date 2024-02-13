import 'dart:developer';
import 'dart:io';
import 'package:flutter_video_cache/flutter_video_cache.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

class AppVideoController extends PlayableInterface {

  VlcPlayerController? controller;

  bool _isPlaying = false;

  String? dataFilePath;

  PlayingState _currentPlayingState = PlayingState.initializing;
  
  @override
  Future<void> setDataSource(String filePath) async {
      if(controller != null){
        await controller!.dispose();
      }
      dataFilePath = filePath;
      File file = File(filePath);
      controller = VlcPlayerController.file(
          file,
          hwAcc: HwAcc.auto,
          autoInitialize: false,
          autoPlay: false,
      );

      controller!.addListener(() {

          if (_currentPlayingState != controller!.value.playingState && controller!.value.playingState == PlayingState.ended) {
            _currentPlayingState = controller!.value.playingState;
            controller!.setMediaFromFile(file, autoPlay: false, hwAcc: HwAcc.auto);
          }
          if(_currentPlayingState != controller!.value.playingState){
            _currentPlayingState = controller!.value.playingState;
            log('_currentPlayingState $_currentPlayingState');
          }
      });
  }

  
  Future<void> dispose() async {
    await controller?.dispose();
    controller = null;
  }

  @override
  Future<void> play() async {
    if(controller!.value.isInitialized){
      await controller!.play();
      _isPlaying = true;
    }
  }

  @override
  bool get isPlaying => _isPlaying;

  @override
  Future<int> getCurrentPosition() async {
    if(controller == null) return Future.value(0);
    if(!controller!.value.isInitialized) return Future.value(0);
    return (await controller!.getPosition()).inSeconds;
  }

  @override
  bool get isInitialized => controller?.value.isInitialized ?? false;

  @override
  Future<void> pause() async {
    log('pause in app video controller');
    await controller?.pause();
    _isPlaying = false;
  }

  @override
  Future<void> initialize() async {
    await controller?.initialize();
  }
}