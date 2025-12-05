import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/assistant_service.dart';
import '../theme.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  // ⭐ NUEVO: Estado para "Escribiendo..."
  bool _typing = false;

  final List<Map<String, dynamic>> _messages = [
    {
      'from': 'assistant',
      'text':
          '¡Hola! Soy tu Asistente personal 🧠💜\nSube una foto de lo que hiciste hoy o cuéntame cómo te sientes.'
    }
  ];

  // ⭐ FUNCION UNIVERSAL PARA BAJAR EL SCROLL AUTOMATICAMENTE
  Future<void> _scrollToBottom() async {
    await Future.delayed(const Duration(milliseconds: 120));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _image == null) return;

    final imageToSend = _image;

    // --- Usuario envía mensaje ---
    setState(() {
      _loading = true;
      _typing = true; // ⭐ MUESTRA "ESCRIBIENDO..."
      _messages.add({'from': 'user', 'text': text, 'image': imageToSend});
      _controller.clear();
      _image = null;
    });

    await _scrollToBottom(); // 🔥 AUTO-SCROLL CUANDO TU ESCRIBES

    try {
      final reply = await _assistant.chat(text: text, image: imageToSend);
      if (!mounted) return;

      setState(() {
        _messages.add({'from': 'assistant', 'text': reply});
      });

      await _scrollToBottom(); // 🔥 AUTO-SCROLL CUANDO RESPONDE
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _messages.add({
          'from': 'assistant',
          'text': '⚠️ Ocurrió un error inesperado.\n\n$e'
        });
      });

      await _scrollToBottom(); // 🔥 TAMBIÉN SI HAY ERROR
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _typing = false; // ⭐ OCULTA "ESCRIBIENDO..."
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null && mounted) {
      setState(() => _image = File(picked.path));
    }
  }

  String? _extraerUrlDeEtiqueta(String text) {
    final regex = RegExp(r'\[imagen\](https[^\[]+)\[\/imagen\]');
    final match = regex.firstMatch(text);
    return match != null ? match.group(1) : null;
  }

  // ⭐⭐ BURBUJA COMPLETA CON ICONO DE USUARIO SI NO TIENE FOTO ⭐⭐
  Widget _buildMessageBubble(String text, bool isUser, File? image) {
    final imageUrl = _extraerUrlDeEtiqueta(text);
    final cleanText = text.replaceAll(
      RegExp(r'\[imagen\].*?\[\/imagen\]', dotAll: true),
      '',
    ).trim();

    final bubbleColor = isUser ? kPurple : kBlue;

    // FOTO DEL FIREBASE USER
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final userPhoto = firebaseUser?.photoURL;

    // AVATAR DEL USUARIO (ICONO POR DEFECTO SI NO TIENE FOTO)
    final userAvatar = CircleAvatar(
      radius: 22,
      backgroundColor: Colors.white,
      child: userPhoto == null || userPhoto.isEmpty
          ? const Icon(Icons.person, color: Colors.black, size: 28)
          : ClipOval(
              child: Image.network(
                userPhoto,
                fit: BoxFit.cover,
                width: 44,
                height: 44,
              ),
            ),
    );

    // AVATAR DEL ASISTENTE
    final assistantAvatar = CircleAvatar(
      radius: 22,
      backgroundColor: Colors.white,
      backgroundImage: const AssetImage('assets/assistant.png'),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: assistantAvatar,
            ),

          // ⭐ Contenedor principal del mensaje
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
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
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(2, 2),
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
                        child: Image.file(
                          image,
                          height: 140,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                  if (imageUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          imageUrl,
                          height: 180,
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
                        height: 1.3,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ⭐ AVATAR DEL USUARIO A LA DERECHA
          if (isUser)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: userAvatar,
            ),
        ],
      ),
    );
  }

  // ⭐⭐ BURBUJA "ESCRIBIENDO…" ⭐⭐
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12, top: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white,
            backgroundImage: const AssetImage('assets/assistant.png'),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: kBlue,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: const [
                Text(
                  "Escribiendo",
                  style: TextStyle(color: kInk, fontSize: 15),
                ),
                SizedBox(width: 6),
                SizedBox(
                  width: 22,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(kInk),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Asistente',
          style: TextStyle(
            color: kInk,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: kInk),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                physics: const BouncingScrollPhysics(),
                children: [
                  for (var msg in _messages)
                    _buildMessageBubble(
                      msg['text'],
                      msg['from'] == 'user',
                      msg['image'],
                    ),

                  if (_typing) _buildTypingIndicator(), // ⭐ AQUI SE AGREGA
                ],
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
                      child: Image.file(
                        _image!,
                        height: 60,
                        width: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        "Imagen lista para enviar 📸",
                        style: TextStyle(
                            color: kInk, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: kInk),
                      onPressed: () => setState(() => _image = null),
                    ),
                  ],
                ),
              ),

            // ⭐ INPUT BAR
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.photo, color: kPurple),
                    onPressed: _pickImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Escribe algo...',
                        hintStyle: TextStyle(color: kGrey1),
                        filled: true,
                        fillColor: const Color(0xFFF4F4F4),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
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
                      onPressed: _loading ? null : _send,
                      icon: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: kInk, strokeWidth: 2),
                            )
                          : const Icon(Icons.send, color: kInk),
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
