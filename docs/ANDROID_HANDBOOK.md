# LOTLOT.NET — Android Handbook

> Android ilerleme, gap ve iOS-güvenli plan. **iOS Review beklerken** bu dosya takip kaynağıdır.  
> Ana ürün roadmap: [`AGENT_HANDBOOK.md`](AGENT_HANDBOOK.md) §0.  
> Son güncelleme: 2026-08-07 (ilk envanter + A0–A5 plan)

---

## 0. Kararlar (kilitli)

| Konu | Karar |
|------|--------|
| iOS koruma | Android işi **ortak Flutter’ı bozmaz**. Tercih: `android/` + config + ince `Platform.isAndroid` dalları. Shared auth/billing/push çekirdeğinde “yeniden yazma” yok. |
| Auth parity | Android’de **Google + Apple + e-posta** — iOS ile aynı seçenekler. Apple butonu Android’de gizlenmeyecek (ürün kararı 2026-08-07). |
| Package ID | `com.lotlot.lotlotnet_mobile` (**değiştirme**; Firebase/OAuth/Play buna bağlı olacak). iOS Bundle `com.lotlot.lotlotnetMobile` farklı kalır — bilinçli. |
| Monetization | Yalnızca **Play Billing** (web POS / Garanti yok). Apple StoreKit’e dokunma. |
| Backend | `MOBILE_API_INTEGRATION_GUIDE` + BIST **salt okuma** (fork yok). Env ekleri web/ops ile. |
| Kalite | Commit/push/ship: analyze + **Sonar QG OK** (`quality-gate-pre-push`). Play ship = QG yeşil. |
| Skills | `android-fullstack-developer`, `project-manager`, `cybersecurity-expert`, `test-engineer`, `ux-expert` |

### iOS’u bozmama kuralları (zorunlu)

1. `OauthSignIn.initialize` / Google `clientId` seçiminde iOS dalını regresyon test et (veya dokunma + Android-only default).  
2. Firebase: `google-services.json` yokken iOS build’i kırılmamalı (şu an optional plugin — koru).  
3. IAP ürün ID’leri (`lotlot_pro_monthly_v2`, `lotlot_premium_monthly`) **paylaşılan**; Play için yeniden adlandırma yok.  
4. `google_play=true` flip’i yalnız Play ürün + SA hazırsa; aksi halde iOS etkilenmez ama Android paywall “kırık” görünür.  
5. Deep link / `app_links` değişiklikleri her iki OS’i etkiler — `lotlot://` sözleşmesini koru.  
6. Her Android PR/self-review’da soru: **“Bu diff iOS TF +76 davranışını değiştirir mi?”**

---

## 1. Durum özeti (2026-08-07)

| Katman | iOS (TF / Review) | Android |
|--------|-------------------|---------|
| Flutter ürün yüzeyi | Tam (F0–F6) | Kod büyük ölçüde **ortak** |
| Google Sign-In | E2E OK | Client ID **boş**; SHA/Firebase eksik |
| Apple Sign-In | E2E OK | UI **gizli** + SDK Android path **yok** → **parity gap (ürün)** |
| E-posta + Turnstile | OK | Ortak kod — cihaz smoke açık |
| FCM push | OK (+76 token ownership) | `google-services.json` **yok** → no-op |
| IAP | StoreKit Sandbox PASS | `google_play=false`; Play hesabı yok |
| Release imza | ASC / Team | **debug signing** (Play’e yüklenemez) |
| Deep link `lotlot://` | OK | Manifest’te var |
| HTTPS App Links / aasa | İkisi de dışı (web) | Aynı |

**Blokleyenler (Android ship):** Play hesabı · release keystore · Firebase Android app · Google Android OAuth · (ürün) Apple-on-Android config · Play Billing + backend SA.

---

## 2. Kod envanteri (platform farkları)

### 2.1 Bilinçli `Platform` dalları

| Dosya | Ne yapıyor | Android notu |
|-------|------------|--------------|
| `lib/features/auth/auth_screen.dart` | `showApple = !Platform.isAndroid` | **Kaldırılacak / tersine çevrilecek** — Apple her zaman (availability’ye göre) |
| `lib/features/auth/oauth_sign_in.dart` | Google clientId iOS vs Android; Apple yalnız iOS/macOS throw | Android Apple: Services ID + redirect akışı |
| `lib/core/config/oauth_config.dart` | `OauthLocal.googleAndroidClientId = ''` | Doldurulacak |
| `lib/core/push/push_service.dart` | Android `Permission.notification`; iOS APNs wait | Kopya: “GoogleService-Info.plist” → platforma göre |
| `lib/features/billing/iap_service.dart` | apple JWS vs google purchaseToken | Hazır; backend gate |
| `lib/features/billing/paywall_screen.dart` | Manage URL App Store vs Play | OK |

### 2.2 Native / console

