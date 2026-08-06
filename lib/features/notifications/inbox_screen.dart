import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/deep_link_router.dart';
import '../../core/push/app_badge.dart';
import '../../core/theme/app_theme.dart';
import '../auth/session_controller.dart';
import '../pro/soft_gate_sheet.dart';
import 'inbox_controller.dart';

/// Gelen bildirimler — §25.4 (ikon: notifications; alarm kur ayrı).
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = context.read<SessionController>();
      if (!session.isPremium || !session.pushNotificationsOn) {
        return;
      }
      context.read<InboxController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final inbox = context.watch<InboxController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gelen bildirimler'),
        actions: [
          if (session.isPremium && session.pushNotificationsOn) ...[
            IconButton(
              tooltip: 'Tümünü okundu',
              onPressed: inbox.items.isEmpty
                  ? null
                  : () => inbox.markReadAll(),
              icon: const Icon(Icons.done_all),
            ),
            IconButton(
              tooltip: 'Tümünü sil',
              onPressed: inbox.items.isEmpty
                  ? null
                  : () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: LotlotColors.surface,
                          title: const Text('Tüm bildirimleri sil?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Vazgeç'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Sil'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) await inbox.clearAll();
                    },
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          ],
        ],
      ),
      body: _body(session, inbox),
    );
  }

  Widget _body(SessionController session, InboxController inbox) {
    if (!session.isPremium) {
      return _GateMessage(
        text: 'Gelen bildirimler Premium planda açılır.',
        actionLabel: 'Planları gör',
        onAction: () => showSoftGateSheet(context, kind: SoftGateKind.premium),
      );
    }
    if (!session.pushNotificationsOn) {
      return const _GateMessage(
        text:
            'Push bildirimleri kapalı. Hesap → Bildirim tercihlerinden açın.',
      );
    }
    if (inbox.loading && inbox.items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: LotlotColors.accent),
      );
    }
    if (inbox.error != null && inbox.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                inbox.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: LotlotColors.textSecondary),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => inbox.load(),
                child: const Text('Yeniden dene'),
              ),
            ],
          ),
        ),
      );
    }
    if (inbox.items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Henüz bildirim yok.\nSinyal ve grafik uyarıları burada listelenir.',
            textAlign: TextAlign.center,
            style: TextStyle(color: LotlotColors.textSecondary, height: 1.4),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: LotlotColors.accent,
      onRefresh: () => inbox.load(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: inbox.items.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: LotlotColors.border),
        itemBuilder: (ctx, i) {
          final item = inbox.items[i];
          return Dismissible(
            key: ValueKey(item.id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: LotlotColors.danger.withValues(alpha: 0.25),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete_outline, color: LotlotColors.danger),
            ),
            onDismissed: (_) => inbox.deleteItem(item.id),
            child: ListTile(
              leading: Icon(
                Icons.notifications_outlined,
                color: item.isUnread
                    ? LotlotColors.accent
                    : LotlotColors.textSecondary,
              ),
              title: Text(
                item.titleTr?.isNotEmpty == true
                    ? item.titleTr!
                    : (item.symbol ?? 'Bildirim'),
                style: TextStyle(
                  fontWeight:
                      item.isUnread ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.bodyTr != null && item.bodyTr!.isNotEmpty)
                    Text(
                      item.bodyTr!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: LotlotColors.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  if (item.createdAt != null)
                    Text(
                      item.createdAt!,
                      style: const TextStyle(
                        color: LotlotColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
              trailing: item.isUnread
                  ? const Icon(Icons.circle, size: 10, color: LotlotColors.accent)
                  : null,
              onTap: () async {
                await AppBadge.clear();
                if (item.isUnread) {
                  await inbox.markRead(item.id);
                }
                final deep = item.deepLink;
                if (deep != null && deep.isNotEmpty) {
                  openDeepLink(deep);
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class _GateMessage extends StatelessWidget {
  const _GateMessage({
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_outlined, size: 40),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: LotlotColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
