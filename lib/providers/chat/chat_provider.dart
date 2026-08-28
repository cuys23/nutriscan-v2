import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nutriscan/models/chat_message.dart';
import 'package:nutriscan/services/ai/groq_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatProvider with ChangeNotifier {
  final GroqService _groqService = GroqService();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _error;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get error => _error;

  ChatProvider() {
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedMessages = prefs.getString('chat_messages');
      if (savedMessages != null) {
        final List<dynamic> decoded = json.decode(savedMessages);
        _messages.clear();
        _messages.addAll(decoded.map((m) => ChatMessage.fromJson(m)));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading chat messages: $e');
    }
  }

  Future<void> _saveMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = json.encode(_messages.map((m) => m.toJson()).toList());
      await prefs.setString('chat_messages', encoded);
    } catch (e) {
      debugPrint('Error saving chat messages: $e');
    }
  }

  Future<void> sendMessage(String content, {
    required String userContext,
    String language = 'en',
  }) async {
    if (content.trim().isEmpty) return;

    final userMessage = ChatMessage(
      content: content,
      role: MessageRole.user,
    );

    _messages.add(userMessage);
    _isLoading = true;
    _error = null;
    notifyListeners();
    _saveMessages();

    try {
      final response = await _groqService.getHealthCoachResponse(
        history: _messages,
        userContext: userContext,
        language: language,
      );

      final assistantMessage = ChatMessage(
        content: response,
        role: MessageRole.assistant,
      );

      _messages.add(assistantMessage);
      _isLoading = false;
      notifyListeners();
      _saveMessages();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearChat() async {
    _messages.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chat_messages');
    notifyListeners();
  }
}
