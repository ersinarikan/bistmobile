# Test Mühendisi — Referans

## A. Web ↔ mobil parity prosedürü

Her test edilen özellik için doldur:

| Adım | Soru | Kanıt |
|------|------|--------|
| 1 Web | Hangi route/template/JS? | path + satır / curl |
| 2 API | HTTP + `error` + body alanları? | guide § + canlı yanıt |
| 3 Mobil | Hangi ekran/controller map ediyor? | `lib/...` |
| 4 Matris | Happy + hatalar + sıralama? | tablo B |
| 5 Sapma | Web’de X, mobil Y mi? | ekran / log (token yok) |
| 6 Fix | Mobil geliştirici ticket? | evet/hayır + doğrulama |

## B. Senaryo matrisi şablonları

### B1 — E-posta kayıt (prod Turnstile ALWAYS)

| # | Senaryo | Beklenen |
|---|---------|----------|
| R1 | Yeni e-posta, token’sız POST | `400 invalid_turnstile` → köprü aç |
| R2 | Köprü iptal / token boş | Form kalır; net iptal; takılı loading yok |
| R3 | Yeni e-posta + geçerli token | `201 pending_verification` → doğrulama ekranı; JWT yok |
| R4 | **Kayıtlı e-posta** + token | `409 email_already_registered` → Türkçe mesaj + Giriş CTA |
| R5 | Token sonrası tekrar `invalid_turnstile` | Kullanıcıya “doğrulama yenilenmeli”; sessiz no-op **yasak** |
| R6 | Zayıf şifre / eksik alan | Client validation; gereksiz Turnstile yok |
| R7 | Rate limit | `rate_limited` + retry_after anlaşılır |

### B2 — E-posta login

| # | Senaryo | Beklenen |
|---|---------|----------|
| L1 | Doğru kimlik | Shell; `/me` tier |
| L2 | Yanlış şifre | `invalid_credentials` |
| L3 | Captcha gerekli | `captcha_required` / Turnstile → retry |
| L4 | Doğrulanmamış e-posta | `email_not_verified` → pending ekran |
| L5 | Logout | Guest shell (F2); token wipe |

### B3 — Guest browse + watchlist (F2)

| # | Senaryo | Beklenen |
|---|---------|----------|
| G1 | Cold start tokensız | Keşfet; Login dayatması yok |
| G2 | Search `q` ≥ 2 | `GET /api/stocks/search` auth:false |
| G3 | BIST 30/100 | `index-screener` auth:false |
| G4 | Guest İzleme | Giriş/Kayıt CTA; watchlist çağrısı yok |
| G5 | Auth add/delete | Kota sunucudan; 403 mesajları |
| G6 | Predictions | `display_state`/`label` render; client hesap yok |

### B4 — OAuth

| # | Senaryo | Beklenen |
|---|---------|----------|
| O1 | Google idToken | `google-mobile` → JWT |
| O2 | Apple identityToken | `apple-mobile`; aud Bundle ID |
| O3 | İptal / SDK hata | Anlaşılır mesaj; crash yok |

## C. Prod smoke (BIST PREDEPLOY §3 uyarlama)

Secret/token sohbete yazma. Placeholder:

```bash
# Register (beklenen: turnstile veya 201/409)
curl -sS -X POST https://lotlot.net/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"...","password":"...","first_name":"T","last_name":"T"}'

# Login → me → watchlist → logout (PREDEPLOY §3.1–3.4)
```

Mobil UI smoke aynı sırayı cihazdan tekrarlar.

## D. Severity

| Seviye | Örnek |
|--------|--------|
| Critical | Auth kırık; token sızıntısı; guest’te Bearer/401 fırtınası |
| High | Kayıt/login hata yolu sessiz; yanlış `error` map; veri kaybı |
| Medium | Parity sapması (web toast var, mobil yok); kota metni eksik |
| Low | Kopya / spacing |

## E. Bug raporu (mobil geliştiriciye)

```markdown
### Bug
- Özet:
- Ortam: iOS/Android + build/tag
- Web referansı: (dosya + beklenen)
- Adımlar:
- Beklenen:
- Görülen:
- API kanıtı: status + error (token yok)
- Önerilen fix: (map / UI / retry)
```

## F. Regresyon minimum (her auth/watchlist PR)

- [ ] R1–R5 kayıt matrisi
- [ ] L1–L5 login/logout
- [ ] G1–G6 guest/watchlist
- [ ] analyze + ilgili ekranlar elle
