extends RefCounted
## Дерево талантов в духе Path of Exile. Общее поле узлов; у каждого класса своя стартовая точка,
## свои ветки и два уникальных навыка в конце веток. Узел можно взять, только если он соединён
## с уже взятым. Чужой старт закрыт, поэтому навыки других классов недоступны.
##
## Узел: {id, kind: start/small/notable/keystone/skill, cls, name, stats, skill, pos}

const CLASS_ANGLE := {"warrior": -150.0, "archer": -30.0, "mage": 90.0}
const CLASS_COLOR := {"warrior": Color(0.95, 0.45, 0.3), "archer": Color(0.45, 0.9, 0.45), "mage": Color(0.6, 0.55, 1.0)}

## Уникальные навыки классов (берутся в дереве). Описание показывается в подсказке.
const SKILLS := {
	"charge": {"cls": "warrior", "name": "Рывок", "desc": "Каждые 6 с бросается к дальнему врагу\nи бьёт всех рядом (x1.5 урона)"},
	"warcry": {"cls": "warrior", "name": "Боевой клич", "desc": "Каждые 12 с: +35% урона на 5 с\nи лечит 12% здоровья"},
	"trap": {"cls": "archer", "name": "Капкан", "desc": "Каждые 7 с ставит капкан под врага:\nвзрыв по области (x2 урона)"},
	"pierce": {"cls": "archer", "name": "Пронзающий выстрел", "desc": "Каждые 3 с стрела пробивает\nвсех врагов на пути (x1.6 урона)"},
	"frost_nova": {"cls": "mage", "name": "Ледяная нова", "desc": "Каждые 7 с волна холода вокруг:\nурон и замедление врагов на 3 с"},
	"chain_lightning": {"cls": "mage", "name": "Цепная молния", "desc": "Каждые 4 с молния бьёт врага\nи перескакивает ещё на 4 цели"},
}

const CLASS_FLAVOR := {
	"warrior": {
		"small": [{"max_hp": 10.0}, {"damage_taken_mult": -0.03}, {"damage": 2.0}, {"max_hp_pct": 0.04}],
		"a": ["Мясник", {"damage_mult": 0.1, "lifesteal": 0.02}],
		"b": ["Несокрушимость", {"max_hp_pct": 0.1, "damage_taken_mult": -0.05}],
		"skills": ["charge", "warcry"],
	},
	"archer": {
		"small": [{"attack_speed_mult": 0.04}, {"crit_chance": 0.02}, {"move_speed_mult": 0.03}, {"attack_range": 0.5}],
		"a": ["Охотник", {"crit_chance": 0.05, "attack_speed_mult": 0.06}],
		"b": ["Попутный ветер", {"move_speed_mult": 0.06, "attack_range": 1.0}],
		"skills": ["trap", "pierce"],
	},
	"mage": {
		"small": [{"damage_mult": 0.04}, {"skill_cd_mult": -0.04}, {"regen": 0.4}, {"max_hp": 6.0}],
		"a": ["Архимаг", {"damage_mult": 0.1, "crit_chance": 0.03}],
		"b": ["Поток маны", {"skill_cd_mult": -0.1, "regen": 0.6}],
		"skills": ["frost_nova", "chain_lightning"],
	},
}

const RING_NOTABLES := [
	["Ярость боя", {"attack_speed_mult": 0.06, "damage_mult": 0.05}],
	["Стойкость", {"regen": 1.0, "max_hp_pct": 0.05}],
	["Удача", {"gold_mult": 0.2, "xp_mult": 0.1}],
]
const RING_SMALL := [{"crit_chance": 0.02}, {"max_hp": 8.0}, {"damage_mult": 0.03}, {"move_speed_mult": 0.03},
	{"regen": 0.4}, {"attack_speed_mult": 0.03}]

const STAT_TEXT := {
	"damage": "+%s к урону", "max_hp": "+%s к здоровью", "attack_range": "+%s к дальности",
	"crit_chance": "+%s%% шанс крита", "lifesteal": "+%s%% вампиризм", "attack_speed_mult": "+%s%% к скорости атаки",
	"move_speed_mult": "+%s%% к скорости бега", "damage_mult": "+%s%% к урону", "damage_taken_mult": "%s%% получаемого урона",
	"regen": "+%s здоровья в секунду", "xp_mult": "+%s%% опыта", "skill_cd_mult": "%s%% перезарядки навыков",
	"max_hp_pct": "+%s%% к здоровью", "gold_mult": "+%s%% золота", "second_wind": "Раз за забег: вместо смерти\nвстаёшь с 40% здоровья",
}
const PCT := ["crit_chance", "lifesteal", "attack_speed_mult", "move_speed_mult", "damage_mult", "damage_taken_mult",
	"xp_mult", "skill_cd_mult", "max_hp_pct", "gold_mult"]

static var _nodes := {}
static var _edges: Array = []


static func nodes() -> Dictionary:
	if _nodes.is_empty():
		_build()
	return _nodes


static func edges() -> Array:
	if _nodes.is_empty():
		_build()
	return _edges


static func node(id: String) -> Dictionary:
	return nodes().get(id, {})


static func neighbors(id: String) -> Array:
	var res := []
	for e in edges():
		if e[0] == id:
			res.append(e[1])
		elif e[1] == id:
			res.append(e[0])
	return res


