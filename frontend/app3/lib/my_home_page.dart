// lib/my_home_page.dart

import 'package:flutter/material.dart';
import 'main.dart';
import 'backend_api.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'stash_page.dart';
import 'user_profile_page.dart';
import 'memo_page.dart';

class MyHomePage extends StatefulWidget {
  final String title;
  final Map<String, dynamic> user;
  final VoidCallback onLogout;
  final bool permissionGranted;
  const MyHomePage({
    super.key,
    required this.title,
    required this.user,
    required this.onLogout,
    required this.permissionGranted,
  });

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  static const MethodChannel _iflytekChannel = MethodChannel(
    'com.example.app3/iflytek_asr',
  );
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  bool _isListening = false;
  String _lastWords = '';

  // 待办事项相关
  List<Map<String, dynamic>> _todos = [];
  bool _todoLoading = false;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // 调整后的颜色方案（匹配参考图）
  final Color mainBlue = const Color(0xFFE8F4FC); // 更浅的背景蓝
  final Color accentBlue = const Color(0xFF4A90E2); // 主色调（原图蓝）
  final Color userBubbleColor = const Color(0xFFE1F0FA); // 用户气泡底色
  final Color aiBubbleColor = const Color(0xFFFFFFFF); // AI气泡底色（白色）
  final Color veryLightBlue = const Color(0xFFF0F8FF); // 很淡的淡蓝色

  // 欢迎框相关
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _showWelcomeBox = true;

  @override
  void initState() {
    super.initState();
    if (widget.permissionGranted) {
      initIflytek();
    }
    // _initIflytek(); // 移除自动初始化
    _initNotifications();
    _fetchTodos();

    // 初始化时区数据
    tz.initializeTimeZones();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _notifications.initialize(initializationSettings);
  }

  Future<void> _initIflytek() async {
    await _iflytekChannel.invokeMethod('initIflytek', {
      'appId': '44ab668e',
      'apiKey': 'ee31448f183443ede13c0fb0a4ef19c5',
      'apiSecret': 'NmIzNzllZjJmNzg4NjI1NDY3MWU1ZTRj',
    });
    _iflytekChannel.setMethodCallHandler(_iflytekHandler);
  }

