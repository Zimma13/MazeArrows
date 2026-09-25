# Arrow Maze Premium — что нужно добавить

Покупка и восстановление транзакций реализованы в `PremiumStore`. С 13 августа 2026 года подтверждённый entitlement подключён через единый `PremiumAccessPolicy` к подсказкам, темам и безлимитному Photo Maze.

Текущий статус:

- ✅ Free получает 5 успешных генераций Photo Maze, затем добровольную rewarded-рекламу за одну дополнительную; Premium — безлимит;
- ✅ Premium-подсказки не расходуют запас, но учитываются в статистике уровня;
- ✅ Sakura, Atlas и Nordic закрыты для Free;
- ✅ после окончания подписки Premium-тема безопасно заменяется на Aurora Light;
- ✅ переиспользуемый paywall открывается из Photo Maze, подсказок, тем и Settings;
- ✅ после покупки продолжается исходное действие: создаётся запрошенный Photo Maze, применяется тема или выполняется подсказка;
- ⏳ следующим этапом остаётся полноценный раздел управления подпиской и постоянные юридические ссылки в Settings.

## 1. Зафиксировать состав Premium

Рекомендуемый состав, уже совпадающий с paywall и App Store-текстами:

- **Unlimited Photo Maze creations** — Premium (5 успешных генераций доступны Free);
- **Unlimited hints** — Premium;
- **Premium themes** — Premium;
- недельная и годовая подписки дают одинаковые возможности, отличается только период и цена.

Рекомендуемое разделение тем:

- Free: `Aurora Light`, `Midnight Neon`, `Petal Pastel`;
- Premium: `Sakura`, `Atlas`, `Nordic`.

Не добавлять в описание **No Ads**, ежедневные Premium-монеты или Unlimited Zen, пока эти преимущества не реализованы и не включены в release build.

## 2. Production-продукты App Store Connect

Создать или окончательно проверить:

- Subscription Group: `Maze Arrows Premium`;
- Weekly product ID: рекомендуется `zimma.MazeArrows.premium.weekly`;
- Annual product ID: рекомендуется `zimma.MazeArrows.premium.annual`;
- Duration: 1 week / 1 year;
- обе подписки открывают один и тот же Premium entitlement;
- introductory offer отсутствует у Weekly и Annual для версии 1.0;
- цены по территориям;
- все 12 локализаций из `AppStore/ASO/*/subscriptions.txt`;
- App Review Screenshot с paywall, ценами, Restore, Terms и Privacy;
- Review Notes с инструкцией, где открыть paywall и как проверить Premium-функции.

После создания продуктов заменить `.test` IDs в `MazeArrows/MazeArrows/Data/PremiumStore.swift`. Product IDs в коде и App Store Connect должны совпадать посимвольно.

## 3. Единая проверка entitlement

Не разбрасывать самостоятельные проверки по экранам. Добавить единый слой наподобие `PremiumAccessPolicy`, который получает актуальный `PremiumStore.isPremium` и отвечает:

```text
hasUnlimitedPhotoMaze
hasUnlimitedHints
canUseTheme(themeID)
```

Все Premium-возможности должны опираться на проверенную StoreKit 2 entitlement, а не на локальный boolean в UserDefaults.

## 4. Photo Maze

Файлы: `Views/MainMenuView.swift`, `Views/PhotoLevelView.swift` и переиспользуемый Premium paywall.

Реализовано:

- редактор и первые 5 успешных генераций доступны Free без замка;
- лимит списывается только после успешной сборки уровня;
- после лимита предлагается явно выбранная rewarded-реклама за 1 генерацию или Premium без ограничений;
- рекламный кредит выдаётся в callback Google и сохраняется, если последующая сборка не удалась;
- реклама не запускается автоматически во время обработки фотографии;
- показан реальный прогресс сборки 0–100% без искусственной задержки;
- после успешной покупки запрошенная генерация продолжается автоматически;
- Restore Purchases сразу возвращает безлимитный доступ.

## 5. Unlimited hints

Файлы: `ViewModels/GameViewModel.swift`, `Data/ProgressStore.swift`, `Views/GameView.swift`, `Views/ResourceOfferSheet.swift`.

