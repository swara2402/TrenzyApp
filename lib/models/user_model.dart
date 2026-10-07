class UserModel {
  final String id;
  final String name;
  final String displayName;
  final String email;
  final String profileImageUrl;
  final String avatarUrl;
  final String bio;
  final int followers;
  final int following;
  final bool isFollowing;
  final String firebaseUid;
  final bool emailVerified;
  final bool ageVerified;
  final bool isMinor;

  UserModel({
    String? id,
    String? name,
    String? displayName,
    String? email,
    String? profileImageUrl,
    String? avatarUrl,
    String? bio,
    int? followers,
    int? following,
    bool? isFollowing,
    String? firebaseUid,
    bool? emailVerified,
    bool? ageVerified,
    bool? isMinor,
  })  : id = id ?? '',
        name = name ?? displayName ?? '',
        displayName = displayName ?? name ?? '',
        email = email ?? '',
        profileImageUrl = profileImageUrl ?? '',
        avatarUrl = avatarUrl ?? '',
        bio = bio ?? '',
        followers = followers ?? 0,
        following = following ?? 0,
        isFollowing = isFollowing ?? false,
        firebaseUid = firebaseUid ?? '',
        emailVerified = emailVerified ?? false,
        ageVerified = ageVerified ?? false,
        isMinor = isMinor ?? false;

  /// Creates a UserModel from a Firebase Auth user's basic info
  factory UserModel.fromFirebase({
    required String uid,
    String? name,
    String? email,
  }) {
    return UserModel(
      id: uid,
      firebaseUid: uid,
      name: name,
      displayName: name,
      email: email,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString(),
      name: json['name'] as String?,
      displayName: json['displayName'] as String?,
      email: json['email'] as String?,
      profileImageUrl: json['profileImageUrl'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      followers: json['followers'] as int?,
      following: json['following'] as int?,
      isFollowing: json['isFollowing'] as bool?,
      firebaseUid: json['firebaseUid'] as String?,
      emailVerified: json['emailVerified'] as bool?,
      ageVerified: json['ageVerified'] as bool?,
      isMinor: json['isMinor'] as bool?,
    );
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? displayName,
    String? email,
    String? profileImageUrl,
    String? avatarUrl,
    String? bio,
    int? followers,
    int? following,
    bool? isFollowing,
    String? firebaseUid,
    bool? emailVerified,
    bool? ageVerified,
    bool? isMinor,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      isFollowing: isFollowing ?? this.isFollowing,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      emailVerified: emailVerified ?? this.emailVerified,
      ageVerified: ageVerified ?? this.ageVerified,
      isMinor: isMinor ?? this.isMinor,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'displayName': displayName,
      'email': email,
      'profileImageUrl': profileImageUrl,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'followers': followers,
      'following': following,
      'isFollowing': isFollowing,
      'firebaseUid': firebaseUid,
      'emailVerified': emailVerified,
      'ageVerified': ageVerified,
      'isMinor': isMinor,
    };
  }
}