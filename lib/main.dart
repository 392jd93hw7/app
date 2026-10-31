import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

void main() => runApp(const AniScrollApp());

const bg = Color(0xFF090A12), panel = Color(0xFF151727), purple = Color(0xFF9B70FF), cyan = Color(0xFF61DDF5), muted = Color(0xFF999CB0);
const apiBase = 'http://16.176.100.190:3000';

class Anime {
  const Anime(this.id, this.title, this.image, {this.score='—', this.year='', this.synopsis='', this.genres=const ['Anime']});
  final String id, title, image, score, year, synopsis;
  final List<String> genres;
  factory Anime.fromJson(Map<String,dynamic> j) {
    final t=j['title']; final title=t is Map ? (t['english']??t['romaji']??t['native']??'Anime').toString() : (t??j['name']??j['english']??'Anime').toString();
    final c=j['coverImage']; final image=j['image']??j['poster']??j['cover']??(c is Map ? c['large'] : '')??'';
    return Anime((j['id']??j['anilistId']??title).toString(),title,image.toString(),score:(j['score']??j['averageScore']??'—').toString(),year:(j['year']??j['seasonYear']??'').toString(),synopsis:(j['synopsis']??j['description']??'').toString(),genres:j['genres'] is List ? (j['genres'] as List).map((e)=>e.toString()).toList() : const ['Anime']);
  }
}
const samples = [
 Anime('1','Solo Leveling','https://images.unsplash.com/photo-1578632767115-351597cf2477?w=900',score:'9.2',year:'2024',synopsis:'The weakest hunter discovers a mysterious power that lets him grow stronger without limits.',genres:['Action','Fantasy']),
 Anime('2','Demon Slayer','https://images.unsplash.com/photo-1614583225154-5fc5d9e9d4b3?w=700',score:'8.7',year:'2019',genres:['Action']),
 Anime('3','Jujutsu Kaisen','https://images.unsplash.com/photo-1601850494422-3cf14624b0b3?w=700',score:'8.8',year:'2020',genres:['Action','Supernatural']),
 Anime('4','Attack on Titan','https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=700',score:'9.1',year:'2013',genres:['Drama','Action']),
 Anime('5','Frieren','https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=700',score:'9.4',year:'2023',genres:['Adventure','Fantasy']),
 Anime('6','One Piece','https://images.unsplash.com/photo-1518709594023-6eab9bab7b23?w=700',score:'9.0',year:'1999',genres:['Adventure']),
];

class Api {
 static Future<dynamic> get(String path) async {
  final c=HttpClient()..connectionTimeout=const Duration(seconds:8);
  try { final q=await c.getUrl(Uri.parse('$apiBase$path')); q.headers.set(HttpHeaders.acceptHeader,'application/json'); final r=await q.close().timeout(const Duration(seconds:10)); final b=await r.transform(utf8.decoder).join(); if(r.statusCode<200||r.statusCode>299) throw HttpException('HTTP ${r.statusCode}'); return jsonDecode(b); } finally { c.close(force:true); }
 }
 static Future<List<Anime>> search(String s) async {
  final d=await get('/api/search?q=${Uri.encodeQueryComponent(s)}'); final list=d is List?d:d is Map?(d['results']??d['data']??d['animes']??[]):[];
  return list is List?list.whereType<Map>().map((e)=>Anime.fromJson(Map<String,dynamic>.from(e))).toList():[];
 }
}

