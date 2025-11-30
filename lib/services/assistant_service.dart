import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/assistant_service.dart';
import '../theme.dart';

class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key});
  static const route = '/assistant';

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final _assistant = AssistantService();
  final _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  File? _image;
  bool _loading = false;

  final List<Map<String, dynamic>> _messages = [
    {
      'from': 'assistant',
      'text':
          '¡Hola! Soy tu asistente personal 🧠💜\nSube una foto de lo que hiciste hoy o cuéntame cómo te sientes.'
    }
  ];

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _image == null) return;

    final imageToSend = _image;

    setState(() {
      _loading = true;
      _messages.add({'from': 'user', 'text': text, 'image': imageToSend});
      _controller.clear();
      _image = null;
    });

    await Future.delayed(const Duration(milliseconds: 200));
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 100,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );

    try {
      final reply = await _assistant.chat(text: text, image: imageToSend);
      if (!mounted) return;
      setState(() {
        _messages.add({'from': 'assistant', 'text': reply});
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add({
          'from': 'assistant',
          'text': '⚠️ Ocurrió un error inesperado.\n\n$e'
        });
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null && mounted) {
      setState(() => _image = File(picked.path));
    }
  }

  String? _extraerUrlDeEtiqueta(String text) {
    final regex = RegExp(r'\[imagen\](https[^\[]+)\[\/imagen\]');
    final match = regex.firstMatch(text);
    return match?.group(1);
  }

  Widget _buildMessageBubble(String text, bool isUser, File? image) {
    final imageUrl = _extraerUrlDeEtiqueta(text);
    final cleanText =
        text.replaceAll(RegExp(r'\[imagen\].*?\[\/imagen\]', dotAll: true), '').trim();

    final bubbleColor = isUser ? kPurple : kBlue;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: isUser ? const Radius.circular(18) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              offset: const Offset(2, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (image != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(image, height: 150, fit: BoxFit.cover),
                ),
              ),

            if (imageUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    height: 170,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            if (cleanText.isNotEmpty)
              Text(
                cleanText,
                style: const TextStyle(
                  color: kInk,
                  fontSize: 16,
                  height: 1.25,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: kInk),
        title: const Text(
          'Asistente',
          style: TextStyle(
            color: kInk,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                physics: const BouncingScrollPhysics(),
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final msg = _messages[i];
                  return _buildMessageBubble(
                    msg['text'] ?? '',
                    msg['from'] == 'user',
                    msg['image'],
                  );
                },
              ),
            ),

            if (_image != null)
              Container(
                padding: const EdgeInsets.all(8),
                color: kPurple.withOpacity(0.12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_image!, height: 60, width: 60, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        "Imagen lista para enviar 📸",
                        style: TextStyle(color: kInk, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: kInk),
                      onPressed: () => setState(() => _image = null),
                    ),
                  ],
                ),
              ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(color: Colors.white),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.photo, color: kPurple),
                    onPressed: _pickImage,
                  ),

                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Escribe algo...',
                        filled: true,
                        fillColor: const Color(0xFFF4F4F4),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Container(
                    height: 48,
                    width: 48,
                    decoration: const BoxDecoration(
                      color: kPurple,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _loading
                          ? const CircularProgressIndicator(color: kInk, strokeWidth: 2)
                          : const Icon(Icons.send, color: kInk),
                      onPressed: _loading ? null : _send,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            .collection('memories')
        .doc(uid)
        .collection('user_memories')
        .where('date', isGreaterThanOrEqualTo: inicio.toIso8601String())
        .where('date', isLessThan: fin.toIso8601String())
        .get();

    if (query.docs.isEmpty) {
      final altQuery = await _firestore
          .collection('memories')
          .doc(uid)
          .collection('user_memories')
          .where('date', isGreaterThanOrEqualTo: inicio)
          .where('date', isLessThan: fin)
          .get();
      return altQuery.docs.map((d) => d.data()).toList();
    }

    return query.docs.map((d) => d.data()).toList();
  }

  DateTime? _extraerFechaFlexible(String text) {
    text = text.toLowerCase().trim();
    final ahora = DateTime.now();
    if (text.contains('hoy')) return ahora;
    if (text.contains('ayer')) return ahora.subtract(const Duration(days: 1));
    if (text.contains('antier') || text.contains('antes de ayer')) {
      return ahora.subtract(const Duration(days: 2));
    }

    final numeric = RegExp(r'(\d{1,2})[\/\- ](\d{1,2})[\/\- ](\d{2,4})');
    final numMatch = numeric.firstMatch(text);
    if (numMatch != null) {
      final d = int.parse(numMatch.group(1)!);
      final m = int.parse(numMatch.group(2)!);
      final y = int.parse(
          numMatch.group(3)!.length == 2 ? '20${numMatch.group(3)!}' : numMatch.group(3)!);
      return DateTime(y, m, d);
    }

    const meses = {
      'enero': 1, 'febrero': 2, 'marzo': 3, 'abril': 4, 'mayo': 5,
      'junio': 6, 'julio': 7, 'agosto': 8, 'septiembre': 9,
      'octubre': 10, 'noviembre': 11, 'diciembre': 12,
    };

    final textoNormal = RegExp(
      r'(\d{1,2})[ ]?(de)?[ ]?([a-záéíóú]+)[ ]?(de)?[ ]?(\d{2,4})?',
      caseSensitive: false,
    );
    final match1 = textoNormal.firstMatch(text);
    if (match1 != null) {
      final dia = int.parse(match1.group(1)!);
      final mes = meses[match1.group(3)!] ?? 1;
      final anio = int.tryParse(match1.group(5) ?? '') ?? DateTime.now().year;
      return DateTime(anio, mes, dia);
    }
    return null;
  }

  String _formatearFecha(DateTime fecha) =>
      DateFormat('dd/MM/yyyy').format(fecha);
}