| Öğe | Yol / not |
|-----|-----------|
| `applicationId` | `android/app/build.gradle.kts` → `com.lotlot.lotlotnet_mobile` |
| Release signing | `signingConfig = debug` — **A0 blocker** |
| Manifest | INTERNET + POST_NOTIFICATIONS + `lotlot` scheme — OK iskelet |
| `google-services.json` | **Yok** (plugin conditional) |
| iOS `GoogleService-Info.plist` | Lokal (gitignore) — dokunma |
| Keystore / `key.properties` | **Yok** |

### 2.3 Zaten ortak (Android için yeniden yazma yok)

Splash, session, e-posta auth, Turnstile, watchlist, browse, hisse, soft gate, AI, wizard, account prefs, inbox/badge, socket, `deep_link_router`, API client, tema/marka, billing controller (google path hazır).

---

## 3. Gap listesi (öncelikli)

### P0 — Ship / E2E blocker

| ID | Gap | iOS risk |
|----|-----|----------|
| G1 | Play Console uygulama + internal testing track yok | Yok |
| G2 | Release upload keystore yok (debug imza) | Yok |
| G3 | Firebase Android app + `google-services.json` yok → FCM/Google native kırık | Düşük (optional plugin) |
| G4 | Google Cloud **Android** OAuth client + SHA-1/256; `OauthLocal.googleAndroidClientId`; backend `GOOGLE_MOBILE_CLIENT_IDS` | Orta — listeye ekle, iOS ID’yi silme |
| G5 | **Apple Sign-In Android** (UI + `sign_in_with_apple` Android config + Services ID redirect) | Orta — iOS `appleIdentity` dalını koru |
| G6 | Play Billing ürünleri + backend SA + `platforms.google_play=true` | Düşük (flag ayrı) |

### P1 — Parity / polish

| ID | Gap |
|----|-----|
| G7 | Push status metni iOS plist adını hardcode ediyor |
| G8 | `tool/android_push_bootstrap.sh` yok |
| G9 | F4 Android smoke checklist (§0) işaretsiz |
| G10 | Notification channel (Android 8+) bilinçli ayar |
| G11 | Play Data safety formu |
| G12 | HTTPS App Links + `assetlinks.json` (iOS aasa ile birlikte — ortak web işi) |

### Bilinçli non-gap

- APNs wait yalnız iOS.  
- Bundle ID ≠ applicationId.  
- Manage-subscription URL platforma göre.

---

## 4. Faz planı (A0–A5)

iOS F0–F7’ye paralel takip. Her faz: **acceptance** + **iOS regression notu**.

### A0 — Kimlik & iskelet

- **Amaç:** Play’e yüklenebilir imzalı AAB; uygulama kimliği sabit.  
- **İşler:**
  - [ ] Play Console’da uygulama (`com.lotlot.lotlotnet_mobile`)
  - [ ] Upload keystore + `key.properties` (repoya secret yok; CI/local only)
  - [ ] `build.gradle.kts` release signing (debug imzayı kaldır)
  - [ ] `flutter build appbundle --release` yeşil
  - [ ] Internal testing track’e boş/iskelet yükleme (opsiyonel smoke)
- **iOS:** dokunulmaz.  
- **Skills:** `android-fullstack-developer`, `project-manager`.  
- **Dışı:** Billing, OAuth doldurma (sonraki faz).

### A1 — Auth parity (Google + Apple + e-posta)

- **Amaç:** Android giriş ekranı iOS ile aynı üç kanal.  
- **Google:**
  - [ ] Cloud Console Android OAuth client (package + SHA)
  - [ ] `OauthLocal.googleAndroidClientId` / dart-define
  - [ ] Backend `GOOGLE_MOBILE_CLIENT_IDS` güncelle (iOS ID kalsın)
  - [ ] Cihaz E2E: Google → `/api/auth/google-mobile` → `/me`
- **Apple (ürün zorunlu):**
  - [ ] Apple Developer: Services ID + return URL (Android `sign_in_with_apple` dokümantasyonu)
  - [ ] `OauthSignIn.appleIdentity`: Android path (throw kaldırma; iOS path aynen)
  - [ ] `AuthScreen`: `showApple = !Platform.isAndroid` kaldır; `SignInWithApple.isAvailable()` veya her zaman göster + hata UX
  - [ ] Backend: mevcut `apple-mobile` + `APPLE_CLIENT_ID` / Services ID aud — web ekibi ile doğrula (Android token `aud` Services ID olur)
  - [ ] E2E: Apple → aynı kullanıcı iOS’ta da tanınır (hesap birliği)
- **E-posta:**
  - [ ] Register / login / Turnstile / verify handoff Android smoke
- **iOS regression:** Google+Apple login TF’de bir kez smoke.  
- **Skills:** `cybersecurity-expert`, `ios-fullstack-developer` (Apple Services ID), `android-fullstack-developer`, `test-engineer`, `ux-expert`.

### A2 — Push (FCM)

- **Amaç:** F5 push parity (+76 token ownership Android’de de).  
- **İşler:**
  - [ ] Firebase Console → Android app (`com.lotlot.lotlotnet_mobile`)
  - [ ] `android/app/google-services.json` (gitignore politikasına uy)
  - [ ] google-services plugin apply doğrula
  - [ ] Status string platforma göre
  - [ ] Premium + pushOn → register; logout → unregister; hesap değişince çift push yok
  - [ ] Foreground / background / killed + deep_link
