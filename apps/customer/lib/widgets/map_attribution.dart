import 'package:flutter/material.dart';

/// Tiny OpenStreetMap attribution shown bottom-left over every map.
/// Add as the last child of a [FlutterMap]'s `children`.
class OsmAttribution extends StatelessWidget {
  const OsmAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.75),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          '© OpenStreetMap',
          style: TextStyle(fontSize: 10, color: Color(0xFF5B6472)),
        ),
      ),
    );
  }
}
