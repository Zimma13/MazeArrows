# Аудит проекта: уровни, прогресс и игровые режимы

Дата: 16 октября 2026 года. Проведен аудит текущей рабочей копии Maze Arrows.[^workspace] Код, каталог уровней и настройки не изменялись. Статистика рассчитана Python-скриптами, которые только читали данные. Генераторы не запускались; тесты Xcode не запускались.

## 1. Точный состав текущей кампании

Источник: [MazeArrows/MazeArrows/Data/levels.json:1](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Data/levels.json:1>), однострочный JSON. SHA-256 полного файла на момент аудита:

`f781f36eb3a64e8e2e84c5fb3e693e83e0f1425cc37a801d63acd7a06fb223c9`

- **240 уровней** с уникальными ID `story_1`…`story_240` и уникальными непрерывными индексами 1…240.
- У всех 240 цель `goal.kind=clearAll`, пустой массив препятствий, отсутствуют название `name` и собственная палитра уровня.
- Все 240 досок прямоугольные и **на 100% заполнены стрелками**: каждая клетка принадлежит ровно одной стрелке. Пустого пространства, фигурных масок и объектов-препятствий в текущей кампании нет.
- Сложность: easy — 60 уровней, medium — 70, hard — 70, expert — 40. Жизни: 5 у easy, 4 у medium, 3 у hard/expert.
- Всего **13 609 стрелок**: standard — 12 240 (89,94%), fragile — 826, frozen — 455, lockedKey — 44, lockedLock — 44. В текущем каталоге нет heavy, double, bomb и chain.
- Fragile встречается на каждом уровне 30…240: 211 уровней. Frozen — на каждом уровне 70…240: 171 уровень. Пара key+lock — на каждом третьем уровне от 111 до 240: 44 уровня; всегда одна пара группы 1. Уровни 1…29 содержат только standard.
- Порог frozen: 2 удаления в 142 случаях, 3 — в 172, 4 — в 141. Считаются удаления **в любом месте доски**, а не соседних стрелок: [Logic/MoveValidator.swift:58–74](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Logic/MoveValidator.swift:58>).
- Точных повторов содержимого доски после исключения ID уровня/стрелок и порядка стрелок не обнаружено. Это не проверка визуального сходства, поворотов, отражений или изоморфизма графов: из результата не следует, что все уровни ощущаются разными.
- Порог трех звезд — 0 ошибок у всех 240 уровней. Порог двух звезд — от 4 до 20 ошибок; в 226 из 240 случаев он не меньше исходного числа жизней. Поэтому на этих уровнях обычное успешное прохождение с ошибкой, без возрождения, обычно дает две звезды; одна звезда в основном становится возможна после возрождения или в спокойном режиме. Это наблюдение для проектирования нового контента, **не предложение пересчитывать старые уровни**.

### Распределение по главам

Определения глав: [Models/Chapter.swift:60–68](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Models/Chapter.swift:60>). Во всех столбцах «мин. / среднее / макс.» среднее рассчитано по уровням соответствующей главы.

| Глава и уровни | Число уровней | Диапазон размеров поля | Стрелки: мин. / среднее / макс. | Доступные первые ходы: мин. / среднее / макс. | Глубина зависимостей: мин. / среднее / макс. | Уровни с fragile / frozen / key+lock |
|---|---:|---|---|---|---|---|
| The Meadows, 1–25 | 25 | 12×16–14×18 | 20 / 24,28 / 29 | 2 / 4,04 / 5 | 8 / 10,68 / 15 | 0 / 0 / 0 |
| The Forest, 26–60 | 35 | 14×19–16×22 | 24 / 31,60 / 40 | 2 / 5,11 / 6 | 9 / 11,40 / 15 | 31 / 0 / 0 |
| The Mountains, 61–95 | 35 | 16×22–19×25 | 34 / 42,11 / 50 | 4 / 6,20 / 8 | 11 / 13,74 / 18 | 35 / 26 / 0 |
| The Caves, 96–130 | 35 | 19×26–21×29 | 43 / 52,26 / 62 | 4 / 7,37 / 9 | 12 / 15,69 / 23 | 35 / 35 / 7 |
| The Glacier, 131–160 | 30 | 21×29–23×32 | 56 / 63,80 / 71 | 6 / 8,60 / 10 | 14 / 16,47 / 21 | 30 / 30 / 10 |
| The Summit, 161–200 | 40 | 23×32–26×36 | 66 / 74,97 / 86 | 6 / 9,18 / 12 | 15 / 18,82 / 27 | 40 / 40 / 13 |
| The Void, 201–240 | 40 | 26×36–29×40 | 84 / 92,00 / 102 | 7 / 10,57 / 13 | 17 / 20,18 / 26 | 40 / 40 / 14 |

