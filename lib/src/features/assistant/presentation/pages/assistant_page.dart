import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:whoami_app/src/core/theme/app_theme.dart';
import 'package:whoami_app/src/features/assistant/data/assistant_service.dart';

class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key});

  static const route = '/assistant';

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final AssistantService _assistant = AssistantService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  final ImagePicker _picker = ImagePicker();
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  File? _image;

  bool _loading = false;
  bool _speechReady = false;
  bool _listening = false;
  bool _readAssistantResponses = false;
  bool _voiceInputEnabled = true;

  int? _speakingMessageId;
  int? _pausedMessageId;

  String? _currentSpeechText;
  String? _lastSpokenText;

  int _speechBaseOffset = 0;
  int _currentSpeechOffset = 0;
  int _pausedSpeechOffset = 0;

  bool _speechPaused = false;

  final List<Map<String, dynamic>> _items = [
    {
      'id': 1,
      'type': 'message',
      'from': 'assistant',
      'text':
          '¡Hola! Soy tu Asistente personal 🧠💜\nPuedes contarme cómo te sientes, preguntarme por tus recuerdos o enviarme una foto.',
    },
  ];

  int _nextMessageId = 2;

  static const double _inputBarHeight = 92;
  static const double _imagePreviewHeight = 92;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _maybeScrollToBottom(force: true);
      }
    });
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _listening = false);
          }
        },
        onError: (_) {
          if (!mounted) return;
          setState(() => _listening = false);
        },
      );

      if (mounted) {
        setState(() => _speechReady = available);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _speechReady = false);
      }
    }
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('es-MX');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    _tts.setProgressHandler((
      String text,
      int startOffset,
      int endOffset,
      String word,
    ) {
      _currentSpeechOffset = _speechBaseOffset + endOffset;
    });

    _tts.setCompletionHandler(() {
      if (!mounted) return;

      setState(() {
        _speakingMessageId = null;
        _pausedMessageId = null;
        _speechPaused = false;
        _speechBaseOffset = 0;
        _currentSpeechOffset = 0;
        _pausedSpeechOffset = 0;
      });
    });

    _tts.setCancelHandler(() {
      if (!mounted) return;

      setState(() {
        _speakingMessageId = null;
      });
    });

    _tts.setPauseHandler(() {
      if (!mounted) return;

      setState(() {
        _speakingMessageId = null;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    return _scrollController.offset <= 80;
  }

  Future<void> _maybeScrollToBottom({bool force = false}) async {
    await Future.delayed(const Duration(milliseconds: 60));

    if (!_scrollController.hasClients) return;

    if (force || _isNearBottom()) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  void _insertAtBottom(Map<String, dynamic> item) {
    _items.insert(0, item);
    _listKey.currentState?.insertItem(
      0,
      duration: const Duration(milliseconds: 220),
    );
  }

  void _removeTypingIfExists() {
    final typingIndex = _items.indexWhere(
      (item) => item['type'] == 'typing',
    );

    if (typingIndex == -1) return;

    _items.removeAt(typingIndex);

    _listKey.currentState?.removeItem(
      typingIndex,
      (context, animation) => SizeTransition(
        sizeFactor: animation,
        child: const SizedBox.shrink(),
      ),
      duration: const Duration(milliseconds: 180),
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();

    if (text.isEmpty && _image == null) return;

    final imageToSend = _image;
    final shouldStickToBottom = _isNearBottom();

    setState(() => _loading = true);

    _insertAtBottom({
      'id': _nextMessageId++,
      'type': 'message',
      'from': 'user',
      'text': text,
      'image': imageToSend,
    });

    _controller.clear();

    setState(() => _image = null);

    FocusScope.of(context).unfocus();

    await _maybeScrollToBottom(force: shouldStickToBottom);

    _insertAtBottom({
      'id': _nextMessageId++,
      'type': 'typing',
    });

    await _maybeScrollToBottom(force: shouldStickToBottom);

    try {
      final reply = await _assistant.chat(
        text: text,
        image: imageToSend,
      );

      if (!mounted) return;

      _removeTypingIfExists();

      final assistantMessageId = _nextMessageId++;

      _insertAtBottom({
        'id': assistantMessageId,
        'type': 'message',
        'from': 'assistant',
        'text': reply,
      });

      if (_readAssistantResponses) {
        await _speakText(
          messageId: assistantMessageId,
          text: reply,
        );
      }

      await _maybeScrollToBottom(force: shouldStickToBottom);
    } catch (error) {
      if (!mounted) return;

      _removeTypingIfExists();

      _insertAtBottom({
        'id': _nextMessageId++,
        'type': 'message',
        'from': 'assistant',
        'text': '⚠️ Ocurrió un error inesperado.\n\n$error',
      });

      await _maybeScrollToBottom(force: shouldStickToBottom);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _startListening() async {
    if (!_voiceInputEnabled || _loading) return;

    if (!_speechReady) {
      await _initSpeech();
    }

    if (!_speechReady) {
      _showSnack('No se pudo activar el micrófono. Revisa los permisos.');
      return;
    }

    if (_listening) {
      await _stopListening();
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => _listening = true);

    await _speech.listen(
      localeId: 'es_MX',
      listenMode: stt.ListenMode.confirmation,
      partialResults: true,
      onResult: (result) {
        if (!mounted) return;

        setState(() {
          _controller.text = result.recognizedWords;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        });
      },
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();

    if (mounted) {
      setState(() => _listening = false);
    }
  }

  Future<void> _pickImageFromGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (picked == null || !mounted) return;

    setState(() => _image = File(picked.path));

    await _maybeScrollToBottom(force: true);
  }

  Future<void> _pickImageFromCamera() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (picked == null || !mounted) return;

    setState(() => _image = File(picked.path));

    await _maybeScrollToBottom(force: true);
  }

  Future<void> _showImageSourceSheet() async {
    final colors = context.appColors;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Agregar imagen',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: Icon(
                    Icons.photo_camera_rounded,
                    color: colors.secondaryButton,
                  ),
                  title: Text(
                    'Tomar foto',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Usar la cámara',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromCamera();
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.photo_library_rounded,
                    color: colors.primaryButton,
                  ),
                  title: Text(
                    'Elegir de galería',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Seleccionar una imagen existente',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _speakText({
    required int messageId,
    required String text,
  }) async {
    final cleanText = _cleanTextForSpeech(text);

    if (cleanText.isEmpty) return;

    await _tts.stop();

    if (!mounted) return;

    setState(() {
      _speakingMessageId = messageId;
      _pausedMessageId = null;
      _currentSpeechText = cleanText;
      _lastSpokenText = cleanText;
      _speechBaseOffset = 0;
      _currentSpeechOffset = 0;
      _pausedSpeechOffset = 0;
      _speechPaused = false;
    });

    await _tts.speak(cleanText);
  }

  Future<void> _pauseSpeech() async {
    if (_speakingMessageId == null || _currentSpeechText == null) return;

    final pausedId = _speakingMessageId!;
    final pausedOffset = _currentSpeechOffset;

    await _tts.stop();

    if (!mounted) return;

    setState(() {
      _pausedMessageId = pausedId;
      _pausedSpeechOffset = pausedOffset;
      _speakingMessageId = null;
      _speechPaused = true;
    });
  }

  Future<void> _continueSpeech() async {
    if (_pausedMessageId == null || _currentSpeechText == null) return;

    final fullText = _currentSpeechText!;
    final offset = _pausedSpeechOffset.clamp(0, fullText.length);

    final remainingText = fullText.substring(offset).trim();

    if (remainingText.isEmpty) {
      await _stopSpeech();
      return;
    }

    await _tts.stop();

    if (!mounted) return;

    setState(() {
      _speakingMessageId = _pausedMessageId;
      _speechPaused = false;
      _speechBaseOffset = offset;
      _currentSpeechOffset = offset;
    });

    await _tts.speak(remainingText);
  }

  Future<void> _stopSpeech() async {
    await _tts.stop();

    if (mounted) {
      setState(() {
        _speakingMessageId = null;
        _pausedMessageId = null;
        _speechPaused = false;
        _speechBaseOffset = 0;
        _currentSpeechOffset = 0;
        _pausedSpeechOffset = 0;
      });
    }
  }

  Future<void> _restartSpeech(int messageId) async {
    final text = _lastSpokenText;

    if (text == null || text.trim().isEmpty) return;

    await _tts.stop();

    if (!mounted) return;

    setState(() {
      _speakingMessageId = messageId;
      _pausedMessageId = null;
      _currentSpeechText = text;
      _speechBaseOffset = 0;
      _currentSpeechOffset = 0;
      _pausedSpeechOffset = 0;
      _speechPaused = false;
    });

    await _tts.speak(text);
  }

  String _cleanTextForSpeech(String text) {
    return text
        .replaceAll(RegExp(r'\[imagen\].*?\[\/imagen\]', dotAll: true), '')
        .replaceAll('*', '')
        .replaceAll('─', '')
        .trim();
  }

  String? _extraerUrlDeEtiqueta(String text) {
    final regex = RegExp(r'\[imagen\](https[^\[]+)\[\/imagen\]');
    final match = regex.firstMatch(text);
    return match != null ? match.group(1) : null;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openAssistantSettings() async {
    final colors = context.appColors;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 46,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Ajustes del asistente',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: _readAssistantResponses,
                      activeColor: colors.primaryButton,
                      title: Text(
                        'Leer respuestas en voz alta',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        'Muestra controles de voz en cada respuesta.',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                      onChanged: (value) {
                        modalSetState(() {
                          _readAssistantResponses = value;
                        });
                        setState(() {
                          _readAssistantResponses = value;
                        });

                        if (!value) {
                          _stopSpeech();
                        }
                      },
                    ),
                    SwitchListTile(
                      value: _voiceInputEnabled,
                      activeColor: colors.secondaryButton,
                      title: Text(
                        'Activar botón para hablar',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        'Convierte tu voz en texto para enviarlo.',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                      onChanged: (value) {
                        modalSetState(() {
                          _voiceInputEnabled = value;
                        });
                        setState(() {
                          _voiceInputEnabled = value;
                        });

                        if (!value) {
                          _stopListening();
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUserAvatar(BuildContext context) {
    final colors = context.appColors;
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final userPhoto = firebaseUser?.photoURL;

    return CircleAvatar(
      radius: 22,
      backgroundColor:
          context.isDark ? colors.elevatedCard : colors.cardBackground,
      child: userPhoto == null || userPhoto.isEmpty
          ? Icon(
              Icons.person,
              color: colors.textPrimary,
              size: 28,
            )
          : ClipOval(
              child: Image.network(
                userPhoto,
                fit: BoxFit.cover,
                width: 44,
                height: 44,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.person,
                  color: colors.textPrimary,
                  size: 28,
                ),
              ),
            ),
    );
  }

  Widget _buildAssistantAvatar(BuildContext context) {
    final colors = context.appColors;

    return CircleAvatar(
      radius: 22,
      backgroundColor:
          context.isDark ? colors.elevatedCard : colors.cardBackground,
      backgroundImage: const AssetImage('assets/assistant.png'),
      onBackgroundImageError: (_, __) {},
    );
  }

  Widget _buildVoiceControls({
    required int messageId,
    required String text,
  }) {
    if (!_readAssistantResponses) return const SizedBox.shrink();

    final colors = context.appColors;
    final isSpeaking = _speakingMessageId == messageId;
    final isPaused = _pausedMessageId == messageId && _speechPaused;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          _voiceChipButton(
            icon:
                isSpeaking ? Icons.volume_up_rounded : Icons.play_arrow_rounded,
            label: isSpeaking ? 'Leyendo' : 'Leer',
            onTap: () => _speakText(
              messageId: messageId,
              text: text,
            ),
            color: colors.primaryButton,
          ),
          if (isSpeaking)
            _voiceChipButton(
              icon: Icons.pause_rounded,
              label: 'Pausar',
              onTap: _pauseSpeech,
              color: colors.secondaryButton,
            ),
          if (isPaused)
            _voiceChipButton(
              icon: Icons.play_circle_rounded,
              label: 'Continuar',
              onTap: _continueSpeech,
              color: colors.categoryGreen,
            ),
          _voiceChipButton(
            icon: Icons.stop_rounded,
            label: 'Detener',
            onTap: _stopSpeech,
            color: colors.emergency,
          ),
          _voiceChipButton(
            icon: Icons.restart_alt_rounded,
            label: 'Reiniciar',
            onTap: () {
              _lastSpokenText = _cleanTextForSpeech(text);
              _restartSpeech(messageId);
            },
            color: colors.categoryGreen,
          ),
        ],
      ),
    );
  }

  Widget _voiceChipButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    final colors = context.appColors;

    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: context.isDark ? 0.28 : 0.45),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: color.withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colors.textPrimary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    int messageId,
    String text,
    bool isUser,
    File? image,
  ) {
    final colors = context.appColors;
    final imageUrl = _extraerUrlDeEtiqueta(text);

    final cleanText = text
        .replaceAll(RegExp(r'\[imagen\].*?\[\/imagen\]', dotAll: true), '')
        .trim();

    final bubbleColor =
        isUser ? colors.chatUserBubble : colors.chatAssistantBubble;

    final bubbleBorderColor = isUser
        ? colors.secondaryButton.withValues(alpha: 0.45)
        : colors.primaryButton.withValues(alpha: 0.45);

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
              child: _buildAssistantAvatar(context),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft:
                      isUser ? const Radius.circular(18) : Radius.zero,
                  bottomRight:
                      isUser ? Radius.zero : const Radius.circular(18),
                ),
                border: Border.all(
                  color: bubbleBorderColor,
                  width: 1.1,
                ),
                boxShadow: context.isDark
                    ? []
                    : [
                        BoxShadow(
                          color: colors.textPrimary.withValues(alpha: 0.08),
                          blurRadius: 5,
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
                          width: double.infinity,
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
                          errorBuilder: (_, __, ___) => Container(
                            height: 180,
                            width: double.infinity,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colors.inputFill,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'No se pudo cargar la imagen',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (cleanText.isNotEmpty)
                    Text(
                      cleanText,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 16,
                        height: 1.3,
                      ),
                    ),
                  if (!isUser && cleanText.isNotEmpty)
                    _buildVoiceControls(
                      messageId: messageId,
                      text: text,
                    ),
                ],
              ),
            ),
          ),
          if (isUser)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: _buildUserAvatar(context),
            ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12, top: 4),
      child: Row(
        children: [
          _buildAssistantAvatar(context),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.chatAssistantBubble,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(
                color: colors.primaryButton.withValues(alpha: 0.45),
              ),
            ),
            child: Text(
              'Escribiendo...',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedItem(
    BuildContext context,
    int index,
    Animation<double> animation,
  ) {
    final item = _items[index];

    final Widget child;

    if (item['type'] == 'typing') {
      child = _buildTypingIndicator();
    } else {
      final fromUser = item['from'] == 'user';
      final text = (item['text'] ?? '') as String;
      final id = (item['id'] ?? 0) as int;
      final File? img = item['image'] as File?;

      child = _buildMessageBubble(
        id,
        text,
        fromUser,
        img,
      );
    }

    return SizeTransition(
      sizeFactor: animation,
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }

  Widget _buildInputBar() {
    final colors = context.appColors;

    return Material(
      color: colors.pageBackground,
      elevation: 0,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: colors.pageBackground,
            border: Border(
              top: BorderSide(
                color: colors.border.withValues(alpha: 0.7),
              ),
            ),
            boxShadow: context.isDark
                ? []
                : [
                    BoxShadow(
                      color: colors.textPrimary.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, -2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.add_photo_alternate_rounded,
                  color: colors.secondaryButton,
                ),
                onPressed: _loading ? null : _showImageSourceSheet,
              ),
              if (_voiceInputEnabled)
                IconButton(
                  icon: Icon(
                    _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color:
                        _listening ? colors.emergency : colors.primaryButton,
                  ),
                  onPressed: _loading ? null : _startListening,
                ),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 110),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    onTap: () => _maybeScrollToBottom(force: true),
                    minLines: 1,
                    maxLines: 4,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText:
                          _listening ? 'Escuchando...' : 'Escribe algo...',
                      hintStyle: TextStyle(color: colors.textSecondary),
                      filled: true,
                      fillColor: colors.inputFill,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(
                          color: colors.primaryButton,
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: colors.secondaryButton,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _loading ? null : _send,
                  icon: _loading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: colors.secondaryButtonText,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          Icons.send_rounded,
                          color: colors.secondaryButtonText,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedImagePreview() {
    final colors = context.appColors;

    if (_image == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.secondaryButton.withValues(alpha: 0.12),
        border: Border(
          top: BorderSide(color: colors.border),
        ),
      ),
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
          Expanded(
            child: Text(
              'Imagen lista para enviar 📸',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: colors.textPrimary),
            onPressed: () => setState(() => _image = null),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final reservedBottom =
        _inputBarHeight + (_image != null ? _imagePreviewHeight : 0) + 16;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colors.pageBackground,
        title: Text(
          'Asistente',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: colors.textPrimary),
        actions: [
          IconButton(
            tooltip: 'Ajustes del asistente',
            icon: Icon(
              Icons.tune_rounded,
              color: colors.textPrimary,
            ),
            onPressed: _openAssistantSettings,
          ),
        ],
      ),
      bottomSheet: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSelectedImagePreview(),
          _buildInputBar(),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          onVerticalDragStart: (_) => FocusScope.of(context).unfocus(),
          child: AnimatedList(
            key: _listKey,
            controller: _scrollController,
            reverse: true,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 16, 16, reservedBottom),
            initialItemCount: _items.length,
            itemBuilder: (context, index, animation) =>
                _buildAnimatedItem(context, index, animation),
          ),
        ),
      ),
    );
  }
}