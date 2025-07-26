import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'backend_api.dart';
import 'stash_detail_page.dart';
import 'main.dart';
import 'styles.dart';

class StashPage extends StatefulWidget {
  const StashPage({super.key, required this.userId});
  final int userId;

  @override
  State<StashPage> createState() => _StashPageState();
}

class _StashPageState extends State<StashPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _stash = [];
  bool _loading = true;
  String? _error;
  String _selectedType = 'health'; // 默认分类
  final List<Map<String, String>> _types = [
    {'label': '养生区', 'value': 'health'},
    {'label': '产业分析报告', 'value': 'industry_report'},
    {'label': '财经分析', 'value': 'finance_analysis'},
  ];
  List<String> _subscribedCategories = [];
  bool _subscribing = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _types.length, vsync: this);
    _fetchSubscribedCategories();
    _tabController.addListener(() {
      setState(() {
        _selectedType = _types[_tabController.index]['value']!;
      });
      _fetchStash();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchSubscribedCategories() async {
    setState(() {
      _loading = true;
    });
    try {
      _subscribedCategories = await BackendApi.fetchSubscribedCategories(
        widget.userId,
      );
      if (_subscribedCategories.isNotEmpty) {
        _selectedType = _subscribedCategories.contains(_selectedType)
            ? _selectedType
            : _subscribedCategories.first;
        await _fetchStash();
      } else {
        _stash = [];
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _fetchStash() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_subscribedCategories.contains(_selectedType)) {
        _stash = await BackendApi.fetchStash(type: _selectedType);
        _stash.sort((a, b) {
          final dateA = DateTime.parse(a['created_at']);
          final dateB = DateTime.parse(b['created_at']);
          return dateB.compareTo(dateA);
        });
      } else {
        _stash = [];
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _toggleSubscribe(String category) async {
    setState(() {
      _subscribing = true;
    });
    try {
      if (_subscribedCategories.contains(category)) {
        await BackendApi.unsubscribeCategory(widget.userId, category);
        _subscribedCategories.remove(category);
        // 退订后停留在当前类别，清空该类别文章
        if (_selectedType == category) {
          _stash = [];
        }
      } else {
        await BackendApi.subscribeCategory(widget.userId, category);
        _subscribedCategories.add(category);
        _selectedType = category;
        await _fetchStash();
      }
    } catch (e) {
      // 检查是否是没有权限
      final errStr = e.toString();
      if (errStr.contains('403') || errStr.contains('没有此权限')) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('提示'),
            content: const Text('抱歉，您未订阅此模块'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    } finally {
      setState(() {
        _subscribing = false;
      });
    }
  }

  bool _isNewArticle(Map<String, dynamic> article) {
    if (_stash.isNotEmpty) {
      final latestDate = DateTime.parse(_stash.first['created_at']);
      final articleDate = DateTime.parse(article['created_at']);
      return articleDate.isAtSameMomentAs(latestDate);
    }
    return false;
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
            title: const Text('内容订阅'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(90),
              child: Container(
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
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: Colors.white,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white.withOpacity(0.7),
                        labelPadding: EdgeInsets.zero,
                        indicatorPadding: EdgeInsets.zero,
                        isScrollable: false,
                        indicatorWeight: 3,
                        indicatorSize: TabBarIndicatorSize.tab,
                        tabs: _types.map((type) {
                          final value = type['value']!;
                          final isSubscribed = _subscribedCategories.contains(
                            value,
                          );
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  type['label']!,
                                  style: const TextStyle(fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                _subscribing && value == _selectedType
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : OutlinedButton(
                                        onPressed: () =>
                                            _toggleSubscribe(value),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                            color: isSubscribed
                                                ? Colors.red
                                                : Colors.green,
                                            width: 1.5,
                                          ),
                                          foregroundColor: isSubscribed
                                              ? Colors.red
                                              : Colors.green,
                                          backgroundColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          minimumSize: const Size(56, 28),
                                        ),
                                        child: Text(
                                          isSubscribed ? '退订' : '订阅',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isSubscribed
                                                ? Colors.red
                                                : Colors.green,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text('加载失败: $_error'))
              : _subscribedCategories.isEmpty
              ? const Center(child: Text('请先订阅一个分类'))
              : !_subscribedCategories.contains(_selectedType)
              ? const Center(child: Text('期待您的订阅'))
              : _stash.isEmpty
              ? const Center(child: Text('期待您的订阅'))
              : Container(
                  color: Colors.white, // 文章列表背景颜色设置为白色
                  child: ListView.separated(
                    itemCount: _stash.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 18),
                    itemBuilder: (context, index) {
                      final item = _stash[index];
                      final isNew = _isNewArticle(item);
                      final createdDate = DateTime.parse(item['created_at']);
                      final formattedDate =
                          '${createdDate.year}-${createdDate.month}-${createdDate.day}';
                      return Padding(
                        padding: EdgeInsets.only(top: index == 0 ? 20.0 : 0.0),
                        child: GestureDetector(
                          onTap: () {
                            if ((item['url'] == null ||
                                    item['url'].toString().isEmpty) &&
                                (item['content'] != null &&
                                    item['content'].toString().isNotEmpty)) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StashDetailPage(item: item),
                                ),
                              );
                            } else if (item['url'] != null &&
                                item['url'].toString().isNotEmpty) {
                              final url = item['url'];
                              final uri = Uri.tryParse(url);
                              if (uri != null) {
                                launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            }
                          },
                          child: Card(
                            color: Colors.white,
                            elevation: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (item['cover'] != null)
                                    Container(
                                      width: 60,
                                      height: 60,
                                      margin: const EdgeInsets.only(right: 12),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          item['cover'],
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            if (isNew)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                  right: 6,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: Colors.orange,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: const Text(
                                                  '最新',
                                                  style: TextStyle(
                                                    color: Colors.orange,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            Expanded(
                                              child: Text(
                                                item['title'] ?? '',
                                                style: titleTextStyle.copyWith(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        if (item['summary'] != null)
                                          Text(
                                            item['summary'],
                                            style: subtitleTextStyle.copyWith(
                                              fontSize: 13,
                                              color: Colors.grey[700],
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        const SizedBox(height: 6),
                                        Text(
                                          formattedDate,
                                          style: subtitleTextStyle.copyWith(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.open_in_new,
                                          size: 20,
                                        ),
                                        tooltip: '打开',
                                        onPressed: () async {
                                          final url = item['url'];
                                          if (url != null) {
                                            final uri = Uri.tryParse(url);
                                            if (uri != null &&
                                                await canLaunchUrl(uri)) {
                                              await launchUrl(
                                                uri,
                                                mode: LaunchMode
                                                    .externalApplication,
                                              );
                                            } else {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text('无法打开链接: $url'),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          size: 20,
                                          color: Colors.red,
                                        ),
                                        tooltip: '删除',
                                        onPressed: () async {
                                          final confirm =
                                              await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text('确认删除'),
                                                  content: Text(
                                                    '确定要删除“${item['title']}”？',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            ctx,
                                                            false,
                                                          ),
                                                      child: const Text('取消'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            ctx,
                                                            true,
                                                          ),
                                                      child: const Text('删除'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                          if (confirm == true) {
                                            try {
                                              await BackendApi.deleteStash(
                                                item['id'],
                                              );
                                              setState(() {
                                                _stash.removeAt(index);
                                              });
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text('删除成功'),
                                                ),
                                              );
                                            } catch (e) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text('删除失败: $e'),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
