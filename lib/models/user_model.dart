class UserModel {
  final String id,name; final String? email,avatarUrl,bio; final bool? isFollowing;
  final bool ageVerified; final bool isMinor;
  const UserModel({required this.id,required this.name,this.email,this.avatarUrl,this.bio,this.isFollowing,this.ageVerified=false,this.isMinor=false});
  factory UserModel.fromJson(Map<String,dynamic> j)=>UserModel(
    id:(j['id']??j['firebase_uid']??j['firebaseUid']??'').toString(),
    name:(j['name']??j['display_name']??'User').toString(),
    email:j['email']?.toString(),
    avatarUrl:(j['avatar_url']??j['avatarUrl']??j['photo_url'])?.toString(),
    bio:j['bio']?.toString(),
    isFollowing:j['isFollowing'] is bool?j['isFollowing']:null,
    ageVerified:j['ageVerified'] == true,
    isMinor:j['isMinor'] == true,
  );
}