class User {
  final int id;
  final String name;
  final String email;
  
  User({
    required this.id,
    required this.name,
    required this.email,
  });
  
  factory User.fromJson(Map<String, dynamic> json) {
    // Fix the id conversion - handle both String and int
    var rawId = json['id'];
    int parsedId = rawId is int ? rawId : int.parse(rawId.toString());
    
    return User(
      id: parsedId,
      name: json['name'],
      email: json['email'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
    };
  }
}