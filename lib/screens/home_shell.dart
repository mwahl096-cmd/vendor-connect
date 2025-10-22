import 'package:badges/badges.dart' as badges;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import 'articles_list_screen.dart';
import 'search_screen.dart';
import 'profile_screen.dart';
import 'auth_screen.dart';
import 'info_page.dart';

class HomeShell extends StatefulWidget {
  static const route = '/home';
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _pageTitles = const ['Articles', 'Search', 'Profile'];
  final _pages = const [ArticlesListScreen(), SearchScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      key: _scaffoldKey,
      drawer: _AppDrawer(
        onNavigateToProfile: () {
          setState(() => _index = 2);
          Navigator.of(context).pop();
        },
      ),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text(
          _pageTitles[_index],
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF2BBFD4),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white70,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
            showUnselectedLabels: true,
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            items: [
              BottomNavigationBarItem(
                icon: uid == null
                    ? const Icon(Icons.article)
                    : StreamBuilder<int>(
                        stream: FirestoreService().watchUnreadCount(uid),
                        builder: (context, snap) {
                          final count = snap.data ?? 0;
                          // Update app badge in background
                          context.read<NotificationService>().setBadgeCount(count);
                          final icon = const Icon(Icons.article);
                          if (count <= 0) return icon;
                          return badges.Badge(
                            position: badges.BadgePosition.topEnd(top: -12, end: -12),
                            badgeContent: Text(
                              count > 99 ? '99+' : '$count',
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                            ),
                            child: icon,
                          );
                        },
                      ),
                label: 'Articles',
              ),
              const BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
              const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  final VoidCallback onNavigateToProfile;
  const _AppDrawer({required this.onNavigateToProfile});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (uid != null)
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection(AppConfig.usersCollection)
                    .doc(uid)
                    .snapshots(),
                builder: (context, snap) {
                  final data = snap.data?.data();
                  final name = data?['name'] ?? FirebaseAuth.instance.currentUser?.email ?? 'Vendor';
                  final email = data?['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '';
                  return UserAccountsDrawerHeader(
                    accountName: Text(name),
                    accountEmail: Text(email),
                    currentAccountPicture: CircleAvatar(
                      child: Text(name.toString().substring(0, 1).toUpperCase()),
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2BBFD4), Color(0xFF6EA7E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  );
                },
              )
            else
              const DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2BBFD4), Color(0xFF6EA7E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Vendor Connect',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              onTap: onNavigateToProfile,
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About Us'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const InfoPage(
                    title: 'About Us',
                    paragraphs: [
                      'Vendor Connect helps market administrators keep vendors aligned with important updates and announcements.',
                      'We combine real-time notifications, searchable articles, and easy communication tools to keep your vendor community in sync.'
                    ],
                  ),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.design_services_outlined),
              title: const Text('Services'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const InfoPage(
                    title: 'Services',
                    paragraphs: [
                      '• Publish updates for your vendor community.',
                      '• Enable comments and gather feedback instantly.',
                      '• Track vendor activity, approvals, and communication in one place.'
                    ],
                  ),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Privacy Policy'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const InfoPage(
                    title: 'Privacy Policy',
                    paragraphs: [
                      'We respect your privacy. Vendor information is only used inside Vendor Connect to deliver platform services.',
                      'No personal data is sold or shared with third parties without consent.'
                    ],
                  ),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('Terms & Services'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const InfoPage(
                    title: 'Terms & Services',
                    paragraphs: [
                      'Use of Vendor Connect is subject to the community guidelines set by your market administrator.',
                      'We reserve the right to update or modify platform features to improve your experience.'
                    ],
                  ),
                ));
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () async {
                await context.read<AuthService>().signOut();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(AuthScreen.route, (route) => false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
