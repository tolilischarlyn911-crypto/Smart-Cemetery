class UserModel {
  final String? uid;
  final String email;
  final String name;
  final String? photoUrl; // Idinagdag para sa profile picture / HomeScreen

  UserModel({
    this.uid,
    required this.email,
    required this.name,
    this.photoUrl, // Optional para hindi mag-error kahit walang larawan
  });
}
