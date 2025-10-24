class AppConfig {
  // Configure your WordPress site base URL
  static const String wordpressBaseUrl = 'https://YOUR-WORDPRESS-SITE.com';

  // WordPress REST endpoints
  static const String wpPostsEndpoint = '/wp-json/wp/v2/posts';
  static const String wpCategoriesEndpoint = '/wp-json/wp/v2/categories';

  // Firestore collection names
  static const String usersCollection = 'users';
  static const String articlesCollection = 'articles';
  static const String commentsSubcollection = 'comments';
  static const String readsCollection = 'reads';

  // Notification topic for new articles
  static const String articlesTopic = 'articles';

  /// Temporary escape hatch: skip APNs/FCM registration on iOS builds.
  /// Set to `false` once push notifications are configured for production.
  static const bool disableIosPush = true;
}
