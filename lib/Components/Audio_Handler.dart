// // lib/Components/Audio_Handler.dart
// import 'package:audio_service/audio_service.dart';
// import 'package:just_audio/just_audio.dart'; 

// class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
//   final _player = AudioPlayer();
//   // Using a private, internal list of URIs to build the audio source.
//   final _uriPlaylist = ConcatenatingAudioSource(children: []);

//   MyAudioHandler() { 
//     _player.playbackEventStream.map(_transformEvent).pipe(playbackState); 
    
//     _player.currentIndexStream.listen((index) {
//       if (index != null && queue.value.isNotEmpty) {
//         // 🐛 FIX: Update mediaItem when the index changes
//         mediaItem.add(queue.value[index]); 
//       }
//     });
//   } 
  
//   // Renamed to avoid conflict with BaseAudioHandler's updateQueue
//   Future<void> loadNewPlaylist(List<MediaItem> songs, int initialIndex) async {
//     // 1. Convert MediaItems to AudioSources
//     final newSources = songs.map((item) {
//       // You must handle empty ID/URI gracefully
//       if (item.id.isEmpty) {
//         return AudioSource.uri(Uri.parse('asset:///assets/audio/empty_track.mp3'), tag: item);
//       }
//       return AudioSource.uri(Uri.parse(item.id), tag: item);
//     }).toList();
    
//     // 2. Update internal just_audio source
//     await _uriPlaylist.clear();
//     await _uriPlaylist.addAll(newSources);
//     await _player.setAudioSource(_uriPlaylist, initialIndex: initialIndex, preload: true);
    
//     // 3. Update audio_service queue (This is what the notification/OS sees)
//     queue.add(songs);

//     // 4. Update the current item based on the initial index
//     if (initialIndex < songs.length) {
//       mediaItem.add(songs[initialIndex]);
//     }

//     // Update controls after loading
//     playbackState.add(playbackState.value.copyWith(controls: [
//       MediaControl.skipToPrevious, MediaControl.pause, MediaControl.skipToNext, MediaControl.stop
//     ]));
//   }
 
//   // Implement skipToQueueItem required by your calling function
//   @override
//   Future<void> skipToQueueItem(int index) async {
//     if (index < queue.value.length) {
//       await _player.seek(Duration.zero, index: index);
//       // The currentIndexStream listener handles mediaItem.add()
//     }
//   }

//   @override
//   Future<void> play() => _player.play();
//   @override
//   Future<void> pause() => _player.pause();
//   @override
//   Future<void> stop() async {
//     await _player.stop();
//     // This is required to remove the notification/service
//     await super.stop();
//   }
//   @override
//   Future<void> skipToNext() => _player.seekToNext();
//   @override
//   Future<void> skipToPrevious() => _player.seekToPrevious();
//   @override
//   Future<void> seek(Duration position) => _player.seek(position);
 
//   PlaybackState _transformEvent(PlaybackEvent event) {
//     return PlaybackState(
//       controls: [
//         MediaControl.skipToPrevious,
//         _player.playing ? MediaControl.pause : MediaControl.play,
//         MediaControl.skipToNext,
//         MediaControl.stop,
//       ],
//       systemActions: const {MediaAction.seek, MediaAction.skipToNext, MediaAction.skipToPrevious},
//       androidCompactActionIndices: const [0, 1, 2],
//       processingState: const {
//         ProcessingState.idle: AudioProcessingState.idle,
//         ProcessingState.loading: AudioProcessingState.loading,
//         ProcessingState.buffering: AudioProcessingState.buffering,
//         ProcessingState.ready: AudioProcessingState.ready,
//         ProcessingState.completed: AudioProcessingState.completed,
//       }[_player.processingState] ?? AudioProcessingState.idle, // Added null check/default
//       playing: _player.playing,
//       updatePosition: _player.position,
//       bufferedPosition: _player.bufferedPosition,
//       speed: _player.speed,
//       queueIndex: event.currentIndex,
//     );
//   }
// }