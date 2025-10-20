import 'package:flutter/material.dart';

class InfoPage extends StatelessWidget {
  final String title;
  final List<String> paragraphs;

  const InfoPage({super.key, required this.title, required this.paragraphs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: paragraphs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => Text(
          paragraphs[index],
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