- **iOS:** plist / APNs’e dokunma.  
- **Skills:** `android-fullstack-developer`, `cybersecurity-expert`.

### A3 — Play Billing (F6)

- **Amaç:** Pro/Premium satın alma + restore Android’de.  
- **İşler:**
  - [ ] Play Console abonelikler: aynı product ID’ler
  - [ ] License testers
  - [ ] Backend: Play SA JSON, `GOOGLE_PLAY_PACKAGE_NAME`, verify path, **sonra** `google_play=true`
  - [ ] E2E I1/I2 Android mirror (satın al / restore / hesap sil)
- **iOS:** StoreKit / `apple:true` değişmesin.  
- **Skills:** `android-fullstack-developer`, `project-manager`.

### A4 — Play teslim (F7 Android)

- [ ] Data safety / store listing / ekran görüntüleri  
- [ ] Closed → production (veya staged)  
- [ ] Handbook §0 F7 Android acceptance  
- [ ] Sonar QG OK → AAB ship ritüeli  

### A5 — Ortak (opsiyonel, her iki OS)

- [ ] HTTPS App Links + Apple Universal Links (`assetlinks` / `aasa`) — web BIST bağımlı  

---

## 5. Apple-on-Android (detay notu)

**Neden:** Kullanıcı hesabı iOS’ta Apple ile açılmış olabilir; Android’de yalnız Google/e-posta = hesap bölünmesi + “Apple ile gir yok” UX şikayeti.

**Nasıl (özet):**

1. Apple Services ID (web ile paylaşılabilir veya ayrı) + domain verify.  
2. Return URL → `sign_in_with_apple` Android intent.  
3. Dart: `SignInWithApple.getAppleIDCredential` Android’de de; platform guard’ı gevşet.  
4. Backend `aud`: Services ID — `APPLE_CLIENT_ID` / allowlist’e ekle (**iOS Bundle ID’yi çıkarma**).  
5. UI: Google + Apple yan yana (iOS layout parity); koyu temada `AppleLogoMark` mevcut.

**Risk:** Services ID yanlış aud → `invalid_oauth_token`. Mitigasyon: staging’de token claim dump (log’a yazmadan) + web ekibi doğrulama.

---

## 6. Bağımlılıklar (dış)

| Bağımlılık | Sahip | Faz |
|------------|-------|-----|
| Play Developer hesabı | İş / kullanıcı | A0 |
| Google Cloud Android OAuth + SHA | Mobil + Cloud | A1 |
| `GOOGLE_MOBILE_CLIENT_IDS` prod | Web/ops SSH | A1 |
| Apple Services ID + redirect | Apple Dev + ops | A1 |
| `APPLE_*` aud allowlist | Web/ops | A1 |
| Firebase Android app | Firebase proje | A2 |
| Play Billing SA + `google_play` | Web/ops | A3 |

---

## 7. Test matrisi (Android)

| ID | Senaryo | Faz |
|----|---------|-----|
| TA1 | Cold start → splash → login | A0+ |
| TA2 | Google Sign-In → me Premium/Free | A1 |
| TA3 | Apple Sign-In → me; iOS’ta aynı e-posta/hesap | A1 |
| TA4 | E-posta + Turnstile register/login | A1 |
| TA5 | Push izin → register → test FCM → badge/inbox | A2 |
| TA6 | Logout → token düşer; ikinci hesap push karışmaz | A2 |
| TA7 | Paywall satın al / restore / manage Play URL | A3 |
| TA8 | `lotlot://symbol/THYAO` | A0+ |
| TR-iOS | Her A1/A2/A3 sonrası iOS Google+Apple+push smoke | Hep |

---

## 8. İlerleme kaydı

| Tarih | Not |
|-------|-----|
| 2026-08-07 | İlk envanter; A0–A5 plan; Apple-on-Android ürün kararı; iOS Review beklemede |

### Acceptance özeti

- [ ] A0  
- [ ] A1 (Google + **Apple** + e-posta)  
- [ ] A2  
- [ ] A3  
- [ ] A4  

---

## 9. Hızlı referans

| | Değer |
|--|--------|
| Android applicationId | `com.lotlot.lotlotnet_mobile` |
| iOS Bundle ID | `com.lotlot.lotlotnetMobile` |
| Firebase proje | `lotlotnet-8c348` |
| API | `https://lotlot.net` |
| Son iOS kod | `1.0.0+76` / tag `v69` |
| Sonar | `ersinarikan_bistmobile` |

---

## 10. Sonraki 3 iş (önerilen kickoff)

1. **A0:** Play app + keystore + release AAB.  
2. **A1 Google:** Android OAuth client + SHA + `OauthLocal` + backend allowlist.  
3. **A1 Apple:** Services ID / redirect tasarımı + `AuthScreen`/`OauthSignIn` planlı patch (iOS regression checklist ile).
