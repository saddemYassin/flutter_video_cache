import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_video_cache_platform_interface.dart';

/// An implementation of [FlutterVideoCachePlatform] that uses method channels.
class MethodChannelFlutterVideoCache extends FlutterVideoCachePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_video_cache');

}
