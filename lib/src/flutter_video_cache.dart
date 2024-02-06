import 'downloader_manager.dart';


/// The plugin implementation for the flutter_video_cache plugin.
class FlutterVideoCache {

  /// True if packages has been initialized
  static bool _isInitialized = false;

  /// [_isInitialized] getter
  bool get isInitialized => _isInitialized;


  /// Initialize the package
  static Future<void> init({bool debug = false}) async {
    if(!_isInitialized) {
      await DownloadManager.instance.init(debug: debug);
      _isInitialized = true;
    }
  }
}