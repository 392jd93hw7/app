class Anime {
 const Anime(this.id,this.title,this.image,{this.score='—',this.year='',this.synopsis='',this.genres=const ['Anime']});
 final String id,title,image,score,year,synopsis; final List<String> genres;
 factory Anime.fromJson(Map<String,dynamic> j){
  final t=j['title']; final name=t is Map?(t['english']??t['romaji']??t['native']??'Anime').toString():(t??j['name']??'Anime').toString();
  final cover=j['coverImage']; final img=j['image']??j['poster']??j['cover']??(cover is Map?cover['large']:'')??'';
  return Anime((j['id']??j['anilistId']??name).toString(),name,img.toString(),score:(j['score']??j['averageScore']??'—').toString(),year:(j['year']??j['seasonYear']??'').toString(),synopsis:(j['synopsis']??j['description']??'').toString(),genres:j['genres'] is List?(j['genres'] as List).map((e)=>e.toString()).toList():const ['Anime']);
 }
}
