import 'dart:convert';
import 'package:http/http.dart' as http;

class OllamaService {
  final String baseUrl;
  final String model;
  
  OllamaService({
    this.baseUrl = 'http://192.168.40.10:11434', // Your PC IP from previous chat
    this.model = 'llama3.2:latest', // Or whatever model you have
  });

    Future<String> chat(List<Map<String, String>> conversationHistory) async {
    try {
      print(">>> Ollama request: ${jsonEncode({
        'model': model,
        'messages': conversationHistory.length > 5 
            ? conversationHistory.sublist(conversationHistory.length - 5) 
            : conversationHistory,
        'stream': false,
      })}");
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': model,
          'messages': conversationHistory,
          'stream': false,
        }),
      );

      print(">>> Ollama status code: ${response.statusCode}");
      print(">>> Ollama raw response: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print(">>> Parsed data: $data");
        print(">>> Message content: ${data['message']['content']}");
        return data['message']['content'];
      } else {
        return "Yo, my brain's offline right now. Try again?";
      }
    } catch (e) {
      print('>>> Ollama error: $e');
      return "Can't think straight right now. Connection issues.";
    }
  }
  
}