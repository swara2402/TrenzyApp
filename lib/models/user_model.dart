class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.backendId,
  });

  final String id;
  final String name;
  final String email;
  final int? backendId;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['firebaseUid']?.toString() ?? json['id']?.toString() ?? '',
      backendId: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? ''),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }

  factory UserModel.fromFirebase({
    required String uid,
    required String name,
    required String email,
    int? backendId,
  }) {
    return UserModel(id: uid, name: name, email: email, backendId: backendId);
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    int? backendId,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      backendId: backendId ?? this.backendId,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'backendId': backendId, 'name': name, 'email': email};
  }
}