Число стрелок каждого типа по главам:

| Уровни | Standard | Fragile | Frozen | Key | Lock |
|---|---:|---:|---:|---:|---:|
| 1–25 | 607 | 0 | 0 | 0 | 0 |
| 26–60 | 1045 | 61 | 0 | 0 | 0 |
| 61–95 | 1347 | 88 | 39 | 0 | 0 |
| 96–130 | 1633 | 113 | 69 | 7 | 7 |
| 131–160 | 1699 | 122 | 73 | 10 | 10 |
| 161–200 | 2654 | 199 | 120 | 13 | 13 |
| 201–240 | 3255 | 243 | 154 | 14 | 14 |

Методика метрик воспроизводит правила из [Logic/MoveValidator.swift:33–74](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Logic/MoveValidator.swift:33>) и [Logic/SnakeFillGenerator.swift:70–109](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Logic/SnakeFillGenerator.swift:70>): проверяется прямой луч выхода головы стрелки, учитываются ограничения frozen и lock, затем одновременно удаляются все доступные стрелки. Число таких раундов до пустого поля — `parallelDepth`, здесь «глубина зависимостей».

**Все 240 полей очистились в этой независимой симуляции.** Она не заменяет нативные тесты и проверку интерфейса: скрипт моделирует только типы, реально присутствующие в текущем каталоге. От первой до последней главы средняя глубина растет с 10,68 до 20,18, а число стрелок — с 24,28 до 92,00. Увеличение поля добавляет объем визуального поиска и очистки, но само по себе не доказывает более глубокий стратегический выбор.

## 2. Насколько специальные стрелки меняют решение

Для обычной геометрии определим:

- `B(p)` — множество других стрелок, пересекающих прямой луч выхода головы стрелки `p`.
- `Pred(p)` — транзитивное замыкание `B(p)`: все стрелки, которые обязательно нужно удалить до выхода `p`, если не учитывать специальные ограничения.

В текущем каталоге нет побочных эффектов bomb/double/chain и объектов-препятствий. Поэтому для геометрии это корректная модель монотонного направленного ациклического графа зависимостей, или DAG.

**Frozen.** Стрелка с порогом `k` не добавляет нового ограничения на порядок, если `|Pred(p)| ≥ k`: необходимые геометрические удаления уже разморозят ее до того, как она сможет выйти. Это достаточное условие избыточности выполняется для **303 из 455 frozen-стрелок, или 66,6%**. Остальные 152 только потенциально значимы: дополнительные ограничения или порядок других удалений могут сделать часть из них избыточной. Из расчета не следует, что все 152 заметно меняют ощущаемую сложность.

**Key/lock.** Замок `L` с соответствующим ключом `K` не добавляет нового ограничения, если `K ∈ Pred(L)`. Это выполняется для **11 из 44 пар, или 25%**. Остальные 33 пары вводят зависимость, не следующую из обычной геометрии; ее интересность все равно требует игрового тестирования.

Это критерии для будущих уровней, а не основания изменять пройденные игроками доски. Новую механику следует размещать так, чтобы она действительно меняла рассуждение игрока.

Текущая базовая игра монотонна: любой допустимый ход только освобождает другие стрелки. Решатель прямо опирается на это свойство: [Logic/LevelSolver.swift:8–10](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Logic/LevelSolver.swift:8>) и [Logic/LevelSolver.swift:43–47](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Logic/LevelSolver.swift:43>). Интерес возникает при поиске и понимании зависимостей; игрок не может испортить решение просто выбором «не той» из уже доступных стрелок.

Цели `freePiece` и `clearColorGroup` могут сфокусировать внимание на объекте и убрать обязательную зачистку остального поля. Медаль или ограничение по числу ходов добавит задачу проследить нужные зависимости и не удалять лишнее. **Но в обычном DAG с фиксированными направлениями множество предшественников цели уже задано: альтернативных более коротких маршрутов такая цель сама по себе не создает.** Условия «достаточно одного из нескольких ключей», выбор направления/действия и переключатели состояния могут дать другой тип планирования, но требуют более существенного изменения движка и решателя.

## 3. Режимы: реальное поведение и заготовки

