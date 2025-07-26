import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_html/flutter_html.dart';
import 'styles.dart';
import 'package:intl/intl.dart';

class StashDetailPage extends StatelessWidget {
  final Map<String, dynamic> item;
  const StashDetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final isVideo =
        item['type'] == 'video' &&
        (item['content']?.contains('<iframe') ?? false);
    final createdDate = DateTime.parse(item['created_at']).toLocal();
    final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(createdDate);
    return Scaffold(
      appBar: AppBar(
        title: Text(item['title'] ?? '详情'),
        backgroundColor: accentBlue,
      ),
      body: isVideo
          ? SingleChildScrollView(child: Html(data: item['content'] ?? ''))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    item['title'] ?? '',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  item['content'] != null &&
                          item['content'].toString().trim().isNotEmpty
                      ? MarkdownBody(
                          data: item['content'],
                          styleSheet: MarkdownStyleSheet(
                            h1: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              height: 2,
                            ),
                            h2: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              height: 1.8,
                            ),
                            h3: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              height: 1.6,
                            ),
                            p: const TextStyle(fontSize: 16, height: 1.7),
                            listBullet: const TextStyle(fontSize: 16),
                            blockquote: TextStyle(
                              color: Colors.grey[700],
                              fontStyle: FontStyle.italic,
                            ),
                            code: const TextStyle(
                              fontFamily: 'monospace',
                              backgroundColor: Color(0xFFF5F5F5),
                            ),
                            img: const TextStyle(),
                            unorderedListAlign: WrapAlignment.start,
                            orderedListAlign: WrapAlignment.start,
                            listIndent: 24,
                          ),
                          imageBuilder: (uri, title, alt) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(uri.toString()),
                            ),
                          ),
                        )
                      : const Text('无正文'),
                  const SizedBox(height: 16),
                  if (item['created_at'] != null)
                    Text(
                      '发布时间: $formattedDate',
                      style: subtitleTextStyle.copyWith(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
    );
  }
}
