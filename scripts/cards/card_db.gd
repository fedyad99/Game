extends Node
## База карточек повышения уровня. class == "" значит общая карточка.
## once == true: карточку можно взять только один раз (навыки).
## rarity: common / rare / epic / legendary — цвет камня и рамки, а также шанс выпадения.
## icon: какая картинка рисуется в овале карточки (см. card_view.gd).

const RARITY_WEIGHT := {"common": 10.0, "rare": 5.0, "epic": 2.5, "legendary": 1.0}

const CARDS := [
	{"id": "hp_up", "class": "", "title": "Крепкое тело", "desc": "+25 к макс. здоровью", "stat": "max_hp", "value": 25.0,
		"rarity": "common", "icon": "heart"},
	{"id": "dmg_up", "class": "", "title": "Сила", "desc": "+12% к урону", "stat": "damage_mult", "value": 0.12,
		"rarity": "common", "icon": "sword"},
	{"id": "speed_up", "class": "", "title": "Лёгкий шаг", "desc": "+8% к скорости бега", "stat": "move_speed_mult", "value": 0.08,
		"rarity": "common", "icon": "boot"},
	{"id": "atk_speed", "class": "", "title": "Ярость", "desc": "+12% к скорости атаки", "stat": "attack_speed_mult", "value": 0.12,
		"rarity": "rare", "icon": "bolt"},
	{"id": "regen", "class": "", "title": "Регенерация", "desc": "+1.5 здоровья в секунду", "stat": "regen", "value": 1.5,
		"rarity": "rare", "icon": "cross"},
	{"id": "crit", "class": "", "title": "Меткость", "desc": "+8% шанс крита\n(двойной урон)", "stat": "crit_chance", "value": 0.08,
		"rarity": "rare", "icon": "target"},
	{"id": "lifesteal", "class": "", "title": "Вампиризм", "desc": "4% нанесённого урона лечит тебя", "stat": "lifesteal", "value": 0.04,
		"rarity": "epic", "icon": "drop"},
	{"id": "whirlwind", "class": "warrior", "title": "Вихрь", "desc": "Навык: каждые 4 с бьёт всех вокруг", "skill": "whirlwind",
		"once": true, "rarity": "legendary", "icon": "spiral"},
	{"id": "armor", "class": "warrior", "title": "Латы", "desc": "-10% получаемого урона", "stat": "damage_taken_mult", "value": -0.10,
		"rarity": "rare", "icon": "shield"},
	{"id": "reach", "class": "warrior", "title": "Длинный клинок", "desc": "+0.5 к дальности удара", "stat": "attack_range", "value": 0.5,
		"rarity": "epic", "icon": "blade"},
	# Лучник
	{"id": "volley", "class": "archer", "title": "Залп", "desc": "Навык: каждые 5 с 10 стрел во все стороны", "skill": "volley",
		"once": true, "rarity": "legendary", "icon": "arrows"},
	{"id": "eagle_eye", "class": "archer", "title": "Орлиный глаз", "desc": "+2 к дальности выстрела", "stat": "attack_range", "value": 2.0,
		"rarity": "rare", "icon": "eye"},
	{"id": "quick_hands", "class": "archer", "title": "Быстрые руки", "desc": "+18% к скорости стрельбы", "stat": "attack_speed_mult", "value": 0.18,
		"rarity": "epic", "icon": "bolt"},
	# Маг
	{"id": "meteor", "class": "mage", "title": "Метеор", "desc": "Навык: каждые 6 с метеор по ближайшему врагу", "skill": "meteor",
		"once": true, "rarity": "legendary", "icon": "meteor"},
	{"id": "inferno", "class": "mage", "title": "Пламя", "desc": "+18% к урону заклинаний", "stat": "damage_mult", "value": 0.18,
		"rarity": "epic", "icon": "flame"},
	{"id": "ice_armor", "class": "mage", "title": "Ледяная броня", "desc": "-12% получаемого урона", "stat": "damage_taken_mult", "value": -0.12,
		"rarity": "rare", "icon": "shield"},
]


func by_id(id: String) -> Dictionary:
	for c in CARDS:
		if c.id == id:
			return c
	return {}


## Три разные случайные карточки: общие + карточки класса игрока, с учётом редкости.
## Уже взятые навыки не выпадают.
func roll(player_class: String, taken_skills: Array = [], count: int = 3) -> Array:
	var pool := CARDS.filter(func(c):
		return (c["class"] == "" or c["class"] == player_class) \
			and not (c.get("once", false) and c.get("skill", "") in taken_skills))
	var result := []
	while result.size() < count and not pool.is_empty():
		var total := 0.0
		for c in pool:
			total += RARITY_WEIGHT[c.rarity]
		var r := randf() * total
		for c in pool:
			r -= RARITY_WEIGHT[c.rarity]
			if r <= 0.0:
				result.append(c)
				pool.erase(c)
				break
	return result
