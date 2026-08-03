/// Web `user-dashboard.js` `_patternStatus` / formasyon sıralama ile hizalı.
const kFormationHorizons = ['1d', '3d', '7d', '14d', '30d'];

const _sourceOrder = <String, int>{
  'ADVANCED_TA': 0,
  'BASIC_TA': 1,
  'BASIC': 1,
  'VISUAL_YOLO': 2,
};

class FormationStatus {
  const FormationStatus({required this.key, required this.prio});

  final String key;
  final int prio;
}

FormationStatus formationStatus(Map<String, dynamic> p) {
  final effect = (p['effect_state']?.toString() ?? '').toLowerCase();
  final rec = (p['recency_bucket']?.toString() ?? '').toUpperCase();
  final ageRaw = p['age_bars'];
  final age = ageRaw is num ? ageRaw.round().clamp(0, 9999) : null;
  final invalid = p['valid'] == false || rec == 'INVALID';
  final playedOut = p['played_out'] == true;

  if (invalid) return const FormationStatus(key: 'bozuldu', prio: 3);
  if (playedOut) return const FormationStatus(key: 'tamamlandı', prio: 1);
  if (effect == 'triggered_active' || effect == 'retest_active') {
    return const FormationStatus(key: 'etkisi sürüyor', prio: 4);
  }
  if (effect == 'armed') {
    return const FormationStatus(key: 'eşikte', prio: 3);
  }
  if (effect == 'forming') {
    return const FormationStatus(key: 'oluşuyor', prio: 2);
  }
  if (rec == 'STALE') return const FormationStatus(key: 'geçmiş', prio: 0);
  if (rec == 'ACTIVE') {
    if (age != null) {
      return FormationStatus(key: 'güncel ($age bar)', prio: 3);
    }
    return const FormationStatus(key: 'güncel', prio: 3);
  }
  if (age != null && age <= 5) {
    return FormationStatus(key: 'güncel ($age bar)', prio: 3);
  }
  return const FormationStatus(key: 'tespit', prio: 1);
}

/// Teknik/görsel formasyonlar — ML/FINGPT hariç; aktif durumlar önde.
List<Map<String, dynamic>> sortFormations(
  List<Map<String, dynamic>> raw, {
  required Set<String> excludeSources,
}) {
  final list = raw
      .where((p) => !excludeSources.contains(p['source']?.toString() ?? ''))
      .toList();

  list.sort((a, b) {
    final sa = formationStatus(a);
    final sb = formationStatus(b);
    final byPrio = sb.prio.compareTo(sa.prio);
    if (byPrio != 0) return byPrio;

    final srcA = a['source']?.toString() ?? '';
    final srcB = b['source']?.toString() ?? '';
    final orderA = _sourceOrder[srcA] ?? 9;
    final orderB = _sourceOrder[srcB] ?? 9;
    final bySrc = orderA.compareTo(orderB);
    if (bySrc != 0) return bySrc;

    final confA = _confidencePct(a['confidence']) ?? 0;
    final confB = _confidencePct(b['confidence']) ?? 0;
    return confB.compareTo(confA);
  });
  return list;
}

int? _confidencePct(dynamic conf) {
  if (conf is! num) return null;
  final v = conf <= 1 ? conf * 100 : conf;
  return v.round().clamp(0, 100);
}

String? pickDefaultHorizon(Map? signalsByHorizon) {
  if (signalsByHorizon == null) return '7d';
  if (signalsByHorizon['7d'] is Map) return '7d';
  for (final h in kFormationHorizons) {
    if (signalsByHorizon[h] is Map) return h;
  }
  return '7d';
}

Map<String, dynamic>? signalRowForHorizon(Map? signalsByHorizon, String horizon) {
  if (signalsByHorizon == null) return null;
  final raw = signalsByHorizon[horizon];
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return null;
}

Map<String, dynamic>? mlUnifiedForHorizon(Map? mlUnified, String horizon) {
  if (mlUnified == null) return null;
  final raw = mlUnified[horizon];
  if (raw is! Map) return null;
  final map = Map<String, dynamic>.from(raw);
  if (map['basic'] == null && map['enhanced'] == null && map['best_model'] == null) {
    // Some payloads nest models only; empty object → hide
    if (map.isEmpty) return null;
  }
  return map;
}

String? pickMlModelKey(Map<String, dynamic> horizonMl) {
  final best = horizonMl['best_model']?.toString() ??
      horizonMl['best']?.toString();
  if (best == 'enhanced' || best == 'basic') return best;
  if (horizonMl['enhanced'] is Map) return 'enhanced';
  if (horizonMl['basic'] is Map) return 'basic';
  return null;
}

String translateModelLabel(String? key) {
  switch (key) {
    case 'enhanced':
      return 'Gelişmiş';
    case 'basic':
      return 'Temel';
    default:
      return key ?? '-';
  }
}
