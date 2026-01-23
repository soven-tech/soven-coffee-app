import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class SovenApiService {
  static const String baseUrl = 'https://api.soven.ca';
  static const String apiKey = 'a6ab80229a083849fbc00e99e2d706b7470f33029e9eb9620bacc9489f7274f6';
  
  // For local testing, use:
  // static const String baseUrl = 'http://192.168.40.10:8000';
  
  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'X-API-Key': apiKey,
  };

  /// Health check - no auth required
  Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/health'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'healthy';
      }
      return false;
    } catch (e) {
      print('Health check error: $e');
      return false;
    }
  }

  /// Create AI personality during onboarding
  Future<Map<String, dynamic>> createPersonality({
    required String name,
    required String description,
    bool preferAmerican = true,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/personality/create'),
        headers: _headers,
        body: jsonEncode({
          'name': name,
          'description': description,
          'prefer_american': preferAmerican,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Personality creation failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Create personality error: $e');
      rethrow;
    }
  }

  /// Main conversation endpoint - replaces direct Ollama calls
  Future<ConversationResponse> sendMessage({
    required String userInput,
    required String userId,
    required String deviceId,
    String? userName,  // Add this parameter
    Map<String, dynamic>? voiceConfig,
  }) async {
    try {
      print('>>> Sending to server: $userInput');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/conversation'),
        headers: _headers,
        body: jsonEncode({
          'user_input': userInput,
          'user_id': userId,
          'device_id': deviceId,
          'voice_config': voiceConfig ?? {
            'voice_id': 'p297',
            'model': 'tts_models/en/vctk/vits'
          },
        }),
      );

      print('>>> Server response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('>>> AI response: ${data['ai_response']}');
        print('>>> Commands: ${data['commands']}');
        return ConversationResponse.fromJson(data);
      } else {
        throw Exception('Conversation failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Send message error: $e');
      rethrow;
    }
  }

  /// Get TTS audio file
  Future<Uint8List> getAudioFile(String filename) async {
    try {
      print('>>> Fetching audio: $filename');
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/audio/$filename'),
        headers: {'X-API-Key': apiKey},
      );

      if (response.statusCode == 200) {
        print('>>> Audio fetched: ${response.bodyBytes.length} bytes');
        return response.bodyBytes;
      } else {
        throw Exception('Audio fetch failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Get audio error: $e');
      rethrow;
    }
  }

  /// List available voices
  Future<Map<String, dynamic>> listVoices() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/voices/list'),
        headers: {'X-API-Key': apiKey},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('List voices failed: ${response.statusCode}');
      }
    } catch (e) {
      print('List voices error: $e');
      rethrow;
    }
  }
}

/// Response model for conversation endpoint
class ConversationResponse {
  final String aiResponse;
  final String audioFilename;
  final List<String> commands;
  final String messageId;

  ConversationResponse({
    required this.aiResponse,
    required this.audioFilename,
    required this.commands,
    required this.messageId,
  });

  factory ConversationResponse.fromJson(Map<String, dynamic> json) {
    return ConversationResponse(
      aiResponse: json['ai_response'],
      audioFilename: json['audio_filename'],
      commands: List<String>.from(json['commands']),
      messageId: json['message_id'],
    );
  }
}