class AniScrollApp extends StatelessWidget {
 const AniScrollApp({super.key});
 @override Widget build(BuildContext context)=>MaterialApp(title:'AniScroll',debugShowCheckedModeBanner:false,theme:ThemeData(brightness:Brightness.dark,scaffoldBackgroundColor:bg,colorScheme:const ColorScheme.dark(primary:purple,secondary:cyan,surface:panel),useMaterial3:true),home:const Shell());
}
class Shell extends StatefulWidget { const Shell({super.key}); @override State<Shell> createState()=>_ShellState(); }
class _ShellState extends State<Shell> {
 int tab=0; final saved=<Anime>[]; final history=<Anime>[]; String profile='You';
 void toggle(Anime a) { setState(() { if (saved.any((x)=>x.id==a.id)) { saved.removeWhere((x)=>x.id==a.id); } else { saved.add(a); } }); }
 void open(Anime a)=>Navigator.push(context,MaterialPageRoute(builder:(_)=>Detail(a:a,saved:saved.any((x)=>x.id==a.id),toggle:()=>toggle(a),play:(n){if(!history.any((x)=>x.id==a.id))setState(()=>history.insert(0,a));Navigator.push(context,MaterialPageRoute(builder:(_)=>Player(a:a,episode:n)));})));
 @override Widget build(BuildContext context) {
  final pages=[Home(open:open,history:history),Discover(open:open),const Schedule(),Watchlist(items:saved,open:open,remove:toggle),Profile(profile:profile,history:history,change:(s)=>setState(()=>profile=s))];
  return Scaffold(body:IndexedStack(index:tab,children:pages),bottomNavigationBar:NavigationBar(height:68,backgroundColor:const Color(0xFF10111C),indicatorColor:purple.withValues(alpha:.2),selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:const [
   NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Home'),NavigationDestination(icon:Icon(Icons.explore_outlined),selectedIcon:Icon(Icons.explore),label:'Discover'),NavigationDestination(icon:Icon(Icons.calendar_month_outlined),selectedIcon:Icon(Icons.calendar_month),label:'Schedule'),NavigationDestination(icon:Icon(Icons.bookmark_border),selectedIcon:Icon(Icons.bookmark),label:'Watchlist'),NavigationDestination(icon:Icon(Icons.person_outline),selectedIcon:Icon(Icons.person),label:'Profile')]));
 }
}

class Home extends StatelessWidget {
 const Home({super.key,required this.open,required this.history}); final ValueChanged<Anime> open; final List<Anime> history;
 @override Widget build(BuildContext context)=>SafeArea(child:CustomScrollView(slivers:[
  SliverToBoxAdapter(child:Padding(padding:const EdgeInsets.fromLTRB(20,14,20,15),child:Row(children:[Container(width:38,height:38,decoration:BoxDecoration(borderRadius:BorderRadius.circular(13),gradient:const LinearGradient(colors:[purple,cyan])),child:const Icon(Icons.play_arrow_rounded)),const SizedBox(width:10),const Text('Ani',style:TextStyle(fontSize:23,fontWeight:FontWeight.w900)),const Text('Scroll',style:TextStyle(fontSize:23,fontWeight:FontWeight.w900,color:purple)),const Spacer(),const Icon(Icons.notifications_none),const SizedBox(width:12),const CircleAvatar(radius:16,child:Icon(Icons.person,size:18))]))),
  SliverToBoxAdapter(child:Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:GestureDetector(onTap:()=>open(samples.first),child:ClipRRect(borderRadius:BorderRadius.circular(24),child:SizedBox(height:330,child:Stack(fit:StackFit.expand,children:[Cover(samples.first.image),const DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Colors.transparent,bg],stops:[.25,1]))),Positioned(left:20,bottom:22,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Chip(label:Text('✦ FEATURED'),backgroundColor:panel),const Text('Solo Leveling',style:TextStyle(fontSize:31,fontWeight:FontWeight.w900)),const Text('ACTION • FANTASY    ★ 9.2',style:TextStyle(color:Colors.white70)),const SizedBox(height:12),FilledButton.icon(onPressed:()=>open(samples.first),icon:const Icon(Icons.play_arrow),label:const Text('Explore anime'))]))])))))),
  if(history.isNotEmpty) SliverToBoxAdapter(child:Section(title:'Continue watching',action:'History',child:Horizontal(items:history,open:open))),
  SliverToBoxAdapter(child:Section(title:'Trending now',action:'See all',child:Horizontal(items:samples,open:open))),
  SliverToBoxAdapter(child:Section(title:'Popular this season',action:'Explore',child:Horizontal(items:samples.reversed.toList(),open:open))),
  SliverToBoxAdapter(child:Section(title:'Made for you',action:'Refresh',child:Horizontal(items:samples.take(4).toList(),open:open))),
  const SliverToBoxAdapter(child:SizedBox(height:22))
 ]));
}

