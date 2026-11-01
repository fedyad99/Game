extends RefCounted
## Каталог всей экипировки игры. Предметы меняют характеристики и внешний вид героя.
## weapon — только для своего класса (cls), armor, amulet и ring — для всех.
## look: weapon/offhand — модели в руках; cape — цвет плаща; aura — цвет свечения амулета; gem — камень кольца (иконка).

const A := "res://assets/kaykit/adventurers/"

const SLOT_NAME := {"weapon": "Оружие", "armor": "Доспех", "amulet": "Амулет", "ring": "Кольцо"}
const SLOTS := ["weapon", "armor", "amulet", "ring"]
const RARITY_NAME := {"common": "Обычный", "rare": "Редкий", "epic": "Эпический", "legendary": "Легендарный"}
const RARITY_COLOR := {
	"common": Color(0.85, 0.85, 0.85), "rare": Color(0.25, 0.55, 1.0),
	"epic": Color(0.7, 0.3, 1.0), "legendary": Color(1.0, 0.6, 0.1),
}
const STAT_TEXT := {
	"damage": "+%d к урону", "max_hp": "+%d к здоровью", "attack_range": "+%s к дальности",
	"crit_chance": "+%d%% шанс крита", "lifesteal": "+%d%% вампиризм", "attack_speed_mult": "+%d%% к скорости атаки",
	"move_speed_mult": "+%d%% к скорости бега", "damage_mult": "+%d%% к урону", "damage_taken_mult": "%d%% получаемого урона",
	"regen": "+%s здоровья в секунду", "xp_mult": "+%d%% опыта", "skill_cd_mult": "%d%% перезарядки навыков",
	"max_hp_pct": "+%d%% к здоровью", "gold_mult": "+%d%% золота",
}

## Что держит в руках герой без экипировки.
const DEFAULT_LOOK := {
	"warrior": {"weapon": A + "sword_1handed.gltf", "offhand": A + "shield_round.gltf"},
	"archer": {"weapon": A + "crossbow_1handed.gltf"},
	"mage": {"weapon": A + "wand.gltf"},
}

