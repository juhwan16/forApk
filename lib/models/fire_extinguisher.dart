// C:\project\smart_extinguisher_app-main\lib\models\fire_extinguisher.dart
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

  // 서버에서 bool이 true/false, "true"/"false", 0/1 등으로 올 수 있으니 안전하게 변환
  static bool _toBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase().trim();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
    }
    return false;
  }

  factory FireExtinguisher.fromJson(Map<String, dynamic> json) {
    final rawSound = json['isSoundOn'] ?? json['soundOn'];
    final rawLight = json['isLightOn'] ?? json['lightOn'];

    return FireExtinguisher(
      id: (json['_id'] ?? json['id'] ?? '').toString(),

      // 서버에서 name 으로 줄 수도 있으니 둘 다 대응
      location: (json['location'] ?? json['name'] ?? '').toString(),

      // expire_date 같이 다른 이름으로 올 수도 있으니 대비
      expireDate: (json['expireDate'] ?? json['expire_date'] ?? '').toString(),

      // null → '' 처리해서 이미지 URL 깨짐 방지
      imagePath: (json['imagePath'] ?? json['image'] ?? '').toString(),

      isSoundOn: _toBool(rawSound),
      isLightOn: _toBool(rawLight),
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

      // 혹시 서버가 name 을 사용하면 이쪽으로도 같이 보내줌
      'name': location,
    };
  }
}