class Discover extends StatefulWidget { const Discover({super.key,required this.open}); final ValueChanged<Anime> open; @override State<Discover> createState()=>_DiscoverState(); }
class _DiscoverState extends State<Discover> {
 final c=TextEditingController(); Timer? timer; List<Anime> results=samples; bool loading=false; String? note; String genre='All';
 void search(String s){timer?.cancel();if(s.trim().isEmpty){setState(()=>results=samples);return;}timer=Timer(const Duration(milliseconds:400),()async{setState(()=>loading=true);try{final r=await Api.search(s);if(mounted)setState(() { results=r; loading=false; note=null; });}catch(_){if(mounted)setState(() { results=samples.where((a)=>a.title.toLowerCase().contains(s.toLowerCase())).toList(); loading=false; note='API unavailable — showing local suggestions.'; });}});}
 @override void dispose(){timer?.cancel();c.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>SafeArea(child:Column(children:[
  const Padding(padding:EdgeInsets.fromLTRB(20,18,20,12),child:Align(alignment:Alignment.centerLeft,child:Text('Discover',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900)))),
  Padding(padding:const EdgeInsets.symmetric(horizontal:18),child:TextField(controller:c,onChanged:search,decoration:InputDecoration(hintText:'Search anime, genres, characters…',prefixIcon:const Icon(Icons.search,color:purple),filled:true,fillColor:panel,border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:BorderSide.none)))),
  SizedBox(height:48,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.all(8),children:['All','Action','Adventure','Fantasy','Romance','Comedy','Drama'].map((g)=>Padding(padding:const EdgeInsets.only(right:7),child:ChoiceChip(label:Text(g),selected:genre==g,onSelected:(_)=>setState(() { genre=g; results=g=='All'?samples:results.where((a)=>a.genres.any((x)=>x.toLowerCase()==g.toLowerCase())).toList(); }),selectedColor:purple.withValues(alpha:.25),backgroundColor:panel,side:BorderSide.none))).toList())),
  if(loading) const LinearProgressIndicator(color:purple),if(note!=null) Text(note!,style:const TextStyle(color:muted,fontSize:11)),
  Expanded(child:results.isEmpty?const Center(child:Text('No anime found.')):GridView.builder(padding:const EdgeInsets.all(15),gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,childAspectRatio:.62,crossAxisSpacing:13,mainAxisSpacing:13),itemCount:results.length,itemBuilder:(_,i)=>Poster(a:results[i],open:()=>widget.open(results[i]))))
 ]));
}

class Detail extends StatefulWidget { const Detail({super.key,required this.a,required this.saved,required this.toggle,required this.play}); final Anime a; final bool saved; final VoidCallback toggle; final ValueChanged<int> play; @override State<Detail> createState()=>_DetailState(); }
class _DetailState extends State<Detail> { bool saved=false; String status=''; @override void initState(){super.initState();saved=widget.saved; if(RegExp(r'^\d+$').hasMatch(widget.a.id)) Api.get('/api/info?anilistId=${widget.a.id}').then((_){if(mounted)setState(()=>status='Metadata API connected.');}).catchError((_){if(mounted)setState(()=>status='Using available title information.');});}
 @override Widget build(BuildContext context)=>Scaffold(body:CustomScrollView(slivers:[
  SliverAppBar(expandedHeight:340,pinned:true,actions:[IconButton(onPressed:()=>setState(() { saved=!saved; widget.toggle(); }),icon:Icon(saved?Icons.bookmark:Icons.bookmark_border,color:purple))],flexibleSpace:FlexibleSpaceBar(background:Stack(fit:StackFit.expand,children:[Cover(widget.a.image),const DecoratedBox(decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Colors.transparent,bg],stops:[.3,1]))),Positioned(left:20,bottom:22,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(widget.a.year.isEmpty?'FEATURED':widget.a.year,style:const TextStyle(color:cyan)),Text(widget.a.title,style:const TextStyle(fontSize:29,fontWeight:FontWeight.w900)),Text('★ ${widget.a.score}',style:const TextStyle(color:Colors.white70))]))]))),
  SliverToBoxAdapter(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Row(children:[Expanded(child:FilledButton.icon(onPressed:()=>widget.play(1),icon:const Icon(Icons.play_arrow),label:const Text('Watch episode 1'))),const SizedBox(width:9),OutlinedButton.icon(onPressed:()=>setState(() { saved=!saved; widget.toggle(); }),icon:Icon(saved?Icons.check:Icons.add),label:Text(saved?'Saved':'Watchlist'))]),
   if(status.isNotEmpty)Text(status,style:const TextStyle(color:muted,fontSize:11)),
   const SizedBox(height:22),const Text('Synopsis',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),const SizedBox(height:8),Text(widget.a.synopsis.isEmpty?'Connect metadata providers to load the complete synopsis, cast, staff and franchise information.':widget.a.synopsis,style:const TextStyle(color:muted,height:1.5)),
   const SizedBox(height:12),Wrap(spacing:7,children:widget.a.genres.map((g)=>Chip(label:Text(g),backgroundColor:panel,side:BorderSide.none)).toList()),
   const SizedBox(height:22),const Text('Episodes',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),const SizedBox(height:10),
   ...List.generate(12,(i)=>Card(color:panel,child:ListTile(onTap:()=>widget.play(i+1),leading:CircleAvatar(backgroundColor:bg,child:Text('${i+1}',style:const TextStyle(color:purple))),title:Text('Episode ${i+1}'),subtitle:const Text('Episode details supplied by source API'),trailing:const Icon(Icons.play_circle_outline,color:purple)))),
   const SizedBox(height:18),const Text('More details',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const Text('AniList, MAL, Kitsu, characters, voice actors and related titles appear when returned by metadata sources.',style:TextStyle(color:muted))
  ])))
 ]));}
