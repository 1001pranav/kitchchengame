import 'package:flutter/material.dart';

/// All colours in one place so a dark theme or another cuisine skin can be added later.
class Palette {
  static const bg = Color(0xFFF6F1E9);
  static const surface = Color(0xFFFFFCF7);
  static const surface2 = Color(0xFFEFE7DA);
  static const line = Color(0xFFE0D6C6);
  static const ink = Color(0xFF2A2420);
  static const muted = Color(0xFF7A6E60);
  static const accent = Color(0xFF2F7D4F); // Italian green
  static const accentSoft = Color(0xFFDCEFE3);
  static const tomato = Color(0xFFC8462F);
  static const ok = Color(0xFF3E8E5A);
  static const warn = Color(0xFFC98A1B);
  static const bad = Color(0xFFC24A3A);
  static const owner = Color(0xFF7A3FA0);
  static const staff = Color(0xFF3A6EA8);
  static const gold = Color(0xFFE0A526);
  static const wood = Color(0xFFD9C3A0);
  static const floor = Color(0xFFEDE3D2);
  static const kitchen = Color(0xFF3B3631);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.accent,
    primary: Palette.accent,
    secondary: Palette.tomato,
    surface: Palette.surface,
    error: Palette.bad,
  );
  final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Palette.bg);
  return base.copyWith(
    textTheme: base.textTheme
        .apply(bodyColor: Palette.ink, displayColor: Palette.ink)
        .copyWith(
          headlineMedium: base.textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
          titleLarge:
              base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          titleMedium:
              base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
    cardTheme: const CardThemeData(
      color: Palette.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: Palette.line)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: Palette.line),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Palette.surface,
      indicatorColor: Palette.accentSoft,
      labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    ),
    chipTheme:
        base.chipTheme.copyWith(side: const BorderSide(color: Palette.line)),
    dividerTheme: const DividerThemeData(color: Palette.line, space: 1),
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
        'main' => Icons.local_pizza,
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
        'staff' => const Color(0xFF5B6CB5),
        'supplier' => const Color(0xFF8A6A3B),
        'equipment' => const Color(0xFF6B6B6B),
        'premises' => const Color(0xFF3F7F8F),
        'customer' => const Color(0xFFB5523F),
        'money' => const Color(0xFF2F6F4F),
        'inspection' => const Color(0xFF8C5A9E),
        'good' => const Color(0xFFD08A1E),
        _ => Palette.muted,
      };

  static IconData storage(String s) => switch (s) {
        'dry' => Icons.inventory_2,
        'chilled' => Icons.kitchen,
        'frozen' => Icons.ac_unit,
        _ => Icons.inventory,
      };
}
