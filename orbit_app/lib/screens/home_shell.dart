import 'package:flutter/material.dart';

import '../theme.dart';
import 'chats_screen.dart';
import 'map_dashboard.dart';
import 'post_hangout_screen.dart';
import 'profile_screen.dart';
import 'requests_screen.dart';
import 'townhall_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _mapKey = GlobalKey<MapDashboardState>();
  final _requestsKey = GlobalKey<RequestsScreenState>();
  final _chatsKey = GlobalKey<ChatsScreenState>();

  late final List<Widget> _pages = [
    MapDashboard(key: _mapKey),
    const TownhallScreen(),
    RequestsScreen(key: _requestsKey),
    ChatsScreen(key: _chatsKey),
    const ProfileScreen(),
  ];

  Future<void> _openPost() async {
    final posted = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const PostHangoutScreen()));
    if (posted == true) {
      _mapKey.currentState?.reload();
      _requestsKey.currentState?.reload();
      _chatsKey.currentState?.reload();
      if (mounted) setState(() => _index = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              onPressed: _openPost,
              backgroundColor: OrbitColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_location_alt_rounded),
              label: const Text(
                'Post',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          if (i == 0) _mapKey.currentState?.reload();
          if (i == 2) _requestsKey.currentState?.reload();
          if (i == 3) _chatsKey.currentState?.reload();
          setState(() => _index = i);
        },
        backgroundColor: OrbitColors.surface,
        indicatorColor: OrbitColors.primary.withValues(alpha: 0.14),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded, color: OrbitColors.primary),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum_rounded, color: OrbitColors.primary),
            label: 'Town Hall',
          ),
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox_rounded, color: OrbitColors.primary),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(
              Icons.chat_bubble_rounded,
              color: OrbitColors.primary,
            ),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(
              Icons.person_rounded,
              color: OrbitColors.primary,
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
