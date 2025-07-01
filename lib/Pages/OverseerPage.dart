import 'package:flutter/material.dart';

class OverseerPage extends StatefulWidget {
  const OverseerPage({super.key});

  @override
  State<OverseerPage> createState() => _OverseerPageState();
}

class _OverseerPageState extends State<OverseerPage> {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Available Oversers'));
  }
}
