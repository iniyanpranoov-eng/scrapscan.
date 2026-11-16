import 'dart:convert';
import 'package:flutter/material.dart';

class ScrapCategory {
  final int? id;
  final String name;
  final double ratePerKg;
  final bool isDefault;
  final String iconName;
  final String description;
  final List<String> recyclingSteps;
  final String disposalWarning;

  const ScrapCategory({
    this.id,
    required this.name,
    required this.ratePerKg,
    this.isDefault = true,
    this.iconName = 'recycling_rounded',
    this.description = '',
    this.recyclingSteps = const [],
    this.disposalWarning = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'rate_per_kg': ratePerKg,
      'is_default': isDefault ? 1 : 0,
      'icon_name': iconName,
      'description': description,
      'recycling_steps': jsonEncode(recyclingSteps),
      'disposal_warning': disposalWarning,
    };
  }

  factory ScrapCategory.fromMap(Map<String, dynamic> map) {
    List<String> steps = [];
    if (map['recycling_steps'] != null) {
      if (map['recycling_steps'] is List) {
        steps = (map['recycling_steps'] as List).map((e) => e.toString()).toList();
      } else if (map['recycling_steps'] is String &&
          (map['recycling_steps'] as String).trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(map['recycling_steps'] as String);
          if (decoded is List) {
            steps = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {
          steps = (map['recycling_steps'] as String)
              .split('\n')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        }
      }
    }

    return ScrapCategory(
      id: map['id'] as int?,
      name: map['name'] as String,
      ratePerKg: (map['rate_per_kg'] as num).toDouble(),
      isDefault: (map['is_default'] as int? ?? 1) == 1,
      iconName: (map['icon_name'] as String?) ?? 'recycling_rounded',
      description: (map['description'] as String?) ?? '',
      recyclingSteps: steps,
      disposalWarning: (map['disposal_warning'] as String?) ?? '',
    );
  }

  ScrapCategory copyWith({
    int? id,
    String? name,
    double? ratePerKg,
    bool? isDefault,
    String? iconName,
    String? description,
    List<String>? recyclingSteps,
    String? disposalWarning,
  }) {
    return ScrapCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      ratePerKg: ratePerKg ?? this.ratePerKg,
      isDefault: isDefault ?? this.isDefault,
      iconName: iconName ?? this.iconName,
      description: description ?? this.description,
      recyclingSteps: recyclingSteps ?? this.recyclingSteps,
      disposalWarning: disposalWarning ?? this.disposalWarning,
    );
  }

  IconData get iconData {
    switch (iconName) {
      case 'local_drink_rounded':
        return Icons.local_drink_rounded;
      case 'inventory_2_rounded':
        return Icons.inventory_2_rounded;
      case 'description_rounded':
        return Icons.description_rounded;
      case 'hardware_rounded':
        return Icons.hardware_rounded;
      case 'cable_rounded':
        return Icons.cable_rounded;
      case 'memory_rounded':
        return Icons.memory_rounded;
      case 'liquor_rounded':
        return Icons.liquor_rounded;
      default:
        return Icons.recycling_rounded;
    }
  }
}
