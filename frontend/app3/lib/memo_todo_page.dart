// ...existing code...
// lib/memo_todo_page.dart
import 'package:flutter/material.dart';
import 'backend_api.dart';
import 'package:intl/intl.dart';
import 'styles.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;

// 空状态提示组件
class EmptyHintCard extends StatelessWidget {
  final String title;
  final String hintText;
  final Color titleColor;
  final IconData emojiIcon;
  final Color emojiBgColor;
  final Color emojiIconColor;
  const EmptyHintCard({
    super.key,
    required this.title,
    required this.hintText,
    this.titleColor = const Color(0xFFB39DDB), // 柔和淡紫
    this.emojiIcon = Icons.emoji_emotions,
    this.emojiBgColor = const Color(0xFF81D4FA), // 彩色圆
    this.emojiIconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 320,
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  hintText,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF444444),
                  ),
                ),
              ],
            ),
          ),
          // 右上角卷角
          Positioned(
            top: -1,
            right: -1,
            child: ClipPath(
              clipper: _CornerClipper(),
              child: Container(
                width: 38,
                height: 38,
                color: const Color(0xFFF3E5F5),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Icon(
                    Icons.sticky_note_2,
                    size: 18,
                    color: Color(0xFFB39DDB),
                  ),
                ),
              ),
            ),
          ),
          // 左上角彩色圆形表情
          Positioned(
            top: -22,
            left: 18,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: emojiBgColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: emojiBgColor.withOpacity(0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Center(
                child: Icon(emojiIcon, color: emojiIconColor, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 右上角卷角裁剪器
class _CornerClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.quadraticBezierTo(size.width * 0.7, size.height * 0.7, 0, 0);
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class MemoTodoPage extends StatefulWidget {
  final Map<String, dynamic> user;
  const MemoTodoPage({super.key, required this.user});

  @override
  State<MemoTodoPage> createState() => _MemoTodoPageState();
}

class _MemoTodoPageState extends State<MemoTodoPage> {
  List<Map<String, dynamic>> _todos = [];
  bool _todoLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchTodos();
  }

  Future<void> _fetchTodos() async {
    setState(() => _todoLoading = true);
    try {
      _todos = await BackendApi.fetchTodos(widget.user['id']);
      print('[MemoTodoPage] _fetchTodos 拿到: ${_todos.length} 条, 内容: $_todos');
    } catch (e) {
      _todos = [];
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('获取待办事项失败: $e')));
    }
    print('[MemoTodoPage] 调用 _scheduleNotifications');
    _scheduleNotifications();
    setState(() => _todoLoading = false);
  }

  void _scheduleNotifications() {
    for (final todo in _todos) {
      if (todo['remind_at'] != null) {
        final remindTime = DateTime.parse(todo['remind_at']).toLocal();
        if (kIsWeb && remindTime.isAfter(DateTime.now())) {
          // scheduleWebNotification('待办事项提醒', todo['content'], remindTime);
        } else if (!kIsWeb) {
          final now = DateTime.now();
          final delay = remindTime.difference(now);
          if (delay.inMilliseconds > 0) {
            // 正常到点提醒
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
  }

  void scheduleWebNotification(
    String title,
    String body,
    DateTime scheduledTime,
  ) {
    final now = DateTime.now();
    final delay = scheduledTime.difference(now);
    print(
      '[Web通知] now: ' +
          now.toString() +
          ', scheduledTime: ' +
          scheduledTime.toString() +
          ', delay: ' +
          delay.inSeconds.toString() +
          '秒',
    );
    print(
      '[Web通知] 计划在: ' +
          scheduledTime.toString() +
          ' 弹窗提醒: ' +
          title +
          ' - ' +
          body,
    );
    if (delay.isNegative) {
      print('[Web通知] 已经过期，不再弹窗');
      return;
    }
    Timer(delay, () {
      print('[Web通知] 到点弹窗: ' + title + ' - ' + body);
      // if (html.Notification.supported) {
      //   html.Notification.requestPermission().then((permission) {
      //     print('[Web通知] 用户授权状态: ' + permission);
      //     if (permission == 'granted') {
      //       html.Notification(title, body: body);
      //     }
      //   });
      // }
      // 到点时弹出对话框提醒
      print('[Web通知] 调用 showWebDialog');
      showWebDialog(body);
    });
  }

  void showWebDialog(String content) {
    // 只在Web端弹窗
    if (kIsWeb) {
      BuildContext? dialogContext;
      try {
        dialogContext = context;
      } catch (e) {
        print('[WebDialog] 获取 context 失败: $e');
      }
      showDialog(
        context: dialogContext!,
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

  Future<void> _addTodo(String content, [DateTime? remindAt]) async {
    print(
      '[MemoTodoPage] 添加待办: content=$content, remindAt=$remindAt, userId= ${widget.user['id']}',
    );
    // 新增：校验提醒时间是否已过
    if (remindAt != null && remindAt.isBefore(DateTime.now())) {
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
      return;
    }
    try {
      await BackendApi.addTodo(
        content,
        remindAt: remindAt,
        userId: widget.user['id'],
      );
      await _fetchTodos();
    } catch (e) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('添加失败'),
          content: Text('添加待办事项失败: $e'),
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

  Future<void> _deleteTodo(int id) async {
    try {
      await BackendApi.deleteTodo(id.toString(), widget.user['id']);
      await _fetchTodos();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除待办事项失败: $e')));
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
                    style: subtitleTextStyle,
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
                print(
                  '[MemoTodoPage] 点击添加按钮: input=' +
                      input +
                      ', selectedTime=' +
                      selectedTime.toString(),
                );
                // 校验必须在关闭弹窗前
                if (selectedTime != null &&
                    selectedTime!.isBefore(DateTime.now())) {
                  showDialog(
                    context: context,
                    builder: (ctx2) => AlertDialog(
                      title: const Text('无效时间'),
                      content: const Text('这个时间已经过去了哦，请选择未来的时间'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx2).pop(),
                          child: const Text('知道了'),
                        ),
                      ],
                    ),
                  );
                  return;
                }
                if (input.trim().isNotEmpty) {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('待办事项', style: titleTextStyle),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _showAddTodoDialog,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_todoLoading)
            const Center(child: CircularProgressIndicator())
          else if (_todos.isEmpty)
            const Expanded(
              child: EmptyHintCard(
                title: 'Hello～',
                hintText: '今日暂无日程，快来点击“ + ”添加一个日程吧，我会在适当的时间提醒你',
                titleColor: Color(0xFFB39DDB),
                emojiIcon: Icons.emoji_emotions,
                emojiBgColor: Color(0xFF81D4FA),
                emojiIconColor: Colors.white,
              ),
            )
          else
            Expanded(
              child: ListView(
                children: _todos
                    .map(
                      (todo) => Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          title: Text(
                            todo['content'],
                            style: titleTextStyle.copyWith(fontSize: 16),
                          ),
                          subtitle: todo['remind_at'] != null
                              ? Text(
                                  '提醒时间: ' +
                                      DateFormat('yyyy-MM-dd HH:mm').format(
                                        DateTime.parse(
                                          todo['remind_at'],
                                        ).toLocal(),
                                      ),
                                  style: subtitleTextStyle,
                                )
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteTodo(todo['id']),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
