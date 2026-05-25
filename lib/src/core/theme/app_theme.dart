import 'package:flutter/material.dart';

/// ===========================================================
/// WHOAMI THEME SYSTEM
/// - Light theme
/// - Dark theme
/// - Simplified mode support
/// - Semantic colors for screens
/// ===========================================================

const kPurple = Color(0xFFD6A7F4);
const kBlue = Color(0xFF9ED3FF);
const kInk = Color(0xFF111111);
const kGrey1 = Color(0xFF6B7280);
const kYellow = Color(0xFFFFF7CC);
const kGreenPastel = Color(0xFFB6E2B6);

class AppColors extends ThemeExtension<AppColors> {
  final Color pageBackground;
  final Color cardBackground;
  final Color elevatedCard;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color inputFill;
  final Color primaryButton;
  final Color primaryButtonText;
  final Color secondaryButton;
  final Color secondaryButtonText;
  final Color emergency;
  final Color emergencyText;
  final Color categoryYellow;
  final Color categoryPink;
  final Color categoryBlue;
  final Color categoryGreen;
  final Color categoryPurple;
  final Color chatAssistantBubble;
  final Color chatUserBubble;
  final Color chipBackground;
  final Color chipSelected;
  final Color chipText;
  final Color chipSelectedText;
  final Color calendarSurface;

  const AppColors({
    required this.pageBackground,
    required this.cardBackground,
    required this.elevatedCard,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.inputFill,
    required this.primaryButton,
    required this.primaryButtonText,
    required this.secondaryButton,
    required this.secondaryButtonText,
    required this.emergency,
    required this.emergencyText,
    required this.categoryYellow,
    required this.categoryPink,
    required this.categoryBlue,
    required this.categoryGreen,
    required this.categoryPurple,
    required this.chatAssistantBubble,
    required this.chatUserBubble,
    required this.chipBackground,
    required this.chipSelected,
    required this.chipText,
    required this.chipSelectedText,
    required this.calendarSurface,
  });

  @override
  AppColors copyWith({
    Color? pageBackground,
    Color? cardBackground,
    Color? elevatedCard,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? inputFill,
    Color? primaryButton,
    Color? primaryButtonText,
    Color? secondaryButton,
    Color? secondaryButtonText,
    Color? emergency,
    Color? emergencyText,
    Color? categoryYellow,
    Color? categoryPink,
    Color? categoryBlue,
    Color? categoryGreen,
    Color? categoryPurple,
    Color? chatAssistantBubble,
    Color? chatUserBubble,
    Color? chipBackground,
    Color? chipSelected,
    Color? chipText,
    Color? chipSelectedText,
    Color? calendarSurface,
  }) {
    return AppColors(
      pageBackground: pageBackground ?? this.pageBackground,
      cardBackground: cardBackground ?? this.cardBackground,
      elevatedCard: elevatedCard ?? this.elevatedCard,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      inputFill: inputFill ?? this.inputFill,
      primaryButton: primaryButton ?? this.primaryButton,
      primaryButtonText: primaryButtonText ?? this.primaryButtonText,
      secondaryButton: secondaryButton ?? this.secondaryButton,
      secondaryButtonText: secondaryButtonText ?? this.secondaryButtonText,
      emergency: emergency ?? this.emergency,
      emergencyText: emergencyText ?? this.emergencyText,
      categoryYellow: categoryYellow ?? this.categoryYellow,
      categoryPink: categoryPink ?? this.categoryPink,
      categoryBlue: categoryBlue ?? this.categoryBlue,
      categoryGreen: categoryGreen ?? this.categoryGreen,
      categoryPurple: categoryPurple ?? this.categoryPurple,
      chatAssistantBubble: chatAssistantBubble ?? this.chatAssistantBubble,
      chatUserBubble: chatUserBubble ?? this.chatUserBubble,
      chipBackground: chipBackground ?? this.chipBackground,
      chipSelected: chipSelected ?? this.chipSelected,
      chipText: chipText ?? this.chipText,
      chipSelectedText: chipSelectedText ?? this.chipSelectedText,
      calendarSurface: calendarSurface ?? this.calendarSurface,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      pageBackground:
          Color.lerp(pageBackground, other.pageBackground, t) ?? pageBackground,
      cardBackground:
          Color.lerp(cardBackground, other.cardBackground, t) ?? cardBackground,
      elevatedCard:
          Color.lerp(elevatedCard, other.elevatedCard, t) ?? elevatedCard,
      textPrimary:
          Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      border: Color.lerp(border, other.border, t) ?? border,
      inputFill: Color.lerp(inputFill, other.inputFill, t) ?? inputFill,
      primaryButton:
          Color.lerp(primaryButton, other.primaryButton, t) ?? primaryButton,
      primaryButtonText:
          Color.lerp(primaryButtonText, other.primaryButtonText, t) ??
              primaryButtonText,
      secondaryButton:
          Color.lerp(secondaryButton, other.secondaryButton, t) ??
              secondaryButton,
      secondaryButtonText:
          Color.lerp(secondaryButtonText, other.secondaryButtonText, t) ??
              secondaryButtonText,
      emergency: Color.lerp(emergency, other.emergency, t) ?? emergency,
      emergencyText:
          Color.lerp(emergencyText, other.emergencyText, t) ?? emergencyText,
      categoryYellow:
          Color.lerp(categoryYellow, other.categoryYellow, t) ?? categoryYellow,
      categoryPink:
          Color.lerp(categoryPink, other.categoryPink, t) ?? categoryPink,
      categoryBlue:
          Color.lerp(categoryBlue, other.categoryBlue, t) ?? categoryBlue,
      categoryGreen:
          Color.lerp(categoryGreen, other.categoryGreen, t) ?? categoryGreen,
      categoryPurple:
          Color.lerp(categoryPurple, other.categoryPurple, t) ?? categoryPurple,
      chatAssistantBubble:
          Color.lerp(chatAssistantBubble, other.chatAssistantBubble, t) ??
              chatAssistantBubble,
      chatUserBubble:
          Color.lerp(chatUserBubble, other.chatUserBubble, t) ??
              chatUserBubble,
      chipBackground:
          Color.lerp(chipBackground, other.chipBackground, t) ?? chipBackground,
      chipSelected:
          Color.lerp(chipSelected, other.chipSelected, t) ?? chipSelected,
      chipText: Color.lerp(chipText, other.chipText, t) ?? chipText,
      chipSelectedText:
          Color.lerp(chipSelectedText, other.chipSelectedText, t) ??
              chipSelectedText,
      calendarSurface:
          Color.lerp(calendarSurface, other.calendarSurface, t) ??
              calendarSurface,
    );
  }

