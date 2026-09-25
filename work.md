# Maze Arrows — что ещё не сделано

Файл фиксирует фичи из ТЗ и расширенного списка идей, которых пока **нет** в коде. Группировка — по приоритету и объёму работы.

---

## 1. Полировка существующего (мелкие быстрые задачи)

- [x] ~~**App Icon**~~ — добавлен.
- [ ] **Launch Screen** — генерируется автоматически Xcode, кастомного экрана нет. Можно добавить простой gradient + лого.
- [x] ~~**Локализация**~~ — 158 строк собраны в `MazeArrows/Localizable.xcstrings`. 8 локалей: `en` (база), `en-IN`, `hi`, `id`, `pt-BR`, `pt-PT`, `ru`, `th`. Все модели (`GameMode`, `Difficulty`, `AppThemeID`, `LevelGoal`, `Achievement`, `Chapter`) переведены на `String(localized:)`; кнопки и хелперы (PrimaryButton, GhostButton, ActionPillView, sectionTitle, infoRow, statPill, statItem) переведены на `LocalizedStringKey`; uppercase-литералы заменены на `.textCase(.uppercase)`. `knownRegions` в pbxproj пополнен `th`. Билд успешен, все 8 `.lproj` собраны в bundle. **Native review:** строки на hi/th/id стоит проверить с носителями перед релизом.
- [ ] **Звуковые эффекты** — сейчас только haptics. Добавить:
  - `swoosh` при успешном вылете
  - `thud` / `error` при блокировке
  - `success` jingle при победе
  - `unlock` при разблокировке уровня
- [ ] **Фоновая музыка** — спокойный ambient loop с кнопкой отключения в Settings.
- [ ] **Settings → Сброс прогресса** — кнопка есть, но не сбрасывает звёзды (только `completedLevels`). Поправить `ProgressStore.resetAll()`.
- [ ] **Tutorial / onboarding** для первого запуска: 2-3 экрана объясняющих «тапни — улетит», «у каждой стрелки своё направление», «жизни конечны».
- [ ] **Hero preview на главном меню** — сейчас три статичных стрелки. Сделать живую мини-доску с маленькой анимацией.
- [ ] **Privacy Policy** placeholder в Settings (есть в ТЗ §23.4).

---

## 2. Геймплейные улучшения (средняя сложность)

### Тактильность / визуал
- [x] ~~Свободная стрелка слегка **сжимается** перед вылетом~~ — `ArrowPieceNode.runFlyOut` теперь делает directional squash (короткое сжатие вдоль/растяжение поперёк направления) перед запуском texture-animation.
- [x] ~~**Trail / particle след** за улетающей стрелкой~~ — `SKEmitterNode` с soft-dot текстурой; цепляется за головой во время вылета, угасает после.
- [x] ~~Заблокированная стрелка кроме shake — **дрожь всего поля** или микро-flash вокруг блокировщика~~ — `GameScene.runFieldShake` (tremor слоёв) + красное кольцо `runFieldFlash` вокруг точки коллизии.
- [x] ~~**Particle assembly** в конце уровня~~ — `GameScene.runVictoryBurst` собирает 24 частицы к центру.
- [x] ~~**Combo glow** на x5 / x10 более выраженный эффект~~ — `ComboBurstView.glowStrength`/`scale` плавно растут с x3 до x10+, подсветка двумя цветами темы.
- [x] ~~**Combo callouts** «Chain Clear!», «Sweep!»~~ — `GameViewModel.comboCalloutText` подменяет «COMBO» на текстовый callout (Chain → Sweep → On Fire → Unstoppable).

### Подсказки
- [x] ~~**Многоуровневые подсказки**~~:
  1. Уровень 1: подсветить область — `GameScene.highlightArea` рисует translucent-рамку вокруг подсказанной фигуры.
  2. Уровень 2: подсветить конкретную фигуру — стандартный `runHintFeedback` (pulse).
  3. Уровень 3: фигура + ghost для следующей — `ArrowPieceNode.runGhostStep` (полу-прозрачная следующая фигура).
  Управляется через `Settings → Hint depth (1/2/3)`.
