# ТЗ: Puzzle Game “Maze Arrows”

## 0. Краткое описание

Нужно разработать iOS-игру-головоломку с лабиринтными стрелками.

На игровом поле расположены чёрные стрелки-лабиринты. Каждая стрелка — это не простая иконка, а цельная фигура из линии, которая занимает несколько клеток сетки и может иметь повороты. У каждой фигуры есть направление вылета: вверх, вниз, влево или вправо.

Игрок нажимает на фигуру. Если вся фигура может улететь в своём направлении, не столкнувшись с другими фигурами, она анимированно улетает за пределы поля и удаляется. Если на пути есть препятствие, фигура подсвечивается красным, не двигается, игрок теряет жизнь. Цель уровня — убрать все стрелки.

Главная особенность: проверять нужно не только наконечник стрелки, а всю форму фигуры на каждом шаге движения.

---

## 1. Платформа и стек

Минимальная версия: **iOS 16**.

Использовать:

- **SwiftUI** — меню, экраны, прогресс, настройки, UI вокруг игры.
- **SpriteKit** — игровая сцена, отрисовка фигур, анимации, тапы.
- **Codable JSON** — хранение ручных уровней.
- **UserDefaults** или **SwiftData** — сохранение прогресса.
- Без сторонних библиотек на MVP.

Архитектура:

```text
App
 ├── SwiftUI Screens
 │    ├── MainMenuView
 │    ├── LevelSelectView
 │    ├── GameView
 │    ├── SettingsView
 │    └── ResultView / Overlay
 │
 ├── SpriteKit
 │    ├── GameScene
 │    ├── ArrowPieceNode
 │    └── BoardRenderer
 │
 ├── Game Logic
 │    ├── Board
 │    ├── ArrowPiece
 │    ├── GridPoint
 │    ├── Direction
 │    ├── MoveValidator
 │    ├── LevelSolver
 │    └── LevelGenerator
 │
 ├── Data
 │    ├── Level
 │    ├── LevelLoader
 │    ├── ProgressStore
 │    └── DifficultyConfig
 │
 └── Resources
      └── levels.json
```

---

## 2. Основная механика

На уровне есть поле и набор лабиринтных стрелок.

Каждая стрелка:

- занимает несколько клеток сетки;
- состоит из связного пути;
- имеет направление вылета;
- отрисовывается как толстая линия с поворотами;
- имеет наконечник стрелки на конце;
- является одним цельным объектом;
- при успешном ходе улетает целиком.

Важно: нарисованный лабиринтный путь — это **форма объекта**, а не маршрут движения.

Например фигура может выглядеть так:

```text
┌────→
│
└──
```

Но при нажатии она улетает вправо целиком.

---

## 3. Игровая сетка

Вся логика работает на невидимой сетке.

Пример размеров:

```text
Easy:   7 x 9
Medium: 9 x 12
Hard:   10 x 14
```

Игрок сетку не видит. Сетка нужна для:

- проверки столкновений;
- генерации уровней;
- отрисовки линий;
- адаптации под разные экраны;
- стабильной логики.

Координаты сетки:

```swift
struct GridPoint: Hashable, Codable {
    let x: Int
    let y: Int
}
```

`x` растёт слева направо.  
`y` лучше сделать сверху вниз для логики, а при рендере конвертировать в координаты SpriteKit.

---

## 4. Модели данных

### 4.1 Direction

```swift
enum Direction: String, Codable, CaseIterable {
    case up
    case down
    case left
    case right
}
```

У `Direction` должны быть:

```swift
var dx: Int
var dy: Int
var vector: CGVector
var angle: CGFloat
```

Пример:

```swift
extension Direction {
    var dx: Int {
        switch self {
        case .left: return -1
        case .right: return 1
        case .up, .down: return 0
        }
    }

    var dy: Int {
        switch self {
        case .up: return -1
        case .down: return 1
        case .left, .right: return 0
        }
    }
}
```

### 4.2 GridPoint

```swift
struct GridPoint: Hashable, Codable {
    let x: Int
    let y: Int

    func moved(_ direction: Direction) -> GridPoint {
        GridPoint(
            x: x + direction.dx,
            y: y + direction.dy
        )
    }
}
```

### 4.3 ArrowPiece

```swift
struct ArrowPiece: Identifiable, Codable, Hashable {
    let id: String
    var cells: [GridPoint]
    var direction: Direction
}
```

`cells` — все клетки, которые занимает фигура.

Требования к `cells`:

- минимум 2 клетки;
- клетки должны быть связными;
- каждая следующая клетка должна быть соседней по вертикали или горизонтали;
- фигура не должна самопересекаться;
- одна фигура не должна занимать одну клетку дважды;
- разные фигуры не должны занимать одинаковые клетки.

### 4.4 Level

```swift
struct Level: Identifiable, Codable {
    let id: String
    let index: Int
    let difficulty: Difficulty
    let width: Int
    let height: Int
    let lives: Int
    let pieces: [ArrowPiece]
}
```

### 4.5 Difficulty