| Режим | Что делает текущий код | Возможное продолжение |
|---|---|---|
| Story | 240 фиксированных уровней, classic. 25 монет за каждую впервые заработанную звезду, максимум 75 на уровень. Повтор тех же звезд монет не дает. | Сохранить 1–240 неизменными; добавлять авторские главы с 241 с отчетливой механической темой и контролируемой длиной сессии. Увеличивать поле не обязательно. |
| Daily | Seed по UTC-дате; medium 15×21, только standard, clearAll, спокойный `.zenDaily`. До 120 попыток генерации с постепенным ослаблением критериев качества. 25×звезды один раз за дату и серия ежедневных прохождений. | Кураторская ротация мотивов/целей, календарь или архив, явная версия контента/seed. Не нужен второй режим того же ежедневного случайного поля. |
| Weekly | Seed по ISO-неделе UTC; expert 26×36, только standard, clearAll, classic. До 200 попыток. 150 монет один раз за неделю и достижение за первое прохождение. Вход расположен внизу карты мира. | Небольшая авторская недельная экспедиция или набор задач с единым правилом и необязательным испытанием мастерства. Не ограничиваться большим случайным полем. |
| Zen | Детерминированный UTC-день + номер; easy, затем medium, medium и далее hard. `.relax`, три бесплатных завершения в день, без наград. **Безлимит Premium сейчас не подключен:** экран лимита содержит неработающую заготовку кнопки за `premiumOffersEnabled=false`. | Спокойная альтернатива с выбором размера, продолжительности и мотива. Не считать заготовку Premium готовой функцией. |
| Master | Повтор уже пройденной доски: Challenge — на одну жизнь меньше; Timed — 180 секунд; Hard — без подсказок, отмены и предпросмотра пути, на одну жизнь меньше. Корона и 25 монет один раз за пару «индекс + модификатор». Не меняет звезды, открытия, лучшее время и задания кампании. Доступен по нажатию на пройденный уровень в списке. | Это уже имеющийся слой повторной игры. Можно разнообразить испытания новых глав, сохраняя старые результаты и сопоставимость оценок. |
| Photo | Фигурная маска и цветовые зоны из изображения, собственная палитра; relax/generated, без наград. Пять бесплатных генераций за все время, далее рекламный кредит или Premium. Плата списывается только после успешной генерации. | Основа для коллекций, галереи и авторских наборов фигурных досок. Обмен, импорт и QR уже реализованы, **но скрыты за `photoMazeSharingAvailable=false`**; довести эту заготовку проще, чем сразу строить серверную платформу пользовательского контента. |

Основные источники:

- Награды Story: [Data/ProgressStore.swift:52–63](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Data/ProgressStore.swift:52>).
- Daily: [Data/DailyPuzzleProvider.swift:19–49](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Data/DailyPuzzleProvider.swift:19>); размер medium — [Logic/DifficultyConfig.swift:52–60](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Logic/DifficultyConfig.swift:52>); награда — [Data/ProgressStore.swift:263–274](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Data/ProgressStore.swift:263>).
- Weekly: [Data/WeeklyChallengeProvider.swift:20–54](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Data/WeeklyChallengeProvider.swift:20>); режим запуска — [Views/WorldMapView.swift:371–378](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Views/WorldMapView.swift:371>); награда — [Data/ProgressStore.swift:361–367](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Data/ProgressStore.swift:361>).
- Zen: [Data/ZenProvider.swift:22–52](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Data/ZenProvider.swift:22>), [Data/EconomyConfig.swift:28–31](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Data/EconomyConfig.swift:28>), [Views/ZenView.swift:29–40](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Views/ZenView.swift:29>), [Views/ZenView.swift:68–78](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Views/ZenView.swift:68>), [Views/ZenView.swift:121–123](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Views/ZenView.swift:121>).
- Master: [Models/GameMode.swift:67–90](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Models/GameMode.swift:67>), [Views/LevelSelectView.swift:88–107](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Views/LevelSelectView.swift:88>), [Views/LevelSelectView.swift:142–155](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Views/LevelSelectView.swift:142>), [Data/ProgressStore.swift:230–244](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Data/ProgressStore.swift:230>).
- Photo: [Data/PhotoMazeGenerationPolicy.swift:9–35](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Data/PhotoMazeGenerationPolicy.swift:9>), [Data/ProgressStore.swift:130–155](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Data/ProgressStore.swift:130>), [Views/PhotoLevelView.swift:94–108](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Views/PhotoLevelView.swift:94>), [Data/FeatureFlags.swift:14–21](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Data/FeatureFlags.swift:14>).
- Генератор этих режимов создает только стандартные стрелки: [Logic/LevelGenerator.swift:44–79](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Logic/LevelGenerator.swift:44>).

