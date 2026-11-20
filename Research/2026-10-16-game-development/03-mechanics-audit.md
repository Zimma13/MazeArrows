# Аудит механик Maze Arrows — 16 октября 2026

Исследование исходников и read-only анализ JSON. Реализация и существующие уровни не изменялись. Аудит относится к рабочей копии `/Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows`, её совпадение с опубликованным бинарём отдельно не подтверждено. Игровые выводы разделены на проверенное поведение кода и рекомендации.

## Что игроки действительно получают сейчас

В [MazeArrows/MazeArrows/Data/levels.json:1](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Data/levels.json:1>) — 240 уровней, индексы 1…240; все с `clearAll`, ни одного препятствия. Статистика рассчитана непосредственно из JSON:

| Механика | Количество фигур | В скольких уровнях | Первое появление |
|---|---:|---:|---:|
| standard | 12 240 | 240 | 1 |
| fragile | 826 | 211 | 30 |
| frozen | 455 | 171 | 70 |
| lockedKey | 44 | 44 | 111 |
| lockedLock | 44 | 44 | 111 |
| heavy, double, bomb, chain | 0 | 0 | — |

У frozen пороги только 2, 3 и 4 снятые фигуры. Это значит, что в основной кампании уже представлены наказание за ошибки, небольшая начальная задержка и редкая пара ключ/замок. Порталы, стены, пружины, бомбы и альтернативные цели пока не проходились игроками в этом каталоге. Наличие старых заготовок с ними не доказывает наличие в актуальной кампании.

## Фактический статус стрелок

| Вид | Реальная логика | Статус/ограничения | Код |
|---|---|---|---|
| standard | Выход разрешён, если прямой луч от головы до края не пересекает другую фигуру/непроходимое препятствие. Тело уходит по собственной извилистой траектории, не перемещается как жёсткая фигура. | Рабочее ядро. | [MazeArrows/MazeArrows/Logic/MoveValidator.swift:18](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Logic/MoveValidator.swift:18>)–54; [Game/ArrowPieceNode.swift:489](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Game/ArrowPieceNode.swift:489>)–519 |
| heavy | Штрих шире ×1.35, наконечник немного больше; дополнительный запас длины анимации выхода. | Визуальный вариант, **не новая задача**: не толкает, не ломает стену, не требует второго тапа. | [Game/ArrowPieceNode.swift:78](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Game/ArrowPieceNode.swift:78>)–96; [Logic/MoveValidator.swift:154](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Logic/MoveValidator.swift:154>)–169 |
| fragile | Первый неверный тап ставит трещину и снимает 1 жизнь; начиная со второго неверного тапа по этой фигуре снимает 2 жизни и показывает эффект. | Работает как усиленное наказание. Фигура **не исчезает/не разбивается на части**, хотя комментарий модели говорит breaks. Нового правильного способа решения не даёт. | [ViewModels/GameViewModel.swift:438](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/ViewModels/GameViewModel.swift:438>)–478 |
| frozen | Разрешается после снятия N любых фигур на поле. | Работает; это **глобальный счётчик снятых фигур, не соседство**, несмотря на имя frozenUnlockNeighbors. Снятие нескольких соседей бомбой также увеличивает счётчик. Нет динамического уменьшения цифры/перевода kind в standard в просмотренной логике. | [Logic/MoveValidator.swift:58](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Logic/MoveValidator.swift:58>)–62; [Models/Board.swift:79](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Models/Board.swift:79>); [Game/ArrowPieceNode.swift:247](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Game/ArrowPieceNode.swift:247>)–248 |
| lockedKey/lockedLock | Замок нельзя снять, пока на поле есть хотя бы один ключ с таким же colorGroup. Если ключей несколько — должны исчезнуть все. Если group=nil либо ключа изначально нет — замок открыт. | Работает; удаление ключа бомбой также открывает замок. Нумерация пар уже визуализируется. | [Logic/MoveValidator.swift:63](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Logic/MoveValidator.swift:63>)–74; [Game/ArrowPieceNode.swift:265](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Game/ArrowPieceNode.swift:265>)–270,291–304 |
| double | Swipe выбирает primary/secondary; меняется направление той же головы, затем проверяется выход. | Runtime-ветка и жесты есть, но **не готово к публикации**. Неудачный swipe во второе направление заменяет primary на secondary, оставляя allowed=[secondary,secondary]; вернуться к прежнему направлению невозможно. Тело при этом не разворачивается: меняется лишь direction. Solver не перебирает secondary. | [ViewModels/GameViewModel.swift:390](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/ViewModels/GameViewModel.swift:390>)–405; [Game/GameScene.swift:588](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Game/GameScene.swift:588>)–601,922–945 |
| bomb | При разрешённом выходе уничтожает любые соседние фигуры и destructible в ортогональных соседних клетках **вокруг всего исходного тела**. | Runtime есть, но проверка/undo не соответствуют. Соседние bomb/chain удаляются **без срабатывания их эффектов**. Сквозь любые destructible в луче bomb проходит, но уничтожает только соседние своему исходному телу: дальний блок может остаться. | [ViewModels/GameViewModel.swift:481](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/ViewModels/GameViewModel.swift:481>)–497,544–553; [Logic/MoveValidator.swift:99](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Logic/MoveValidator.swift:99>)–100 |
| chain | После выхода пытается автоматически запустить linked piece; только если он сейчас может выйти. Далее рекурсивно происходит его обычный successfulMove. | Работает условная автосерия. Если linked piece ещё заблокирован, серия прекращается; постоянной подписки на его будущее освобождение нет. Не связано с настоящим совместным перемещением двух тел. | [ViewModels/GameViewModel.swift:503](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/ViewModels/GameViewModel.swift:503>)–541 |

