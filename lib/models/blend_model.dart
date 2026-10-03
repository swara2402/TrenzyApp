import 'product_model.dart';
class BlendGroup {
  final String id,name,inviteCode; final List<dynamic> members;
  const BlendGroup({required this.id,required this.name,required this.inviteCode,required this.members});
  factory BlendGroup.fromJson(Map<String,dynamic> j)=>BlendGroup(id:(j['id']??j['groupId']??'').toString(),name:(j['name']??'').toString(),inviteCode:(j['inviteCode']??j['invite_code']??'').toString(),members:j['members'] is List?List<dynamic>.from(j['members']):const[]);
}
class BlendRankedProduct {
  final ProductModel product; final double score; final int loveCount,likeCount; final int? matchScore;
  const BlendRankedProduct({required this.product,required this.score,this.loveCount=0,this.likeCount=0,this.matchScore});
  factory BlendRankedProduct.fromJson(Map<String,dynamic> j){final p=j['product'] is Map?Map<String,dynamic>.from(j['product']):<String,dynamic>{};return BlendRankedProduct(product:ProductModel.fromJson(p),score:(j['score'] as num?)?.toDouble()??0,loveCount:(j['loveCount'] as num?)?.toInt()??0,likeCount:(j['likeCount'] as num?)?.toInt()??0,matchScore:p['matchScore'] is num?(p['matchScore'] as num).toInt():null);}
}
class BlendCategoryWinner {
  final List<BlendRankedProduct> products; final bool isTie; final double score;
  const BlendCategoryWinner({required this.products,this.isTie=false,this.score=0});
  factory BlendCategoryWinner.fromJson(Map<String,dynamic> j)=>BlendCategoryWinner(products:(j['products'] as List? ?? const[]).map((e)=>BlendRankedProduct.fromJson(Map<String,dynamic>.from(e))).toList(),isTie:j['isTie']==true,score:(j['score'] as num?)?.toDouble()??0);
}
class BlendResults {
  final String groupId,groupName; final Map<String,List<BlendRankedProduct>> recommendations; final List<BlendCategoryWinner> winners; final List<BlendRankedProduct> overallWinners; final List<dynamic> wardrobeOverlap; final List<String> sharedBrands,sharedColours,sharedStyles;
  const BlendResults({required this.groupId,required this.groupName,required this.recommendations,required this.winners,this.overallWinners=const[],this.wardrobeOverlap=const[],this.sharedBrands=const[],this.sharedColours=const[],this.sharedStyles=const[]});
  factory BlendResults.fromJson(Map<String,dynamic> j){
    final rec=<String,List<BlendRankedProduct>>{}; final raw=j['blendRecommendations']??j['recommendations'];
    if(raw is Map){for(final e in raw.entries){final list=e.value is List?e.value as List:const[];rec[e.key.toString()]=list.map((x)=>BlendRankedProduct.fromJson(Map<String,dynamic>.from(x))).toList();}}
    final wins=<BlendCategoryWinner>[]; final rw=j['winners']; if(rw is Map){for(final e in rw.entries){wins.add(BlendCategoryWinner.fromJson(Map<String,dynamic>.from(e.value)));}}
    return BlendResults(groupId:(j['groupId']??j['group_id']??'').toString(),groupName:(j['groupName']??j['group_name']??'').toString(),recommendations:rec,winners:wins,overallWinners:j['overallWinner'] is Map?[BlendRankedProduct.fromJson(Map<String,dynamic>.from(j['overallWinner']))]:const[],wardrobeOverlap:j['wardrobeOverlap'] is List?List<dynamic>.from(j['wardrobeOverlap']):const[],sharedBrands:(j['sharedBrands'] as List? ?? const[]).map((e)=>e.toString()).toList(),sharedColours:(j['sharedColours'] as List? ?? const[]).map((e)=>e.toString()).toList(),sharedStyles:(j['sharedStyles'] as List? ?? const[]).map((e)=>e.toString()).toList());
  }
}