  Future<void> _iflytekHandler(MethodCall call) async {
    if (call.method == 'onIflytekResult') {
      final text = call.arguments as String;
      setState(() {
        _lastWords = text;
        _isListening = false;
      });
      if (text.trim().isNotEmpty) {
        _sendVoiceMessage(text.trim());
      }
    } else if (call.method == 'onIflytekError') {
      setState(() => _isListening = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('语音识别失败: ${call.arguments}')));
    }
  }

  Future<void> _onMicButtonPressed() async {
    if (!_isListening) {
      setState(() => _isListening = true);
      await _iflytekChannel.invokeMethod('startIflytekAsr');
    } else {
      await _iflytekChannel.invokeMethod('stopIflytekAsr');
      setState(() => _isListening = false);
    }
  }

  Future<void> _sendVoiceMessage(String text) async {
    print('发送给后端的内容: ' + text);
    print('当前用户ID: ${widget.user['id']}');
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
      _showWelcomeBox = false;
    });
    try {
      final aiReplyData = await BackendApi.sendVoiceMessage(
        text,
        widget.user['id'],
      );
      final aiReply = aiReplyData['answer'] ?? '';
      final aiRemindAt = aiReplyData['remind_at'];
      setState(() {
        _messages.add({'role': 'ai', 'content': aiReply});
        _isLoading = false;
      });
      // 检查AI回复是否为待办建议
      if (aiReply.startsWith('建议添加到待办') || aiReply.contains('要不要加入待办')) {
        final todoContent = text;
        if (mounted) {
          DateTime? selectedTime = aiRemindAt != null
              ? DateTime.tryParse(aiRemindAt)
              : null;
          showDialog(
            context: context,
            builder: (ctx) => StatefulBuilder(
              builder: (ctx, setStateDialog) => AlertDialog(
                title: const Text('AI建议'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('检测到一句待办事项：\n"$todoContent"\n是否添加到待办？'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          selectedTime == null
                              ? '未选择提醒时间'
                              : DateFormat(
                                  'yyyy-MM-dd HH:mm',
                                ).format(selectedTime!),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: selectedTime ?? now,
                              firstDate: now,
                              lastDate: DateTime(now.year + 5),
                            );
                            if (picked != null) {
                              final time = await showTimePicker(
                                context: ctx,
                                initialTime: selectedTime != null
                                    ? TimeOfDay(
                                        hour: selectedTime!.hour,
                                        minute: selectedTime!.minute,
                                      )
                                    : TimeOfDay.now(),
                              );
                              if (time != null) {
                                setStateDialog(() {
                                  selectedTime = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    time.hour,
                                    time.minute,
                                  );
                                });
                              }
                            }
                          },
                          child: const Text('选择时间'),
                        ),
                      ],
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      print(
                        '[语音添加待办] 内容: ' +
                            todoContent +
                            ' 选择时间: ' +
                            (selectedTime != null
                                ? selectedTime.toString()
                                : '无'),
                      );
                      _addTodo(todoContent, selectedTime);
                    },
                    child: const Text('添加'),
                  ),
                ],
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _messages.add({'role': 'ai', 'content': '获取回复失败: $e'});
        _isLoading = false;
      });
    }
  }

  // 文字输入消息发送
  Future<void> _sendTextMessage(String text) async {
    print('发送给后端的内容: ' + text);
    print('当前用户ID: ${widget.user['id']}');
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
      _showWelcomeBox = false;
    });
    _controller.clear();
    try {
      final aiReplyData = await BackendApi.sendVoiceMessage(
        text,
        widget.user['id'],
      );
      final aiReply = aiReplyData['answer'] ?? '';
      final aiRemindAt = aiReplyData['remind_at'];
      setState(() {
        _messages.add({'role': 'ai', 'content': aiReply});
        _isLoading = false;
      });
      // 检查AI回复是否为待办建议
      if (aiReply.startsWith('建议添加到待办') || aiReply.contains('要不要加入待办')) {
        final todoContent = text;
        if (mounted) {
          DateTime? selectedTime = aiRemindAt != null
              ? DateTime.tryParse(aiRemindAt)
              : null;
          showDialog(
            context: context,
            builder: (ctx) => StatefulBuilder(
              builder: (ctx, setStateDialog) => AlertDialog(
                title: const Text('AI建议'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('检测到一句待办事项：\n"$todoContent"\n是否添加到待办？'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          selectedTime == null
                              ? '未选择提醒时间'
                              : DateFormat(
                                  'yyyy-MM-dd HH:mm',
                                ).format(selectedTime!),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: selectedTime ?? now,
                              firstDate: now,
                              lastDate: DateTime(now.year + 5),
                            );
                            if (picked != null) {
                              final time = await showTimePicker(
                                context: ctx,
                                initialTime: selectedTime != null
                                    ? TimeOfDay(
                                        hour: selectedTime!.hour,
                                        minute: selectedTime!.minute,
                                      )
                                    : TimeOfDay.now(),
                              );
                              if (time != null) {
                                setStateDialog(() {
                                  selectedTime = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    time.hour,
                                    time.minute,
                                  );
                                });
                              }
                            }
                          },
                          child: const Text('选择时间'),
                        ),
                      ],
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      print(
                        '[文字添加待办] 内容: ' +
                            todoContent +
                            ' 选择时间: ' +
                            (selectedTime != null
                                ? selectedTime.toString()
                                : '无'),
                      );
                      _addTodo(todoContent, selectedTime);
                    },
                    child: const Text('添加'),
                  ),
                ],
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _messages.add({'role': 'ai', 'content': '获取回复失败: $e'});
        _isLoading = false;
      });
    }
  }

  void _showAddTodoDialog() {
    String input = '';
    DateTime? selectedTime;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('添加待办事项'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                onChanged: (v) => input = v,
                decoration: const InputDecoration(hintText: '请输入待办事项内容'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    selectedTime == null
                        ? '未选择提醒时间'
                        : DateFormat('yyyy-MM-dd HH:mm').format(selectedTime!),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: now,
                        firstDate: now,
                        lastDate: DateTime(now.year + 5),
                      );
                      if (picked != null) {
                        final time = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null) {
                          setStateDialog(() {
                            selectedTime = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        }
                      }
                    },
                    child: const Text('选择时间'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                // 校验必须在关闭弹窗前
                if (selectedTime != null &&
                    selectedTime!.isBefore(DateTime.now())) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('这个时间已经过去了哦，请选择未来的时间')),
                  );
                  return;
                }
                if (input.trim().isNotEmpty) {
                  print(
                    '[手动添加待办] 内容: ' +
                        input.trim() +
                        ' 选择时间: ' +
                        (selectedTime != null ? selectedTime.toString() : '无'),
                  );
                  _addTodo(input.trim(), selectedTime);
                }
                Navigator.pop(ctx);
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchTodos() async {
    setState(() => _todoLoading = true);
    try {
      _todos = await BackendApi.fetchTodos(widget.user['id']);
      _scheduleNotifications();
    } catch (e) {
      _todos = [];
    } finally {
      setState(() => _todoLoading = false);
    }
  }

  void _addTodo(String content, DateTime? remindTime) {
    print('添加待办事项: $content, 提醒时间: $remindTime');
    // 新增：校验提醒时间是否已过
    if (remindTime != null && remindTime.isBefore(DateTime.now())) {
      if (!kIsWeb) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('无效时间'),
            content: const Text('这个时间已经过去了哦，请选择未来的时间'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('这个时间已经过去了哦，请选择未来的时间')));
      }
      return;
    }
    if (remindTime != null) {
      if (kIsWeb) {
        // scheduleWebNotification('待办事项提醒', content, remindTime);
      } else {
        _notifications.zonedSchedule(
          DateTime.now().millisecondsSinceEpoch,
          '待办事项提醒',
          content,
          tz.TZDateTime.from(remindTime, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'todo_channel',
              '待办提醒',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          androidAllowWhileIdle: true,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        // 手机端弹窗提醒
        final delay = remindTime.difference(DateTime.now());
        if (delay.inMilliseconds > 0) {
          Future.delayed(delay, () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('待办事项提醒'),
                content: Text(content),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('知道了'),
                  ),
                ],
              ),
            );
          });
        }
      }
    }

    // 调用后端 API 同步待办事项
    BackendApi.addTodo(content, remindAt: remindTime, userId: widget.user['id'])
        .then((_) {
          print('待办事项已同步到后端');
        })
        .catchError((error) {
          print('同步待办事项到后端失败: $error');
          if (!kIsWeb) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('添加失败'),
                content: Text('添加待办事项失败: $error'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('知道了'),
                  ),
                ],
              ),
            );
          } else {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('添加待办事项失败: $error')));
          }
        });
  }

  void _scheduleNotifications() {
    for (final todo in _todos) {
      final remindTime = DateTime.parse(todo['remind_at']);
      if (kIsWeb) {
        // scheduleWebNotification('待办事项提醒', todo['content'], remindTime);
      } else {
        _notifications.zonedSchedule(
          todo['id'],
          '待办事项提醒',
          todo['content'],
          tz.TZDateTime.from(remindTime, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'todo_channel',
              '待办提醒',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          androidAllowWhileIdle: true,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        // 手机端弹窗提醒
        final delay = remindTime.difference(DateTime.now());
        if (delay.inMilliseconds > 0) {
          Future.delayed(delay, () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('待办事项提醒'),
                content: Text(todo['content']),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('知道了'),
                  ),
                ],
              ),
            );
          });
        }
      }
    }
  }

  void scheduleWebNotification(
    String title,
    String body,
    DateTime scheduledTime,
  ) {
    final now = DateTime.now();
    final delay = scheduledTime.difference(now);
    print(
      '[Web通知] 计划在: ' +
          scheduledTime.toString() +
          ' 弹窗提醒: ' +
          title +
          ' - ' +
          body +
          ' (当前时间: ' +
          now.toString() +
          ', 延迟: ' +
          delay.inSeconds.toString() +
          '秒)',
    );
    if (delay.isNegative) {
      print('[Web通知] 已经过期，不再弹窗');
      return;
    }
    Timer(delay, () {
      print('[Web通知] 到点弹窗: ' + title + ' - ' + body);
      // 到点时弹出对话框提醒
      showWebDialog(body);
    });
  }

  void showWebDialog(String content) {
    // 只在Web端弹窗
    if (kIsWeb) {
      showDialog(
        context: navigatorKey.currentState!.overlay!.context,
        builder: (ctx) => AlertDialog(
          title: const Text('待办事项提醒'),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    }
  }

  // 新增公开方法，供 main.dart 调用
  Future<void> initIflytek() async {
    await _initIflytek();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: CircleAvatar(
                backgroundColor: mainBlue,
                radius: 16,
                child: IconButton(
                  icon: const Icon(
                    Icons.storage_rounded,
                    size: 18,
                    color: Color(0xFF4A90E2),
                  ),
                  tooltip: '内容订阅',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StashPage(userId: widget.user['id']),
                      ),
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: CircleAvatar(
                backgroundColor: mainBlue,
                radius: 16,
                child: IconButton(
                  icon: const Icon(
                    Icons.event_note_rounded,
                    size: 18,
                    color: Color(0xFF4A90E2),
                  ),
                  tooltip: '备忘录',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MemoPage(
                          user: widget.user,
                          onLogout: widget.onLogout,
                        ),
                      ),
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: CircleAvatar(
                backgroundColor: mainBlue,
                radius: 16,
                child: IconButton(
                  icon: const Icon(
                    Icons.logout,
                    size: 18,
                    color: Color(0xFF4A90E2),
                  ),
                  tooltip: '退出登录',
                  onPressed: widget.onLogout,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // 欢迎框
            if (_showWelcomeBox)
              FadeTransition(
                opacity: _animation,
                child: ScaleTransition(
                  scale: _animation,
                  child: Container(
                    margin: EdgeInsets.all(16.0),
                    padding: EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: veryLightBlue.withOpacity(0.85), // 半透明
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '你好，',
                                    style: TextStyle(
                                      fontSize: 18.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '我是你的AI助手',
                                    style: TextStyle(
                                      fontSize: 18.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8.0),
                                  Text(
                                    '我会热心解答你的每一个问题。让我们开启愉快的对话之旅吧！',
                                    style: TextStyle(fontSize: 14.0),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 16.0),
                            Image.network(
                              'https://img.icons8.com/?size=160&id=gJe74kt934cg&format=png',
                              width: 80.0,
                              height: 80.0,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Column(
                          children: [
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '欢迎使用AI助手，点击右下角麦克风可语音提问',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '进入内容订阅专区，获取更丰富且全面的生活实时资讯',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '可添加待办事项并设置提醒，体验更多功能',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // 聊天区域
            Expanded(
              child: Container(
                color: Colors.transparent,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isUser = msg['role'] == 'user';
                    return Align(
                      alignment: isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: () {
                          if (msg['content'] != null) {
                            Clipboard.setData(
                              ClipboardData(text: msg['content']!),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已复制到剪贴板')),
                            );
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isUser ? userBubbleColor : aiBubbleColor,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: isUser
                                  ? const Radius.circular(18)
                                  : const Radius.circular(4),
                              bottomRight: isUser
                                  ? const Radius.circular(4)
                                  : const Radius.circular(18),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          constraints: const BoxConstraints(maxWidth: 340),
                          child: MarkdownBody(
                            data: msg['content'] ?? '',
                            selectable: true,
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(
                                fontSize: 15,
                                fontFamily: 'PingFang SC',
                                color: isUser ? accentBlue : Colors.black87,
                              ),
                            ),
                            onTapLink: (text, href, title) async {
                              if (href != null) {
                                final uri = Uri.tryParse(href);
                                if (uri != null && await canLaunchUrl(uri)) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('无法打开链接: $href')),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // 底部输入栏
            Container(
              color: Colors.transparent,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              decoration: InputDecoration(
                                hintText: '有什么需要问我的吗~',
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                                filled: false,
                                suffixIcon: _controller.text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.clear,
                                          color: Colors.grey[400],
                                        ),
                                        onPressed: () => _controller.clear(),
                                      )
                                    : null,
                              ),
                              style: const TextStyle(
                                fontSize: 15,
                                fontFamily: 'PingFang SC',
                              ),
                              onSubmitted: (value) async {
                                if (value.trim().isNotEmpty && !_isLoading) {
                                  await _sendTextMessage(value.trim());
                                  _controller.clear();
                                }
                              },
                            ),
                          ),
                          // 发送按钮
                          const SizedBox(width: 6),
                          ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () async {
                                    final text = _controller.text.trim();
                                    if (text.isNotEmpty) {
                                      await _sendTextMessage(text);
                                      _controller.clear();
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentBlue,
                              foregroundColor: Colors.white,
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(12),
                              elevation: 0,
                            ),
                            child: const Icon(Icons.send, size: 18),
                          ),
                          const SizedBox(width: 4),
                          // 语音按钮
                          ElevatedButton.icon(
                            icon: Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                              color: accentBlue,
                            ),
                            label: const SizedBox.shrink(),
                            onPressed: _isLoading ? null : _onMicButtonPressed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: userBubbleColor,
                              foregroundColor: accentBlue,
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(12),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
