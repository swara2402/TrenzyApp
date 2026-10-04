import 'package:flutter/material.dart';
import '../../theme/glass_theme.dart';

const BoxDecoration kPanelDecoration = BoxDecoration(
  borderRadius: BorderRadius.all(Radius.circular(GlassRadius.card)),
  border: Border.fromBorderSide(BorderSide(color: GlassColors.glassBorder)),
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x14FAF6F0), Color(0x08FAF6F0)],
  ),
);