  static const light = AppColors(
    pageBackground: Color(0xFFFFFFFF),
    cardBackground: Color(0xFFF8F8FA),
    elevatedCard: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF111111),
    textSecondary: Color(0xFF6B7280),
    border: Color(0xFFE5E7EB),
    inputFill: Color(0xFFF7F8FA),
    primaryButton: kBlue,
    primaryButtonText: Color(0xFF111111),
    secondaryButton: kPurple,
    secondaryButtonText: Color(0xFF111111),
    emergency: Color(0xFFF59CA8),
    emergencyText: Color(0xFF111111),
    categoryYellow: Color(0xFFF7EE9E),
    categoryPink: Color(0xFFF3A0A8),
    categoryBlue: Color(0xFFA8D2F4),
    categoryGreen: Color(0xFF99E08E),
    categoryPurple: Color(0xFFC796E9),
    chatAssistantBubble: Color(0xFFA8D2F4),
    chatUserBubble: Color(0xFFEAD6FA),
    chipBackground: Color(0xFFF3F4F6),
    chipSelected: Color(0xFFA8D2F4),
    chipText: Color(0xFF222222),
    chipSelectedText: Color(0xFF111111),
    calendarSurface: Color(0xFFFFFFFF),
  );

  static const dark = AppColors(
    pageBackground: Color(0xFF050816),
    cardBackground: Color(0xFF111827),
    elevatedCard: Color(0xFF172033),
    textPrimary: Color(0xFFF3F4F6),
    textSecondary: Color(0xFFB9C0CC),
    border: Color(0xFF2A3750),
    inputFill: Color(0xFF101722),
    primaryButton: Color(0xFF6B8DBA),
    primaryButtonText: Color(0xFFF8FAFC),
    secondaryButton: Color(0xFF8D73B8),
    secondaryButtonText: Color(0xFFF8FAFC),
    emergency: Color(0xFFC97D8A),
    emergencyText: Color(0xFFFFFFFF),
    categoryYellow: Color(0xFF8F8450),
    categoryPink: Color(0xFF9A6870),
    categoryBlue: Color(0xFF5E7FA4),
    categoryGreen: Color(0xFF5F9460),
    categoryPurple: Color(0xFF8D6AA5),
    chatAssistantBubble: Color(0xFF5E7FA4),
    chatUserBubble: Color(0xFF6E5F95),
    chipBackground: Color(0xFF1C2536),
    chipSelected: Color(0xFF5E7FA4),
    chipText: Color(0xFFF3F4F6),
    chipSelectedText: Color(0xFFFFFFFF),
    calendarSurface: Color(0xFF111827),
  );
}

