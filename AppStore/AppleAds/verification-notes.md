# Проверка запуска, 2026-09-07 Asia/Bangkok

- Запрос пользователя: исследовать конкурентов/страны/ключи, собрать и запустить Apple Ads, $100/month. Уточнено: цель Premium/окупаемость; бюджет отдельный от iCleanse; мониторинг не нужен.
- Выбран активный account 21329790 Stepanov Dmitry, USD, PAYG, Asia/Bangkok. Роль API Campaign Manager, delegation CONTENT_PROVIDER присутствует.
- App 6800708435 принадлежит Stepanov Dmitry, доступен в CA. Eligibility Search Results CA ELIGIBLE iPhone/iPad.
- Опубликованные locales API: en-GB, en-CA, pt-PT, fr-CA, de-DE, pt-BR, de-CH, zh-Hant, en-AU, ko-KR, en-US, fr-FR, ja-JP, es-ES, es-MX.
- Campaign 2144620520 создан ровно один раз на паузе; после проверки включён. Финальная read-back: ENABLED, NOT_RUNNING, ON_HOLD, APP_NOT_CATEGORIZED. Финальная UI проверка кампании: «Ожидается проверка приложения».
- 3 ad groups read-back ENABLED, Search Match false, manual bids 0.20/0.15/0.15; campaign IDs совпадают. Собственное systemStatus групп RUNNING, displayStatus CAMPAIGN_ON_HOLD.
- Bulk response подтвердил success=true для 14/14 EXACT targeting keywords и 11/11 BROAD negatives. Отдельное keywords find подтвердило 14 записей, все ENABLED, ставки не выше $0.20.
- Daily budget 3.07 USD; CA только; Search Results только; campaign и все группы заканчиваются 2026-10-06T16:59:59 UTC = 23:59:59 Asia/Bangkok.
- Проверка арифметики: 3.07 ×30.4×1.07 =99.86096 USD. VAT7% — резерв исходя из Thailand/no VAT ID в бизнес-настройках и первичных налоговых источников. Фактический налог ещё не подтверждён отдельным счётом этой кампании.
- UI группы Core_EN: Default Ad ACTIVE, источник Default Product Page; preview English (Canada), title/subtitle совпадают с en-CA. Изображения визуально загружены. Шаблонное число рейтингов в preview не принято за факт.
- API apps view сообщает Games/Entertainment. Публичная канадская страница имеет Games/Casual/Puzzle/Entertainment. Категории приложения не менялись.
- Report endpoint вернул result={} и totalCount0: ещё нет доступной статистики. Не интерпретировать как доказанную нулевую конверсию.

## Особенности API, полезные при ручном продолжении

- Первый adgroup create получил 400 Missing startTime; после добавления start/end созданы ровно три группы. Ошибка 400 ресурсов не создала.
- Suggestion keywords без seeds вернул общепопулярные нерелевантные запросы; seeded country queries дали идентичные результаты для шести стран. Для сравнения рынков использован Search Term Popularity Insights с явным country в ответе.
- Phrases suggestions завершились HTTP500; этот источник недоступен. Search popularity CLI не допускает fields, хотя общий текст Apple mentions projection; сохранён совместимый запрос без fields.
- V1 ads create для Search Results отвергнут AD_CAMPAIGN_SUPPLY_SOURCES_NOT_SUPPORTED; дополнительное объявление не создано. Встроенное Default Ad видно в UI и не возвращается в ads find/v5 list. Внешний creative4064902 VALID, не связан с custom ad, отдельного расхода не создаёт.
- Campaign report API отвергает campaignId filter в этом аккаунте; сохранён рабочий запрос без него, возвращающий набор account-level campaign rows. При появлении данных выбирать строку2144620520 в ответе. Не использовать ошибочный campaignId filter из общего примера docs.
- Для диагностики APP_NOT_CATEGORIZED подготовлен support-request-draft.md; сообщение не отправлено.

## Быстрая ручная проверка

```sh
asc ads campaigns view --ads-profile icleanse-apple-ads --ad-account 21329790 --campaign 2144620520 --output json
asc ads ad-groups find --ads-profile icleanse-apple-ads --ad-account 21329790 --file AppStore/AppleAds/requests/campaign-children-query.json --output json
asc ads targeting-keywords find --ads-profile icleanse-apple-ads --ad-account 21329790 --file AppStore/AppleAds/requests/campaign-children-query.json --output json
```

Для отчёта сначала обновить timeRange в requests/report-campaigns.json. Пауза кампании при необходимости:

```sh
asc ads campaigns pause --ads-profile icleanse-apple-ads --ad-account 21329790 --campaign 2144620520
```