```swift
enum Difficulty: String, Codable {
    case easy
    case medium
    case hard
}
```

### 4.6 Board

```swift
struct Board {
    let width: Int
    let height: Int
    var pieces: [ArrowPiece]
}
```

У `Board` должны быть методы:

```swift
func isInside(_ point: GridPoint) -> Bool
func piece(at point: GridPoint) -> ArrowPiece?
func occupiedMap() -> [GridPoint: String]
mutating func removePiece(id: String)
```

---

## 5. Правила движения

При нажатии на фигуру нужно проверить, может ли она улететь.

Фигура может улететь, если при движении в своём направлении она не столкнётся ни с одной другой фигурой до полного выхода за пределы поля.

Важно: проверять надо **всю фигуру**, а не только наконечник стрелки.

Алгоритм:

```swift
func canFlyOut(piece: ArrowPiece, board: Board) -> Bool {
    let occupied = board.occupiedMap()
    var movingCells = Set(piece.cells)

    while !movingCells.isEmpty {
        let nextCells = Set(movingCells.map { $0.moved(piece.direction) })

        for cell in nextCells {
            guard board.isInside(cell) else {
                continue
            }

            if let blockerId = occupied[cell], blockerId != piece.id {
                return false
            }
        }

        movingCells = Set(nextCells.filter { board.isInside($0) })
    }

    return true
}
```

Объяснение:

- берём все клетки фигуры;
- двигаем их на 1 клетку в направлении стрелки;
- если новая позиция пересекается с другой фигурой — ход запрещён;
- клетки, вышедшие за пределы поля, удаляются из симуляции;
- когда все клетки вышли за пределы поля — фигура может улететь.

---

## 6. Реакция на нажатие

При тапе по фигуре:

```text
1. Найти ArrowPiece по node.name / id.
2. Проверить canFlyOut.
3. Если true:
   - убрать фигуру из логического board;
   - запустить анимацию вылета;
   - удалить node со сцены;
   - проверить победу.
4. Если false:
   - подсветить фигуру красным;
   - сделать shake-анимацию;
   - проиграть haptic / звук ошибки;
   - отнять 1 жизнь;
   - если жизней 0 — показать экран поражения / restart.
```

Важно: при успешном ходе фигуру нужно удалить из `board` **до окончания анимации**, чтобы остальные фигуры сразу считались разблокированными.

---

## 7. Подсветка заблокированной фигуры

Если фигура не может улететь:

- линия становится красной на 0.25–0.4 сек;
- фигура слегка трясётся;
- затем возвращается в чёрный цвет;
- отнимается одно сердце.

Пример:

```swift
func showBlockedFeedback(for node: ArrowPieceNode) {
    node.setColor(.systemRed)

    let shake = SKAction.sequence([
        .moveBy(x: -6, y: 0, duration: 0.04),
        .moveBy(x: 12, y: 0, duration: 0.08),
        .moveBy(x: -6, y: 0, duration: 0.04)
    ])

    let reset = SKAction.run {
        node.setColor(.black)
    }

    node.run(.sequence([
        shake,
        .wait(forDuration: 0.15),
        reset
    ]))
}
```

---

## 8. Анимация успешного вылета

Если ход разрешён:

- фигура двигается в своём направлении;
- скорость быстрая, но читаемая;
- длительность примерно 0.25–0.35 сек;
- в конце node удаляется.

Нужно рассчитать дистанцию, чтобы вся фигура полностью вышла за экран/поле.

Пример:

```swift
func exitDistance(for piece: ArrowPiece, board: Board, cellSize: CGFloat) -> CGFloat {
    switch piece.direction {
    case .right:
        let maxX = piece.cells.map(\.x).max() ?? 0
        return CGFloat(board.width - maxX + 2) * cellSize

    case .left:
        let minX = piece.cells.map(\.x).min() ?? 0
        return CGFloat(minX + 2) * cellSize

    case .down:
        let maxY = piece.cells.map(\.y).max() ?? 0
        return CGFloat(board.height - maxY + 2) * cellSize

    case .up:
        let minY = piece.cells.map(\.y).min() ?? 0
        return CGFloat(minY + 2) * cellSize
    }
}
```

---

## 9. Отрисовка лабиринтной стрелки

Каждая фигура должна быть отдельным `SKNode`.

Структура:

```text
ArrowPieceNode
 ├── lineShape: SKShapeNode
 └── arrowHead: SKShapeNode
```

Линия строится по `cells`.

```swift
final class ArrowPieceNode: SKNode {
    let pieceId: String
    private let lineShape: SKShapeNode
    private let arrowHead: SKShapeNode
}
```

Требования к стилю:

- цвет линии: чёрный;
- толщина линии: 6–10 pt в зависимости от размера клетки;
- `lineCap = .round`;
- `lineJoin = .round`;
- наконечник стрелки чёрный;
- при ошибке вся фигура становится красной;
- при hint можно подсвечивать зелёным/синим;
- фигура должна иметь нормальную hit area, чтобы по ней удобно было нажимать.

### 9.1 Построение линии

