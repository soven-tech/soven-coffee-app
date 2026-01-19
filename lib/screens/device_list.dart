import 'package:flutter/material.dart';
import '../models/device.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import 'device_chat.dart';
import '../services/ble_service.dart';
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'onboarding_screen.dart';

class DeviceListScreen extends StatefulWidget {
  final User user;

  const DeviceListScreen({super.key, required this.user});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  final ApiService _api = ApiService();
  final CoffeeMakerBLE _ble = CoffeeMakerBLE();
  
  List<Device> _devices = [];
  bool _loading = true;
  String? _connectingDeviceId; // Track which device is connecting
  Timer? _connectingTimer;
  int _connectingLedIndex = 0;

  Timer? _refreshTimer;

  bool _initialLoad = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
    
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _connectingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    print(">>> STARTING _loadDevices");
    
    if (_initialLoad) {
      setState(() => _loading = true);
    }
    
    // REQUEST PERMISSIONS
    print(">>> Requesting BLE permissions...");
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    
    if (!statuses.values.every((status) => status.isGranted)) {
      print(">>> Permissions DENIED!");
      setState(() => _loading = false);
      return;
    }
    print(">>> Permissions GRANTED");
    
    // STEP 1: Scan for devices (includes serial)
    print(">>> Starting BLE scan...");
    List<Map<String, dynamic>> bleDevices = await _ble.scanForDevices();
    print(">>> BLE scan found ${bleDevices.length} Soven devices");
    
    // STEP 2: Get registered devices from database
    print(">>> Fetching devices from API...");
    List<Device> dbDevices = await _api.getUserDevices(widget.user.userId);
    print(">>> Got ${dbDevices.length} devices from database");
    
    // STEP 3: Match by serial number
    List<Device> finalDeviceList = [];
    
    // Add database devices (mark online/offline by serial match)
    for (var dbDevice in dbDevices) {
      var bleMatch = bleDevices.firstWhere(
        (bleData) => bleData['serial'] == dbDevice.serialNumber,
        orElse: () => <String, dynamic>{},
      );
      
      dbDevice.isConnected = bleMatch.isNotEmpty;
      finalDeviceList.add(dbDevice);
      print(">>> DB Device: ${dbDevice.aiName ?? dbDevice.deviceName} (Serial: ${dbDevice.serialNumber}) - ${dbDevice.isConnected ? 'ONLINE' : 'OFFLINE'}");
    }
    
    // Add new devices (serial not in database)
    for (var bleData in bleDevices) {
      String serial = bleData['serial'];
      String name = bleData['name'];

      print(">>> Processing BLE device: $name (Serial: $serial)");
      bool inDatabase = dbDevices.any((db) => db.serialNumber == serial);
      print(">>> In database: $inDatabase");
      
      if (!inDatabase) {
        print(">>> Adding as NEW device");
        // Parse device type from broadcast name
        String deviceType = 'unknown';
        if (name.toLowerCase().contains('coffee')) {
          deviceType = 'coffee';
        } else if (name.toLowerCase().contains('toast')) {
          deviceType = 'toaster';
        }
        
        print(">>> Device type: $deviceType");

        Device newDevice = Device(
          deviceId: 'new-$serial',
          userId: widget.user.userId,
          deviceType: '${deviceType}_maker',
          deviceName: 'Soven ${deviceType.capitalize()} Maker',
          serialNumber: serial,
          personalityConfig: {},
          bleAddress: name,
          ledCount: deviceType == 'coffee' ? 3 : 2,
          isConnected: true,
          firstBootComplete: false,
        );
        
        finalDeviceList.add(newDevice);
        print(">>> NEW Device: $name (Serial: $serial)");
        print(">>> Device added to final list");
      }
    }
    
