import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/unread_count_badge.dart';
import '../pro/soft_gate_sheet.dart';

/// Which notification preference controls to show (web Hesabım parity).
enum NotificationPrefsLayout {
  /// Meraklı / Free — CTA only
  freeCta,

  /// Yatırımcı / Pro — email switch + locked push
  proEmailPushLocked,

  /// Profesyonel / Premium — email + push
  premiumBoth,
}

NotificationPrefsLayout notificationPrefsLayout({
  required bool isPro,
  required bool isPremium,
}) {
  if (!isPro) return NotificationPrefsLayout.freeCta;
  if (!isPremium) return NotificationPrefsLayout.proEmailPushLocked;
  return NotificationPrefsLayout.premiumBoth;
}

SoftGateKind emailEnableGateKind() => SoftGateKind.pro;

SoftGateKind pushEnableGateKind() => SoftGateKind.premium;

const _hintStyle = TextStyle(
  color: LotlotColors.textSecondary,
  fontSize: 12,
  height: 1.35,
);

const _subStyle = TextStyle(
  color: LotlotColors.textSecondary,
  fontSize: 12,
);

/// Hesap → Bildirim tercihleri (tier-aware). Inbox tile always shown.
class NotificationPrefsSection extends StatelessWidget {
  const NotificationPrefsSection({
    super.key,
    required this.layout,
    required this.emailOn,
    required this.pushOn,
    required this.unread,
    required this.prefsReady,
    required this.patchingEmail,
    required this.patchingPush,
    this.statusMessage,
    required this.onEmailChanged,
    required this.onPushChanged,
    required this.onOpenPlans,
    required this.onPremiumGate,
    required this.onOpenInbox,
  });

  final NotificationPrefsLayout layout;
  final bool emailOn;
  final bool pushOn;
  final int unread;
  final bool prefsReady;
  final bool patchingEmail;
  final bool patchingPush;
  final String? statusMessage;
  final ValueChanged<bool> onEmailChanged;
  final ValueChanged<bool> onPushChanged;
  final VoidCallback onOpenPlans;
  final VoidCallback onPremiumGate;
  final VoidCallback onOpenInbox;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._prefControls(),
        const Divider(height: 16, color: LotlotColors.border),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: UnreadCountBadge(
            count: unread,
            child: const Icon(Icons.notifications_outlined),
          ),
          title: const Text('Gelen bildirimler'),
          subtitle: Text(
            unread > 0
                ? '$unread okunmamış · Push geçmişi'
                : 'Push geçmişi — okundu / sil',
            style: _subStyle,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onOpenInbox,
        ),
      ],
    );
  }

  List<Widget> _prefControls() {
    switch (layout) {
      case NotificationPrefsLayout.freeCta:
        return [
          const Text(
            'Grafik alarm e-postası Pro planında. Anlık push ve sinyal bildirimleri Premium planında açılır.',
            style: _hintStyle,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onOpenPlans,
            child: const Text('Planları incele'),
          ),
        ];
      case NotificationPrefsLayout.proEmailPushLocked:
        return [
          const Text(
            'Pro planında grafik alarmları e-posta ile gelir. Anlık push Premium’dadır.',
            style: _hintStyle,
          ),
          ..._statusLines(),
          const SizedBox(height: 8),
          _emailSwitch(),
          if (patchingEmail) _patchBar(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Push / anlık bildirimler'),
            subtitle: const Text('Premium gerekir', style: _subStyle),
            trailing: TextButton(
              onPressed: onPremiumGate,
              child: const Text('Premium'),
            ),
            onTap: onPremiumGate,
          ),
        ];
      case NotificationPrefsLayout.premiumBoth:
        return [
          const Text(
            'Premium’da cihaz bildirimleri açılabilir. Sistem izni gerekir.',
            style: _hintStyle,
          ),
          ..._statusLines(),
          const SizedBox(height: 8),
          _emailSwitch(),
          if (patchingEmail) _patchBar(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Push bildirimleri'),
            value: pushOn,
            onChanged: (!prefsReady || patchingPush) ? null : onPushChanged,
            activeThumbColor: LotlotColors.onAccent,
            activeTrackColor: LotlotColors.accent,
          ),
          if (patchingPush) _patchBar(),
        ];
    }
  }

  List<Widget> _statusLines() {
    if (statusMessage == null) return const [];
    return [
      const SizedBox(height: 6),
      Text(
        statusMessage!,
        style: const TextStyle(color: LotlotColors.warning, fontSize: 12),
      ),
    ];
  }

  Widget _emailSwitch() {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('E-posta bildirimleri'),
      subtitle: const Text('Grafik alarmları', style: _subStyle),
      value: emailOn,
      onChanged: (!prefsReady || patchingEmail) ? null : onEmailChanged,
      activeThumbColor: LotlotColors.onAccent,
      activeTrackColor: LotlotColors.accent,
    );
  }

  Widget _patchBar() {
    return const LinearProgressIndicator(
      color: LotlotColors.accent,
      minHeight: 2,
    );
  }
}
