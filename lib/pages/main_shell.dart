import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/anime.dart';
import 'home_page.dart';
import 'discover_page.dart';
import 'schedule_page.dart';
import 'watchlist_page.dart';
import 'profile_page.dart';
import 'anime_detail_page.dart';
import 'player_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int tab = 0;
  final saved = <Anime>[];
  final history = <Anime>[];
  String profile = 'You';

  void toggle(Anime anime) {
    setState(() {
      if (saved.any((item) => item.id == anime.id)) {
        saved.removeWhere((item) => item.id == anime.id);
      } else {
        saved.add(anime);
      }
    });
  }

  void open(Anime anime) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AnimeDetailPage(
      anime: anime,
      isSaved: saved.any((item) => item.id == anime.id),
      onSave: () => toggle(anime),
      onPlay: (episode) {
        if (!history.any((item) => item.id == anime.id)) {
          setState(() => history.insert(0, anime));
        }
        Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerPage(anime: anime, episode: episode)));
      },
    )));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(onOpen: open, history: history),
      DiscoverPage(onOpen: open),
      const SchedulePage(),
      WatchlistPage(items: saved, onOpen: open, onRemove: toggle),
      ProfilePage(profile: profile, history: history, onProfile: (value) => setState(() => profile = value)),
    ];
    return Scaffold(
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: NavigationBar(
        height: 68,
        backgroundColor: const Color(0xFF10111C),
        indicatorColor: appPurple.withValues(alpha: .2),
        selectedIndex: tab,
        onDestinationSelected: (index) => setState(() => tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Discover'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Schedule'),
          NavigationDestination(icon: Icon(Icons.bookmark_border), selectedIcon: Icon(Icons.bookmark), label: 'Watchlist'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
