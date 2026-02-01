import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:http/http.dart' as http;

class SovenApiService {
  static const String baseUrl = 'https://api.soven.ca';
  static const String apiKey = 'a6ab80229a083849fbc00e99e2d706b7470f33029e9eb9620bacc9489f7274f6';
  
  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'X-API-Key': apiKey,
  };

  // ==========================================================================
  // HEALTH & SYSTEM
  // ==========================================================================

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

  // ==========================================================================
  // ONBOARDING & PERSONALITY
  // ==========================================================================

  /// Create AI personality during onboarding (legacy method)
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

  /// Create personality with DNA from origin story (NEW - DNA System)
  Future<Map<String, dynamic>> createPersonalityWithOrigin({
    required String userId,
    required String deviceId,
    required String aiName,
    required String originStory,
    bool preferAmerican = true,
  }) async {
    try {
      print('[API] Creating personality with DNA...');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/onboarding/create-with-origin'),
        headers: _headers,
        body: jsonEncode({
          'user_id': userId,
          'device_id': deviceId,
          'ai_name': aiName,
          'origin_story': originStory,
          'prefer_american': preferAmerican,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[API] DNA created successfully');
        print('[API] Voice config: ${data['voice_config']}');
        return data;
      } else {
        throw Exception('DNA creation failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('[API] Create personality with origin error: $e');
      rethrow;
    }
  }

  // ==========================================================================
  // CONVERSATION (Phone-based voice)
  // ==========================================================================

  /// Main conversation endpoint - phone captures voice, server processes
  Future<ConversationResponse> sendMessage({
    required String userInput,
    required String userId,
    required String deviceId,
    String? userName,
    Map<String, dynamic>? voiceConfig,
  }) async {
    try {
      print('[API] Sending message to server: $userInput');
      
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

      print('[API] Server response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[API] AI response: ${data['ai_response']}');
        print('[API] Commands: ${data['commands']}');
        return ConversationResponse.fromJson(data);
      } else {
        throw Exception('Conversation failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('[API] Send message error: $e');
      rethrow;
    }
  }

  // ==========================================================================
  // DEVICE AUDIO (BLE Bridge mode)
  // ==========================================================================

  /// Process audio from device (when using BLE bridge)
  Future<ConversationResponse> processDeviceAudio({
    required String deviceId,
    required String userId,
    required File audioFile,
  }) async {
    try {
      print('[API] Uploading device audio (${audioFile.lengthSync()} bytes)...');
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/audio/process'),
      );
      
      request.headers['X-API-Key'] = apiKey;
      request.fields['device_id'] = deviceId;
      request.fields['user_id'] = userId;
      
      request.files.add(
        await http.MultipartFile.fromPath('audio', audioFile.path),
      );
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[API] Device audio processed successfully');
        return ConversationResponse.fromJson(data);
      } else {
        throw Exception('Device audio processing failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('[API] Device audio error: $e');
      rethrow;
    }
  }

  // ==========================================================================
  // AUDIO FILES
  // ==========================================================================

  /// Get TTS audio file
  Future<Uint8List> getAudioFile(String filename) async {
    try {
      print('[API] Fetching audio: $filename');
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/audio/$filename'),
        headers: {'X-API-Key': apiKey},
      );

      if (response.statusCode == 200) {
        print('[API] Audio fetched: ${response.bodyBytes.length} bytes');
        return response.bodyBytes;
      } else {
        throw Exception('Audio fetch failed: ${response.statusCode}');
      }
    } catch (e) {
      print('[API] Get audio error: $e');
      rethrow;
    }
  }

  // ==========================================================================
  // VOICE MANAGEMENT
  // ==========================================================================

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
      print('[API] List voices error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// RESPONSE MODELS
// ============================================================================

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