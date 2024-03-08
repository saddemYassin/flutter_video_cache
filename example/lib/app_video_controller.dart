import 'dart:async';
import 'dart:io';
import 'package:flutter_video_cache/flutter_video_cache.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';



/// A controller for managing video playback within the application.
///
/// This class extends [PlayableInterface], providing methods to control
/// the playback of video content. It allows setting the data source,
/// initializing the player, playing, pausing, seeking, and querying the
/// playback state and position of the video.
class AppVideoController extends PlayableInterface {

  /// The controller for the video player responsible for controlling video playback.
  /// This property holds an instance of a video player controller, allowing the management
  /// of video playback operations such as play, pause, seek, and volume control.
  /// It can be null if no video controller is assigned or initialized yet.
  VlcPlayerController? controller;

  /// True video playback is ongoing, and false otherwise.
  ///
  /// A boolean flag indicating whether the video is currently playing or not.
  bool _isPlaying = false;


  /// The file path where the video data is stored or will be stored after downloading.
  /// It holds the absolute path to the location of the video file on the device's storage.
  /// If the video is not yet downloaded, this property remains null.
  String? dataFilePath;


  /// Represents the current state of the video player.
  /// It tracks various states such as initialization, playing, pausing, buffering, etc.
  /// The initial state is set to [PlayingState.initializing] until the player is ready.
  PlayingState _currentPlayingState = PlayingState.initializing;


  /// A function that listens to video player events.
  ///
  /// This function is called whenever there is a change in the video player's state
  /// or when certain events occur during video playback.
  int _oldPosition = 0;


  /// Sets the data source for the video player.
  ///
  /// This method takes a [filePath] as input, which represents the path to the video file.
  /// It initializes the video player controller with the provided file.
  ///
  /// Parameters:
  ///   - [filePath]: The path to the video file.
  ///
  /// Throws:
  ///   - Exception: If an error occurs during file initialization.
  @override
  Future<void> setDataSource(String filePath) async {
    // Set the data file path
    dataFilePath = filePath;

    // Create a file object from the file path
    File file = File(filePath);

    // Initialize the video player controller with the file
    /// TODO replace with pooling controller
    controller = VlcPlayerController.file(
        file,
        hwAcc: HwAcc.full,
        autoInitialize: false,
        autoPlay: false,
        allowBackgroundPlayback: false
    );

    // Add a listener to the controller for player events
    controller!.addListener(playerEventListener);
  }


  /// Listens to player events and performs actions accordingly.
  ///
  /// This method is called whenever there's a change in the player's state.
  void playerEventListener() {
    // Check if the current playing state has changed and the player has ended
    if (_currentPlayingState != controller!.value.playingState &&
        controller!.value.playingState == PlayingState.ended) {
      // Update the current playing state
      _currentPlayingState = controller!.value.playingState;

      // Set media from file and reset position to start
      /// Fixme : a quick fix for replay video when it ends.
      controller!.setMediaFromFile(File(dataFilePath!), autoPlay: false, hwAcc: HwAcc.auto)
          .then((value) {
        // If the player was playing, start playing from the beginning
        if(_isPlaying){
          controller!.setTime(0).then((_) {
            if(_isPlaying){
              controller!.play();
            }
          });
        }
      });
    }

    // Update the current playing state if it has changed
    if(_currentPlayingState != controller!.value.playingState){
      _currentPlayingState = controller!.value.playingState;
    }
  }



  /// Disposes the video player controller.
  ///
  /// This method releases all the resources used by the video player controller.
  Future<void> dispose() async {
    // Dispose the controller if it exists
    await controller?.dispose();

    // Set the controller reference to null to release the memory
    controller = null;
  }


  /// Plays the video.
  ///
  /// This method plays the video using the video player controller.
  /// It first checks if the controller is initialized before playing the video.
  @override
  Future<void> play() async {
    // Check if the controller is initialized
    if(controller!.value.isInitialized){
      // Play the video using the controller
      await controller!.play();

      // Set the playing state to true
      _isPlaying = true;
    }
  }

  /// Getter to check if the video is currently playing.
  ///
  /// Returns a boolean value indicating whether the video is currently playing or not.
  @override
  bool get isPlaying => _isPlaying;

  /// Retrieves the current position of the video playback.
  ///
  /// This method returns the current position (in seconds) of the video playback.
  /// If the controller is not initialized or if the current position is less than or equal to the previous position,
  /// it returns the previous position stored in [_oldPosition].
  ///
  /// Returns:
  ///   - An integer representing the current position of the video playback in seconds.
  @override
  Future<int> getCurrentPosition() async {
    // Check if the controller is null, return 0 if true
    if (controller == null) return 0;

    // Check if the controller is initialized, return 0 if false
    if (!controller!.value.isInitialized) return 0;

    // Check if the current position is greater than the previous position
    // If true, return the current position
    if (controller!.value.position.inSeconds > _oldPosition) {
      return controller!.value.position.inSeconds;
    }

    // If the current position is less than or equal to the previous position,
    // return the previous position stored in _oldPosition
    return _oldPosition;
  }


  /// Checks if the video controller is initialized.
  ///
  /// This getter returns a boolean value indicating whether the video controller
  /// is initialized or not. It returns true if the controller is not null and
  /// its value's `isInitialized` property is true. Otherwise, it returns false.
  ///
  /// Returns:
  ///   - A boolean value indicating whether the video controller is initialized or not.
  @override
  bool get isInitialized => controller?.value.isInitialized ?? false;


  /// Pauses the video playback.
  ///
  /// This method pauses the video playback by calling the `pause` method on the
  /// video controller. It also updates the `_isPlaying` flag to false to indicate
  /// that the video is not playing.
  ///
  /// Note: If the video controller is null, this method does nothing.
  @override
  Future<void> pause() async {
    await controller?.pause();
    _isPlaying = false;
  }


  /// Initializes the video player controller.
  ///
  /// This method initializes the video player controller if it's not already
  /// initialized. If the controller is already initialized or if it's in the
  /// process of initialization, this method does nothing.
  ///
  /// Note: If the controller's view ID is null, it means that it's not fully
  /// initialized yet, so the method calls itself recursively until the controller
  /// is fully initialized.
  @override
  Future<void> initialize() async {
    if (controller != null && controller!.viewId == null) {
      // If the controller's view ID is null, it means it's not fully initialized.
      // Call the initialize method recursively until the controller is initialized.
      initialize();
      return;
    }
    if (controller != null && !controller!.value.isInitialized) {
      // If the controller is not initialized yet, initialize it.
      await controller!.initialize();
    }
  }

  /// Seeks the video to the specified position in seconds.
  ///
  /// This method seeks the video to the specified position in seconds by setting
  /// the time of the video player controller. It also updates the [_oldPosition]
  /// variable to keep track of the last known position.
  ///
  /// Parameters:
  ///   - positionInSeconds: The position to seek to in seconds.
  ///
  /// Note: If the controller is null or not initialized, this method does nothing.
  @override
  Future<void> seekTo(int positionInSeconds) async {
    // Update the _oldPosition variable to keep track of the last known position.
    _oldPosition = positionInSeconds;
    // Set the time of the controller to seek to the specified position.
    await controller?.setTime(positionInSeconds);
  }
}