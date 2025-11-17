class FireExtinguisher {
  final String id;
  final String location;
  final String expireDate;
  final String imagePath;
  bool isSoundOn;
  bool isLightOn;

  FireExtinguisher({
    required this.id,
    required this.location,
    required this.expireDate,
    required this.imagePath,
    required this.isSoundOn,
    required this.isLightOn,
  });

  factory FireExtinguisher.fromJson(Map<String, dynamic> json) {
    return FireExtinguisher(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      expireDate: (json['expireDate'] ?? '').toString(),

      // null → '' 처리해서 이미지 URL 깨짐 방지
      imagePath: (json['imagePath'] ?? json['image'] ?? '').toString(),

      isSoundOn: (json['isSoundOn'] ?? false) as bool,
      isLightOn: (json['isLightOn'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'location': location,
      'expireDate': expireDate,
      'imagePath': imagePath,
      'isSoundOn': isSoundOn,
      'isLightOn': isLightOn,
    };
  }
}
