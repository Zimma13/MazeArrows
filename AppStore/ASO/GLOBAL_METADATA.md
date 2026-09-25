# Глобальные поля App Store Connect

## Рекомендуемая классификация

- Primary Category: `Games`
- Games Subcategory 1: `Puzzle`
- Games Subcategory 2: `Casual`
- Secondary Category: не заполнять для первого релиза
- Primary Language: `English (U.S.)`
- Content Rights: игра не показывает и не предоставляет сторонний контент; пользовательское фото обрабатывается только как источник Photo Maze
- Made for Kids: `No`
- License Agreement: Apple Standard EULA

Возрастной рейтинг нужно получить через актуальную анкету App Store Connect. Для игры нет насилия, азартных игр, сексуального контента, открытого веб-доступа или пользовательского общения; не ставить число рейтинга вручную до завершения анкеты.

## Выпуск и доступность

- Price: `Free` — если основной продукт действительно распространяется бесплатно с опциональной подпиской
- Release: `Manually release this version` для первой версии, чтобы синхронизировать Game Center, подписки и локализованные материалы
- Availability: локали первой волны не требуют ограничивать распространение двенадцатью странами; приложение можно открыть во всех территориях, где готовы договоры, налоги, Privacy и локальное регулирование
- App Tags: если App Store Connect предлагает теги, выбрать только релевантные варианты уровня `Puzzle`, `Logic`, `Brain`, `Casual`, `Relaxing`; не выбирать нерелевантные теги ради охвата
- Custom Product Pages и Product Page Optimization: запускать после появления достаточного трафика; первым тестом сравнить «core puzzle/combo» против «Photo Maze»

## Отдельные обязательные анкеты

- App Privacy: заполнить по фактическому сбору данных и SDK; ASO-тексты не заменяют Privacy Nutrition Label
- Export Compliance: ответить по фактическому использованию шифрования в release build
- Digital Services Act: завершить trader/non-trader disclosure для продаж в ЕС
- Accessibility Nutrition Labels: отмечать только проверенные возможности, не делать неподтверждённых заявлений
- Korea/China/Vietnam: перед включением соответствующей доступности проверить локальные требования к играм; Traditional Chinese в первой волне рассчитан прежде всего на Taiwan/Hong Kong, а не на материковый Китай

## Обязательные значения, которых пока нет в проекте

Заменить перед отправкой:

- `SUPPORT_URL`: `https://kinapp.dev/arrowmaze/support/`
- `PRIVACY_POLICY_URL`: `https://kinapp.dev/arrowmaze/privacy/`
- `MARKETING_URL`: `https://kinapp.dev/arrowmaze/`
- `TERMS_URL`: `https://kinapp.dev/arrowmaze/terms/`
- Copyright: `Dmitrii Stepanov`
- App Review contact: Dmitrii Stepanov, `support@kinapp.dev`, `+66925175007`

Support URL должен открывать реальную страницу с контактными данными. Privacy Policy URL обязателен для iOS. Требования: [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information), [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information).

## App Review Notes — черновик

```text
Arrow Maze is a single-player arrow-path puzzle. No account is required.

To review the core game:
1. Launch the app and complete or skip onboarding.
2. Tap Play for the 240-level campaign.
3. Daily, Quests, Zen, Photo Maze, Achievements, and Settings are available from the main menu.

Photo Maze uses the system photo picker. Select a photo with a clear subject, adjust the silhouette if needed, then tap Play.

Game Center authentication uses Apple's system UI. Leaderboards and achievements are available from the Achievements and Settings screens.

The app offers weekly and annual auto-renewable Premium subscriptions. Purchase and Restore use StoreKit. Prices and subscription periods are supplied by the App Store. Version 1.0 has no introductory offer or free trial.
```

## Подписки — технические поля

- Subscription Group Reference Name: `Arrow Maze Premium`
- Weekly Reference Name: `Arrow Maze Premium Weekly`
- Weekly Duration: `1 week`
- Annual Reference Name: `Arrow Maze Premium Annual`
- Annual Duration: `1 year`
- Intro Offer: отсутствует у Weekly и Annual для версии 1.0
- Review Screenshot: экран paywall с обоими планами, Restore, Terms и Privacy
- Promotional Image: требуется только если подписка будет продвигаться на странице продукта; 1024 × 1024, PNG/JPG, RGB, без скруглённых углов

Не копировать тестовые product IDs из локальной StoreKit-конфигурации в production без проверки в App Store Connect.
