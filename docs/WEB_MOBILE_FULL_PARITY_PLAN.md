# Full web ↔ mobil parity planı

> Ürün: LOTLOT.NET Flutter (`bistmobile`) vs web dashboard (`lotlot.net` / `/opt/bist-pattern`).
> Tarih: 2026-08-03 · Yol haritası güncellemesi handbook §0 / §7.3’e işlenecek.
> Local agent: `.cursor/rules` + `.cursor/skills` (gitignore; GitHub’da yok).

---

## 0. Web’i nasıl biliyoruz / kimlik

- **Kaynak:** Canlı template/JS SSH salt okuma (`user_dashboard.html`, `user-dashboard.js`, `dashboard/renderer.js`) + `docs/MOBILE_API_INTEGRATION_GUIDE.md` (salt okuma).
- **MCP:** Şu an bağlı sunucu yok. Görsel teyit için gerekirse tarayıcı oturumu **sen açarsın**; şifre sohbete / repoya yazılmaz.
- **Kurallar:** `test-and-review` döngüsü — web incele → geliştir → test/parity → analyze/sonar → commit/tag.
- **Skills:** `project-manager`, `test-engineer`, `ux-expert`, platform FS, `cybersecurity-expert` ilgili dilimde.
- **Authorship:** Ersin ARIKAN; Cursor co-author yok.

### Web referans yüzeyleri (özet)

| Yüzey | Web davranışı |
|-------|----------------|
| İzleme kartı | Fiyat, AL/SAT pill, `delta_pct`, Genel Sinyal Gücü bar, ufuk filtresi, `display_state` notu |
| Detay modal | Sol: spark → büyük grafik CTA, hacim segmenti, volatilite, adil değer · Sağ: formasyonlar, ML özeti, fundamentals |
| Fullscreen chart | Hacim, EMA20/50, BB, RSI, S/R, Öngörü, Formasyon shading, bar sayısı |
| Keşif | Dashboard filtre + index screener / skor |

---

## 1. Bilinçli dışı (tüm plan)

- Fib / Gann / Elliott drawing suite (web drawing tools)
- Garanti / WebView checkout
- Admin / automation API UI
- Guide dosyasına mobil “sahiplenerek” edit

---

## 2. Dilimler ve sıra

```text
A İzleme kartı
 → B Detay hacim/volatilite
 → C1 Grafik hacim + bar seçici
 → D Keşfet/screener shell
 → C2–C3 EMA50/BB/öngörü + Pro formasyon shading
 → Handbook + git ritüeli
```

### Dilim A — İzleme kartı (web card parity)

**Hedef:** `_WatchlistTile` web kartına yaklaşır.

- `symbol` / `name`
- Seçili ufuk: `label` + **Δ%** (`delta_pct`)
- Mini **Genel Sinyal Gücü** (`genel_confidence_pct` + `confidence_bar_type`)
- `current_price`; alert / remove
- Free muted AL/SAT: yalnızca API `display_state` (client skor yok)

**Dosyalar:** `lib/features/watchlist/watchlist_screen.dart`, controller helpers, isteğe `widgets/watchlist_signal_tile.dart`

**Acceptance:** Aynı ufukta web ile yön/Δ%/güç tutarlı; prediction yoksa sade satır.

**Skills:** ux-expert, test-engineer

---

### Dilim B — Hisse detay meta (hacim + volatilite)

**Web:** `detailVolumeTier`, `detailAvgVolume`, `detailVolatilityRegime`

**Mobil:** Chart altında kompakt kart.

- Önce API alan doğrulama: `GET /api/stocks/<sym>/volume-tier`, pattern-analysis `volatility_regime`, avg volume
- Yoksa gizle (valuation pattern)

**Dosyalar:** `stock_detail_screen.dart`, controller, yeni widget örn. `market_meta_card.dart`, `api_client.dart`

**Acceptance:** Auth/public veri varsa görünür; empty gizli; guest Bearer yok.

---

### Dilim C — Grafik katmanı

Mevcut: `simple_candle_chart.dart` (120 bar, MA20, S/R, OHLC touch).

| Alt dilim | İçerik |
|-----------|--------|
| **C1** | Hacim paneli (parsed `volume`); bar sayısı chip (60/120/200/…) |
| **C2** | EMA50; opsiyonel Bollinger; isteğe RSI mini pane |
| **C3** | Öngörü polyline (auth chart `forecasts` — Free’de sunucu boşaltır); Pro formasyon range shading |

**UX:** Web’deki checkbox ormanı yerine chip / “Sade | Detaylı” segment.

**Acceptance:** C1–C2 cihazda akıcı; öngörü yoksa gizli; shading Pro soft gate; drawing suite dışı.

**Skills:** ios/android-fullstack, ux-expert, risk-integrity

---

### Dilim D — Keşfet / screener

**Durum (v32):** `MainShell` IndexedStack — İzleme | Keşfet; `BrowseScreen` orphan değil.

**Hedef IA:** MainShell’de İzleme + Keşfet (veya eşdeğer AppBar giriş).

- BIST 30/100 + `lotlot_scores` + FV etiketi + `last_close` (`index-screener` / mevcut browse)
- `StocksSearchScreen` katalog ile rol ayrımı (katalog arama vs skorlu tarama)
- Satır → StockDetail

**Acceptance:** Guest public screener; orphan kalkar veya tek giriş.

**Skills:** project-manager, ux-expert, test-engineer

---

### Dilim E — Handbook + kalite + git

- §7.3 parity satırları güncelle; F3 “dışı” listesini daralt
- Her dilim: `flutter analyze` → `sonar-scanner` → commit → tag `v29+` → push (onay)
- Fiziksel cihaz release smoke

---

## 3. Riskler

- Grafik frame drop → C’de profil / lazy pane
- Soft gate / Free prune bozulmamalı
- Entitlement / sinyal client’ta uydurulmaz
- Şifre chat’e konmaz; `.cursor/` GitHub’a dönmez

---

## 4. Başarı tanımı

Login sonrası kullanıcı web okuma akışını tanır: izlemede sinyal+Δ%+güç, detayda hacim/volatilite, grafikte hacim+temel indikatör+öngörü, keşifte skorlu BIST tarama — drawing suite olmadan.
