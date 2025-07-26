// lib/memo_page.dart
import 'package:flutter/material.dart';
import 'memo_todo_page.dart';
import 'user_profile_page.dart';
import 'styles.dart';

class MemoPage extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  const MemoPage({super.key, required this.user, required this.onLogout});

  @override
  State<MemoPage> createState() => _MemoPageState();
}

class _MemoPageState extends State<MemoPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 渐变背景
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF5B9BD5), // 深蓝（顶部颜色）
                Color(0xFFE3F0FF), // 浅蓝（底部颜色）
              ],
            ),
          ),
        ),
        // 内容
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('备忘录'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            shadowColor: Colors.transparent,
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.7),
              tabs: const [
                Tab(text: '待办事项'),
                Tab(text: '人脉管理'),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: '退出登录',
                onPressed: widget.onLogout,
              ),
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              MemoTodoPage(user: widget.user),
              UserProfilePage(userId: widget.user['id']),
            ],
          ),
        ),
      ],
    );
  }
}