class Player extends StatelessWidget { const Player({super.key,required this.a,required this.episode}); final Anime a; final int episode;
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:Colors.black,appBar:AppBar(backgroundColor:Colors.black,title:Text(a.title)),body:Column(children:[const Expanded(child:Center(child:Padding(padding:EdgeInsets.all(28),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(Icons.play_circle_outline,size:76,color:purple),SizedBox(height:16),Text('AniScroll Player',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),SizedBox(height:10),Text('Player interface foundation. Real playback needs a provider stream URL and native HLS/MP4 integration, subtitles, audio tracks and PiP.',textAlign:TextAlign.center,style:TextStyle(color:muted,height:1.5))])))),Padding(padding:const EdgeInsets.all(18),child:Row(children:[IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.skip_previous)),const Expanded(child:LinearProgressIndicator(value:0,color:purple)),IconButton(onPressed:(){},icon:const Icon(Icons.skip_next)),IconButton(onPressed:(){},icon:const Icon(Icons.subtitles)),IconButton(onPressed:(){},icon:const Icon(Icons.settings))]))]));
}

class Schedule extends StatefulWidget { const Schedule({super.key}); @override State<Schedule> createState()=>_ScheduleState(); }
class _ScheduleState extends State<Schedule>{int day=DateTime.now().weekday-1;String filter='Upcoming';@override Widget build(BuildContext context)=>SafeArea(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 const Padding(padding:EdgeInsets.all(20),child:Text('Release schedule',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900))),
 SizedBox(height:72,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:12),children:List.generate(7,(i)=>GestureDetector(onTap:()=>setState(() { day=i; }),child:Container(width:53,margin:const EdgeInsets.all(4),decoration:BoxDecoration(color:day==i?purple.withValues(alpha:.2):panel,borderRadius:BorderRadius.circular(14),border:Border.all(color:day==i?purple:Colors.transparent)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text(['MON','TUE','WED','THU','FRI','SAT','SUN'][i],style:const TextStyle(color:muted,fontSize:10)),Text('${i+1}',style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold))]))))),
 Padding(padding:const EdgeInsets.all(12),child:SegmentedButton<String>(segments:const[ButtonSegment(value:'Upcoming',label:Text('Upcoming')),ButtonSegment(value:'Aired Today',label:Text('Aired')),ButtonSegment(value:'My Anime',label:Text('My anime'))],selected:{filter},onSelectionChanged:(s)=>setState(()=>filter=s.first),showSelectedIcon:false)),
 const Padding(padding:EdgeInsets.fromLTRB(20,10,20,8),child:Text('ON THE TIMELINE',style:TextStyle(color:muted,letterSpacing:1.5,fontSize:10))),
 Expanded(child:ListView(padding:const EdgeInsets.all(16),children:[_ScheduleTile('17:00',samples[1],'Episode 8'),_ScheduleTile('18:30',samples[2],'Episode 4'),_ScheduleTile('20:00',samples[4],'Episode 12'),_ScheduleTile('22:15',samples[0],'New episode'),const Text('Sample schedule entries — connect a live airing-calendar source for real release times.',style:TextStyle(color:muted,fontSize:11))]))
 ]));}
