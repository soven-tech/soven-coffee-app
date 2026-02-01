import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/device.dart';
import '../models/user.dart';
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
  final ApiService _api = ApiService();
  final SovenApiService _sovenApi = SovenApiService();
  
  int _currentStep = 0;
  
  // Step 1: AI name
  String _aiName = '';
  
  // Step 2: Origin story
  String _originStory = '';
  final TextEditingController _originController = TextEditingController();
  
  // Step 3: WiFi configuration
  String _wifiSsid = '';
  String _wifiPassword = '';
  bool _wifiConfigured = false;
  bool _configuringWifi = false;
  
  // Step 4: Completion
  bool _isRegistering = false;
  bool _registrationComplete = false;
  
  String? _deviceId; // Store after registration

  @override
  void dispose() {
    _originController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // STEP 0: WELCOME
  // ==========================================================================
  
  Widget _buildStep0Welcome() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.coffee,
            size: 80,
            color: Color(0xFF0088FF),
          ),
          SizedBox(height: 40),
          Text(
            'Let\'s set up your\n${widget.device.deviceName}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'This will only take a minute',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
          SizedBox(height: 60),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0088FF),
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                setState(() {
                  _currentStep = 1;
                });
              },
              child: Text('Get Started', style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // STEP 1: AI NAME
  // ==========================================================================
  
  Widget _buildStep1AIName() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What should I call myself?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Choose a name for your AI assistant',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
          SizedBox(height: 40),
          TextField(
            autofocus: true,
            style: TextStyle(color: Colors.white, fontSize: 24),
            decoration: InputDecoration(
              hintText: 'e.g., Frank, Stella, Maya',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 24,
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF0088FF), width: 2),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _aiName = value;
              });
            },
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                setState(() {
                  _aiName = value.trim();
                  _currentStep = 2;
                });
              }
            },
          ),
          SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0088FF),
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _aiName.trim().isNotEmpty
                  ? () {
                      setState(() {
                        _currentStep = 2;
                      });
                    }
                  : null,
              child: Text('Continue', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // STEP 2: ORIGIN STORY
  // ==========================================================================
  
  Widget _buildStep2OriginStory() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 40),
            Text(
              'Tell me about $_aiName\'s origins',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Who raised them? What shaped their personality?',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Example: "$_aiName\'s mom was a tired waitress who worked doubles. Dad was never around. $_aiName grew up helping in the kitchen from age 7."',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
            SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              child: TextField(
                controller: _originController,
                maxLines: 8,
                style: TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Write $_aiName\'s backstory here...',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
                onChanged: (value) {
                  setState(() {
                    _originStory = value;
                  });
                },
              ),
            ),
            SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0088FF),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _originStory.trim().length > 20
                    ? () async {
                        // Register device and create personality NOW
                        await _registerDeviceAndCreatePersonality();
                      }
                    : null,
                child: _isRegistering
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text('Continue', style: TextStyle(fontSize: 16)),
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // STEP 3: WIFI CONFIGURATION
  // ==========================================================================
  
  Widget _buildStep3WiFi() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 40),
            Text(
              'Connect $_aiName to WiFi',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'This enables voice control when your phone isn\'t nearby',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
            SizedBox(height: 40),
            
            // WiFi Network Name
            TextField(
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'WiFi Network Name',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                hintText: 'Enter your WiFi SSID',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                prefixIcon: Icon(Icons.wifi, color: Color(0xFF0088FF)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF0088FF), width: 2),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _wifiSsid = value;
                  _wifiConfigured = false;
                });
              },
            ),
            
            SizedBox(height: 24),
            
            // WiFi Password
            TextField(
              obscureText: true,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'WiFi Password',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                hintText: 'Enter password',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                prefixIcon: Icon(Icons.lock, color: Color(0xFF0088FF)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Color(0xFF0088FF), width: 2),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _wifiPassword = value;
                  _wifiConfigured = false;
                });
              },
            ),
            
            SizedBox(height: 32),
            
            // Configure Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _wifiConfigured ? Colors.green : Color(0xFF0088FF),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: (_wifiSsid.isNotEmpty && _wifiPassword.isNotEmpty && !_configuringWifi)
                    ? () async {
                        await _configureWiFiAndRestart();
                      }
                    : null,
                child: _configuringWifi
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : _wifiConfigured
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, size: 20),
                              SizedBox(width: 8),
                              Text('WiFi Configured', style: TextStyle(fontSize: 16)),
                            ],
                          )
                        : Text('Configure WiFi & Complete Setup', style: TextStyle(fontSize: 16)),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Skip Button
            Center(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _currentStep = 4;
                    _registrationComplete = true;
                  });
                },
                child: Text(
                  'Skip WiFi (phone control only)',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // STEP 4: COMPLETION
  // ==========================================================================
  
  Widget _buildStep4Completion() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            size: 80,
            color: Colors.green,
          ),
          SizedBox(height: 24),
          Text(
            'All set!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Text(
            '$_aiName is ready to help',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
          if (_wifiConfigured) ...[
            SizedBox(height: 16),
            Text(
              'Device is restarting and will connect to WiFi...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
          SizedBox(height: 60),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0088FF),
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DeviceChatScreen(
                      user: widget.user,
                      device: widget.device,
                      bleService: widget.bleService,
                    ),
                  ),
                );
              },
              child: Text('Start Chatting', style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // HELPER METHODS
  // ==========================================================================

  Future<void> _registerDeviceAndCreatePersonality() async {
    setState(() {
      _isRegistering = true;
    });
    
    try {
      print('[Onboarding] Starting registration...');
      
      // Step 1: Register device in database
      final registrationResponse = await _api.registerDevice(
        userId: widget.user.userId,
        deviceType: widget.device.deviceType,
        deviceName: widget.device.deviceName,
        aiName: _aiName,
        bleAddress: widget.device.bleAddress,
        ledCount: widget.device.ledCount,
        serialNumber: widget.device.serialNumber ?? '',
      );
      
      _deviceId = registrationResponse['device_id'];
      print('[Onboarding] Device registered: $_deviceId');
      
      // Step 2: Create personality with DNA system
      print('[Onboarding] Creating DNA from origin story...');
      
      final response = await _sovenApi.createPersonalityWithOrigin(
        userId: widget.user.userId,
        deviceId: _deviceId!,
        aiName: _aiName,
        originStory: _originStory,
        preferAmerican: true,
      );
      
      print('[Onboarding] DNA created successfully');
      print('[Onboarding] Voice: ${response['voice_config']}');
      
      // Update device object
      widget.device.aiName = _aiName;
      widget.device.firstBootComplete = true;
      widget.device.personalityConfig['voice'] = response['voice_config'];
      widget.device.personalityConfig['dna'] = response['dna_parameters'];
      
      setState(() {
        _isRegistering = false;
        _currentStep = 3; // Move to WiFi configuration
      });
      
    } catch (e) {
      print('[Onboarding] Registration error: $e');
      
      setState(() {
        _isRegistering = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _configureWiFiAndRestart() async {
    setState(() {
      _configuringWifi = true;
    });
    
    try {
      print('[Onboarding] Sending WiFi credentials and AI name...');
      
      // Send AI name first
      await widget.bleService.sendCommand(jsonEncode({
        'action': 'set_name',
        'params': {
          'name': _aiName,
        }
      }));
      
      await Future.delayed(Duration(milliseconds: 500));
      
      // Then send WiFi credentials
      await widget.bleService.sendCommand(jsonEncode({
        'action': 'set_wifi',
        'params': {
          'ssid': _wifiSsid,
          'password': _wifiPassword,
        }
      }));
      
      setState(() {
        _wifiConfigured = true;
        _configuringWifi = false;
        _registrationComplete = true;
      });
      
      print('[Onboarding] WiFi configured, device will restart');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_aiName is restarting with WiFi and voice enabled!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      
      // Wait a moment then go to completion
      await Future.delayed(Duration(seconds: 2));
      setState(() {
        _currentStep = 4;
      });
      
    } catch (e) {
      print('[Onboarding] WiFi config error: $e');
      
      setState(() {
        _configuringWifi = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to configure WiFi. Try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep0Welcome();
      case 1:
        return _buildStep1AIName();
      case 2:
        return _buildStep2OriginStory();
      case 3:
        return _buildStep3WiFi();
      case 4:
        return _buildStep4Completion();
      default:
        return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1A1A1A),
      appBar: _currentStep > 0 && _currentStep < 4
          ? AppBar(
              backgroundColor: Color(0xFF1A1A1A),
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  if (_currentStep > 0 && !_isRegistering) {
                    setState(() {
                      _currentStep--;
                    });
                  }
                },
              ),
              title: Text(
                'Step $_currentStep of 4',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            )
          : null,
      body: SafeArea(
        child: _buildCurrentStep(),
      ),
    );
  }
}