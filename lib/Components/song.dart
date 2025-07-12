import 'package:cloud_firestore/cloud_firestore.dart';

class Song {
  final String songName;
  final String songUrl;
  final String artist;
  final DateTime? createdAt;

  Song({
    required this.songName,
    required this.songUrl,
    required this.artist,
    this.createdAt,
  });

  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      songName: map['songName'] ?? '',
      songUrl: map['songUrl'] ?? '',
      artist: map['artist'] ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'songName': songName,
      'songUrl': songUrl,
      'artist': artist,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
