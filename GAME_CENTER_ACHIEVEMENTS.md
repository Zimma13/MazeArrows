# Arrow Maze — Game Center achievements

This file is the App Store Connect source of truth. Achievement IDs and point
values must exactly match `GameCenterAchievements.swift`.

## Common settings

- Hidden: No
- Achievable More Than Once: No
- Image: required, 1024×1024 px, RGB, PNG/JPEG
- Prepared images: `AppStore/GameCenter/Achievements/`
- Preview sheet: `AppStore/GameCenter/achievements_contact_sheet.png`
- Total points: 600

## Current status (August 13, 2026)

- All 15 achievements are created in App Store Connect.
- All 3 leaderboards are created in App Store Connect.
- Every identifier and point value matches the app configuration.
- All achievements and leaderboards are localized for Chinese (Traditional),
  English (Australia), English (Canada), English (U.K.), English (U.S.), French,
  French (Canada), German, Japanese, Korean, Portuguese (Brazil), Russian,
  Spanish (Mexico), and Spanish (Spain).
- Each achievement localization has its prepared 1024×1024 image.
- All achievements are in `Prepare for Submission` status.
- Achievements have not been added to the review submission yet.
- Optimized in-app artwork is bundled in `MazeArrows/MazeArrows/Assets.xcassets`
  at 64, 128, and 192 px for 1x, 2x, and 3x displays.

## Identifiers and points

| # | Reference Name | Achievement ID | Points | Image file |
|---:|---|---|---:|---|
| 1 | First Steps | `zimma.mazearrows.achievement.first_clear` | 10 | `01_first_clear.png` |
| 2 | Meadow Wanderer | `zimma.mazearrows.achievement.chapter1_complete` | 40 | `02_chapter1_complete.png` |
| 3 | Forest Explorer | `zimma.mazearrows.achievement.chapter2_complete` | 50 | `03_chapter2_complete.png` |
| 4 | Summit Seeker | `zimma.mazearrows.achievement.chapter3_complete` | 60 | `04_chapter3_complete.png` |
| 5 | Pathfinder | `zimma.mazearrows.achievement.all_levels_complete` | 100 | `05_all_levels_complete.png` |
| 6 | Perfectionist | `zimma.mazearrows.achievement.perfect_clear` | 20 | `06_perfect_clear.png` |
| 7 | Purist | `zimma.mazearrows.achievement.hintless_win` | 20 | `07_hintless_win.png` |
| 8 | Speed Demon | `zimma.mazearrows.achievement.speedrun` | 30 | `08_speedrun.png` |
| 9 | Combo Master | `zimma.mazearrows.achievement.combo_master` | 40 | `09_combo_master.png` |
| 10 | Flawless Meadow | `zimma.mazearrows.achievement.perfect_chapter1` | 75 | `10_perfect_chapter1.png` |
| 11 | On a Roll | `zimma.mazearrows.achievement.streak_3` | 25 | `11_streak3.png` |
| 12 | Dedicated | `zimma.mazearrows.achievement.streak_7` | 50 | `12_streak7.png` |
| 13 | Weekly Champion | `zimma.mazearrows.achievement.weekly_champion` | 40 | `13_weekly_champion.png` |
| 14 | Quest Finisher | `zimma.mazearrows.achievement.quest_complete` | 25 | `14_quest_complete.png` |
| 15 | Coin Collector | `zimma.mazearrows.achievement.coin_collector` | 15 | `15_coin_collector.png` |

## English localization

| # | Display Name | Pre-earned Description | Earned Description |
|---:|---|---|---|
| 1 | First Steps | Complete your first level. | You completed your first level. |
| 2 | Meadow Wanderer | Complete all levels in The Meadows. | You completed all levels in The Meadows. |
| 3 | Forest Explorer | Complete all levels in The Forest. | You completed all levels in The Forest. |
| 4 | Summit Seeker | Complete all levels in The Mountains. | You completed all levels in The Mountains. |
| 5 | Pathfinder | Complete all 240 levels. | You completed all 240 levels. |
| 6 | Perfectionist | Earn 3 stars on any level. | You earned 3 stars on a level. |
| 7 | Purist | Complete a level without using any hints. | You completed a level without using hints. |
| 8 | Speed Demon | Complete a level in under 60 seconds. | You completed a level in under 60 seconds. |
| 9 | Combo Master | Achieve a 5× combo in a single level. | You achieved a 5× combo in a single level. |
| 10 | Flawless Meadow | Earn 3 stars on every level in The Meadows. | You earned 3 stars on every level in The Meadows. |
| 11 | On a Roll | Complete the Daily Puzzle 3 days in a row. | You completed the Daily Puzzle 3 days in a row. |
| 12 | Dedicated | Complete the Daily Puzzle 7 days in a row. | You completed the Daily Puzzle 7 days in a row. |
| 13 | Weekly Champion | Complete a Weekly Challenge. | You completed a Weekly Challenge. |
| 14 | Quest Finisher | Complete all 3 Daily Quests in one day. | You completed all 3 Daily Quests in one day. |
| 15 | Coin Collector | Accumulate 200 coins. | You accumulated 200 coins. |

## Russian localization

| # | Отображаемое название | Описание до получения | Описание после получения |
|---:|---|---|---|
| 1 | Первые шаги | Пройдите первый уровень. | Первый уровень пройден. |
| 2 | Странник лугов | Пройдите все уровни «Лугов». | Все уровни «Лугов» пройдены. |
| 3 | Исследователь леса | Пройдите все уровни «Леса». | Все уровни «Леса» пройдены. |
| 4 | Покоритель вершин | Пройдите все уровни «Гор». | Все уровни «Гор» пройдены. |
| 5 | Следопыт | Пройдите все 240 уровней. | Все 240 уровней пройдены. |
| 6 | Перфекционист | Получите 3 звезды на любом уровне. | На уровне получены 3 звезды. |
| 7 | Пурист | Пройдите уровень без подсказок. | Уровень пройден без подсказок. |
| 8 | Скороход | Пройдите уровень менее чем за 60 секунд. | Уровень пройден менее чем за 60 секунд. |
| 9 | Мастер комбо | Сделайте комбо 5× за один уровень. | За один уровень сделано комбо 5×. |
| 10 | Безупречные луга | Получите 3 звезды на всех уровнях «Лугов». | На всех уровнях «Лугов» получены 3 звезды. |
| 11 | На волне | Пройдите ежедневный пазл 3 дня подряд. | Ежедневный пазл пройден 3 дня подряд. |
| 12 | Преданный | Пройдите ежедневный пазл 7 дней подряд. | Ежедневный пазл пройден 7 дней подряд. |
| 13 | Чемпион недели | Пройдите еженедельный вызов. | Еженедельный вызов пройден. |
| 14 | Завершитель заданий | Выполните все 3 задания за один день. | Все 3 задания выполнены за один день. |
| 15 | Коллекционер монет | Накопите 200 монет. | Накоплено 200 монет. |

The images, localizations, and Game Center-enabled build are ready. Add the
achievements to the review submission together with the release build when the
rest of the App Store version metadata is ready.
