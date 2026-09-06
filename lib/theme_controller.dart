import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<bool> darkModeNotifier = ValueNotifier<bool>(false);

Future<void> loadDarkMode({required bool isDriver}) async {
  final prefs = await SharedPreferences.getInstance();
  darkModeNotifier.value =
      prefs.getBool(isDriver ? 'isDarkModeDriver' : 'isDarkModePassenger') ??
          false;
}

Future<void> setDarkMode(bool value, {required bool isDriver}) async {
  darkModeNotifier.value = value;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(
    isDriver ? 'isDarkModeDriver' : 'isDarkModePassenger',
    value,
  );
}
