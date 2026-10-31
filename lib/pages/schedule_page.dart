import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/anime_api.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});
  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  late Future<dynamic> _future;
  int selectedDay = DateTime.now().weekday - 1;
  String selectedTab = 'Upcoming';
  static const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  @override
  void initState() { super.initState(); _future = AnimeApi.season(); }
  @override
  Widget build(BuildContext context) => SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Padding(padding: EdgeInsets.fromLTRB(20, 22, 20, 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Schedule', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
      SizedBox(height: 4),
      Text('Airing data supplied by the anime API.', style: TextStyle(color: Colors.white60)),
    ])),
    SizedBox(height: 76, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 14), itemCount: 7, itemBuilder: (context, index) {
      final date = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1 - index));
      final selected = selectedDay == index;
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: InkWell(borderRadius: BorderRadius.circular(15), onTap: () => setState(() => selectedDay = index), child: AnimatedContainer(duration: const Duration(milliseconds: 180), width: 54, decoration: BoxDecoration(color: selected ? appPurple.withValues(alpha: .22) : appPanel, borderRadius: BorderRadius.circular(15), border: Border.all(color: selected ? appPurple : Colors.transparent)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(weekdays[index], style: TextStyle(fontSize: 11, color: selected ? Colors.white : Colors.white60, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5), Text('${date.day}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
      ]))));
    })),
    Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 10), child: SizedBox(width: double.infinity, child: SegmentedButton<String>(
      segments: const [ButtonSegment(value: 'Upcoming', label: Text('Upcoming')), ButtonSegment(value: 'Aired', label: Text('Aired today')), ButtonSegment(value: 'Mine', label: Text('My anime'))],
      selected: {selectedTab}, showSelectedIcon: false, onSelectionChanged: (v) => setState(() => selectedTab = v.first),
    ))),
    Expanded(child: FutureBuilder<dynamic>(future: _future, builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: appPurple));
      if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Schedule data unavailable: ${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: appMuted))));
      final entries = AnimeApi.extractList(snapshot.data);
      final weekday = selectedDay + 1;
      final airing = entries.where((e) {
        if (e is! Map) return false;
        final next = e['nextAiringEpisode'] ?? e['next_airing_episode'];
        if (next is! Map) return false;
        final timestamp = int.tryParse((next['airingAt'] ?? next['airing_at'] ?? '').toString());
        if (timestamp == null) return false;
        return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000).toLocal().weekday == weekday;
      }).toList();
      if (airing.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('The API did not return confirmed airing times for this day. No times have been guessed.', textAlign: TextAlign.center, style: TextStyle(color: appMuted))));
      airing.sort((a, b) {
        int stamp(dynamic e) => int.tryParse(((e as Map)['nextAiringEpisode'] ?? e['next_airing_episode'])['airingAt'].toString()) ?? 0;
        return stamp(a).compareTo(stamp(b));
      });
      return ListView.separated(padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), itemCount: airing.length, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (context, i) {
        final item = airing[i] as Map;
        final next = (item['nextAiringEpisode'] ?? item['next_airing_episode']) as Map;
        final stamp = int.tryParse((next['airingAt'] ?? next['airing_at']).toString()) ?? 0;
        final local = DateTime.fromMillisecondsSinceEpoch(stamp * 1000).toLocal();
        final titleValue = item['title'];
        final title = titleValue is Map ? (titleValue['english'] ?? titleValue['romaji'] ?? 'Anime').toString() : (titleValue ?? item['name'] ?? 'Anime').toString();
        return Card(color: appPanel, child: ListTile(leading: Text('${local.hour.toString().padLeft(2,'0')}:${local.minute.toString().padLeft(2,'0')}', style: const TextStyle(color: appCyan, fontWeight: FontWeight.bold)), title: Text(title), subtitle: Text('Episode ${next['episode'] ?? '?'} • local time')));
      });
    })),
  ]));
}
