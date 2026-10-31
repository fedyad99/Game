extends RefCounted
## Таланты: пассивные навыки, которые качаются между забегами за очки талантов.
## per_rank — прибавка за каждый уровень таланта, max — сколько уровней, cost — очков за уровень.

const TALENTS := [
	{"id": "vitality", "name": "Живучесть", "desc": "+6% к здоровью за уровень", "stat": "max_hp_pct", "per_rank": 0.06, "max": 5, "cost": 1, "icon": "heart"},
	{"id": "might", "name": "Сила", "desc": "+5% к урону за уровень", "stat": "damage_mult", "per_rank": 0.05, "max": 5, "cost": 1, "icon": "sword"},
	{"id": "haste", "name": "Проворство", "desc": "+4% к скорости атаки за уровень", "stat": "attack_speed_mult", "per_rank": 0.04, "max": 5, "cost": 1, "icon": "bolt"},
	{"id": "precision", "name": "Точность", "desc": "+2% шанс крита за уровень", "stat": "crit_chance", "per_rank": 0.02, "max": 5, "cost": 1, "icon": "target"},
	{"id": "swift", "name": "Быстрые ноги", "desc": "+3% к скорости бега за уровень", "stat": "move_speed_mult", "per_rank": 0.03, "max": 3, "cost": 1, "icon": "boot"},
	{"id": "recovery", "name": "Восстановление", "desc": "+0.5 здоровья в секунду за уровень", "stat": "regen", "per_rank": 0.5, "max": 3, "cost": 1, "icon": "cross"},
	{"id": "greed", "name": "Жадность", "desc": "+15% золота за забег за уровень", "stat": "gold_mult", "per_rank": 0.15, "max": 3, "cost": 1, "icon": "coin"},
	{"id": "wisdom", "name": "Мудрость", "desc": "+10% опыта за уровень", "stat": "xp_mult", "per_rank": 0.1, "max": 3, "cost": 1, "icon": "eye"},
	{"id": "second_wind", "name": "Второе дыхание", "desc": "Раз за забег: вместо смерти встаёшь с 40% здоровья", "stat": "second_wind", "per_rank": 1.0, "max": 1, "cost": 3, "icon": "spiral"},
]


static func by_id(id: String) -> Dictionary:
	for t in TALENTS:
		if t.id == id:
			return t
	return {}
