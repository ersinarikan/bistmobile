# LOTLOT.NET Mobile

Flutter istemcisi — Android + iOS. Backend: `https://lotlot.net`

## Doküman

- [Agent kılavuzu — §0 Mobil ürün yol haritası](docs/AGENT_HANDBOOK.md) — aşamalı plan (F0–F7), kurallar, ritüel
- [Mobil API entegrasyon rehberi](docs/MOBILE_API_INTEGRATION_GUIDE.md) — web ekibinin yaşayan sözleşmesi (**salt okuma**; yol haritası handbook §0’da)

## Çalıştırma

```bash
flutter pub get
flutter run
```

## Fazlar (özet)

Detay ve acceptance: **[handbook §0](docs/AGENT_HANDBOOK.md)**.

1. F0–F1 — Temel + auth tamam  
2. F2–F4 — Watchlist, hisse detay, hesap/yasal  
3. F5 — Pro yüzey + push (satın alma yok)  
4. F6–F7 — IAP paywall + mağaza teslimi  
