import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AssistantContext {
  final String uid;
  final String firstName;
  final String lastName;
  final String displayName;
  final String role;
  final String address;
  final DateTime? birthday;
  final List<Map<String, dynamic>> recentHistory;
  final List<Map<String, dynamic>> recentMemories;
  final List<Map<String, dynamic>> reminders;
  final List<Map<String, dynamic>> supportContacts;
  final List<Map<String, dynamic>> longTermMemory;

  const AssistantContext({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.displayName,
    required this.role,
    required this.address,
    required this.birthday,
    required this.recentHistory,
    required this.recentMemories,
    required this.reminders,
    required this.supportContacts,
    required this.longTermMemory,
  });
}

class AssistantContextService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<AssistantContext> buildContext(String uid) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? <String, dynamic>{};

    final firstName = _safeText(userData['firstName']);
    final lastName = _safeText(userData['lastName']);
    final displayName = '$firstName $lastName'.trim();
    final role = _safeText(userData['role']).toLowerCase();

    final address = _safeText(
      userData['address'] ??
          userData['direccion'] ??
          userData['domicilio'] ??
          userData['location'],
    );

    return AssistantContext(
      uid: uid,
      firstName: firstName,
      lastName: lastName,
      displayName: displayName,
      role: role,
      address: address,
      birthday: _readDate(userData['birthday']),
      recentHistory: await _getRecentHistory(uid),
      recentMemories: await _getRecentMemories(uid),
      reminders: await _getUpcomingReminders(uid),
      supportContacts: await _getSupportContacts(uid),
      longTermMemory: await _getLongTermMemory(uid),
    );
  }

  Future<void> saveAssistantMessage({
    required String uid,
    required String? userText,
    required String response,
    required String role,
  }) async {
    await _firestore.collection('assistant').doc(uid).collection('messages').add({
      'mensaje': (userText != null && userText.trim().isNotEmpty)
          ? userText.trim()
          : '[foto]',
      'respuesta': response,
      'role': role,
      'fecha': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String?> tryAnswerProfileQuestion({
    required String uid,
    required String text,
    required String lower,
    required AssistantContext context,
  }) async {
    if (_asksRole(lower)) {
      if (context.role == 'cuidador') {
        return 'Tu rol dentro de la app es Cuidador 💚';
      }

      if (context.role == 'consultante' || context.role == 'paciente') {
        return 'Tu rol dentro de la app es Consultante 💙';
      }

      return 'Aún no tengo registrado tu rol dentro de la app 🕯️';
    }

    if (_asksAge(lower)) {
      if (context.birthday == null) {
        return 'No tengo registrada tu fecha de nacimiento 💛';
      }

      return 'Tienes ${_calculateAge(context.birthday!)} años${context.firstName.isNotEmpty ? ', ${context.firstName}' : ''} 💜';
    }

    if (_asksBirthday(lower)) {
      if (context.birthday == null) {
        return 'No tengo tu cumpleaños registrado 💛';
      }

      return 'Tu cumpleaños está registrado el ${DateFormat('dd/MM').format(context.birthday!)} 🎉💜';
    }

    if (_asksAddress(lower)) {
      if (context.address.isEmpty) {
        return 'No tengo tu dirección registrada 💛';
      }

      return 'Tu dirección registrada es:\n\n${context.address} 🏠';
    }

    if (_asksMemories(lower)) {
      if (context.recentMemories.isEmpty) {
        return 'Aún no encontré recuerdos guardados 💜';
      }

      final buffer = StringBuffer('Estos son algunos de tus recuerdos más recientes 💜\n\n');

      for (final memory in context.recentMemories) {
        final description = _safeText(
          memory['text'] ?? memory['descripcion'] ?? memory['description'],
        );
        final imageUrl = _safeText(memory['imageUrl']);
        final createdAt = _readDate(memory['createdAt']);

        buffer.writeln('📅 ${createdAt != null ? DateFormat('dd/MM/yyyy').format(createdAt) : 'Sin fecha'}');
        buffer.writeln('📝 ${description.isNotEmpty ? description : '(sin descripción)'}');

        if (imageUrl.isNotEmpty) {
          buffer.writeln('[imagen]$imageUrl[/imagen]');
        }

        buffer.writeln('──────────────');
      }

      return buffer.toString().trim();
    }

    return null;
  }

  String buildReadableContext(AssistantContext context) {
    final buffer = StringBuffer();

    buffer.writeln('Nombre: ${context.displayName.isNotEmpty ? context.displayName : 'No registrado'}');
    buffer.writeln('Rol: ${context.role.isNotEmpty ? context.role : 'No registrado'}');
    buffer.writeln('Dirección: ${context.address.isNotEmpty ? context.address : 'No registrada'}');

    if (context.birthday != null) {
      buffer.writeln('Fecha de nacimiento: ${DateFormat('dd/MM/yyyy').format(context.birthday!)}');
      buffer.writeln('Edad: ${_calculateAge(context.birthday!)}');
    }

    if (context.longTermMemory.isNotEmpty) {
      buffer.writeln('\nDatos que el usuario pidió recordar:');
      for (final item in context.longTermMemory) {
        final key = _safeText(item['key']);
        final value = _safeText(item['value']);
        if (key.isNotEmpty && value.isNotEmpty) {
          buffer.writeln('- $key: $value');
        }
      }
    }

    if (context.recentMemories.isNotEmpty) {
      buffer.writeln('\nRecuerdos recientes:');
      for (final item in context.recentMemories) {
        final description = _safeText(item['text'] ?? item['description']);
        buffer.writeln('- ${description.isNotEmpty ? description : 'Recuerdo sin descripción'}');
      }
    }

    if (context.reminders.isNotEmpty) {
      buffer.writeln('\nRecordatorios próximos:');
      for (final item in context.reminders) {
        final title = _safeText(item['title'] ?? item['titulo'] ?? item['text']);
        buffer.writeln('- ${title.isNotEmpty ? title : 'Recordatorio'}');
      }
    }

    if (context.supportContacts.isNotEmpty) {
      buffer.writeln('\nContactos de apoyo:');
      for (final item in context.supportContacts) {
        final name = _safeText(item['name'] ?? item['nombre']);
        final phone = _safeText(item['phone'] ?? item['telefono']);
        buffer.writeln('- ${name.isNotEmpty ? name : 'Contacto'}${phone.isNotEmpty ? ': $phone' : ''}');
      }
    }

    return buffer.toString().trim();
  }

  String buildHistoryText(AssistantContext context) {
    if (context.recentHistory.isEmpty) return 'Sin historial reciente.';

    final buffer = StringBuffer();

    for (final item in context.recentHistory) {
      final user = _safeText(item['mensaje']);
      final assistant = _safeText(item['respuesta'])
          .replaceAll(RegExp(r'\[imagen\].*?\[\/imagen\]', dotAll: true), '')
          .trim();

      if (user.isNotEmpty) buffer.writeln('Usuario: $user');
      if (assistant.isNotEmpty) buffer.writeln('Memora: $assistant');
    }

    return buffer.toString().trim();
  }

  Future<List<Map<String, dynamic>>> _getRecentHistory(String uid) async {
    try {
      final snap = await _firestore
          .collection('assistant')
          .doc(uid)
          .collection('messages')
          .orderBy('fecha', descending: true)
          .limit(12)
          .get();

      return snap.docs.map((d) => d.data()).toList().reversed.toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getRecentMemories(String uid) async {
    try {
      final snap = await _firestore
          .collection('memories')
          .doc(uid)
          .collection('user_memories')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      return snap.docs.map((d) => d.data()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getUpcomingReminders(String uid) async {
    try {
      final snap = await _firestore
          .collection('reminders')
          .where('userId', isEqualTo: uid)
          .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
          .orderBy('dateTime')
          .limit(5)
          .get();

      return snap.docs.map((d) => d.data()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getSupportContacts(String uid) async {
    try {
      final snap = await _firestore
          .collection('supportContacts')
          .where('userId', isEqualTo: uid)
          .limit(5)
          .get();

      return snap.docs.map((d) => d.data()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getLongTermMemory(String uid) async {
    try {
      final snap = await _firestore
          .collection('assistant')
          .doc(uid)
          .collection('long_term_memory')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      return snap.docs.map((d) => d.data()).toList();
    } catch (_) {
      return [];
    }
  }

  bool _asksRole(String lower) =>
      lower.contains('mi rol') ||
      lower.contains('qué soy') ||
      lower.contains('que soy') ||
      lower.contains('quién soy') ||
      lower.contains('quien soy');

  bool _asksAge(String lower) =>
      lower.contains('qué edad tengo') ||
      lower.contains('que edad tengo') ||
      lower.contains('cuántos años tengo') ||
      lower.contains('cuantos años tengo');

  bool _asksBirthday(String lower) =>
      lower.contains('mi cumpleaños') ||
      lower.contains('cuando cumplo') ||
      lower.contains('cuándo cumplo');

  bool _asksAddress(String lower) =>
      lower.contains('mi dirección') ||
      lower.contains('mi direccion') ||
      lower.contains('dónde vivo') ||
      lower.contains('donde vivo');

  bool _asksMemories(String lower) =>
      lower.contains('mis recuerdos') ||
      lower.contains('ver recuerdos') ||
      lower.contains('qué recuerdos tengo') ||
      lower.contains('que recuerdos tengo');

  DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  int _calculateAge(DateTime birthday) {
    final now = DateTime.now();
    int age = now.year - birthday.year;

    if (now.month < birthday.month ||
        (now.month == birthday.month && now.day < birthday.day)) {
      age--;
    }

    return age;
  }

  String _safeText(dynamic value) => value == null ? '' : value.toString().trim();
}