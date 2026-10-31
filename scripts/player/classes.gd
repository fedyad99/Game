extends RefCounted
## Классы героя: модель, базовые характеристики, тип атаки и навык с легендарной карточки.
## Оружие в руках берётся из экипировки (или DEFAULT_LOOK в items.gd), поэтому встроенное в модель скрыто.

const A := "res://assets/kaykit/adventurers/"

const CLASSES := {
	"warrior": {
		"name": "Воин", "desc": "Крепкий боец ближнего боя.\nБьёт мечом ближайшего врага.",
		"model": A + "Knight.glb",
		"hide": ["1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Spike_Shield", "2H_Sword", "1H_Sword", "Round_Shield"],
		"stats": {"max_hp": 110.0, "damage": 30.0, "move_speed": 6.0, "attack_range": 2.8, "attack_cd": 0.5},
		"ranged": false, "attack_anim": "1H_Melee_Attack_Chop",
		"skill": "whirlwind",
	},
	"archer": {
		"name": "Лучник", "desc": "Быстрый стрелок.\nСтреляет из арбалета издалека.",
		"model": A + "Rogue.glb",
		"hide": ["Knife_Offhand", "1H_Crossbow", "Knife", "Throwable", "2H_Crossbow"],
		"stats": {"max_hp": 85.0, "damage": 20.0, "move_speed": 6.6, "attack_range": 12.0, "attack_cd": 0.55},
		"ranged": true, "attack_anim": "2H_Ranged_Shoot", "projectile": "arrow",
		"skill": "volley",
	},
	"mage": {
		"name": "Маг", "desc": "Хрупкий, но сильный.\nКидает огненные шары.",
		"model": A + "Mage.glb",
		"hide": ["Spellbook", "Spellbook_open", "1H_Wand", "2H_Staff"],
		"stats": {"max_hp": 75.0, "damage": 34.0, "move_speed": 5.8, "attack_range": 11.0, "attack_cd": 0.8},
		"ranged": true, "attack_anim": "Spellcast_Shoot", "projectile": "fireball",
		"skill": "meteor",
	},
}

## Навыки: перезарядка и название (для HUD).
const SKILLS := {
	"whirlwind": {"name": "Вихрь", "cd": 4.0},
	"volley": {"name": "Залп", "cd": 5.0},
	"meteor": {"name": "Метеор", "cd": 6.0},
}
