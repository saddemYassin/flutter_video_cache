import 'dart:io';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';

import 'models/media_metadata.dart';


/// A utility class for working with media metadata.
class MediaMetadataUtils {


  /// Asynchronously retrieves media metadata from a file.
  ///
  /// Parameters:
  ///   - [file] : The file for which metadata needs to be retrieved.
  ///
  /// Returns: A [Future] that completes with a [MediaMetadata] instance if
  /// metadata retrieval is successful, or `null` if the track duration is unavailable.
  static Future<MediaMetadata?> retrieveMetadataFromFile(File file) async {
    // Retrieve metadata from the provided file.
    final extractedMetadata = await MetadataRetriever.fromFile(file);

    // Check if track duration is unavailable, return null in such case.
    if (extractedMetadata.trackDuration == null) {
      return null;
    }

    // Return a new MediaMetadata instance with extracted metadata.
    return MediaMetadata(
      duration: extractedMetadata.trackDuration!,
      bitrate: extractedMetadata.bitrate,
      mimType: extractedMetadata.mimeType,
    );
  }
}
