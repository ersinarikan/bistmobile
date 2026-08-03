# LOTLOT.NET Mobile — Agent Kılavuzu

> Bu dosya agent’ın çalışma kılavuzudur. **Her anlamlı değişiklikten sonra güncellenir.**
> Son güncelleme: 2026-08-03 (v28 web↔mobil analiz parity)

---

## 0. Mobil ürün yol haritası

### 0.1 Kararlar (kilitli)

| Konu | Karar |
|------|--------|
| Yol haritası yazım yeri | **Yalnızca bu handbook (§0)** |
| API sözleşmesi | [`docs/MOBILE_API_INTEGRATION_GUIDE.md`](MOBILE_API_INTEGRATION_GUIDE.md) + web [ersinarikan/BIST](https://github.com/ersinarikan/BIST) — **salt okuma**. Web ekibi günceller; mobil ekip guide’ı fork’lamaz / §0 oraya yazmaz. |
| Ürün sırası | **Önce uygulamayı tam geliştir** (auth + **guest keşif** → watchlist → hisse → hesap → Pro yüzey/push). **IAP / paywall en sonda** (F6). |
| Monetization kanalı | Yalnızca **StoreKit / Play Billing**. Garanti / WebView checkout **asla** (App Store 3.1.1). |
| İstemci rolü | Thin client: tier, kota, sinyal, ML kararlarını **yeniden hesaplama**; API’yi render et. |
| Guest browse | **Evet.** Kayıt/login zorunlu olmadan public keşif (arama, BIST özet, hisse teaser). Watchlist / Pro özellikler auth ister. |

**Neden IAP sonda:** Auth + watchlist + hisse deneyimi doğrulanmadan paywall scope ve Review riskini büyütür. IAP API CANLI olsa da ürün değeri önce kanıtlanır.

### 0.2 API guide nasıl kullanılır

1. Faz işine başlamadan ilgili **§ numaralarını** guide’dan oku (aşağıdaki tablolarda işaretli).
2. Guide veya BIST değiştiyse: bu §0’daki **API referansları / acceptance** satırlarını güncelle; guide dosyasını bu repoda “düzelterek” sahiplenme.
3. Çelişki: canlı `https://lotlot.net` + BIST kaynak > eski handbook satırı; handbook’u düzelt.
4. Lokal web klonu (isteğe bağlı): `_ref_bist/` — **gitignore**; commit etme.

### 0.3 Faz özeti

```mermaid
flowchart TD
  F0[F0_Foundation] --> F1[F1_AuthComplete]
  F1 --> F2[F2_Browse_Watchlist]
  F2 --> F3[F3_StockDetail]
  F3 --> F4[F4_Account_Legal]
  F4 --> F5[F5_ProPush_NoIAP]
  F5 --> F6[F6_IAP_Paywall]
  F6 --> F7[F7_Store_Submission]
```

| Faz | İsim | Durum | IAP? |
|-----|------|--------|------|
| **F0** | Temel / kalite iskeleti | Tamam (tema web hizalı; INTERNET; display name) | Hayır |
| **F1** | Auth tamam | Tamam (e-posta+Turnstile+Google+Apple E2E; `/me` tier okuma) | Hayır |
| **F2** | Keşfet + Watchlist (+ guest) | Tamam (shell + browse + watchlist) | Hayır |
| **F3** | Hisse detay | Tamam (+ ufuk/ML/formasyon durum parity) | Hayır |
| **F4** | Hesap / yasal / bütünlük | Tamam (AccountSettings + PATCH prefs + legal URLs) | Hayır |
| **F5** | Pro yüzey + push (satın alma yok) | Tamam (çekirdek + wizard/AI) | Satın alma yok |
| **F6** | IAP paywall | İstemci tamam (prod Apple `IAP_ENABLED=1`; Google SA yok) | **Evet** |
| **F7** | Mağaza teslimi | Bekliyor | Hazır olmalı |

Guide §29 P0–P6 ile ilişki: P1 ≈ F1; P4 ≈ F2–F5; P2/P3/P6 ≈ F6–F7 (IAP sona kaydırıldı).

### 0.4 Faz detayları

#### F0 — Temel / kalite iskeleti

- **Amaç:** iOS+Android ortak iskelet, marka, kalite/git ritüeli.
- **Ekranlar:** Splash (marka), minimal home (geçici).
- **API:** — (config `baseUrl` = `https://lotlot.net`).
- **Skills / kurallar:** `project-manager`, `clean-mobile-dev`, `quality-gate-pre-push`, `agent-handbook`, `risk-integrity-mobile`.
- **Acceptance:**
  - [x] Flutter iskelet, Provider, secure storage, tema
  - [x] Brand CDN logo + launcher ikon
  - [x] analyze + sonar + tag akışı
  - [x] Release `INTERNET` main manifest
  - [x] Display name **LOTLOT.NET** (Android label + iOS `CFBundleDisplayName`)
  - [x] `LotlotColors` / tema web `brand.css` token’larıyla hizalı (`brand-visual-parity`)
- **Dışı:** Yeni ürün ekranı şişirme.
- **Risk:** Release build’de network yoksa tüm fazlar kırılır.

#### F1 — Auth tamam

- **Amaç:** Üç kanal + oturum yaşam döngüsü (guide §4–§8).
- **Ekranlar:** Splash bootstrap; Login/Register; e-posta doğrulama bekleyen; (opsiyonel) şifre sıfırlama → web.
- **API (guide):** §5–§6 login/register; §8.4–§8.5 Google/Apple mobile; §8.6 Turnstile `https://lotlot.net/mobile/turnstile`; §7 refresh; §8 logout / `DELETE /me`.
- **Skills:** `cybersecurity-expert`, `android-fullstack-developer`, `ios-fullstack-developer`.
- **Acceptance:**
  - [x] E-posta + Turnstile lazy köprü (register/login)
  - [x] Google + Apple native SDK → `google-mobile` / `apple-mobile` (Client ID’ler `OauthLocal` / dart-define)
  - [x] Splash: token → `/me` → gerekirse refresh → home | login
  - [x] Logout revoke (`refresh_token`) + local wipe; hesap silme UI
  - [x] Token log’larda yok
  - [x] Register → `pending_verification` + resend UX
  - [x] `email_not_verified` → doğrulama bekleyen ekran
  - [x] Apple native E2E (prod `APPLE_MOBILE_CLIENT_IDS=com.lotlot.lotlotnetMobile` + web `APPLE_CLIENT_ID`)
- **Dışı:** Web session cookie auth. Guest shell F2’de (F1 sonrası splash hâlâ login’e düşebilir; F2’de browse’a açılır).
- **Risk / web:** Prod `GOOGLE_MOBILE_CLIENT_IDS` (iOS+Android), `APPLE_MOBILE_CLIENT_IDS`, `TURNSTILE_SITE_KEY`. Google Cloud OAuth client’ları + iOS URL scheme.

#### F2 — Keşfet + Watchlist (+ guest browse)

- **Amaç:** Ana shell: **kayıtsız keşif** + (auth ise) izleme listesi / tahmin özeti (guide §10–§12, §17 stocks / public).
- **Ekranlar:** Guest/Auth ortak shell — Search/Browse; BIST 30/100 özet; Home/Watchlist (auth); kota göstergesi (auth); login/register CTA (guest).
- **API (guest, Bearer yok):** `GET /api/stocks/search`; `GET /api/stocks`; `GET /api/public/index-screener`; (F3’e köprü) public chart/valuation teaser linkleri.
- **API (auth):** `GET/POST/PATCH/DELETE /api/watchlist*`; `GET /api/watchlist/predictions`; `/me` quota alanları.
- **Skills:** `project-manager`, `clean-mobile-dev`, `ux-expert`.
- **Acceptance:**
  - [x] **Guest browse:** oturum yokken **Landing** açılır (zorunlu login yok); BIST Hisseleri → tam katalog arama; hisse teaser public API ile
  - [x] Guest → hisse satırına dokununca F3 detay açılır
  - [x] Guest’te watchlist mutation / predictions → net “Giriş yap” / kayıt CTA (sessiz 401 yok)
  - [x] Auth: watchlist CRUD + hata/403/kota mesajları sunucudan
  - [x] Auth: predictions listesi render-only (`label` / confidence; ham `display_state` yok)
  - [x] Email verified gate uyumu (watchlist yazma)
  - [x] Splash: bootstrap → **Landing** (auth olsa da); logout → Landing; shell’de Keşfet yok
- **Dışı:** Admin cache-report UI (zorunlu değil); Pro gated kartlar (F5).
- **Risk:** Aylık mutation kotası client’ta uydurulmaz; guest’te Bearer gönderme.

#### F3 — Hisse detay

- **Amaç:** Public teaser (**guest OK**) + auth analiz; Adil Değer ayrı (guide §17.2, §22).
- **Ekranlar:** Stock detail (özet + kartlar + sade grafik).
- **API (guest):** `/api/public/stocks/<sym>/valuation|fundamentals|corporate`; `/api/public/chart-data`.
- **API (auth):** `/api/pattern-analysis`, `/api/chart-data` (levels).
- **Skills:** `seo-expert` (deep link hazırlığı F7), Android/iOS FS.
- **Acceptance:**
  - [x] Guest hisse detay: public kartlar + grafik teaser; auth-only bloklarda “Giriş yap” CTA
  - [x] Valuation ayrı çağrı; yoksa kart gizli
  - [x] Mum + MA (sade); web drawing suite **yok**
  - [x] Pattern/signal alanları olduğu gibi (auth); `pending` → loading/empty
  - [x] Sezgisel rozet + haber sheet; formasyonlar + görsel onay (`pattern-analysis`)
  - [x] Ufuk chip’leri + `signals_by_horizon` Genel Sinyal Gücü + `ml_unified` tahmin özeti
  - [x] Formasyon durum etiketleri (web `_patternStatus` hizası) + sıralama
  - [x] Free prune boş → Pro soft gate CTA (auto-pop yok)
  - [x] Disclaimer görünür
  - [x] Browse / watchlist / prediction satırı → `StockDetailScreen`; placeholder kaldırıldı
- **Pre-dev not (2026-08-03):** Public chart `ohlcv[]` + `time` (unix); valuation/fundamentals/corporate alanları guide ile uyumlu (THYAO canlı GET).
- **Post-dev matris:** S1 guest THYAO public+CTA; S2 valuation unavailable gizli; S3 auth pattern+levels; S4 pending crash yok; S5 watchlist tap; S6 public `auth:false`; S7 disclaimer.
- **Dışı:** Fib/Gann/Elliott çizim motoru; chart formasyon range highlight; chart-alerts (F5); deep link aasa (F7).
- **Risk:** Cache/`pending` analiz — loading/empty states.

#### F4 — Hesap / yasal / bütünlük

- **Amaç:** Settings, yasal, iOS↔Android parity smoke.
- **Ekranlar:** `AccountSettingsScreen`; Legal **dış tarayıcı** (`url_launcher`); `push_notifications` / `email_notifications` → `PATCH /me`.
- **API:** §8 `PATCH /api/auth/me`; legal: `/gizlilik`, `/privacy`, `/terms`.
- **Skills:** `cybersecurity-expert`, `project-manager`, `seo-expert` (ASO), `ux-expert`.
- **Acceptance:**
  - [x] Quota + subscription **okuma** (`/me`) — `subscription.label` + watchlist limit / mutation remaining
  - [x] Privacy/terms/KVKK erişimi (dış tarayıcı)
  - [x] Kritik ekranlarda yatırım tavsiyesi değildir (hesap ekranı + mevcut auth/detail)
  - [x] iOS + Android smoke checklist (aşağıda)
  - [x] Ayarlarda `push_notifications` + `email_notifications` toggle (OS/FCM **yok** — F5)
- **Pre-dev (2026-08-03):** `/gizlilik` `/privacy` `/terms` → 200; `/me` Bearer zorunlu.
- **Post-dev matris:** S1 auth hesap `/me`; S2–S3 toggle PATCH; S4 hata geri al; S5 yasal; S6 guest bilgi; S7 çıkış/sil.
- **Smoke checklist (manuel):**
  - [ ] iOS: Hesap aç → label görünür → toggle → yasal tarayıcı → çıkış
  - [ ] Android: aynı
  - [ ] Guest: Bilgi ikonu → yasal + Giriş; PATCH yok
- **ASO (erken taslak):** Başlık “LOTLOT.NET — BIST Analiz”; kısa: “BIST hisseleri, adil değer ve izleme listesi. Yatırım tavsiyesi değildir.” Anahtar: BIST, hisse, adil değer, lotlot.
- **Dışı:** IAP satın alma UI; FCM token kaydı (F5).

#### F5 — Pro yüzey + push (satın alma yok)

- **Amaç:** Tier’a göre gated özellikler + **Premium gerçek zamanlı / push bildirimleri**; **satın alma F6’da**.
- **Bu turda (çekirdek):** Soft gate; Chart alerts; watchlist `alert_enabled`; OS izni + FCM register; Socket `actionable_alert`; `deep_link` → hisse detay.
- **Dilim (wizard/AI):** Hisse Sihirbazı UI; AI commentary UI — **tamam**.
- **API:** §18.1–18.3; §25 `device/register|unregister`; Socket.IO.
- **Firebase:** `android/app/google-services.json` + `ios/Runner/GoogleService-Info.plist` **gitignore**. Yoksa init no-op + hesap uyarısı (S7).
- **Acceptance (çekirdek):**
  - [x] `pro_required` / `premium_required` → soft gate (IAP yok)
  - [x] OS bildirim izni akışı (context’li; Premium + push)
  - [x] FCM register (Premium + push on); logout unregister; `onTokenRefresh` → re-register
  - [x] Foreground FCM `onMessage` → SnackBar; Socket `actionable_alert` banner
  - [x] Deep link (`data.deep_link` → StockDetail); cold-start kuyruk + splash flush
  - [x] Free chart-alerts: soft gate otomatik pop yok (boş + Detay)
  - [x] Hesap push aç → Premium soft gate; watchlist alert + push kapalı → Hesap yönü
  - [x] Tier `/me` — client uydurmaz
  - [x] Privacy Manifest / Data safety notu (aşağı)
- **Acceptance (dilim):**
  - [x] Pro: hisse detay CTA → `POST /api/ai/commentary` → `text`; Free soft gate
  - [x] 429 rate_limited/busy + 502 anlaşılır
  - [x] Premium: Sihirbaz (`AL`/`SAT`/`TUT`, horizons prod) → `results` → detay
  - [x] 400 `invalid_selection` + `details`
- **Firebase ekleme:** Console’dan iOS/Android app → dosyaları yerel yollara koy → rebuild. Commit etme.
- **Privacy / Data safety:** FCM registration token = cihaz tanımlayıcı; App Privacy / Play Data safety’de bildirim + identifiers. Token loglanmaz.
- **Post-dev matris:** S1–S10 (plan); wizard W1–W7.
- **Dışı:** StoreKit/Play purchase; VAPID/web-push.
- **Risk:** Entitlement fake yok; Free/Pro `device/register` client guard.

#### F6 — IAP paywall

- **Amaç:** Tek mobil satış kanalı (guide §9, §25–§28, §29 P2–P3).
- **Ekranlar:** `PaywallScreen`; Restore; mağaza abonelik yönetimi URL; soft gate → paywall.
- **API:** `GET /api/billing/iap/config`; `POST .../verify`; `POST .../restore`; sonra `/me`.
- **Skills:** `ios-fullstack-developer`, `android-fullstack-developer`, `cybersecurity-expert`.
- **Acceptance:**
  - [ ] Sandbox/license tester E2E: satın al → verify → tier (`IAP_ENABLED=1` + store ürünleri)
  - [x] Restore UI + API çağrısı (prod enabled olunca E2E)
  - [x] Garanti/WebView **yok**
  - [x] Soft gate’ler paywall’a bağlanır
  - [x] Config kapalıyken paywall çökmez; satın alma kilitli mesaj
- **Web bağımlılığı:** Product ID’ler, `IAP_ENABLED`, bundle/package env. **2026-08-03 prod:** Apple-only `IAP_ENABLED=1` + `APPLE_IAP_BUNDLE_ID=com.lotlot.lotlotnetMobile`; `platforms.google_play=false` (SA yok). Sandbox E2E store ürünlerine bağlı.
- **Kod:** `lib/features/billing/` (`BillingController`, `IapService`, `PaywallScreen`); `in_app_purchase`.

#### F7 — Mağaza teslimi

- **Amaç:** Store submission (guide §9.9, §28.5, §29 P6).
- **Ekranlar:** — (metadata, screenshots, privacy forms).
- **API:** Deep link: assetlinks / aasa (web).
- **Skills:** `seo-expert` (ASO), `project-manager` (go/no-go), platform FS.
- **Acceptance:**
  - [ ] Data safety / App Privacy doğru
  - [ ] Restore + hesap silme Review’da görünür
  - [ ] Build notları: dijital abonelik yalnızca IAP
  - [ ] analyze + sonar + smoke yeşil
- **Dışı:** Admin/HPO.

### 0.5 Tüm fazlarda bilinçli dışı

- `/api/admin/*`, `/api/internal/*`, `/api/automation/*`, HPO, admin dashboard
- Garanti / in-app WebView checkout
- Web chart drawing suite kopyası
- `MOBILE_API_INTEGRATION_GUIDE.md` dosyasına mobil ekibinin “sahiplenerek” edit’i

### 0.6 Faz bitiş ritüeli

1. Risk analizi (`risk-integrity-mobile`) — iOS+Android
2. Minimal kod + skills
3. Bu §0’da faz **Durum** / acceptance checkbox güncelle
4. `flutter analyze` → `sonar-scanner` → commit → tag `vN` → push (`bistmobile-git-flow`)

---

## 1. Proje özeti

| | |
|---|---|
| Uygulama | LOTLOT.NET Flutter mobil (Android + iOS) |
| Bu repo (yerel) | `lotlotnet_mobile` |
| GitHub remote | https://github.com/ersinarikan/bistmobile |
| Web/API | https://lotlot.net (sunucu: www.lotlot.net) |
| Web kaynak kod | https://github.com/ersinarikan/BIST |
| API sözleşmesi (salt okuma) | `docs/MOBILE_API_INTEGRATION_GUIDE.md` — web ekibi günceller |
| Yol haritası | **§0** (bu dosya) |
| SonarCloud | https://sonarcloud.io/dashboard?id=ersinarikan_bistmobile |

## 2. Cursor kuralları (`.cursor/rules/`)

Hepsi `alwaysApply: true` (özet):

1. **web-server-ssh** — Canlı sunucu www.lotlot.net; SSH ile teşhis (yazma/restart izinsiz yok). Kod referansı için önce BIST repo.
2. **clean-mobile-dev** — Temiz kod; gereksiz kod yok; anlaşılır “neden” comment’leri; yazınca test/review.
3. **post-change-refactor** — Değişiklik sonrası ilgili dosyalarda refaktör fırsatını değerlendir.
4. **web-bist-repo** — Web kodu: ersinarikan/BIST.
5. **bistmobile-git-flow** — İş bitince: kalite → commit → sıradaki tag (`vN`) → push bistmobile.
6. **quality-gate-pre-push** — Commit/push öncesi: **test+review** + `flutter analyze` + `sonar-scanner`.
7. **risk-integrity-mobile** — Kod öncesi risk/etki analizi; iOS+Android bütünlüğü; yan etkiyi kırma.
8. **agent-handbook** — Bu kılavuzu her değişiklik sonrası güncelle (özellikle §0 faz durumu).
9. **brand-visual-parity** — Renk/tema/font/logo web (`brand.css` / lotlot.net) ile aynı; görsel işi siteden doğrula.
10. **test-and-review** — **Web incele → geliştir → test/parity**; analyze yetmez.

## 2b. Agent skills (`.cursor/skills/`)

Her skill: `SKILL.md` + detay `reference.md`. İlgili konuda otomatik / istenince uygula.

| Skill | Rol |
|-------|-----|
| `seo-expert` | Teknik SEO, içerik, ASO, deep link / web tutarlılığı |
| `android-fullstack-developer` | Android native + Play + Billing + FCM + Flutter embedding |
| `ios-fullstack-developer` | iOS native + StoreKit + APNs + Privacy + Flutter embedding |
| `project-manager` | Kapsam, faz, risk, bağımlılık, go/no-go |
| `cybersecurity-expert` | Appsec, token, OWASP Mobile, secret, sertleştirme |
| `ux-expert` | Hedefe odaklı UX; jargon/geliştirici notunu UI’dan uzak tut; heuristic review |
| `test-engineer` | **Pre-dev:** web davranışı; **post-dev:** matris + parity; analyze ≠ test |

## 3. Mimari (mevcut)

```
lib/
  main.dart                 # LotlotApp, Provider tree
  core/
    api/api_client.dart     # HTTP + Bearer + refresh
    brand/brand_assets.dart # CDN logo URL + BrandLogo
    config/api_config.dart  # baseUrl = https://lotlot.net
    storage/token_storage.dart
    theme/app_theme.dart    # LotlotColors / dark tema
  features/
    splash/                 # bootstrap → Landing | MainShell
    landing/                # guest hero (web landing parity)
    stocks/                 # BIST Hisse Merkezi (`GET /api/stocks`)
    auth/                   # login/register/OAuth + SessionController
    shell/                  # İzleme (+ arama)
    billing/                # IAP paywall / verify / restore
    browse/                 # (legacy screener; shell’de yok)
    watchlist/              # auth list + predictions
```

State: **Provider**. Token: **flutter_secure_storage**.

### Skills notu (2026-08-03)

- `test-engineer`: web parity zorunlu; prod PREDEPLOY §3 + register matrisi (reference B1–B5)
- Kayıt: `email_already_registered` + `invalid_email` / `weak_password` / `rate_limited` map
- `verification_email_sent` → pending ekran kopyası + resend banner
- Kural `test-and-review`: yazınca senaryo + self-review zorunlu

## 4. Yapılanlar (kronoloji)

### v28 (2026-08-03) — Web↔mobil analiz parity
- Hisse detay `PatternSection`: ufuk chip’leri, Genel Sinyal Gücü (`confidence_bar_type`), `ml_unified` tahmin özeti
- Formasyon durum etiketleri + web sıralama (`formation_status.dart`); ortak `HorizonChips`
- İzleme satırı: predictions’tan fiyat + seçili ufuk sinyal teaser
- Prod IAP (önceki tur): Apple-only açıldı — handbook F6 notu güncellendi

### v27 (2026-08-03) — F6 IAP paywall (istemci)
- `in_app_purchase` + `BillingController` / `PaywallScreen`
- Soft gate → Planları gör → paywall; Hesap: planlar + geri yükle
- Config kapalıyken satın alma kilitli (Garanti/WebView yok); sonra prod Apple `enabled=true`
- E2E: App Store sandbox + (sonra) Play SA/ürünleri

### v26 (2026-08-03) — Landing, BIST arama, auth + chart cila
- Splash → `LandingScreen` (Ücretsiz Başla / Giriş / BIST Hisseleri; Özellikler/Metodoloji yok)
- `StocksSearchScreen`: `GET /api/stocks` + sektör + BIST 30/100; satır → detay
- Birleşik `AuthScreen` (web modal parity: Apple/Google, kayıt↔giriş, geri/kapat)
- `MainShell`: Keşfet kaldırıldı — İzleme + arama; logout → Landing
- Chart: CustomPainter mum + MA20 + S/R + OHLCV dokunma; `overall_signal` Map parse (G9)
- `analysis_options.yaml`: `build/**` exclude (Problems flood)

### v25 (2026-08-03) — Watchlist build-phase fix
- Guest `clear()` / auth `refresh()` post-frame (setState during build yok)

### v24 (2026-08-03) — UX cila (Sezgisel + metin)
- Sezgisel sheet: haber kaynağı + yön; formasyon sinyal Türkçe; çift Görsel rozet yok
- Predictions/overall Türkçe; AI ham exception yok; wizard likidite `unknown` → Bilinmiyor
- Handbook P13 / F2 predictions metni güncellendi

### v23 (2026-08-03) — Pattern yüzeyi + parity audit
- Hisse detay: Sezgisel sheet, formasyonlar, görsel onay (`pattern-analysis` cache)
- Handbook §7.2 guide↔prod; §7.3 F0–F5 parity matrisi
- Free boş pattern → Pro soft gate CTA

### v22 (2026-08-03) — F5 cila + predictions
- Wizard: izlemeye ekle; `email_not_verified` mesajı
- AI: uzun bekleme kopyası; watchlist: confidence bar, ham `display_state` kaldırıldı

### v21 (2026-08-03) — F5 dilim: wizard + AI
- Hisse detay: CTA → `POST /api/ai/commentary` → `text` (Pro soft gate)
- Hisse Sihirbazı: Premium form (AL/SAT/TUT, prod horizons) → results → detay
- Hesap + İzleme girişleri; prod şema (guide `bullish` örneği kullanılmaz)

### v20 (2026-08-03) — F5 cila
- Soft gate auto-pop kaldırıldı; push toggle Premium gate; FCM foreground SnackBar
- `onTokenRefresh` re-register; deep_link cold-start kuyruk; Türkçe chart form etiketleri
- `push_disabled` / kota alanları / `channels_allowed` yoksa sunucuya bırak

### v19 (2026-08-03) — F5 Pro + push çekirdek

- Soft gate; chart alerts CRUD; watchlist `alert_enabled`
- Firebase optional (gitignore configs); FCM register; Socket actionable_alert; deep_link
- Privacy/Data safety notu; wizard/AI ertelendi

### v18 (2026-08-03) — F4 cila

- Hesap: auth geçişinde `refreshMe`; yasal `launchUrl` try/catch; yüzey kartları
- Çıkışta shell Keşfet’e dönüş; “Gizlilik (EN)” etiketi

### v17 (2026-08-03) — F4 hesap / yasal

- `AccountSettingsScreen`: `/me` label+kota; push/e-posta PATCH; yasal dış tarayıcı
- `url_launcher` + `LegalUrls`; shell Hesap / Bilgi; logout-sil ayarlarda
- Post-dev S1–S7; ASO taslak; smoke checklist

### v16 (2026-08-03) — F3 cila

- Login `popOnSuccess`: detay/watchlist/shell’den girişte ekran korunur
- Hisse detay: auth geçişinde pattern/levels yeniden yükleme; dispose-safe notify
- SMA etiketi; destek/direnç jargonsuz; Adil Değer bar ±5 hizası; guest bookmark → giriş

### v15 (2026-08-03) — F3 hisse detay

- `StockDetailScreen` + controller: public valuation/fundamentals/corporate/chart paralel; auth pattern + chart levels
- `fl_chart` mum + SMA(20) overlay; boş kartlar gizli; disclaimer
- Browse / watchlist / prediction → detail; placeholder sheet kaldırıldı
- Post-dev: S1–S7 matris; public `auth:false`; P7 fixed

### v1 (2026-08-03) — ilk push

- Flutter iskelet: auth/session, splash, login, home
- Marka: lotlot.net PWA ikonu → launcher (`flutter_launcher_icons`); in-app logo CDN (`BrandLogo`)
- Cursor kuralları 1–5 (SSH, temiz kod, refaktör, BIST repo, git flow)
- Remote: `git@github.com:ersinarikan/bistmobile.git`, tag **v1**
- GitHub SSH key bu Mac’te: `~/.ssh/id_ed25519_bistmobile`

### v2 (2026-08-03) — kalite + kılavuz

- Kalite kapısı kuralı + `sonar-project.properties` + Homebrew `sonar-scanner`
- SonarCloud projesi `ersinarikan_bistmobile`; analiz yeşil
- Risk/bütünlük kuralı (`risk-integrity-mobile`)
- Agent kılavuzu: `docs/AGENT_HANDBOOK.md` + güncelleme kuralı (`agent-handbook`)
- `.scannerwork/` gitignore

### v3 (2026-08-03) — rol skills

- Beş proje skill’i eklendi (SEO, Android FS, iOS FS, PM, siber güvenlik)
- Her birinde kapsamlı `SKILL.md` + `reference.md`

### v5 (2026-08-03) — F0 kural uyumu

- `LotlotColors` ← web `brand.css` (#19e38a, #0b2018, …)
- Splash/login web `.brand-dark` radial gradient
- Android `INTERNET` + label `LOTLOT.NET`; iOS display name; launch `#071610`

### v6 (2026-08-03) — ikon, UX, push roadmap

- Launcher ikon: net vektör-tarzı marka (`tool/generate_app_icon.py` + `flutter_launcher_icons`); bg `#071610`
- Login/home: iç billing/sprint metinleri kaldırıldı (UX)
- Skill: `ux-expert` (Nielsen heuristic + mobil keskinleştirme)
- F4/F5: Free/Pro/Premium + Premium FCM/Socket/OS izni akışı handbook’ta netleştirildi

### v7 (2026-08-03) — F1 e-posta auth (Google/Apple hariç)

- Register + lazy Turnstile WebView (`/mobile/turnstile`)
- Verify-email pending + resend; login `email_not_verified` / `captcha_required`
- Logout `refresh_token` revoke; `DELETE /me` hesap silme
- `webview_flutter` eklendi

### v8 (2026-08-03) — F1 Google / Apple native

- `google_sign_in` + `sign_in_with_apple` → `POST .../google-mobile` / `apple-mobile`
- iOS Sign in with Apple entitlement; Bundle ID `com.lotlot.lotlotnetMobile`
- `OauthConfig` / `OauthLocal` — Google iOS client dolu; Apple E2E prod (`APPLE_MOBILE_CLIENT_IDS`)

### Handbook — guest browse (2026-08-03)

- §0.1 karar: **Guest browse = evet** (kayıtsız public keşif)
- F2 acceptance: guest shell, public search/screener, auth CTA; splash token yok → browse
- F3: guest hisse teaser + auth-only CTA
- F1 durumu: Tamam (Apple E2E OK)

### v9 (2026-08-03) — F2 guest browse + watchlist

- `MainShell`: Keşfet | İzleme; splash → shell (zorunlu login yok)
- Public: `stocks/search`, `public/index-screener`; auth: watchlist CRUD + predictions
- Guest İzleme CTA; hisse satırı F3 placeholder sheet; kota / `email_not_verified` mesajları
- F1 `HomeScreen` stub kaldırıldı (hesap menüsü AppBar’da)

### v4 (2026-08-03) — yol haritası §0 + görsel parity

- Handbook **§0 Mobil ürün yol haritası** (F0–F7); API guide salt-referans politikası
- Ürün önce, IAP sonda; README işaretlendi
- Kural **brand-visual-parity**: renk/font/görsel web’den doğrulanır

## 5. Çalışma ritüeli

1. İstek → **risk analizi** (platform + çapraz etki)
2. Hangi **§0 faz**? Acceptance’a bak
3. **`test-engineer` pre-dev:** web/prod/guide incele → davranış + matris iskeleti (kod yok)
4. Minimal / temiz kod; API guide **oku** (yazma); thin client
5. **`test-engineer` post-dev** + kural `test-and-review` → bulguları düzelt
6. Refaktör değerlendirmesi + **§0 durum güncelle**
7. `flutter analyze` → `sonar-scanner` → commit → tag `vN` → push

```bash
# Döngü: web anla → kod → davranış testi → sonra:
flutter analyze
export SONAR_TOKEN='…'   # ortama; commit etme
sonar-scanner
# sonra git commit + tag + push
```

## 6. Marka / ikon / tema

| Kullanım | Kaynak |
|---|---|
| In-app logo | `https://lotlot.net/static/img/brand/lotlot-icon-transparent.png` (`BrandAssets`) |
| Launcher | `tool/generate_app_icon.py` → `assets/branding/app_icon*.png` + `dart run flutter_launcher_icons` (marka #071610 / #19e38a) |
| Tema token’ları | Web `static/css/brand.css` → `LotlotColors` (`brand-visual-parity`) |
| Not | CDN `immutable` cache (~1 yıl); aynı URL’de değişince istemci gecikebilir |

## 7. Bilinen / ertelenen

- [x] lotlot.net SSH (`~/.ssh/id_ed25519_lotlot` → `root@lotlot.net`)
- [x] F2: guest browse + watchlist — bkz. **§0**
- [x] F3: hisse detay (public + auth pattern) — bkz. **§0**
- [x] F4: hesap / yasal / bildirim prefs — bkz. **§0**
- [x] F5 çekirdek: soft gate + chart alerts + push/socket — bkz. **§0**
- [x] F5 dilim: wizard / AI commentary
- [ ] F6+: IAP — bkz. **§0**
- [ ] Web: `/metodoloji` 404 (landing link kırık olabilir; web ekibi)

### 7.1 Parity review (2026-08-03) — F0–F2

Kaynak: prod `api_auth_routes.py` / `login_protection.py` / `api_watchlist_routes.py` + mobil `lib/features/**`.

| ID | Sev | Alan | Web/API beklenen | Mobil | Durum |
|----|-----|------|------------------|-------|-------|
| P1 | High | Login Turnstile retry | Token sonrası hata görünür | Tekrar `needsTurnstile` / fail sessiz kalabilirdi | **fixed** — login_screen (register ile aynı) |
| P2 | High | Bootstrap 401 | Geçersiz oturum wipe | 401’de token clear eksikti | **fixed** — `bootstrap` `_tokens.clear()` |
| P3 | Med | Bootstrap 5xx/ağ | Soft retry / “yeniden dene” | Guest shell + token kalır; splash retry yok | **fixed** — splash Yeniden dene + Misafir |
| P4 | Med | Login `invalid_credentials`+`captcha_required` | Guide: köprü aç | Köprü açılır; yanlış şifre metni bazen atlanır | **fixed** — mesaj korunur + köprü |
| P5 | Med | `email_already_registered` CTA | Web: girişe yönlendir | Mesaj var, tek tık Giriş butonu yok | **fixed** — Giriş yap CTA + SnackBar |
| P6 | Med | Watchlist alert/PATCH | Web alert alanları | `alert_enabled` UI + soft gate | **fixed** (F5) |
| P7 | Med | Hisse detay | Web `/hisse/...` | `StockDetailScreen` + public/auth API | **fixed** (F3) |
| P8 | Low | `oauth_failed` / `token_issue_failed` map | Anlaşılır mesaj | Ham/genel | **fixed** — friendly map |
| P9 | Low | Browse yoğunluk | Web `/stocks` zengin | Screener+search yeterli F2 | OK / F3 zenginleştirir |
| P10 | — | Guest Bearer | Public `auth:false` | search/screener `auth:false` | OK |
| P11 | — | Register error map | §5 kodları | invalid_email/weak/409/sent bayrağı | OK (v11) |
| P12 | — | Logout | Session wipe | Shell’de kalır (guest) | OK (F2) |
| P13 | — | Predictions | Render-only label/güç | `label` + confidence bar; ham `display_state` yok | **ok** (v22/v24) |
| P14 | — | Token log | Yok | Grep temiz | OK |

**Critical:** yok.

**Bu turda düzeltilen:** P7 (F3 hisse detay).

### 7.2 Guide ↔ prod fark kaydı (2026-08-03)

Kaynak: SSH `/opt/bist-pattern` (salt okuma) vs `docs/MOBILE_API_INTEGRATION_GUIDE.md`. **Guide’a mobil edit yok** — web ekibine iletilecek maddeler.

| ID | Sev | Konu | Guide iddia | Prod gerçek | Mobil etki / öneri |
|----|-----|------|-------------|-------------|-------------------|
| G1 | High | Wizard `signal_types` | Örnek `["bullish"]` | `AL` / `SAT` / `TUT` (`SIGNAL_KEYS`) | Mobil prod enum kullanıyor; **guide örneğini düzelt** |
| G2 | Med | Wizard horizons | Kısmi örnek `1d`,`7d` | `1d,3d,7d,14d,30d` | Mobil tam set; guide tabloya yaz |
| G3 | Med | Wizard 400 | `validation_errors` vurgusu | `error: invalid_selection` + `details[]` | Mobil `invalid_selection` mapli; guide hizala |
| G4 | Med | AI success body | Yok | `status,symbol,model,text,cached,duration_s` | Mobil `text` okuyor; **guide’a success örneği ekle** |
| G5 | Med | AI 429 | `rate_limited` / `busy` | rate 6/60s + busy→429 | OK; guide metinleri netleştir |
| G6 | Med | Sezgisel / görsel onay | `news_context` kısmen; UI adı yok | FINGPT + `news_context` + `confirmation_sources` | Mobil UI eklendi; guide’a Sezgisel/görsel onay notu |
| G7 | Low | `user/predictions`, `pattern-summary` | §18.1 listeli | Prod var | Mobil client **yok** (bilinçli; backlog) |
| G8 | Low | Batch pattern | §15.1 | Prod var | Mobil yok (bilinçli) |
| G9 | Med | `overall_signal` | Örnek string `BUY` | Nesne `{signal,confidence,strength,reasoning,signals[]}` veya string | Mobil her iki şekli parse eder; **guide örneğini güncelle** |

**Web ekibine özet:** G1–G6, G9 guide düzeltme; G7–G8 isteğe bağlı mobil sonraki faz.

### 7.3 F0–F5 web ↔ mobil parity matrisi (2026-08-03)

| Alan | Web | Mobil | Durum |
|------|-----|-------|--------|
| Auth e-posta + Turnstile | Lazy köprü | Aynı | **ok** |
| Google/Apple | Native → mobile endpoints | Var | **ok** |
| Guest browse | Public stocks | Keşfet | **ok** |
| Watchlist CRUD + kota | Dashboard | İzleme | **ok** |
| Watchlist satır teaser | Fiyat + sinyal | Fiyat + seçili ufuk `label` (predictions) | **ok** (v28) |
| Predictions kart | label, güç çubuğu, stale | label/summary + `genel_confidence_pct` bar; ham `display_state` yok | **ok** (cila) |
| Hisse public kartlar | valuation/fund/corporate | Var | **ok** |
| Chart + levels | Lightweight Charts | Özel mum + MA20 + S/R + dokununca OHLCV | **ok** (sade; drawing suite yok) |
| Sezgisel + haber sheet | 💡 portal | Rozet + bottom sheet | **ok** |
| Ufuk + Genel Sinyal | Detay modal ufuk | Chip + `signals_by_horizon` | **ok** (v28) |
| ML / öngörü özeti | `detailMlUnified` | `ml_unified[horizon]` kart | **ok** (v28; chart çizgisi yok) |
| Formasyonlar + görsel onay | Liste + durum badge | Durum + `görsel onay` + sıralama | **ok** (v28) |
| Chart formasyon highlight | range hover | — | **bilinçli dışı** |
| AI commentary | Pro | CTA → `text` | **ok** |
| Hisse Sihirbazı | Premium modal | Form + izlemeye ekle | **ok** |
| Chart alerts | Pro+ | Hesap → ekran | **ok** |
| Soft gate / IAP | Web paywall | Soft gate → `PaywallScreen` (prod Apple enabled) | **istemci ok** |
| FCM push | — | Optional Firebase | **ok** / no-op configsız |
| `pattern-summary` UI | Var/özet | Yok | **gap** (backlog) |

## 8. Dokunulmaması gerekenler

- Secret / `.env` / `SONAR_TOKEN` / private key commit yok
- Üretim sunucusunda izinsiz yazma / restart / migrate yok
- Force push / tag silme yalnız açık kullanıcı isteğiyle
- API integration guide’ı mobil “master” sayıp bu repoda sahiplenerek rewrite yok

## 9. Hızlı dosya haritası

| Ne | Nerede |
|---|---|
| Agent kılavuzu + **yol haritası §0** | `docs/AGENT_HANDBOOK.md` (bu dosya) |
| API rehberi (salt okuma) | `docs/MOBILE_API_INTEGRATION_GUIDE.md` |
| Sonar config | `sonar-project.properties` |
| Cursor rules | `.cursor/rules/*.mdc` |
| Skills | `.cursor/skills/*/SKILL.md` |
