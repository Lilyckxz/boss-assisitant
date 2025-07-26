import 'package:http/http.dart' as http;
import 'dart:convert';

class BackendApi {
  // static const String baseUrl = 'http://36.137.93.246:8081';
  // 我的本地IP
  static const String baseUrl = 'http://192.168.31.141:8000';

  // 发送语音消息到后端
  static Future<Map<String, dynamic>> sendVoiceMessage(
    String text,
    int userId,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chat'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'message': text, 'user_id': userId}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return {
        'answer': data['answer'],
        if (data['remind_at'] != null) 'remind_at': data['remind_at'],
      };
    } else {
      throw Exception('Failed to get AI response');
    }
  }

  // 获取待办事项列表
  static Future<List<Map<String, dynamic>>> fetchTodos(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/todos?user_id=$userId'),
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to fetch todos');
    }
  }

  // 添加待办事项
  static Future<void> addTodo(
    String content, {
    DateTime? remindAt,
    required int userId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/todos'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'content': content,
        if (remindAt != null) 'remind_at': remindAt.toIso8601String(),
        'user_id': userId,
      }),
    );
    if (response.statusCode != 201) {
      // 新增：后端返回提醒时间已过，友好提示
      if (response.statusCode == 400 && response.body.contains('提醒时间已经过去了')) {
        throw Exception('这个时间已经过去了哦，请选择未来的时间');
      }
      throw Exception('Failed to add todo');
    }
  }

  // 删除待办事项
  static Future<void> deleteTodo(String id, int userId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/todos/$id?user_id=$userId'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete todo');
    }
  }

  // 获取内容订阅列表
  static Future<List<Map<String, dynamic>>> fetchStash({String? type}) async {
    final url = type == null ? '$baseUrl/stash' : '$baseUrl/stash?type=$type';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('Failed to fetch stash content');
    }
  }

  // 删除内容订阅内容
  static Future<void> deleteStash(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/stash/$id'));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete stash content');
    }
  }

  // 新增内容订阅内容
  static Future<void> addStash({
    required String title,
    String? url,
    String type = 'news',
    String? summary,
    String? cover,
    String? content,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/stash'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'title': title,
        if (url != null) 'url': url,
        'type': type,
        if (summary != null) 'summary': summary,
        if (cover != null) 'cover': cover,
        if (content != null) 'content': content,
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to add stash content');
    }
  }

  // 用户注册
  static Future<Map<String, dynamic>> register(
    String username,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'password': password}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(json.decode(response.body)['detail'] ?? '注册失败');
    }
  }

  // 用户登录
  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'password': password}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(json.decode(response.body)['detail'] ?? '登录失败');
    }
  }

  // 用户订阅分类
  static Future<void> subscribeCategory(int userId, String category) async {
    final response = await http.post(
      Uri.parse('$baseUrl/subscribe_category'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'user_id': userId, 'category': category}),
    );
    if (response.statusCode != 200) {
      throw Exception(response.body);
    }
  }

  // 用户取消订阅分类
  static Future<void> unsubscribeCategory(int userId, String category) async {
    final response = await http.post(
      Uri.parse('$baseUrl/unsubscribe_category'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'user_id': userId, 'category': category}),
    );
    if (response.statusCode != 200) {
      throw Exception(response.body);
    }
  }

  // 获取用户已订阅分类
  static Future<List<String>> fetchSubscribedCategories(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/my_categories?user_id=$userId'),
    );
    if (response.statusCode == 200) {
      return List<String>.from(json.decode(response.body));
    } else {
      throw Exception('获取已订阅分类失败');
    }
  }

  // 获取所有用户画像
  static Future<List<Map<String, dynamic>>> fetchUserProfiles(
    int userId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/user_profiles?user_id=$userId'),
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    } else {
      throw Exception('获取用户画像失败');
    }
  }

  // 添加用户画像
  static Future<Map<String, dynamic>> addUserProfile(
    String name,
    String traits,
    int userId,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/user_profile'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': name, 'traits': traits, 'user_id': userId}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('添加用户画像失败');
    }
  }

  // 删除用户画像
  static Future<void> deleteUserProfile(int id, int userId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/user_profile/$id?user_id=$userId'),
    );
    if (response.statusCode != 200) {
      throw Exception('删除用户画像失败');
    }
  }

  // 更新用户画像
  static Future<Map<String, dynamic>> updateUserProfile(
    int id,
    String name,
    String traits,
    int userId,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/user_profile/$id'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': name, 'traits': traits, 'user_id': userId}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('更新用户画像失败');
    }
  }
}
