import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:typed_data';

class CoffeeMakerBLE {
  static final CoffeeMakerBLE _instance = CoffeeMakerBLE._internal();
  factory CoffeeMakerBLE() => _instance;
  CoffeeMakerBLE._internal();
  Function(List<bool> ledStates)? onLedStateChange;
  Function(int)? onProgressChange;
  

  BluetoothDevice? _device;
  BluetoothCharacteristic? _commandChar;
  BluetoothCharacteristic? _stateChar;
  BluetoothCharacteristic? _tempChar;
  BluetoothCharacteristic? _progressChar;
  BluetoothCharacteristic? _convoChar;
  BluetoothCharacteristic? _ledStateChar;
  
  bool get isConnected => _device != null;
  
  Function(bool isConnected)? onConnectionChange;

  // UUIDs from ESP32 firmware
  static const String serviceUUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String commandUUID = "beb5483e-36e1-4688-b7f5-ea07361b26ab";
  static const String stateUUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  static const String tempUUID = "beb5483e-36e1-4688-b7f5-ea07361b26a9";
  static const String ledStateUUID = "beb5483e-36e1-4688-b7f5-ea07361b26ad";
  //static const String progressUUID = "beb5483e-36e1-4688-b7f5-ea07361b26aa";
  static const String conversationUUID = "beb5483e-36e1-4688-b7f5-ea07361b26ac";
  
  // Callbacks
  Function(String state)? onStateChange;
  Function(double temp)? onTemperatureChange;

  void _handleTempUpdate(List<int> value) {
    if (value.isNotEmpty) {
      // Temperature is sent as a float (4 bytes)
      if (value.length >= 4) {
        ByteData byteData = ByteData.sublistView(Uint8List.fromList(value));
        double temp = byteData.getFloat32(0, Endian.little);
        
        if (onTemperatureChange != null) {
          onTemperatureChange!(temp);
        }
      }
    }
  }

  void _handleStateUpdate(List<int> value) {
    if (value.isNotEmpty) {
      String state = String.fromCharCodes(value);
      
      if (onStateChange != null) {
        onStateChange!(state);
      }
    }
  }

  void _handleProgressUpdate(List<int> value) {
    if (value.isNotEmpty) {
      int progress = value[0];
      // You can add a callback here if needed later
      print("Progress update: $progress%");
    }
  }

  void _handleLedUpdate(List<int> value) {
    if (value.isNotEmpty) {
      int ledStateByte = value[0];
      // Convert byte to list of bools (one per LED)
      List<bool> ledStates = [];
      for (int i = 0; i < 5; i++) {
        ledStates.add((ledStateByte & (1 << i)) != 0);
      }
      if (onLedStateChange != null) {
        onLedStateChange!(ledStates);
      }
    }
  }

  Future<List<Map<String, dynamic>>> scanForDevices() async {
    List<Map<String, dynamic>> devices = [];
    
    // Stop any existing scan
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      // Ignore
    }
    
    await Future.delayed(Duration(milliseconds: 100));
    
    // Start scan
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    
    // Collect results
    var subscription = FlutterBluePlus.scanResults.listen((results) {
      print(">>> SCAN RESULTS RECEIVED: ${results.length} results");
  
      for (ScanResult result in results) {
        String deviceName = result.device.platformName;
        
        print(">>> ========== PROCESSING DEVICE: $deviceName ==========");
        
        // Extract serial from manufacturer data OR device name
        String? serial;
        
        print(">>> Checking device: $deviceName");
        print(">>> Advertisement data: ${result.advertisementData.manufacturerData}");

        // Try manufacturer data first
        if (result.advertisementData.manufacturerData.isNotEmpty) {
          var mfgDataMap = result.advertisementData.manufacturerData;
          print(">>> Manufacturer data map: $mfgDataMap");
          
          if (mfgDataMap.containsKey(0xFFFF)) {
            var mfgData = mfgDataMap[0xFFFF]!;
            print(">>> Raw manufacturer data: $mfgData");
            if (mfgData.length >= 3) {
              serial = mfgData.sublist(0, 3)
                .map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0'))
                .join('');
              print(">>> Serial from manufacturer data: $serial");
            }
          } else {
            print(">>> No 0xFFFF key in manufacturer data");
          }
        }

        // Fallback: parse from name (Soven-Coffee-DF5B04)
        if (serial == null && deviceName.contains('-')) {
          var parts = deviceName.split('-');
          if (parts.length >= 3) {
            serial = parts.last.toUpperCase();
            print(">>> Serial from device name: $serial");
          }
        }

        if (serial == null) {
          print(">>> NO SERIAL FOUND for device: $deviceName");
        }
        
        // Only add devices with valid serials
        if (serial != null && serial.length == 6) {
          // Check if already added
          if (!devices.any((d) => d['serial'] == serial)) {
            devices.add({
              'device': result.device,
              'name': deviceName,
              'serial': serial,
            });
            print(">>> Found Soven device: $deviceName (Serial: $serial)");
          }
        }
      }
    });
    
