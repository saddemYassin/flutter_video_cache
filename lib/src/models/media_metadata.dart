
/// A class representing metadata for media content.
///
/// This class includes information such as duration, bitrate, and MIME type.
class MediaMetadata {
  /// The duration of the media content in seconds.
  final int duration;

  /// The size of the media content in bytes
  final int fileSize;

  /// The bitrate of the media content in bits per second.
  final int? bitrate;

  /// The MIME type of the media content.
  final String? mimType;


  /// Creates a [MediaMetadata] instance with the specified parameters.
  ///
  /// Parameters:
  ///   - [duration] : The duration of the media content in seconds.
  ///   - [bitrate] : The bitrate of the media content in bits per second.
  ///   - [mimType] : The MIME type of the media content.
  const MediaMetadata({
    required this.duration,
    required this.fileSize,
    this.bitrate,
    this.mimType,
  });

  /// Returns a string representation of the [MediaMetadata] instance.
  @override
  String toString() => 'MediaMetadata(duration: $duration, fileSize: $fileSize, bitrate: $bitrate, mimType: $mimType)';

  /// Computes the hash code for the [MediaMetadata] instance.
  @override
  int get hashCode => Object.hash(duration, fileSize, bitrate, mimType);

  /// Checks if this [MediaMetadata] instance is equal to another object.
  ///
  /// Returns true if the other object is a [MediaMetadata] instance with
  /// the same duration, bitrate, and MIME type.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is MediaMetadata &&
              runtimeType == other.runtimeType &&
              duration == other.duration &&
              fileSize == other.fileSize &&
              bitrate == other.bitrate &&
              mimType == other.mimType;
}
