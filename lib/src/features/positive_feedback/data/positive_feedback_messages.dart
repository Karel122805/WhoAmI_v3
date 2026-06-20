import 'dart:math';

class PositiveFeedbackMessages {
  PositiveFeedbackMessages._();

  static final Random _random = Random();

  static const List<String> memorySavedMessages = [
    '¡Excelente trabajo! Has guardado un nuevo recuerdo.',
    'Muy bien. Cada recuerdo ayuda a conservar momentos importantes.',
    'Lo hiciste muy bien. Este recuerdo quedó guardado con éxito.',
    'Gran trabajo. Guardar recuerdos puede ayudarte a revivir momentos especiales.',
    '¡Muy bien! Tu recuerdo se guardó correctamente.',
  ];

  static const List<String> neutralMessages = [
    'Buen intento. Puedes volver a intentarlo cuando quieras.',
    'No pasa nada. Puedes intentarlo de nuevo con calma.',
    'Está bien, tómate tu tiempo y vuelve a intentarlo.',
    'Puedes seguir practicando poco a poco.',
  ];

  static String memorySaved() {
    return memorySavedMessages[_random.nextInt(memorySavedMessages.length)];
  }

  static String neutral() {
    return neutralMessages[_random.nextInt(neutralMessages.length)];
  }
}