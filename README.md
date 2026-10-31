# Coop Roguelite

3D кооп roguelite RPG на Godot 4 (Android + ПК, кроссплей, до 3 игроков).

## Этапы
1. Соло: воин, одна карта, монстры, мини-босс, босс, карточки при повышении уровня.
2. Кооп 2–3 игрока через выделенный headless-сервер.
3. Награды после забега, лучник и маг, классовые карточки.

## Структура
- `scenes/` — сцены
- `scripts/player`, `scripts/enemies`, `scripts/cards`, `scripts/net` — код
- `assets/` — графика (CC0: Kenney, Quaternius)

## Тесты
- `godot --headless --fixed-fps 60 --path . -s tests/smoke_test.gd` — бот проходит забег по карте.
- `godot --headless --fixed-fps 60 --path . -s tests/boss_test.gd` — бой героя 12 уровня с боссом.

## Карта
Карта «Лес» задаётся данными в `scripts/maps/forest_map.gd`: стены, камни, лагеря монстров, боссы.

## Графика
3D-модели — бесплатные паки KayKit от Kay Lousberg (CC0, www.kaylousberg.com):
Adventurers (герой), Skeletons (враги), Halloween Bits (окружение). Лицензии лежат рядом с моделями в `assets/kaykit/`.

Скриншоты для проверки картинки: `xvfb-run godot --rendering-method gl_compatibility --path . -s tests/screenshot.gd -- <папка>`.

## Меню и прогресс
- `scenes/menu.tscn` — лагерь: вкладки Герой, Таланты, Сундуки, Библиотека.
- `scripts/meta/profile.gd` (автозагрузка `Profile`) — золото, сундуки, таланты, экипировка; сохранение в `user://profile.json`.
- `scripts/meta/items.gd` — каталог экипировки (20 предметов), `scripts/meta/talents.gd` — таланты.
- Классы: `scripts/player/classes.gd` (воин, лучник, маг).
- Тесты принимают класс: `... -s tests/smoke_test.gd -- archer`. Скриншоты меню: `tests/menu_shots.gd`.
