# Arrow Maze — готовность к Apple Ads и измерению Premium

Проверено 7 сентября 2026. Аудит чтения: исходники, публичные витрины Apple и авторизованный App Store Connect. Код, продажи, настройки и релиз не менялись. В корне и проверенных родительских директориях, а также по `rg --files -g AGENTS.md`, AGENTS.md не найден.

## Вывод для кампании

Приложение доступно для рекламы. Локализация подходит для запуска в Канаде; фактические канадские цены Premium — **C$7.99 в неделю / C$39.99 в год**. Подтверждённой истории окупаемости пока нет: за 30 августа–5 сентября ASC показывает **4 app units во всём мире и $0 proceeds**; Канада — **0 units**. Покупки Premium пока нельзя надёжно связать с конкретной рекламной установкой по текущей локальной реализации. Первый бюджет нужно оценивать как ограниченный эксперимент спроса и покупок, без обещания положительного ROI.

## Что подтверждено в опубликованном приложении

- Apple ID **6800708435**, bundle ID `zimma.MazeArrows`, версия **1.0**, release **1 сентября 2026**. ASC: **Ready for Distribution**, build **1**.
- Public US lookup: **Free**, iOS **17+**, iPhone/iPad, ~37.8 MB, Game Center, возраст **4+**, **0 ratings** в US. [Публичная страница](https://apps.apple.com/us/app/arrow-maze-logic-puzzle/id6800708435), [Apple lookup](https://itunes.apple.com/lookup?id=6800708435&country=us).
- ASC: группа **Arrow Maze Premium (22305547) Approved**; **Annual 6800860897** (`zimma.MazeArrows.premium.annual`) и **Weekly 6800858748** (`zimma.MazeArrows.premium.weekly`) оба **Approved**. Группа имеет 13 локализаций, включая English (Canada) и French (Canada). Billing Grace Period: **16 days**, Only Paid-to-Paid Renewals, Production and Sandbox; Streamlined Purchasing: **Turned On**.
- Публичный список языков: EN, FR, DE, HI, ID, JA, KO, PT, RU, ES, TH, ZH. Это языки бинаря, не количество полноценных локалей витрины.
- В ASC и публичной US-витрине первые пять screenshot titles: **Your photo, your maze → Find the free arrow → Watch it all unravel → 240 levels, 7 worlds → Fresh maze every day**. Первым продаётся Photo Maze, тогда как core search intent обычно «arrow puzzle/tap away»; это гипотеза возможного снижения конверсии core-запросов, а не измеренный эффект.
- Live описание обещает 240 уровней, 7 миров, Daily, 3 Daily Quests, Zen, Photo Maze с Premium, Game Center и темы. Возможность обхода/завершения onboarding и точное соответствие бинаря текущим исходникам не проверялись на устройстве.

### Публичные действующие цены

Все ниже прочитаны непосредственно из региональных Apple App Store страниц 7 сентября; это gross retail цены, а не developer proceeds. Доступность страницы не доказывает доступность рекламного аукциона или покупку на устройстве.

| Страна | Weekly | Annual | Источник |
|---|---:|---:|---|
| Канада | C$7.99 | C$39.99 | [CA](https://apps.apple.com/ca/app/id6800708435) |
| США | US$5.99 | US$29.99 | [US](https://apps.apple.com/us/app/id6800708435) |
| Великобритания | £5.99 | £29.99 | [GB](https://apps.apple.com/gb/app/id6800708435) |
| Австралия | A$9.99 | A$49.99 | [AU](https://apps.apple.com/au/app/id6800708435) |
| Германия | €6.99 | €34.99 | [DE](https://apps.apple.com/de/app/id6800708435) |
| Франция | €6.99 | €34.99 | [FR](https://apps.apple.com/fr/app/id6800708435) |
| Испания | €6.99 | €34.99 | [ES](https://apps.apple.com/es/app/id6800708435) |
| Япония | ¥1,000 | ¥5,000 | [JP](https://apps.apple.com/jp/app/id6800708435) |
| Корея | ₩9,900 | ₩49,000 | [KR](https://apps.apple.com/kr/app/id6800708435) |
| Тайвань | NT$190 | NT$990 | [TW](https://apps.apple.com/tw/app/id6800708435) |
| Бразилия | R$39.90 | R$199.90 | [BR](https://apps.apple.com/br/app/id6800708435) |
| Мексика | MX$129 | MX$599 | [MX](https://apps.apple.com/mx/app/id6800708435) |

Raw: `raw/readiness/2026-09-07/app-store-{country}.html`, `lookup-us.json`, `public-storefront-summary.json`.

## Фактическая стартовая база ASC

Проверка авторизованного UI Trends, **Last 7 Days: Aug 30–Sep 5, 2026; UTC**; Parent App = Arrow Maze: Logic Puzzle, 6800708435.

| Срез | Результат |
|---|---:|
| Proceeds, весь мир | **US$0**, no sales for selected period/filter |
| Units, весь мир | **4** |
| Units, France | **3** |
| Units, Switzerland | **1** |
| Units, Canada | **0** |

Это единицы в Sales and Trends; не sessions, retention и не оценка рекламных установок. Нельзя выводить страну с лучшим ROI из четырёх установок.

Subscription Summary, App = Arrow Maze, Ending Sep 5: Active Paid Subscriptions, Daily Subscription Units/Sales, Events, Top Subscriptions показывают **There isn't any data**. В Summary также присутствовал общий баннер unexpected error; поэтому этот экран не используем как независимое доказательство точного нуля активных подписчиков. Надёжнее подтверждённые $0 proceeds в Sales за всё время, прошедшее с релиза до Sep 5.

`asc auth status` отдельно: App Store Connect API-профилей нет, env credentials отсутствуют. Apple Ads OAuth-профиль не заменяет ASC API доступ. Авторизация браузера есть; для дальнейших проверок достаточно UI, без создания новых ключей.

## Локализация текущего кода

`MazeArrows/MazeArrows/Localizable.xcstrings`: 476 entries; 474 помечены переводимыми. Base `en`; 14 переводных локалей: **de, en-IN, es, es-MX, fr, hi, id, ja, ko, pt-BR, pt-PT, ru, th, zh-Hant**.

- В каждой переводной локали **472** присутствующих ключа, все string units `translated`, пустых значений нет.
- Два пустых entries: `Manage subscription`, `Subscription renews automatically until canceled.`. Эти формулировки используются как fallback в `OnboardingCopy`, фактические ключи `onboarding.paywall.manage_subscription` и `onboarding.paywall.auto_renewal` есть в отдельных Onboarding.strings. Это технический долг каталога, не доказанный видимый English fallback.
- Один stale entry: `Shows Premium plans.`. `LocalizationCompletenessTests` по текущей логике обнаружит эти три проблемы; тесты не запускались, каталог проверен независимо JSON-скриптом.
- Все 14 `*.lproj/Onboarding.strings` содержат ровно **81** ключ, совпадающий с активными ключами `OnboardingCopy.swift`.
- `knownRegions` дополнительно декларирует en-AU/en-GB; это не отдельные полноценные наборы строк, английская база покрывает их.
- Локальный ASO-пакет: 12 полных storefront locales en-US/GB/CA/AU, de-DE, fr-FR, es-ES/MX, pt-BR, ja, ko, zh-Hant. fr-CA имеет только screenshots и subscriptions. Старые документы о «8 готовых локалях» устарели.

## Продукт и монетизация — только текущие исходники

Сильные стороны: `Data/levels.json` действительно содержит **240** уровней, `Models/Chapter.swift` — 7 глав; Photo Maze из пользовательского фото, combos, ежедневные цели и Zen формируют отличия от простого arrow clone.

- `Data/PremiumStore.swift`: production IDs `zimma.MazeArrows.premium.weekly` и `.annual`, StoreKit 2, проверяемые transactions, restore, entitlement refresh. Локальный `.storekit`: $5.99/$29.99, no introductory offer; live prices выше проверены отдельно.
- `PremiumAccessPolicy`: Premium даёт unlimited Photo Maze, unlimited hints и 3 закрытые темы (sakura/atlas/nordic). `AdService` прекращает рекламу для Premium.
- `PhotoMazeGenerationPolicy.standard`: **5 бесплатных генераций за всё время**, затем rewarded credits или Premium; `SettingsView` открывает paywall независимо от feature flag premiumOffersEnabled.
- `FeatureFlags`: onboardingPaywallAvailable **false**, premiumOffersEnabled **false**, adsAvailable/interstitialAdsAvailable **true**, photoMazeSharingAvailable **false**. Нельзя рекламировать sharing как доступную функцию.
- Onboarding: 4 tutorial boards → starter reward → optional notification prompt → theme picker → handoff к level 5; Skip доступен на tutorial. Платёжной стены до gameplay нет. С другой стороны, путь до первых настоящих уровней длинный и покупка Premium не предлагается автоматически — риск медленной покупки на маленьком рекламном объёме.
- Interstitial policy: первая возможность после 5 учитываемых первых campaign clears; затем каждые 4, минимум 180 секунд между показами. Это не «каждые 180 секунд» и не доказательство фактических показов в опубликованном build.

## Измерение покупки и ROI

Критичное ограничение: `Data/Analytics.swift:194–204` использует **NoopAnalyticsClient**. В release он не отправляет ничего. Текущие enums имеют игровые/экономические события, но не полный purchase/revenue funnel. По Swift/project поиску нет `AdServices`, `AAAttribution`, MMP (AppsFlyer/Adjust/Tenjin и т.п.), внешнего analytics SDK или установки другого Analytics.client; единственная SPM-зависимость — Google Mobile Ads. SKAdNetworkItems в Info.plist обслуживают рекламный SDK и не заменяют Apple Ads → Premium attribution.

Apple Ads измеряет App Store verified downloads после клика/просмотра. Post-install events требуют отдельной интеграции. Это разные уровни данных: [Apple MMP help](https://ads.apple.com/app-store/help/attribution/0027-mobile-measurement-providers). AdServices использует token из app и серверный запрос атрибуции: [официальная документация](https://developer.apple.com/documentation/AdServices/).

**Минимум без нового релиза:** одна страна/одна кампания; ежедневно Ads spend, taps, new downloads и redownloads отдельно; ASC country-level first-time downloads, Premium new purchases/renewals/refunds и proceeds; стартовая база выше. Изменение совокупных канадских proceeds после запуска — ориентир, не точная выручка рекламной когорты и не keyword ROAS. Не приписывать рекламе весь органический доход. ASC даёт предварительные proceeds, финальные доступны в финансовых отчётах: [Apple reporting](https://developer.apple.com/help/app-store-connect/measure-app-performance/download-and-view-reports).

**Для точного измерения в будущем:** AdServices attribution при первом запуске + собственный installation ID, событие verified purchase со SKU/transaction ID/value/currency и связью с установкой; server-side учёт renewals/refunds (или готовый MMP/subscription service). Это требует разработки, проверки privacy и нового релиза; не выполнялось в рамках рекламного запуска.

Решение об окупаемости считать по **net proceeds за фиксированное окно D7/D30**, а не gross цене. Предельный CPI = paid conversion × net LTV на платящего (+ ad LTV, если цель включает рекламу). Реальные conversion/LTV отсутствуют; подстановка отраслевой медианы не создаст доказательство ROI.


## Дополнение: APP_NOT_CATEGORIZED при создании кампании

Root сообщил статус APP_NOT_CATEGORIZED для CA-кампании 2144620520. Повторная публичная проверка Apple lookup CA 7 сентября показывает `primaryGenreName: Games`, `primaryGenreId: 6014`, `genres: [Games, Casual, Puzzle, Entertainment]`, `genreIds: [6014, 7003, 7012, 6016]`. Категория присутствует в опубликованной канадской витрине. Raw: `raw/readiness/2026-09-07/lookup-ca-category-check.json`. [Apple lookup CA](https://itunes.apple.com/lookup?id=6800708435&country=ca).

Официальная документация определяет APP_NOT_CATEGORIZED как отсутствие назначенной категории: [CampaignServingStateReasons](https://developer.apple.com/documentation/apple_ads/campaignservingstatereasons). Она не раскрывает внутреннюю стадию категоризации и не даёт гарантированный срок устранения. Поэтому версия об ожидании Apple Ads review/синхронизации — вывод по сочетанию состояний, а не подтверждённый точный диагноз. На основании публичной витрины нет признака, что локально отсутствует категория, которую требуется добавить.

В дополнительном subagent-turn CUA больше не предоставил браузер (browsers: []); попытка открыть App Information вернула Browser is not available. Primary/secondary поля ASC в этом дополнении повторно не прочитаны. Для точной проверки у root есть ранее наблюдавшаяся ссылка https://appstoreconnect.apple.com/apps/6800708435/distribution/info. Ничего не менялось.