```swift
func makePath(cells: [GridPoint], cellSize: CGFloat) -> CGPath {
    let path = CGMutablePath()

    guard let first = cells.first else {
        return path
    }

    path.move(to: pointForCell(first, cellSize: cellSize))

    for cell in cells.dropFirst() {
        path.addLine(to: pointForCell(cell, cellSize: cellSize))
    }

    return path
}
```

### 9.2 Наконечник стрелки

Наконечник должен находиться на последней клетке пути или на конце визуальной линии.

Для MVP:

- использовать `SKShapeNode` с треугольником;
- повернуть по `piece.direction`.

Пример формы:

```swift
func makeArrowHead(size: CGFloat) -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: size, y: 0))
    path.addLine(to: CGPoint(x: -size * 0.6, y: size * 0.6))
    path.addLine(to: CGPoint(x: -size * 0.6, y: -size * 0.6))
    path.closeSubpath()
    return path
}
```

Повороты:

```text
right: 0
down:  .pi / 2
left:  .pi
up:   -.pi / 2
```

---

## 10. Hit testing

Пользователь должен попадать по фигуре легко.

Не надо полагаться только на тонкую линию. Нужно сделать расширенную зону тапа.

Рекомендуемый вариант для MVP:

```text
ArrowPieceNode
 ├── visible line
 ├── visible arrow head
 └── invisible hit cells
```

Каждая hit-cell:

- прозрачная;
- размер примерно `cellSize * 0.9`;
- `isUserInteractionEnabled = false`;
- `name = piece.id`.

В `GameScene.touchesBegan` искать node с `name`.

---

## 11. UI уровня

Экран игры должен содержать:

Вверху:

- кнопка назад;
- кнопка restart;
- номер уровня;
- жизни в виде сердечек.

В центре:

- игровое поле;
- стрелки.

Внизу:

- можно оставить пустое место;
- позже добавить кнопки Hint / Undo / Skip.

Минимальный UI:

```text
[Back] [Restart]       Level 15
       ❤️ ❤️ ❤️ 🤍 🤍

        Game Board
```

При успешном прохождении:

- показать overlay “Level Complete”;
- кнопка Next;
- автоматически разблокировать следующий уровень.

При проигрыше:

- overlay “Try Again”;
- кнопка Restart.

---

## 12. Жизни

На уровне есть количество жизней.

По умолчанию:

```text
Easy:   5
Medium: 5
Hard:   3
```

При неправильном нажатии:

- минус 1 жизнь;
- если жизни > 0 — игра продолжается;
- если жизни == 0 — уровень проигран.

Жизни сбрасываются при restart уровня.

---

## 13. Restart

Кнопка restart должна:

- вернуть уровень в начальное состояние;
- восстановить все фигуры;
- восстановить жизни;
- очистить историю ходов;
- перерисовать сцену.

---

## 14. Undo

На MVP желательно сделать Undo, но можно после основной механики.

Undo должен:

- вернуть последнюю успешно удалённую фигуру;
- вернуть её в исходное место;
- восстановить board;
- не возвращать потерянные жизни за ошибки.

Для этого хранить историю:

```swift
struct MoveHistoryItem {
    let piece: ArrowPiece
}
```

При успешном удалении добавлять фигуру в history.

---

## 15. Hint

Hint должен показать одну фигуру, которая сейчас может улететь.

Алгоритм:

```swift
func availableMoves(board: Board) -> [ArrowPiece] {
    board.pieces.filter { canFlyOut(piece: $0, board: board) }
}
```

Если есть доступные фигуры:

- подсветить одну на 0.8 сек;
- можно выбрать ту, которая ближе к решению, если есть solution;
- на MVP выбрать любую.

---

## 16. Условие победы

Уровень пройден, если:

```swift
board.pieces.isEmpty == true
```

После победы:

- сохранить прогресс;
- открыть следующий уровень;
- показать экран успеха.

---

## 17. JSON-формат ручных уровней

Файл `levels.json`.

Пример:

```json
[
  {
    "id": "level_001",
    "index": 1,
    "difficulty": "easy",
    "width": 7,
    "height": 9,
    "lives": 5,
    "pieces": [
      {
        "id": "p1",
        "direction": "right",
        "cells": [
          { "x": 1, "y": 2 },
          { "x": 2, "y": 2 },
          { "x": 3, "y": 2 },
          { "x": 3, "y": 3 }
        ]
      },
      {
        "id": "p2",
        "direction": "down",
        "cells": [
          { "x": 5, "y": 1 },
          { "x": 5, "y": 2 },
          { "x": 6, "y": 2 }
        ]
      }
    ]
  }
]
```

При загрузке уровня нужно валидировать:

- все координаты внутри поля;
- нет пересечений между фигурами;
- каждая фигура связная;
- нет повторов клеток внутри фигуры;
- уровень решаемый.

---

## 18. Solver уровня

Нужен автоматический solver, чтобы проверять, решается ли уровень.

Solver нужен для:

- проверки ручных уровней;
- будущей автогенерации;
- hint;
- оценки сложности.

