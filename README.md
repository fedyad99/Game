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
- `scenes/menu.tscn` — лагерь: вкладки Герой, Таланты, Сундуки, Библиотека. При первом запуске — выбор класса; дальше смена класса стоит 150 золота.
- `scripts/meta/profile.gd` (автозагрузка `Profile`) — золото, сундуки, дерево талантов по классам, экипировка; сохранение в `user://profile.json`.
- `scripts/meta/items.gd` — каталог экипировки (39 предметов, слоты: оружие, доспех, амулет, кольцо).
- `scripts/meta/talent_tree.gd` — дерево талантов в духе Path of Exile: у каждого класса свой старт и два уникальных навыка.
- Сундуки: 70% новый предмет (без повторов), 30% очки талантов; золота в сундуках нет.
- Иконки оружия: `tests/render_icons.gd` рисует их из 3D-моделей в `assets/icons/items/`.

## Звук
- Все звуки и музыка синтезированы скриптом `tools/make_sounds.py` (numpy, scipy, ffmpeg) в `assets/audio/`.
- Автозагрузка `Sfx` (`scripts/audio/sfx.gd`): `Sfx.play("hit")`, `Sfx.music("battle")`.
