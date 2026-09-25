# Arrow Maze — юридические страницы для сайта

В папке лежат два простых Markdown-документа и самостоятельная HTML-страница поддержки без внешних библиотек, cookies и аналитики:

- `privacy-policy.md` — Privacy Policy;
- `terms-of-use.md` — дополнительные Terms of Use, работающие вместе с Apple Standard EULA;
- `support.html` — обязательная страница поддержки с контактами.

## Что заменить перед публикацией

Во всех файлах выполнить замену следующих значений:

| Placeholder | Что поставить |
|---|---|
| `{{LEGAL_NAME}}` | Точное имя продавца/правообладателя из Apple Developer / App Store Connect |
| `{{SUPPORT_EMAIL}}` | Реальный email поддержки, который регулярно проверяется |
| `{{POSTAL_ADDRESS}}` | Юридический или почтовый адрес, который разрешено публиковать |
| `{{WEBSITE_URL}}` | Главный адрес сайта, например `https://example.com` |
| `{{PRIVACY_URL}}` | Полный URL Privacy Policy |
| `{{TERMS_URL}}` | Полный URL Terms of Use |
| `{{SUPPORT_URL}}` | Полный URL Support page |
| `{{GOVERNING_LAW}}` | Право страны/региона регистрации продавца |
| `{{COURTS}}` | Компетентные суды по месту регистрации продавца |

Пример рекомендуемых адресов:

```text
https://YOUR-DOMAIN.com/maze-arrows/privacy
https://YOUR-DOMAIN.com/maze-arrows/terms
https://YOUR-DOMAIN.com/maze-arrows/support
```

Не публиковать страницы, пока на них остался хотя бы один `{{PLACEHOLDER}}`. Быстрая проверка:

```bash
rg '\{\{' AppStore/Legal
```

## Что добавить после загрузки на сайт

1. App Store Connect → **App Information → Privacy Policy URL**: `{{PRIVACY_URL}}`.
2. App Store Connect → **iOS App Version → Support URL**: `{{SUPPORT_URL}}`.
3. App Store Connect → **iOS App Version → Marketing URL**: `{{WEBSITE_URL}}` или отдельная страница Arrow Maze; поле необязательное.
4. ✅ В приложении используются опубликованные Privacy и Terms URL на `kinapp.dev`.
5. В paywall направить **Terms of Use** на `{{TERMS_URL}}`, а **Privacy Policy** на `{{PRIVACY_URL}}`.
6. В Settings добавить постоянно доступные ссылки на Privacy, Terms и Support. Одной ссылки только в онбординге недостаточно: после его завершения пользователь тоже должен легко открыть политику.
7. Оставить **Apple Standard EULA** в App Store Connect. Наш `terms-of-use.md` прямо указывает, что дополняет стандартную лицензию Apple, а не подменяет её.

## На чём основана Privacy Policy

Документ отражает текущий код версии 1.0:

- аккаунта Arrow Maze и собственного сервера нет;
- встроены Google Mobile Ads и Google User Messaging Platform; рекламные и диагностические категории должны быть отражены в App Privacy;
- персонализация рекламы и Google publisher first-party ID отключены, ATT не запрашивается;
- прогресс и настройки сохраняются локально через UserDefaults;
- Photo Maze получает только выбранное через системный Photos Picker изображение, обрабатывает его на устройстве и не загружает;
- sharing и импорт Photo Maze отключены релизным флагом до V2 и не описываются как доступные в публичных документах версии 1.0;
- уведомления локальные, push token на сервер не отправляется;
- Game Center и покупки обрабатываются сервисами Apple; доступный приложению restriction status используется на устройстве, чтобы выбрать возрастной режим Google consent/ads SDK до рекламного запроса.

Если позже появится отдельная аналитика, mediation, персонализированная реклама, ATT, push-сервер, облачное сохранение, аккаунты или backend, Privacy Policy, `PrivacyInfo.xcprivacy` и App Privacy в App Store Connect нужно обновить **до** выпуска соответствующей сборки.

## App Privacy сейчас

Для текущего кода ответ в App Store Connect: **Yes, data is collected from this app**. По privacy manifest подключённых Google SDK и документации Google нужно раскрыть как минимум `Coarse Location`, `Device ID`, `Advertising Data`, `Product Interaction`, `Crash Data`, `Performance Data` и `Other Diagnostic Data` с фактическими целями SDK. Собственные игровые данные и фотографии, которые остаются только на устройстве, collected для Privacy Label не считаются. Текущая конфигурация отключает персонализированную рекламу и publisher first-party ID и не запрашивает ATT; при изменении этой конфигурации ответы о tracking требуется пересмотреть до выпуска сборки.

Это технически подготовленный release-драфт, а не индивидуальная юридическая консультация. Перед коммерческим релизом желательно, чтобы название юрлица, адрес, применимое право, возрастные положения и потребительские ограничения проверил юрист страны регистрации продавца.
