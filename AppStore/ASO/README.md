# Arrow Maze — ASO первой волны

Готовый пакет метаданных для 12 локалей первого релиза. Тексты основаны на фактической версии игры: 240 уровней, 7 миров, Daily Puzzle, 3 ежедневных задания, Zen, Photo Maze, серии, достижения и таблицы Game Center.

## Локали

1. `en-US` — English (U.S.)
2. `ja` — Japanese
3. `de-DE` — German
4. `ko` — Korean
5. `zh-Hant` — Traditional Chinese
6. `pt-BR` — Portuguese (Brazil)
7. `es-MX` — Spanish (Mexico)
8. `fr-FR` — French (France)
9. `en-GB` — English (U.K.)
10. `en-CA` — English (Canada)
11. `en-AU` — English (Australia)
12. `es-ES` — Spanish (Spain)

В каждой папке:

- `metadata.txt` — Name, Subtitle, Promotional Text, Keywords и URL-поля;
- `description.txt` — готовое описание;
- `screenshots.txt` — порядок и продающие подписи для 5 скриншотов первого релиза;
- `app-preview.txt` — сценарий App Preview;
- `subscriptions.txt` — локализация группы, недельного и годового Premium.

Дополнительная локаль `fr-CA` пока содержит только `subscriptions.txt` и
`screenshots.txt`. Для скриншотов она повторно использует нейтральный
французский текст `fr-FR` и не входит в 12-локальный валидатор полной ASO-
метадаты.

## Как переносить в App Store Connect

1. Сначала заполнить обязательные глобальные поля из `GLOBAL_METADATA.md`.
2. В **App Information → Localizations** перенести `APP_NAME` и `SUBTITLE`.
3. В **iOS App → Version → Localizations** перенести `PROMOTIONAL_TEXT`, `description.txt`, `KEYWORDS`, Support URL и Marketing URL.
4. Загрузить локализованные скриншоты по плану `screenshots.txt`.
5. В **Subscriptions** добавить локализации из `subscriptions.txt`.
6. Запустить `ruby validate_aso.rb` перед вставкой и ещё раз после любых правок.

## Принцип ключей

Название, подзаголовок и поле Keywords не повторяют одни и те же слова. В Keywords нет пробелов после запятых, названий конкурентов, названия категории и нерелевантных запросов. Поле ограничено 100 UTF-8 байтами, поэтому CJK-наборы намеренно короче визуально.

Apple ограничивает название и подзаголовок 30 символами, Promotional Text — 170 символами, описание — 4000 символами, Keywords — 100 байтами. Promotional Text не участвует в поисковом ранжировании, поэтому он написан для конверсии, а не как список ключей. Источники: [Creating your product page](https://developer.apple.com/app-store/product-page/), [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information), [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information).

## Важно перед публикацией

- Support, Marketing, Privacy Policy и Terms используют опубликованные страницы `kinapp.dev`.
- Японский, корейский, Traditional Chinese, французский, немецкий, португальский и испанский тексты готовы как release-кандидаты, но перед масштабным платным трафиком желательна финальная вычитка носителем.
- `What’s New` не заполняется для версии 1.0; шаблон для будущего обновления находится в каждом `metadata.txt`.
