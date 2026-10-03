class FeedItem {
  final String id,title,description,imageUrl; final String? type;
  const FeedItem({required this.id,required this.title,required this.description,required this.imageUrl,this.type});
  factory FeedItem.fromJson(Map<String,dynamic> j)=>FeedItem(id:(j['id']??'').toString(),title:(j['title']??j['name']??'').toString(),description:(j['description']??j['content']??'').toString(),imageUrl:(j['image_url']??j['imageUrl']??'').toString(),type:j['type']?.toString());
}