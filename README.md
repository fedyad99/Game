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
