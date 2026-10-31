extends Node
## База карточек повышения уровня. class == "" значит общая карточка.

const CARDS := [
	{"id": "hp_up", "class": "", "title": "Крепкое тело", "desc": "+20 к макс. здоровью", "stat": "max_hp", "value": 20},
	{"id": "dmg_up", "class": "", "title": "Сила", "desc": "+10% к урону", "stat": "damage_mult", "value": 0.10},
	{"id": "speed_up", "class": "", "title": "Лёгкий шаг", "desc": "+8% к скорости", "stat": "move_speed_mult", "value": 0.08},
	{"id": "atk_speed", "class": "", "title": "Ярость", "desc": "+12% к скорости атаки", "stat": "attack_speed_mult", "value": 0.12},
	{"id": "regen", "class": "", "title": "Регенерация", "desc": "+1 HP в секунду", "stat": "regen", "value": 1.0},
	{"id": "whirlwind", "class": "warrior", "title": "Вихрь", "desc": "Навык: удар по всем врагам вокруг", "skill": "whirlwind"},
	{"id": "armor", "class": "warrior", "title": "Латы", "desc": "-10% получаемого урона", "stat": "damage_taken_mult", "value": -0.10},
]

## Три случайные карточки: общие + карточки класса игрока.
func roll(player_class: String, count: int = 3) -> Array:
	var pool := CARDS.filter(func(c): return c["class"] == "" or c["class"] == player_class)
	pool.shuffle()
	return pool.slice(0, count)
