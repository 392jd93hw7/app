import 'package:flutter_test/flutter_test.dart';
import 'package:aniscroll/models/anime.dart';

void main() {
  group('Anime.fromJson', () {
    test('normalizes AniList title, cover, score and metadata', () {
      final anime = Anime.fromJson({
        'id': 151807,
        'idMal': 52991,
        'title': {
          'english': 'Example Anime',
          'romaji': 'Example Anime JP',
        },
        'coverImage': {
          'extraLarge': 'https://example.com/cover.jpg',
          'large': 'https://example.com/cover-small.jpg',
        },
        'bannerImage': 'https://example.com/banner.jpg',
        'averageScore': 87,
        'seasonYear': 2025,
        'episodes': 12,
        'genres': ['Action', 'Drama'],
        'format': 'TV',
        'status': 'FINISHED',
      });

      expect(anime.id, '151807');
      expect(anime.malId, '52991');
      expect(anime.title, 'Example Anime');
      expect(anime.image, 'https://example.com/cover.jpg');
      expect(anime.banner, 'https://example.com/banner.jpg');
      expect(anime.score, '87');
      expect(anime.year, '2025');
      expect(anime.episodeCount, 12);
      expect(anime.genres, ['Action', 'Drama']);
      expect(anime.format, 'TV');
      expect(anime.status, 'FINISHED');
    });

    test('handles missing and alternate MAL fields safely', () {
      final anime = Anime.fromJson({
        'mal_id': 123,
        'name': 'MAL Anime',
        'images': {'jpg': {'image_url': 'https://example.com/poster.jpg'}},
        'type': 'TV',
      });

      expect(anime.id, '123');
      expect(anime.title, 'MAL Anime');
      expect(anime.format, 'TV');
      expect(anime.score, '—');
      expect(anime.genres, isEmpty);
    });
  });
}
