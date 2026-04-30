import 'package:flutter/material.dart';

enum PWRole { none, receive, send }

class StationInfo {
  final String id;
  final String label;
  final Color color;
  final IconData icon;
  final String? allowedType;
  final String? fixedDestination;
  final PWRole pwRole;

  const StationInfo({
    required this.id,
    required this.label,
    required this.color,
    required this.icon,
    this.allowedType,
    this.fixedDestination,
    this.pwRole = PWRole.none,
  });
}
