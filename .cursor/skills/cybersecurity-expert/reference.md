# Siber Güvenlik — Referans

## A. OWASP Mobile Top 10 (pratik eşleme)

| Risk | LOTLOT kontrolü |
|------|-----------------|
| Improper credential usage | Keychain / EncryptedSharedPreferences; token log yok |
| Inadequate supply chain | kilitli bağımlılıklar; pub audit; native SDK güncelliği |
| Insecure auth/session | Refresh + revoke; 401 cascade logout; biometric opsiyonel |
| Insufficient input validation | API hata gövdesi; deep link validation |
| Insecure communication | HTTPS only; ATS / network security config |
| Inadequate privacy controls | Privacy labels; minimal PII; retention |
| Security misconfig | debuggable off; backup rules; ProGuard |
| Inadequate binary protection | Obfuscation makul; root detection abartma |
| Insecure data storage | Secure storage; screenshot sensitive flags gerektiğinde |
| Insufficient cryptography | Platform crypto; kendi “şifrelemen” yok |

## B. Auth / token tehdit modeli

**Asset:** access JWT, refresh token, kullanıcı PII.

| Tehdit | Mitigasyon |
|--------|------------|
| Cihaz çalınma | Secure storage; kısa access TTL |
| XSS / kötü app (sınırlı) | OS sandbox; clipboard’a token koyma |
| Replay refresh | Rotation + server revoke store |
| MITM | TLS; user CA’ye güvenme (prod) |
| Privilege escalation | Client’ta is_pro uydurma; sunucu entitlement |

## C. Mobil checklist (PR öncesi)

- [ ] Secret / token / key dosyası staged değil
- [ ] `flutter analyze` + Sonar secrets sensor
- [ ] Logging’de Authorization header yok
- [ ] Deep link parametreleri whitelist
- [ ] WebView yoksa sorun yok; varsa JS bridge kapalı
- [ ] Backup’ta token exclude (Android allowBackup politikası)
- [ ] Certificate / ATS exception yok veya dokümante

## D. API istemci sertleştirme

- Timeout’lar tanımlı
- Certificate hatalarında sessiz downgrade yok
- Error body’yi olduğu gibi loglama (PII)
- Rate limit 429 UX; brute-force’u client’ta “çözmeye” çalışma

## E. Store / gizlilik

- Data safety / App Privacy gerçek SDK’larla uyumlu
- Hesap silme endpoint’i UI’da
- Push opt-in; sessiz PII toplama yok

## F. Severity ölçeği

| Seviye | Örnek |
|--------|--------|
| Critical | Prod secret sızıntısı; auth bypass |
| High | Token plaintext storage; cleartext API |
| Medium | Eksik certificate validation exception; verbose logs |
| Low | Sertleştirme / defense-in-depth |

## G. Olay müdahalesi (hafif)

1. Kapsamı belirle (hangi token/sürüm).
2. Rotate secret / revoke refresh.
3. Store emergency / force update gerekip gerekmediği.
4. Handbook’a kayıt; tekrarını engelleyen kontrol.
