import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';

class AssistantService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  final _gemini = GenerativeModel(
    model: 'gemini-2.0-flash',
    apiKey: 'AIzaSyDqXK7eVedTcy8brlvRwawwgNDAjGwY1qA',
  );

  /// 🧠 Chat principal del asistente
  Future<String> chat({String? text, File? image}) async {
    final user = _auth.currentUser;
    if (user == null) return 'Debes iniciar sesión primero.';
    final uid = user.uid;

    // === Datos del usuario ===
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};

    final firstName = userData['firstName'] ?? '';
    final lastName = userData['lastName'] ?? '';
    final role = (userData['role'] ?? '').toLowerCase();
    final caregiverId = userData['caregiverId'];
    final displayName = "$firstName $lastName".trim();
    final lower = (text ?? '').toLowerCase().trim();

    // === Contexto anterior (memoria a corto plazo) ===
    final lastContext = await _obtenerUltimoContexto(uid);
    String contextoPrevio = '';
    if (lastContext != null) {
      contextoPrevio =
          "La última vez me dijiste: '${lastContext['mensaje']}'. Yo respondí: '${lastContext['respuesta']}'.";
    }

    // === Identidad e información personal ===
    if (lower.contains('como me llamo') || lower.contains('quien soy')) {
      final respuesta = "Te llamas $displayName 💜 y eres una persona muy importante. "
          "Nunca olvides que tu historia y tus recuerdos te definen.";
      await _guardarMensaje(uid, text, respuesta);
      return respuesta;
    }

    // === Consultante pregunta quién es su cuidador ===
    if (lower.contains('quien es mi cuidador')) {
      if (caregiverId != null && caregiverId.isNotEmpty) {
        final caregiverDoc =
            await _firestore.collection('users').doc(caregiverId).get();
        final data = caregiverDoc.data();
        if (data != null) {
          final name =
              "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}".trim();
          final photo = data['photoURL'] ?? '';
          final respuesta =
              "Tu cuidador es $name 💜, quien te acompaña y te cuida con cariño cada día.";
          await _guardarMensaje(uid, text, respuesta, imageUrl: photo);
          return respuesta;
        }
      }
      const respuesta =
          "Parece que aún no tienes un cuidador asignado 🕯️. "
          "Puedes vincularte con uno desde tu perfil.";
      await _guardarMensaje(uid, text, respuesta);
      return respuesta;
    }

    // === Cuidador pregunta quién es su consultante/paciente ===
    if (lower.contains('quien es mi consultante') ||
        lower.contains('quien es mi paciente')) {
      final pacientesSnap = await _firestore
          .collection('caregivers')
          .doc(uid)
          .collection('patients')
          .get();

      if (pacientesSnap.docs.isNotEmpty) {
        final nombres = <String>[];
        for (final doc in pacientesSnap.docs) {
          final patientDoc = await _firestore
              .collection('users')
              .doc(doc.id)
              .get();
          if (patientDoc.exists) {
            final data = patientDoc.data()!;
            final name =
                "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}".trim();
            nombres.add(name);
          }
        }
        if (nombres.isNotEmpty) {
          final respuesta = nombres.length == 1
              ? "Tu consultante es ${nombres.first} 💜."
              : "Tienes ${nombres.length} consultantes: ${nombres.join(', ')} 💜.";
          await _guardarMensaje(uid, text, respuesta);
          return respuesta;
        }
      }
      const respuesta = "No tienes consultantes registrados actualmente 🕯️.";
      await _guardarMensaje(uid, text, respuesta);
      return respuesta;
    }

    // === Emoción detectada y almacenada ===
    final emocion = _detectarEmocionTexto(lower);
    if (emocion != null) {
      await _guardarEstadoEmocional(uid, emocion, text ?? '');
      final resumen = await _resumenEmocional(uid, emocion);
      await _guardarMensaje(uid, text, resumen);
      return resumen;
    }

    // === Buscar recuerdos por fecha ===
    final fechaBuscada = _extraerFechaFlexible(text ?? '');
    if (fechaBuscada != null) {
      final recuerdos = await _buscarRecuerdosPorFecha(uid, fechaBuscada);
      if (recuerdos.isNotEmpty) {
        final buffer = StringBuffer();
        for (final r in recuerdos) {
          final dateField = r['date'];
          DateTime? fecha;
          if (dateField is Timestamp) fecha = dateField.toDate();
          if (dateField is String) {
            try {
              fecha = DateTime.parse(dateField);
            } catch (_) {}
          }

          final descripcion =
              r['text'] ?? r['descripcion'] ?? '(sin descripción)';
          final url = r['imageUrl'] ?? '';
          buffer.writeln(
              "📅 ${fecha != null ? _formatearFecha(fecha) : 'Sin fecha registrada'}");
          buffer.writeln("📝 Descripción: $descripcion");
          if (url.isNotEmpty) buffer.writeln("[imagen]$url[/imagen]");
          buffer.writeln("────────────────────");
        }

        final respuesta =
            "✨ He encontrado ${recuerdos.length} recuerdo(s) de esa fecha:\n\n${buffer.toString()}";
        await _guardarMensaje(uid, text, respuesta);
        return respuesta;
      } else {
        const respuesta =
            "No encontré ningún recuerdo guardado para esa fecha 🕯️. ¿Deseas subir una foto o contarme qué pasó ese día?";
        await _guardarMensaje(uid, text, respuesta);
        return respuesta;
      }
    }

    // === Subir imagen si existe ===
    String? imageUrl;
    if (image != null) {
      final ref = _storage
          .ref('memories/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(image, SettableMetadata(contentType: 'image/jpeg'));
      imageUrl = await ref.getDownloadURL();

      await _firestore
          .collection('memories')
          .doc(uid)
          .collection('user_memories')
          .add({
        'text': text ?? '',
        'imageUrl': imageUrl,
        'date': DateTime.now().toIso8601String(),
        'frequency': 'monthly',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // === Prompt principal con contexto y memoria emocional ===
    final moodHistory = await _obtenerHistorialEmocional(uid);
    final resumenEmociones = moodHistory.isEmpty
        ? ''
        : 'Últimamente el usuario ha tenido los siguientes estados emocionales: ${moodHistory.join(', ')}.';

    final systemPrompt = '''
Eres el asistente personal de $displayName.
Tu función es acompañar emocionalmente, ayudar a recordar momentos importantes y seguir el estado de ánimo del usuario.

$contextoPrevio
$resumenEmociones

Habla con calidez, empatía y naturalidad.
Nunca menciones que eres una IA ni uses lenguaje técnico.
Solo puedes hablar sobre Alzheimer, emociones, memoria y bienestar.
''';

    final parts = <Part>[
      TextPart(systemPrompt),
      if (image != null) DataPart('image/jpeg', await image.readAsBytes()),
      if (text != null && text.isNotEmpty) TextPart(text),
    ];

    try {
      final response = await _gemini.generateContent([Content.multi(parts)]);
      final reply = response.text?.trim() ?? 'No tengo información sobre eso.';
      await _guardarMensaje(uid, text, reply);
      return reply;
    } catch (e) {
      print('⚠️ Error al conectar con Gemini: $e');
      return '⚠️ Error al conectar con Gemini:\n$e';
    }
  }

  // ===============================================================
  // 🔍 FUNCIONES AUXILIARES
  // ===============================================================

  Future<Map<String, dynamic>?> _obtenerUltimoContexto(String uid) async {
    final snap = await _firestore
        .collection('assistant')
        .doc(uid)
        .collection('messages')
        .orderBy('fecha', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data();
  }

  /// Detectar emoción base
  String? _detectarEmocionTexto(String texto) {
    if (texto.contains('feliz') || texto.contains('alegre')) return 'feliz';
    if (texto.contains('triste')) return 'triste';
    if (texto.contains('ansioso') || texto.contains('nervioso')) return 'ansioso';
    if (texto.contains('enojado') || texto.contains('molesto')) return 'enojado';
    if (texto.contains('cansado') || texto.contains('agotado')) return 'cansado';
    if (texto.contains('solo') || texto.contains('sola')) return 'solo';
    return null;
  }

  /// Guardar estado emocional diario
  Future<void> _guardarEstadoEmocional(
      String uid, String emocion, String mensaje) async {
    final fecha = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await _firestore
        .collection('assistant')
        .doc(uid)
        .collection('mood_history')
        .doc(fecha)
        .set({
      'mood': emocion,
      'message': mensaje,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Generar respuesta empática en base al historial
  Future<String> _resumenEmocional(String uid, String emocion) async {
    final moods = await _obtenerHistorialEmocional(uid);
    String respuesta = '';

    if (emocion == 'feliz') {
      respuesta =
          "¡Qué gusto saber que te sientes feliz hoy! 💜 ${moods.contains('triste') ? 'Me alegra ver que tu ánimo ha mejorado desde la última vez.' : 'Sigue disfrutando de ese momento tan bonito.'}";
    } else if (emocion == 'triste') {
      respuesta =
          "Lamento que te sientas triste 😔. Estoy aquí contigo, cuéntame qué te preocupa.";
    } else if (emocion == 'ansioso') {
      respuesta =
          "Parece que estás algo ansioso 🌿. ¿Quieres que hagamos juntos un pequeño ejercicio para relajarte?";
    } else if (emocion == 'enojado') {
      respuesta =
          "Siento que estés molesto 😞. Es normal sentir enojo a veces. Estoy aquí para escucharte sin juzgar.";
    } else if (emocion == 'cansado') {
      respuesta =
          "Parece que tuviste un día pesado 💫. Te recomiendo descansar un poco y cuidar de ti.";
    } else if (emocion == 'solo') {
      respuesta =
          "No estás solo 💜. Estoy aquí contigo, siempre dispuesto a escucharte.";
    }

    return respuesta;
  }

  /// Recuperar últimos 7 estados emocionales
  Future<List<String>> _obtenerHistorialEmocional(String uid) async {
    final snap = await _firestore
        .collection('assistant')
        .doc(uid)
        .collection('mood_history')
        .orderBy('timestamp', descending: true)
        .limit(7)
        .get();
    return snap.docs.map((d) => d['mood'] as String).toList();
  }

  /// Guardar mensajes en historial
  Future<void> _guardarMensaje(String uid, String? mensaje, String respuesta,
      {String? imageUrl}) async {
    await _firestore
        .collection('assistant')
        .doc(uid)
        .collection('messages')
        .add({
      'mensaje': mensaje ?? '[foto]',
      'respuesta': respuesta,
      'imageUrl': imageUrl,
      'fecha': FieldValue.serverTimestamp(),
    });
  }

  /// Buscar recuerdos por fecha
  Future<List<Map<String, dynamic>>> _buscarRecuerdosPorFecha(
      String uid, DateTime fecha) async {
    final inicio = DateTime(fecha.year, fecha.month, fecha.day);
    final fin = inicio.add(const Duration(days: 1));

    final query = await _firestore
        .collection('memories')
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