extension AppThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);

  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

ThemeData buildAppTheme({
  required Color seedColor,
  required bool darkMode,
  required bool simplified,
}) {
  final appColors = darkMode ? AppColors.dark : AppColors.light;
  final brightness = darkMode ? Brightness.dark : Brightness.light;

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: appColors.pageBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    ).copyWith(
      primary: darkMode ? const Color(0xFF9DBAF0) : seedColor,
      secondary: darkMode ? const Color(0xFFB59AF5) : kPurple,
      surface: appColors.cardBackground,
      onSurface: appColors.textPrimary,
      outline: appColors.border,
      error: appColors.emergency,
      onError: appColors.emergencyText,
    ),
    extensions: <ThemeExtension<dynamic>>[appColors],
    appBarTheme: AppBarTheme(
      backgroundColor: appColors.pageBackground,
      foregroundColor: appColors.textPrimary,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: appColors.textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: appColors.textPrimary),
    ),
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: appColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: appColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: appColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: 18,
        color: appColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 16,
        color: appColors.textPrimary,
      ),
      bodySmall: TextStyle(
        fontSize: 14,
        color: appColors.textSecondary,
      ),
      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: appColors.textPrimary,
      ),
    ),
    cardTheme: CardThemeData(
      color: appColors.cardBackground,
      elevation: darkMode ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: appColors.border),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: DividerThemeData(
      color: appColors.border,
      thickness: 1,
    ),
    iconTheme: IconThemeData(color: appColors.textPrimary),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: appColors.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: TextStyle(color: appColors.textSecondary),
      labelStyle: TextStyle(color: appColors.textSecondary),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: appColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: seedColor, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: appColors.emergency, width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: appColors.emergency, width: 1.8),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        elevation: 0,
        backgroundColor: appColors.primaryButton,
        foregroundColor: appColors.primaryButtonText,
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: appColors.border),
        foregroundColor: appColors.textPrimary,
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStatePropertyAll(appColors.border),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return appColors.primaryButtonText;
        }
        return appColors.textSecondary;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return appColors.primaryButton;
        }
        return appColors.chipBackground;
      }),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: appColors.chipBackground,
      selectedColor: appColors.chipSelected,
      disabledColor: appColors.chipBackground,
      side: BorderSide(color: appColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      labelStyle: TextStyle(
        color: appColors.chipText,
        fontWeight: FontWeight.w600,
      ),
      secondaryLabelStyle: TextStyle(
        color: appColors.chipSelectedText,
        fontWeight: FontWeight.w700,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: appColors.pageBackground,
      selectedItemColor: seedColor,
      unselectedItemColor: appColors.textSecondary,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
  );

  if (!simplified) return base;

  return base.copyWith(
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}

/// ===========================================================
/// BUTTON HELPERS
/// ===========================================================

ButtonStyle pillBlue(BuildContext context) =>
    FilledButton.styleFrom(backgroundColor: context.appColors.primaryButton);

ButtonStyle pillLav(BuildContext context) =>
    FilledButton.styleFrom(backgroundColor: context.appColors.secondaryButton);

ButtonStyle pillGreen(BuildContext context) =>
    FilledButton.styleFrom(backgroundColor: context.appColors.categoryGreen);

ButtonStyle pillDanger(BuildContext context) =>
    FilledButton.styleFrom(backgroundColor: context.appColors.emergency);

ButtonStyle pill(BuildContext context, Color color) =>
    FilledButton.styleFrom(backgroundColor: color);

/// ===========================================================
/// COMMON TEXT STYLES
/// ===========================================================

TextStyle welcomeKicker(BuildContext context) => TextStyle(
      letterSpacing: 1.5,
      color: context.appColors.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );





