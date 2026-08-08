# LOTLOT.NET — Android Handbook

> Android ilerleme, gap ve iOS-güvenli plan. **iOS Review beklerken** bu dosya takip kaynağıdır.  
> Ana ürün roadmap: [`AGENT_HANDBOOK.md`](AGENT_HANDBOOK.md) §0.  
> Son güncelleme: 2026-08-08 (A3 Play Billing §0e / §7.3)

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

Cursor kuralı: `.cursor/rules/android-ios-parity.mdc` (`alwaysApply`).

1. `OauthSignIn` Google: iOS → `googleIosClientId` + `googleServerClientId` (`544107…`); Android → `googleAndroidClientId` + `googleAndroidServerClientId` (`202330…`). Karıştırma.  
2. Apple: iOS native (`webAuthenticationOptions` null); Android Services ID + redirect.  
3. Backend `GOOGLE_MOBILE_CLIENT_IDS` / Apple aud: **ekle, iOS ID silme**.  
4. Firebase: `google-services.json` yokken iOS build kırılmamalı (optional plugin).  
5. IAP ürün ID’leri paylaşılan; `google_play=true` yalnız Play + SA hazırsa.  
6. Deep link / `app_links`: `lotlot://` sözleşmesini koru.  
7. Her Android diff: **“iOS Google/Apple/push/IAP yolunu değiştirir mi?”**

---

## 1. Durum özeti (2026-08-07)

| Katman | iOS (TF / Review) | Android |
|--------|-------------------|---------|
| Flutter ürün yüzeyi | Tam (F0–F6) | Kod büyük ölçüde **ortak** |
| Google Sign-In | E2E OK | Tablet E2E OK (Firebase Web `serverClientId` + Android client) |
| Apple Sign-In | E2E OK | Android UI + Services ID redirect E2E OK |
| E-posta + Turnstile | OK | Ortak kod — cihaz smoke açık |
| FCM push | OK (+76 token ownership) | JSON + channel/icon + bootstrap; **§7.2 tablet E2E açık** |
| IAP | StoreKit Sandbox PASS | Client hazır; **`google_play=false`** (Play SA yok); ürün/license §0e |
| Release imza | ASC / Team | **debug signing** (Play’e yüklenemez) |
| Deep link `lotlot://` | OK | Manifest’te var |
| HTTPS App Links / aasa | İkisi de dışı (web) | Aynı |

**Blokleyenler (Android ship):** ~~Play hesabı~~ · ~~keystore~~ · ~~Firebase Android~~ · ~~Google OAuth~~ · ~~Apple-on-Android~~ · **Play Billing SA + abonelik ürünleri (A3)** · A4 listing.

---

## 0b. Sıfırdan hesap yönlendirmesi (senin durumun)

### Ne zaten var? (yeniden açma)

Aynı Google hesabında büyük ihtimalle şunlar **zaten** duruyor — **Play Console değil**:

| Servis | Ne işe yarar | Bizim kullanım |
|--------|----------------|----------------|
| **Firebase** `lotlotnet-8c348` | FCM, Analytics | iOS + Android app OK; lokal `google-services.json` (gitignore) |
| **Google Cloud** (aynı proje numarası `544107298661…`) | OAuth client’lar | iOS + Web Google client var; **Android OAuth client eksik** |
| Search Console / Analytics vb. | SEO / web | Android app için zorunlu değil |

Bunları silme / yeni proje açma. Android işi **aynı Firebase + aynı Cloud projesine** eklenir.

### Ne yok? (ayrı ürün — zorunlu)

| Servis | Ne işe yarar | Not |
|--------|----------------|-----|
| **Google Play Console** | Uygulamayı mağazaya koyma + abonelik (Billing) | Firebase ≠ Play. **Ayrı kayıt**, bir kerelik **$25 USD** |
| Play’de “LOTLOT.NET” uygulaması | AAB yükleme, internal test, ürünler | Console açılınca oluşturulur |

```text
Firebase / Cloud  →  push + Google Sign-In (ücretsiz, mevcut proje)
Play Console      →  dağıtım + ücretli abonelik (ayrı, $25)
```

Apple App Store Connect nasıl Firebase’den ayrıysa, Play de Firebase’den ayrıdır.

### Senin yapman gereken sıra (bugün / bu hafta)

Checkbox’ları handbook’ta işaretleyeceğiz; biten adımı sohbete yaz.

#### Adım 1 — Play Developer hesabı aç (sen)