static func start_of(cls: String) -> String:
	return cls + "_start"


static func describe(n: Dictionary) -> String:
	if n.kind == "skill":
		return "Уникальный навык класса\n" + SKILLS[n.skill].desc
	var lines := []
	for k in n.stats:
		var v: float = n.stats[k]
		if k == "second_wind":
			lines.append(STAT_TEXT[k])
		elif k in PCT:
			lines.append(STAT_TEXT[k] % str(int(round(v * 100))))
		else:
			lines.append(STAT_TEXT[k] % str(v))
	if n.kind == "start":
		return "Начало пути класса"
	return "\n".join(lines)


static func _polar(r: float, deg: float) -> Vector2:
	return Vector2(cos(deg_to_rad(deg)), sin(deg_to_rad(deg))) * r


static func _add(id: String, kind: String, pos: Vector2, name_: String, stats: Dictionary, cls := "", skill := "") -> void:
	_nodes[id] = {"id": id, "kind": kind, "cls": cls, "name": name_, "stats": stats, "skill": skill, "pos": pos}


static func _link(a: String, b: String) -> void:
	_edges.append([a, b])


static func _small_name(st: Dictionary) -> String:
	var k: String = st.keys()[0]
	return {"max_hp": "Здоровье", "damage_taken_mult": "Броня", "damage": "Сила", "max_hp_pct": "Крепость",
		"attack_speed_mult": "Скорость атаки", "crit_chance": "Меткость", "move_speed_mult": "Ловкость",
		"attack_range": "Дальность", "damage_mult": "Мощь", "skill_cd_mult": "Сосредоточенность", "regen": "Восстановление",
		"lifesteal": "Вампиризм", "xp_mult": "Мудрость", "gold_mult": "Жадность"}.get(k, "Талант")


static func _build() -> void:
	_nodes = {}
	_edges = []
	_add("hub", "keystone", Vector2.ZERO, "Второе дыхание", {"second_wind": 1.0})
	var classes := ["warrior", "archer", "mage"]
	for ci in classes.size():
		var cls: String = classes[ci]
		var a: float = CLASS_ANGLE[cls]
		var fl: Dictionary = CLASS_FLAVOR[cls]
		var sm: Array = fl.small
		var p := cls + "_"
		_add(p + "start", "start", _polar(300, a), {"warrior": "Воин", "archer": "Лучник", "mage": "Маг"}[cls], {}, cls)
		# Две ветки наружу: малые узлы -> значимый -> уникальный навык
		for side in [-1, 1]:
			var b := "a" if side < 0 else "b"
			var notable: Array = fl[b]
			var s1: Dictionary = sm[0 if side < 0 else 1]
			var s2: Dictionary = sm[2 if side < 0 else 3]
			_add(p + b + "1", "small", _polar(370, a + side * 13), _small_name(s1), s1, cls)
			_add(p + b + "2", "small", _polar(440, a + side * 19), _small_name(s2), s2, cls)
			_add(p + b + "3", "notable", _polar(515, a + side * 21), notable[0], notable[1], cls)
			var sk: String = fl.skills[0 if side < 0 else 1]
			_add(p + b + "4", "skill", _polar(600, a + side * 13), SKILLS[sk].name, {}, cls, sk)
			_link(p + "start", p + b + "1")
			_link(p + b + "1", p + b + "2")
			_link(p + b + "2", p + b + "3")
			_link(p + b + "3", p + b + "4")
		# Мостик между ветками (короткий путь к обоим навыкам)
		_add(p + "mid", "small", _polar(450, a), _small_name(sm[0]), sm[0], cls)
		_link(p + "a2", p + "mid")
		_link(p + "mid", p + "b2")
		# Путь к центру
		_add(p + "i1", "small", _polar(230, a), _small_name(sm[1]), sm[1], cls)
		_add(p + "i2", "small", _polar(160, a), "Мощь", {"damage_mult": 0.03})
		_add(p + "c", "small", _polar(80, a), "Здоровье", {"max_hp": 8.0})
		_link(p + "start", p + "i1")
		_link(p + "i1", p + "i2")
		_link(p + "i2", p + "c")
		_link(p + "c", "hub")
	# Кольцо между классами
	for ci in classes.size():
		var c1: String = classes[ci]
		var c2: String = classes[(ci + 1) % classes.size()]
		var a1: float = CLASS_ANGLE[c1]
		var a2: float = CLASS_ANGLE[c2]
		if a2 < a1:
			a2 += 360.0
		var r := "ring%d_" % ci
		var s_a: Dictionary = RING_SMALL[ci * 2]
		var s_b: Dictionary = RING_SMALL[ci * 2 + 1]
		_add(r + "1", "small", _polar(185, lerp(a1, a2, 0.25)), _small_name(s_a), s_a)
		_add(r + "2", "notable", _polar(215, lerp(a1, a2, 0.5)), RING_NOTABLES[ci][0], RING_NOTABLES[ci][1])
		_add(r + "3", "small", _polar(185, lerp(a1, a2, 0.75)), _small_name(s_b), s_b)
		_link(c1 + "_i2", r + "1")
		_link(r + "1", r + "2")
		_link(r + "2", r + "3")
		_link(r + "3", c2 + "_i2")
