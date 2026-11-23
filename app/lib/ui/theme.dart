import 'package:flutter/material.dart';

/// All colours in one place. The look is a restaurant after dark: warm
/// charcoal surfaces, cream text and a brass accent.
class Palette {
  static const bg = Color(0xFF12100E);
  static const surface = Color(0xFF1C1916);
  static const surface2 = Color(0xFF28231F);
  static const line = Color(0xFF39322B);
  static const ink = Color(0xFFF1E8D8);
  static const muted = Color(0xFF9E9384);
  static const accent = Color(0xFFC9A55B); // brass
  static const onAccent = Color(0xFF17120C);
  static const accentSoft = Color(0xFF2F2819);
  static const tomato = Color(0xFFC4553A); // ember: the one call to action
  static const ok = Color(0xFF74C08F);
  static const warn = Color(0xFFE2AE52);
  static const bad = Color(0xFFE3705C);
  static const owner = Color(0xFF3F8C9A); // you
  static const staff = Color(0xFF6F9FD6);
  static const gold = Color(0xFFD9B25F);
  static const wood = Color(0xFF5A3E2B);
  static const floor = Color(0xFF231D18);
  static const kitchen = Color(0xFF16191B);
}

/// Display type for headings and big numbers' captions.
const displayFont = 'Playfair';

ThemeData buildTheme([Color accent = Palette.accent]) {
  const scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Palette.accent,
    onPrimary: Palette.onAccent,
    primaryContainer: Palette.accentSoft,
    onPrimaryContainer: Palette.accent,
    secondary: Palette.tomato,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFF3A231C),
    onSecondaryContainer: Color(0xFFF0B9A8),
    tertiary: Palette.owner,
    onTertiary: Colors.white,
    error: Palette.bad,
    onError: Palette.onAccent,
    surface: Palette.surface,
    onSurface: Palette.ink,
    onSurfaceVariant: Palette.muted,
    surfaceContainerHighest: Palette.surface2,
    surfaceContainerHigh: Color(0xFF24201C),
    surfaceContainer: Color(0xFF201C19),
    surfaceContainerLow: Palette.surface,
    surfaceContainerLowest: Palette.bg,
    outline: Palette.line,
    outlineVariant: Color(0xFF2E2823),
    inverseSurface: Palette.ink,
    onInverseSurface: Palette.bg,
    shadow: Colors.black,
  );
  final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: Palette.bg);
  TextStyle? serif(TextStyle? t,
          {double? size, FontWeight w = FontWeight.w700}) =>
      t?.copyWith(
          fontFamily: displayFont,
          fontWeight: w,
          fontSize: size,
          letterSpacing: 0.2,
          color: Palette.ink);
  final tt =
      base.textTheme.apply(bodyColor: Palette.ink, displayColor: Palette.ink);
  return base.copyWith(
    textTheme: tt.copyWith(
      displaySmall: serif(tt.displaySmall, w: FontWeight.w800),
      headlineMedium: serif(tt.headlineMedium, w: FontWeight.w800),
      headlineSmall: serif(tt.headlineSmall, w: FontWeight.w700),
      titleLarge: serif(tt.titleLarge, size: 21),
      titleMedium: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      bodyMedium: tt.bodyMedium?.copyWith(height: 1.35),
    ),
    cardTheme: const CardThemeData(
      color: Palette.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: Palette.line)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: Palette.accent,
        foregroundColor: Palette.onAccent,
        disabledBackgroundColor: Palette.surface2,
        disabledForegroundColor: Palette.muted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
            fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.3),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 44),
        foregroundColor: Palette.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: const BorderSide(color: Palette.line),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: Palette.accent)),
    iconTheme: const IconThemeData(color: Palette.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.bg,
      foregroundColor: Palette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
          fontFamily: displayFont,
          fontSize: 21,
          fontWeight: FontWeight.w700,
          color: Palette.ink),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Palette.ink,
      unselectedLabelColor: Palette.muted,
      dividerColor: Palette.line,
      indicatorSize: TabBarIndicatorSize.label,
      indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: Palette.accent, width: 2),
          insets: EdgeInsets.only(bottom: 6)),
      labelStyle: TextStyle(
          fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.6),
      unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500, fontSize: 13, letterSpacing: 0.6),
      overlayColor: WidgetStatePropertyAll(Colors.transparent),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF0E0C0A),
      indicatorColor: Palette.accentSoft,
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? Palette.accent
              : Palette.muted)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          fontSize: 11.5,
          letterSpacing: 0.3,
          fontWeight: FontWeight.w600,
          color: s.contains(WidgetState.selected)
              ? Palette.accent
              : Palette.muted)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: Palette.line,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    ),
    dialogTheme: const DialogThemeData(
        backgroundColor: Palette.surface, surfaceTintColor: Colors.transparent),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Palette.surface2,
      contentTextStyle: TextStyle(color: Palette.ink, fontFamily: 'Inter'),
      actionTextColor: Palette.accent,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? Palette.onAccent : Palette.muted),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? Palette.accent : Palette.surface2),
      trackOutlineColor: WidgetStateProperty.all(Palette.line),
    ),
    sliderTheme: const SliderThemeData(
        activeTrackColor: Palette.accent, thumbColor: Palette.accent),
    chipTheme: base.chipTheme.copyWith(
        backgroundColor: Palette.surface2,
        side: const BorderSide(color: Palette.line),
        labelStyle: const TextStyle(color: Palette.ink)),
    dividerTheme: const DividerThemeData(color: Palette.line, space: 1),
    listTileTheme: const ListTileThemeData(iconColor: Palette.muted),
    tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
            color: Palette.surface2,
            borderRadius: BorderRadius.all(Radius.circular(6))),
        textStyle: TextStyle(color: Palette.ink)),
  );
}

