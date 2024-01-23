import 'package:flutter_video_cache/src/video_streamer.dart';

/// An interface for playing a video or audio
///
/// Enable [VideoStream] to play/pause a video or audio while streaming its content
abstract class PlayableInterface {

  Future<void> initialize();

  /// Plays a video or audio
  Future<void> play();

  /// Pauses a video or audio
  Future<void> pause();

  /// True if playable is initialized
  bool get isInitialized;
}