`Design/special-pieces.jsx` содержит более богатые визуальные концепты, а не доказательство игровой реализации. Отдельных PieceKind gold/portal/gem нет ([Models/ArrowPiece.swift:15](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Models/ArrowPiece.swift:15>)–32). Золотая стрелка может быть обычной цветовой группой; `freePiece` — цель по ID, без самостоятельной модели драгоценности. Дизайн double показывает разветвлённую форму с двумя физическими концами ([Design/special-pieces.jsx:201](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/Design/special-pieces.jsx:201>)–218), runtime хранит одно линейное cells[] и одну headCell ([Models/ArrowPiece.swift:91](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Models/ArrowPiece.swift:91>)–96).

## Препятствия

Все 6 видов моделируются, рисуются SpriteKit, доступны в редакторе. Ни одного из них нет в текущих 240 уровнях.

| Вид | Фактическая логика | Вывод |
|---|---|---|
| wall | Всегда блокирует луч выхода. | Рабочий статический блок. Для fixed-direction clearAll стрелка, луч которой пересекает стену, не выйдет никогда (кроме уничтожения самой стрелки бомбой); если лучи стену не пересекают, на порядок снятия она не влияет. |
| gate | Пропускает только совпадающее направление и при заданном group — совпадающую группу. | Рабочий **постоянный фильтр**, не дверь с ключом/переключателем. Ключи открывают lockedLock-стрелки, но не gate-объекты. Неверный/пустой parameter убирает проверку направления. |
| portal | Всегда passable. | Есть модель параметра пары и пульсирующее изображение; **нет телепортации, второй точки выхода, перенаправления, проверки пары**. |
| ice | Всегда passable. | Есть плитка-снежинка; **нет дополнительного скольжения/изменения траектории**. |
| spring | Всегда passable. | Есть значок; **нет отскока, разворота или блокировки**. Комментарий Obstacle.swift называет wall-like, но код этого не делает. |
| destructible | Блокирует всех, кроме bomb; удаляется при соседнем взрыве. | Имеет реальный потенциал поэтапного открытия пространства; требуется согласовать правила бомбы с solver/Undo. |

Источники: [MazeArrows/MazeArrows/Logic/MoveValidator.swift:80](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Logic/MoveValidator.swift:80>)–101; [Models/Obstacle.swift:15](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Models/Obstacle.swift:15>)–40; [Game/ObstacleNode.swift:41](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Game/ObstacleNode.swift:41>)–56,80–177,215–228. [Design/obstacles.jsx:1](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/Design/obstacles.jsx:1>)–126 — только React-рендеры без состояния ходов. Поэтому формулировка «препятствия уже готовы, надо расставить по уровням» неверна.

**Геймдизайн-инвариант:** статические wall/gate сами по себе не добавляют временного выбора в очищаемое поле с неизменными направлениями. Они либо навсегда запрещают выход, либо уже разрешают его и не меняют дальнейшие зависимости. Для осмысленного применения нужны хотя бы один из факторов: альтернативные направления, изменяемое состояние ворот, разрушение/удаление, partial goal с допустимыми оставшимися стрелками. Просто разложить стены по новым clearAll — риск получить невозможные либо декоративные уровни.