    setState(() {
      _devices = finalDeviceList;
      _loading = false;
      _initialLoad = false;
    });
    print(">>> _loadDevices COMPLETE - ${finalDeviceList.length} devices");
}

    Future<void> _connectToDevice(Device device) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1A1A1A),
        title: Text(
          'Connect to ${device.deviceName}?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Connect', style: TextStyle(color: Color(0xFF0088FF))),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _connectingDeviceId = device.deviceId;
      _connectingLedIndex = 0;
    });

    try {
      List<Map<String, dynamic>> bleDevices = await _ble.scanForDevices();
      
      if (bleDevices.isEmpty) {
        print(">>> No BLE devices found");
        _connectingTimer?.cancel();
        setState(() => _connectingDeviceId = null);
        return;
      }
      
      var targetDevice = bleDevices.firstWhere(
        (bleData) => bleData['serial'] == device.serialNumber,
        orElse: () => bleDevices.first,
      );
      
      BluetoothDevice bleDevice = targetDevice['device'];
      bool connected = await _ble.connect(bleDevice);

    if (connected) {
      print(">>> CONNECTION SUCCESSFUL");
      
      // NOW start LED cascade AFTER connection is stable
      _connectingTimer = Timer.periodic(Duration(milliseconds: 300), (timer) async {
        setState(() {
          _connectingLedIndex = (_connectingLedIndex + 1) % 3;
        });
        
        List<bool> pattern = List.generate(3, (i) => i <= _connectingLedIndex);
        try {
          await _ble.sendLedState(pattern);
        } catch (e) {
          print(">>> Error sending LED cascade: $e");
        }
      });
      
      // Let cascade run for 2 seconds
      await Future.delayed(Duration(seconds: 2));
      
      // Stop cascade
      _connectingTimer?.cancel();
      setState(() => _connectingDeviceId = null);
      
    // Check if this is a NEW device (needs onboarding)
    bool isNewDevice = device.deviceId.startsWith('new-');
    
    // Stop cascade
    _connectingTimer?.cancel();
    setState(() => _connectingDeviceId = null);
  
    if (isNewDevice) {
        print(">>> NEW DEVICE - Starting onboarding");
        
        // Navigate to onboarding
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OnboardingScreen(
                user: widget.user,
                device: device,
                bleService: _ble,
              ),
            ),
          );
        }
      } else {
        print(">>> REGISTERED DEVICE - Navigating to chat");
        
        // Mark device as connected
        device.isConnected = true;
        
        // Navigate to chat
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DeviceChatScreen(
                user: widget.user,
                device: device,
                bleService: _ble,
              ),
            ),
          );
        }
      }
    }

    } catch (e) {
      print(">>> Connection error: $e");
      _connectingTimer?.cancel();
      setState(() => _connectingDeviceId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Color(0xFF1A1A1A),
        title: Text('Your Appliances', style: TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF0088FF)))
          : _devices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.devices, size: 80, color: Colors.white),
                      SizedBox(height: 20),
                      Text(
                        'No devices yet',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _devices.length,
                  itemBuilder: (context, index) {
                    Device device = _devices[index];
                    bool isConnecting = _connectingDeviceId == device.deviceId;
                    
                    return DeviceCard(
                      device: device,
                      isConnecting: isConnecting,
                      connectingLedIndex: _connectingLedIndex,
                      onTap: () => _connectToDevice(device),
                    );
                  },
                ),
    );
  }
}

class DeviceCard extends StatelessWidget {
  final Device device;
  final bool isConnecting;
  final int connectingLedIndex;
  final VoidCallback onTap;

  const DeviceCard({
    super.key,
    required this.device,
    required this.isConnecting,
    required this.connectingLedIndex,
    required this.onTap,
  });

  IconData _getDeviceIcon() {
    switch (device.deviceType) {
      case 'coffee_maker':
        return Icons.coffee;
      case 'toaster':
        return Icons.breakfast_dining;
      case 'heater':
        return Icons.thermostat;
      default:
        return Icons.devices;
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isNew = !device.firstBootComplete && device.deviceId.startsWith('new-');
    bool isOffline = !device.isConnected && device.firstBootComplete;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOffline ? Colors.grey : Color(0xFF0088FF),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // Device icon with status indicator
            Stack(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Color(0xFF0088FF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getDeviceIcon(),
                    size: 30,
                    color: isOffline ? Colors.grey : Color(0xFF0088FF),
                  ),
                ),
                if (isNew)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add, size: 16, color: Colors.white),
                    ),
                  ),
              ],
            ),
            
            SizedBox(width: 16),
            
            // Device info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isNew ? 'New Device Found' : device.deviceName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    isOffline ? 'Offline' : (isNew ? 'Tap to register' : device.currentState),
                    style: TextStyle(
                      color: isOffline ? Colors.grey : Colors.white.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            // Status indicator  
            if (isOffline)
              Icon(Icons.power_off, color: Colors.grey, size: 24)
            else if (isNew)
              Icon(Icons.chevron_right, color: Color(0xFF0088FF), size: 24)
            else if (isConnecting)
              Text(
                'Connecting...',
                style: TextStyle(
                  color: Color(0xFF0088FF),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Icon(Icons.check_circle, color: Color(0xFF0088FF), size: 20),
          ],
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}