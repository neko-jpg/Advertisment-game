import 'package:flutter/material.dart';

/// Describes a cosmetic skin for the player avatar.
class PlayerSkin {
  const PlayerSkin({
    required this.id,
    required this.name,
    required this.cost,
    required this.primaryColor,
    required this.secondaryColor,
    required this.auraColor,
    required this.trailColor,
  });

  final String id;
  final String name;
  final int cost;
  final Color primaryColor;
  final Color secondaryColor;
  final Color auraColor;
  final Color trailColor;
}

/// Default catalog of skins available in the prototype store.
const List<PlayerSkin> kDefaultSkins = [
  PlayerSkin(
    id: 'default',
    name: 'Neon Runner',
    cost: 0,
    primaryColor: Color(0xFF38BDF8),
    secondaryColor: Color(0xFF1D4ED8),
    auraColor: Color(0xFF38BDF8),
    trailColor: Color(0xFFA855F7),
  ),
  PlayerSkin(
    id: 'ember',
    name: 'Ember Trail',
    cost: 100,
    primaryColor: Color(0xFFF97316),
    secondaryColor: Color(0xFFEA580C),
    auraColor: Color(0xFFFF9B45),
    trailColor: Color(0xFFFF5F70),
  ),
  PlayerSkin(
    id: 'glacier',
    name: 'Glacier Drift',
    cost: 300,
    primaryColor: Color(0xFF67E8F9),
    secondaryColor: Color(0xFF0EA5E9),
    auraColor: Color(0xFFBAE6FD),
    trailColor: Color(0xFF60A5FA),
  ),
  PlayerSkin(
    id: 'midnight',
    name: 'Midnight Pulse',
    cost: 800,
    primaryColor: Color(0xFFA855F7),
    secondaryColor: Color(0xFF7C3AED),
    auraColor: Color(0xFFC084FC),
    trailColor: Color(0xFF22D3EE),
  ),
];
