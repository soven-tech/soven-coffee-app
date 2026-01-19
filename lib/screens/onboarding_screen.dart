import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/user.dart';
import '../models/device.dart';
import '../services/ble_service.dart';
import '../services/api_service.dart';
import '../services/soven_api_service.dart';
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
  final stt.SpeechToText _speech = stt.SpeechToText();
  final ApiService _api = ApiService();
  final SovenApiService _sovenApi = SovenApiService();
  
  final TextEditingController _textController = TextEditingController();
  
  int _currentStep = 0;
  bool _isListening = false;
  String _currentQuestion = '';
  
  String? _userName;
  String? _aiName;
  String? _personalityDescription;
  Map<String, dynamic>? _selectedVoice;
  
  List<bool> _ledStates = List.filled(3, false);

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
    _startOnboarding();
  }

  Future<void> _initializeSpeech() async {
    bool available = await _speech.initialize(
      onError: (error) => print(">>> Speech error: $error"),
      onStatus: (status) => print(">>> Speech status: $status"),
    );
    
    if (!available) {
      print(">>> Speech recognition not available");
    } else {
      print(">>> Speech recognition initialized");
    }
  }

  Future<void> _startOnboarding() async {
    // Wait for speech initialization
    bool available = _speech.isAvailable;
    int attempts = 0;
    
    while (!available && attempts < 10) {
      await Future.delayed(Duration(milliseconds: 500));
      available = _speech.isAvailable;
      attempts++;
    }
    
    _askQuestion(0);
  }

  void _askQuestion(int step) {
    setState(() {
      _currentStep = step;
      _textController.clear();
      
      // Update LED progress (3 LEDs for 3 questions)
      _ledStates = List.filled(3, false);
      for (int i = 0; i <= step && i < 3; i++) {
        _ledStates[i] = true;
      }
      
      // Set question text
      switch (step) {
        case 0:
          _currentQuestion = "What's your name?";
          break;
        case 1:
          _currentQuestion = "What should I call myself?";
          break;
        case 2:
          _currentQuestion = "Describe my personality";
          if (_textController.text.isEmpty) {
          _textController.clear();
          }
          break;

        default:
          _currentQuestion = '';
      }
    });
    
    // Send LED state to package
    widget.bleService.sendLedState(_ledStates).catchError((e) {
      print(">>> LED error: $e");
    });
  }

  Future<void> _startListening() async {
    if (!_isListening && _speech.isAvailable) {
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _textController.text = result.recognizedWords;
          });
        },
        listenFor: Duration(seconds: 30),
        pauseFor: Duration(seconds: 3),
      );
      
      setState(() => _isListening = true);
      print(">>> Listening started");
    }
  }

  void _stopListening() {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
      print(">>> Listening stopped");
    }
  }

  void _handleContinue() {
    String input = _textController.text.trim();
    
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please provide an answer')),
      );
      return;
    }
    
    switch (_currentStep) {
      case 0:
        _userName = _parseName(input);
        print(">>> User name: $_userName");
        _askQuestion(1);
        break;
        
      case 1:
        _aiName = _parseName(input);
        print(">>> AI name: $_aiName");
        _askQuestion(2);
        break;
        
      case 2:
        _personalityDescription = input;
        print(">>> Personality: $_personalityDescription");
        _completeOnboarding();
        break;
    }
  }

  void _handleBack() {
    if (_currentStep > 0) {
      _askQuestion(_currentStep - 1);
    } else {
      Navigator.pop(context);
    }
  }

  String _parseName(String input) {
    String lower = input.toLowerCase().trim();
    
    // Try to extract name after trigger phrases
    List<String> triggerPhrases = [
      'call yourself ',
      'call you ',
      'call me ',
      'my name is ',
      'i am ',
      'i\'m ',
    ];
    
    for (String trigger in triggerPhrases) {
      if (lower.contains(trigger)) {
        int startIndex = lower.indexOf(trigger) + trigger.length;
        String remainder = input.substring(startIndex).trim();
        
        // Get first word after trigger
        List<String> words = remainder.split(' ');
        if (words.isNotEmpty && words.first.isNotEmpty) {
          String name = words.first.replaceAll(RegExp(r'[^a-zA-Z]'), '');
          if (name.isNotEmpty) {
            return name[0].toUpperCase() + name.substring(1).toLowerCase();
          }
        }
      }
    }
    
    // Fallback: just take first word
    List<String> words = input.trim().split(' ');
    if (words.isNotEmpty) {
      String name = words.first.replaceAll(RegExp(r'[^a-zA-Z]'), '');
      if (name.isNotEmpty) {
        return name[0].toUpperCase() + name.substring(1).toLowerCase();
      }
    }
    
    return "Assistant"; // Final fallback
  }

  Future<void> _completeOnboarding() async {
    // Show loading - all 3 LEDs on
    setState(() => _ledStates = List.filled(3, true));
    await widget.bleService.sendLedState(_ledStates);
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Setting up $_aiName...'),
              ],
            ),
          ),
        ),
      ),
    );
    
    // CREATE PERSONALITY ON SERVER
    print(">>> Creating personality on server...");
    try {
      final personalityResult = await _sovenApi.createPersonality(
        name: _aiName!,
        description: _personalityDescription ?? 'helpful and friendly',
        preferAmerican: true,
      );
      
      _selectedVoice = personalityResult['voice'];
      print(">>> Voice selected: ${_selectedVoice!['speaker']}");
    } catch (e) {
      print(">>> ERROR creating personality: $e");
      _selectedVoice = {
        'voice_id': 'p297',
        'model': 'tts_models/en/vctk/vits'
      };
    }
    
    // Send name to ESP32 (it will restart immediately)
    print(">>> Sending name to ESP32...");
    try {
      await widget.bleService.sendCommand('set_name:$_aiName');
      print(">>> Name sent, device will restart...");
    } catch (e) {
      print(">>> Send error (expected if device restarts quickly): $e");
      // Error is often expected - device may restart before acknowledging
    }
    
    // Wait longer for full boot cycle (ESP32 boot takes ~3-5 seconds)
    print(">>> Waiting for device to restart and boot...");
    await Future.delayed(Duration(seconds: 7));
    
    // Try to disconnect if still connected
    try {
      if (widget.bleService.isConnected) {
        await widget.bleService.disconnect();
      }
    } catch (e) {
      print(">>> Disconnect: $e (device may have already disconnected)");
    }
    
    // Wait a moment before scanning
    await Future.delayed(Duration(seconds: 2));
    
    // Reconnect
    print(">>> Scanning for renamed device...");
    List<Map<String, dynamic>> bleDevices = await widget.bleService.scanForDevices();
    
    var targetDevice = bleDevices.firstWhere(
      (bleData) => bleData['serial'] == widget.device.serialNumber,
      orElse: () => <String, dynamic>{},
    );
    
    if (targetDevice.isNotEmpty) {
      BluetoothDevice bleDevice = targetDevice['device'] as BluetoothDevice;
      await widget.bleService.connect(bleDevice);
    }
    
    // Register device and capture the device_id from server
    String? registeredDeviceId;
    try {
      print(">>> Registering device in database...");
      final registrationResponse = await _api.registerDevice(
        userId: widget.user.userId,
        deviceType: widget.device.deviceType,
        deviceName: _aiName!,
        aiName: _aiName!,
        bleAddress: _aiName!,
        ledCount: 3,
        serialNumber: widget.device.serialNumber!,
      );
      registeredDeviceId = registrationResponse['device_id'];
      print(">>> Device registered with ID: $registeredDeviceId");
    } catch (e) {
      print(">>> Registration error: $e");
    }
    
    // Close loading dialog
    if (mounted) Navigator.pop(context);
    
    // Navigate to chat
    if (mounted) {
      Device updatedDevice = Device(
        deviceId: registeredDeviceId ?? widget.device.deviceId,  // USE SERVER-GENERATED ID
        userId: widget.user.userId,
        deviceType: widget.device.deviceType,
        deviceName: _aiName!,
        aiName: _aiName!,
        serialNumber: widget.device.serialNumber,
        personalityConfig: {
          'personality': _personalityDescription ?? 'helpful',
          'interests': ['coffee', 'conversation'],
          'voice': _selectedVoice ?? {
            'voice_id': 'p297',
            'model': 'tts_models/en/vctk/vits'
          },
        },
        bleAddress: _aiName!,
        ledCount: 3,
        isConnected: true,
        firstBootComplete: true,
      );
      
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: _handleBack,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // LED Progress Indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 6),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _ledStates[index] 
                        ? Color(0xFF0088FF) 
                        : Colors.grey.shade300,
                    ),
                  );
                }),
              ),
              
              SizedBox(height: 48),
              
              // Question
              Text(
                _currentQuestion,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              
              SizedBox(height: 32),
              
              // Text Input Field
              TextField(
                controller: _textController,
                style: TextStyle(fontSize: 18),
                maxLines: _currentStep == 2 ? 4 : 1,
                decoration: InputDecoration(
                  hintText: _currentStep == 2 
                    ? 'Example: A grad student, encouraging but not chipper' 
                    : 'Type here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFF0088FF), width: 2),
                  ),
                ),
              ),
              
              SizedBox(height: 24),
              
              // Voice Input Button
              GestureDetector(
                onTapDown: (_) => _startListening(),
                onTapUp: (_) => _stopListening(),
                onTapCancel: () => _stopListening(),
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _isListening 
                      ? Color(0xFF0088FF) 
                      : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.mic,
                        color: _isListening ? Colors.white : Colors.black54,
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Text(
                        _isListening ? 'Listening...' : 'Hold to speak',
                        style: TextStyle(
                          fontSize: 18,
                          color: _isListening ? Colors.white : Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              Spacer(),
              
              // Continue Button
              ElevatedButton(
                onPressed: _handleContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0088FF),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _currentStep == 2 ? 'Complete Setup' : 'Continue',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
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
    _textController.dispose();
    super.dispose();
  }
}