Базовый greedy-solver:

```swift
func solve(board: Board) -> [String]? {
    var board = board
    var solution: [String] = []

    while !board.pieces.isEmpty {
        let movable = board.pieces.filter {
            canFlyOut(piece: $0, board: board)
        }

        if movable.isEmpty {
            return nil
        }

        let piece = movable[0]
        solution.append(piece.id)
        board.removePiece(id: piece.id)
    }

    return solution
}
```

Для этой механики этого обычно достаточно, потому что удаление фигур только упрощает поле. Но архитектуру нужно сделать так, чтобы потом можно было заменить solver на более умный.

---

## 19. Генерация уровней

Нужен автогенератор уровней с разной сложностью.

Генератор не должен просто случайно раскидывать фигуры. Он должен:

- создавать красивые лабиринтные фигуры;
- размещать их без пересечений;
- проверять решаемость;
- оценивать качество уровня;
- отбрасывать плохие варианты.

### 19.1 Конфиг сложности

```swift
struct DifficultyConfig {
    let width: Int
    let height: Int
    let piecesCount: ClosedRange<Int>
    let minPathLength: Int
    let maxPathLength: Int
    let maxTurns: Int
    let targetDensity: Double
    let minBlockedRatio: Double
    let maxInitialMovable: Int
    let lives: Int
}
```

Пример:

```swift
let easy = DifficultyConfig(
    width: 7,
    height: 9,
    piecesCount: 8...14,
    minPathLength: 2,
    maxPathLength: 4,
    maxTurns: 1,
    targetDensity: 0.35,
    minBlockedRatio: 0.35,
    maxInitialMovable: 5,
    lives: 5
)

let medium = DifficultyConfig(
    width: 9,
    height: 12,
    piecesCount: 18...30,
    minPathLength: 2,
    maxPathLength: 6,
    maxTurns: 2,
    targetDensity: 0.50,
    minBlockedRatio: 0.55,
    maxInitialMovable: 4,
    lives: 5
)

let hard = DifficultyConfig(
    width: 10,
    height: 14,
    piecesCount: 35...50,
    minPathLength: 3,
    maxPathLength: 9,
    maxTurns: 4,
    targetDensity: 0.65,
    minBlockedRatio: 0.70,
    maxInitialMovable: 3,
    lives: 3
)
```

### 19.2 Шаблоны фигур

Чтобы фигуры были красивыми, использовать не чистый рандом, а шаблоны.

Пример шаблонов:

```text
1. ───→

2. └──→

3. ┌──→

4. ┌─┐
   └→

5. ┌──
   │
   └→

6. ─┐
    └──→
```

В коде:

```swift
struct ShapeTemplate {
    let cells: [GridPoint]
    let direction: Direction
}
```

Шаблон можно:

- поворачивать;
- зеркалить;
- переносить на поле;
- иногда удлинять прямые сегменты.

### 19.3 Размещение фигур

Алгоритм генерации:

```text
1. Создать пустой Board.
2. Выбрать DifficultyConfig.
3. Случайно выбрать количество фигур.
4. Пока фигур меньше нужного:
   - выбрать шаблон;
   - случайно повернуть/отразить;
   - выбрать случайную позицию;
   - проверить, помещается ли фигура;
   - проверить, не пересекается ли с другими;
   - добавить фигуру.
5. Запустить solver.
6. Посчитать метрики сложности.
7. Если уровень плохой — сгенерировать заново.
8. Если хороший — вернуть Level.
```

### 19.4 Проверка размещения

```swift
func canPlace(piece: ArrowPiece, board: Board) -> Bool {
    let occupied = board.occupiedMap()

    for cell in piece.cells {
        if !board.isInside(cell) {
            return false
        }

        if occupied[cell] != nil {
            return false
        }
    }

    return true
}
```

### 19.5 Метрики качества уровня

После генерации нужно посчитать:

1. Решаемость.
2. Количество доступных ходов на старте.
3. Доля заблокированных фигур.
4. Плотность поля.
5. Длина решения.
6. Визуальная сложность: количество клеток, поворотов, средняя длина фигуры.

Пример проверки:

```swift
func isGoodLevel(
    board: Board,
    solution: [String],
    config: DifficultyConfig
) -> Bool {
    let initialMovable = availableMoves(board).count
    let density = calculateDensity(board)
    let blockedRatio = calculateBlockedRatio(board)

    return initialMovable > 0
        && initialMovable <= config.maxInitialMovable
        && density >= config.targetDensity * 0.8
        && density <= config.targetDensity * 1.2
        && blockedRatio >= config.minBlockedRatio
}
```

---

## 20. Валидация фигуры

Каждая фигура должна быть валидной.

Проверки:

```text
1. cells.count >= 2
2. Нет повторяющихся cells
3. Все cells внутри board
4. Каждая следующая cell соседняя по вертикали/горизонтали
5. Фигура не пересекается с другими
```

Пример:

