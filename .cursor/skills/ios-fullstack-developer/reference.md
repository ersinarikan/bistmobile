# iOS Full Stack — Referans

## A. Flutter iOS yapısı

- `ios/Runner/Info.plist` — display name, orientations, ATS
- `AppDelegate.swift` / `SceneDelegate.swift`
- `Assets.xcassets/AppIcon` — flutter_launcher_icons çıktısı
- `LaunchScreen.storyboard` — marka arka plan rengi
- Signing: Team ID, Bundle ID, automatic vs manual

## B. Capabilities checklist

- [ ] Push Notifications (APNs)
- [ ] Sign in with Apple (gerekince)
- [ ] In-App Purchase
- [ ] Associated Domains (`applinks:lotlot.net`)
- [ ] Background Modes — yalnız gerekirse (remote-notification)

## C. Universal Links

- `apple-app-site-association` web’de (content-type, https)
- Path patterns hisse / auth ile uyumlu
- Flutter tarafında link handling + cold/warm start

## D. StoreKit 2 (IAP)

1. Product IDs ↔ backend `iap/config`
2. `Transaction.updates` dinle; interrupt/renewal
3. JWS / receipt → sunucu verify
4. Restore; family sharing politikası bilinçli
5. Sandbox / StoreKit Configuration file ile E2E

## E. APNs / push

- `.p8` key sunucuda (mobil repoya koyma)
- Permission UX; provisional dikkatli
- Token refresh → `device/register`
- Logout → unregister

## F. Gizlilik & ATS

- App Privacy “nutrition labels” doğru (tokens, analytics, crash)
- Privacy Manifest (`PrivacyInfo.xcprivacy`) required reason API’ler
- ATS: keyfi exception yok; gerekçeli exception dokümante
- ATT yalnız tracking varsa

## G. Sign in with Apple

- Native token `aud` = Bundle ID
- Backend `APPLE_CLIENT_ID` = Bundle ID (web Services ID karıştırma)
- Hide My Email akışı

## H. App Store Review hazırlığı

- Demo hesap; edge case ekran görüntüleri
- IAP restore görünür
- Hesap silme yolu
- “Yatırım tavsiyesi değildir” mağaza metninde abartı yok
- Export compliance / encryption soruları

## I. Kalite

- Instruments: leaks, hangs
- Ana thread I/O yok
- Bitcode/deprecated API temizliği
- TestFlight external notes