Добавить:

- при активном Premium подсказка работает, даже если `hintsCount == 0`;
- при Premium не уменьшать `hintsCount`;
- подсказка по-прежнему увеличивает `hintsUsed`, чтобы задания «без подсказок», звёзды и достижения оставались честными;
- вместо числа можно показывать `∞` и корректный accessibility label;
- бесплатный пользователь сохраняет текущую механику расходования и покупки за монеты;
- кнопка `Premium — unlimited` в `ResourceOfferSheet` должна реально открывать paywall;
- после покупки закрыть offer sheet и выполнить ранее запрошенную подсказку;
- `FeatureFlags.premiumOffersEnabled` удалить или включить только после подключения рабочего действия.

## 6. Premium themes

Файлы: `Data/SettingsStore.swift`, `Views/SettingsView.swift`, `Onboarding/OnboardingFlowView.swift`.

Добавить:

- явное свойство `isPremiumTheme` или список Premium themes;
- замок и метку Premium для `Sakura`, `Atlas`, `Nordic`;
- бесплатному пользователю по нажатию показывать paywall, не применяя тему;
- после покупки применять выбранную тему;
- если подписка закончилась, а сохранена Premium-тема, безопасно переключить на `Aurora Light`;
- не показывать в онбординге Premium-тему как бесплатный подарок, если это не отдельное намеренное предложение.

## 7. Экран Premium после онбординга

Paywall сейчас живёт внутри onboarding-flow. Нужен переиспользуемый экран, который можно открыть:

- из Photo Maze;
- при отсутствии подсказок;
- при выборе Premium-темы;
- из Settings через пункт `Maze Arrows Premium`.

На нём всегда должны быть:

- недельный и годовой планы с ценой из StoreKit;
- период оплаты;
- текущую цену, период и автопродление до подтверждения покупки;
- явная кнопка покупки;
- Restore Purchases;
- Terms of Use;
- Privacy Policy;
- возможность закрыть paywall;
- сообщение для pending, cancelled, failed и successful purchase.

## 8. Settings и управление подпиской

Добавить в Settings раздел Premium:

- текущий статус: Free / Premium;
- Restore Purchases;
- Manage Subscription через системный интерфейс Apple;
- Privacy Policy;
- Terms of Use;
- Support.

Ссылки должны быть доступны всегда, а не только во время первого онбординга.

## 9. Синхронизация состояния

Проверить:

- `Transaction.currentEntitlements` при старте;
- `Transaction.updates` во время работы;
- возврат приложения из background;
- покупку на другом устройстве и Restore;
- refund/revocation;
- expiration и billing retry;
- Ask to Buy / pending;
- работу без сети: не снимать уже подтверждённый действующий entitlement из-за одного сетевого сбоя;
- смену Apple Account.

## 10. Тесты перед Review

Обязательные сценарии:

1. Новый бесплатный пользователь видит закрытые функции, но может играть без покупки.
2. Weekly purchase открывает все три преимущества.
3. Annual purchase открывает те же преимущества.
4. Weekly и Annual не имеют introductory offer; покупка списывается сразу.
5. Cancelled purchase ничего не открывает.
6. Pending purchase показывает ожидание и не даёт ложного доступа.
7. Restore после переустановки возвращает доступ.
8. Expired/refunded subscription закрывает Premium и возвращает бесплатную тему.
9. Unlimited hints не тратят запас, но считаются использованными в статистике уровня.
10. Покупка из контекстного paywall возвращает пользователя именно к Photo Maze, подсказке или теме.
11. Terms, Privacy и Support открываются на iPhone и iPad.
12. Product IDs, названия и преимущества полностью совпадают с App Store Connect.

## 11. Что не надо добавлять

- собственную регистрацию или сервер только ради StoreKit;
- локальный `isPremium = true` как источник прав;
- внешнюю оплату на сайте;
- фиксированные цены в коде или описании App Store;
- ATT-запрос, пока нет cross-app tracking;
- рекламный SDK до обновления Privacy Policy, Privacy Manifest и App Privacy.
