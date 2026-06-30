import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

import 'assistant_context_service.dart';

class AssistantMemoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const String _timezone = 'America/Mexico_City';
  static const String _weeklyCadence = 'weekly';

  Future<String?> tryHandleMemoryFlow({
    required String uid,
    required String text,
    required File? image,
    required AssistantContext context,
  }) async {
    try {
      final cleanText = text.trim();
      final lower = cleanText.toLowerCase();

      final pending = await _getPendingMemory(uid);

      final wantsSave = _wantsToSaveMemory(lower);
      final wantsCancel = _wantsToCancel(lower);

      if (wantsCancel) {
        await _deletePendingMemory(uid);
        return 'Claro, cancelé el recuerdo pendiente 💜';
      }

      if (!wantsSave && pending == null) {
        return null;
      }

      final current = pending == null
          ? _newPendingMemory()
          : Map<String, dynamic>.from(pending);

      String description = _safeText(current['description']);
      String imageUrl = _safeText(current['imageUrl']);
      String imageStoragePath = _safeText(current['imageStoragePath']);

      final extractedDescription = _extractDescription(cleanText);

      if (extractedDescription.isNotEmpty) {
        description = extractedDescription;
        current['description'] = description;
      }

      if (image != null) {
        final uploaded = await _uploadMemoryImage(
          uid: uid,
          image: image,
        );

        imageUrl = uploaded['url'] ?? '';
        imageStoragePath = uploaded['path'] ?? '';

        current['imageUrl'] = imageUrl;
        current['imageStoragePath'] = imageStoragePath;
      }

      current['description'] = description;
      current['imageUrl'] = imageUrl;
      current['imageStoragePath'] = imageStoragePath;
      current['updatedAt'] = FieldValue.serverTimestamp();

      await _savePendingMemory(uid, current);

      if (description.isEmpty && imageUrl.isEmpty) {
        return 'Sí, puedo guardar un recuerdo 💜\n\nPuedes darme primero la descripción o la foto. Necesito ambas para guardarlo.';
      }

      if (description.isEmpty) {
        return 'Ya tengo la foto 💜\n\nSolo me falta la descripción del recuerdo. ¿Qué quieres que escriba?';
      }

      if (imageUrl.isEmpty) {
        return 'Ya tengo la descripción:\n\n"$description"\n\nAhora mándame una foto tomada con cámara o seleccionada de galería.';
      }

      final saved = await _saveFinalMemory(
        uid: uid,
        description: description,
        imageUrl: imageUrl,
        imageStoragePath: imageStoragePath,
      );

      await _deletePendingMemory(uid);

      return 'Listo 💜 Guardé este recuerdo en tu calendario:\n\n'
          '📝 $description\n\n'
          '[imagen]${saved['imageUrl']}[/imagen]';
    } catch (_) {
      return 'No pude guardar el recuerdo en este momento 💛\n\nIntenta de nuevo en unos segundos.';
    }
  }
    Future<String?> trySaveLongTermMemory({
    required String uid,
    required String text,
  }) async {
    final clean = text.trim();
    final lower = clean.toLowerCase();

    if (clean.isEmpty) return null;

    final shouldRemember = lower.startsWith('recuerda que ') ||
        lower.startsWith('quiero recordar que ') ||
        lower.startsWith('mi ') ||
        lower.startsWith('mis ') ||
        lower.startsWith('me gusta ') ||
        lower.startsWith('me gustan ');

    if (!shouldRemember) return null;

    String key = '';
    String value = '';

    final familyMatch = RegExp(
      r'^(mi|mis)\s+(.+?)\s+(se llama|se llaman)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(clean);

    if (familyMatch != null) {
      key = _safeText(familyMatch.group(2));
      value = _safeText(familyMatch.group(4));
    } else if (lower.startsWith('me gusta ') ||
        lower.startsWith('me gustan ')) {
      key = 'gusto';
      value = clean
          .replaceFirst(RegExp(r'^me gustan?\s+', caseSensitive: false), '')
          .trim();
    } else if (lower.startsWith('quiero recordar que ')) {
      key = 'dato importante';
      value = clean
          .replaceFirst(
            RegExp(r'^quiero recordar que\s+', caseSensitive: false),
            '',
          )
          .trim();
    } else if (lower.startsWith('recuerda que ')) {
      key = 'dato importante';
      value = clean
          .replaceFirst(
            RegExp(r'^recuerda que\s+', caseSensitive: false),
            '',
          )
          .trim();
    }

    if (key.isEmpty || value.isEmpty) return null;

    await _firestore
        .collection('assistant')
        .doc(uid)
        .collection('long_term_memory')
        .add({
      'key': key,
      'value': value,
      'sourceText': clean,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return 'Lo voy a recordar 💜\n\n$key: $value';
  }

  Map<String, dynamic> _newPendingMemory() {
    return {
      'status': 'draft',
      'description': '',
      'imageUrl': '',
      'imageStoragePath': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<Map<String, dynamic>?> _getPendingMemory(String uid) async {
    final doc = await _firestore
        .collection('assistant')
        .doc(uid)
        .collection('state')
        .doc('pending_memory')
        .get();

    return doc.data();
  }

  Future<void> _savePendingMemory(
    String uid,
    Map<String, dynamic> data,
  ) async {
    await _firestore
        .collection('assistant')
        .doc(uid)
        .collection('state')
        .doc('pending_memory')
        .set(data, SetOptions(merge: true));
  }

  Future<void> _deletePendingMemory(String uid) async {
    await _firestore
        .collection('assistant')
        .doc(uid)
        .collection('state')
        .doc('pending_memory')
        .delete();
  }

  Future<Map<String, String>> _uploadMemoryImage({
    required String uid,
    required File image,
  }) async {
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final path = 'assistant_pending_memories/$uid/$tempId.jpg';

    final ref = _storage.ref().child(path);

    await ref.putFile(
      image,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    final url = await ref.getDownloadURL();

    return {
      'url': url,
      'path': path,
    };
  }
    Future<Map<String, String>> _saveFinalMemory({
    required String uid,
    required String description,
    required String imageUrl,
    required String imageStoragePath,
  }) async {
    final now = DateTime.now();
    final nextAt = now.add(const Duration(days: 7));

    final docRef = _firestore
        .collection('memories')
        .doc(uid)
        .collection('user_memories')
        .doc();

    final data = {
      'text': description.trim(),
      'description': description.trim(),
      'imageUrl': imageUrl.trim(),
      'imageStoragePath': imageStoragePath.trim(),
      'displayDate': DateFormat('yyyy-MM-dd').format(now),
      'reminder': {
        'enabled': true,
        'cadence': _weeklyCadence,
        'time': DateFormat('HH:mm').format(nextAt),
        'timezone': _timezone,
        'nextAt': Timestamp.fromDate(nextAt),
        'read': false,
        'deleted': false,
        'completed': false,
      },
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': FieldValue.serverTimestamp(),
      'source': 'assistant',
    };

    await docRef.set(data);

    final checkDoc = await docRef.get();

    if (!checkDoc.exists) {
      throw Exception(
        'Firestore no confirmó el guardado en memories/$uid/user_memories/${docRef.id}',
      );
    }

    return {
      'id': docRef.id,
      'path': 'memories/$uid/user_memories/${docRef.id}',
      'imageUrl': imageUrl,
    };
  }

  bool _wantsToSaveMemory(String lower) {
    return lower.contains('guardar recuerdo') ||
        lower.contains('guarda este recuerdo') ||
        lower.contains('guardar este recuerdo') ||
        lower.contains('guardar esta foto') ||
        lower.contains('guardar este momento') ||
        lower.contains('guardar en calendario') ||
        lower.contains('guardar en el calendario') ||
        lower.contains('guárdalo como recuerdo') ||
        lower.contains('guardalo como recuerdo') ||
        lower.contains('quiero guardar este recuerdo');
  }

  bool _wantsToCancel(String lower) {
    return lower.contains('cancelar recuerdo') ||
        lower.contains('cancela el recuerdo') ||
        lower.contains('no guardar') ||
        lower.contains('no lo guardes') ||
        lower.contains('ya no quiero guardarlo') ||
        lower.contains('olvídalo') ||
        lower.contains('olvidalo');
  }

  String _extractDescription(String text) {
    final clean = text.trim();
    final lower = clean.toLowerCase();

    if (clean.isEmpty) return '';

    if (_wantsToSaveMemory(lower) || _wantsToCancel(lower)) {
      return '';
    }

    if (lower.contains('cuál te doy primero') ||
        lower.contains('cual te doy primero') ||
        lower.contains('qué te doy primero') ||
        lower.contains('que te doy primero')) {
      return '';
    }

    if (clean.length < 4) return '';

    return clean;
  }

  String _safeText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }
}