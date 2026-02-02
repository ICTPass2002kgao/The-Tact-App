// // lib/services/audio_service_handler.dart

// import 'package:audio_service/audio_service.dart';
// import 'package:ttact/Components/Audio_Handler.dart';

// class AudioServiceHandler {
//   static AudioHandler? _audioHandler;
//   static Future<AudioHandler>? _initializationFuture;
  
//   static Future<AudioHandler> get audioHandler async {
//     if (_initializationFuture != null) {
//       return _initializationFuture!;
//     }
    
//     if (_audioHandler != null) {
//       return _audioHandler!;
//     }
    
//     _initializationFuture = _initializeInternal();
    
//     final handler = await _initializationFuture;
    
//     _initializationFuture = null; 
//     if (handler == null) {
//       throw Exception('AudioHandler initialization failed');
//     }
//     return handler;
//   }
  
//   static Future<AudioHandler> _initializeInternal() async {
//     try {
//       _audioHandler = await AudioService.init(
//         builder: () => MyAudioHandler(), 
//         config: const AudioServiceConfig(
//           androidNotificationChannelId: 'com.thetact.ttact.channel.audio',
//           androidNotificationChannelName: 'TACT Music Playback',
//           androidNotificationOngoing: true,
//           androidStopForegroundOnPause: true,
//         ),
//       );
//       return _audioHandler!;
//     } catch (e) {
//       print('Audio service initialization error: $e');
//       _initializationFuture = null; 
//       rethrow;
//     }
//   }
  
//   static void dispose() {
//     _audioHandler?.stop();
//     _audioHandler = null;
//     _initializationFuture = null;
//   }
// }