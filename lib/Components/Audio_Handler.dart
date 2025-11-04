import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart'; // Import rxdart for the combineLatest stream

class MyAudioHandler extends BaseAudioHandler {
  final _player = AudioPlayer();

  MyAudioHandler() {
    // We listen to the JustAudio streams and combine them to produce a single
    // PlaybackState stream. This is the recommended robust pattern.
    _listenForPlaybackStateChanges(); 

    // Initialize playback state immediately
    playbackState.add(playbackState.value.copyWith(
        controls: [MediaControl.play, MediaControl.stop],
        processingState: AudioProcessingState.idle,
        playing: false, 
      ));
  }

  /// Combines the streams from just_audio to produce a single stream of PlaybackState.
  void _listenForPlaybackStateChanges() {
    // Listen to all relevant player streams
    Rx.combineLatest4<ProcessingState, bool, Duration, Duration?, PlaybackState>(
      _player.processingStateStream,
      _player.playingStream,
      _player.positionStream.throttleTime(const Duration(seconds: 1)), // Throttle position updates
      _player.bufferedPositionStream,
      (processingState, playing, position, bufferedPosition) {
        // Map JustAudio's ProcessingState to AudioService's AudioProcessingState
        final audioServiceProcessingState = const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[processingState] ?? AudioProcessingState.idle;

        // Construct the PlaybackState
        return playbackState.value.copyWith(
          // Use updatePosition (older audio_service) or position (newer audio_service)
          // We use 'updatePosition' for maximum compatibility based on your error report
          updatePosition: position, 
          bufferedPosition: bufferedPosition ?? Duration.zero,
          playing: playing,
          processingState: audioServiceProcessingState, 
          
          controls: [
            MediaControl.skipToPrevious,
            playing ? MediaControl.pause : MediaControl.play,
            MediaControl.skipToNext,
            MediaControl.stop,
          ],
        );
      },
    ).listen((state) => playbackState.add(state));

    // Also listen to duration changes separately to update the MediaItem
    _player.durationStream.listen((duration) {
      final media = mediaItem.value;
      if (media != null && duration != null) {
        mediaItem.add(media.copyWith(duration: duration));
      }
    });
    
    // Listen for completion (optional, as the state listener covers it)
    // _player.playerStateStream.listen((playerState) {
    //   if (playerState.processingState == ProcessingState.completed) {
    //     // Handle next song or stop playback if PlaySong isn't managing it
    //   }
    // });
  }

  // Custom method used by PlaySong to load and start a new song
  Future<void> playSong(String url, String title, String artist) async {
    final item = MediaItem(
      id: url,
      title: title,
      artist: artist,
      artUri: Uri.parse('https://cdn-icons-png.flaticon.com/512/727/727245.png'),
    );

    mediaItem.add(item); 
    await _player.setUrl(url); 
    await _player.play();
  }

  // --- BaseAudioHandler Overrides ---

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  // Correctly uses positional argument for JustAudio's seek method.
  Future<void> seek(Duration position) {
    return _player.seek(position); 
  }

  // Skip methods remain empty as their logic is in PlaySong.dart
  @override
  Future<void> skipToNext() async {}

  @override
  Future<void> skipToPrevious() async {}
}