- [x] ~~При preview-on-hold **красная точка** на месте коллизии~~ — `ArrowPieceNode.showPathPreview` рисует blocked-цвета линию + красный круг на cell коллизии.

### Звёзды и метрики
- [x] ~~**«Идеальное прохождение» (3 ★)** золотая рамка~~ — `LevelSelectView.borderColor` для 3★ возвращает золотой обвод + золотая тень.
- [x] ~~**Лучший результат** на экране выбора уровня~~ — `PlayerProgress.bestTimes` хранит `levelIndex → seconds`; LevelSelectView отображает `m:ss` если есть рекорд.

---

## 3. Новые типы стрелок (ТЗ — «Фичи» §1)

Реализованы все 7 типов плюс инфраструктура. `PieceKind` теперь включает `standard, heavy, fragile, frozen, double, lockedLock, lockedKey, bomb, chain`. Каждый имеет уникальный рендер в `ArrowPieceNode` (цвет, иконка-бейдж) и обработку в `MoveValidator` / `GameViewModel`.

- [x] ~~**Heavy (тяжёлая)**~~ — линия x1.45, chevron x1.2, медленный fly-out (`baseDuration: 0.50`), длиннее exit-padding.
- [x] ~~**Fragile (хрупкая)**~~ — `crackLevel` инкрементируется на failed tap; на втором уровне ломается, тратит **2 жизни**, экран взрывается explosion-FX.
- [x] ~~**Frozen (замороженная)**~~ — `frozenUnlockNeighbors: Int`. `MoveValidator.canActOnKindRule` запрещает вылет пока `board.removedPieceCount < threshold`.
- [x] ~~**Double (двойная)**~~ — `secondaryDirection`. Свайп в любом из двух направлений выбирает направление и запускает вылет. `GameScene` ловит `UISwipeGestureRecognizer` и зовёт `sceneDidSwipePiece`.
- [x] ~~**Locked + Key**~~ — пара `kind: .lockedLock` ↔ `kind: .lockedKey` через `colorGroup`. Замок не вылетает пока хоть один ключ той же группы на доске.
- [x] ~~**Bomb (бомба)**~~ — при успешном вылете `applyKindSideEffectsBeforeFlyOut` удаляет все соседние pieces + destructible obstacles, играет explosion-кольцо.
- [x] ~~**Chain (цепная)**~~ — `chainedPieceId` ссылается на следующую. После flyOut автоматически запускает цепную (через 200ms задержку для читаемости).

Расширения схемы (опциональные поля): `kind`, `colorGroup`, `secondaryDirection`, `frozenUnlockNeighbors`, `chainedPieceId`, `crackLevel`. Все обратно-совместимы с существующими 22 уровнями.

Демо-уровни: 23 (Frozen + Walls), 24 (Key & Lock), 25 (Chain Reaction с bomb + destructible + chain).

---

## 4. Препятствия и элементы поля (ТЗ — «Фичи» §2)

Новый тип `Obstacle` с `ObstacleKind`. Хранятся в `Level.obstacles` (опциональное поле JSON), рендерятся через `ObstacleNode` отдельным `obstacleLayer` в `GameScene`. `MoveValidator.obstaclePassable` решает кто проходит:

- [x] ~~**Walls**~~ — `kind: wall`. Полностью блокируют exit lane.
- [x] ~~**Gates**~~ — `kind: gate`, `parameter: <direction>`, опциональный `colorGroup`. Пропускают только если направление и группа совпадают.
- [x] ~~**Portals**~~ — `kind: portal`, `parameter: <pairId>`. Рендер с пульсирующим кольцом, `obstaclePassable` пропускает. (Teleport-логика — заглушка, проходимы.)
- [x] ~~**Ice**~~ — `kind: ice`. Визуал с снежинкой, рендер на полу, проходимая.
- [x] ~~**Springs**~~ — `kind: spring`. Зелёный квадрат с символом ↯, проходимый.
- [x] ~~**Destructible blocks**~~ — `kind: destructible`. Блокирует всех **кроме bomb**. При вылете bomb соседи-destructible сносятся через `GameScene.removeObstacle` с анимацией.