## Цели

В модели перечислены 7 целей ([Models/LevelGoal.swift:14](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Models/LevelGoal.swift:14>)–28); switch победы присутствует ([ViewModels/GameViewModel.swift:556](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/ViewModels/GameViewModel.swift:556>)–582). Но все опубликованные в JSON уровни используют clearAll.

- `clearAll`: реализовано.
- `clearColorGroup`: победа сразу после исчезновения целевой группы. Подходит для коротких тактических задач; solver всё ещё требует убрать **всё**, поэтому будет ошибочно отвергать допустимые partial-goal уровни с навсегда оставшимися фигурами. Нужен счётчик целевых фигур и идентификация не только цветом.
- `freePiece`: победа при отсутствии указанного ID. Бомба, уничтожившая цель, также считается её «освобождением»; если требуется именно спасение, нынешнее условие недостаточно. Отдельной визуальной сущности gem нет. Нужна проверка существования ID и цель-aware solver.
- `keysBeforeLocks`: тот же критерий «поле пусто», отдельной проверки последовательности нет. Порядок обеспечивается только типом lockedLock. В обычных фигурах эта цель ничего не меняет.
- `clearWithoutMistakes`: после единственной ошибки задача становится невыполнимой, но игра объявит это только после полного очищения, если жизни не кончатся раньше. Для релиза решить UX мгновенного поражения/перезапуска либо явно опционального медального условия.
- `noHints`: подсказку можно использовать, затем игра будет ждать полного очищения и объявит goalFailed. Нужно заранее блокировать несовместимое действие или менять цель на бонусный челлендж.
- `clearInSeconds`: время проверяется только после полного очищения. Таймер режима (`hasTimer`) зависит только от `.timed`, а не от цели. Classic с этой целью показывает цель-chip и жизни, но не целевой countdown ([GameViewModel.swift:168,210](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/ViewModels/GameViewModel.swift:168>)–224,239; [Views/GameView.swift:583](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Views/GameView.swift:583>)–654). Не считать готовым временем-ограниченным уровнем.

## Что реально доказывает solver

[LevelSolver.swift:19](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Logic/LevelSolver.swift:19>)–25 пытается greedy, затем bounded DFS. В обеих ветках переход состояния — только `board.removePiece(id:)` (`39`–48; `154`–164). Он не выполняет bomb, chain, swipe и не читает LevelGoal (получает только Board).

Для текущего набора standard/fragile/frozen/lockedKey/lockedLock и clearAll успешные удаления монотонны: уменьшается занятость, растёт removedPieceCount, исчезают ключи-ограничители. Если фигура сейчас разрешена, снятие любой другой фигуры не может снова её заблокировать. При этих правилах greedy математически достаточен; DFS не открывает полезных других веток. Это сильное достоинство ядра: ошибочный успешный ход не может испортить решение.

Для double, bombs с meaningful destructibles, изменяемых ворот/порталов и целей этого утверждения недостаточно. DFS хранит visited как sorted removed IDs, без направления, состояния ворот, препятствий, оставшихся зарядов и прогресса цели (`156`–163). Это нельзя считать универсальным solver для следующих механик. `nextHintPiece` при неудаче solve просто берёт первый доступный ход (`173`–181), что опасно в немонотонных головоломках.

### Контрпример с необратимым тупиком

Проверен read-only Python-моделированием точных условий текущих Swift-функций; редакторский solve взят из AST `build_levels.py`, без запуска генерации и записи каталога.

Поле 7×7:
- A: bomb, cells [(2,3),(2,2)], direction up.
- B: bomb, cells [(3,3),(3,4)], direction down.
- P: standard, cells [(0,4),(1,4)], direction right.
- C: destructible в (4,4).

И A, и B сначала могут выйти. Если нажать A, она уничтожает B, но C находится вне её соседства. P навсегда застревает за C. Если нажать B, она уничтожает A и C, затем P выходит. Отсюда **бомба уже может превращать допустимый ход в проигрышный**, хотя базовое ядро обещает обратное. Это не гипотеза о будущих механиках, а следствие текущей runtime-ветки.

