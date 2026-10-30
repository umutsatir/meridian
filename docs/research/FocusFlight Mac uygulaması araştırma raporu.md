# FocusFlight'tan esinlenen Mac uygulaması: araştırma raporu

Hazırlanma tarihi: 29 Ekim 2026. Kapsam: FocusFlight (App Store, Cement Planet LTD) analizi, kullanıcı yorumları, rakipler, Mac'e özgü teknik kısıtlar, stack kararı, özellik listesi ve yol haritası.

---

## 0. Özet: kararlar bir bakışta

1. **Fırsat gerçek ve Mac tarafı boş.** FocusFlight 4,8 yıldız ve yaklaşık 9,8 bin puanla (ABD) sevilen bir uygulama, ama Mac'te yerel bir uygulaması yok gibi görünüyor: App Store kaydı "iosUniversal" ve Mac sürümü iPhone/iPad uygulamasının Apple silicon'da çalışması gibi davranıyor. Bir kullanıcı Mac yorumunda "pencere küçülmüyor, haritayı ekranda sabit tutamıyorum" diye şikayet ediyor. Bu, yerel bir Mac uygulamasının doğrudan açabileceği boşluk.
2. **Yorumlardaki en güçlü talepler:** doğru dürüst bir "birlikte uçma" (yaklaşık 40 yorum), değişmeyen pencere manzarası yerine canlı bir "pencere" (yaklaşık 60 yorum), kalkış havalimanını seçebilme (yaklaşık 24 yorum, sürekli tekrarlanan bir öfke), kabin anonsları ve sesleri, uçuş geçmişini/biletleri haritada renkli görme ve koleksiyon (yaklaşık 27 yorum).
3. **En büyük şikayet fiyat ve güven.** Yeni 2.0 sürümü daha önce ücretsiz olan sesleri ve geçmiş görünümünü ücretli yaptı; örneklemde 2.0 sürümünün ortalaması 4,43, öncesi 4,56. İade, deneme sonrası tahsilat ve cevapsız destek şikayetleri tekrarlanıyor. Bu, bizim için "cömert ücretsiz katman + şeffaf fiyat" farkı demek.
4. **Mac'te "Airplane Mode" (uygulama engelleme) iOS'taki gibi yapılamaz.** iOS'taki Screen Time API'si (FamilyControls) Mac'te kullanılamıyor. Sert engelleme için ya Mac App Store dışı dağıtım ya da yumuşak engelleme gerekiyor. Bu, v1 kapsamını doğrudan etkiliyor.
5. **Stack önerisi: SwiftUI + AppKit (yerel Swift).** React'e olan eğilimin anlaşılır, ama bu ürünün değeri 3D harita, menü çubuğu, widget, iCloud, StoreKit ve sistem entegrasyonunda, hepsi Swift tarafında. React Native macOS veya Tauri ile gitsek bile bu parçaları Swift ile yazmak zorunda kalırız. Electron ise şikayetlerin başında gelen pil/ısınma sorununu büyütür. Kodu ben yazacağım için Swift öğrenme maliyeti sizin tarafınızda küçük. Ayrıntı ve alternatifler bölüm 5'te.
6. **Orijinalin kopyası değil, "Mac-first ve birlikte uçulan" bir ürün yapalım.** İsim, görseller, sesler ve kod sıfırdan olmalı (App Store telif/taklit kuralları ve yorumlardaki "pahalı ve kopya" algısı için de). Mekanik fikirleri (uçuşu odak sayacı yapmak) serbest, varlıkları (illüstrasyon, ses, UI) birebir kopyalamak değil.
7. **Gelir beklentisini gerçekçi tutalım.** Bir Çin haberine göre (Diandian verisi) uygulamanın aylık geliri başlangıç döneminde 5 bin doları geçmemiş; makalenin tarihini doğrulayamadım. Niş bir kategori, küçük ve yalın bir ekip için uygun, büyük yatırımlık değil.

---

## 1. Orijinal uygulama: ne, kim, nasıl para kazanıyor

| Alan | Bulgu |
|---|---|
| Ad / geliştirici | FocusFlight - Deepfocus Timer, Cement Planet LTD |
| Çıkış | 21 Ocak 2025; son sürüm 2.0, 7 Haziran 2026 |
| Puan | ABD 4,85 / 9.793 puan; Türkiye 4,66 / 2.561 puan |
| Platform | iPhone, iPad, Mac (macOS 14+), Vision Pro; Watch yok. Kayıt türü "iosUniversal", yani Mac için ayrı yerel sürüm olduğuna dair işaret yok. Bu bir **çıkarım**, kesin doğrulama değil. |
| Boyut | 306 MB |
| Diller | EN, DE, JA, KO, ZH-Hans, ZH-Hant. **Türkçe yok**, Türkçe yorumlar bunu istiyor. |
| Fiyat | Ücretsiz + uygulama içi satın alma. Abonelik: 3,99 $/ay, 18,99 $/yıl. Ömür boyu seçenekleri: 18,99 / 19,99 / 33,99 $ (yorumlarda 49,99 $ "üstü çizili" fiyat, 2.500 yen, 50 € geçiyor) |
| Öne çıkan | App Store "App of the Day", Editors' Choice, "Apps We Love" |
| Gizlilik | Analitik (satın alma geçmişi, kullanıcı kimliği, kullanım) ve tanılama; kimliğe bağlı veri yok |
| Gelir | Diandian'a atfen aylık < 5.000 $ (tarihi doğrulanmadı); kullanıcıların çoğu Çin'den, Doğu Asya ağırlığı yorumlarda da belli |

### Çekirdek akış