Текущий код обмена переносит стрелки и палитру; при восстановлении уровня препятствия и цели не передаются: [Logic/LevelShareCodec.swift:254–265](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Logic/LevelShareCodec.swift:254>). Поэтому нельзя считать, что достаточно включить существующую кнопку, чтобы без потерь обмениваться будущими уровнями с препятствиями и особыми целями.

### Задания, серия дней и экономика

Ежедневно детерминированно выбираются три шаблона из семи, но реальных типов задач только четыре: завершить уровни кампании, пройти идеально, пройти без подсказок и решить Daily. Награда за задание — 30–70 монет; несколько шаблонов требуют похожих действий. Задание с названием «Zen Master» в действительности означает два прохождения без подсказок, а не игру в Zen: [Models/DailyQuest.swift:11–16](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Models/DailyQuest.swift:11>), [Models/DailyQuest.swift:21–28](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Models/DailyQuest.swift:21>), [Models/DailyQuest.swift:44–83](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Models/DailyQuest.swift:44>).

Заданий за Master, использование конкретных механик или Photo-коллекцию нет. Повтор старых Story-уровней может продвигать задания кампании; generated и master этого не делают: [ViewModels/GameViewModel.swift:731–779](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/ViewModels/GameViewModel.swift:731>).

Сундуки серии выдаются на 3/7/14/30 дней один раз за все время. Заморозка серии покрывает ровно один пропущенный день. При развитии важно сохранить уже существующие ограничения: генерируемый и пользовательский контент не должны создавать бесконечный источник монет, а одноразовые награды не должны выдаваться повторно.

## 4. Безопасное продолжение только добавлением новых уровней

