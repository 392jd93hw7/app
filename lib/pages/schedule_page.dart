import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/anime_api.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});
  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  late Future<List<dynamic>> _future;
  int selectedDay = DateTime.now().weekday - 1;
  String selectedTab = 'Upcoming';
  static const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  @override
  void initState() {
    super.initState();
    _future = AnimeApi.airingSchedule();
  }

  DateTime get _selectedDate {
    final today = DateTime.now();
    final monday = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - 1));
    return monday.add(Duration(days: selectedDay));
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 22, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Schedule',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 4),
              Text(
                'Airing times shown in your local timezone.',
                style: TextStyle(color: Colors.white60),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 76,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: 7,
            itemBuilder: (context, index) {
              final date = DateTime.now().subtract(
                Duration(days: DateTime.now().weekday - 1 - index),
              );
              final selected = selectedDay == index;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: () => setState(() => selectedDay = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 54,
                    decoration: BoxDecoration(
                      color: selected
                          ? appPurple.withValues(alpha: .22)
                          : appPanel,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: selected ? appPurple : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          weekdays[index],
                          style: TextStyle(
                            fontSize: 11,
                            color: selected ? Colors.white : Colors.white60,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${date.day}',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Upcoming', label: Text('Upcoming')),
                ButtonSegment(value: 'Aired', label: Text('Aired')),
                ButtonSegment(value: 'Mine', label: Text('My anime')),
              ],
              selected: {selectedTab},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: appPurple.withValues(alpha: .24),
                selectedForegroundColor: Colors.white,
                foregroundColor: appMuted,
                side: const BorderSide(color: appPurple),
              ),
              onSelectionChanged: (v) => setState(() => selectedTab = v.first),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: appPurple),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Schedule data unavailable: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: appMuted),
                    ),
                  ),
                );
              }
              if (selectedTab == 'Mine') {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Add anime to your watchlist to build your personal schedule. Personal schedule filtering is coming next.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: appMuted),
                    ),
                  ),
                );
              }
              final start = DateTime(
                _selectedDate.year,
                _selectedDate.month,
                _selectedDate.day,
              );
              final end = start.add(const Duration(days: 1));
              final now = DateTime.now();
              final airing =
                  (snapshot.data ?? []).where((entry) {
                    if (entry is! Map) return false;
                    final stamp = int.tryParse('${entry['airingAt'] ?? ''}');
                    if (stamp == null) return false;
                    final local = DateTime.fromMillisecondsSinceEpoch(
                      stamp * 1000,
                    ).toLocal();
                    final sameDay =
                        !local.isBefore(start) && local.isBefore(end);
                    return sameDay &&
                        (selectedTab == 'Upcoming'
                            ? local.isAfter(now)
                            : !local.isAfter(now));
                  }).toList()..sort(
                    (a, b) => (int.tryParse('${a['airingAt']}') ?? 0).compareTo(
                      int.tryParse('${b['airingAt']}') ?? 0,
                    ),
                  );

              if (airing.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No ${selectedTab.toLowerCase()} episodes found for this day.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: appMuted),
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: airing.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final item = airing[i] as Map;
                  final stamp = int.tryParse('${item['airingAt']}') ?? 0;
                  final local = DateTime.fromMillisecondsSinceEpoch(
                    stamp * 1000,
                  ).toLocal();
                  final media = item['media'] is Map
                      ? item['media'] as Map
                      : const {};
                  final titleValue = media['title'];
                  final title = titleValue is Map
                      ? (titleValue['english'] ??
                                titleValue['romaji'] ??
                                titleValue['userPreferred'] ??
                                'Anime')
                            .toString()
                      : 'Anime';
                  return Card(
                    color: appPanel,
                    child: ListTile(
                      leading: Text(
                        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: appPurple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      title: Text(title),
                      subtitle: Text(
                        'Episode ${item['episode'] ?? '?'} • local time',
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}
