import 'tutorial_keys.dart';

class TutorialMessages {
  static String getMessage(TutorialKey key) {
    switch (key) {
      case TutorialKey.choiceStart:
        return "Bienvenido a WhoAmI?. Aquí puedes elegir si quieres iniciar sesión o registrarte por primera vez.";

      case TutorialKey.login:
        return "Aquí puedes iniciar sesión con tu correo y contraseña para entrar a tu cuenta.";

      case TutorialKey.registerName:
        return "Vamos a crear tu cuenta. Primero escribe tu nombre como aparecerá en la app.";

      case TutorialKey.registerRole:
        return "Selecciona si eres cuidador o consultante para personalizar tu experiencia.";

      case TutorialKey.registerPatient:
        return "Aquí puedes agregar información sobre tu paciente para comenzar a usar la app.";

      case TutorialKey.homeCaregiver:
        return "Esta es tu pantalla principal como cuidador. Desde aquí puedes ver pacientes, guías, recuerdos y usar el asistente.";

      case TutorialKey.homeConsultant:
        return "Bienvenido. Desde aquí puedes acceder a tus consejos, frases motivacionales, recordar momentos especiales y jugar.";

      case TutorialKey.calendar:
        return "Aquí puedes guardar recuerdos con fotos y notas, y también programar recordatorios.";

      case TutorialKey.notifications:
        return "Aquí verás todos tus recordatorios y alertas importantes.";

      case TutorialKey.settings:
        return "Aquí puedes ver tu perfil, cambiar datos y administrar tu cuenta.";

      case TutorialKey.memories:
        return "Aquí encontrarás todos tus recuerdos guardados con fotos, notas y fechas.";

      case TutorialKey.patientList:
        return "Aquí puedes ver, buscar y administrar tus pacientes.";

      case TutorialKey.tips:
        return "Aquí podrás ver guías y consejos importantes para tu día a día.";

      case TutorialKey.games:
        return "Aquí puedes acceder a los juegos pensados para estimular la memoria y la atención.";
    }
  }
}