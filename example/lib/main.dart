import 'package:flutter/material.dart';
import 'package:flutter_video_cache/flutter_video_cache.dart';
import 'package:flutter_video_cache_example/videos_list.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterVideoCache.init(debug: true);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {


  /// TODO create a ui of list of scrollable videos:
  /// TODO A pageView list of videos.
  /// TODO create a list of [VideosStreamer] objects each one contain a video
  /// TODO start precaching the first video
  /// TODO when first video is full downloaded precaching the next video
  /// TODO #2 if second video not playing stop precaching when obtaining 5 seconds of the video
  /// TODO #2 done do the the some to the next video etc ...

  /// TODO Every time user go to the new video assign a controller the [VideosStreamer] object
  /// TODO init the selected video [VideosStreamer] object
  /// TODO check if visibility is > 0.5 start playing the video
  /// TODO when visibility is < 0.5 pause the video

  @override
  void initState() {
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: const VideosList(),
      ),
    );
  }
}
