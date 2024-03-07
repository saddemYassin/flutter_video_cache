import 'package:flutter/material.dart';
import 'package:flutter_video_cache/flutter_video_cache.dart';
import 'package:flutter_video_cache_example/videos_list.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterVideoCache.init(debug: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
