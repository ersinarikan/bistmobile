# Android Full Stack — Referans

## A. Proje yapısı (Flutter)

- `android/app/src/main/AndroidManifest.xml` — ana izinler + activity
- `debug` / `profile` — ek izinler; **release’i unutma**
- `build.gradle.kts` — applicationId, minSdk, targetSdk, signing
- Adaptive icon: `mipmap-anydpi-v26`, foreground/background
- Splash: `LaunchTheme` / `launch_background` marka rengi

## B. İzin matrisi (kontrol listesi)

- [ ] INTERNET (release)
- [ ] POST_NOTIFICATIONS (API 33+) gerektiğinde runtime
- [ ] Billing / FCM için ek library manifest merge
- [ ] Exact alarm / foreground service — gerçekten gerekli mi?

## C. App Links

- `intent-filter` + `autoVerify`
- Digital Asset Links dosyası web’de (`/.well-known/assetlinks.json`)
- Path’ler hisse / auth deep link ile uyumlu

## D. Play Billing (IAP)

1. Play Console ürünleri (subscription) = sunucu `iap/config` ile hizalı
2. Purchase → native purchase token → backend verify
3. Acknowledge / consume zamanında
4. License tester / sandbox E2E
5. Restore purchases akışı

## E. FCM

- `google-services.json` (secret politikasına göre; commit kurallarına uy)
- Token register / unregister logout’ta
- Data vs notification payload; arka plan handler
- Kanallar (Android 8+ notification channel)

## F. Güvenlik

- `network_security_config`: cleartext disabled
- Certificate pinning yalnız bilinçli + ops planı ile
- WebView varsa JS bridge minimal
- Backup / debuggable release kapalı
- Secure storage: EncryptedSharedPreferences / flutter_secure_storage aOptions

## G. Performans & kalite

- R8/ProGuard kuralları plugin’ler için
- ANR: main thread I/O yok
- Startup: Application/Flutter init maliyeti
- Play pre-launch report / internal testing track

## H. API seviyeleri

- minSdk / targetSdk proje gradle’dan oku; yeni API’de davranış farkını not et
- Test: en az bir düşük API + güncel Pixel image

## I. Flutter köprüsü

- Platform channel isimleri versioned / dokümante
- Hata kodları Dart’a anlamlı map
- iOS kanalı ile semantik parity (mümkün olduğunca)
