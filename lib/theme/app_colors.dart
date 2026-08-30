import 'package:flutter/material.dart';

class AppColors {
  static const ink = Color(0xFF1C2624);
  static const muted = Color(0xFF74807B);
  static const paper = Color(0xFFF5F1EA);
  static const cream = Color(0xFFFAF8F4);
  static const white = Color(0xFFFFFDFA);
  static const line = Color(0xFFDFDDD7);
  static const forest = Color(0xFF1E3B35);
  static const forest2 = Color(0xFF2E594E);
  static const gold = Color(0xFFD99F43);
  static const goldPale = Color(0xFFF2E5CA);
  static const coral = Color(0xFFD77C5E);
  static const food = Color(0xFFEF3340);
  static const coffee = Color(0xFF936037);
  static const work = Color(0xFF0EA5E9);
  static const gym = Color(0xFF171827);
  static const events = Color(0xFF7C3AED);
  static const public = Color(0xFF789C68);

  static Color category(String id) {
    return switch (id) {
      'food' => food,
      'coffee' => coffee,
      'work' => work,
      'gym' => gym,
      'events' => events,
      'public' => public,
      _ => forest,
    };
  }
}
