# UX Uzmanı — Referans

Kaynak özeti: [Nielsen Norman Group — 10 Usability Heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/) (Jakob Nielsen; mobil için daha katı “az içerik” — [Mobile Sharpens Usability](https://www.nngroup.com/articles/mobile-sharpens-usability-guidelines/)).

## A. Nielsen 10 — hızlı kontrol listesi

| # | Heuristic | LOTLOT mobil pratik |
|---|-----------|---------------------|
| 1 | Visibility of system status | Splash/login: yükleme; istek sonrası snackbar/inline; sessiz başarısızlık yok |
| 2 | Match system ↔ real world | Kullanıcı dili (Giriş, E-posta, Şifre); “entitle”, “tier JSON” yok |
| 3 | User control & freedom | İptal, geri, çıkış; yanlış tap’te çıkış yolu |
| 4 | Consistency & standards | Platform kalıpları + site markası; aynı eylem aynı etiket |
| 5 | Error prevention | Şifre göster; boş gönderimi engelle; yıkıcı işlemde onay |
| 6 | Recognition > recall | Alan etiketleri görünür; kritik bilgi başka ekrandan ezbere değil |
| 7 | Flexibility & efficiency | Güç kullanıcı: kısa yollar sonra; önce net ana akış |
| 8 | Aesthetic & minimalist | İlk viewport: marka + hedef + CTA; politika/roadmap yok |
| 9 | Error diagnose & recover | “E-posta veya şifre hatalı” + yeniden dene; ham exception yok |
| 10 | Help & documentation | Gerekirse bağlamsal kısa yardım; uzun kılavuz ana ekrana değil |

## B. Mobil keskinleştirme

- Masaüstünde “olabilir” ikincil metin, mobilde çoğu zaman **silinir**.
- Bir ekran = bir iş. Giriş ekranı = giriş; abonelik kanalı politikası ≠ giriş işi.
- Thumb zone: birincil CTA erişilebilir; küçük tap hedefi yok (≈44pt / 48dp).
- Kısa kopya; ilk 1–2 satır değeri taşır.

## C. Metin / içerik filtreleri

**Kullanıcıya göster:** fayda, durum, yasal zorunlu kısa disclaimer, net hata, sonraki adım.

**Kullanıcıya gösterme (handbook / kod yorumu / PR):**
- StoreKit, Play Billing, IAP-only, Garanti / WebView yasağı
- Sprint backlog, faz kodları (F0–F7), API path’leri
- “yakında” listelerini roadmap gibi dump etmek (yerine tek umut verici cümle)

## D. Durum matrisi (ekran tesliminden önce)

| Durum | Soru |
|-------|------|
| Empty | Ne eksik, ilk eylem ne? |
| Loading | Kullanıcı beklediğini anlıyor mu? |
| Error | Ne oldu + nasıl düzelir? |
| Success | Sonraki adım net mi? |
| Permission / Pro | Neden kilitli, yükseltme nerede (IAP UI gelince)? |

## E. Heuristic review çıktısı

Her bulgu için:
1. Ekran / akış
2. Heuristic #
3. Şiddet (bloklayıcı / yüksek / orta / düşük)
4. Öneri (kopya veya UI)

## F. LOTLOT örnekleri

| Kötü (geliştirici) | İyi (kullanıcı) |
|--------------------|-----------------|
| “Abonelik yalnızca App Store / Play Billing…” | (Girişte yok; paywall’da plan + fiyat) |
| “Sonraki sprintler: StoreKit / …” | “Watchlist ve hisse detayları yakında.” |
| `pro_required` ham | “Pro üyelik gerekli” + yükselt CTA |
| “Exception: 401” | “Oturum sona erdi. Tekrar giriş yapın.” |
