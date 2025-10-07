// lib/models/user_model.dart
class UserModel {
  final String uid;
  final String username;
  final String email;
  final bool isPremium;

  UserModel({
    required this.uid,
    required this.username,
    required this.email,
    required this.isPremium,
  });

  // 👇 Add this method — allows creating a new instance with updated fields
  UserModel copyWith({
    String? uid,
    String? username,
    String? email,
    bool? isPremium,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      email: email ?? this.email,
      isPremium: isPremium ?? this.isPremium,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      username: map['username'] ?? 'Unknown',
      email: map['email'] ?? '',
      isPremium: map['membership']?['isPremium'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'email': email,
      'membership': {
        'isPremium': isPremium,
        'subscriptionStart': null,
        'subscriptionEnd': null,
      },
      'accountStatus': 'active',
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }
}