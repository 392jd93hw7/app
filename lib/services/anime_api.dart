import 'dart:convert'; import 'dart:io'; import '../models/anime.dart';
class AnimeApi {
 static const baseUrl='http://16.176.100.190:3000';
 static Future<dynamic> get(String path) async {final c=HttpClient()..connectionTimeout=const Duration(seconds:8);try{final q=await c.getUrl(Uri.parse('$baseUrl$path'));q.headers.set(HttpHeaders.acceptHeader,'application/json');final r=await q.close().timeout(const Duration(seconds:10));final b=await r.transform(utf8.decoder).join();if(r.statusCode<200||r.statusCode>299)throw HttpException('HTTP ${r.statusCode}');return jsonDecode(b);}finally{c.close(force:true);}}
 static Future<List<Anime>> search(String q) async {final d=await get('/api/search?q=${Uri.encodeQueryComponent(q)}');final l=d is List?d:d is Map?(d['results']??d['data']??d['animes']??[]):[];return l is List?l.whereType<Map>().map((e)=>Anime.fromJson(Map<String,dynamic>.from(e))).toList():[];}
}