Kalkış havalimanı → süre (en az 30 dk, en çok yaklaşık 5 saat) → süreye uyan varış noktası → koltuk (çalışma/okuma/yaratıcı gibi "odak türü") → check-in → bilet yazdırma ve yırtma (haptic) → uçuş (3D harita, uydu/klasik harita, pencere görünümü, beyaz gürültü, Dynamic Island/widget/StandBy) → iniş, uçuş günlüğü (FlightLog), mil ve üyelik kartları.

Ücretsiz katmanda: temel zamanlayıcı, uçak sesi, uygulama engelleme (iOS Screen Time üzerinden). Ücretli katmanda: pencere görünümü, sınırsız/uzun uçuşlar, geçmiş ve trend, harita türleri, ek sesler, 3D rotalar, widget'lar, kartlar (kullanıcı yorumlarına göre; 2.0 sonrası bazı eski ücretsiz özellikler de ücretliye alındı).

---

## 2. Kullanıcı yorumu analizi

### Yöntem ve sınırlar

- Apple'ın herkese açık yorum akışından (iTunes RSS) 8 mağazadan (ABD, İngiltere, Türkiye, Almanya, Japonya, Güney Kore, Kanada, Avustralya) **1.285 benzersiz yorum** çektim: 949'u 5 yıldız (%74), 186 dört, 66 üç, 23 iki, 61 bir yıldız. Tarih aralığı: Ocak 2025 – 28 Ekim 2026.
- 3 yıldız ve altındaki **150 yorumun tamamını**, geri kalan olumlu yorumlardan istek içeren yaklaşık 75 en uzun yorumu elle okudum.
- Tema sayıları **kaba anahtar kelime eşleşmesi** (çok dilli) ve yaklaşık. Orantıları gösterir, kesin sayı değildir. Örnek: "arkadaş" kelimesi bazen yalnızca "arkadaşlarıma öneririm" anlamında geçiyor, bu yüzden aşağıdaki sayılar abartılı olabilir.
- Örneklem Güney Kore, Japonya ve ABD ağırlıklı. Hiçbir özelliği uygulamayı çalıştırarak doğrulamadım, her şey kullanıcı beyanı ve App Store kaydı.
- Ekran görüntüsü/video analizi yapmadım; UI kararlarını sizin göndereceğiniz görsellerle netleştirelim.

### Sevilen şeyler (bunları korumalıyız)

- **Ritüel ve estetik:** bilet yazdırma/yırtma ve haptic geri bildirim defalarca övülüyor ("bileti yırtmak için odaklanıyorum"). UI "çok sade ve güzel" bulunuyor.
- **Tutunma mekaniği:** uçuşu bitirmeden yarım bırakmama baskısı, ilerleyen rota, mil birikimi, harita doldukça gelen tatmin. ADHD'li kullanıcılar özellikle "uçuşu kaybetmek istemiyorum" etkisinden bahsediyor (yaklaşık 23 yorumda ADHD geçiyor).
- **Atmosfer:** uçak motor sesi, "airplane mode" hissi, kulaklıkla kabin ambiyansı.
- **Ücretsiz katmanın cömertliği 2.0 öncesinde** bir marka değeriydi ("reklam yok, zorlama yok", yaklaşık 28 yorum).

### Şikayetler (şiddet sırasına göre)

1. **Ücretli duvar ve güven.** Pencere görünümü için 20 $ ödeyenler görüntünün "aynı döngü video" olduğunu söylüyor. Uzun uçuşlar, geçmiş, harita türü, ses çeşitliliği ücretli. 2.0'da önceden ücretsiz sesler (yağmur, okyanus, orman) ve haftalık/aylık geçmiş ücretliye alınınca açık bir tepki oluştu (en az 6 yorum, çoğu 1–3 yıldız). Deneme süresinde beklenmedik tahsilat, iade reddi, "cevap vermeyen destek" şikayetleri tekrarlıyor. Ülkeye göre "indirimli ömür boyu" gibi baskı pencereleri de "aldatıcı fiyatlandırma" diye yorumlanmış.
2. **Kalkış havalimanı değiştirilemiyor.** En sinir bozucu eksik: yaklaşık 24 yorum; İngiltere, Almanya, Japonya, Türkiye, Güney Kore ve ABD'den. "Londra'dayım ama Paris'ten kalkıyorum", "hep Kongo'dan kalkıyorum", "Seul'deyim ama Yangyang görünüyor". Bir kullanıcı bunu bir yıldır beklediğini yazmış. Bu özellik bizde ilk günden olmalı.
3. **Kararlılık ve veri kaybı.** iOS 26 ile başlayan çökme dalgası (Eylül 2025); cihaz kapanınca veya yeniden başlayınca uçuşun sıfırlanması ve "gecikme" yazılması; devam eden uçuşun iPhone/iPad arasında senkron olmaması; iCloud'un "Uploading"de takılması; hesabın silinip uçuşların kaybolması.
4. **Pil ve ısınma.** iPad'de iki buçuk saatte %100'den %10'a, Mac'te "fan sesi, ısınma" (az sayıda ama çok sert yorumlar). Mac için 3B harita ve animasyonun enerji bütçesini baştan tasarlamalıyız.
5. **Engelleme güvenilmez.** Bazı uygulamalar engellenmiyor (WhatsApp, "engeli kaldırdığım uygulamaları açmıyor"); Screen Time bağlantısı kopuyor. Mac'te bunun zaten başka bir hikâyesi var (bölüm 4).
6. **Harita siyaseti.** Güney Kore'den en az 10 yorum "Doğu Denizi yerine Japon Denizi yazıyor, Dokdo yok" diye 1 yıldız verip uygulamayı silmiş; Türkiye'den biri Filistin'in haritada olmadığını belirtip silmiş. Harita sağlayıcısı ve etiket politikası bir ürün kararıdır (bölüm 6).
7. **Sürtünme.** "Koltuk seç, odak türü seç, check-in, bileti yırt, Board, Go" en az 6 dokunuş; masaüstünde bilet yırtmak zahmetli bulunuyor. En az 30 dk uçuş şartı DEHB'li kullanıcılar için fazla uzun (10 dk isteyenler var), bazıları ise tersine sonsuz/uzun uçuş istiyor.
8. **Derinlik eksikliği.** Pencere manzarası hep aynı (gece/gündüz, hava yok), kalkış/iniş yok (yalnızca "ding"), anons yok, rota düz çizgi, koltuk/odak türü bir şeyi değiştirmiyor. "İlk uçuştan sonra yenilik bitiyor ve beyaz gürültü makinesine dönüşüyor" diyen yorum bu eksiğin özeti.
9. **Dil ve destek.** Türkçe ve daha fazla dil isteniyor; geliştiriciye yazılan e-postalar okunuyor ama cevaplanmıyor (en az 4 yorum).