1. **Зафиксировать все записи 1–240.** Сохранить ID, индекс, геометрию, типы стрелок, пороги, группы, жизни, цели и звездные пороги. Для автоматической проверки дополнения удобен канонический хеш каждой записи: хеш всего файла закономерно изменится при добавлении новых уровней. Важно сохранить и поведение старых механик во время игры.
2. **Добавлять непрерывные индексы с 241.** Сохранения используют положительные целочисленные индексы для completed, stars, bestTimes и master, а не ID: [Models/PlayerProgress.swift:12–17](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Models/PlayerProgress.swift:12>), [Models/PlayerProgress.swift:41–42](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Models/PlayerProgress.swift:41>). Перенумерация или подмена записи со старым индексом перенесет старый результат игрока на другую головоломку.
3. **Сброс прогресса для простого дополнения не нужен.** Прошедший №240 уже имеет `unlockedLevelIndex=241`, потому что завершение устанавливает максимум `index+1`: [Models/PlayerProgress.swift:172–180](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Models/PlayerProgress.swift:172>). Меню ограничивает отображаемый индекс концом каталога: [Views/MainMenuView.swift:343–345](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Views/MainMenuView.swift:343>). После появления нового уровня кнопка продолжения естественно сможет открыть №241.
4. **Добавить определения новых глав.** Карта перечисляет `Chapter.all`, а общий список — каталог. Если добавить только JSON, новый контент может открываться из Continue/списка, но не появиться отдельным миром: [Models/Chapter.swift:60–68](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Models/Chapter.swift:60>), [Views/WorldMapView.swift:40–41](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Views/WorldMapView.swift:40>), [Views/LevelSelectView.swift:39](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Views/LevelSelectView.swift:39>). ID и диапазоны глав 1–7 сохранить.
5. **Сохранить смысл исторического достижения Pathfinder.** В описании написано «Complete all 240 levels»: [Models/Achievement.swift:87](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Models/Achievement.swift:87>). Однако награда вычисляется по всем текущим главам: [Data/ProgressStore.swift:427–428](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Data/ProgressStore.swift:427>). Добавление `Chapter.all` незаметно увеличит требование для тех, кто еще не получил достижение. Старое условие следует явно закрепить за 1–240, новым главам/сезонам дать отдельные достижения. Уже заработанные достижения сохранить.
6. **Сохранить идентификаторы Game Center.** Существующие таблицы используют стабильные ID и монотонные счетчики: [Data/GameCenterLeaderboards.swift:8–17](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Data/GameCenterLeaderboards.swift:8>), [Data/GameCenterLeaderboards.swift:27–37](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Data/GameCenterLeaderboards.swift:27>). Дополнение кампании естественно увеличивает счетчики. Новые соревновательные правила не должны обесценивать старые рекорды; отдельному сезонному испытанию нужна собственная идентичность.
7. **Сохранить ключ и совместимость сохранения.** Сейчас ключ — `MazeArrows.PlayerProgress.v2`, с чтением старого v1: [Data/ProgressStore.swift:16](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Data/ProgressStore.swift:16>), [Data/ProgressStore.swift:26–38](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Data/ProgressStore.swift:26>). Необязательные поля декодируются с безопасными значениями по умолчанию: [Models/PlayerProgress.swift:130–169](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Models/PlayerProgress.swift:130>). Не заменять ключ и не обрезать сохраненные значения по размеру текущего каталога; новые поля прогресса добавлять совместимо.
8. **Проверять целостность каталога до выпуска.** Загрузчик проверяет структуру, но не решает все уровни при запуске: [Data/LevelLoader.swift:65–80](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Data/LevelLoader.swift:65>). Неправильные уровни пропускаются. Общей проверки уникальности и непрерывности индексов нет; словарь в `completeLoad` перезаписывает повторный индекс: [Data/LevelLoader.swift:166–175](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Data/LevelLoader.swift:166>). Будущий процесс выпуска должен отклонять пропуски/дубликаты, а не рассчитывать на тихое исключение ошибочного уровня приложением.
9. **Дополнить проверки совместимости перед реализацией контента.** Уже есть проверка разрешимости каталога — [MazeArrows/MazeArrowsTests/LevelCatalogStoreTests.swift:36–48](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrowsTests/LevelCatalogStoreTests.swift:36>), старых сохранений — [MazeArrows/MazeArrowsTests/PlayerProgressCodingTests.swift:18–67](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrowsTests/PlayerProgressCodingTests.swift:18>), изоляции Master — [MazeArrows/MazeArrowsTests/ZenAndMasterTests.swift:100–143](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrowsTests/ZenAndMasterTests.swift:100>). Специальной проверки неизменности хешей 1–240 и обновления игрока с 240 на 241 не найдено.
10. **Не расширять каталог простым повторным запуском текущего генератора.** [Tools/LevelBaker/main.swift:214–245](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/Tools/LevelBaker/main.swift:214>) пересобирает все с первого уровня и перезаписывает файл; [Tools/LevelBaker/bake.sh:7](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/Tools/LevelBaker/bake.sh:7>) по умолчанию указывает на рабочий `levels.json`. Старый [Tools/generate_campaign_levels.py:213–231](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/Tools/generate_campaign_levels.py:213>) генерирует всего 50 и перезаписывает тот же файл. Новые записи следует готовить отдельно, проверять и добавлять после сравнения с неизменной базой.
11. **Для механик с изменяемым состоянием нужен общий механизм переходов.** Сцена, решатель, отмена, подсказки и валидатор должны одинаково применять правила. Текущий DFS различает состояния по набору удаленных ID: [Logic/LevelSolver.swift:151–164](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Logic/LevelSolver.swift:151>). Этого недостаточно для переключателей, изменяемой ориентации порталов, расходуемых ресурсов или оптимизации по ходам. Нынешний валидатор решает полную очистку доски, а не достижимость конкретной цели `LevelGoal`: [Logic/LevelValidator.swift:96–126](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Logic/LevelValidator.swift:96>).
12. **Фиксировать версию генерируемых испытаний.** Один seed не гарантирует прежнее поле после изменения генератора или правил. Daily/Weekly/Zen пересоздают доски текущим кодом. Для архива, обмена и честного сравнения результатов нужна зафиксированная версия контента либо готовая доска. Нельзя незаметно менять ежедневное испытание посреди его прохождения.

Будущие приемочные сценарии: новая установка; игрок на №17; игрок, еще не завершивший №240; игрок после №240 со смешанными звездами; игрок с 720 существующими коронами Master; старое сохранение v1; сохраненные Daily/Weekly, серия, монеты и лимиты Photo; отсутствующий/повторный новый индекс; неизменные отпечатки всех старых досок; видимость новой главы; правильное автоматическое открытие №241; возможность получить старое достижение на №240; отсутствие повторной выдачи прежних наград.

## 5. Аналитика и актуальность документации

