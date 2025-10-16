// // lib/AppInitializer.dart
// import 'package:audio_service/audio_service.dart';
// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:google_mobile_ads/google_mobile_ads.dart';
// import 'package:ttact/Components/AdBanner.dart';
// import 'package:ttact/Components/Audio_Handler.dart';
// import 'package:ttact/firebase_options.dart';
// import 'package:ttact/introductionPage.dart';
 
// late AudioHandler _audioHandler;

// class AppInitializer extends StatelessWidget {
//   const AppInitializer({super.key});
 
//   Future<void> _initializeApp() async {
//     await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
//     await MobileAds.instance.initialize();
//     await AdManager.initialize();

//     _audioHandler = await AudioService.init(
//       builder: () => MyAudioHandler(),
//       config: const AudioServiceConfig(
//         androidNotificationChannelId: 'com.thetact.ttact.channel.audio',
//         androidNotificationChannelName: 'TTact Audio Playback',
//         androidNotificationOngoing: true,
//         androidStopForegroundOnPause: true,
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder(
//       future: _initializeApp(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.done) {
//           // All services are initialized, navigate to the first screen
//           return const Introductionpage();
//         } else if (snapshot.hasError) {
//           // Handle initialization errors
//           return Scaffold(
//             body: Center(
//               child: Text('Error: ${snapshot.error}'),
//             ),
//           );
//         } else {
//           // Show a loading screen while waiting
//           return const Scaffold(
//             body: Center(
//               child: CircularProgressIndicator(),
//             ),
//           );
//         }
//       },
//     );
//   }
// }