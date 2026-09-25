# Экономика и режимы — план реализации

**Дата:** 05.08.2026
**База:** `economy-and-modes-proposal.md` (утверждённые решения §2–§6).
**Принцип:** этапы 0–4 — чистая игровая логика и UI, не зависят от рекламного SDK, StoreKit-гейтинга и remote config. Всё внешнее подключается флагами на этапе 5, когда до него дойдёт большой `план реализации.md`. Каждый этап шипуем отдельно — игра остаётся рабочей после любого из них.

---

## Этап 0 — Фундамент: конфиг и модели (~1 день)

### 0.1 `Data/EconomyConfig.swift` — все числа экономики в одном месте

```swift
struct EconomyConfig {
    var hintCost = 100
    var undoCost = 30
    var reviveCost = 150
    var reviveLives = 2
    var streakFreezeCost = 250
    var maxStreakFreezes = 2
    var zenFreeLevelsPerDay = 3
    var masterClearReward = 25
    var streakChests: [Int: Int] = [3: 50, 7: 100, 14: 200, 30: 400]
    var rewardedDailyBonus = 50      // этап 5
    var premiumDailyReward = 125     // этап 5
}
```

Доступ через протокол `EconomyConfigProviding` (дефолт — статичный), чтобы на этапе 5 подменить на remote config без переписывания вызовов. В DEBUG — оверрайд из UserDefaults для ручного тюнинга.

### 0.2 `PlayerProgress` — новые поля

Ключ хранения не меняем (`v2`), все поля декодируются через `try? … ?? default` (паттерн в файле уже есть):

- `streakFreezes: Int = 0`
- `claimedStreakChests: Set<Int> = []`        // дни 3/7/14/30
- `zenPlayedDate: String? / zenPlayedCount: Int = 0`
- `masterClears: [Int: Set<GameMode>] = [:]`  // levelIndex → пройденные модификаторы

### 0.3 `ProgressStore` — API трат

- `@discardableResult func spendCoins(_ amount: Int) -> Bool` — единственная точка списания.
- `purchaseHint() / purchaseUndo() / purchaseRevive() / purchaseStreakFreeze() -> Bool` — цена из конфига → `spendCoins` → соответствующий grant. `grantHint`/`grantUndo` наконец получают вызовы.

**Тесты:** списание при нехватке/достатке; идемпотентность grant; декод старого JSON без новых полей.

**Готово, когда:** можно из дебаг-меню купить подсказку за монеты и увидеть изменение обоих счётчиков.

---

## Этап 1 — Стоки в геймплее (~2–3 дня)

### 1.1 `Views/ResourceOfferSheet.swift` — единый контекстный шит

Контексты: `.hint`, `.undo`, `.revive`. Слоты сверху вниз:

1. **Rewarded** — скрыт за флагом `adsAvailable` (сейчас false; появится на этапе 5);
2. **За монеты** — цена + текущий баланс; при нехватке кнопка задизейблена с подписью «не хватает N»;
3. **Premium** — скрыт за флагом `premiumOffersEnabled` (сейчас false; на этапе 5 станет триггером контекстного пейволла «исчерпание хинтов» из ресёрча §09).

Это тот самый переиспользуемый компонент, который потом станет пейволл-точкой, — проектируем его сразу с событиями `economy_offer_shown/converted(context, slot)`.

### 1.2 `GameViewModel` — вызов шита вместо тупика

- `consumeHint()` при `hintsCount == 0`: вместо warning-хаптики выставляем `resourceOfferRequest = .hint`; `GameView` показывает шит; успешная покупка → авто-применение подсказки (продолжить прерванный вызов).
- Аналогично `consumeUndo()`.
- Новое поле `failReason: FailReason?` (`.outOfLives`, `.timeUp`, `.goalFailed`) — проставлять в `declareFailure()` по месту вызова.

### 1.3 Revive в `FailOverlayView`

- `GameViewModel.revive()`: только из `isFailed && failReason == .outOfLives` → `lives = reviveLives`, `isFailed = false`, сессия продолжается (таймер и доска не сбрасываются).
- Кнопка «Продолжить · +2 ♥ · 150 🪙» **над** Retry; показывается только для `.outOfLives`. Тап при нехватке монет → тот же `ResourceOfferSheet(.revive)`.
- `.timeUp` и `.goalFailed` — без revive (провал цели необратим; timed-revive — кандидат v1.1 «+60 сек», не сейчас).
- **Инвариант:** revive не бесплатен ни для кого, включая будущий Premium.

### 1.4 Видимость баланса

- Чип с монетами в `MainMenuView` (рядом с кнопкой квестов).
- В `GameView` баланс не висит постоянно — показывается внутри шита (меньше шума на доске).

**Тесты:** revive-переходы состояний; повторный revive на том же уровне (разрешён, пока хватает монет); шит не появляется в hard-режиме (там подсказки запрещены по правилам режима, не по балансу).

**Готово, когда:** цикл «кончились подсказки → купил за монеты → подсказка сработала» и «проиграл → продолжил за 150» проходят вручную end-to-end.

---

## Этап 2 — Реструктуризация режимов (~3–4 дня, самый объёмный)

### 2.1 Кампания — только classic

- Убрать `modeChip` и `ModePickerSheet` из `MainMenuView`.
- `storyDestination`: жёстко `gameMode: .classic`.
- `SettingsStore.selectedGameMode` — оставить в модели (обратная совместимость декода), но игнорировать; пометить deprecated.
- Daily: всегда `.zenDaily` (убрать ветвление `effectiveMode`).
- Enum `GameMode` не трогаем — он остаётся механизмом модификаторов.