`build_levels.py` выдал для примера ['A','B','P']; такой порядок невозможен в runtime — B уже взорвана после A. Причина: редакторский solver удаляет блоки, но **не фигуры-соседи**, и не применяет все эффекты рекурсивной цепи. Swift solver, наоборот, вообще не снимает C и не решит даже правильный порядок. Два checker-а дают разные ответы об одном пазле.

### Редакторы и инструменты

- Python [Tools/build_levels.py:149](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/Tools/build_levels.py:149>)–190 и native Creator `LevelLogic.swift:101`–143 удаляют destructible при bomb, не удаляют соседние фигуры; у chain сразу удаляют linked piece без выполнения её bomb/chain-effects. Не совпадают с runtime.
- Оба редактора явно **пропускают проверку решаемости**, если есть double: [Tools/level_editor.py:1843](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/Tools/level_editor.py:1843>)–1846; [MazeArrowsCreator/MazeArrowsCreator/MazeArrowsCreator/EditorViewModel.swift:15](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrowsCreator/MazeArrowsCreator/MazeArrowsCreator/EditorViewModel.swift:15>)–17.
- Runtime [LevelValidator.swift:111](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Logic/LevelValidator.swift:111>)–126 проверяет границы obstacle и пересечение со стрелкой, затем текущий solver. Нет проверки пар portal, целей по ID, ссылок chain, уникальности IDs, дубликатов obstacle на одной клетке, meaningful color-group, диапазона frozen и согласованности альтернативных направлений.
- Native Creator cheap validator не проверяет selfBlockedExit, который runtime LevelValidator проверяет ([Creator/LevelLogic.swift:5](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrowsCreator/MazeArrowsCreator/MazeArrowsCreator/LevelLogic.swift:5>)–26 vs runtime [Logic/LevelValidator.swift:84](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Logic/LevelValidator.swift:84>)–90). Это ещё один дрейф правил.
- [LevelGenerator.swift:28](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Logic/LevelGenerator.swift:28>)–34 строит маску всего прямоугольника, создаёт только snakes, не передаёт obstacles/goal в Level (`68`–79). Это хороший генератор базового наполнения, не генератор осмысленных комбинаций препятствий.
- `LevelMetrics` умеет initialMovable, parallelDepth, дальние блокеры/traps, dullRatio. Depth тоже считается простым снятием всех доступных фигур, без side effects ([SnakeFillGenerator.swift:93](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Logic/SnakeFillGenerator.swift:93>)–99). После новых механик нельзя использовать его как доказанную меру сложности.
- [Tools/LevelBaker/main.swift:137](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/Tools/LevelBaker/main.swift:137>)–188 добавляет лишь fragile/frozen/key-lock и проверяет текущим solver. Он генерирует целый каталог 1…240 (`214`), сохраняет JSON целиком (`244`–245), а bake.sh по умолчанию пишет в app Data/levels.json (`7`). Его нельзя запускать для продолжения кампании без отдельного append-only пути.
- Старый [Tools/generate_campaign_levels.py:213](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/Tools/generate_campaign_levels.py:213>) генерирует 1…50 и перезаписывает catalog (`230`–232). Старые ручные special-level заготовки находятся в build_levels.py, но они не текущая кампании.
- В просмотренных `MazeArrowsTests/*.swift` не обнаружено целевых тестов bomb/destructible/frozen/double/chain/portal/fragile/альтернативных целей. Имеющиеся undo-тесты относятся к экономике ресурсов, не восстановлению сложного игрового состояния.

## Обязательные условия перед новыми механиками

