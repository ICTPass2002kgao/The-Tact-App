// lib/Components/DownloadedSongs.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ttact/Components/API.dart'; // Ensure this path is correct
import 'package:ttact/Components/Play_Song.dart'; // Ensure this path is correct
import 'package:ttact/Components/song.dart'; // Ensure this path is correct

class DownloadedSongs extends StatefulWidget {
  const DownloadedSongs({super.key});

  @override
  State<DownloadedSongs> createState() => _DownloadedSongsState();
}

class _DownloadedSongsState extends State<DownloadedSongs> {
  List<Song> songs = [];
  final LocalStorageService _localStorageService = LocalStorageService();

  @override
  void initState() {
    super.initState();
    _loadDownloadedSongs();
  }

  Future<void> _loadDownloadedSongs() async {
    final downloaded = await _localStorageService.getDownloadedSongs();
    setState(() {
      songs = downloaded;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Downloaded Songs')),
      body: songs.isEmpty
          ? const Center(child: Text('No downloaded songs found.'))
          : ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];

                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(width: 1.5),
                    ),
                    child: ListTile(
                      onTap: () {
                        showCupertinoModalPopup(
                          // Use showCupertinoModalPopup for better sheet behavior
                          context: context,
                          builder: (context) {
                            return PlaySong(
                              songs: songs
                                  .map((s) => s.toMap())
                                  .toList(), // Pass as List<Map<String, dynamic>>
                              initialIndex: index,
                            );
                          },
                        );
                      },
                      trailing: const Icon(Icons.more_vert_outlined),
                      subtitle: Text(
                        'by - ${song.artist ?? 'Unknown artist'} • ${song.createdAt is Timestamp ? (song.createdAt as Timestamp).toDate().toString().split(' ')[0] : (song.createdAt ?? 'Unknown date')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w200,
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                        ),
                      ),
                      title: Text(song.songName ?? 'Untitled song'),
                      leading: Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(width: 1.5),
                        ),
                        child: Icon(
                          Icons.music_note_outlined,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
