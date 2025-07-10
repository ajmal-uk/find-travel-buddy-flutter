import 'package:flutter/material.dart';

class AppColors {
  static Color genderBorderColor(String gender) {
    if (gender.toLowerCase() == "male") {
      return Colors.lightBlue;
    } else if (gender.toLowerCase() == "female") {
      return Colors.pinkAccent.shade100;
    } else {
      return Colors.yellow.shade600;
    }
  }

  static Color genderShadowColor(String gender) {
    if (gender.toLowerCase() == "male") {
      return Colors.lightBlue.withOpacity(0.1);
    } else if (gender.toLowerCase() == "female") {
      return Colors.pinkAccent.shade100.withOpacity(0.1);
    } else {
      return Colors.yellow.shade600.withOpacity(0.1);
    }
  }

  static Color getLegendColor(String legend) {
    if (legend.contains('Male')) return Colors.lightBlue;
    if (legend.contains('Female')) return Colors.pink;
    if (legend.contains('Other')) return Colors.yellow;
    if (legend.contains('Completed')) return Colors.green;
    if (legend.contains('Incompleted')) return Colors.grey;
    if (legend.contains('Removed')) return Colors.red;
    return Colors.green;
  }
}
