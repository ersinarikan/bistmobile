# Proje Yöneticisi — Referans

## A. Faz kapıları (LOTLOT)

| Faz | Giriş kriteri | Çıkış / acceptance |
|-----|---------------|-------------------|
| 1 Auth | API login/me/refresh canlı | Splash bootstrap, login, logout, token secure |
| 2 Watchlist/detay | Auth yeşil; endpoint’ler dokümante | Liste + detay; hata/403 UX |
| 3 Social auth | Console client ID’ler | Google/Apple native; backend aud uyumu |
| 4 IAP | Store ürünleri + `iap/config` | Purchase→verify→entitlement; restore |

## B. Bağımlılık haritası

```
BIST API / auth ──► Mobil session
BIST iap verify ──► StoreKit / Play Billing
FCM/APNs keys ──► Push
assetlinks / aasa ──► Deep links
Play/App Store hesap ──► Release
Sonar + analyze ──► Tag/push
```

## C. Risk kaydı şablonu

| ID | Risk | Olasılık | Etki | Mitigasyon | Sahip |
|----|------|----------|------|------------|-------|
| R1 | Release’te INTERNET eksik | O | Y | Manifest checklist | Android |
| R2 | Apple aud mismatch | O | Y | Bundle ID = APPLE_CLIENT_ID | iOS/Backend |
| R3 | CDN icon cache stale | D | D | versioned URL | Mobil |

## D. Toplantı / güncelleme ritmi (öneri)

- Günlük (kısa): dün / bugün / engel
- Haftalık: faz ilerleme + risk top 3
- Release öncesi: go/no-go (kalite, store, API smoke)

## E. Go / No-Go checklist

- [ ] `flutter analyze` temiz
- [ ] Sonar quality gate
- [ ] iOS + Android smoke (login, me, logout)
- [ ] Store metadata / gizlilik formları
- [ ] Backend smoke (`mobile_predeploy_smoke` varsa)
- [ ] Rollback planı (önceki tag)

## F. Kapsam değişikliği protokolü

1. İstek yazılır (ne / neden).
2. Etki: süre, risk, faz kayması.
3. Onay / ertele / reddet.
4. Handbook + roadmap güncellenir.

## G. Öncelik skoru (basit)

`Skor = İş değeri (1–5) + Risk azaltma (1–5) - Efor (1–5) - Bağımlılık gecikmesi (0–3)`