### 2.2 Zen — отдельная активность

- `Data/ZenProvider.swift`: уровень через существующий `LevelGenerator`; сложность растёт с номером уровня в сессии (маппинг на `DifficultyConfig`); seed = `stableHash64("zen_" + date + index)` — день детерминирован, `Date.now` в геймплей не тащим.
- Лимит: `zenPlayedCount`/`zenPlayedDate`, сброс по UTC-дню (та же логика дат, что у квестов). Free-лимит из конфига (3).
- UI: пункт «Zen» в `MainMenuView` (место освободилось от modeChip); запуск как `LevelMode.generated` + `GameMode.relax` — **наград нет уже сейчас** (ветка `.generated` в `recordCompletion` пустая — закрепить тестом как инвариант).
- Экран лимита: «Zen на сегодня закончился» + слот Premium за флагом (вторая пейволл-точка этапа 5).

### 2.3 Мастер-слой — реплей пройденных глав

- Новый `LevelMode.master(index: Int)`; модификатор — обычный `gameMode` (challenge/timed/hard).
- Вход: в `LevelSelectView` у **пройденного** уровня — «Мастер-испытание» с выбором модификатора (доступно с первого пройденного уровня; на карте главы — сводка корон).
- `ProgressStore.recordMasterCompletion(levelIndex:modifier:)`: если `masterClears[index]` не содержит модификатор → вставить + `masterClearReward` (25), иначе 0. **Не трогает** stars/unlock/quests/bestTimes — только короны и монеты. One-time = фарм исключён.
- UI корон: до трёх мини-иконок модификаторов на ячейке уровня в `LevelSelectView`.

**Тесты:** zen-лимит через смену даты; мастер-награда one-time; кампания игнорирует сохранённый `selectedGameMode`; generated не даёт монет.

**Готово, когда:** в меню нет выбора режима; Zen играется и упирается в лимит; мастер-реплей даёт корону и 25 монет ровно один раз.

---

## Этап 3 — Стрик-механика (~1–2 дня)

### 3.1 Streak freeze

- В `recordDailyCompletion`: разрыв ровно в 1 пропущенный день (`diff == 2`) и `streakFreezes > 0` → списать freeze, стрик продолжается; иначе — как сейчас.
- Покупка за 250 (кап 2) — в `DailyQuestsView`/стрик-блоке; событие `streak_freeze_bought/used`.

### 3.2 Стрик-сундуки

- После обновления стрика: для каждого порога из `streakChests`, если `dailyStreak >= порог` и порога нет в `claimedStreakChests` → грант + отметка. UI — на стрик-блоке daily-экрана (без попапов — принцип П5 онбординга).

**Тесты:** freeze списывается ровно при разрыве в один день; сундук не выдаётся дважды; стрик 30 выдаёт все четыре, если не были получены.

---

## Этап 4 — Аналитика, строки, полировка (~1 день)

- `AnalyticsClient`-протокол с заглушкой (SDK появится позже — события прошиваем сейчас): `economy_coins_spent(sink, amount, balance)`, `economy_offer_shown/converted(context, slot)`, `revive_offered/used`, `zen_level_start / zen_limit_hit`, `master_clear(modifier)`, `streak_freeze_bought/used`, `streak_chest_claimed(day)`.
- Все новые строки — сразу через String Catalog с plural variations (монеты, жизни, уровни) — требование этапа 1 большого плана.
- A11y-проход: шит и чипы — Dynamic Type до accessibility2, VoiceOver-лейблы с ценой и балансом, `minimumTapTarget`.

---

## Этап 5 — Стыковка с большим планом монетизации (по его графику)

Делается внутри соответствующих этапов `план реализации.md`, здесь — только точки стыковки:

| Что | Куда подключается | Этап большого плана |
|---|---|---|
| Rewarded-слоты шита + дневной бонус +50 | флаг `adsAvailable` → ad SDK | 8 (реклама) |
| Premium-слоты шита + Zen-limit teaser → контекстный пейволл | entitlement-модель | 6, 10–11 |
| Premium-права: безлимит подсказок (`availableHints = ∞`), Zen без лимита, авто-daily-reward 125, freeze 1/нед | entitlement-модель | 6–7 |
| ⚠️ Авто-выдача rewarded для Premium — **только дневной бонус**, не revive/не подсказки | правило entitlement-модели | 7 |
| `EconomyConfig` → remote config | подмена провайдера | 13 |

---

## Вне плана (сознательно)

- Косметика за монеты, экран магазина, доп. генерации Photo Maze — v1.1 (после запуска, по данным).
- Паки монет за IAP — не в v1 (риск каннибализации подписки).
- Квест-типы для Zen/мастер-слоя, ачивки за короны — v1.1.
- Revive в timed (+60 сек) — v1.1.

## Сводка по срокам

| Этап | Объём |
|---|---|
| 0. Конфиг + модели + API трат | ~1 день |
| 1. Шит ресурсов + revive + баланс | ~2–3 дня |
| 2. Режимы: classic-кампания, Zen, мастер-слой | ~3–4 дня |
| 3. Freeze + сундуки | ~1–2 дня |
| 4. Аналитика + строки + a11y | ~1 день |
| **Итого (этапы 0–4)** | **~8–11 дней чистой работы** |

Порядок жёсткий только для 0 → 1; этапы 2 и 3 независимы друг от друга и могут меняться местами. После этапа 1 игра уже избавлена от главного дефекта («подсказки кончаются навсегда») — это минимальный шипуемый инкремент.
