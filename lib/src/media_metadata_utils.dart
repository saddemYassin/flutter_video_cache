import 'dart:io';
import 'package:flutter_video_info/flutter_video_info.dart';
import 'models/media_metadata.dart';


/// A utility class for working with media metadata.
class MediaMetadataUtils {


  static final videoInfo = FlutterVideoInfo();


  /// Asynchronously retrieves media metadata from a file.
  ///
  /// Parameters:
  ///   - [file] : The file for which metadata needs to be retrieved.
  ///
  /// Returns: A [Future] that completes with a [MediaMetadata] instance if
  /// metadata retrieval is successful, or `null` if the track duration is unavailable.
  static Future<MediaMetadata?> retrieveMetadataFromFile(File file) async {
    // Retrieve metadata from the provided file.
    final extractedMetadata = await videoInfo.getVideoInfo(file.path);

    // Check if track duration is unavailable, return null in such case.
    if (extractedMetadata?.duration == null) {
      return null;
    }


    // Return a new MediaMetadata instance with extracted metadata.
    return MediaMetadata(
      duration: extractedMetadata!.duration! ~/ 1000,
      fileSize: extractedMetadata.filesize ?? 0,
      bitrate: extractedMetadata.framerate?.toInt() ?? 0,
      mimType: extractedMetadata.mimetype,
    );
  }
}
