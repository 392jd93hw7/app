import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/sample_anime.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  int selectedDay = DateTime.now().weekday - 1;
  String selectedTab = 'Upcoming';

  static const _weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const _releaseTimes = ['17:00', '18:30', '20:00', '22:15'];

  @override
  Widget build(BuildContext context) {
    final anime = sampleAnime.take(4).toList();

    return SafeArea(
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
                  'Keep up with the latest episodes.',
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
                final isSelected = selectedDay == index;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () => setState(() => selectedDay = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 54,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? appPurple.withValues(alpha: 0.22)
                            : appPanel,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isSelected ? appPurple : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _weekdays[index],
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected ? Colors.white : Colors.white60,
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
                  ButtonSegment(
                    value: 'Upcoming',
                    label: Text('Upcoming'),
                  ),
                  ButtonSegment(
                    value: 'Aired',
                    label: Text('Aired today'),
                  ),
                  ButtonSegment(
                    value: 'Mine',
                    label: Text('My anime'),
                  ),
                ],
                selected: {selectedTab},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  setState(() => selectedTab = selection.first);
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Text(
                  '${_weekdays[selectedDay]} RELEASES',
                  style: const TextStyle(
                    color: appCyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const Spacer(),
                const Text(
                  'Times shown locally',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          Expanded(
            child: anime.isEmpty
                ? const Center(child: Text('No scheduled episodes yet.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: anime.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = anime[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: appPanel,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          leading: Container(
                            width: 58,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: appPurple.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _releaseTimes[index],
                              style: const TextStyle(
                                color: appCyan,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          title: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            'Episode ${index + 1}',
                            style: const TextStyle(color: Colors.white60),
                          ),
                          trailing: const Icon(
                            Icons.notifications_none_rounded,
                            color: Colors.white60,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
