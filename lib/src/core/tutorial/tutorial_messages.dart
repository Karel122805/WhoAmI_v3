// lib/src/core/tutorial/tutorial_messages.dart

import 'tutorial_keys.dart';

class TutorialMessages {
  const TutorialMessages._();

  static String getMessage(TutorialKey key) {
    switch (key) {
      case TutorialKey.choiceStart:
        return 'Bienvenido a WhoAmI. Aquí puedes iniciar sesión si ya tienes '
            'una cuenta o registrarte por primera vez.';

      case TutorialKey.login:
        return 'Escribe tu correo electrónico y contraseña para entrar a tu '
            'cuenta. Si todavía no tienes una cuenta, puedes crear una desde '
            'el botón que aparece en la parte inferior.';

      case TutorialKey.registerName:
        return 'Vamos a crear tu cuenta. Escribe tu nombre, apellidos y fecha '
            'de nacimiento para continuar con el registro.';

      case TutorialKey.registerPassword:
        return 'Escribe tu correo electrónico y crea una contraseña segura. '
            'Debe tener al menos 8 caracteres, una mayúscula, una minúscula, '
            'un número y un símbolo. Después vuelve a escribirla para '
            'confirmarla.';

      case TutorialKey.registerRole:
        return 'Selecciona cómo utilizarás la aplicación. Puedes registrarte '
            'como cuidador o como consultante. Esta selección permitirá '
            'personalizar las funciones de tu cuenta.';

      case TutorialKey.registerPatient:
        return 'Completa la información solicitada para finalizar la creación '
            'del perfil del consultante.';

      case TutorialKey.homeCaregiver:
        return 'Esta es tu pantalla principal como cuidador. Te mostraré las '
            'funciones más importantes disponibles en tu cuenta.';

      case TutorialKey.homeConsultant:
        return 'Esta es tu pantalla principal como consultante. Te mostraré '
            'las funciones que puedes utilizar dentro de la aplicación.';

      case TutorialKey.caregiverPatients:
        return 'En Pacientes puedes buscar consultantes, enviar solicitudes '
            'de vinculación y consultar a las personas que tienes asignadas.';

      case TutorialKey.caregiverGuides:
        return 'En Guías encontrarás información rápida para ayudarte en '
            'distintas situaciones de cuidado.';

      case TutorialKey.caregiverPrevention:
        return 'En Prevención encontrarás recomendaciones sobre memoria, '
            'sueño, alimentación, medicamentos y cuidados diarios.';

      case TutorialKey.caregiverSupportContacts:
        return 'En Contactos puedes consultar o administrar personas de apoyo '
            'que pueden ayudar al consultante.';

      case TutorialKey.caregiverMemories:
        return 'En Recuerdos puedes consultar y guardar momentos importantes '
            'con fotografías, notas y fechas.';

      case TutorialKey.caregiverReminders:
        return 'En Recordatorios puedes crear avisos o alarmas para '
            'medicamentos, citas, actividades y otras tareas importantes. '
            'También puedes elegir la fecha, la hora y activar una alerta '
            'para recibir el aviso en el momento programado.';

      case TutorialKey.caregiverAssistant:
        return 'El Asistente puede responder preguntas, analizar imágenes y '
            'ayudarte a consultar o guardar información importante.';

      case TutorialKey.caregiverEmergency:
        return 'En esta misma pantalla puedes ver, revisar y atender las '
            'alertas de emergencia enviadas por los consultantes vinculados.';

      case TutorialKey.caregiverNotifications:
        return 'La campana muestra tus notificaciones como alertas, '
            'recuerdos o recordatorios.';

      case TutorialKey.caregiverSettings:
        return 'Desde Ajustes puedes consultar tu perfil, cambiar la '
            'apariencia y administrar las opciones de tu cuenta.';

      case TutorialKey.consultantPhrases:
        return 'En Frases encontrarás mensajes positivos y motivacionales.';

      case TutorialKey.consultantPrevention:
        return 'En Prevención encontrarás recomendaciones para cuidar tu '
            'memoria, salud y bienestar.';

      case TutorialKey.consultantMemories:
        return 'En Recuerdos puedes guardar fotografías, notas y momentos '
            'importantes para consultarlos después.';

      case TutorialKey.consultantReminders:
        return 'En Recordatorios puedes crear avisos o alarmas para '
            'medicamentos, citas, actividades y tareas importantes. '
            'Puedes seleccionar la fecha, la hora y recibir una alerta '
            'cuando llegue el momento programado.';

      case TutorialKey.consultantGames:
        return 'En Juegos encontrarás actividades diseñadas para ejercitar '
            'la memoria y la atención.';

      case TutorialKey.consultantAssistant:
        return 'El Asistente puede conversar contigo, responder preguntas, '
            'analizar fotografías y ayudarte a guardar recuerdos.';

      case TutorialKey.consultantEmergency:
        return 'El botón de Emergencia permite enviar una alerta a tu '
            'cuidador junto con tu ubicación. Para utilizarlo debes tener un '
            'cuidador vinculado.';

      case TutorialKey.consultantNotifications:
        return 'La campana te permite revisar recordatorios, avisos y otras '
            'notificaciones importantes.';

      case TutorialKey.consultantSettings:
        return 'Desde Ajustes puedes consultar tu perfil, cambiar '
            'preferencias y administrar tu cuenta.';

      case TutorialKey.calendar:
        return 'Aquí puedes guardar recuerdos con fotografías y notas, además '
            'de programar recordatorios.';

      case TutorialKey.notifications:
        return 'Aquí encontrarás tus avisos y notificaciones importantes.';

      case TutorialKey.settings:
        return 'Aquí puedes consultar tu perfil y administrar las opciones '
            'de tu cuenta.';

      case TutorialKey.memories:
        return 'Aquí encontrarás los recuerdos que has guardado.';

      case TutorialKey.patientList:
        return 'Aquí puedes buscar y administrar pacientes vinculados.';

      case TutorialKey.tips:
        return 'Aquí encontrarás guías y recomendaciones útiles.';

      case TutorialKey.games:
        return 'Aquí puedes acceder a juegos para estimular la memoria y la '
            'atención.';
    }
  }

  static List<TutorialKey> caregiverHomeSteps() {
    return const <TutorialKey>[
      TutorialKey.homeCaregiver,
      TutorialKey.caregiverPatients,
      TutorialKey.caregiverGuides,
      TutorialKey.caregiverPrevention,
      TutorialKey.caregiverSupportContacts,
      TutorialKey.caregiverMemories,
      TutorialKey.caregiverReminders,
      TutorialKey.caregiverAssistant,
      TutorialKey.caregiverEmergency,
      TutorialKey.caregiverNotifications,
      TutorialKey.caregiverSettings,
    ];
  }

  static List<TutorialKey> consultantHomeSteps() {
    return const <TutorialKey>[
      TutorialKey.homeConsultant,
      TutorialKey.consultantPhrases,
      TutorialKey.consultantPrevention,
      TutorialKey.consultantMemories,
      TutorialKey.consultantReminders,
      TutorialKey.consultantGames,
      TutorialKey.consultantAssistant,
      TutorialKey.consultantEmergency,
      TutorialKey.consultantNotifications,
      TutorialKey.consultantSettings,
    ];
  }
}