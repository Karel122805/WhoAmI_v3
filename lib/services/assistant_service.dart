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
    apiKey: '',
  );

  static const List<String> _mesesNombre = [
    'enero','febrero','marzo','abril','mayo','junio',
    'julio','agosto','septiembre','octubre','noviembre','diciembre',
  ];

  Future<String> chat({String? text, File? image}) async {
    final user = _auth.currentUser;
    if (user == null) return 'Debes iniciar sesión primero.';
    final uid = user.uid;

    final userDoc = await _firestore.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};

    final firstName = userData['firstName'] ?? '';
    final lastName = userData['lastName'] ?? '';
    final rawRole = (userData['role'] ?? '').toString();
    final role = rawRole.toLowerCase().trim();
    final caregiverId = userData['caregiverId'];
    final displayName = "$firstName $lastName".trim();
    final lower = (text ?? '').toLowerCase().trim();

    final lastContext = await _obtenerUltimoContexto(uid);
    String contextoPrevio = '';
    if (lastContext != null) {
      contextoPrevio =
          "La última vez me dijiste: '${lastContext['mensaje']}'. Yo respondí: '${lastContext['respuesta']}'.";

    }

    
// ================================
// ¿CUÁL ES MI ROL?
// ================================
if (lower.contains('que rol tengo') ||
    lower.contains('qué rol tengo') ||
    lower.contains('cual es mi rol') ||
    lower.contains('cuál es mi rol') ||
    lower.contains('mi rol') ||
    lower.contains('que soy') ||
    lower.contains('qué soy') ||
    lower.contains('que papel tengo') ||
    lower.contains('qué papel tengo') ||
    lower.contains('soy cuidador') ||
    lower.contains('soy consultante') ||
    lower.contains('que funcion tengo') ||
    lower.contains('qué función tengo')) {

  String respuesta;

  if (role == 'cuidador') {
    respuesta =
        "Tu rol dentro de WhoAmI? es **Cuidador** 💚.\n\n"
        "Eres quien acompaña, organiza y apoya a tu consultante con cariño en su día a día. "
        "Tu labor es muy valiosa y hace una gran diferencia. 💜";
  } else if (role == 'consultante') {
    respuesta =
        "Tu rol dentro de WhoAmI? es **Consultante** 💙.\n\n"
        "Tú eres el protagonista de tus recuerdos y emociones. "
        "Estoy aquí para ayudarte, acompañarte y recordarte momentos importantes. 💜";
  } else {
    respuesta =
        "Aún no tengo registrado tu rol dentro de la app 🕯️.\n"
        "Puedes revisarlo en tu perfil o pedir apoyo para actualizarlo.";
  }

  await _guardarMensaje(uid, text, respuesta);
  return respuesta;
}


    // ================================
    // CONSULTAR EDAD
    // ================================
    if (lower.contains('cuantos años tengo') ||
        lower.contains('cuantos anos tengo') ||
        lower.contains('cuantos aos tengo') ||
        lower.contains('que edad tengo') ||
        (lower.contains('mi edad') && !lower.contains('tu edad'))) {
      
      final birthdayStr = userData['birthday'];
      if (birthdayStr != null) {
        try {
          DateTime birthday;
          if (birthdayStr is Timestamp) birthday = birthdayStr.toDate();
          else birthday = DateTime.parse(birthdayStr.toString());

          final hoy = DateTime.now();

          int edad = hoy.year - birthday.year;
          if (hoy.month < birthday.month ||
              (hoy.month == birthday.month && hoy.day < birthday.day)) {
            edad--;
          }

          final respuesta =
              "Según la fecha que tengo registrada, tienes **$edad años**, $firstName 💜.\n\n"
              "Lo importante no es el número, sino lo que has vivido y lo que aún viene. Estoy aquí contigo.";

          await _guardarMensaje(uid, text, respuesta);
          return respuesta;

        } catch (_) {
          final resp =
              "No puedo leer tu fecha de nacimiento correctamente 🕯️.\n"
              "Revisa tu perfil o pide ayuda para actualizarla.";
          await _guardarMensaje(uid, text, resp);
          return resp;
        }
      }

      final respuesta =
          "No tengo registrada tu fecha de nacimiento 💛. Agrégala en tu perfil.";
      await _guardarMensaje(uid, text, respuesta);
      return respuesta;
    }

    // ================================
    // ¿CUÁNDO ES MI CUMPLEAÑOS?
    // ================================
    if (lower.contains('cuando cumplo') ||
        lower.contains('cuando es mi cumple') ||
        lower.contains('cuando es mi cumpleaños') ||
        (lower.contains('mi cumpleaños') && !lower.contains('falta'))) {

      final birthdayStr = userData['birthday'];
      if (birthdayStr != null) {
        try {
          DateTime birthday;
          if (birthdayStr is Timestamp) birthday = birthdayStr.toDate();
          else birthday = DateTime.parse(birthdayStr.toString());

          final fecha = _formatearCumpleCorto(birthday);

          final respuesta =
              "Tu cumpleaños está registrado el **$fecha** 🎉💜.\n"
              "Es un día para celebrar tu vida y tus recuerdos.";
          
          await _guardarMensaje(uid, text, respuesta);
          return respuesta;

        } catch (_) {
          final resp =
              "No pude leer correctamente tu cumpleaños 🕯️. Revisa tu perfil.";
          await _guardarMensaje(uid, text, resp);
          return resp;
        }
      }

      final respuesta =
          "No tengo tu cumpleaños registrado 💛. Agrégalo en tu perfil.";
      await _guardarMensaje(uid, text, respuesta);
      return respuesta;
    }

    // ================================
    // DÍA EXACTO EN QUE NACISTE
    // ================================
    if (lower.contains('que dia naci') ||
        lower.contains('cuando naci') ||
        lower.contains('cuando nací') ||
        lower.contains('fecha de nacimiento') ||
        lower.contains('cual es mi cumpleaños')) {

      final birthdayStr = userData['birthday'];
      if (birthdayStr != null) {
        try {
          DateTime birthday;
          if (birthdayStr is Timestamp) birthday = birthdayStr.toDate();
          else birthday = DateTime.parse(birthdayStr.toString());

          final fecha = _formatearCumpleLargo(birthday);

          final respuesta =
              "Naciste el **$fecha** 💜.\nEse día comenzó tu historia.";
          
          await _guardarMensaje(uid, text, respuesta);
          return respuesta;

        } catch (_) {
          final resp =
              "No puedo leer tu fecha de nacimiento 🕯️. Revisa tu perfil.";
          await _guardarMensaje(uid, text, resp);
          return resp;
        }
      }

      final respuesta =
          "No tengo tu fecha de nacimiento registrada 💛.";
      await _guardarMensaje(uid, text, respuesta);
      return respuesta;
    }

    // ================================
    // ¿CUÁNTOS DÍAS FALTAN PARA MI CUMPLE?
    // ================================
    if ((lower.contains('faltan') && lower.contains('cumple')) ||
        lower.contains('cuantos dias para mi cumpleaños') ||
        lower.contains('cuantos días para mi cumpleaños')) {

      final birthdayStr = userData['birthday'];
      if (birthdayStr != null && birthdayStr.toString().isNotEmpty) {
        try {
          DateTime nacimiento;
          if (birthdayStr is Timestamp) nacimiento = birthdayStr.toDate();
          else nacimiento = DateTime.parse(birthdayStr.toString());

          final hoy = DateTime.now();
          final hoyNormal = DateTime(hoy.year, hoy.month, hoy.day);

          DateTime proximo =
              DateTime(hoy.year, nacimiento.month, nacimiento.day);

          if (proximo.isBefore(hoyNormal)) {
            proximo = DateTime(hoy.year + 1, nacimiento.month, nacimiento.day);
          }

          final dias = proximo.difference(hoyNormal).inDays;

          String respuesta;
          if (dias == 0) {
            respuesta = "🎉💜 ¡Hoy es tu cumpleaños! 💜🎉";
          } else if (dias == 1) {
            respuesta = "Falta **1 día** para tu cumpleaños 🎂💜";
          } else {
            respuesta = "Faltan **$dias días** para tu cumpleaños 🎂💜";
          }

          await _guardarMensaje(uid, text, respuesta);
          return respuesta;

        } catch (_) {
          final resp =
              "No pude calcular cuántos días faltan 🕯️. Revisa tu fecha en el perfil.";
          await _guardarMensaje(uid, text, resp);
          return resp;
        }
      }

      final respuesta =
          "No tengo tu fecha registrada 💛. Agrégala en tu perfil.";
      await _guardarMensaje(uid, text, respuesta);
      return respuesta;
    }

    // ===============================================================
    // TEXTO SEGURO PARA QUE GEMINI NO INVENTE FECHAS
    // ===============================================================
    String cumpleSeguro = "Sin registrar";
    final cumpleCampo = userData['birthday'];

    if (cumpleCampo != null) {
      try {
        DateTime cumple;
        if (cumpleCampo is Timestamp) cumple = cumpleCampo.toDate();
        else cumple = DateTime.parse(cumpleCampo.toString());

        final mes = _mesesNombre[cumple.month - 1];
        cumpleSeguro = "${cumple.day} de $mes de ${cumple.year}";
      } catch (_) {}
    }

    final reglasFijas = '''
REGLAS ESTRICTAS SOBRE IDENTIDAD:
- La edad solo puede calcularse con la fecha REAL guardada en Firestore.
- La fecha de nacimiento REAL es: $cumpleSeguro.
- Si no existe fecha, responde: "No tengo registrada tu fecha de nacimiento".
- No inventes fechas, edades ni años.
- No respondas sobre cumpleaños si no hay fecha verificada.
- Usa siempre los datos reales de Firestore.
''';

    // ===============================================================
    // APOYO SI ES CUIDADOR
    // ===============================================================
    if (role == 'cuidador' &&
        (lower.contains('como puedo ayudar') ||
         lower.contains('como le ayudo') ||
         lower.contains('ideas para ayudar'))) {

      final respuesta =
          "Gracias por cuidar con tanto cariño, $firstName 💚.\n\n"
          "Aquí tienes algunas ideas prácticas:\n"
          "• Habla despacio y con calma.\n"
          "• Usa objetos y fotos familiares.\n"
          "• Mantén una rutina diaria.\n"
          "• Valida sus emociones.\n\n"
          "Si quieres, cuéntame cómo se ha sentido últimamente 💜.";

      await _guardarMensaje(uid, text, respuesta);
      return respuesta;
    }

    // ===============================================================
    // APOYO SI ES CONSULTANTE
    // ===============================================================
    if (role == 'consultante' &&
        (lower.contains('como mejorar mi memoria') ||
         lower.contains('como puedo recordar'))) {

      final respuesta =
          "Me alegra que quieras cuidar tu memoria 💙.\n"
          "Puedes probar:\n"
          "• Guardar fotos y notas.\n"
          "• Repetir información con alguien de confianza.\n"
          "• Tener una rutina diaria.\n"
          "• Escuchar música o ver fotos.\n\n"
          "Si quieres, te ayudo a escribir un recuerdo 💜.";

      await _guardarMensaje(uid, text, respuesta);
      return respuesta;
    }

    // ===============================================================
    // ¿QUIÉN ES MI CUIDADOR?
    // ===============================================================
    if (lower.contains('quien es mi cuidador')||
        lower.contains('quien es mi cuidadora')) {
 
      if (caregiverId != null && caregiverId.toString().isNotEmpty) {
        final caregiverDoc =
            await _firestore.collection('users').doc(caregiverId).get();
        final cdata = caregiverDoc.data();

        if (cdata != null) {
          final name =
              "${cdata['firstName'] ?? ''} ${cdata['lastName'] ?? ''}".trim();

          final respuesta =
              "Tu cuidador/cuidora es **$name** 💜.\n"
              "Esa persona te acompaña todos los días.";
          await _guardarMensaje(uid, text, respuesta);
          return respuesta;
        }
      }

      const respuesta =
          "No tienes registrado ningún cuidador 🕯️.";
      await _guardarMensaje(uid, text, respuesta);
      return respuesta;
    }

    // ===============================================================
    // ¿QUIÉN ES MI CONSULTANTE?
    // ===============================================================
    if (lower.contains('quien es mi consultante') ||
        lower.contains('quien es mi paciente')) {

      final snap = await _firestore
          .collection('caregivers')
          .doc(uid)
          .collection('patients')
          .get();

      if (snap.docs.isNotEmpty) {
        final nombres = <String>[];
        for (final doc in snap.docs) {
          final pDoc =
              await _firestore.collection('users').doc(doc.id).get();
          if (pDoc.exists) {
            final pdata = pDoc.data()!;
            final n =
                "${pdata['firstName'] ?? ''} ${pdata['lastName'] ?? ''}".trim();
            nombres.add(n);
          }
        }

        final respuesta = nombres.length == 1
            ? "Tu consultante/paciente es **${nombres.first}** 💜."
            : "Tienes **${nombres.length} consultantes**: ${nombres.join(', ')} 💜";

        await _guardarMensaje(uid, text, respuesta);
        return respuesta;
      }

      const respuesta =
          "No tienes consultantes registrados 🕯️.";
      await _guardarMensaje(uid, text, respuesta);
      return respuesta;
    }

    // ===============================================================
    // DETECTAR EMOCIÓN
    // ===============================================================
    final emocion = _detectarEmocionTexto(lower);
    if (emocion != null) {
      await _guardarEstadoEmocional(uid, emocion, text ?? '');
      final resumen = await _resumenEmocional(uid, emocion);
      await _guardarMensaje(uid, text, resumen);
      return resumen;
    }

    // ===============================================================
    // BUSCAR RECUERDOS POR FECHA
    // ===============================================================
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
            try { fecha = DateTime.parse(dateField); } catch (_) {}
          }

          final desc =
              r['text'] ?? r['descripcion'] ?? '(sin descripción)';
          final url = r['imageUrl'] ?? '';

          buffer.writeln("📅 ${fecha != null ? _formatearFecha(fecha) : 'Sin fecha'}");
          buffer.writeln("📝 $desc");
          if (url.isNotEmpty) buffer.writeln("[imagen]$url[/imagen]");
          buffer.writeln("──────────────");
        }

        final respuesta =
            "✨ Encontré **${recuerdos.length} recuerdo(s)**:\n\n${buffer.toString()}";

        await _guardarMensaje(uid, text, respuesta);
        return respuesta;
      }

      const respuesta =
          "No encontré recuerdos de esa fecha 🕯️.";
      await _guardarMensaje(uid, text, respuesta);
      return respuesta;
    }

    // ===============================================================
    // SUBIR IMAGEN
    // ===============================================================
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

    // ===============================================================
    // PROMPT PRINCIPAL DE GEMINI
    // ===============================================================
    final systemPrompt = '''
Eres el asistente emocional y de recuerdos personales de $displayName.

$reglasFijas

$contextoPrevio

Reglas:
• Habla con calidez.
• No uses lenguaje técnico.
• No menciones que eres una IA.
• Ayuda a recordar, sin diagnosticar.
''';

    final parts = <Part>[
      TextPart(systemPrompt),
      if (image != null) DataPart('image/jpeg', await image.readAsBytes()),
      if (text != null && text.isNotEmpty) TextPart(text),
    ];

    try {
      final response = await _gemini.generateContent([Content.multi(parts)]);
      final reply = response.text?.trim() ??
          'En este momento no tengo una respuesta clara, pero sigo aquí contigo 💜';

      await _guardarMensaje(uid, text, reply, imageUrl: imageUrl);
      return reply;

    } catch (e) {
      print('ERROR GEMINI: $e');
      return "⚠️ Ocurrió un error al conectar con el asistente.";
    }
  }

  // ===============================================================
  // FUNCIONES AUXILIARES
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

  String? _detectarEmocionTexto(String texto) {
    if (texto.contains('feliz') || texto.contains('alegre')) return 'feliz';
    if (texto.contains('triste')) return 'triste';
    if (texto.contains('ansioso') || texto.contains('nervioso')) return 'ansioso';
    if (texto.contains('enojado') || texto.contains('molesto')) return 'enojado';
    if (texto.contains('cansado') || texto.contains('agotado')) return 'cansado';
    if (texto.contains('solo') || texto.contains('sola')) return 'solo';
    return null;
  }

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

  Future<String> _resumenEmocional(String uid, String emocion) async {
    if (emocion == 'feliz') return "Me alegra saber que estás feliz hoy 💜";
    if (emocion == 'triste') return "Lamento que te sientas triste 😔, estoy contigo.";
    if (emocion == 'ansioso') return "Parece que estás ansioso 🌿, respiremos juntos.";
    if (emocion == 'enojado') return "Siento que estés molesto 😞, cuéntame qué pasó.";
    if (emocion == 'cansado') return "Tuviste un día pesado 💫, intenta descansar.";
    if (emocion == 'solo') return "No estás solo/a 💜, estoy aquí contigo.";
    return "Estoy contigo 💜";
  }

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

  Future<void> _guardarMensaje(
      String uid, String? mensaje, String respuesta,
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
      final alt = await _firestore
          .collection('memories')
          .doc(uid)
          .collection('user_memories')
          .where('date', isGreaterThanOrEqualTo: inicio)
          .where('date', isLessThan: fin)
          .get();
      return alt.docs.map((d) => d.data()).toList();
    }

    return query.docs.map((d) => d.data()).toList();
  }

  DateTime? _extraerFechaFlexible(String text) {
    text = text.toLowerCase().trim();
    final ahora = DateTime.now();

    if (text.contains('hoy')) return ahora;
    if (text.contains('ayer')) return ahora.subtract(Duration(days: 1));
    if (text.contains('antier') || text.contains('antes de ayer'))
      return ahora.subtract(Duration(days: 2));

    final numeric = RegExp(r'(\d{1,2})[\/\- ](\d{1,2})[\/\- ](\d{2,4})');
    final match = numeric.firstMatch(text);

    if (match != null) {
      final d = int.parse(match.group(1)!);
      final m = int.parse(match.group(2)!);
      final y = int.parse(match.group(3)!.length == 2
          ? "20${match.group(3)!}"
          : match.group(3)!);
      return DateTime(y, m, d);
    }

    const meses = {
      'enero':1,'febrero':2,'marzo':3,'abril':4,'mayo':5,'junio':6,
      'julio':7,'agosto':8,'septiembre':9,'octubre':10,'noviembre':11,'diciembre':12,
    };

    final textoNormal =
        RegExp(r'(\d{1,2}) ?(de)? ?([a-záéíóú]+) ?(de)? ?(\d{2,4})?',
            caseSensitive: false);

    final m2 = textoNormal.firstMatch(text);
      if (m2 != null) {
        final d = int.parse(m2.group(1)!);
        final mes = meses[m2.group(3)!] ?? 1;
        final anio = int.tryParse(m2.group(5) ?? '') ?? DateTime.now().year;
        return DateTime(anio, mes, d);
      }


    return null;
  }

  String _formatearFecha(DateTime f) =>
      DateFormat('dd/MM/yyyy').format(f);

  String _formatearCumpleCorto(DateTime f) {
    final mes = _mesesNombre[f.month - 1];
    return "${f.day} de $mes";
  }

  String _formatearCumpleLargo(DateTime f) {
    final mes = _mesesNombre[f.month - 1];
    return "${f.day} de $mes de ${f.year}";
  }
}