Текущий клиент аналитики по умолчанию — **`NoopAnalyticsClient`**: [Data/Analytics.swift:194–204](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Data/Analytics.swift:194>). Поиск по проекту не обнаружил присваивания другого производственного клиента. События начала, завершения, провала и перезапуска уровня предусмотрены; события жизненного цикла подключены в [Views/GameView.swift:248–280](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Views/GameView.swift:248>). Завершение передает продолжительность, ошибки, подсказки и комбо: [Data/Analytics.swift:144–159](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Data/Analytics.swift:144>).

Из этой рабочей копии нельзя сделать вывод о фактическом сборе удержания и воронок уровней. Поэтому численные утверждения о том, где существующие игроки уходят или что им нравится, на данных проекта пока не основаны.

До оценки новых глав нужно собрать либо получить из доступных внешних данных базовые показатели: входы и завершения 201–240, номер попытки, активное время решения, выход/брошенный уровень, возврат на следующий день и неделю, использование подсказок/возрождения, цепочку «начал 241 → завершил 241 → дошел до конца новой главы», а также качественные причины ухода. При необходимости добавляются версия контента, группа эксперимента и идентификатор механики. Это требования к будущему измерению, а не выполненная сейчас реализация. Существующие события стоит использовать повторно, не создавая дубли.

Исторические документы расходятся с текущим кодом:

- [work.md:113](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/work.md:113>) описывает 50 уровней со стенами, бомбами, chain и альтернативными целями. Это не состав нынешнего каталога. [work.md:115–119](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/work.md:115>) отмечает главы, карту, Weekly и Daily Quests как незавершенные, хотя они уже реализованы.
- [work.md:73](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/work.md:73>) прямо указывает, что телепортация порталов — заглушка. Ее нельзя считать готовой игровой механикой по отметке о наличии объекта.
- Заголовок baker говорит о 200 уровнях — [Tools/LevelBaker/main.swift:5](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/Tools/LevelBaker/main.swift:5>), константа равна 240 — [Tools/LevelBaker/main.swift:37](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/Tools/LevelBaker/main.swift:37>), комментарий обещает 140+ стрелок — [Tools/LevelBaker/main.swift:67](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/Tools/LevelBaker/main.swift:67>), тогда как текущий максимум равен 102.
- [maze_arrows_tz.md](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/maze_arrows_tz.md>) — исходная спецификация с идеями, а не перечень готового функционала.
- [futureV2.md:5–9](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/futureV2.md:5>) соответствует текущему состоянию отключенных Photo share/import.
- Планы в папке Pay описывают намерения. В частности, безлимит Zen и аналитика требуют проверки по коду, прежде чем считать их доступными функциями.

## 6. Выводы для плана развития

- Максимально полезное ближайшее разнообразие — авторские уровни с другим взаимодействием или целью. Продолжение с №241 не обязано увеличивать размеры. Первое знакомство с новой идеей должно быть понятным вернувшемуся опытному игроку и достаточно коротким.
- Frozen и пара «стрелка-ключ / стрелка-замок» уже знакомы игрокам. Ворота, открываемые ключом, будут новой механикой только при действительно отличающемся поведении. Существующая заготовка статических ворот по направлению/цвету сама по себе не является динамической дверью.
- Частичные цели дают более короткие эпизоды и фокус на зависимостях. Медаль за число ходов полезна, но не создает выбора маршрута в текущем DAG; обещание стратегического ветвления потребует дополнительных правил.
- Фигурные поля, визуальные мотивы, пустое пространство и композиция могут сделать новые доски узнаваемыми. В нынешней кампании этого нет, хотя Photo уже умеет работать с масками и цветами.
- Расписание авторского контента и понятный вход в продолжение можно построить на существующих Daily/Weekly/Master. Новые пункты меню, повторяющие те же циклы, сами по себе интереса не добавляют.
- Для каждой новой механики нужен проверочный вопрос: если убрать ее правило, изменятся ли доступные ходы, достижение цели или набор оптимальных действий? Если нет, механика может оказаться лишь оформлением.
- Сохранение незавершенной доски между игровыми сессиями в `PlayerProgress` и выполненном поиске по хранилищам не найдено. Перед очень длинными многоэтапными задачами это стоит оценить отдельно. Game Center синхронизирует достижения и рекорды, но не полноценную контрольную точку поля.

[^workspace]: Аудит описывает файлы текущей рабочей копии на 16 октября 2026 года. Соответствие опубликованному бинарю App Store отдельно не проверялось. Флаги, доступность функций и состав контента в установленной у игроков версии могут отличаться.