1. Bilgisayarda (tercihen): [https://play.google.com/console/signup](https://play.google.com/console/signup)  
2. **Firebase’i açtığın aynı Google hesabı** ile giriş yap (önerilir — fatura/ekip tek yerde).  
3. Geliştirici profili: ülke, iletişim, geliştirici adı (ör. **Lotlot** / **lotlot.net**).  
4. **$25** tek seferlik ücreti öde.  
5. Google bazen kimlik / D-U-N-S / doğrulama isteyebilir (kişisel vs kurumsal). Gelen e-postayı tamamla; **onay 48 saat–birkaç gün** sürebilir.  
6. Bittiğinde: Play Console ana sayfada “Uygulama oluştur” görebilmelisin.

**Bana yaz:** “Play hesabı açıldı / onay bekliyor / takıldım: …”

#### Adım 2 — Play’de uygulama oluştur (sen; hesap onayından sonra)

1. Play Console → **Uygulama oluştur**  
2. Uygulama adı: **LOTLOT.NET**  
3. Varsayılan dil: Türkçe  
4. Uygulama / oyun: **Uygulama**  
5. Ücretsiz / ücretli: **Ücretsiz** (içinde abonelik olacak — bu normal)  
6. Beyanlar: politika + geliştirici program politikası onayları  
7. Paket adı (applicationId) **sonra** AAB ile sabitlenir; hedefimiz: `com.lotlot.lotlotnet_mobile`  
   - İlk yüklemede bu ID **değişmez** — yanlış yazma.

**Henüz store listing / production zorunlu değil** — Internal testing yeter.

**Bana yaz:** “Play’de uygulama oluşturuldu.”

#### Adım 3 — (Paralel, Play onayı beklerken) Firebase’e Android app (sen + ben)

Play olmadan da yapılabilir:

1. [Firebase Console](https://console.firebase.google.com/) → proje **lotlotnet-8c348**  
2. **Add app → Android**  
3. Package name: `com.lotlot.lotlotnet_mobile` (tıpatıp)  
4. App nickname: LOTLOT.NET Android  
5. `google-services.json` indir  
6. Dosyayı bana ver / `android/app/` altına koy (gitignore’da — commit etme)  
7. Ben: Gradle plugin + smoke.

**Debug SHA-1** (Google Sign-In için sonra lazım): Mac’te:

```bash
keytool -list -v -alias androiddebugkey \
  -keystore ~/.android/debug.keystore -storepass android -keypass android
```

SHA-1 / SHA-256’yı Cloud OAuth Android client’a ekleyeceğiz (Adım 5).

**Bana yaz:** “google-services.json hazır” + SHA-1 yapıştır (public; secret değil).

#### Adım 4 — Upload keystore (birlikte; Play hesabı olunca)

- Mac’te keystore üretiriz (`lotlot-upload.jks`) — **şifreyi sen sakla**, chat’e yazma.  
- `key.properties` lokal (gitignore).  
- Release AAB imzası debug’dan çıkar.  
- Play App Signing’e ilk AAB yüklemede kayıt.

#### Adım 5 — Google Android OAuth (mevcut Cloud proje)

1. [Google Cloud Console](https://console.cloud.google.com/) → **aynı** proje (`544107298661` / lotlot Firebase projesi)  
2. APIs & Services → Credentials → **Create OAuth client ID** → **Android**  
3. Package: `com.lotlot.lotlotnet_mobile`  
4. SHA-1: debug (+ sonra release upload key)  
5. Client ID’yi `OauthLocal.googleAndroidClientId` için bana ver.  
6. Ops: prod `GOOGLE_MOBILE_CLIENT_IDS` listesine ekle (iOS ID’yi silme).

#### Adım 6 — Kod fazları (ben)

Play + JSON + OAuth geldikçe handbook A0 → A1 → A2…  
Apple-on-Android ayrı (Apple Developer — sende zaten var).

### Sık karışıklıklar

| Sanı | Gerçek |
|------|--------|
| “Firebase var = Play var” | Hayır |
| “Yeni Google hesabı açayım” | Gerekmez; **aynı hesap** + aynı Firebase proje |
| “Önce Billing” | Hayır; önce **Play hesabı + uygulama + imza** |
| “iOS Bundle ID’yi Android’e kopyala” | Hayır; Android ID: `com.lotlot.lotlotnet_mobile` |

### Şimdi senden tek net aksiyon

1. [Play Console signup](https://play.google.com/console/signup) → $25 → onay sürecini başlat.  
2. Onay beklerken (istersen): Firebase’e Android app + `google-services.json` + debug SHA-1.

Ben kod/imza/OAuth adımlarında yanında olacağım; sen konsol hesaplarını açmadan A0 tamamlanmaz.

---

## 0c. Bekleme penceresi — şimdi yapılabilir / yapılamaz

Play’de **kimlik doğrulanıyor** + **gerçek Android cihaz** şartı varken:

### Yapılamaz (Play kilidi)

- Mağazaya uygulama yayınlama / production  
- (Çoğu hesapta) AAB ile “ilk uygulama oluştur + yükle” tam akışı doğrulama bitene kadar kısıtlı olabilir  
- Play Billing ürünlerini canlıya alma  

### Yapılabilir (beklemeden — önerilen sıra)

| # | Kim | İş | Sonuç |
|---|-----|-----|--------|
| 1 | Sen | Firebase → **lotlotnet-8c348** → Add Android app → paket `com.lotlot.lotlotnet_mobile` → `google-services.json` | FCM iskeleti |
| 2 | Sen / birlikte | Debug SHA-1 üret, sohbete yapıştır | Google OAuth Android client |
| 3 | Birlikte | Cloud’da Android OAuth client + `OauthLocal` doldur | Google giriş kod yolu |
| 4 | Birlikte | Mac’te Android emülatör (API 34 + Google Play image) | Geliştirme testi |
| 5 | Birlikte | Upload keystore üret (şifre sende) + release gradle | İmza hazır; Play yükleme sonra |
| 6 | Birlikte | Kod: Firebase eksik metinleri Android’e göre; (isteğe bağlı) Apple-on-Android tasarım/patch | A1 hazırlık |
| 7 | Sen | Ucuz/ödünç **gerçek** Android + Play Console uygulaması | Hesap doğrulama kapanır |

**Emülatör:** kod ve FCM/Google Sign-In denemesi için evet.  
**Play “cihaz doğrulama”:** hayır — gerçek telefon şart (ekrandaki metin bunu söylüyor).

---

## 0e. A3 Play Billing — senin Console + SA adımları

Flutter client hazır (`purchaseToken` / `platform:google`). Prod config (2026-08-08 smoke): `apple:true` · `google_play:true` · `verify_ready:true`. Play API list: `lotlot_pro_monthly_v2` + `lotlot_premium_monthly` (`monthly:ACTIVE`). Flag, SA + paket adı set edilince **otomatik** `true` olur (`apple:true` değişmez).

### Kopyala-yapıştır ürün ID’leri

```
lotlot_pro_monthly_v2
```

```
lotlot_premium_monthly
```

Paket: `com.lotlot.lotlotnet_mobile`

### Adım A — Play Console abonelikler

1. [Play Console](https://play.google.com/console) → **LOTLOT.NET**
2. **Google Play ile para kazanın** → **Abonelikler** (veya Monetize → Products → Subscriptions)
3. **Abonelik oluştur** ×2:
   - Product ID: `lotlot_pro_monthly_v2` · ad: LOTLOT Pro (aylık)
   - Product ID: `lotlot_premium_monthly` · ad: LOTLOT Premium (aylık)
4. Her biri için **base plan** (aylık) + **TRY** fiyat
5. Aktifleştir / yayına al (dahili test için yeterli durum)

### Adım B — License testers

1. Play Console → **Ayarlar** → **License testing** (veya Setup → License testers)
2. E-posta ekle: `ersin@lotlot.net` (tablette Play’e giriş aynı hesap)
3. Uygulamayı **dahili test** linkinden yükle (license tester + internal track)

### Adım C — Play Developer API service account

1. [Google Cloud](https://console.cloud.google.com/) → proje **`lotlotnet-8c348`**
2. IAM → **Service accounts** → Create → ad: `lotlot-play-billing`
3. Key → JSON indir → örn. `~/Downloads/lotlot-play-billing.json` (**commit yok**)
4. [Play Console](https://play.google.com/console) → **Kullanıcılar ve izinler** → **Yeni kullanıcılar davet et** / service account e-postasını ekle
5. İzin: **View financial data**, **Manage orders and subscriptions** (veya “View app information and download bulk reports” + monetization — guide §9.5)
6. Mac’te: `tool/android_play_billing_bootstrap.sh install` (JSON’u sunucuya koyar, servisi restart eder)
7. Kontrol: `curl -s https://lotlot.net/api/billing/iap/config | jq .iap.platforms` → `"google_play": true`

**iOS:** StoreKit / `apple:true` / ASC ürünlerine dokunma.

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
| Release signing | `key.properties` + upload keystore → release; yoksa debug fallback |
| Manifest | INTERNET + POST_NOTIFICATIONS + `lotlot` + FCM channel/icon meta-data |
| `google-services.json` | Lokal (gitignore); plugin conditional apply |
| iOS `GoogleService-Info.plist` | Lokal (gitignore) — dokunma |
| Keystore / `key.properties` | Lokal (`~/.lotlot/` + `android/key.properties`, gitignore) |

### 2.3 Zaten ortak (Android için yeniden yazma yok)

Splash, session, e-posta auth, Turnstile, watchlist, browse, hisse, soft gate, AI, wizard, account prefs, inbox/badge, socket, `deep_link_router`, API client, tema/marka, billing controller (google path hazır).

---

## 3. Gap listesi (öncelikli)

### P0 — Ship / E2E blocker

| ID | Gap | iOS risk |
|----|-----|----------|
| G1 | ~~Play Console + internal testing~~ **DONE** (dahili test v80+) | Yok |
| G2 | ~~Release upload keystore~~ **DONE** | Yok |
| G3 | ~~Firebase Android + `google-services.json`~~ **DONE** (gitignore) | Düşük |
| G4 | ~~Android OAuth + Play SHA clients~~ **DONE** (debug/Play/prev/PQ) | Orta |
| G5 | ~~Apple Sign-In Android~~ **DONE** | Orta |
| G6 | ~~Play Billing ürünleri + SA + `google_play=true`~~ **DONE** (API smoke OK) — tablet E2E **§7.3** açık | Düşük |

### P1 — Parity / polish

| ID | Gap |
|----|-----|
| G7 | ~~Push status plist hardcode~~ **DONE** (A2: platforma göre json/plist) |
| G8 | ~~`android_push_bootstrap.sh`~~ **DONE** (A2) |
| G9 | F4 Android smoke checklist (§0) işaretsiz |
| G10 | ~~Notification channel + icon~~ **DONE** (A2) |
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
  - [x] Play Console’da uygulama (`com.lotlot.lotlotnet_mobile`)
  - [x] Upload keystore + `key.properties` (repoya secret yok; `~/.lotlot/`)
  - [x] `build.gradle.kts` release signing (key.properties varsa release; yoksa debug fallback)
  - [ ] `flutter build appbundle --release` yeşil
  - [ ] Internal testing track’e AAB yükleme
- **iOS:** dokunulmaz.  
- **Skills:** `android-fullstack-developer`, `project-manager`.  
- **Dışı:** Billing, OAuth doldurma (sonraki faz).

### A1 — Auth parity (Google + Apple + e-posta)

- **Amaç:** Android giriş ekranı iOS ile aynı üç kanal.  
- **Google:**
  - [x] Cloud Console Android OAuth client (package + SHA)
  - [x] `OauthLocal.googleAndroidClientId` + Firebase Web `googleAndroidServerClientId`
  - [x] Backend `GOOGLE_MOBILE_CLIENT_IDS` güncelle (iOS ID kalsın)
  - [x] Cihaz E2E: Google → `/api/auth/google-mobile` → `/me` (SM-X230; USB + Play v79)
  - [x] Play App Signing: klasik + prev + PQ SHA → Cloud Android OAuth clients + Firebase fingerprints
  - [x] Android `GoogleSignIn`: `clientId=null` (Play SHA client seçimi); yalnız Web `serverClientId`
- **Apple (ürün zorunlu):**
  - [x] Kod: Android UI + `WebAuthenticationOptions` + Manifest callback (2026-08-07)
  - [x] Backend: `GET/POST /callbacks/sign_in_with_apple` → `intent://signinwithapple`
  - [x] Apple Developer: Services ID Return URL = `https://lotlot.net/callbacks/sign_in_with_apple`
  - [x] E2E: Apple Android girişi OK (hesap birliği iOS smoke opsiyonel)
- **E-posta:**
  - [ ] Register / login / Turnstile / verify handoff Android smoke (v80: Turnstile false-red düzeltmesi)
- **iOS regression:** Google+Apple login TF’de bir kez smoke.  
- **Skills:** `cybersecurity-expert`, `ios-fullstack-developer` (Apple Services ID), `android-fullstack-developer`, `test-engineer`, `ux-expert`.

### A2 — Push (FCM)

- **Amaç:** F5 push parity (+76 token ownership Android’de de).  
- **İşler:**
  - [x] Firebase Console → Android app (`com.lotlot.lotlotnet_mobile`)
  - [x] `android/app/google-services.json` (gitignore politikasına uy)
  - [x] google-services plugin apply doğrula (JSON varken)
  - [x] Status string platforma göre (G7)
  - [x] Default FCM channel + `ic_stat_lotlot` (G10)
  - [x] `tool/android_push_bootstrap.sh` (G8)
  - [ ] Premium + pushOn → register; logout → unregister; hesap değişince çift push yok (**§7.2 TA5/TA6**)
  - [ ] Foreground / background / killed + deep_link (**§7.2**)
- **iOS:** plist / APNs’e dokunma.  
- **Skills:** `android-fullstack-developer`, `cybersecurity-expert`.

### A3 — Play Billing (F6)

- **Amaç:** Pro/Premium satın alma + restore Android’de.  
- **İşler:**
  - [x] Play Console abonelikler: `lotlot_pro_monthly_v2` + `lotlot_premium_monthly` (**§0e Adım A**)
  - [x] License testers: `ersin@lotlot.net` (**§0e Adım B**)
  - [x] Backend: Play SA JSON + `GOOGLE_PLAY_*` (**§0e Adım C** / bootstrap) → config `google_play:true` + API smoke OK
  - [ ] E2E I1/I2 Android mirror (**§7.3**) — tablet
- **iOS:** StoreKit / `apple:true` değişmesin.  
- **Skills:** `android-fullstack-developer`, `project-manager`.
- **Client:** Dart verify/restore path hazır — A3’te davranış değişikliği yok.

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

### 7.1 Fiziksel test listesi (Play dahili — sen işaretle)

**Build:** `1.0.0+85` · track: Dahili test · cihaz: tablet (SM-X230) · hesap: `ersin@lotlot.net`

| ID | Senaryo | Beklenen | Sen |
|----|---------|----------|-----|
| PT1 | Play’den **85** güncelle / yükle | Sürüm 85 | [ ] |
| PT2 | **Google** ile giriş (Play imzalı) | Hesap açılır; `[16] reauth` yok | [ ] |
| PT3 | **Apple** ile giriş | Hesap açılır (önceki gibi) | [ ] |
| PT4 | E-posta **kayıt** + Turnstile | Köprü açılır; kırmızı “yüklenemedi” **yanlış alarm olmamalı**; verify mail → login | [ ] |
| PT5 | E-posta **login** | Giriş OK; DNS/host lookup yoksa ağ kontrol | [ ] |
| PT6 | Chrome: `https://lotlot.net/mobile/turnstile` | Sayfa açılır (ağ smoke) | [ ] |
| PT7 | Logout → tekrar Google | Temiz giriş | [ ] |

**Sonraki faz (A2 — push):** PT listesi geçince §7.2.

### 7.2 A2 Push fiziksel test (Premium + pushOn)

**Önkoşul:** Premium hesap · Hesap → push açık · build A2 ship (channel/icon) · `ersin@lotlot.net`

| ID | Senaryo | Beklenen | Sen |
|----|---------|----------|-----|
| TA5a | Push aç → OS bildirim izni | `POST_NOTIFICATIONS` / izin diyaloğu | [ ] |
| TA5b | Register | Hesap status “Bildirim kaydı tamam” (veya eşdeğeri); `platform=android` | [ ] |
| TA5c | Uygulama ön planda test FCM | SnackBar; **inbox/badge yalnız dispatcher yolu** (API unread) | [ ] |
| TA5d | Arka plan / killed → bildirime dokun | `deep_link` → hisse detay | [ ] |
| TA6a | Logout | Token unregister; eski hesaba push gitmez | [ ] |
| TA6b | İkinci hesap login + push | Çift teslimat yok (ownership) | [ ] |
| TR-iOS | TF: Google + Apple + push bir kez | iOS regresyon yok | [ ] |

### 7.3 A3 Billing fiziksel test (license tester)

**Önkoşul:** §0e A+B+C tamam · config `google_play:true` · Play’den yüklü build · `ersin@lotlot.net` license tester

> **2026-08-08:** Tablet Pro→Premium **90s timeout** — Play ayrı subscription ürünleri için `ChangeSubscriptionParam` yoktu; `+84` / `GooglePlayPurchaseParam` + `ReplacementMode.withTimeProration` ile düzeldi. I1b-A’yı **84** üzerinde tekrarla.

| ID | Senaryo | Beklenen | Sen |
|----|---------|----------|-----|
| N1 | Free Hesap → Bildirim tercihleri | Switch yok; Plan CTA; push/e-posta açık görünmez | [ ] |
| TA7a | Flag kapalıyken paywall (SA öncesi) | Crash yok; satın alma kapalı / net neden | [ ] |
| TA7b | `google_play:true` sonrası paywall | Pro/Premium fiyatları görünür | [ ] |
| I1a-A | Pro satın al | verify → `/me` Pro | [x] (+83) |
| I1b-A | Premium upgrade | `/me` Premium | [ ] (**84** bekliyor) |
| I2-A | Restore | Tier geri | [ ] |
| TA7c | Aboneliği yönet | Play subscriptions URL | [ ] |
| TA7e | Başka hesaba ait makbuz | `receipt_owned_by_other_account` UX | [ ] |
| TR-iOS-A3 | iOS Sandbox buy veya restore bir kez | StoreKit bozulmadı | [ ] |

### 7.3b Bildirim prefs (N matrisi — 2026-08-08)

Backend deploy + Free cleanup (111 kullanıcı normalize) tamam. Cihazda doğrula:

| ID | Senaryo | Beklenen | Sen |
|----|---------|----------|-----|
| N1 | Free Hesap bildirimleri | Switch yok; Planları incele | [ ] |
| N2 | Pro: e-posta aç/kapa; push kilit | Soft gate Premium | [ ] |
| N3 | Premium: ikisi OK | FCM yalnız push ON | [ ] |
| N4 | Premium→Free | Flag kapalı; Free UI | [ ] |
| N5 | iOS + Android | Aynı davranış (shared lib) | [ ] |
| N6 | Web Hesabım | Free CTA / Pro e-posta / Premium ikisi | [ ] |

Sonra §7.3 I1a Pro satın alma.

### 7.4 Birikimli tablet notu (AAB en sonda)

AAB’yi her fazda yüklemek zorunda değilsin — **A2+A3 bitince tek Play yüklemesi** yeterli. O zamana kadar işaretle:

1. **§7.2** (push) — TA5/TA6 / TR-iOS  
2. **§7.3** (billing) — TA7 / I1 / I2 / TR-iOS-A3  
3. **§7.1** (auth smoke) — hâlâ açıksa PT2–PT7  

---

## 8. İlerleme kaydı

| Tarih | Not |
|-------|-----|
| 2026-08-07 | İlk envanter; A0–A5 plan; Apple-on-Android ürün kararı; iOS Review beklemede |
| 2026-08-07 | §0b: Firebase ≠ Play; sıfırdan Play Developer + paralel Firebase Android yönlendirmesi |
| 2026-08-07 | Play: kimlik doğrulama kuyrukta; cihaz doğrulaması “gerçek Android” şart; beklemede yapılabilir işler §0c |
| 2026-08-08 | Play Google Sign-In: App Signing klasik/prev/PQ SHA → Cloud OAuth; Android clientId=null; v80 Turnstile main-frame-only error; PT listesi §7.1 |
| 2026-08-08 | A2: FCM channel/icon, platform status strings, `android_push_bootstrap.sh`, §7.2 TA5/TA6 |
| 2026-08-08 | A3 plan: §0e Play Billing Console+SA rehberi; §7.3/§7.4 tablet notları; `android_play_billing_bootstrap.sh` (SA gelince) |
| 2026-08-08 | A3 ops: Play abonelikler ACTIVE + SA + Publisher API smoke; config `google_play:true`; ship **1.0.0+82** dahili |
| 2026-08-08 | Bildirim prefs tier parity: Free CTA / Pro e-posta / Premium push; backend PATCH gate + Free cleanup |

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
| Son Android AAB | `1.0.0+85` / tag `v77` (dahili; inbox/badge FCM parity) |
| Sonar | `ersinarikan_bistmobile` |

---

## 10. Sonraki 3 iş (önerilen kickoff)

1. **Sen:** Play dahili → **85** yükle (inbox/badge FCM parity + launcher badge).
2. **Sen:** Tablet **TA5d** deep link + ikon badge; **§7.2** kalanı.
3. **Sonra:** A4 store listing / production.
