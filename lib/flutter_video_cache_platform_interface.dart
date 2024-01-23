import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_video_cache_method_channel.dart';

abstract class FlutterVideoCachePlatform extends PlatformInterface {
  /// Constructs a FlutterVideoCachePlatform.
  FlutterVideoCachePlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterVideoCachePlatform _instance = MethodChannelFlutterVideoCache();

  /// The default instance of [FlutterVideoCachePlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterVideoCache].
  static FlutterVideoCachePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterVideoCachePlatform] when
  /// they register themselves.
  static set instance(FlutterVideoCachePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }
}