```swift
func isValidPiece(_ piece: ArrowPiece, board: Board) -> Bool {
    guard piece.cells.count >= 2 else { return false }
    guard Set(piece.cells).count == piece.cells.count else { return false }

    for cell in piece.cells {
        guard board.isInside(cell) else { return false }
    }

    for index in 1..<piece.cells.count {
        let previous = piece.cells[index - 1]
        let current = piece.cells[index]

        let dx = abs(previous.x - current.x)
        let dy = abs(previous.y - current.y)

        guard dx + dy == 1 else {
            return false
        }
    }

    return true
}
```

---

## 21. Зависимости между фигурами

Для анализа сложности можно определить, кто кого блокирует.

```swift
func blockers(for piece: ArrowPiece, board: Board) -> Set<String> {
    let occupied = board.occupiedMap()
    var result = Set<String>()
    var movingCells = Set(piece.cells)

    while !movingCells.isEmpty {
        let nextCells = Set(movingCells.map { $0.moved(piece.direction) })

        for cell in nextCells {
            if board.isInside(cell),
               let blockerId = occupied[cell],
               blockerId != piece.id {
                result.insert(blockerId)
            }
        }

        movingCells = Set(nextCells.filter { board.isInside($0) })
    }

    return result
}
```

Если `blockers` пустой — фигура доступна.

Если не пустой — фигура заблокирована.

---

## 22. Прогресс игрока

Нужно сохранять:

```swift
struct PlayerProgress: Codable {
    var unlockedLevelIndex: Int
    var completedLevels: Set<Int>
    var hintsCount: Int
}
```

Для MVP можно хранить в `UserDefaults`.

Требования:

- после прохождения уровня открывается следующий;
- пройденные уровни отмечаются;
- текущий прогресс сохраняется между запусками.

---

## 23. Экраны приложения

### 23.1 MainMenuView

Кнопки:

```text
Play
Levels
Settings
```

`Play` открывает последний доступный уровень.

### 23.2 LevelSelectView

Показать список/сетку уровней:

- открытые уровни доступны;
- закрытые заблокированы;
- пройденные отмечены галочкой.

### 23.3 GameView

Содержит `SpriteView(scene:)`.

SwiftUI отвечает за:

- верхнюю панель;
- уровень;
- жизни;
- кнопки;
- overlay победы/поражения.

SpriteKit отвечает за:

- игровое поле;
- фигуры;
- тапы по фигурам;
- анимации.

### 23.4 SettingsView

Минимально:

```text
Sound On/Off
Haptics On/Off
Reset Progress
Privacy Policy placeholder
```

---

## 24. GameScene

`GameScene` должна:

- принимать `Level`;
- строить board;
- рисовать все `ArrowPieceNode`;
- обрабатывать тапы;
- сообщать SwiftUI о событиях через callback/delegate.

Пример callback:

```swift
final class GameScene: SKScene {
    var onLivesChanged: ((Int) -> Void)?
    var onLevelCompleted: (() -> Void)?
    var onLevelFailed: (() -> Void)?
}
```

---

## 25. Связь SwiftUI и SpriteKit

`GameViewModel` хранит состояние:

```swift
final class GameViewModel: ObservableObject {
    @Published var level: Level
    @Published var lives: Int
    @Published var isCompleted: Bool
    @Published var isFailed: Bool
}
```

`GameView` создаёт сцену:

```swift
SpriteView(scene: scene)
```

Сцена сообщает события во ViewModel через closures.

---

## 26. Адаптация под разные экраны

Игровое поле должно:

- центрироваться;
- сохранять пропорции;
- подбирать `cellSize` по доступному месту;
- не залезать под верхний UI и нижнюю область;
- корректно работать на iPhone SE и больших iPhone.

Расчёт:

```swift
let cellSize = min(
    availableWidth / CGFloat(board.width),
    availableHeight / CGFloat(board.height)
)
```

---

## 27. Визуальный стиль MVP

Фон:

- белый или очень светлый.

Стрелки:

- чёрные;
- толстые;
- скруглённые;
- без лишних деталей.

Ошибочная стрелка:

- красная.

Доступная подсказка:

- зелёная/синяя пульсация.

UI:

- крупный текст;
- сердечки;
- простые кнопки;
- плавные анимации.

---

## 28. Звуки и haptics

На MVP:

- успешный вылет: лёгкий haptic;
- ошибка: warning haptic;
- победа: success haptic.

Звуки можно добавить позже.

---

## 29. Тестовые уровни

Сразу создать минимум 10 ручных уровней:

```text
1–3: Easy, маленькое поле, короткие фигуры
4–7: Medium, больше фигур, больше блокировок
8–10: Hard, длинные фигуры, плотное поле
```

Ручные уровни нужны, чтобы проверить механику до генератора.

---

## 30. Unit-тесты

Обязательно покрыть тестами:

### Board tests

- `isInside`;
- `occupiedMap`;
- `removePiece`.

### MoveValidator tests

- фигура может улететь вправо;
- фигура заблокирована другой фигурой;
- фигура сложной формы задевает препятствие боковой частью;
- фигура выходит за поле полностью;
- фигура не сталкивается сама с собой.

