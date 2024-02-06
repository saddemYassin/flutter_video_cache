
/// Exception class for VideoStreamer-related errors.
///
/// This class extends the built-in [Exception] class and is used to represent
/// exceptions specific to the VideoStreamer functionality.
class VideoStreamerException implements Exception {
  /// Constructs a [VideoStreamerException] with the provided error [message].
  const VideoStreamerException(this.message);

  /// The error message associated with the exception.
  final String message;

  /// Overrides the [toString] method to provide a custom string representation of the exception.
  @override
  String toString() => 'VideoStreamer exception $message';
}