    await Future.delayed(const Duration(seconds: 4));
    await subscription.cancel();
    await FlutterBluePlus.stopScan();
    
    print("BLE scan complete - found ${devices.length} Soven devices");
    return devices;
  }

   Future<bool> connect(BluetoothDevice device) async {
    try {
      await device.connect(timeout: Duration(seconds: 15));
      _device = device;
      
      // Listen for disconnection
      device.connectionState.listen((state) {
        bool connected = (state == BluetoothConnectionState.connected);
        if (onConnectionChange != null) {
          onConnectionChange!(connected);
        }
      });
      
      // Wait for connection to stabilize
      await Future.delayed(Duration(milliseconds: 1000));
      
      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      
      for (BluetoothService service in services) {
        if (service.uuid.toString() == serviceUUID) {
          for (BluetoothCharacteristic char in service.characteristics) {
            String uuid = char.uuid.toString().toLowerCase();
            print(">>> Found characteristic UUID: $uuid");
  
              if (uuid == commandUUID.toLowerCase()) {
                _commandChar = char;
                print("✅ Found command characteristic");
              } else if (uuid == stateUUID.toLowerCase()) {
                _stateChar = char;
                await char.setNotifyValue(true);
                char.lastValueStream.listen(_handleStateUpdate);
                print("✅ Found state characteristic");
              } else if (uuid == tempUUID.toLowerCase()) {
                _tempChar = char;
                await char.setNotifyValue(true);
                char.lastValueStream.listen(_handleTempUpdate);
                print("✅ Found temp characteristic");
              //else if (uuid == progressUUID.toLowerCase()) {
              //  _progressChar = char;
              // await char.setNotifyValue(true);
              // char.lastValueStream.listen(_handleProgressUpdate);
              //  print("✅ Found progress characteristic");
              } else if (uuid == conversationUUID.toLowerCase()) {
                _convoChar = char;
                print("✅ Found conversation characteristic");
              } else if (uuid == ledStateUUID.toLowerCase()) {
                _ledStateChar = char;
                await char.setNotifyValue(true);
                char.lastValueStream.listen(_handleLedUpdate);
                print("✅ Found LED state characteristic");
              }
            }

            // After loop, verify what was found
            print(">>> Characteristics found:");
            print(">>> Command: ${_commandChar != null}");
            print(">>> State: ${_stateChar != null}");
            print(">>> Temp: ${_tempChar != null}");
            print(">>> LED: ${_ledStateChar != null}");
            
        }
      }
      
      print(">>> All characteristics discovered");
      return true;
    } catch (e) {
      print("Connection error: $e");
      return false;
    }
  }

  Future<void> disconnect() async {
    await _device?.disconnect();
    _device = null;
    _commandChar = null;
    _stateChar = null;
    _tempChar = null;
  }

  Future<void> sendCommand(String command) async {
    if (_commandChar != null) {
      try {
        await _commandChar!.write(command.codeUnits);
        print(">>> Sent command: $command");
      } catch (e) {
        print(">>> Error sending command: $e");
        rethrow;
      }
    } else {
      print(">>> ERROR: Command characteristic is null");
      throw Exception("Command characteristic not found");
    }
  }

  Future<String?> getState() async {
    if (_stateChar == null) return null;
    
    try {
      var value = await _stateChar!.read();
      return String.fromCharCodes(value);
    } catch (e) {
      print("State read error: $e");
      return null;
    }
  }

  Future<void> setDeviceName(String name) async {
  // Just use the existing sendCommand method
  await sendCommand('set_name:$name');
  }
  
  Future<void> sendLedState(List<bool> ledStates) async {
    print(">>> sendLedState called with: ${ledStates.map((s) => s ? '1' : '0').join('')}");
    
    if (_ledStateChar == null) {
      print(">>> ERROR: _ledStateChar is NULL - characteristic not found!");
      return;
    }
    
    try {
      // Convert bool list to byte (each LED is a bit)
      int ledByte = 0;
      for (int i = 0; i < ledStates.length && i < 8; i++) {
        if (ledStates[i]) {
          ledByte |= (1 << i);
        }
      }
      
      print(">>> Converting LED states to byte: $ledByte");
      await _ledStateChar!.write([ledByte]);
      print(">>> Sent LED state: ${ledStates.map((s) => s ? '1' : '0').join('')}");
    } catch (e) {
      print(">>> Error sending LED state: $e");
    }
  }
}