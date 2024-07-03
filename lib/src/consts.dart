
/// The threshold time in seconds that should be cached before playback.
/// If the player's loaded time exceeds the current playback position plus this threshold,
/// playback continues; otherwise, playback stops.
const kMediaThreshHoldInSeconds = 8;

/// The threshold time in seconds to add to the playing position when restarting playback.
/// This additional time ensures a smoother user experience when resuming playback.
const kMediaThreshHoldInToRestartPlay = kMediaThreshHoldInSeconds + 3;

/// The minimum number of seconds required to start playing a media item.
/// Playback starts when the current playback position exceeds this threshold plus the
/// `kMediaThreshHoldInSeconds`.
const kMinSecondsToStartPlay = kMediaThreshHoldInSeconds + 2;

