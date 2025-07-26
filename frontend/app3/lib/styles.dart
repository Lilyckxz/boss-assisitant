// lib/styles.dart
import 'package:flutter/material.dart';

// 渐变浅蓝色
const LinearGradient mainGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    Color(0xFFE3F0FF), // 较浅的浅蓝色
    Color(0xFFAED6F1), // 较深的浅蓝色
  ],
);

const Color mainBlue = Color(0xFFE3F0FF); // 浅蓝背景
const Color accentBlue = Color(0xFF1976D2); // 主色

const TextStyle titleTextStyle = TextStyle(
  fontWeight: FontWeight.bold,
  fontSize: 20,
  color: Colors.black87,
);

const TextStyle subtitleTextStyle = TextStyle(fontSize: 14, color: Colors.grey);