/// Placeholder art behind one catalogue, so real art can be dropped in later (doc 07 §6).
class AssetCatalog {
  static IconData role(String role) => switch (role) {
        'headChef' => Icons.soup_kitchen,
        'lineCook' => Icons.outdoor_grill,
        'prepCook' => Icons.blender,
        'dishwasher' => Icons.wash,
        'server' => Icons.room_service,
        'cashier' => Icons.point_of_sale,
        'cleaner' => Icons.cleaning_services,
        _ => Icons.person,
      };

  static IconData task(String type) => switch (type) {
        'seat' => Icons.event_seat,
        'takeOrder' => Icons.edit_note,
        'cook' => Icons.local_fire_department,
        'deliver' => Icons.room_service,
        'bill' => Icons.receipt_long,
        'clear' => Icons.cleaning_services,
        _ => Icons.circle,
      };

  static IconData equipment(String type) => switch (type) {
        'eq_range' => Icons.local_fire_department,
        'eq_oven' => Icons.microwave,
        'eq_wok' => Icons.ramen_dining,
        'eq_grill' => Icons.outdoor_grill,
        'eq_fryer' => Icons.set_meal,
        'eq_tandoor' => Icons.fireplace,
        'eq_fridge' => Icons.kitchen,
        'eq_freezer' => Icons.ac_unit,
        'eq_shelving' => Icons.shelves,
        'eq_dish_machine' => Icons.wash,
        'eq_hood' => Icons.air,
        'eq_pos' => Icons.point_of_sale,
        'eq_ac' => Icons.mode_fan_off,
        'eq_generator' => Icons.electric_bolt,
        _ => Icons.build,
      };

  static IconData course(String course) => switch (course) {
        'starter' => Icons.tapas,
        'main' => Icons.dinner_dining,
        'side' => Icons.bakery_dining,
        'dessert' => Icons.cake,
        'drink' => Icons.coffee,
        _ => Icons.restaurant,
      };

  static IconData category(String cat) => switch (cat) {
        'staff' => Icons.groups,
        'supplier' => Icons.local_shipping,
        'equipment' => Icons.build_circle,
        'premises' => Icons.home_repair_service,
        'customer' => Icons.sentiment_dissatisfied,
        'money' => Icons.account_balance,
        'inspection' => Icons.fact_check,
        'good' => Icons.celebration,
        _ => Icons.info,
      };

  static Color categoryColor(String cat) => switch (cat) {
        'staff' => const Color(0xFF3E4A78),
        'supplier' => const Color(0xFF6B5230),
        'equipment' => const Color(0xFF4A4A4A),
        'premises' => const Color(0xFF2E5E6A),
        'customer' => const Color(0xFF7A3A2E),
        'money' => const Color(0xFF2E5A44),
        'inspection' => const Color(0xFF5E3E6E),
        'good' => const Color(0xFF8A6A2A),
        _ => Palette.muted,
      };

  static IconData storage(String s) => switch (s) {
        'dry' => Icons.inventory_2,
        'chilled' => Icons.kitchen,
        'frozen' => Icons.ac_unit,
        _ => Icons.inventory,
      };
}
