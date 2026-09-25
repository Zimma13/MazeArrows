# Блокеры перед отправкой в App Review

## P0 — обязательные URL

1. ✅ Опубликованная Privacy Policy открывается по `https://kinapp.dev/arrowmaze/privacy/`.
2. ✅ Опубликована реальная Support page с рабочим email: `https://kinapp.dev/arrowmaze/support/`.
3. ✅ Актуальные Privacy, Support и Marketing URL внесены во все 12 `metadata.txt`.
4. ✅ Юридические ссылки в `OnboardingFlowView.swift` заменены на опубликованные URL.
5. Проверить, что Privacy и Terms открываются из paywall на физическом устройстве.

App Store Connect требует Privacy Policy URL для iOS и обязательный Support URL, ведущий к фактическим контактам: [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information), [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information).

## P0 — Premium должен выдавать заявленные права

На момент подготовки ASO `PremiumStore` используется для покупки и восстановления в онбординге, но `isPremium` не управляет доступом к Photo Maze, подсказкам и темам в основном приложении. Кроме того:

- локальная конфигурация использует product IDs с суффиксом `.test`;
- `FeatureFlags.premiumOffersEnabled = false`;
- Photo Maze открывается из главного меню без проверки Premium;
- нет подтверждённой логики безлимитных подсказок и Premium-тем после покупки.

До отправки подписок на Review нужно либо реализовать и протестировать все заявленные права, либо удалить Premium-абзацы из описаний и не отправлять подписки в первой версии. Оставлять платный продукт без фактически выдаваемых преимуществ нельзя.

## P1 — финальная проверка витрины

- Проверить занятость каждого локализованного App Name прямо в App Store Connect.
- Вставить тексты и повторно проверить счётчики в интерфейсе App Store Connect.
- Вычитать CJK и европейские тексты носителями перед закупкой трафика.
- Загрузить минимум обязательные iPhone/iPad screenshot sets; первые три изображения должны соответствовать `screenshots.txt`.
- Для версии 1.0 выбран запуск без free trial: проверить, что у production Weekly и Annual нет активного или запланированного introductory offer.
- Проверить, что 240 уровней, 7 миров, Daily, Quests, Zen, Photo Maze и Game Center доступны в выбранном release build.
