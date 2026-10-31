extends Node
## База карточек повышения уровня. class == "" значит общая карточка.
## once == true: карточку можно взять только один раз (навыки).

const CARDS := [
	{"id": "hp_up", "class": "", "title": "Крепкое тело", "desc": "+25 к макс. здоровью", "stat": "max_hp", "value": 25.0},
	{"id": "dmg_up", "class": "", "title": "Сила", "desc": "+12% к урону", "stat": "damage_mult", "value": 0.12},
	{"id": "speed_up", "class": "", "title": "Лёгкий шаг", "desc": "+8% к скорости бега", "stat": "move_speed_mult", "value": 0.08},
	{"id": "atk_speed", "class": "", "title": "Ярость", "desc": "+12% к скорости атаки", "stat": "attack_speed_mult", "value": 0.12},
	{"id": "regen", "class": "", "title": "Регенерация", "desc": "+1.5 HP в секунду", "stat": "regen", "value": 1.5},
	{"id": "crit", "class": "", "title": "Меткость", "desc": "+8% шанс крита (x2 урон)", "stat": "crit_chance", "value": 0.08},
	{"id": "lifesteal", "class": "", "title": "Вампиризм", "desc": "4% урона лечит тебя", "stat": "lifesteal", "value": 0.04},
	{"id": "whirlwind", "class": "warrior", "title": "Вихрь", "desc": "Навык: каждые 4 с удар по всем врагам вокруг", "skill": "whirlwind", "once": true},
	{"id": "armor", "class": "warrior", "title": "Латы", "desc": "-10% получаемого урона", "stat": "damage_taken_mult", "value": -0.10},
	{"id": "reach", "class": "warrior", "title": "Длинный клинок", "desc": "+0.5 к дальности удара", "stat": "attack_range", "value": 0.5},
]


## Три случайные карточки: общие + карточки класса игрока. Уже взятые навыки не выпадают.
func roll(player_class: String, taken_skills: Array = [], count: int = 3) -> Array:
	var pool := CARDS.filter(func(c):
		return (c["class"] == "" or c["class"] == player_class) \
			and not (c.get("once", false) and c.get("skill", "") in taken_skills))
	pool.shuffle()
	return pool.slice(0, count)
