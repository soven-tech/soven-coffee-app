## Voice Integration Updates

### Onboarding Flow (Updated)
1. **Welcome** - Introduction
2. **AI Name** - User names the device (e.g., "Frank")
3. **Origin Story** - User describes AI's background
   - Server generates DNA parameters via Ollama
   - Voice selected based on DNA
4. **WiFi Config** - User enters WiFi credentials
   - Sent to device via BLE
   - Device restarts with name + WiFi configured
5. **Completion** - Ready to use

### New Features
- ✅ WiFi provisioning during onboarding
- ✅ DNA-based personality creation from narrative
- ✅ Device restarts with AI name in NVRAM
- ✅ WebSocket audio bridge (future: BLE fallback)

### Files Modified
- `lib/screens/onboarding_screen.dart` - Reordered steps, added WiFi config
- `lib/services/soven_api_service.dart` - Added `createPersonalityWithOrigin()`