class Watchlist extends StatelessWidget {const Watchlist({super.key,required this.items,required this.open,required this.remove});final List<Anime> items;final ValueChanged<Anime> open,remove;@override Widget build(BuildContext context)=>SafeArea(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Padding(padding:EdgeInsets.fromLTRB(20,20,20,5),child:Text('My watchlist',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900))),Padding(padding:const EdgeInsets.symmetric(horizontal:20,vertical:8),child:Text('${items.length} titles saved',style:const TextStyle(color:muted))),Expanded(child:items.isEmpty?const Empty(icon:Icons.bookmark_border,title:'Your list is waiting',message:'Save anime from its detail page to see it here.'):GridView.builder(padding:const EdgeInsets.all(15),gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,childAspectRatio:.62,crossAxisSpacing:13,mainAxisSpacing:13),itemCount:items.length,itemBuilder:(_,i)=>Poster(a:items[i],open:()=>open(items[i]),long:()=>remove(items[i]))))]));}
class Profile extends StatelessWidget {const Profile({super.key,required this.profile,required this.history,required this.change});final String profile;final List<Anime> history;final ValueChanged<String> change;@override Widget build(BuildContext context)=>SafeArea(child:ListView(padding:const EdgeInsets.all(20),children:[
 const Text('Your profile',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900)),const SizedBox(height:20),Center(child:Column(children:[const CircleAvatar(radius:40,backgroundColor:panel,child:Icon(Icons.person,size:42,color:purple)),const SizedBox(height:9),Text(profile,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),const Text('Local profile • No account',style:TextStyle(color:muted,fontSize:11))])),
 const SizedBox(height:24),const Text('SWITCH PROFILE',style:TextStyle(color:muted,fontSize:10,letterSpacing:1.5)),const SizedBox(height:9),
 ...['You','Guest','Family','Kids'].map((p)=>Card(color:panel,child:ListTile(leading:const Icon(Icons.person,color:purple),title:Text(p),trailing:profile==p?const Icon(Icons.check_circle,color:purple):null,onTap:()=>change(p)))),
 const SizedBox(height:20),const Text('WATCH HISTORY',style:TextStyle(color:muted,fontSize:10,letterSpacing:1.5)),if(history.isEmpty)const Text('No episodes watched yet.',style:TextStyle(color:muted))else ...history.map((a)=>ListTile(title:Text(a.title),subtitle:const Text('Recently watched'))),
 const SizedBox(height:16),const ListTile(leading:Icon(Icons.notifications_outlined,color:purple),title:Text('Notifications'),subtitle:Text('Watchlist and new episode alerts')),const ListTile(leading:Icon(Icons.subtitles,color:purple),title:Text('Subtitles'),subtitle:Text('Preferred language: English')),const ListTile(leading:Icon(Icons.headphones,color:purple),title:Text('Audio language'),subtitle:Text('Preferred language: Japanese')),const ListTile(leading:Icon(Icons.info_outline,color:purple),title:Text('About AniScroll'))
 ]));}

class Section extends StatelessWidget {const Section({super.key,required this.title,required this.action,required this.child});final String title,action;final Widget child;@override Widget build(BuildContext context)=>Column(children:[Padding(padding:const EdgeInsets.fromLTRB(20,22,18,12),child:Row(children:[Expanded(child:Text(title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800))),Text(action,style:const TextStyle(color:purple,fontSize:11))])),child]);}
class Horizontal extends StatelessWidget {const Horizontal({super.key,required this.items,required this.open});final List<Anime> items;final ValueChanged<Anime> open;@override Widget build(BuildContext context)=>SizedBox(height:220,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:16),children:items.map((a)=>SizedBox(width:126,child:Padding(padding:const EdgeInsets.only(right:12),child:Poster(a:a,open:()=>open(a)))).toList()));}
class Poster extends StatelessWidget {const Poster({super.key,required this.a,required this.open,this.long});final Anime a;final VoidCallback open;final VoidCallback? long;@override Widget build(BuildContext context)=>GestureDetector(onTap:open,onLongPress:long,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(14),child:Stack(fit:StackFit.expand,children:[Cover(a.image),Positioned(top:7,right:7,child:Chip(label:Text('★ ${a.score}',style:const TextStyle(fontSize:9)),visualDensity:VisualDensity.compact,backgroundColor:panel))]))),const SizedBox(height:7),Text(a.title,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:13)),Text(a.year,maxLines:1,style:const TextStyle(color:muted,fontSize:10))]));}
class Cover extends StatelessWidget {const Cover(this.url,{super.key});final String url;@override Widget build(BuildContext context)=>url.startsWith('http')?Image.network(url,fit:BoxFit.cover,width:double.infinity,errorBuilder:(_,__,___)=>const CoverFallback()):const CoverFallback();}
class CoverFallback extends StatelessWidget {const CoverFallback({super.key});@override Widget build(BuildContext context)=>Container(color:panel,child:const Center(child:Icon(Icons.movie_outlined,color:purple,size:35)));}
class _ScheduleTile extends StatelessWidget {const _ScheduleTile(this.time,this.a,this.ep);final String time,ep;final Anime a;@override Widget build(BuildContext context)=>Card(color:panel,child:ListTile(leading:Text(time,style:const TextStyle(color:cyan,fontWeight:FontWeight.bold)),title:Text(a.title),subtitle:Text(ep,style:const TextStyle(color:muted)),trailing:const Icon(Icons.notifications_none)));}
class Empty extends StatelessWidget {const Empty({super.key,required this.icon,required this.title,required this.message});final IconData icon;final String title,message;@override Widget build(BuildContext context)=>Center(child:Padding(padding:const EdgeInsets.all(30),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,size:54,color:purple),const SizedBox(height:14),Text(title,style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold)),const SizedBox(height:7),Text(message,textAlign:TextAlign.center,style:const TextStyle(color:muted))])));}