### Level validation tests

- фигура с повторяющимися клетками невалидна;
- фигура с диагональным шагом невалидна;
- пересекающиеся фигуры невалидны;
- уровень без решения невалиден.

### Solver tests

- простой уровень решается;
- уровень без доступных ходов возвращает nil.

---

## 31. Важный тест на сложную форму

Обязательно проверить кейс:

Фигура A занимает:

```text
(1,1), (2,1), (3,1), (3,2)
```

и летит вправо.

Фигура B стоит в:

```text
(4,2)
```

Хотя перед наконечником может быть свободно, нижняя часть фигуры A при движении вправо столкнётся с B.  
`canFlyOut` должен вернуть `false`.

Это ключевой тест.

---

## 32. Порядок разработки

### Этап 1 — базовая логика

Сделать:

- `GridPoint`;
- `Direction`;
- `ArrowPiece`;
- `Board`;
- `MoveValidator`;
- unit-тесты.

Результат: логика движения работает без UI.

### Этап 2 — SpriteKit-прототип

Сделать:

- `GameScene`;
- отрисовку фигур;
- один ручной уровень;
- тап по фигуре;
- успешный вылет;
- красную ошибку.

Результат: можно играть в один уровень.

### Этап 3 — SwiftUI-обвязка

Сделать:

- `GameView`;
- верхний UI;
- жизни;
- restart;
- win/fail overlay.

Результат: полноценный экран игры.

### Этап 4 — уровни из JSON

Сделать:

- `levels.json`;
- `LevelLoader`;
- валидацию уровней;
- выбор уровня;
- сохранение прогресса.

Результат: игра с ручными уровнями.

### Этап 5 — Solver и Hint

Сделать:

- solver;
- available moves;
- hint;
- тесты.

Результат: игра умеет проверять решения и подсказывать.

### Этап 6 — генератор

Сделать:

- шаблоны фигур;
- генерацию easy/medium/hard;
- проверку качества;
- fallback на ручные уровни.

Результат: можно создавать новые уровни автоматически.

### Этап 7 — полировка

Сделать:

- анимации;
- haptics;
- звуки;
- улучшенный UI;
- баланс сложности;
- больше уровней.

---

## 33. Что не делать в первой версии

Не делать сразу:

- сложную экономику;
- рекламу;
- покупки;
- ежедневные челленджи;
- онлайн-синхронизацию;
- лидерборды;
- сложные скины;
- идеальный генератор.

Сначала нужно довести до идеала:

```text
нажатие → проверка всей формы → вылет / ошибка → прохождение уровня
```

---

## 34. Критерии готовности MVP

MVP считается готовым, если:

- есть минимум 20 уровней;
- фигуры рисуются как лабиринтные линии;
- каждая фигура занимает несколько клеток;
- можно нажимать по фигурам;
- свободные фигуры улетают;
- заблокированные подсвечиваются красным;
- жизни уменьшаются;
- restart работает;
- победа определяется корректно;
- прогресс сохраняется;
- уровни загружаются из JSON;
- есть solver для проверки уровней;
- нет багов с тем, что сложная фигура проходит сквозь другую.

---

## 35. Критерии готовности версии 1.0

Версия 1.0 считается готовой, если:

- есть 100+ уровней;
- есть easy/medium/hard баланс;
- есть generator или полуавтоматическая генерация;
- есть hint;
- есть undo;
- есть красивый UI;
- есть haptics/sounds;
- есть сохранение прогресса;
- игра корректно работает на разных iPhone;
- уровни не бывают нерешаемыми;
- сложность растёт постепенно.

---

## 36. Главная техническая идея

Главное правило всей игры:

> Стрелка — это не точка и не иконка. Стрелка — это цельная фигура из нескольких клеток. При проверке хода нужно двигать всю фигуру по клеткам до выхода за поле и проверять столкновение всей формы на каждом шаге.

Именно это отличает механику от простой игры со стрелками.

---

## 37. Минимальный пример ручного уровня

```json
{
  "id": "level_001",
  "index": 1,
  "difficulty": "easy",
  "width": 7,
  "height": 9,
  "lives": 5,
  "pieces": [
    {
      "id": "p1",
      "direction": "right",
      "cells": [
        { "x": 1, "y": 1 },
        { "x": 2, "y": 1 },
        { "x": 3, "y": 1 }
      ]
    },
    {
      "id": "p2",
      "direction": "down",
      "cells": [
        { "x": 5, "y": 1 },
        { "x": 5, "y": 2 },
        { "x": 4, "y": 2 }
      ]
    },
    {
      "id": "p3",
      "direction": "left",
      "cells": [
        { "x": 3, "y": 5 },
        { "x": 2, "y": 5 },
        { "x": 2, "y": 6 },
        { "x": 1, "y": 6 }
      ]
    }
  ]
}
```

---

## 38. Дополнительное требование к качеству кода

Код должен быть:

