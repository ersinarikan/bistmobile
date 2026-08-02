# LOTLOT.NET Mobile

Flutter istemcisi — Android + iOS. Backend: `https://lotlot.net`

## Doküman

- [Agent kılavuzu](docs/AGENT_HANDBOOK.md) — geliştirme geçmişi ve çalışma ritüeli
- [Mobil API entegrasyon rehberi](docs/MOBILE_API_INTEGRATION_GUIDE.md)

## Çalıştırma

```bash
flutter pub get
flutter run
```

## Fazlar

1. Auth + `/api/auth/me` (şu anki iskelet)
2. Watchlist / hisse detay
3. Google + Apple Sign-In
4. IAP-only paywall (StoreKit / Play Billing)
