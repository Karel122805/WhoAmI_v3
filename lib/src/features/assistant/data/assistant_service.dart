import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';

class AssistantService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final GenerativeModel _gemini = GenerativeModel(
    model: 'gemini-2.0-flash',
    apiKey: 'AIzaSyBIqfcOCUo4tEAHNlVIWRSMqzVf5TC5KBQ',
  );

  static const List<String> _mesesNombre = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  static const List<String> _temasPermitidos = [
    'memoria',
    'recuerdo',
    'recuerdos',
    'orientación',
    'orientacion',
    'fecha',
    'día',
    'dia',
    'hora',
    'cumpleaños',
    'cumpleanos',
    'edad',
    'familia',
    'emociones',
    'emoción',
    'emocion',
    'triste',
    'feliz',
    'alegre',
    'ansioso',
    'nervioso',
    'enojado',
    'molesto',
    'solo',
    'sola',
    'cansado',
    'agotado',
    'ejercicio mental',
    'ejercicios',
    'estimulación cognitiva',
    'estimulacion cognitiva',
    'atención',
    'atencion',
    'concentración',
    'concentracion',
    'rutina',
    'paciente',
    'consultante',
    'cuidador',
    'cuidadora',
    'perfil',
    'quien soy',
    'qué soy',
    'que soy',
    'rol',
    'foto',
    'imagen',
    'calendario',
    'recordatorio',
    'recordatorios',
    'ayuda',
    'me siento',
    'cómo estoy',
    'como estoy',
    'cómo ayudar',
    'como ayudar',
    'qué puedes hacer',
    'que puedes hacer',
    'qué haces',
    'que haces',
    'cómo puedes ayudarme',
    'como puedes ayudarme',
  ];

  static const List<String> _temasBloqueados = [
    'sexo',
    'sexual',
    'porn',
    'violencia',
    'arma',
    'armas',
    'droga',
    'drogas',
    'matar',
    'suicidio',
    'hackear',
    'hack',
    'robar',
    'estafa',
    'bomba',
    'política',
    'politica',
    'presidente',
    'apostar',
    'casino',
  ];

  static const List<String> _saludos = [
    'hola',
    'hola!',
    'hola asistente',
    'buenos dias',
    'buenos días',
    'buen dia',
    'buen día',
    'buenas tardes',
    'buenas noches',
    'hey',
    'ey',
  ];

  static const List<String> _mensajesBase = [
    'hola',
    'gracias',
    'ok',
    'oki',
    'vale',
    'esta bien',
    'está bien',
    'sí',
    'si',
    'no',
    'ayúdame',
    'ayudame',
    'qué puedes hacer',
    'que puedes hacer',
    'qué haces',
    'que haces',
    'cómo puedes ayudarme',
    'como puedes ayudarme',
  ];

  Future<String> chat({String? text, File? image}) async {
    final user = _auth.currentUser;
    if (user == null) return 'Debes iniciar sesión primero.';

    final uid = user.uid;
    final cleanText = (text ?? '').trim();
    final lower = cleanText.toLowerCase().trim();

    final userDoc = await _firestore.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? <String, dynamic>{};

    final firstName = (userData['firstName'] ?? '').toString().trim();
    final lastName = (userData['lastName'] ?? '').toString().trim();
    final rawRole = (userData['role'] ?? '').toString().trim().toLowerCase();
    final caregiverId = userData['caregiverId'];
    final displayName = '$firstName $lastName'.trim();

    final historial = await _obtenerHistorialReciente(uid, limit: 6);
    final lastContext = historial.isNotEmpty ? historial.last : null;

    String contextoPrevio = '';
    if (historial.isNotEmpty) {
      final buffer = StringBuffer();
      for (final item in historial) {
        final mensaje = (item['mensaje'] ?? '').toString();
        final respuesta = (item['respuesta'] ?? '').toString();
        buffer.writeln('Usuario: $mensaje');
        buffer.writeln('Asistente: $respuesta');
      }
      contextoPrevio = buffer.toString().trim();
    }

    if (image == null && cleanText.isEmpty) {
      const respuesta =
          'Estoy aquí para ayudarte con recuerdos, orientación, emociones y ejercicios de estimulación cognitiva 💜';
      await _guardarMensaje(uid, text, respuesta, role: rawRole);
      return respuesta;
    }

    if (_contieneTemaBloqueado(lower)) {
      const respuesta =
          'Prefiero ayudarte con recuerdos, orientación, emociones, bienestar y ejercicios de estimulación cognitiva 💜';
      await _guardarMensaje(uid, text, respuesta, role: rawRole);
      return respuesta;
    }

    if (_esSaludo(lower)) {
      final respuesta =
          "Hola${firstName.isNotEmpty ? ' $firstName' : ''} 💜\n\n"
          "Me da gusto saludarte. "
          "Puedo acompañarte con recuerdos, orientación, emociones y ejercicios sencillos de memoria.\n\n"
          "¿Cómo te sientes hoy o en qué te gustaría que te ayude?";
      await _guardarMensaje(uid, text, respuesta, role: rawRole);
      return respuesta;
    }

    if (_esMensajeBase(lower)) {
      final respuesta =
          "Estoy aquí contigo 💜\n\n"
          "Puedo ayudarte con recuerdos, emociones, orientación y ejercicios mentales sencillos.\n"
          "Puedes contarme cómo te sientes, preguntarme por tus recuerdos o decirme qué necesitas.";
      await _guardarMensaje(uid, text, respuesta, role: rawRole);
      return respuesta;
    }

    if (_esSeguimientoCorto(lower) && lastContext != null) {
      final ultimoMensaje = (lastContext['mensaje'] ?? '').toString();
      final ultimaRespuesta = (lastContext['respuesta'] ?? '').toString();

      final systemFollowUp = '''
Eres un asistente emocional y de recuerdos personales.

Debes responder con continuidad, coherencia y calidez.
El usuario hizo una pregunta corta de seguimiento.

Último mensaje del usuario: "$ultimoMensaje"
Última respuesta del asistente: "$ultimaRespuesta"
Nuevo mensaje del usuario: "$cleanText"

REGLAS:
- Mantén continuidad con el mensaje anterior.
- No cambies abruptamente de tema.
- Sé breve, cálido y claro.
- Mantén lenguaje positivo.
- No menciones que eres una IA.
- No diagnostiques.
- Solo responde dentro del dominio: recuerdos, orientación, emociones, bienestar y estimulación cognitiva.
''';

      try {
        final response = await _gemini.generateContent([
          Content.text(systemFollowUp),
        ]);

        final reply = (response.text ?? '').trim().isNotEmpty
            ? response.text!.trim()
            : "Claro 💜, te lo explico con calma. ¿Quieres que vayamos paso a paso?";

        await _guardarMensaje(uid, text, reply, role: rawRole);
        return reply;
      } catch (_) {
        const reply =
            "Claro 💜, seguimos con eso. Cuéntame un poquito más para ayudarte mejor.";
        await _guardarMensaje(uid, text, reply, role: rawRole);
        return reply;
      }
    }

    if (_preguntaRol(lower)) {
      String respuesta;

      if (rawRole == 'cuidador') {
        respuesta =
            "Tu rol dentro de WhoAmI es **Cuidador** 💚.\n\n"
            "Acompañas, organizas y apoyas a tu consultante con mucho valor y cariño. Tu labor hace una gran diferencia 💜";
      } else if (rawRole == 'consultante' || rawRole == 'paciente') {
        respuesta =
            "Tu rol dentro de WhoAmI es **Consultante** 💙.\n\n"
            "Tú eres el centro de tus recuerdos, emociones y avances. Estoy aquí para acompañarte con calma y cariño 💜";
      } else {
        respuesta =
            "Aún no tengo registrado tu rol dentro de la app 🕯️.\n"
            "Puedes revisarlo en tu perfil o pedir apoyo para actualizarlo.";
      }

      await _guardarMensaje(uid, text, respuesta, role: rawRole);
      return respuesta;
    }

    if (_preguntaEdad(lower)) {
      final birthdayStr = userData['birthday'];

      if (birthdayStr != null) {
        try {
          DateTime birthday;
          if (birthdayStr is Timestamp) {
            birthday = birthdayStr.toDate();
          } else {
            birthday = DateTime.parse(birthdayStr.toString());
          }

          final hoy = DateTime.now();
          int edad = hoy.year - birthday.year;

          if (hoy.month < birthday.month ||
              (hoy.month == birthday.month && hoy.day < birthday.day)) {
            edad--;
          }

          final respuesta =
              "Según la fecha registrada, tienes **$edad años**, ${firstName.isNotEmpty ? firstName : 'usuario'} 💜.\n\n"
              "Cada año cuenta una parte valiosa de tu historia.";

          await _guardarMensaje(uid, text, respuesta, role: rawRole);
          return respuesta;
        } catch (_) {
          const respuesta =
              "No pude leer correctamente tu fecha de nacimiento 🕯️.\nRevisa tu perfil o pide ayuda para actualizarla.";
          await _guardarMensaje(uid, text, respuesta, role: rawRole);
          return respuesta;
        }
      }

      const respuesta =
          "No tengo registrada tu fecha de nacimiento 💛. Puedes agregarla en tu perfil.";
      await _guardarMensaje(uid, text, respuesta, role: rawRole);
      return respuesta;
    }

    if (_preguntaCumple(lower)) {
      final birthdayStr = userData['birthday'];

      if (birthdayStr != null) {
        try {
          DateTime birthday;
          if (birthdayStr is Timestamp) {
            birthday = birthdayStr.toDate();
          } else {
            birthday = DateTime.parse(birthdayStr.toString());
          }

          final fecha = _formatearCumpleCorto(birthday);
          final respuesta =
              "Tu cumpleaños está registrado el **$fecha** 🎉💜.\nEs un día especial para celebrar tu vida y tus recuerdos.";

          await _guardarMensaje(uid, text, respuesta, role: rawRole);
          return respuesta;
        } catch (_) {
          const respuesta =
              "No pude leer correctamente tu cumpleaños 🕯️. Revisa tu perfil.";
          await _guardarMensaje(uid, text, respuesta, role: rawRole);
          return respuesta;
        }
      }

      const respuesta =
          "No tengo tu cumpleaños registrado 💛. Puedes agregarlo en tu perfil.";
      await _guardarMensaje(uid, text, respuesta, role: rawRole);
      return respuesta;
    }

    if (_preguntaNacimiento(lower)) {
      final birthdayStr = userData['birthday'];

      if (birthdayStr != null) {
        try {
          DateTime birthday;
          if (birthdayStr is Timestamp) {
            birthday = birthdayStr.toDate();
          } else {
            birthday = DateTime.parse(birthdayStr.toString());
          }

          final fecha = _formatearCumpleLargo(birthday);
          final respuesta =
              "Naciste el **$fecha** 💜.\nEse día comenzó una historia muy valiosa.";

          await _guardarMensaje(uid, text, respuesta, role: rawRole);
          return respuesta;
        } catch (_) {
          const respuesta =
              "No puedo leer tu fecha de nacimiento 🕯️. Revisa tu perfil.";
          await _guardarMensaje(uid, text, respuesta, role: rawRole);
          return respuesta;
        }
      }

      const respuesta = "No tengo tu fecha de nacimiento registrada 💛.";
      await _guardarMensaje(uid, text, respuesta, role: rawRole);
      return respuesta;
    }

    if (_preguntaDiasParaCumple(lower)) {
      final birthdayStr = userData['birthday'];

      if (birthdayStr != null && birthdayStr.toString().isNotEmpty) {
        try {
          DateTime nacimiento;
          if (birthdayStr is Timestamp) {
            nacimiento = birthdayStr.toDate();
          } else {
            nacimiento = DateTime.parse(birthdayStr.toString());
          }

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
            respuesta = "🎉💜 ¡Hoy es tu cumpleaños! Qué bonito día para celebrar 💜🎉";
          } else if (dias == 1) {
            respuesta = "Falta **1 día** para tu cumpleaños 🎂💜";
          } else {
            respuesta = "Faltan **$dias días** para tu cumpleaños 🎂💜";
          }

          await _guardarMensaje(uid, text, respuesta, role: rawRole);
          return respuesta;
        } catch (_) {
          const respuesta =
              "No pude calcular cuántos días faltan 🕯️. Revisa tu fecha de nacimiento en el perfil.";
          await _guardarMensaje(uid, text, respuesta, role: rawRole);
          return respuesta;
        }
      }

      const respuesta =
          "No tengo tu fecha registrada 💛. Puedes agregarla en tu perfil.";
      await _guardarMensaje(uid, text, respuesta, role: rawRole);
      return respuesta;
    }

    if (rawRole == 'cuidador' && _preguntaAyudaCuidador(lower)) {
      final respuesta =
          "Gracias por cuidar con tanto cariño, ${firstName.isNotEmpty ? firstName : 'cuidador'} 💚.\n\n"
          "Aquí tienes algunas ideas prácticas:\n"
          "• Habla despacio y con calma.\n"
          "• Usa fotos, objetos y palabras familiares.\n"
          "• Mantén una rutina sencilla.\n"
          "• Valida sus emociones sin presionarlo.\n"
          "• Descansa también tú cuando lo necesites.\n\n"
          "Si quieres, puedo darte ejercicios simples de estimulación cognitiva 💜";

      await _guardarMensaje(uid, text, respuesta, role: rawRole);
      return respuesta;
    }

    if ((rawRole == 'consultante' || rawRole == 'paciente') &&
        _preguntaMejorarMemoria(lower)) {
      const respuesta =
          "Me alegra que quieras cuidar tu memoria 💙.\n\n"
          "Puedes probar:\n"
          "• Guardar fotos y notas importantes.\n"
          "• Repetir información con alguien de confianza.\n"
          "• Tener una rutina diaria.\n"
          "• Escuchar música que te guste.\n"
          "• Recordar momentos bonitos con calma.\n\n"
          "Si quieres, también puedo proponerte un ejercicio mental sencillo 💜";

      await _guardarMensaje(uid, text, respuesta, role: rawRole);
      return respuesta;
    }

    if (_preguntaCuidador(lower)) {
      if (caregiverId != null && caregiverId.toString().isNotEmpty) {
        final caregiverDoc =
            await _firestore.collection('users').doc(caregiverId).get();
        final cdata = caregiverDoc.data();

        if (cdata != null) {
          final name =
              "${cdata['firstName'] ?? ''} ${cdata['lastName'] ?? ''}".trim();

          final respuesta =
              "Tu cuidador o cuidadora es **$name** 💜.\nEs una persona importante que te acompaña día a día.";
          await _guardarMensaje(uid, text, respuesta, role: rawRole);
          return respuesta;
        }
      }

      const respuesta = "No tienes registrado ningún cuidador 🕯️.";
      await _guardarMensaje(uid, text, respuesta, role: rawRole);
      return respuesta;
    }

    if (_preguntaConsultante(lower)) {
      final snap = await _firestore
          .collection('caregivers')
          .doc(uid)
          .collection('patients')
          .get();

      if (snap.docs.isNotEmpty) {
        final nombres = <String>[];

        for (final doc in snap.docs) {
          final pDoc = await _firestore.collection('users').doc(doc.id).get();
          if (pDoc.exists) {
            final pdata = pDoc.data()!;
            final n =
                "${pdata['firstName'] ?? ''} ${pdata['lastName'] ?? ''}".trim();
            if (n.isNotEmpty) nombres.add(n);
          }
        }

        final respuesta = nombres.length == 1
            ? "Tu consultante o paciente es **${nombres.first}** 💜."
            : "Tienes **${nombres.length} consultantes**: ${nombres.join(', ')} 💜";

        await _guardarMensaje(uid, text, respuesta, role: rawRole);
        return respuesta;
      }

      const respuesta = "No tienes consultantes registrados 🕯️.";
      await _guardarMensaje(uid, text, respuesta, role: rawRole);
      return respuesta;
    }

    final emocion = _detectarEmocionTexto(lower);
    if (emocion != null) {
      await _guardarEstadoEmocional(uid, emocion, cleanText);
      final resumen = await _resumenEmocional(uid, emocion);
      await _guardarMensaje(uid, text, resumen, role: rawRole);
      return resumen;
    }

    // ===============================================================
    // RECUERDOS: CONSULTA POR FECHA O CONSULTA GENERAL
    // ===============================================================
    final bool quiereRecuerdos = _quiereVerRecuerdos(lower);
    final fechaBuscada = _extraerFechaFlexible(cleanText);

    if (fechaBuscada != null) {
      final recuerdos = await _buscarRecuerdosPorFecha(uid, fechaBuscada);

      if (recuerdos.isNotEmpty) {
        final respuesta = _armarRespuestaRecuerdos(
          recuerdos,
          encabezado:
              "✨ Encontré **${recuerdos.length} recuerdo(s)** de esa fecha:",
        );
        await _guardarMensaje(uid, text, respuesta, role: rawRole);
        return respuesta;
      }

      const respuesta = "No encontré recuerdos de esa fecha 🕯️.";
      await _guardarMensaje(uid, text, respuesta, role: rawRole);
      return respuesta;
    }

    if (quiereRecuerdos) {
      final recuerdosRecientes = await _buscarRecuerdosRecientes(uid, limit: 5);

      if (recuerdosRecientes.isNotEmpty) {
        final respuesta = _armarRespuestaRecuerdos(
          recuerdosRecientes,
          encabezado:
              "💜 Estos son algunos de tus recuerdos más recientes:",
        );
        await _guardarMensaje(uid, text, respuesta, role: rawRole);
        return respuesta;
      }

      const respuesta =
          "Aún no encontré recuerdos guardados en tu historial 💜. Cuando quieras, podemos crear uno nuevo.";
      await _guardarMensaje(uid, text, respuesta, role: rawRole);
      return respuesta;
    }

    // ===============================================================
    // SUBIR IMAGEN DESDE CHAT
    // ===============================================================
    String? imageUrl;
    if (image != null) {
      final now = DateTime.now();
      final displayDate = _dateId(now);

      final docRef = _firestore
          .collection('memories')
          .doc(uid)
          .collection('user_memories')
          .doc();

      final ref = _storage
          .ref()
          .child('user_memories')
          .child(uid)
          .child('${docRef.id}.jpg');

      await ref.putFile(
        image,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      imageUrl = await ref.getDownloadURL();

      await docRef.set({
        'text': cleanText,
        'imageUrl': imageUrl,
        'displayDate': displayDate,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      final respuesta =
          "Guardé tu recuerdo de hoy 💜. Si quieres, también puedo ayudarte a recordarlo más tarde.";
      await _guardarMensaje(uid, text, respuesta, imageUrl: imageUrl, role: rawRole);
      return respuesta;
    }

    final temaPermitido = _esTemaPermitido(lower);
    if (!temaPermitido) {
      const respuesta =
          "Puedo acompañarte en temas de recuerdos, orientación, emociones y ejercicios de memoria 💜. Si quieres, cuéntame cómo te sientes o qué te gustaría recordar.";
      await _guardarMensaje(uid, text, respuesta, role: rawRole);
      return respuesta;
    }

    String cumpleSeguro = "Sin registrar";
    final cumpleCampo = userData['birthday'];

    if (cumpleCampo != null) {
      try {
        DateTime cumple;
        if (cumpleCampo is Timestamp) {
          cumple = cumpleCampo.toDate();
        } else {
          cumple = DateTime.parse(cumpleCampo.toString());
        }

        final mes = _mesesNombre[cumple.month - 1];
        cumpleSeguro = "${cumple.day} de $mes de ${cumple.year}";
      } catch (_) {}
    }

    final reglasFijas = '''
REGLAS ESTRICTAS:
- Solo responde temas de estimulación cognitiva, recuerdos, orientación temporal, emociones, bienestar, rutinas, memoria y apoyo amable.
- No respondas temas fuera de ese dominio.
- Si el usuario pregunta algo fuera de dominio, redirígelo con amabilidad.
- Mantén SIEMPRE lenguaje positivo, claro, simple y cálido.
- No uses lenguaje técnico.
- No menciones que eres una IA.
- No diagnostiques.
- La fecha de nacimiento REAL es: $cumpleSeguro.
- Si no existe fecha, responde: "No tengo registrada tu fecha de nacimiento".
- No inventes fechas, edades ni años.
- Usa siempre los datos reales de Firestore cuando existan.
''';

    final systemPrompt = '''
Eres el asistente emocional y de recuerdos personales de $displayName.

$reglasFijas

Contexto reciente de la conversación:
$contextoPrevio

Tu función es:
- acompañar con amabilidad,
- ayudar a recordar,
- orientar con calma,
- proponer ejercicios simples de estimulación cognitiva,
- responder de forma breve, positiva, clara y coherente con el flujo de la conversación.

IMPORTANTE:
- Si el usuario hace una pregunta breve, interpreta su intención usando el contexto reciente.
- Si el usuario saluda, responde con calidez.
- Si el usuario pregunta "qué puedes hacer", explícalo naturalmente.
- No cambies de tema sin motivo.
''';

    final parts = <Part>[
      TextPart(systemPrompt),
      if (cleanText.isNotEmpty) TextPart(cleanText),
    ];

    try {
      final response = await _gemini.generateContent([Content.multi(parts)]);
      final reply = (response.text ?? '').trim().isNotEmpty
          ? response.text!.trim()
          : 'Estoy aquí contigo 💜. Podemos hablar de recuerdos, emociones, orientación o ejercicios sencillos de memoria.';

      await _guardarMensaje(uid, text, reply, role: rawRole);
      return reply;
    } catch (e) {
      return "⚠️ Ocurrió un error al conectar con el asistente. Intenta de nuevo en un momento.";
    }
  }

  Future<List<Map<String, dynamic>>> _obtenerHistorialReciente(
    String uid, {
    int limit = 6,
  }) async {
    final snap = await _firestore
        .collection('assistant')
        .doc(uid)
        .collection('messages')
        .orderBy('fecha', descending: true)
        .limit(limit)
        .get();

    final docs = snap.docs.map((d) => d.data()).toList();
    return docs.reversed.toList();
  }

  bool _preguntaRol(String lower) {
    return lower.contains('que rol tengo') ||
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
        lower.contains('qué función tengo');
  }

  bool _preguntaEdad(String lower) {
    return lower.contains('cuantos años tengo') ||
        lower.contains('cuantos anos tengo') ||
        lower.contains('que edad tengo') ||
        (lower.contains('mi edad') && !lower.contains('tu edad'));
  }

  bool _preguntaCumple(String lower) {
    return lower.contains('cuando cumplo') ||
        lower.contains('cuando es mi cumple') ||
        lower.contains('cuando es mi cumpleaños') ||
        (lower.contains('mi cumpleaños') && !lower.contains('falta'));
  }

  bool _preguntaNacimiento(String lower) {
    return lower.contains('que dia naci') ||
        lower.contains('cuando naci') ||
        lower.contains('cuando nací') ||
        lower.contains('fecha de nacimiento') ||
        lower.contains('cual es mi cumpleaños');
  }

  bool _preguntaDiasParaCumple(String lower) {
    return (lower.contains('faltan') && lower.contains('cumple')) ||
        lower.contains('cuantos dias para mi cumpleaños') ||
        lower.contains('cuántos días para mi cumpleaños');
  }

  bool _preguntaAyudaCuidador(String lower) {
    return lower.contains('como puedo ayudar') ||
        lower.contains('cómo puedo ayudar') ||
        lower.contains('como le ayudo') ||
        lower.contains('cómo le ayudo') ||
        lower.contains('ideas para ayudar');
  }

  bool _preguntaMejorarMemoria(String lower) {
    return lower.contains('como mejorar mi memoria') ||
        lower.contains('cómo mejorar mi memoria') ||
        lower.contains('como puedo recordar') ||
        lower.contains('cómo puedo recordar');
  }

  bool _preguntaCuidador(String lower) {
    return lower.contains('quien es mi cuidador') ||
        lower.contains('quién es mi cuidador') ||
        lower.contains('quien es mi cuidadora') ||
        lower.contains('quién es mi cuidadora');
  }

  bool _preguntaConsultante(String lower) {
    return lower.contains('quien es mi consultante') ||
        lower.contains('quién es mi consultante') ||
        lower.contains('quien es mi paciente') ||
        lower.contains('quién es mi paciente');
  }

  bool _esTemaPermitido(String lower) {
    if (lower.isEmpty) return true;
    return _temasPermitidos.any((tema) => lower.contains(tema));
  }

  bool _contieneTemaBloqueado(String lower) {
    return _temasBloqueados.any((tema) => lower.contains(tema));
  }

  bool _esSaludo(String lower) {
    final t = lower.trim();
    return _saludos.any((s) => t == s || t.startsWith('$s ') || t.contains(s));
  }

  bool _esMensajeBase(String lower) {
    final t = lower.trim();
    return _mensajesBase.any((m) => t == m || t.contains(m));
  }

  bool _esSeguimientoCorto(String lower) {
    final t = lower.trim();
    const seguimientos = [
      'por que',
      'por qué',
      'y eso',
      'que hago',
      'qué hago',
      'como',
      'cómo',
      'y luego',
      'despues',
      'después',
      'no entiendo',
      'explícame',
      'explicame',
      'sigue',
      'continua',
      'continúa',
      'por?',
      '¿por?',
    ];

    return t.split(' ').length <= 4 &&
        seguimientos.any((s) => t.contains(s));
  }

  bool _quiereVerRecuerdos(String lower) {
    return lower.contains('mis recuerdos') ||
        lower.contains('qué recuerdos tengo') ||
        lower.contains('que recuerdos tengo') ||
        lower.contains('muéstrame mis recuerdos') ||
        lower.contains('muestrame mis recuerdos') ||
        lower.contains('quiero recordar') ||
        lower.contains('algún recuerdo') ||
        lower.contains('algun recuerdo') ||
        lower.contains('recordar un recuerdo') ||
        lower.contains('ver mis recuerdos') ||
        lower.contains('recordar algo');
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
    String uid,
    String emocion,
    String mensaje,
  ) async {
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
    switch (emocion) {
      case 'feliz':
        return "Me alegra saber que te sientes feliz hoy 💜";
      case 'triste':
        return "Lamento que te sientas triste 😔. Estoy aquí contigo y podemos hablar con calma.";
      case 'ansioso':
        return "Parece que te sientes ansioso 🌿. Vamos paso a paso, con calma.";
      case 'enojado':
        return "Siento que estés molesto 😞. Si quieres, puedes contarme qué pasó.";
      case 'cansado':
        return "Parece que tuviste un día pesado 💫. Descansar también es importante.";
      case 'solo':
        return "No estás solo o sola 💜. Estoy aquí para acompañarte.";
      default:
        return "Estoy aquí contigo 💜";
    }
  }

  Future<void> _guardarMensaje(
    String uid,
    String? mensaje,
    String respuesta, {
    String? imageUrl,
    String? role,
  }) async {
    await _firestore
        .collection('assistant')
        .doc(uid)
        .collection('messages')
        .add({
      'mensaje': (mensaje != null && mensaje.trim().isNotEmpty)
          ? mensaje.trim()
          : '[foto]',
      'respuesta': respuesta,
      'imageUrl': imageUrl,
      'role': role ?? '',
      'fecha': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> _buscarRecuerdosPorFecha(
    String uid,
    DateTime fecha,
  ) async {
    final displayDate = _dateId(fecha);

    final snap = await _firestore
        .collection('memories')
        .doc(uid)
        .collection('user_memories')
        .where('displayDate', isEqualTo: displayDate)
        .orderBy('createdAt', descending: false)
        .get();

    return snap.docs.map((d) => d.data()).toList();
  }

  Future<List<Map<String, dynamic>>> _buscarRecuerdosRecientes(
    String uid, {
    int limit = 5,
  }) async {
    final snap = await _firestore
        .collection('memories')
        .doc(uid)
        .collection('user_memories')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snap.docs.map((d) => d.data()).toList();
  }

  String _armarRespuestaRecuerdos(
    List<Map<String, dynamic>> recuerdos, {
    required String encabezado,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(encabezado);
    buffer.writeln();

    for (final r in recuerdos) {
      final createdAt = r['createdAt'];
      DateTime? fecha;

      if (createdAt is Timestamp) {
        fecha = createdAt.toDate();
      } else if (createdAt is String) {
        try {
          fecha = DateTime.parse(createdAt);
        } catch (_) {}
      }

      final desc = (r['text'] ?? r['descripcion'] ?? '(sin descripción)')
          .toString()
          .trim();
      final url = (r['imageUrl'] ?? '').toString().trim();

      buffer.writeln("📅 ${fecha != null ? _formatearFecha(fecha) : 'Sin fecha'}");
      buffer.writeln("📝 ${desc.isEmpty ? '(sin descripción)' : desc}");
      if (url.isNotEmpty) {
        buffer.writeln("[imagen]$url[/imagen]");
      }
      buffer.writeln("──────────────");
    }

    return buffer.toString().trim();
  }

  String _dateId(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  DateTime? _extraerFechaFlexible(String text) {
    final input = text.toLowerCase().trim();
    final ahora = DateTime.now();

    if (input.contains('hoy')) return ahora;
    if (input.contains('ayer')) return ahora.subtract(const Duration(days: 1));
    if (input.contains('antier') || input.contains('antes de ayer')) {
      return ahora.subtract(const Duration(days: 2));
    }

    final numeric = RegExp(r'(\d{1,2})[\/\- ](\d{1,2})[\/\- ](\d{2,4})');
    final match = numeric.firstMatch(input);

    if (match != null) {
      final d = int.parse(match.group(1)!);
      final m = int.parse(match.group(2)!);
      final y = int.parse(
        match.group(3)!.length == 2 ? "20${match.group(3)!}" : match.group(3)!,
      );
      return DateTime(y, m, d);
    }

    const meses = {
      'enero': 1,
      'febrero': 2,
      'marzo': 3,
      'abril': 4,
      'mayo': 5,
      'junio': 6,
      'julio': 7,
      'agosto': 8,
      'septiembre': 9,
      'octubre': 10,
      'noviembre': 11,
      'diciembre': 12,
    };

    final textoNormal = RegExp(
      r'(\d{1,2}) ?(de)? ?([a-záéíóú]+) ?(de)? ?(\d{2,4})?',
      caseSensitive: false,
    );

    final m2 = textoNormal.firstMatch(input);
    if (m2 != null) {
      final d = int.parse(m2.group(1)!);
      final mesTexto = m2.group(3)!;
      final mes = meses[mesTexto] ?? 1;
      final anio = int.tryParse(m2.group(5) ?? '') ?? DateTime.now().year;
      return DateTime(anio, mes, d);
    }

    return null;
  }

  String _formatearFecha(DateTime f) {
    return DateFormat('dd/MM/yyyy').format(f);
  }

  String _formatearCumpleCorto(DateTime f) {
    final mes = _mesesNombre[f.month - 1];
    return "${f.day} de $mes";
  }

  String _formatearCumpleLargo(DateTime f) {
    final mes = _mesesNombre[f.month - 1];
    return "${f.day} de $mes de ${f.year}";
  }
}





