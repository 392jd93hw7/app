import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/anime.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.profile,
    required this.history,
    required this.onProfile,
  });
  final String profile;
  final List<Anime> history;
  final ValueChanged<String> onProfile;
  @override
  Widget build(BuildContext c) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Your profile',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 20),
        Center(
          child: Column(
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: appPanel,
                child: Icon(Icons.person, size: 42, color: appPurple),
              ),
              Text(
                profile,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Local profile • No account',
                style: TextStyle(color: appMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('SWITCH PROFILE', style: TextStyle(color: appMuted)),
        ...['You', 'Guest', 'Family', 'Kids'].map(
          (p) => Card(
            color: appPanel,
            child: ListTile(
              title: Text(p),
              leading: const Icon(Icons.person, color: appPurple),
              trailing: profile == p
                  ? const Icon(Icons.check, color: appPurple)
                  : null,
              onTap: () => onProfile(p),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text('WATCH HISTORY', style: TextStyle(color: appMuted)),
        if (history.isEmpty)
          const Text('No episodes watched yet')
        else
          ...history.map(
            (a) => ListTile(
              title: Text(a.title),
              subtitle: const Text('Recently watched'),
            ),
          ),
        const ListTile(
          leading: Icon(Icons.notifications_outlined, color: appPurple),
          title: Text('Notifications'),
        ),
        const ListTile(
          leading: Icon(Icons.subtitles, color: appPurple),
          title: Text('Subtitles • English'),
        ),
        const ListTile(
          leading: Icon(Icons.headphones, color: appPurple),
          title: Text('Audio • Japanese'),
        ),
      ],
    ),
  );
}