- разделён на логические файлы;
- без бизнес-логики внутри SwiftUI View;
- без смешивания рендера и правил игры;
- с понятными именами;
- с комментариями в сложных местах;
- легко расширяемым под рекламу, покупки и генератор.

Не хардкодить уровни внутри `GameScene`.  
Не делать проверку столкновений через физику SpriteKit.  
Вся игровая логика должна работать через сетку и модели данных.

---

## 39. Итоговая задача

Разработать iOS puzzle game, где игрок очищает поле от лабиринтных стрелок. Каждая стрелка является фигурой из нескольких клеток, имеет направление вылета и может быть удалена только если вся её форма может свободно выйти за пределы поля.

Игра должна поддерживать:

- ручные JSON-уровни;
- проверку решаемости;
- жизни;
- restart;
- победу/поражение;
- сохранение прогресса;
- подготовку к будущей автогенерации уровней.

Фичи!
Да, саму механику можно сильно усилить, чтобы это было не просто “убери стрелки”, а прям залипательная puzzle-игра с прогрессией, фишками и вариативностью.

1. Разные типы лабиринтных стрелок

Чтобы уровни не были однообразными, можно постепенно открывать новые типы объектов.

Обычная стрелка

Улетает, если путь свободен.

Тяжёлая стрелка

Улетает медленнее, занимает больше места, может быть толще визуально.

Хрупкая стрелка

Если игрок нажал на неё, когда она заблокирована — она трескается. Второй неправильный тап по ней ломает уровень или отнимает 2 жизни.

Замороженная стрелка

Сначала заблокирована льдом. Чтобы её активировать, нужно убрать рядом 1–2 другие фигуры.

Двойная стрелка

Имеет два возможных направления, например вправо и вверх. Игрок должен выбрать правильное направление свайпом.

Стрелка-замок

Не улетает, пока не убрать стрелку-ключ такого же цвета.

Стрелка-бомба

После удаления очищает соседние маленькие стрелки или разрушает блок.

Цепная стрелка

Когда улетает, автоматически запускает ещё одну связанную стрелку, если та свободна.

⸻

2. Не только стрелки, но и препятствия

Можно добавить элементы поля:

Стены

Фигура не может вылететь через стену.

Ворота

Пропускают стрелки только определённого цвета или направления.

Порталы

Стрелка при вылете может пройти через портал и выйти с другой стороны.

Лёд

Стрелка проскальзывает дальше или меняет поведение.

Пружины

Отталкивают стрелку назад, если она не может выйти.

Разрушаемые блоки

Некоторые стрелки при вылете могут разбивать блоки.

Это даст много разнообразия, особенно для medium/hard уровней.

⸻

3. Цветные “семейства” стрелок

Можно сделать не просто чёрные линии, а красивые цветовые группы:

* обычные чёрные;
* золотые премиум-стрелки;
* красные опасные;
* синие замороженные;
* зелёные ключи;
* фиолетовые портальные.

Но важно: цвет не должен ломать читаемость. Основа всё равно должна быть простой.

⸻

4. Комбо и цепные реакции

Чтобы было приятнее играть:

* убрал 3 стрелки без ошибки — Combo x3;
* 5 подряд — красивый glow;
* 10 подряд — бонусная подсказка;
* несколько стрелок улетели цепочкой — “Chain Clear”.

Это добавит кайф, даже если сама логика простая.

⸻

5. Режим “без ошибок”

Кроме жизней можно добавить режим:

Perfect Clear

Если игрок прошёл уровень без ошибок:

* получает звезду;
* открывает косметику;
* уровень отмечается золотой рамкой.

Прогрессия:

1 звезда — прошёл
2 звезды — прошёл с 1 ошибкой или меньше
3 звезды — прошёл идеально

⸻

6. Ежедневные уровни

Очень хорошая фишка для удержания:

Daily Maze

Каждый день один специальный уровень:

* уникальная тема дня;
* можно пройти только сегодня;
* награда за серию дней;
* календарь streak.

Например:

Day 1 — Simple Maze
Day 7 — Golden Maze
Day 30 — Special Skin

⸻

7. Локальные культурные темы

Твоя идея с локалью реально хорошая. Можно сделать не так, что игра меняет правила, а меняет визуальное настроение.

Примеры:

Japan

* мягкие пастельные цвета;
* фон с subtle sakura pattern;
* аккуратная минималистичная типографика;
* спокойные звуки.

Thailand

* тёплые золотые тона;
* мягкие орнаменты;
* tropical sunset theme;
* элементы воды/солнца.

USA / Canada

* clean casual design;
* яркие контрастные цвета;
* bold UI;
* сезонные темы: Halloween, Thanksgiving, Winter.

Europe

* минимализм;
* muted palette;
* elegant geometric patterns.

Middle East

* глубокие синие/золотые цвета;
* subtle geometric ornaments;
* premium feel.

Важно: не делать стереотипно и грубо. Это должны быть очень тонкие декоративные мотивы, которые можно отключить.

⸻

8. Сезонные скины

Можно сделать скины, которые меняют только визуал:

