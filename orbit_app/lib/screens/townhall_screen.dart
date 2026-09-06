import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/empty_state.dart';
import 'chat_view.dart';

class TownhallScreen extends StatelessWidget {
  const TownhallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final loc = app.myLocation;
    final inNcr = loc != null && Config.withinNCR(loc.latitude, loc.longitude);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Town Hall'),
            Text(
              'NCR · everyone nearby',
              style: TextStyle(fontSize: 12, color: OrbitColors.inkSoft),
            ),
          ],
        ),
      ),
      body: inNcr
          ? ChatView(
              connect: () =>
                  app.chat.connectTownhall(loc.latitude, loc.longitude),
              actionMessage: (_, _) =>
                  'The town hall is only available inside the NCR.',
            )
          : EmptyState(
              icon: Icons.location_off_rounded,
              title: 'Town Hall is NCR-only',
              subtitle:
                  'We could not confirm you are inside the NCR. Refresh your '
                  'location from the map to join the local chat.',
            ),
    );
  }
}
