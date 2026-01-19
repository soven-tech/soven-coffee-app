class Device {
  final String deviceId;
  final String userId;
  final String deviceType;
  final String deviceName;
  final Map<String, dynamic> personalityConfig;
  final String bleAddress;
  final int ledCount;
  final String? serialNumber;  // ADD THIS
  
  String? aiName;
  bool firstBootComplete;
  String? location;
  String? personalityTemplate;
  int? personalityTokens;
  
  bool isConnected;
  String currentState;
  List<bool> ledStates;

  Device({
    required this.deviceId,
    required this.userId,
    required this.deviceType,
    required this.deviceName,
    required this.personalityConfig,
    required this.bleAddress,
    required this.ledCount,
    this.serialNumber,  // ADD THIS
    this.aiName,
    this.firstBootComplete = false,
    this.location,
    this.personalityTemplate,
    this.personalityTokens,
    this.isConnected = false,
    this.currentState = 'idle',
    List<bool>? ledStates,
  }) : ledStates = ledStates ?? List.filled(ledCount, false);

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      deviceId: json['device_id'],
      userId: json['user_id'],
      deviceType: json['device_type'],
      deviceName: json['device_name'],
      personalityConfig: json['personality_config'] ?? {},
      bleAddress: json['ble_address'] ?? '',
      ledCount: json['led_count'] ?? 3,
      serialNumber: json['serial_number'],  // ADD THIS
      aiName: json['ai_name'],
      firstBootComplete: json['first_boot_complete'] ?? false,
      location: json['location'],
      personalityTemplate: json['personality_template'],
      personalityTokens: json['personality_tokens'] ?? 2000,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'user_id': userId,
      'device_type': deviceType,
      'device_name': deviceName,
      'personality_config': personalityConfig,
      'ble_address': bleAddress,
      'led_count': ledCount,
      'serial_number': serialNumber,  // ADD THIS
      'ai_name': aiName,
      'first_boot_complete': firstBootComplete,
      'location': location,
      'personality_template': personalityTemplate,
      'personality_tokens': personalityTokens,
    };
  }
}