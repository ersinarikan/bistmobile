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

**Prod kaynak (kayıt):** `/opt/bist-pattern/bist_pattern/blueprints/api_auth_routes.py` → `api_register`, `api_resend_verification`, `api_login`; koruma: `login_protection.py`.

## B. Senaryo matrisi şablonları

### B1 — E-posta kayıt (prod `REGISTER_TURNSTILE_ALWAYS=True`)

Sıra (sunucu): alan kontrolü → Turnstile → rate limit sayacı → existing user → create/reactivate → verification mail → `201`.

| # | Senaryo | API | Mobil beklenen |
|---|--------|-----|----------------|
| R1 | Token’sız POST (prod ALWAYS) | `400 invalid_turnstile` | Lazy köprü; kullanıcı hatası değil |
| R2 | Köprü iptal / boş token | — | Form; loading kapalı; sessiz takılma yok |
| R3 | Yeni e-posta + geçerli token | `201` + `pending_verification` + `verification_email_sent: true` | Pending ekran; JWT yok; “mail gönderildi” |
| R3b | `201` ama `verification_email_sent: false` | aynı status | Pending; **farklı kopya**: mail gitmemiş olabilir / yeniden dene |
| R4 | Aktif kayıtlı e-posta + token | `409 email_already_registered` | Türkçe + Giriş öner; SnackBar/görünür hata |
| R5 | Token sonrası tekrar `invalid_turnstile` | `400` | “Doğrulama yenilenmeli”; no-op yasak |
| R6 | Eksik email/şifre | `400 email_and_password_required` | Client + sunucu map |
| R7 | Geçersiz e-posta formatı | `400 invalid_email` | Map + form |
| R8 | Zayıf şifre (`< MIN_PASSWORD_LEN`, min 8) | `400 weak_password` | Client ≥8 + sunucu map |
| R9 | Rate limit (API_AUTH_ACTION_LIMIT ~12) | `429 rate_limited` + `retry_after_seconds` | Anlaşılır bekle mesajı |
| R10 | DB/commit fail | `500 register_failed` / `server_error` | Genel hata; crash yok |
| R11 | Pasif (deactivated) e-posta yeniden kayıt | `201 pending_verification` (reactivate) | Pending; özel “hesap yenilendi” zorunlu değil |
| R12 | Progressive Turnstile (`ALWAYS=0`, AFTER=2) | N. denemeden `invalid_turnstile` | Prod’da ALWAYS=1; non-prod için aynı lazy köprü yeterli |

**Not:** `REGISTER_TURNSTILE_AFTER_ACTIONS` yalnız `REGISTER_TURNSTILE_ALWAYS=false` iken geçerli. Prod’da “çok deneme → Turnstile” **login** tarafıdır (B2).

### B1b — Doğrulama maili / resend

| # | Senaryo | API | Mobil beklenen |
|---|---------|-----|----------------|
| V1 | Mail linki | Web `GET /verify-email/<token>` + confirm | Mobilde WebView zorunlu değil; kullanıcı mailde doğrular → login |
| V2 | Resend (doğrulanmamış) | `200` generic + `verification_email_sent` | Banner; `false` ise abartılı “gönderildi” yok |
| V3 | Resend rate limit | `429 rate_limited` | Map |
| V4 | Resend JSON Turnstile | Guide: **yok** | Token gönderme; web form farklı olabilir |
| V5 | Login doğrulanmamış | `403 email_not_verified` | Pending ekrana yönlendir |

### B2 — E-posta login (progressive captcha)

| # | Senaryo | API | Mobil beklenen |
|---|---------|-----|----------------|
| L1 | Doğru + verified | `200` JWT | Shell; `/me` |
| L2 | Yanlış şifre | `401 invalid_credentials` (+ belki `captcha_required`) | Mesaj; eşik sonrası köprü |
| L3 | ≥ `LOGIN_CAPTCHA_AFTER_FAILURES` (5) | `400 captcha_required` | Turnstile → retry |
| L4 | ≥ block eşiği (~10) | `429 rate_limited` | Bekle mesajı |
| L5 | `email_not_verified` | `403` | Pending / resend |
| L6 | Logout | revoke + wipe | **Guest shell** (F2); Login dayatması yok |

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

### B5 — Register `error` kod → mobil map (zorunlu checklist)

| `error` | HTTP | Mobil map |
|---------|------|-----------|
| `invalid_turnstile` | 400 | `needsTurnstile` (lazy) |
| `email_already_registered` | 409 | Türkçe + Giriş |
| `email_and_password_required` | 400 | Alan gerekli |
| `invalid_email` | 400 | Geçerli e-posta |
| `weak_password` | 400 | En az 8 karakter |
| `rate_limited` | 429 | retry_after ile bekle |
| `register_failed` / `server_error` | 500 | Genel hata |
| `email_required` (resend) | 400 | E-posta gerekli |
| `email_not_verified` (login) | 403 | Pending akış |
| `captcha_required` (login) | 400 | Lazy köprü |

## C. Prod smoke (BIST PREDEPLOY §3 uyarlama)

Secret/token sohbete yazma. Placeholder:

```bash
# R1: tokensız → invalid_turnstile
curl -sS -X POST https://lotlot.net/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"new@example.com","password":"StrongPass1","first_name":"T","last_name":"T"}'

# R7/R8: invalid_email / weak_password (token gerekmeden alan hataları önce gelebilir;
# ALWAYS=True ise turnstile önce de gelebilir — sırayı api_register ile doğrula)

# Login → me → watchlist → logout (PREDEPLOY §3.1–3.4)
```

Mobil UI smoke aynı sırayı cihazdan tekrarlar.

## D. Severity

| Seviye | Örnek |
|--------|--------|
| Critical | Auth kırık; token sızıntısı; guest’te Bearer/401 fırtınası |
| High | Kayıt/login hata yolu sessiz; yanlış `error` map; veri kaybı |
| Medium | Parity sapması (web toast var, mobil yok); `verification_email_sent` yok sayıldı |
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

- [ ] R1–R5 + R3b + R6–R9 kayıt matrisi
- [ ] V2–V5 doğrulama / resend
- [ ] L1–L6 login/logout
- [ ] G1–G6 guest/watchlist
- [ ] B5 error map checklist
- [ ] analyze + ilgili ekranlar elle