### İstek listesi (talep gücüne göre)

| Sıra | İstek | Yaklaşık yorum sayısı | Not |
|---|---|---|---|
| 1 | Canlı pencere: gece/gündüz, hava, bulut/kanat, uçuş sırasında değişen manzara, bedava en az bir sahne | ~60 | "Pencere, uçaktan görülen harita olur sanmıştım" diyen yorum var; yani gerçek arazi bekleniyor |
| 2 | Arkadaşlarla birlikte uçma, arkadaşların uçaklarını haritada görme, aynı uçakta koltuk | ~40 | Kore'den 5 yıldızlı bir yorum "arkadaşla uçuş modu yakında geliyor diye duyurulmuş" diyor; ABD'den 3 yıldızlı bir yorum güncelleme ekranlarında "multiplayer"ın yazdığını ama uygulamada olmadığını belirtiyor. **Rakip bunu planlıyor, pencere daralıyor.** |
| 3 | Kabin anonsları, kaptan duyurusu, ATC, emniyet kemeri uyarısı, yemek arabası, iniş öncesi uyarı | onlarca | "İniş zili uyarısız geldi, çok korktum" diyen var |
| 4 | Kalkış noktasını seçme / son indiğim yerden devam | ~24 | Aşırı tekrar eden talep |
| 5 | Geçmiş uçuşları, biletleri ve gidilen yerleri haritada görme, **gidilen yerleri farklı renkte görme**, pasaport/damga, ağ görünümü, dışa aktarma | ~27 | Sizin bahsettiğiniz "eski biletleri renkli görme" talebinin yorum karşılığı bu |
| 6 | Kısa uçuş/stopwatch/uçuş sırasında mola (yemek servisi = Pomodoro molası), sonsuz uçuş, çok bacaklı seyahat | ~37 | DEHB kullanıcılarında güçlü |
| 7 | Uçak ve havayolu seçimi, boya şeması, üyelik/sadakat programı (Star Alliance benzeri), daha çok kart seviyesi | onlarca | Gerçek havayolu markaları hukuki risk (bölüm 9) |
| 8 | Daha çok ses: kahverengi gürültü, yumuşak okyanus, katmanlı karıştırma, müzik | onlarca | |
| 9 | Eşitleme: iPhone-iPad-Mac arası devam eden uçuş, satın alımın aile ve cihazlar arası geçerliliği | ~16 | "Kişisel ve iş cihazım için iki kez açmam gerekiyor" 1 yıldızı |
| 10 | Apple Watch, Focus modu otomasyonu, Kısayollar, Always-On Display, ekran koruyucuyu engelleme, widget harita stili | az ama kalıcı | Mac'te ekran koruyucu şikayeti ayrı bir yorum |
| 11 | Başka araçlar (tren, ICE, Hogwarts Express) | birkaç | "Birden çok ulaşım türü" genişleme fikri |
| 12 | Gerçekçi uçuş rotası ve iniş/kalkış yönü | birkaç | Düz çizgi yerine kavisli koridor |

### Sizin iki fikriniz yorumlarla nasıl örtüşüyor

- **Birlikte aynı uçağa binme:** yalnızca birkaç yorum değil, hem Türkçe, hem Japonca, hem Korece, hem İngilizce talep var ve örnekler somut: aynı uçağa binip koltuk seçmek, arkadaşın uçağını haritada görmek, "yolcu listesi", rekabet. Çoğunun eksik kaldığı nokta: hangi mekanik. Aşağıda (bölüm 6) üç mekanik öneriyorum.
- **Eski biletleri renkli görme:** bir Türkçe kullanıcının yorumu doğrudan "uçtuğum yerleri farklı renkte görmek istiyorum" diyor; ABD'den yorum "tüm eski uçuşları harita üzerinde görmek ve uçağın şehirden şehre zıplamasını izlemek" istiyor. Bilet cüzdanı + renkli dünya haritası bu isteklerin ikisini de karşılar.

---

## 3. Rakipler ve konumlandırma

Bilgiler App Store kayıtlarından ve arama sonuçlarından; doğrulanmamış geliştirici beyanları içerir.

