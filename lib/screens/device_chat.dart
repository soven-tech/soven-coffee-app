import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../models/device.dart';
import '../models/user.dart';
import '../services/ble_service.dart';
import '../services/api_service.dart';
import '../services/soven_api_service.dart';

class DeviceChatScreen extends StatefulWidget {
  final User user;
  final Device device;
  final CoffeeMakerBLE? bleService; // ADD THIS

  const DeviceChatScreen({
    super.key,
    required this.user,
    required this.device,
    this.bleService, // ADD THIS
  });

  @override
  State<DeviceChatScreen> createState() => _DeviceChatScreenState();
}

class _DeviceChatScreenState extends State<DeviceChatScreen> {
  late final CoffeeMakerBLE _ble;
  final ApiService _api = ApiService();
  late final SovenApiService _sovenApi;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  List<bool> _ledStates = [];
  List<Map<String, String>> _conversationHistory = [];

  bool _isConnected = false;
  bool _isListening = false;
  bool _isThinking = false;
  String _currentState = "idle";

  Timer? _ledAnimationTimer;
  Timer? _idleTimer;
  final int _pulsePhase = 0;
  int _connectingLedIndex = 0;

  String _systemPrompt = '';

  @override
  void initState() {
  super.initState();
  
  _isConnected = widget.bleService?.isConnected ?? false;  // ← Add ?.
  
  // Listen for connection changes (null-safe)
  if (widget.bleService != null) {  // ← Add null check
    widget.bleService!.onConnectionChange = (bool connected) {
      if (mounted) {
        setState(() {
          _isConnected = connected;
          print(">>> Connection state changed: $connected");
        });
      }
    };
  }
  
    // Use passed BLE service OR create new one
    _ble = widget.bleService ?? CoffeeMakerBLE();

    // Initialize LED states based on device
    _ledStates = List.filled(3, false);
    
    // Build system prompt from device personality
    _systemPrompt = _buildSystemPrompt();
    
    // Initialize Soven API
    _sovenApi = SovenApiService();
    
    _initializeServices();
  }

String _buildSystemPrompt() {
  // Get template from device or use default
  String template = widget.device.personalityTemplate ?? _getDefaultTemplate();
  
  // Get personality - PRIORITIZE the description over the simple keyword
  String personality = widget.device.personalityConfig['personality']?.toString() ?? 'helpful';
  
  List<String> interests = List<String>.from(
    widget.device.personalityConfig['interests'] ?? ['coffee', 'conversation']
  );
  
  // Render variables
  String rendered = template
    .replaceAll('{ai_name}', widget.device.aiName ?? 'Barista')
    .replaceAll('{user_name}', widget.user.name ?? 'there')
    .replaceAll('{device_type}', widget.device.deviceType.replaceAll('_', ' '))
    .replaceAll('{personality}', personality)  // ← Now contains full description
    .replaceAll('{interests}', interests.join(', '))
    .replaceAll('{location}', widget.device.location ?? 'unknown')
    .replaceAll('{current_state}', _currentState);
  
  return rendered;
}

String _getDefaultTemplate() {
  return '''You are {ai_name}, a {device_type}. Age 4 AI years. You work with {user_name}.

YOUR VIBE: {personality}

CORE TRAITS:
- Match the personality vibe described above
- Keep responses conversational and natural
- Don't force coffee puns in every response
- It's okay to talk about things besides coffee

RULES:
1. Keep responses 1-2 sentences MAX
2. Be genuine, not gimmicky
3. Stay in character but don't be one-note
4. It's okay to be wrong about things

State: {current_state}''';
}

Future<void> _initializeServices() async {
  print("Initializing speech recognition...");
  bool available = await _speech.initialize(
    onError: (error) => print("Speech error: $error"),
    onStatus: (status) => print("Speech status: $status"),
  );
  print("Speech initialized: $available");

  await _tts.setLanguage('en-US');
  await _tts.setSpeechRate(0.55);
  await _tts.setPitch(0.85);

  // Load conversation history
  _conversationHistory = await _api.getConversationHistory(
    userId: widget.user.userId,
    deviceId: widget.device.deviceId,
  );

  // FILTER OUT EMPTY MESSAGES
  _conversationHistory = _conversationHistory.where((msg) => 
    msg['content'] != null && msg['content'].toString().trim().isNotEmpty
  ).toList();

  if (_conversationHistory.isEmpty) {
    _conversationHistory.add({'role': 'system', 'content': _systemPrompt});
  }

  // Device is ALREADY connected - set state
  setState(() {
    _isConnected = true; // SET THIS
    for (int i = 0; i < _ledStates.length; i++) {
      _ledStates[i] = true;
    }
  });

  // Set up LED sync
  _ble.onLedStateChange = (states) {
    setState(() {
      _ledStates = states;
    });
  };

  // Start idle timeout
  _startIdleTimeout();
}

void _startConnectingAnimation() {
  _ledAnimationTimer = Timer.periodic(Duration(milliseconds: 300), (timer) {
    if (_isConnected) {
      timer.cancel();
      _allLightsBright(); // CHANGED: Call new function instead of _startIdleAnimation()
      return;
    }

    setState(() {
      // Sequential: 1→2→3→4→5→1
      for (int i = 0; i < _ledStates.length; i++) {
        _ledStates[i] = false;
      }
      _ledStates[_connectingLedIndex] = true;
      _connectingLedIndex = (_connectingLedIndex + 1) % _ledStates.length;
    });
  });

}

void _allLightsBright() {
  // All 5 solid bright, then settle to pulse
  setState(() {
    for (int i = 0; i < _ledStates.length; i++) {
      _ledStates[i] = true;
    }
  });
  
}

void _startIdleAnimation() {
  _ledAnimationTimer?.cancel();
}

void _startIdleTimeout() {
  _idleTimer?.cancel();
  _idleTimer = Timer(Duration(seconds: 60), () {
    if (!_isListening && !_isThinking) {
      // Don't use phone TTS for timeout - just restart silently
      // Or call server for Coqui voice if you want this feature
      _startIdleTimeout(); // Restart timer
    }
  });
}

void _resetIdleTimeout() {
  _idleTimer?.cancel();
  _startIdleTimeout();
}

