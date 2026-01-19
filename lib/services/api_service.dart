import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/device.dart';

class ApiService {
  
  final String baseUrl = 'https://api.soven.ca';
  final String apiKey = 'a6ab80229a083849fbc00e99e2d706b7470f33029e9eb9620bacc9489f7274f6';

  // Get user's devices
  Future<List<Device>> getUserDevices(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/devices'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<Device> devices = [];
        
        for (var deviceJson in data['devices']) {
          devices.add(Device.fromJson(deviceJson));
        }
        
        return devices;
      } else {
        throw Exception('Failed to load devices');
      }
    } catch (e) {
      print('API error getting devices: $e');
      return [];
    }
  }
  
  Future<Map<String, dynamic>> registerDevice({
    required String userId,
    required String deviceType,
    required String deviceName,
    required String aiName,
    required String bleAddress,
    required int ledCount,
    required String serialNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/devices'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': apiKey,
        },
        body: jsonEncode({
          'user_id': userId,
          'device_type': deviceType,
          'device_name': deviceName,
          'ai_name': aiName,
          'ble_address': bleAddress,
          'led_count': ledCount,
          'serial_number': serialNumber,
        }),
      );
      
      if (response.statusCode == 200) {
        print(">>> Device registered successfully");
        final data = jsonDecode(response.body);
        print(">>> Received device_id: ${data['device_id']}");
        return data;  // Return the response containing device_id
      } else {
        print(">>> Registration failed: ${response.statusCode} - ${response.body}");
        throw Exception('Registration failed: ${response.statusCode}');
      }
    } catch (e) {
      print('API error registering device: $e');
      rethrow;
    }
  }

  Future<void> completeOnboarding({
    required String deviceId,
    required String aiName,
    String? location,
    Map<String, dynamic>? onboardingData,
  }) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/devices/$deviceId/onboarding'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': apiKey,
        },
        body: jsonEncode({
          'ai_name': aiName,
          'location': location,
          'onboarding_data': onboardingData ?? {},
        }),
      );
    } catch (e) {
      print('API error completing onboarding: $e');
    }
  }

  // Save a message to conversation history
  Future<void> saveMessage({
    required String userId,
    required String deviceId,
    required String role,
    required String content,
    String? deviceState,
  }) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/messages'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': apiKey,
        },
        body: jsonEncode({
          'user_id': userId,
          'device_id': deviceId,
          'role': role,
          'content': content,
          'device_state': deviceState,
        }),
      );
    } catch (e) {
      print('API error saving message: $e');
    }
  }

  // Get conversation history
  Future<List<Map<String, String>>> getConversationHistory({
    required String userId,
    required String deviceId,
    int limit = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/conversations/$userId/$deviceId?limit=$limit'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<Map<String, String>> messages = [];
        
        for (var msg in data['messages']) {
          messages.add({
            'role': msg['role'],
            'content': msg['content'],
          });
        }
        
        // Reverse to get chronological order (API returns newest first)
        return messages.reversed.toList();
      } else {
        return [];
      }
    } catch (e) {
      print('API error getting conversation: $e');
      return [];
    }
  }
}