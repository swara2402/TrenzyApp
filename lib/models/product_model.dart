class ProductModel {
  final String id; final String name; final String? title; final String? brand; final String? category;
  final String? imageUrl; final double? price; final double? rating; final int? matchScore; final String? reason;
  final Map<String,dynamic> affiliateLinks; final String? gradient; final String? silhouetteColor;
  const ProductModel({required this.id,required this.name,this.title,this.brand,this.category,this.imageUrl,this.price,this.rating,this.matchScore,this.reason,this.affiliateLinks=const {},this.gradient,this.silhouetteColor});
  factory ProductModel.fromJson(Map<String,dynamic> j){
    double? n(dynamic v)=>v is num?v.toDouble():double.tryParse(v?.toString()??'');
    return ProductModel(id:j['id']?.toString()??'',name:(j['name']??j['title']??'').toString(),title:j['title']?.toString(),brand:j['brand']?.toString(),category:j['category']?.toString(),imageUrl:(j['image_url']??j['imageUrl'])?.toString(),price:n(j['price']),rating:n(j['rating']),matchScore:j['matchScore'] is num?(j['matchScore'] as num).round():int.tryParse(j['matchScore']?.toString()??''),reason:j['reason']?.toString(),affiliateLinks:j['affiliate_links'] is Map?Map<String,dynamic>.from(j['affiliate_links']):const {},gradient:j['gradient']?.toString(),silhouetteColor:j['silhouetteColor']?.toString());
  }
  String get effectiveBrand=>brand??''; String get effectivePrice=>price==null?'':'₹${price!.toStringAsFixed(0)}';
}