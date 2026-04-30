class User {
  final String userId;
  final String fullName;
  final String role;

  User({required this.userId, required this.fullName, required this.role});

  factory User.fromJson(Map<String, dynamic> json) => User(
    userId: json['userId'],
    fullName: json['fullName'],
    role: json['role'],
  );

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'fullName': fullName,
    'role': role,
  };
}
