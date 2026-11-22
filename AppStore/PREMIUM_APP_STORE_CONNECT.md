# Arrow Maze Premium — App Store Connect

> Архив нативной версии 1.x. Порядок завершения подписок и выпуска платной 2.0 описан в [журнале версии](../VERSION_2.md).

Актуальная конфигурация для первого релиза, созданная 13 августа 2026 года.

## Идентификаторы

- Subscription Group Reference Name: `Arrow Maze Premium`
- Subscription Group ID: `22305547`
- Weekly Reference Name: `Arrow Maze Premium Weekly`
- Weekly Product ID: `zimma.MazeArrows.premium.weekly`
- Weekly Apple ID: `6800858748`
- Annual Reference Name: `Arrow Maze Premium Annual`
- Annual Product ID: `zimma.MazeArrows.premium.annual`
- Annual Apple ID: `6800860897`

Обе подписки находятся на Level 1 и открывают один и тот же набор Premium-функций. Пользователь может иметь только одну из них одновременно.

## Планы и цены

- Weekly: 1 week, базовая цена США — $5.99.
- Weekly introductory offer: отсутствует для версии 1.0; списание начинается сразу после подтверждения покупки.
- Annual: 1 year, upfront, базовая цена США — $29.99.
- Для остальных storefront используются автоматически рассчитанные Apple эквивалентные цены.
- Доступность: 175 стран и регионов; новые storefront добавляются автоматически.
- Family Sharing: выключен.

## Локализации

У группы и обоих продуктов добавлены:

- Chinese (Traditional)
- English (Australia)
- English (Canada)
- English (U.K.)
- English (U.S.)
- French
- French (Canada)
- German
- Japanese
- Korean
- Portuguese (Brazil)
- Spanish (Mexico)
- Spanish (Spain)

Тексты продуктов находятся в `AppStore/ASO/archive/1.0/subscriptions/<locale>.txt`.

## Общие настройки

- Billing Grace Period: 16 days.
- Eligible Subscribers: Only Paid-to-Paid Renewals.
- Environments: Production and Sandbox.
- Streamlined Purchasing: On.
- Paid Apps Agreement: Active.
- Bank Account: Active.
- Tax Forms: Active.

## Что остаётся перед App Review

1. Проверить немедленное списание Weekly и Annual, Restore, expiration, refund, billing retry и grace period в StoreKit Testing и Sandbox; убедиться, что ни один план не предлагает trial.
2. ✅ Подтверждённый entitlement открывает Photo Maze, unlimited hints и Premium themes.
3. Сделать App Review Screenshot реального paywall на устройстве или симуляторе. На кадре должны быть планы, StoreKit-цены, Restore, Terms и Privacy.
4. ✅ Review Notes заполнены для Weekly и Annual: указан маршрут до paywall,
   Premium-функции, Restore, Terms и Privacy.
5. Добавить обе подписки к версии 1.0 и отправить их вместе с первым билдом приложения.

Не нажимать `Add for Review`, пока пункты выше не проверены: первая группа подписок отправляется вместе с новой версией приложения.
