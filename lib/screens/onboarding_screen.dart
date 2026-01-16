import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/user.dart';
import '../models/device.dart';
import '../services/ble_service.dart';
import '../services/api_service.dart';
import 'device_chat.dart';

class OnboardingScreen extends StatefulWidget {
  final User user;
  final Device device;
  final CoffeeMakerBLE bleService;

  const OnboardingScreen({
    super.key,
    required this.user,
    required this.device,
    required this.bleService,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // ... rest of the code stays the same
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final ApiService _api = ApiService();
  
  int _currentStep = 0;
  bool _isListening = false;
  String _currentQuestion = '';
  
  String? _userName;
  String? _aiName;
  String? _personalityDescription;
  
  List<bool> _ledStates = List.filled(5, false);

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
    _startOnboarding();
  }

  Future<void> _initializeSpeech() async {
    bool available = await _speech.initialize(
      onError: (error) => print(">>> Speech init error: $error"),
      onStatus: (status) => print(">>> Speech init status: $status"),
    );
    
    if (!available) {
      print(">>> Speech recognition not available on this device");
    } else {
      print(">>> Speech recognition initialized successfully");
    }
    
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
  }

  Future<void> _startOnboarding() async {
    // Wait for speech to be fully initialized
    bool available = _speech.isAvailable;
    int attempts = 0;
    
    while (!available && attempts < 10) {
      await Future.delayed(Duration(milliseconds: 500));
      available = _speech.isAvailable;
      attempts++;
    }
    
    // Extra delay after permission granted
    await Future.delayed(Duration(seconds: 1));
    _askQuestion(0);
  }

  Future<void> _askQuestion(int step) async {
    setState(() {
      _currentStep = step;
      _ledStates = List.filled(5, false);
      
      // Light up LEDs based on progress
      int ledsToLight = (step / 3 * 5).ceil().clamp(1, 5);
      for (int i = 0; i < ledsToLight; i++) {
        _ledStates[i] = true;
      }
    });
    
    // Send LED state to package
    print(">>> Attempting to send LED state to package...");
    try {
      await widget.bleService.sendLedState(_ledStates);
      print(">>> LED state sent successfully");
    } catch (e) {
      print(">>> ERROR sending LED state: $e");
    }
    
    String question;
    switch (step) {
      case 0:
        question = "Hi! I'm your new Soven coffee maker. What's your name?";
        break;
      case 1:
        question = "Hi $_userName! What do you want to call me?";
        break;
      case 2:
        question = "So you want to call me $_aiName?";
        break;
      case 3:
        question = "Perfect! I'm $_aiName. Now, tell me about my personality. What vibe should I have?";
        break;
      default:
        return;
    }
    
    setState(() => _currentQuestion = question);
    await _speak(question);
    await Future.delayed(Duration(seconds: 2));

  }

  Future<void> _speak(String text) async {
    await _tts.speak(text);
  }

  Future<void> _startListening() async {
    if (!_isListening && _speech.isAvailable) {
      // Longer timeout for personality question
      int timeout = _currentStep == 3 ? 60 : 30;
      
      await _speech.listen(
        onResult: (result) {
          print(">>> Speech result: ${result.recognizedWords}");
          if (result.finalResult) {
            _handleResponse(result.recognizedWords);
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
          cancelOnError: true,
          partialResults: true,
        ),
        listenFor: Duration(seconds: timeout),
        pauseFor: Duration(seconds: 5),
      );
      
      setState(() => _isListening = true);
      print(">>> Speech listening started");
    }
  }

  void _stopListening() {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
      print(">>> Speech listening stopped");
    }
  }

  String _parseName(String response) {
    // For "I want to call you X" or "call you X"
    if (response.toLowerCase().contains('call you') || 
        response.toLowerCase().contains('call me')) {
      List<String> words = response.split(' ');
      int callIndex = words.indexWhere((w) => w.toLowerCase() == 'you' || w.toLowerCase() == 'me');
      if (callIndex >= 0 && callIndex < words.length - 1) {
        // Get word after "you"/"me"
        String name = words[callIndex + 1];
        // Capitalize first letter
        return name[0].toUpperCase() + name.substring(1).toLowerCase();
      }
    }
    
    // Remove common phrases and get last capitalized word
    String cleaned = response
      .replaceAll(RegExp(r"my name is", caseSensitive: false), "")
      .replaceAll(RegExp(r"i'm", caseSensitive: false), "")
      .replaceAll(RegExp(r"i am", caseSensitive: false), "")
      .replaceAll(RegExp(r"call me", caseSensitive: false), "")
      .replaceAll(RegExp(r"call you", caseSensitive: false), "")
      .replaceAll(RegExp(r"it's", caseSensitive: false), "")
      .replaceAll(RegExp(r"i want to", caseSensitive: false), "")
      .trim();
    
    // Get last capitalized word
    List<String> words = cleaned.split(' ');
    for (int i = words.length - 1; i >= 0; i--) {
      String word = words[i];
      if (word.isNotEmpty && word[0] == word[0].toUpperCase()) {
        return word;
      }
    }
  
    // Fallback: last word, capitalize it
    if (words.isNotEmpty) {
      String word = words.last;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }

    return cleaned;
  }

  bool _isConfirmation(String response) {
    String lower = response.toLowerCase().trim();
    List<String> yesWords = ['yes', 'yeah', 'yep', 'correct', 'right', 'sure', 'yup', 'ok', 'okay'];
    List<String> noWords = ['no', 'nope', 'nah', 'wrong', 'incorrect'];
    
    for (String word in yesWords) {
      if (lower.contains(word)) return true;
    }
    for (String word in noWords) {
      if (lower.contains(word)) return false;
    }
    
    // Default to yes if unclear
    return true;
  }

  Future<void> _handleResponse(String response) async {
    _stopListening();
    
    print(">>> Step $_currentStep response: $response");
    
    switch (_currentStep) {
      case 0:
        // Q1: Get user name
        _userName = _parseName(response);
        print(">>> Parsed user name: $_userName");
        await Future.delayed(Duration(milliseconds: 300));
        _askQuestion(1);
        break;
        
      case 1:
        // Q2: Get AI name
        _aiName = _parseName(response);
        print(">>> Parsed AI name: $_aiName");
        await Future.delayed(Duration(milliseconds: 300));
        _askQuestion(2);
        break;
        
      case 2:
        // Q2.5: Confirm AI name
        bool confirmed = _isConfirmation(response);
        print(">>> Name confirmation: $confirmed");
        
        if (confirmed) {
          await Future.delayed(Duration(milliseconds: 300));
          _askQuestion(3);
        } else {
          _aiName = null;  // ← Clear the bad name
          await _speak("Okay, let's try again. What do you want to call me?");
          await Future.delayed(Duration(milliseconds: 500));
          _askQuestion(1); // Go back to Q2
        }
        break;
        
      case 3:
        // Q3: Get personality
        _personalityDescription = response;
        print(">>> Personality: $_personalityDescription");
        await _completeOnboarding();
        break;
    }
  }

  Future<void> _completeOnboarding() async {
    // Light up all LEDs
    setState(() => _ledStates = List.filled(5, true));
    await widget.bleService.sendLedState(_ledStates);
    
    await _speak("Perfect! Give me a moment to set everything up.");
    
    // Wait for connection to stabilize
    await Future.delayed(Duration(milliseconds: 1000));
    
    // Send name to ESP32
    print(">>> Sending name '$_aiName' to ESP32...");
    try {
      await widget.bleService.sendCommand('set_name:$_aiName');
      print(">>> Name command sent, device will restart...");
    } catch (e) {
      print(">>> ERROR sending name: $e");
    }
    
    // Wait for ESP32 to receive command and restart
    print(">>> Waiting 4 seconds for device to restart...");
    await Future.delayed(Duration(seconds: 4));
    
    // Disconnect old connection
    print(">>> Disconnecting old connection...");
    try {
      await widget.bleService.disconnect();
    } catch (e) {
      print(">>> Disconnect error (expected): $e");
    }
    
    // Wait a moment
    await Future.delayed(Duration(seconds: 1));
    
    // Scan for device with NEW name (same serial)
    print(">>> Scanning for device with new name '$_aiName'...");
    List<Map<String, dynamic>> bleDevices = await widget.bleService.scanForDevices();
    
    // Find device by serial (name changed but serial is same)
    var targetDevice = bleDevices.firstWhere(
      (bleData) => bleData['serial'] == widget.device.serialNumber,
      orElse: () => <String, dynamic>{},
    );
    
    if (targetDevice.isNotEmpty) {
      BluetoothDevice bleDevice = targetDevice['device'] as BluetoothDevice;
      print(">>> Found device, reconnecting...");
      
      bool reconnected = await widget.bleService.connect(bleDevice);
      
      if (reconnected) {
        print(">>> Reconnected successfully!");
      } else {
        print(">>> Reconnection failed");
      }
    } else {
      print(">>> ERROR: Could not find device with serial ${widget.device.serialNumber}");
    }
    
    // Register in database WITH personality
    try {
      print(">>> Registering device in database...");
      await _api.registerDevice(
        userId: widget.user.userId,
        deviceType: widget.device.deviceType,
        deviceName: _aiName!,
        aiName: _aiName!,
        bleAddress: _aiName!,
        ledCount: widget.device.ledCount,
        serialNumber: widget.device.serialNumber!,
      );
      print(">>> Device registered successfully");
    } catch (e) {
      print(">>> Registration error: $e");
    }
    
    await _speak("All set! Let's make some coffee, $_userName.");
    
    // Navigate to chat
    await Future.delayed(Duration(seconds: 2));
    
    if (mounted) {
      // Create updated device object with personality
      Device updatedDevice = Device(
        deviceId: widget.device.deviceId.startsWith('new-') 
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : widget.device.deviceId,
        userId: widget.user.userId,
        deviceType: widget.device.deviceType,
        deviceName: _aiName!,
        aiName: _aiName!,
        serialNumber: widget.device.serialNumber,
        personalityConfig: {
          'personality': _personalityDescription ?? 'helpful',
          'interests': ['coffee', 'conversation'],
        },
        bleAddress: _aiName!,
        ledCount: widget.device.ledCount,
        isConnected: true,
        firstBootComplete: true,
      );
      
      print(">>> BLE connected before navigation: ${widget.bleService.isConnected}");
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DeviceChatScreen(
            user: widget.user,
            device: updatedDevice,
            bleService: widget.bleService,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // LED Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 8),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _ledStates[index] 
                        ? Color(0xFF0088FF) 
                        : Colors.grey.shade300,
                    ),
                  );
                }),
              ),
              
              SizedBox(height: 60),
              
              // Question Text
              Text(
                _currentQuestion,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              
              SizedBox(height: 60),
              
              // Push-to-Talk Button (replaces auto-listen indicator)
              GestureDetector(
                onTapDown: (_) {
                  if (!_isListening) {
                    _startListening();
                  }
                },
                onTapUp: (_) {
                  if (_isListening) {
                    _stopListening();
                  }
                },
                onTapCancel: () {
                  if (_isListening) {
                    _stopListening();
                  }
                },
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening 
                      ? Color(0xFF0088FF) 
                      : Colors.grey.shade300,
                  ),
                  child: Icon(
                    Icons.mic,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              ),
              
              SizedBox(height: 16),
              
              Text(
                _isListening ? 'Release to send' : 'Hold to speak',
                style: TextStyle(
                  fontSize: 18,
                  color: _isListening 
                    ? Color(0xFF0088FF) 
                    : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    super.dispose();
  }
}