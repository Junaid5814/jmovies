import 'package:flutter/material.dart';
import 'watch_webview_screen.dart';

class PlayerScreen extends StatelessWidget {
  final dynamic movie;
  final dynamic show;
  final dynamic episode;
  final dynamic mediaItem;
  final dynamic media;
  final dynamic item;
  final int? tmdbId;
  final int? id;
  final String? title;
  final String? name;
  final bool isTv;
  final bool? isMovie;
  final int? seasonNumber;
  final int? season;
  final int? episodeNumber;

  const PlayerScreen({
    super.key,
    this.movie,
    this.show,
    this.episode,
    this.mediaItem,
    this.media,
    this.item,
    this.tmdbId,
    this.id,
    this.title,
    this.name,
    this.isTv = false,
    this.isMovie,
    this.seasonNumber,
    this.season,
    this.episodeNumber,
  });

  const PlayerScreen.forMovie(
    dynamic movieItem, {
    super.key,
  })  : movie = movieItem,
        show = null,
        episode = null,
        mediaItem = null,
        media = null,
        item = null,
        tmdbId = null,
        id = null,
        title = null,
        name = null,
        isTv = false,
        isMovie = true,
        seasonNumber = null,
        season = null,
        episodeNumber = null;

  const PlayerScreen.forEpisode({
    super.key,
    this.show,
    this.episode,
    this.movie,
    this.mediaItem,
    this.media,
    this.item,
    this.tmdbId,
    this.id,
    this.title,
    this.name,
    this.isTv = true,
    this.isMovie = false,
    this.seasonNumber,
    this.season,
    this.episodeNumber,
  });

  @override
  Widget build(BuildContext context) {
    return WatchWebviewScreen(
      movie: movie,
      show: show,
      episode: episode,
      mediaItem: mediaItem,
      media: media,
      item: item,
      tmdbId: tmdbId ?? id,
      id: id ?? tmdbId,
      title: title ?? name,
      name: name ?? title,
      isTv: isTv,
      isMovie: isMovie,
      seasonNumber: seasonNumber ?? season,
      season: season ?? seasonNumber,
      episodeNumber: episodeNumber,
    );
  }
}
