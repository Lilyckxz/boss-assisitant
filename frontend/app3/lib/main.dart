import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';

import 'auth_page.dart';
import 'my_home_page.dart';
import 'memo_page.dart';

// 全局导航key用于全局弹窗
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

bool permissionGranted = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await requestPermissions();
  var mic = await Permission.microphone.status;
  print('Microphone permission: ' + mic.toString());
  permissionGranted = mic == PermissionStatus.granted;
  runApp(const MyApp());
}

Future<void> requestPermissions() async {
  await Permission.microphone.request();
  await Permission.storage.request();
  await Permission.phone.request();
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Map<String, dynamic>? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      setState(() {
        _user = json.decode(userStr);
        _loading = false;
      });
    } else {
      setState(() {
        _user = null;
        _loading = false;
      });
    }
  }

  Future<void> _onLogin(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', json.encode(user));
    setState(() {
      _user = user;
    });
  }

  Future<void> _onLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
    setState(() {
      _user = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey, // 新增
      home: _user == null
          ? AuthPage(onLogin: _onLogin)
          : MyHomePage(
              title: 'AI聊天助手',
              user: _user!,
              onLogout: _onLogout,
              permissionGranted: permissionGranted,
            ),
    );
  }
}
