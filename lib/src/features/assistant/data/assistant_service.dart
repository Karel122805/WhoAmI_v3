import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';

import 'assistant_context_service.dart';
import 'assistant_gemini_service.dart';
import 'assistant_memory_service.dart';

class AssistantService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final AssistantContextService _contextService = AssistantContextService();
  final AssistantGeminiService _geminiService = AssistantGeminiService();
  final AssistantMemoryService _memoryService = AssistantMemoryService();

  Future<String> chat({
    String? text,
    File? image,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      return 'Debes iniciar sesión primero.';
    }

    final uid = user.uid;
    final cleanText = (text ?? '').trim();
    final lower = cleanText.toLowerCase();

    if (cleanText.isEmpty && image == null) {
      return _saveAndReturn(
        uid: uid,
        userText: text,
        role: '',
        response:
            'Estoy aquí contigo 💜 Puedes saludarme, platicarme cómo te sientes, preguntarme algo o enviarme una foto.',
      );
    }

    final context = await _contextService.buildContext(uid);
    final role = context.role;

    if (_isBlockedTopic(lower)) {
      return _saveAndReturn(
        uid: uid,
        userText: text,
        role: role,
        response:
            'Prefiero ayudarte con algo seguro y útil 💜 Podemos hablar de tus recuerdos, cómo te sientes, tu rutina o hacer un ejercicio sencillo de memoria.',
      );
    }

    final memoryResponse = await _memoryService.tryHandleMemoryFlow(
      uid: uid,
      text: cleanText,
      image: image,
      context: context,
    );

    if (memoryResponse != null) {
      await _contextService.saveAssistantMessage(
        uid: uid,
        userText: text,
        response: memoryResponse,
        role: role,
      );

      return memoryResponse;
    }

    final permanentMemoryResponse =
        await _memoryService.trySaveLongTermMemory(
      uid: uid,
      text: cleanText,
    );

    if (permanentMemoryResponse != null) {
      await _contextService.saveAssistantMessage(
        uid: uid,
        userText: text,
        response: permanentMemoryResponse,
        role: role,
      );

      return permanentMemoryResponse;
    }

    final profileResponse = await _contextService.tryAnswerProfileQuestion(
      uid: uid,
      text: cleanText,
      lower: lower,
      context: context,
    );

    if (profileResponse != null) {
      await _contextService.saveAssistantMessage(
        uid: uid,
        userText: text,
        response: profileResponse,
        role: role,
      );

      return profileResponse;
    }

    final reply = await _geminiService.generateReply(
      text: cleanText,
      image: image,
      context: context,
    );

    await _contextService.saveAssistantMessage(
      uid: uid,
      userText: text,
      response: reply,
      role: role,
    );

    return reply;
  }

  Future<String> _saveAndReturn({
    required String uid,
    required String? userText,
    required String role,
    required String response,
  }) async {
    await _contextService.saveAssistantMessage(
      uid: uid,
      userText: userText,
      response: response,
      role: role,
    );

    return response;
  }

  bool _isBlockedTopic(String lower) {
    const blocked = [
      'sexo',
      'sexual',
      'porno',
      'porn',
      'arma',
      'armas',
      'droga',
      'drogas',
      'matar',
      'suicidio',
      'suicidarme',
      'quitarme la vida',
      'hackear',
      'robar',
      'estafa',
      'bomba',
      'casino',
      'apostar',
    ];

    return blocked.any((word) => lower.contains(word));
  }
}