| Uygulama | Odak | Notlar |
|---|---|---|
| **Forest** | Ağaç dikme + Plant Together (grup odak) | Sosyal baskı mekaniği referansı. Odada biri çıkarsa herkesin ağacı ölür. Resmi yerel Mac uygulaması bulamadım. Fiyatlandırma kaynaklarda çelişkili (iOS'ta bir kerelik 3,99 $ ve yeni "Plus" iddiaları). |
| **Focus Traveller** | Pomodoro + akış zamanlayıcı | 10 kişiye kadar grup odak, geri sayım/stopwatch, widget. ABD fiyatı: 0,99 $/ay, 7,99 $/yıl, 14,99 $ ömür boyu. FocusFlight'tan belirgin ucuz. |
| **AirFocus** | Uçuş temalı odak | Pencere, harita değişimi, analiz, canlı etkinlik ücretli; iPhone/iPad. |
| **Flight Focus** (başka geliştirici) | 25 dk Pomodoro = uçuş | 3D küre, pasaport damgaları, premium temalar. |
| **FocusTok** | Sıkı mod (kalkıştan sonra durdurma yok) | Boarding pass akışı, iş/çalışma/okuma etiketleri. |
| **AeroFocus** | Salon modu | Şehir gece manzarası, her varışta damga, Pomodoro. |
| **Mac Pomodoro/menü çubuğu araçları** | TomatoBar (ücretsiz, açık kaynak), Focus (Meaningful Things, ~39,99 $/yıl), Flow, Pebble, Flumen | Fonksiyonel ama duygusal bağ/oyunlaştırma yok. |

**Boşluk:** Mac'te hem güzel hem oyunlaştırılmış, hem sosyal bir odak ürünü yok. Uçuş temalı rakiplerin hepsi iPhone/iPad. Bu yüzden konumlandırma: **"Masaüstünde uçarak çalış, arkadaşlarınla aynı uçakta."**

---

## 4. Mac'e özgü fırsat ve kısıtlar

### Fırsatlar

- **Büyük ekran:** harita ve pencere görünümü Mac'te çok daha iyi görünür; ikinci monitörde "koltuk TV'si" olarak tam ekran çalışabilir.
- **Yüzen mini "uçuş içi harita" penceresi:** bir Mac kullanıcısı tam olarak bunu istiyor ("uçuş içi TV haritası gibi ekranda küçük dursun"). Her zaman üstte, yeniden boyutlanabilir, yarı saydam, bir tuşla gizlenir.
- **Menü çubuğu öğesi:** kalan süre, uçak konumu, tek tıkla duraklat/acil iniş.
- **Masaüstü widget'ları** (WidgetKit), **Kısayollar/App Intents**, **küresel kısayol**, **Focus filtresi** (Rahatsız Etme'yi uçuşla aç/kapat), bildirimler.
- **macOS 26 (Tahoe):** iPhone Live Activities Mac menü çubuğunda iPhone Mirroring üzerinden görünüyor. İleride iOS eşlikçi yaparsak ücretsiz bir Mac varlığı kazanırız.
- Bu uygulamanın kitlesi (öğrenci, geliştirici, yazar) zaten saatlerce Mac başında.

### Kısıt 1: Screen Time API Mac'te yok

iOS'taki "Airplane Mode" engellemesi Apple'ın FamilyControls / ManagedSettings / DeviceActivity çatısına dayanıyor. Apple dokümanı bu çatıları iOS, iPadOS ve Mac Catalyst 15+ olarak listeliyor, ancak geliştirici forumlarında Catalyst'te yetkilendirmenin sandbox nedeniyle başarısız olduğu ve saf macOS uygulamasında `AuthorizationCenter`'a erişilemediği bildiriliyor. Bir Apple DTS yanıtı sandbox kapalıyken denemeyi önermiş. Sonuç: **Mac'te iOS'un yaptığı gibi sistem düzeyinde uygulama engelleme yok.**

Mac'te seçenekler (hepsi bir "spike" ile doğrulanmalı, App Review sonuçları için kesin söz veremem):

| Yaklaşım | Ne yapar | Kısıt |
|---|---|---|
| **Yumuşak engelleme** (öneri v1) | Uçuş sırasında engelli bir uygulama öne gelirse örtü/uyarı gösterir, ihlali kaydeder, "uçuş bozuldu mu" politikasını uygular | Gerçek engel değil, taahhüt ve sürtünme sağlar; Mac App Store'a uygun |
| **Uygulama sonlandırma/gizleme** | `NSWorkspace` ile açılan uygulamayı izleyip gizler/kapatır | Sandbox içinde diğer süreçleri sonlandırma kısıtlı; Mac App Store'da risk |
| **Web sitesi engelleme** | Safari içerik engelleyici uzantısı (yalnızca Safari), ağ filtresi (Network Extension, özel yetki ve sistem uzantısı gerekir), ya da `/etc/hosts` düzenleme (ayrıcalıklı yardımcı gerekir) | Tarayıcı kapsaması, onboarding zorluğu, App Review |
| **Doğrudan dağıtım (Developer ID + noterlik)** | Sandbox'sız sert engelleme mümkün | Mac App Store keşfi ve StoreKit'ten vazgeçilir (ya da iki sürüm) |

**Öneri:** v1'i "yumuşak engelleme + Focus filtresi" ile çıkaralım; sert engellemeyi ayrı bir karar olarak (doğrudan dağıtım sürümü veya yardımcı uygulama) v1.5+ için değerlendirelim. iOS eşlikçi geldiğinde telefondaki engelleme zaten Screen Time ile çözülür; Mac uygulamasının değeri "masa başı odak ritüeli".

### Kısıt 2: Enerji

