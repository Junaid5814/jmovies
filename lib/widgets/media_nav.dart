import 'package:flutter/material.dart';
import '../data/models/media_item.dart';
import '../screens/details/details_screen.dart';

/// Opens [DetailsScreen] for a [MediaItem], routing movies/TV correctly.
/// Shared by every carousel/row widget so navigation stays consistent.
void openMediaDetails(BuildContext context, MediaItem item) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => DetailsScreen(id: item.id, isTv: item.isTv),
    ),
  );
}