`LevelValidator` дополнен проверками: obstacles не выходят за границы доски и не накрывают cells пьес. Solver автоматически учитывает obstacles через `availableMoves`.

---

## 5. Режимы игры (ТЗ — «Фичи» §9)

Новый тип `GameMode` (enum). `GameViewModel.init` принимает `gameMode: GameMode`. Главное меню показывает chip с текущим режимом и открывает sheet-picker. Режимы влияют на lives, hints, timer, отказ-условия.

- [x] ~~**Relax**~~ — `isPeaceful = true`, 99 жизней (фактически бесконечные), `usesLives = false`, экран показывает chip «No lives, no pressure» вместо сердец.
- [x] ~~**Challenge**~~ — жизни уменьшены на 1, +1 starting hint.
- [x] ~~**Timed**~~ — 180-секундный countdown. `GameView.timerView` рисует timer-капсулу, окрашивается красным на последних 15 секундах. Достижение 0 → fail.
- [x] ~~**Zen Daily**~~ — daily-пазл + peaceful flow. По умолчанию выбирается для Daily если глобальный mode = Classic.
- [x] ~~**Hard Mode**~~ — `startingHintGrant: 0`, жизни -1.

`AppSettings.selectedGameMode` сохраняется в `UserDefaults`. `MainMenuView` и `LevelSelectView` передают выбранный режим в `GameViewModel`.

---

## 6. Особые цели уровня (ТЗ — «Фичи» §10)

Сейчас цель всегда «убрать все стрелки». Добавить альтернативные:

- [ ] Clear all gold arrows (только золотые)
- [ ] Clear without mistakes
- [ ] Remove keys before locks
- [ ] Free the trapped gem (освободить запертый элемент)
- [ ] Clear in under N seconds
- [ ] Use no hints

Нужно расширить `Level` ещё одним полем `goal: LevelGoal` и обновить логику победы.

---

## 7. Контент

- [x] ~~**Расширить пул ручных уровней** до 50~~ — теперь 50 (было 25). Скрипт-генератор `Tools/build_levels.py` валидирует каждый уровень (adjacency, head-segment, overlap, solvability) и собирает `MazeArrows/Data/levels.json`. Прогрессия 26-30 medium standard, 31-35 medium со спецмеханиками (walls, frozen, key/lock, bomb, chain), 36-40 hard плотные, 41-45 hard с комбинациями, 46-50 hard с альт-целями (clearInSeconds, clearColorGroup, freePiece, clearWithoutMistakes) и финал.
- [ ] **Расширить пул ручных уровней** до 100.
- [ ] **Главы / эпизоды** — группировать уровни (Easy 1-10, Medium 11-25, Hard 26-50 и т.д.) с темой главы.
- [ ] **Карта мира** (ТЗ — «Story shell» §11): красивый экран «World Maze Journey» с переходом по главам.
- [ ] **Достижения** — Complete 5 levels without mistakes, Use 0 hints, Clear 20 blue arrows и т.д.
- [ ] **Weekly Challenge** — недельное задание с особой наградой.
- [ ] **Daily Quests** — 2-3 ежедневных мини-задания.

---

## 8. Темы и сезонные скины (ТЗ — «Фичи» §7-8)

В коде 6 тем: Aurora Light, Midnight Neon, Petal Pastel, Sakura, Atlas, Nordic.