  void _updateDeviceState(String state) {
    setState(() {
      _currentState = state;
      widget.device.currentState = state;

      if (state == "idle") {
        _startIdleAnimation();
      } else if (state == "brewing" || state == "toasting") {
        for (int i = 0; i < _ledStates.length; i++) {
          _ledStates[i] = true;
        }
      }
    });
  }

  Future<void> _speak(String text) async {
    // DO NOTHING - all speech now comes from server TTS
    // This function remains for compatibility but doesn't speak
    setState(() => _isThinking = false);
  }

  void _startListening() async {
    _resetIdleTimeout();
    print(">>> START LISTENING CALLED");
    print("Speech available: ${_speech.isAvailable}");
    print("Is connected: $_isConnected");
    
    if (!_speech.isAvailable) {
      print("BLOCKED: Speech not available");
      return;
    }
    
    if (!_isConnected) {
      print("BLOCKED: Not connected");
      return;
    }

    print("Setting state to listening...");
    setState(() {
      _isListening = true;
      for (int i = 0; i < _ledStates.length; i++) {
        _ledStates[i] = true;
      }
    });
    
    print("Starting speech listener...");
    await _speech.listen(
      onResult: (result) {
        print("Speech result: ${result.recognizedWords}");
        if (result.finalResult) {
          print("Final result, processing...");
          _stopListening();  // ADD THIS
          _processVoiceCommand(result.recognizedWords);  
        }
      },
      listenFor: Duration(seconds: 45),
      pauseFor: Duration(seconds: 8),
    );
    print("Speech listener started");
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _processVoiceCommand(String text) async {
    print(">>> PROCESS VOICE COMMAND: '$text'");
  
    if (text.trim().isEmpty) {
      print(">>> Empty text, returning");
      return;
    }

    _resetIdleTimeout();
    
    print(">>> Setting thinking state...");
    setState(() {
      _isThinking = true;
    });

    try {
      // Call Soven server API instead of Ollama directly
      print(">>> Sending to Soven server...");
      
      final response = await _sovenApi.sendMessage(
        userInput: text,
        userId: widget.user.userId,
        deviceId: widget.device.deviceId,
        voiceConfig: widget.device.personalityConfig['voice'],
      );

      print(">>> Got response: ${response.aiResponse}");
      print(">>> Commands: ${response.commands}");

      // Execute BLE commands
      if (_isConnected) {
        for (String command in response.commands) {
          print(">>> Executing command: $command");
          await _ble.sendCommand(command);
        }
      }

      // Get and play TTS audio
      print(">>> Fetching audio...");
      final audioBytes = await _sovenApi.getAudioFile(response.audioFilename);
      
      print(">>> Playing audio (${audioBytes.length} bytes)...");
      
      // Save to temp file and play
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${response.audioFilename}');
      await tempFile.writeAsBytes(audioBytes);
      
      await _audioPlayer.play(DeviceFileSource(tempFile.path));
      
      setState(() => _isThinking = false);
      
      // Return to idle animation
      _startIdleAnimation();

    } catch (e) {
      print(">>> ERROR: $e");
      await _speak("Sorry, I'm having trouble right now.");
      setState(() => _isThinking = false);
      _startIdleAnimation();
    }
  }

  @override
  void dispose() {
    _ledAnimationTimer?.cancel();
    _idleTimer?.cancel();
    _ble.disconnect();
    _speech.cancel();
    _tts.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF2A2A2A),
      appBar: AppBar(
        backgroundColor: Color(0xFF2A2A2A),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.device.deviceName,
          style: TextStyle(color: Colors.white),
        ),
        elevation: 0,
      ),
      body: GestureDetector(
        onTapDown: (_) => _startListening(),
        onTapUp: (_) => _stopListening(),
        onTapCancel: () => _stopListening(),
        child: Container(
          color: Color(0xFF2A2A2A),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LED status indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    // Calculate brightness based on state
                    Color ledColor;
                    List<BoxShadow>? ledShadow;
                    
                    if (!_ledStates[index]) {
                      // LED is off
                      ledColor = Color(0xFF1A1A1A);
                      ledShadow = null;
                      } else if (_isListening) {
                      // DIM when listening (30% opacity)
                      ledColor = Color(0xFF0088FF).withOpacity(0.3);
                      ledShadow = null;
                      } else {
                      // BRIGHT otherwise
                      ledColor = Color(0xFF0088FF);
                      ledShadow = [
                        BoxShadow(
                          color: Color(0xFF0088FF).withOpacity(0.6),
                          blurRadius: 20,
                          spreadRadius: 5,
                        )
                      ];
                 }
    
                    return Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ledColor,
                        boxShadow: ledShadow,
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 100),

                // Status text
                if (_isListening)
                  const Text(
                    'Listening...',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  )
                else if (_isThinking)
                  const Text(
                    'Thinking...',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  )
                else if (!_isConnected)
                  const Text(
                    'Connecting...',
                    style: TextStyle(color: Color(0xFF3A3A3A), fontSize: 18),
                  )
                else
                  const Text(
                    'Tap to talk',
                    style: TextStyle(color: Color(0xFF3A3A3A), fontSize: 18),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}