const ITEMS := [
	# --- Воин ---
	{"id": "w_knight_sword", "slot": "weapon", "cls": "warrior", "rarity": "common", "name": "Меч рыцаря",
		"stats": {"damage": 3}, "look": {"weapon": A + "sword_1handed.gltf", "offhand": A + "shield_badge.gltf"}},
	{"id": "w_hatchet", "slot": "weapon", "cls": "warrior", "rarity": "common", "name": "Топорик и щит",
		"stats": {"damage": 2, "max_hp": 8}, "look": {"weapon": A + "axe_1handed.gltf", "offhand": A + "shield_round.gltf"}},
	{"id": "w_battle_axe", "slot": "weapon", "cls": "warrior", "rarity": "rare", "name": "Боевой топор",
		"stats": {"damage": 6}, "look": {"weapon": A + "axe_1handed.gltf", "offhand": A + "shield_spikes.gltf"}},
	{"id": "w_guardian", "slot": "weapon", "cls": "warrior", "rarity": "rare", "name": "Меч стража",
		"stats": {"damage": 4, "damage_taken_mult": -0.04}, "look": {"weapon": A + "sword_1handed.gltf", "offhand": A + "shield_spikes.gltf"}},
	{"id": "w_greatsword", "slot": "weapon", "cls": "warrior", "rarity": "epic", "name": "Двуручный меч",
		"stats": {"damage": 10, "crit_chance": 0.03}, "look": {"weapon": A + "sword_2handed.gltf"}},
	{"id": "w_executioner", "slot": "weapon", "cls": "warrior", "rarity": "legendary", "name": "Секира палача",
		"stats": {"damage": 15, "lifesteal": 0.03}, "look": {"weapon": A + "axe_2handed.gltf"}},
	# --- Лучник ---
	{"id": "a_hunter", "slot": "weapon", "cls": "archer", "rarity": "common", "name": "Охотничий арбалет",
		"stats": {"damage": 2}, "look": {"weapon": A + "crossbow_1handed.gltf", "offhand": A + "dagger.gltf"}},
	{"id": "a_scout", "slot": "weapon", "cls": "archer", "rarity": "common", "name": "Арбалет разведчика",
		"stats": {"damage": 1, "move_speed_mult": 0.04}, "look": {"weapon": A + "crossbow_1handed.gltf"}},
	{"id": "a_heavy", "slot": "weapon", "cls": "archer", "rarity": "rare", "name": "Тяжёлый арбалет",
		"stats": {"damage": 4, "attack_range": 1.0}, "look": {"weapon": A + "crossbow_2handed.gltf"}},
	{"id": "a_duelist", "slot": "weapon", "cls": "archer", "rarity": "rare", "name": "Арбалет дуэлянта",
		"stats": {"damage": 3, "crit_chance": 0.04}, "look": {"weapon": A + "crossbow_1handed.gltf", "offhand": A + "dagger.gltf"}},
	{"id": "a_twin", "slot": "weapon", "cls": "archer", "rarity": "epic", "name": "Арбалет и кинжал",
		"stats": {"damage": 6, "attack_speed_mult": 0.06}, "look": {"weapon": A + "crossbow_1handed.gltf", "offhand": A + "dagger.gltf"}},
	{"id": "a_siege", "slot": "weapon", "cls": "archer", "rarity": "legendary", "name": "Осадный арбалет",
		"stats": {"damage": 9, "attack_range": 2.0, "crit_chance": 0.04}, "look": {"weapon": A + "crossbow_2handed.gltf"}},
	# --- Маг ---
	{"id": "m_student", "slot": "weapon", "cls": "mage", "rarity": "common", "name": "Палочка ученика",
		"stats": {"damage": 3}, "look": {"weapon": A + "wand.gltf", "offhand": A + "spellbook_closed.gltf"}},
	{"id": "m_twig", "slot": "weapon", "cls": "mage", "rarity": "common", "name": "Простая палочка",
		"stats": {"damage": 2, "regen": 0.5}, "look": {"weapon": A + "wand.gltf"}},
	{"id": "m_staff", "slot": "weapon", "cls": "mage", "rarity": "rare", "name": "Посох мага",
		"stats": {"damage": 5}, "look": {"weapon": A + "staff.gltf"}},
	{"id": "m_runes", "slot": "weapon", "cls": "mage", "rarity": "rare", "name": "Посох и руны",
		"stats": {"damage": 4, "skill_cd_mult": -0.06}, "look": {"weapon": A + "staff.gltf", "offhand": A + "spellbook_closed.gltf"}},
	{"id": "m_grimoire", "slot": "weapon", "cls": "mage", "rarity": "epic", "name": "Палочка и гримуар",
		"stats": {"damage": 8, "crit_chance": 0.05}, "look": {"weapon": A + "wand.gltf", "offhand": A + "spellbook_open.gltf"}},
	{"id": "m_archmage", "slot": "weapon", "cls": "mage", "rarity": "legendary", "name": "Посох архимага",
		"stats": {"damage": 12, "damage_mult": 0.08}, "look": {"weapon": A + "staff.gltf", "offhand": A + "spellbook_open.gltf"}},
	# --- Доспехи (для всех) ---
	{"id": "ar_leather", "slot": "armor", "rarity": "common", "name": "Кожаная куртка",
		"stats": {"max_hp": 12}, "look": {"cape": Color(0.45, 0.3, 0.18)}},
	{"id": "ar_cloak", "slot": "armor", "rarity": "common", "name": "Плащ путника",
		"stats": {"max_hp": 6, "move_speed_mult": 0.03}, "look": {"cape": Color(0.25, 0.4, 0.25)}},
	{"id": "ar_chain", "slot": "armor", "rarity": "rare", "name": "Кольчуга",
		"stats": {"max_hp": 20, "damage_taken_mult": -0.03}, "look": {"cape": Color(0.3, 0.45, 0.65)}},
	{"id": "ar_shadow", "slot": "armor", "rarity": "rare", "name": "Теневой плащ",
		"stats": {"max_hp": 10, "crit_chance": 0.03}, "look": {"cape": Color(0.15, 0.12, 0.2)}},
	{"id": "ar_guard", "slot": "armor", "rarity": "epic", "name": "Латы стража",
		"stats": {"max_hp": 30, "damage_taken_mult": -0.06}, "look": {"cape": Color(0.6, 0.1, 0.15)}},
	{"id": "ar_frost", "slot": "armor", "rarity": "epic", "name": "Мантия инея",
		"stats": {"max_hp": 18, "skill_cd_mult": -0.08}, "look": {"cape": Color(0.55, 0.85, 1.0)}},
	{"id": "ar_king", "slot": "armor", "rarity": "legendary", "name": "Доспех короля",
		"stats": {"max_hp": 45, "damage_taken_mult": -0.1}, "look": {"cape": Color(0.95, 0.7, 0.15)}},
	# --- Амулеты (для всех) ---
	{"id": "am_fang", "slot": "amulet", "rarity": "common", "name": "Клык волка",
		"stats": {"crit_chance": 0.02}, "look": {"aura": Color(0.9, 0.9, 0.9)}},
	{"id": "am_bone", "slot": "amulet", "rarity": "common", "name": "Костяной оберег",
		"stats": {"regen": 0.6}, "look": {"aura": Color(0.85, 0.8, 0.6)}},
	{"id": "am_feather", "slot": "amulet", "rarity": "rare", "name": "Перо ветра",
		"stats": {"move_speed_mult": 0.06}, "look": {"aura": Color(0.4, 1.0, 0.6)}},
	{"id": "am_moon", "slot": "amulet", "rarity": "rare", "name": "Лунный камень",
		"stats": {"xp_mult": 0.1}, "look": {"aura": Color(0.6, 0.7, 1.0)}},
	{"id": "am_bloodstone", "slot": "amulet", "rarity": "epic", "name": "Кровавый камень",
		"stats": {"lifesteal": 0.03, "crit_chance": 0.03}, "look": {"aura": Color(1.0, 0.2, 0.25)}},
	{"id": "am_void", "slot": "amulet", "rarity": "epic", "name": "Око бездны",
		"stats": {"damage_mult": 0.08}, "look": {"aura": Color(0.6, 0.2, 1.0)}},
	{"id": "am_dragon", "slot": "amulet", "rarity": "legendary", "name": "Сердце дракона",
		"stats": {"attack_speed_mult": 0.08, "damage_mult": 0.05}, "look": {"aura": Color(1.0, 0.55, 0.1)}},
	# --- Кольца (для всех) ---
	{"id": "rg_copper", "slot": "ring", "rarity": "common", "name": "Медное кольцо",
		"stats": {"damage": 2}, "look": {"gem": Color(0.85, 0.5, 0.25)}},
	{"id": "rg_life", "slot": "ring", "rarity": "common", "name": "Кольцо жизни",
		"stats": {"max_hp": 8}, "look": {"gem": Color(0.4, 0.9, 0.4)}},
	{"id": "rg_swift", "slot": "ring", "rarity": "rare", "name": "Кольцо ловкости",
		"stats": {"attack_speed_mult": 0.05}, "look": {"gem": Color(0.3, 0.8, 1.0)}},
	{"id": "rg_sage", "slot": "ring", "rarity": "rare", "name": "Кольцо мудреца",
		"stats": {"skill_cd_mult": -0.07}, "look": {"gem": Color(0.5, 0.5, 1.0)}},
	{"id": "rg_vampire", "slot": "ring", "rarity": "epic", "name": "Кольцо вампира",
		"stats": {"lifesteal": 0.04}, "look": {"gem": Color(0.8, 0.05, 0.15)}},
	{"id": "rg_fury", "slot": "ring", "rarity": "epic", "name": "Кольцо ярости",
		"stats": {"crit_chance": 0.05, "damage": 3}, "look": {"gem": Color(1.0, 0.4, 0.1)}},
	{"id": "rg_crown", "slot": "ring", "rarity": "legendary", "name": "Печать короля",
		"stats": {"damage_mult": 0.06, "max_hp_pct": 0.06, "crit_chance": 0.03}, "look": {"gem": Color(1.0, 0.85, 0.3)}},
]


static func by_id(id: String) -> Dictionary:
	for it in ITEMS:
		if it.id == id:
			return it
	return {}


static func describe(it: Dictionary) -> String:
	var lines := []
	for k in it.stats:
		var v: float = it.stats[k]
		var shown = v if k in ["damage", "max_hp"] else (str(v) if k in ["attack_range", "regen"] else round(v * 100))
		lines.append(STAT_TEXT[k] % shown)
	return "\n".join(lines)


## Слот экипировки в профиле: оружие у каждого класса своё.
static func equip_key(it: Dictionary) -> String:
	return "weapon_" + it.cls if it.slot == "weapon" else it.slot
