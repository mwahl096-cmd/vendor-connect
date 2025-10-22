import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../models/article.dart';
import '../services/firestore_service.dart';
import 'article_detail_screen.dart';

class ArticlesListScreen extends StatelessWidget {
  const ArticlesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Article>>(
      stream: FirestoreService().watchArticles(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final articles = snap.data ?? [];
        if (articles.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Vendor Articles')),
            body: const Center(child: Text('No articles yet')),
          );
        }

        // Build category tabs from existing articles
        final allCategories = <String>{};
        for (final a in articles) {
          allCategories.addAll(a.categories);
        }
        final categories = ['All', ...allCategories.toList()..sort()];

        return DefaultTabController(
          length: categories.length,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Vendor Articles'),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
                    indicator: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    indicatorPadding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                    tabs: [for (final c in categories) Tab(text: c)],
                  ),
                ),
              ),
            ),
            body: TabBarView(
              children: [
                for (final c in categories)
                  _ArticlesGrid(
                    articles: c == 'All'
                        ? articles
                        : articles.where((a) => a.categories.contains(c)).toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ArticlesGrid extends StatelessWidget {
  final List<Article> articles;
  const _ArticlesGrid({required this.articles});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final padding = width >= 600 ? 20.0 : 12.0;
        final crossAxisCount = width < 340 ? 1 : 2;
        const spacing = 12.0;
        final itemWidth =
            (width - (crossAxisCount - 1) * spacing - padding * 2) / crossAxisCount;
        final imageHeight = itemWidth * 9 / 16;
        const metaHeight = 180.0; // title, excerpt, footer spacing
        final itemHeight = imageHeight + metaHeight;
        final aspectRatio = itemWidth / itemHeight;

        return Padding(
          padding: EdgeInsets.all(padding),
          child: GridView.builder(
            itemCount: articles.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              childAspectRatio: aspectRatio,
            ),
            itemBuilder: (context, index) {
              return _ArticleCard(article: articles[index]);
            },
          ),
        );
      },
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final Article article;
  const _ArticleCard({required this.article});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedDate =
        article.publishedAt.toLocal().toString().split('.').first.replaceFirst(' ', ' · ');

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ArticleDetailScreen(articleId: article.id)),
      ),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (article.featuredImageUrl != null &&
                      article.featuredImageUrl!.isNotEmpty)
                    Image.network(
                      article.featuredImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.image, size: 36),
                      ),
                    )
                  else
                    Container(
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.image, size: 36),
                    ),
                  if (article.categories.isNotEmpty)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          article.categories.first,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article.excerpt,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey.shade700),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            formattedDate,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: Colors.grey.shade700),
                          ),
                        ),
                        if (article.allowComments)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.chat_bubble_outline,
                                size: 16, color: Colors.grey),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
