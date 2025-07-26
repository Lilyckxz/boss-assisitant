import 'package:flutter/material.dart';
import 'backend_api.dart';
import 'memo_todo_page.dart';
import 'styles.dart';

class UserProfilePage extends StatefulWidget {
  final int userId;
  const UserProfilePage({super.key, required this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  List<Map<String, dynamic>> _contacts = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _contacts = await BackendApi.fetchUserProfiles(widget.userId);
    } catch (e) {
      _error = e.toString();
      _contacts = [];
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _addContact() async {
    String name = '';
    String traits = '';
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加人脉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              onChanged: (v) => name = v,
              decoration: const InputDecoration(labelText: '姓名'),
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => traits = v,
              decoration: const InputDecoration(labelText: '特点/喜好'),
              maxLines: 3,
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
              if (name.trim().isNotEmpty) {
                Navigator.pop(ctx, {
                  'name': name.trim(),
                  'traits': traits.trim(),
                });
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await BackendApi.addUserProfile(
          result['name']!,
          result['traits']!,
          widget.userId,
        );
        await _fetchContacts();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('添加成功')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('添加失败: $e')));
      }
    }
  }

  Future<void> _editContact(Map<String, dynamic> contact) async {
    String name = contact['name'] ?? '';
    String traits = contact['traits'] ?? '';
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑人脉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              onChanged: (v) => name = v,
              decoration: const InputDecoration(labelText: '姓名'),
              controller: TextEditingController(text: name),
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => traits = v,
              decoration: const InputDecoration(labelText: '特点/喜好'),
              maxLines: 3,
              controller: TextEditingController(text: traits),
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
              if (name.trim().isNotEmpty) {
                Navigator.pop(ctx, {
                  'name': name.trim(),
                  'traits': traits.trim(),
                });
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await BackendApi.updateUserProfile(
          contact['id'],
          result['name']!,
          result['traits']!,
          widget.userId,
        );
        await _fetchContacts();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('更新成功')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('更新失败: $e')));
      }
    }
  }

  Future<void> _deleteContact(Map<String, dynamic> contact) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除"${contact['name']}"？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await BackendApi.deleteUserProfile(contact['id'], widget.userId);
        await _fetchContacts();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('删除成功')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
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
              Text('人脉管理', style: titleTextStyle),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _addContact,
                tooltip: '添加人脉',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Center(child: Text('加载失败: $_error'))
          else if (_contacts.isEmpty)
            Expanded(
              child: EmptyHintCard(
                title: 'Hello～',
                hintText: '暂无人脉信息，点击右上角“ + ”添加你的人脉吧，方便随时管理和查找',
                titleColor: Color(0xFFB39DDB),
                emojiIcon: Icons.emoji_people,
                emojiBgColor: Color(0xFFFFB74D),
                emojiIconColor: Colors.white,
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: _contacts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final contact = _contacts[index];
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      title: Text(
                        contact['name'] ?? '',
                        style: titleTextStyle.copyWith(fontSize: 16),
                      ),
                      subtitle:
                          (contact['traits'] != null &&
                              contact['traits'].toString().isNotEmpty)
                          ? Text(contact['traits'], style: subtitleTextStyle)
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: '编辑',
                            onPressed: () => _editContact(contact),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: '删除',
                            onPressed: () => _deleteContact(contact),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
