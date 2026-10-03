class UserModel {
  final String id,name; final String? email,avatarUrl,bio; final bool? isFollowing;
  final bool ageVerified; final bool isMinor;
  const UserModel({required this.id,required this.name,this.email,this.avatarUrl,this.bio,this.isFollowing,this.ageVerified=false,this.isMinor=false});
  factory UserModel.fromFirebase({
    required String uid,
    required String name,
    required String email,
  }) => UserModel(id: uid, name: name, email: email);

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    String? bio,
    bool? isFollowing,
    bool? ageVerified,
    bool? isMinor,
    bool clearEmail = false,
    bool clearAvatarUrl = false,
    bool clearBio = false,
  }) => UserModel(
    id: id ?? this.id,
    name: name ?? this.name,
    email: clearEmail ? null : (email ?? this.email),
    avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
    bio: clearBio ? null : (bio ?? this.bio),
    isFollowing: isFollowing ?? this.isFollowing,
    ageVerified: ageVerified ?? this.ageVerified,
    isMinor: isMinor ?? this.isMinor,
  );

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