1. **Сохранить наследие:** не менять смысл текущего frozen/fragile/key-lock для уровней 1…240. Новый соседский лёд — отдельное правило/версия, а не переосмысление frozenUnlockNeighbors. Для существующего глобального счётчика честнее объяснение «разморозится после ещё N снятых стрелок»; новый вариант можно назвать печатью/зарядом.
2. **Один переход состояния:** общая чистая операция apply(action,state) для игрового движка, solver, hint и editor; действия с направлением, результат с удалениями/изменениями/автосерией. Это prerequisite, не пожелание, для meaningful bombs/double/переключателей.
3. **Undo как транзакция:** сейчас history=[ArrowPiece] и undo делает append(last) ([GameViewModel.swift:118](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/ViewModels/GameViewModel.swift:118>)–119,343–357). Не возвращает взорванные фигуры/блоки, не отменяет автосерию одной операцией, не восстанавливает направление до swipe. Для новых правил нужно восстановление предыдущего Board и логического состояния хода; экономика/таймер — отдельное сознательное решение дизайна.
4. **Явно выбрать отношение к тупикам:** для спокойной основной кампании можно сохранять гарантию «каждый допустимый ход безопасен». Для экспертного режима допустимы ошибки планирования, если есть проверка тупика, объяснение и дешёвый/free отмена последнего решения. Нельзя незаметно перевести спокойную игру в необратимые ловушки с платной Undo.
5. **Прозрачная обратная связь:** counter frozen, открытие lock, связь chain, радиус bomb, целевая стрелка/группа, траектория portal/double. Сейчас preview/firstCollision проверяет геометрический луч, но не frozen/lock доступность ([MoveValidator.swift:122](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Logic/MoveValidator.swift:122>)–134); «путь свободен» может сочетаться с невозможным ходом. Нужна причина блокировки, не просто красный bump.
6. **Goal-aware solver:** для rescue/color задачи достаточно достижимости цели, а не очистки всего поля. Для expert choice — состояние должно включать направления, препятствия/двери/ресурсы, а не только удалённые IDs.
7. **Share codec:** encode не сохраняет obstacles, goal и chainedPieceId ([LevelShareCodec.swift:81](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Logic/LevelShareCodec.swift:81>)–158); decode даёт новые IDs sh_N и defaults (`239`–265). До шаринга новых задач требуется формат, сохраняющий правила/ссылки, или явный отказ от неподдерживаемого экспорта. Молчаливый экспорт сейчас превратит особый пазл в другую игру.
8. **Строгая схема новых данных:** неизвестный PieceKind сейчас превращается в standard ([Models/ArrowPiece.swift:83](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Models/ArrowPiece.swift:83>)), неудачно декодированный массив obstacles целиком превращается в [] ([Models/Level.swift:79](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Models/Level.swift:79>)), неизвестная goal — clearAll ([Models/LevelGoal.swift:53](</Users/stepanovdmitriy/All Doc/Coding/ZimmaInc/Maze Arrows/MazeArrows/MazeArrows/Models/LevelGoal.swift:53>)). Для новых/импортируемых правил нужны rulesVersion и явная ошибка несовместимости; legacy defaults сохранить только для старого формата.
9. **Проверки содержимого:** immutable hash текущих 240 уровней, новые индексы от 241, уникальные IDs/indices, ссылки целей/пар/цепей, повторное исполнение solver-сценариев через тот же transition, round-trip sharing и Undo, проверка всех доступных первых ходов там, где обещана безопасность.

## Приоритеты с точки зрения имеющихся заготовок

Наименьшая стоимость нового интереса — **новые задачи**, не новый физический движок: rescue конкретной стрелки, собрать выбранную группу, несколько видимых ключей/замков, курируемые domino-серии. К ним нужны оформление цели/обратная связь и корректные checker/Undo/share, но сама условная логика уже есть.

Наиболее сильное продолжение с изменением поля — **разрушаемые блоки с предсказуемым локальным взрывом** либо одноразовые открываемые двери; сначала решить семантику цепных взрывов/безопасных ходов. Это действительно изменяет зависимости по ходу пазла.

**Double** может добавлять выбор, но в чистом удалении фигуры после успешного выхода оба направления дают одинаковое конечное Board, т.е. сама по себе альтернативная сторона — в основном дополнительный способ найти доступный выход, а не глубокая развилка. Глубина появится только если направления имеют разные эффекты/цели/маршруты. Не продавать голый double как «многоходовую стратегию».

**Portal** визуально сильный кандидат для следующей полноценной механики: фиксированные пары превращают прямой луч в составной маршрут. Нужны детерминированный трассировщик, detection циклов, preview, анимация по маршруту и solver; текущая картинка не сокращает эту логическую работу. Если пары фиксированы и выход только удаляет стрелку, монотонность можно сохранить.

**Ice tile/spring** пока не имеют ясной роли в модели, где корректная стрелка сразу целиком уходит с поля. «Проехать ещё одну клетку» ничего не меняет для бесконечного выхода. Сначала сформулировать взаимодействие (поворот, одноразовый перенос, остановка на клетке) и доказать интерес, потом вкладываться в реализацию. Heavy и дополнительное наказание fragile не приоритет для разнообразия решений.