* Winter Maze;
* Neon Night;
* Sakura Garden;
* Desert Gold;
* Ocean Glass;
* Halloween Shadows;
* Lunar New Year;
* Cyber Maze.

Это легко монетизировать через IAP, но не влияет на механику.

⸻

9. Разные режимы игры

Classic

Обычные уровни с жизнями.

Relax

Без жизней, без давления. Идеально для casual-аудитории.

Challenge

Ограничение по ошибкам или ходам.

Timed

Нужно пройти за время.

Zen Daily

Один красивый уровень в день, спокойная музыка, без поражения.

Hard Mode

Минимум подсказок, сложные фигуры, меньше доступных ходов.

⸻

10. Особые цели уровня

Не всегда “убери всё”. Можно добавить цели:

Clear all gold arrows
Clear the board without mistakes
Remove keys before locks
Free the trapped gem
Clear in under 40 seconds
Use no hints

Например на поле есть “кристалл”, закрытый лабиринтными стрелками. Цель — освободить его.

⸻

11. Сюжетная оболочка

Можно сделать очень лёгкую историю, чтобы игра была не пустой.

Варианты:

“Unwind the Maze”

Игрок распутывает энергетические линии.

“Path Garden”

Каждый уровень очищает сад/парк/город.

“Signal Flow”

Игрок освобождает потоки света.

“Travel Maze”

Каждая глава — страна/регион, с локальной визуальной темой.

Для твоей идеи с локалью особенно хорошо:

World Maze Journey

Игрок проходит главы по разным визуальным мирам. Но темы могут адаптироваться под локаль.

⸻

12. Метапрогрессия

Чтобы игрок возвращался:

* карта глав;
* сундуки за прохождение;
* коллекция скинов;
* ежедневные задания;
* достижения;
* streak;
* weekly challenge.

Примеры заданий:

Complete 5 levels without mistakes
Use 0 hints in 3 levels
Clear 20 blue arrows
Complete daily puzzle 3 days in a row

⸻

13. Умные подсказки

Подсказка не просто “нажми сюда”, а несколько уровней:

Hint 1

Подсветить область.

Hint 2

Подсветить конкретную фигуру.

Hint 3

Показать порядок следующих 2 ходов.

Это лучше для монетизации и UX.

⸻

14. “Preview path” при удержании

Очень полезная фишка:

Если игрок зажал стрелку, игра показывает полупрозрачную траекторию, куда она улетит.

Если заблокирована — показывает красную точку/свет в месте столкновения.

Это сделает игру понятнее и красивее.

⸻

15. Разные формы лабиринтных объектов

Чтобы визуал был богаче:

* короткие прямые;
* L-образные;
* U-образные;
* S-образные;
* спиральные;
* двойные петли;
* толстые “канаты”;
* неоновые трубки;
* стеклянные дорожки;
* деревянные/металлические дорожки.

Главное — все формы всё равно должны быть читаемыми на сетке.

⸻

16. “Тактильность” объектов

Чтобы было приятнее:

* стрелки слегка подпрыгивают при тапе;
* свободная стрелка перед вылетом чуть сжимается;
* заблокированная дрожит;
* при вылете оставляет trail;
* при combo появляется мягкая вспышка;
* при победе оставшиеся частицы собираются в символ.

Это сильно повышает ощущение качества.

⸻

17. Идея для уникальности: “Mood Adaptive Themes”

Можно сделать фишку:

Game adapts its look to your mood, region and time of day.

Например:

* утром — светлая мягкая тема;
* вечером — dark calm;
* ночью — neon;
* в Японии — Sakura Calm;
* в Таиланде — Tropical Gold;
* в зимний сезон — Snow Glass;
* на праздники — event skin.

В настройках:

Theme Mode:
Auto / Light / Dark / Region / Seasonal / Custom

Это звучит сильно для маркетинга.

⸻

18. Идея для App Store screenshots

Можно позиционировать так:

Unblock beautiful maze arrows
Solve satisfying path puzzles
Clear levels with perfect combos
Daily puzzles and relaxing themes
Personalized visual worlds

То есть не просто “arrow puzzle”, а:

satisfying maze path puzzle

⸻

Что я бы добавил в MVP обязательно

Не всё сразу. Для первой версии я бы выбрал вот это:

1. Лабиринтные стрелки
2. Жизни
3. Restart
4. Hint
5. Perfect Clear / 3 stars
6. Daily Puzzle
7. 3 визуальные темы
8. Preview path on long press
9. Combo feedback
10. Level map / chapters

А позже:

1. Ключи и замки
2. Порталы
3. Замороженные стрелки
4. Локальные культурные темы
5. Сезонные события
6. Скины

Самая сильная концепция

Я бы оформил игру так:

Maze Arrows — satisfying puzzle game where you untangle beautiful maze paths.

Главная фишка:

* не обычные стрелки;
* каждая стрелка — красивая лабиринтная форма;
* темы адаптируются под настроение, время дня и регион;
* уровни становятся сложнее за счёт новых типов путей: ключи, замки, порталы, ледяные линии.

Это уже выглядит как полноценная игра, а не простая механика.