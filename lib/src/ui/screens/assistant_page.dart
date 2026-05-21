import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  File? _image;
  bool _loading = false;

  final List<Map<String, dynamic>> _items = [
    {
      'type': 'message',
      'from': 'assistant',
      'text':
          '¡Hola! Soy tu Asistente personal 🧠💜\nSube una foto de lo que hiciste hoy o cuéntame cómo te sientes.',
    }
  ];

  static const double _inputBarHeight = 84;
  static const double _imagePreviewHeight = 92;

  @override
  void initState() {
    super.initState();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _maybeScrollToBottom(force: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
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
    final typingIndex = _items.indexWhere((e) => e['type'] == 'typing');
    if (typingIndex != -1) {
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
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _image == null) return;

    final imageToSend = _image;
    final shouldStickToBottom = _isNearBottom();

    setState(() => _loading = true);

    _insertAtBottom({
      'type': 'message',
      'from': 'user',
      'text': text,
      'image': imageToSend,
    });

    _controller.clear();
    setState(() => _image = null);

    FocusScope.of(context).unfocus();
    await _maybeScrollToBottom(force: shouldStickToBottom);

    _insertAtBottom({'type': 'typing'});
    await _maybeScrollToBottom(force: shouldStickToBottom);

    try {
      final reply = await _assistant.chat(text: text, image: imageToSend);
      if (!mounted) return;

      _removeTypingIfExists();

      _insertAtBottom({
        'type': 'message',
        'from': 'assistant',
        'text': reply,
      });

      await _maybeScrollToBottom(force: shouldStickToBottom);
    } catch (e) {
      if (!mounted) return;

      _removeTypingIfExists();

      _insertAtBottom({
        'type': 'message',
        'from': 'assistant',
        'text': '⚠️ Ocurrió un error inesperado.\n\n$e',
      });

      await _maybeScrollToBottom(force: shouldStickToBottom);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null && mounted) {
      setState(() => _image = File(picked.path));
      await _maybeScrollToBottom(force: true);
    }
  }

  String? _extraerUrlDeEtiqueta(String text) {
    final regex = RegExp(r'\[imagen\](https[^\[]+)\[\/imagen\]');
    final match = regex.firstMatch(text);
    return match != null ? match.group(1) : null;
  }

  Widget _buildUserAvatar(BuildContext context) {
    final colors = context.appColors;
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final userPhoto = firebaseUser?.photoURL;

    return CircleAvatar(
      radius: 22,
      backgroundColor: context.isDark
          ? colors.elevatedCard
          : colors.cardBackground,
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
      backgroundColor: context.isDark
          ? colors.elevatedCard
          : colors.cardBackground,
      backgroundImage: const AssetImage('assets/assistant.png'),
      onBackgroundImageError: (_, __) {},
      child: null,
    );
  }

  Widget _buildMessageBubble(String text, bool isUser, File? image) {
    final colors = context.appColors;
    final imageUrl = _extraerUrlDeEtiqueta(text);

    final cleanText = text
        .replaceAll(
          RegExp(r'\[imagen\].*?\[\/imagen\]', dotAll: true),
          '',
        )
        .trim();

    final bubbleColor = isUser
        ? colors.chatUserBubble
        : colors.chatAssistantBubble;

    final bubbleTextColor = colors.textPrimary;

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
                  bottomLeft: isUser ? const Radius.circular(18) : Radius.zero,
                  bottomRight: isUser ? Radius.zero : const Radius.circular(18),
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
                        color: bubbleTextColor,
                        fontSize: 16,
                        height: 1.3,
                      ),
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
            child: Row(
              children: [
                Text(
                  'Escribiendo',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 24,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colors.textPrimary,
                    ),
                  ),
                ),
              ],
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

    Widget child;
    if (item['type'] == 'typing') {
      child = _buildTypingIndicator();
    } else {
      final fromUser = item['from'] == 'user';
      final text = (item['text'] ?? '') as String;
      final File? img = item['image'] as File?;
      child = _buildMessageBubble(text, fromUser, img);
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                icon: Icon(Icons.photo, color: colors.secondaryButton),
                onPressed: _pickImage,
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
                      hintText: 'Escribe algo...',
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
                          Icons.send,
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
            icon: Icon(Icons.close, color: colors.textPrimary),
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
      ),
      bottomSheet: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSelectedImagePreview(),
          _buildInputBar(),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
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
          ],
        ),
      ),
    );
  }
}