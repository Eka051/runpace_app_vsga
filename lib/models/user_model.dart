class UserModel {
  final int? id;
  final String email;
  final String password;
  final String? name;
  final String createdAt;

  UserModel({
    this.id,
    required this.email,
    required this.password,
    this.name,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      email: map['email'],
      password: map['password'],
      name: map['name'],
      createdAt: map['created_at'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'password': password,
      'name': name,
      'created_at': createdAt,
    };
  }

  UserModel copyWith({
    int? id,
    String? email,
    String? password,
    String? name,
    String? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      password: password ?? this.password,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
