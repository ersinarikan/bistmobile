# LOTLOT.NET Mobile — Agent Kılavuzu

> Bu dosya agent’ın çalışma kılavuzudur. **Her anlamlı değişiklikten sonra güncellenir.**
> Son güncelleme: 2026-08-03

## 1. Proje özeti

| | |
|---|---|
| Uygulama | LOTLOT.NET Flutter mobil (Android + iOS) |
| Bu repo (yerel) | `lotlotnet_mobile` |
| GitHub remote | https://github.com/ersinarikan/bistmobile |
| Web/API | https://lotlot.net (sunucu: www.lotlot.net) |
| Web kaynak kod | https://github.com/ersinarikan/BIST |
| API sözleşmesi | `docs/MOBILE_API_INTEGRATION_GUIDE.md` |
| SonarCloud | https://sonarcloud.io/dashboard?id=ersinarikan_bistmobile |

## 2. Cursor kuralları (`.cursor/rules/`)

Hepsi `alwaysApply: true` (özet):

1. **web-server-ssh** — Canlı sunucu www.lotlot.net; SSH ile teşhis (yazma/restart izinsiz yok). Kod referansı için önce BIST repo.
2. **clean-mobile-dev** — Temiz kod; gereksiz kod yok; anlaşılır “neden” comment’leri.
3. **post-change-refactor** — Değişiklik sonrası ilgili dosyalarda refaktör fırsatını değerlendir.
4. **web-bist-repo** — Web kodu: ersinarikan/BIST.
5. **bistmobile-git-flow** — İş bitince: kalite → commit → sıradaki tag (`vN`) → push bistmobile.
6. **quality-gate-pre-push** — Commit/push öncesi `flutter analyze` + `sonar-scanner` (SONAR_TOKEN).
7. **risk-integrity-mobile** — Kod öncesi risk/etki analizi; iOS+Android bütünlüğü; yan etkiyi kırma.
8. **agent-handbook** — Bu kılavuzu her değişiklik sonrası güncelle.

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
    splash/                 # bootstrap → home | login
    auth/                   # login + SessionController
    home/                   # basit home + logout
```

State: **Provider**. Token: **flutter_secure_storage**.

## 4. Yapılanlar (kronoloji)

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

## 5. Çalışma ritüeli

1. İstek → **risk analizi** (platform + çapraz etki)
2. Minimal / temiz kod; API rehberi + gerekirse BIST repo
3. Bitince: ilgili yerlerde **refaktör değerlendirmesi**
4. **Bu kılavuzu güncelle** (ne değişti, nerede, bilinen risk)
5. `flutter analyze` → `sonar-scanner` → commit → tag `vN` → push

```bash
flutter analyze
export SONAR_TOKEN='…'   # ortama; commit etme
sonar-scanner
# sonra git commit + tag + push
```

## 6. Marka / ikon

| Kullanım | Kaynak |
|---|---|
| In-app logo | `https://lotlot.net/static/img/brand/lotlot-icon-transparent.png` (`BrandAssets`) |
| Launcher | Yerel `assets/branding/app_icon.png` (PWA 512’den) + `dart run flutter_launcher_icons` |
| Not | CDN `immutable` cache (~1 yıl); aynı URL’de değişince istemci gecikebilir |

## 7. Bilinen / ertelenen

- [ ] lotlot.net **SSH** (root/ersin): sunucu yalnız `publickey`; bu Mac’te sunucu key’i yok — sonra
- [ ] Android **release** `INTERNET` izni main manifest’te yok (şimdilik debug/profile’da var) — release öncesi ekle
- [ ] App display name hâlâ `lotlotnet_mobile` / `Lotlotnet Mobile` — marka adına çekilecek
- [ ] Faz 2+: watchlist, hisse detay, Google/Apple, IAP

## 8. Dokunulmaması gerekenler

- Secret / `.env` / `SONAR_TOKEN` / private key commit yok
- Üretim sunucusunda izinsiz yazma / restart / migrate yok
- Force push / tag silme yalnız açık kullanıcı isteğiyle

## 9. Hızlı dosya haritası

| Ne | Nerede |
|---|---|
| Agent kılavuzu | `docs/AGENT_HANDBOOK.md` (bu dosya) |
| API rehberi | `docs/MOBILE_API_INTEGRATION_GUIDE.md` |
| Sonar config | `sonar-project.properties` |
| Cursor rules | `.cursor/rules/*.mdc` |
