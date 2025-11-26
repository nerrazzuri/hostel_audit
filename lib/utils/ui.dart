import 'package:flutter/material.dart';

void showError(BuildContext context, Object error, {String? prefix}) {
  final msg = '${prefix ?? 'Error'}: ${error.toString()}';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), backgroundColor: Colors.red.shade600),
  );
}

void showInfo(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}