- [ ] **Сезонные скины**: Winter Maze, Halloween Shadows, Lunar New Year, Cyber Maze, Ocean Glass, Desert Gold.
- [ ] **Локальные мотивы**: Thailand (тёплое золото, тропики), USA (bold contrast), Middle East (геометрические орнаменты + сине-золотой).
- [ ] **Mood Adaptive Themes** (ТЗ §17): авто-смена темы по времени суток / региону / празднику. Settings → `Theme Mode: Auto / Light / Dark / Region / Seasonal / Custom`.

Сейчас тема выбирается жёстко через `themeID`. Нужен слой `ThemeResolver` который умеет вычислять активную тему по контексту.

---

## 9. Экономика и монетизация (после MVP)

Поля `coins`, `hintsCount`, `undosCount` уже есть в `PlayerProgress`, но нет:

- [ ] **Магазин** где можно тратить монеты на хинты, undo, скины.
- [ ] **Реклама** для бесплатных хинтов / continue после поражения (на Fail Screen есть placeholder для «Watch ad»).
- [ ] **IAP**:
  - Премиум-набор стрелок
  - Сезонные скины
  - Pro/Ads-free подписка
- [ ] **Cosmetic unlocks** за 3-star прохождения.

---

## 10. Технические задачи

- [ ] **Unit-тесты** (ТЗ §30) — никаких сейчас. Добавить XCTest target и покрыть:
  - Board (isInside, occupiedMap, removePiece)
  - MoveValidator (включая ключевой тест из ТЗ §31 — сложная форма, проходящая боком)
  - LevelValidator (повторяющиеся клетки, диагональные шаги, пересечения)
  - LevelSolver (простой уровень решается, нерешаемый возвращает nil)
- [ ] **Snapshot-тесты** для основных экранов.
- [ ] **iCloud sync** прогресса через `NSUbiquitousKeyValueStore` или SwiftData с CloudKit.
- [ ] **Аналитика** (`PostHog` / `Mixpanel` / `Amplitude`) — track уровней, ошибок, времени.
- [ ] **Crash reporting** (Crashlytics / Sentry).
- [ ] **TestFlight** конфигурация / Release scheme.
- [ ] **AppStore metadata** (description, keywords, screenshots — есть подсказки в ТЗ §18).
- [ ] **PrivacyInfo.xcprivacy** privacy manifest (требуется при сабмите).

---

## 11. Доступность

- [ ] **VoiceOver labels** для всех интерактивных элементов (стрелки SpriteKit-сцены сейчас не озвучиваются).
- [ ] **Dynamic Type** для UI текста.
- [ ] **Reduce Motion** — отключение snake-анимации в пользу мгновенного исчезновения.
- [ ] **Color blind mode** — отличать стрелки разных групп не только цветом, но и паттернами.

---

## 12. Известные мелкие баги

- [ ] **Settings → Reset progress** сбрасывает `progress` но звёзды могут не очищаться визуально без релогина экрана (проверить).
- [ ] При смене темы во время игровой сессии **SpriteView пересоздаётся** — теряется анимация если она в процессе. Низкий приоритет.
- [ ] **Daily Puzzle** использует `LevelGenerator` который иногда требует 100+ попыток на сложной конфигурации — добавить кеш на диск.
- [ ] **Combo burst** надпись иногда перекрывает кнопку Hint. Подвинуть/исключить.

---

## Приоритизация для следующего спринта

**Сначала**:
1. Launch Screen
2. Локализация (EN+RU)
3. Звуковые эффекты
4. Onboarding (3 экрана)
5. ~~Расширить контент до 50 уровней~~ ✅

**Потом**:
6. Многоуровневые подсказки
7. Один новый тип стрелки (рекомендую **Frozen** — простая в реализации, понятная игроку)
8. Unit-тесты ядра
9. iCloud sync прогресса
10. Магазин + первый IAP

**Большие куски на будущее**:
- Карта глав
- Полный набор спецстрелок и препятствий
- Сезонные события и культурные темы
- Weekly challenge / достижения
