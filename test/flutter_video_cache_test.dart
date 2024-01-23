import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_video_cache/flutter_video_cache.dart';
import 'package:flutter_video_cache/flutter_video_cache_platform_interface.dart';
import 'package:flutter_video_cache/flutter_video_cache_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterVideoCachePlatform
    with MockPlatformInterfaceMixin
    implements FlutterVideoCachePlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterVideoCachePlatform initialPlatform = FlutterVideoCachePlatform.instance;

  test('$MethodChannelFlutterVideoCache is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterVideoCache>());
  });

  test('getPlatformVersion', () async {
    // FlutterVideoCache flutterVideoCachePlugin = FlutterVideoCache();
    // MockFlutterVideoCachePlatform fakePlatform = MockFlutterVideoCachePlatform();
    // FlutterVideoCachePlatform.instance = fakePlatform;

  });
}