Orijinalde pil ve ısınma yorumları var ve aynı yorumcular Mac'te de fan sesinden söz ediyor. Kural olarak: pencere görünmüyorsa render durur, imleç/kullanıcı etkileşimi yokken düşük kare hızı, harita arka planda dondurulur, Metal/SceneKit yerine mümkünse MapKit'in kendi optimize edilmiş 3B'si kullanılır.

### Kısıt 3: Harita

MapKit (SwiftUI) macOS'ta `.imagery(elevation: .realistic)` / `.hybrid(elevation: .realistic)` ile gerçek yükseklikli uydu görünümü verir ve `MapCamera` ile eğim, yön, mesafe kontrolü sağlar. Forum kayıtlarında globe (küre) modunda `.standard(elevation: .realistic)`'in 2B'ye düştüğü, `.hybrid(elevation: .realistic)`'in 3B kaldığı bildirilmiş; macOS 14 ve 26'da sürüm bazında test edilmeli (bölüm 6'daki spike).

---

## 5. Stack kararı

### Karar kriterleri (bu ürüne özgü)

1. Çok temiz, "yerel hisli" arayüz (vibrancy, SF yazı tipi, macOS 26'da Liquid Glass, akıcı animasyon).
2. 3B küre/harita kalitesi ve **düşük enerji tüketimi**.
3. Menü çubuğu, WidgetKit, App Intents, Focus filtresi, bildirimler.
4. iCloud (CloudKit) eşitleme, StoreKit 2, Family Sharing.
5. Sistem düzeyi özellikler (engelleme, yardımcı süreç).
6. Gelecekte iPhone/iPad eşlikçisi.
7. Kodu **Claude ile birlikte** yazacağız, yani öğrenme eğrisi ikincil; bakım ve doğruluk birincil.

### Karşılaştırma

| Seçenek | Uyum | Güçlü yanlar | Zayıf yanlar |
|---|---|---|---|
| **A. SwiftUI + AppKit (yerel)** ✅ öneri | Çok yüksek | MapKit 3B, WidgetKit, MenuBarExtra, App Intents, CloudKit, StoreKit 2, Liquid Glass, düşük pil/bellek; iOS/iPadOS/visionOS ile kod paylaşımı | React yok; web/Android'e taşınmaz |
| **B. React Native macOS** (Microsoft) | Orta-düşük | React/TS arayüz, gerçek AppKit görünümleri | MapKit globe, WidgetKit, menü çubuğu, engelleme, StoreKit/CloudKit için **yine Swift yerel modülü** gerekir; Mac topluluğu küçük; ekstra yük (kaynaklar "daha fazla platforma özgü mühendislik" diyor) |
| **C. Tauri v2 + React** | Orta | Küçük paket (~49 MB kaynağa göre), React arayüz | WKWebView içinde 3B küre pil için riskli; yerel hissi elde etmek zor; widget ve Swift kısımları yine ayrı; Mac App Store süreci karmaşık |
| **D. Electron + React** | Düşük | En hızlı prototip, Mapbox/three.js hazır | Bellek/pil ağır (kaynakta medyan 416 MB ve 43 MB yerel); en büyük şikayetlerden biriyle (ısınma) çelişir; yerel his sınırlı; Mac App Store gönderimi zahmetli |
| **E. Hibrit (Swift kabuk + WebView'da React ekranlar)** | Düşük | | İki dünyanın zayıf yanları, bakım yükü |

*(Boyut ve yerel uygulama oranları ikincil kaynaklardan; kesin ölçüm değil. Tauri/Electron sürüm numaraları kaynaklar arasında çelişkili, kullanmadım.)*

### Neden React değil (dürüst özet)

React'in avantajı web ile kod paylaşımı ve ekip hızı. Bu ürünün gerçek işi ise harita, sistem entegrasyonu ve enerji; bunlar Swift'te. React'te yazsak bile ürünün en değerli yarısını Swift ile yazarız ve ortaya iki dilli, bakımı zor bir ürün çıkar. **Tek istisna:** ileride Android veya web sürümü ciddi bir hedefse, ortak parçaları (örneğin sosyal arka uç, hesap, web landing/paylaşılan ticket sayfaları) web teknolojisiyle yazarız; asıl uygulama yine yerel kalır.

**Önerilen yığın:**
- **İstemci:** Swift 6, SwiftUI + AppKit köprüleri, hedef macOS 14+ (orijinalle aynı taban; macOS 26'da Liquid Glass için `#available` ile ek stil), MapKit, SwiftData + CloudKit, StoreKit 2, WidgetKit, App Intents, AVAudioEngine (katmanlı ses).
- **Veri:** OurAirports (kamu malı) havalimanı verisi; rotalar büyük daire hesabı ile üretilir (uygulama içinde, kavisli koridor eklenerek).
- **Sosyal arka uç (v1.5):** gerçek zamanlı "uçuş odaları" için WebSocket tabanlı bir arka uç. Örnek seçenek: Cloudflare Durable Objects (oda başına bir nesne, hafif, ucuz) + Sign in with Apple. Alternatif: CloudKit paylaşımı (arka uç yok ama gerçek zamanlı varlık sinyali zayıf). Karar spike sonrası.
- **Telemetri:** minimum; çökme raporlama (Xcode Organizer / MetricKit), gizlilik etiketi sade.

---

## 6. Ürün tanımı

### Konumlandırma ve ilkeler

- **Mac-first:** masaüstünde sürtünmesiz başlayan, ekranın köşesinde sakin duran, güzel görünen odak aracı.
- **Birlikte uçuş:** body-doubling (başka biri varken daha iyi odaklanma) mantığıyla yaşayan bir sosyal çekirdek.
- **Cömert ve şeffaf:** ücretsiz katmanda gerçek değer; sürpriz tahsilat yok; iade ve destek dürüst.
- **Güvenilir:** uçuş durumu mutlak zamana bağlı; uyku, kapanma, çökme ve pil bitmesi uçuşu bozmaz.
- **Özgün:** isim, çizim, ses ve UI sıfırdan; sadece mekanik benzer.

### Özellik listesi (öncelik P0 = v1.0 şart, P1 = v1.5, P2 = sonra; boyut S/M/L kaba)

**A. Uçuş çekirdeği**
- A1 Hızlı Başlat (tek tuşla son rota ve süre) + isteğe bağlı "Tören modu" (koltuk, check-in, bilet yırtma). Sürtünme şikayetine doğrudan cevap. **P0, S**
- A2 Kalkış havalimanı: otomatik tespit + elle değiştirme + "son indiğim yerden devam" + favori havalimanları. **P0, S**
- A3 Süre: 10 dk – 6 saat, serbest süreli "açık uçuş" (stopwatch). **P0, M**
- A4 Rota: büyük daire + hafif kavisli koridor, rastgele rota, sonradan **çok bacaklı seyahat** (uzak hedef, ara duraklar). **P0 temel / P1 çok bacak, M**
- A5 Odak türü + konu etiketi + kısa not (neye çalıştığım). **P0, S**
- A6 Bilet yazdırma/yırtma (trackpad haptic, sesli/sessiz, atlanabilir). **P0, M**
- A7 Uçuş fazları: boarding, taxi, kalkış, tırmanış, seyir, alçalış, iniş; her fazın sesi/animasyonu. **P0 temel, M**
- A8 Duraklatma politikası: Sıkı (durdurma yok), Normal (acil iniş = kısmi kayıt), Esnek (mola). **P0, S**
- A9 Mola = "yemek servisi" (Pomodoro molası, uçuş devam eder). **P1, S**
- A10 Dayanıklı durum: ilerleme `başlangıç zamanı + süre` ile hesaplanır, tick'e bağlı değil. **P0, S (mimari karar)**

**B. Görsel dünya**
- B1 3B küre + uydu + klasik harita, uçağı izleyen kamera, yakınlaştırma kontrolü. **P0, M**
- B2 **Canlı pencere:** gerçek güneş konumu (uçuş noktasına göre gece/gündüz/gün batımı), bulut katmanları, kanat, isteğe bağlı gerçek hava; yorumların 1 numaralı talebi. **P1, L**
- B3 **Yüzen mini uçuş içi harita** + **menü çubuğu öğesi.** **P0, M**
- B4 İkinci ekranda tam ekran "koltuk TV'si". **P1, S**
- B5 Ekran koruyucuyu/uyku moduna girmeyi uçuşta engelleme (kullanıcı ayarı). **P0, S**

**C. Ses**
- C1 Kabin motoru, yağmur, okyanus, orman, kahverengi/pembe gürültü; **katmanlı mikser.** **P0 temel / P1 mikser, M**
- C2 Anons paketi (kaptan, kabin ekibi), emniyet kemeri zili, **iniş 5 dk önce uyarı**, isteğe bağlı ATC; hepsi açılıp kapanabilir. **P1, M**
- C3 Müzik uygulaması entegrasyonu. **P2, M**

**D. Koleksiyon ve ilerleme**
- D1 **Bilet cüzdanı:** eski biletler **renkli** (odak türüne, uçuş süresine/"kabin sınıfına", kıtaya göre), filtre, arama, bilet ayrıntısı; seri/nadir uçuşlarda folyo efektli bilet. **P0, M**
- D2 **Dünya haritası:** gidilen havalimanı ve ülkeler renkli (yoğunluğa göre), tüm rotaların ağ görünümü, zaman filtresi, "bu yıl". **P0 temel / P1 tam, M**
- D3 Pasaport + ülke damgaları, mil kartı seviyeleri (kurgusal havayolu/ittifak). **P1, M**
- D4 İstatistik: gün/hafta/ay/yıl, kategori, seri, günlük hedef; CSV dışa aktarma; yıllık özet kartı. **P0 temel, M**
- D5 Başarımlar. **P2, S**

**E. Birlikte (Together)** (rakip bunu duyurdu, öncelik yüksek)
- E1 Arkadaş ekleme (Sign in with Apple + davet bağlantısı). **P1, M**
- E2 **Ortak uçuş:** bir uçuş oluştur, bağlantıyla davet et, aynı uçakta koltuk seç, yolcu durumu canlı (odakta/ayrıldı), iniş sonrası ortak bilet. Birisi ayrılırsa grup uçuşu **bozulmaz**, o kişi "indirilir" (Forest'un "ağaç ölür" baskısı yerine yumuşak sosyal sorumluluk). **P1, L**
- E3 **Herkese açık planlı uçuşlar** ("IST-TYO 09:00"): yabancılarla sessiz birlikte çalışma (body-doubling). **P1, L**
- E4 Arkadaşların uçağını haritada görme; konum paylaşılmaz, sadece sanal rota. **P1, M**
- E5 Gizlilik, engelleme, raporlama, çocuk güvenliği. **P1, M**

**F. Sistem entegrasyonu**
- F1 Odak engelleme: yumuşak (v1), sert (karar bekliyor). **P0 yumuşak / P2 sert, M-L**
- F2 macOS Focus filtresi, Kısayollar/App Intents, küresel kısayol. **P0 temel, M**
- F3 WidgetKit masaüstü widget'ı. **P1, M**
- F4 iCloud eşitleme (bilet, istatistik), **evrensel satın alma** + **Aile Paylaşımı.** **P0, M**
- F5 Bildirimler (boarding call, iniş). **P0, S**
- F6 Yerelleştirme: EN, TR öncelik; sonra DE, JA, KO, ZH. **P0 (EN+TR), M**
- F7 Erişilebilirlik: VoiceOver, hareketi azalt, kontrast, klavye ile tam kullanım. **P0, M**
- F8 **Harita adlandırma politikası:** bölgeye göre etiket, çekişmeli adlarda çift adlandırma ("Doğu Denizi / Japon Denizi"), Dokdo ve Filistin gösterimi. **P0, S (ama karar)**

### Sürüm planı (özet)

| Sürüm | Tema | İçerik |
|---|---|---|
| **Spike (1–2 hafta)** | Riskleri erkenden kapat | MapKit 3B kamera + enerji ölçümü, engelleme fizibilitesi, ortak uçuş arka uç seçimi, boarding→bilet→seyir akışının görsel prototipi |
| **v1.0 "Takeoff"** | Mac-first çekirdek | A1–A8, A10; B1, B3, B5; C1 temel; D1, D2 temel, D4 temel; F1 yumuşak, F2, F4, F5, F6 (EN+TR), F7, F8 |
| **v1.5 "Together"** | Sosyal | E1–E5, A9, C2, F3, çok bacaklı seyahat |
| **v2.0 "Living cabin"** | Derinlik | B2 canlı pencere, B4, C3, D3, D5, hava durumu |
| **Sonra** | Genişleme | iPhone/iPad eşlikçi (SwiftUI çoklu platform, Live Activities), Watch, sert engelleme, başka araçlar (tren) |

Kaba tahmin: tek geliştirici + Claude ile spike 1–2 hafta, v1.0 yaklaşık 6–10 hafta. Bu rakamlar kanıta değil deneyime dayanıyor, kapsam netleşince güncelleyelim.

---

## 7. Teknik mimari taslağı

- **FlightEngine (çekirdek):** `startDate`, `duration`, `route` değişmezlerinden `progress(now)` hesaplar; fazları (boarding … landing) süreye bölünmüş oranlarla üretir; uyku/kapanma/çökme sonrası bile doğru konumu gösterir. Saatlik tick yok, görünüm yenilemesi `TimelineView` / `CADisplayLink` ile düşük hızda.
- **Rota:** büyük daire ara noktaları + yanal sapma (kavis) → MapKit `MapPolyline`; kamera yön ve eğimi rota teğetinden.
- **Pencere görünümü (v2):** iki aday: (a) MapKit gerçek arazi kamerasını uçuş yönüne dik, düşük irtifa, yüksek eğimle kullanmak; (b) Metal tabanlı prosedürel gökyüzü + bulut katmanları, güneş konumu astronomik formülle. Muhtemelen ikisinin karışımı. Spike'ta enerji ve görsel kalite ölçülecek.
- **Veri:** SwiftData + CloudKit; havalimanı tabloları paket içi SQLite.
- **Ses:** `AVAudioEngine` ile katmanlı mikser; anonslar kısa, kesintisiz döngüye uygun varlıklar.
- **Satın alma:** StoreKit 2; evrensel satın alma (iPhone/iPad/Mac aynı hak), Aile Paylaşımı açık.
- **Sosyal:** istemci ↔ WebSocket odası; oda durumu (katılımcılar, koltuklar, başlangıç zamanı) sunucuda, istemci yalnızca mutlak zaman ve olayları gönderir; sunucu uçuş içeriği (görev notu) bilmez.
- **Mac özellikleri:** `MenuBarExtra`, `NSWindow.level = .floating` mini pencere, `NSWorkspace` gözlemcisi (yumuşak engelleme), `IOPMAssertion` (ekran koruyucuyu engelle), `NSWindow.occlusionState` ile görünmez render'ı durdurma.

---

## 8. Fiyatlandırma (hipotez, test edilmeli)

Gözlem: orijinal 3,99 $/ay, 18,99 $/yıl, ömür boyu 19,99–33,99 $; rakip Focus Traveller 0,99 $ / 7,99 $ / 14,99 $. Yorumcular çoğunlukla öğrenci ve fiyata duyarlı; şikayet sıklığı fiyatın kendisinden çok **neyin ücretli olduğu ve tahsilat deneyimi** üzerine.

Öneri:
- **Ücretsiz:** sınırsız uçuş (en az 10 dk), kalkış havalimanı seçimi, temel haritalar, 3–4 ses, son 30 gün geçmiş, bilet cüzdanı, yumuşak engelleme, bir pencere sahnesi.
- **Pro (tek seferlik, öneri ~19,99–29,99 $, isteğe bağlı küçük abonelik):** canlı pencere sahneleri, katmanlı ses ve anons paketleri, tam geçmiş ve dışa aktarma, ortak uçuş ev sahipliği ve herkese açık uçuşlar, widget'lar, özel temalar.
- **İlkeler:** daha önce ücretsiz verdiğimiz bir şeyi sonradan ücretliye çevirmeyiz; deneme süresi ve tahsilat tarihi ekranda açık; iade ve destek süreci görünür; Aile Paylaşımı ve evrensel satın alma açık.

Beklenti: kategori niş, geçmiş veriler mütevazı (bölüm 0, madde 7). Mac App Store'da yüksek puan ve doğru anahtar kelimeler (Mac + focus + flight) erken büyümenin ana kaynağı olur; orijinalin Çin ve Doğu Asya ağırlığına karşı Türkiye + İngilizce konuşan öğrenci pazarı ikinci fırsat.

---

## 9. Riskler, hukuk ve fikri mülkiyet

| Risk | Açıklama | Önlem |
|---|---|---|
| **Taklit / kopya** | "Aynısını yapmak" App Store inceleme yönergelerindeki taklit uygulama kuralına (4.1) ve marka/telif sorunlarına açık | İsim, ikon, çizim, ses ve UI sıfırdan; mekanik benzerlik serbest |
| **Marka** | "FocusFlight" ve benzeri isimler hâlihazırda kullanımda (en az 3 benzer isim: FocusFlight, Flight Focus, AirFocus) | Farklı ad, marka araştırması, alan adı/ağ adresi |
| **Gerçek havayolu/ittifak** | Yorumlar Star Alliance gibi sadakat programı istiyor; gerçek logolar ve markalar lisanssız kullanılamaz | Kurgusal havayolları ve ittifak |
| **Uçak modelleri** | Airbus/Boeing gibi isimler ve birebir modeller marka riski | Genel siluetler, kurgusal modeller |
| **Veri lisansı** | OurAirports kamu malı; **OpenFlights rota verisi ODbL** (atıf + paylaşım şartı), ikincil kaynaklar | Yalnızca OurAirports kullan, rotayı hesapla; OpenFlights'tan kaçın veya lisansı net uygula |
| **Harita siyaseti** | Güney Kore'den Dokdo/Doğu Denizi tepkisi, Filistin tepkisi | Etiket politikası (F8) ve test |
| **Sert engelleme / App Review** | Mac App Store kısıtları belirsiz | Spike; yumuşak engelleme ile başla |
| **Sosyal güvenlik** | Yabancılarla ortak uçuşlarda taciz/çocuk güvenliği | Sohbet yok (yalnızca durum/koltuk), engelleme/raporlama, yaş sınırı kararı |
| **Rakip hamlesi** | FocusFlight "multiplayer"ı duyurdu | Mac-first ve açık uçuşlar ile farklılaş; hızlı v1.5 |
| **Gelir** | Niş kategori | Yalın ekip, düşük sabit maliyet, ücretsiz katman ile keşif |
| **Ses/anons telifi** | Gerçek ATC kayıtları ve hazır anons paketleri lisans sorunu | Orijinal kayıt veya lisanslı ses |

---

## 10. Karar bekleyen sorular

1. **İsim ve marka:** bir isim önerelim mi? (FocusFlight kullanılamaz.)
2. **Dağıtım:** yalnızca Mac App Store, yalnızca doğrudan, ya da ikisi? Sert engelleme bunu belirler.
3. **v1'de sert engelleme şart mı?** Önerim: hayır, yumuşak engelleme + Focus filtresi.
4. **iPhone/iPad eşlikçi ne zaman?** Önerim: v2.0 sonrası; mimari baştan çoklu platforma uygun.
5. **Fiyat modeli:** tek seferlik Pro mu, abonelik mi, ikisi mi?
6. **Stack onayı:** SwiftUI yerel mi?

Sonraki adımda: görselleri/videoyu paylaşın (UI dilini birlikte çıkaracağız), stack ve kapsam onayını verin; ben **Spike**'a başlayıp Xcode projesini kurayım.

---

## 11. Kaynaklar

- FocusFlight App Store sayfaları: [Türkiye](https://apps.apple.com/tr/app/focusflight-deepfocus-timer/id6648771147), [ABD](https://apps.apple.com/us/app/focusflight-deepfocus-timer/id6648771147)
- Apple iTunes Lookup ve Customer Reviews RSS uç noktaları (puan, sürüm, desteklenen cihaz bilgisi, 1.285 yorum)
- [36Kr: Focus Flight yazısı](https://eu.36kr.com/de/p/3432666329124482)
- Apple geliştirici forumları: [ManagedSettings Mac'te yok](https://developer.apple.com/forums/thread/721295), [FamilyControls macOS](https://developer.apple.com/forums/thread/717569), [Catalyst sandbox](https://developer.apple.com/forums/thread/814446), [Catalyst Family Controls](https://developer.apple.com/forums/thread/749598)
- [WWDC23: Meet MapKit for SwiftUI](https://developer.apple.com/wwdc23/10043)
- [9to5Mac: Live Activities iPad ve Mac'te](https://9to5mac.com/2025/06/13/live-activities-are-coming-to-ipad-and-mac-heres-how-theyll-work/)
- [OurAirports veri indirmeleri](https://ourairports.com/data/), [OpenFlights verisi](https://openflights.org/data)
- Rakip kayıtları: [Focus Traveller](https://apps.apple.com/app/id1559730367), [FocusTok](https://apps.apple.com/app/id6756112463), [Flight Focus](https://apps.apple.com/us/app/-/id6749649894), [Focus Study Timer - FlightMode](https://apps.apple.com/app/focus-study-timer-flightmode/id6754469745), [AirFocus](https://appshunter.io/ios/app/airfocus-flight-focus-timer/id6752571938), [Forest](https://apps.apple.com/app/id866450515)
- [Timing: Mac için en iyi Pomodoro uygulamaları 2026](https://timingapp.com/blog/best-pomodoro-apps-for-mac/) (satıcı kaynağı, tek görüş)
- [Desktop Insights: masaüstü uygulama durumu 2026](https://desktopinsights.com/blog/state-of-desktop-app-development-2026) (ikincil kaynak)

**Doğrulanmayanlar:** FocusFlight'ın Mac'te yerel olmadığı (çıkarım), gelir rakamının tarihi, rakiplerin tam özellik ve fiyatları, Mac App Store'un engelleme tekniklerine tutumu, MapKit globe davranışının güncel macOS sürümlerinde detayı. Bunları spike'ta kapatacağız.
