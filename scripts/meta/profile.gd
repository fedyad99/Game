extends Node
## Профиль игрока между забегами: золото, сундуки, экипировка, таланты, выбранный класс.
## Сохраняется в user://profile.json (на Windows: %APPDATA%/Godot/app_userdata/Coop Roguelite).

const Items := preload("res://scripts/meta/items.gd")
const Talents := preload("res://scripts/meta/talents.gd")

const SAVE_PATH := "user://profile.json"
const SAVE_VERSION := 2
const CHEST_PRICE := 60
const DUPLICATE_GOLD := {"common": 15, "rare": 30, "epic": 60, "legendary": 120}

var gold := 0
var chests := 0
var talent_points := 0
var talents := {}            # id таланта -> уровень
var selected_class := "warrior"
var owned: Array = []        # id предметов из каталога
var equipped := {}           # "weapon_warrior" / "armor" / "amulet" -> id предмета
var runs := 0
var wins := 0
var best_time := 0.0
var last_run := {}           # итоги последнего забега
var autosave := true         # тесты выключают запись на диск


func _ready() -> void:
	load_profile()


func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 1)) != SAVE_VERSION:
		return   # старый формат сохранения — начинаем заново
	gold = int(data.get("gold", 0))
	chests = int(data.get("chests", 0))
	talent_points = int(data.get("talent_points", 0))
	talents = data.get("talents", {})
	selected_class = data.get("selected_class", "warrior")
	owned = data.get("owned", [])
	equipped = data.get("equipped", {})
	runs = int(data.get("runs", 0))
	wins = int(data.get("wins", 0))
	best_time = float(data.get("best_time", 0.0))


func save_profile() -> void:
	if not autosave:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"version": SAVE_VERSION, "gold": gold, "chests": chests, "talent_points": talent_points,
		"talents": talents, "selected_class": selected_class, "owned": owned, "equipped": equipped,
		"runs": runs, "wins": wins, "best_time": best_time,
	}, "\t"))


# ---------- Экипировка ----------

func equip(item_id: String) -> void:
	var it := Items.by_id(item_id)
	if it.is_empty() or not item_id in owned:
		return
	equipped[Items.equip_key(it)] = item_id
	save_profile()


func unequip(key: String) -> void:
	equipped.erase(key)
	save_profile()


func is_equipped(item_id: String) -> bool:
	return item_id in equipped.values()


## Надетые на класс предметы (оружие этого класса + доспех + амулет).
func worn_items(cls: String) -> Array:
	var res := []
	for key in ["weapon_" + cls, "armor", "amulet"]:
		if equipped.has(key):
			res.append(Items.by_id(equipped[key]))
	return res


## Внешний вид героя класса: оружие, вещь во второй руке, цвет плаща, свечение.
func look(cls: String) -> Dictionary:
	var lk: Dictionary = Items.DEFAULT_LOOK[cls].duplicate()
	for it in worn_items(cls):
		for k in it.look:
			lk[k] = it.look[k]
		if it.slot == "weapon" and not it.look.has("offhand"):
			lk.erase("offhand")
	return lk


# ---------- Таланты ----------

func talent_rank(id: String) -> int:
	return int(talents.get(id, 0))


func can_upgrade(id: String) -> bool:
	var t := Talents.by_id(id)
	return talent_rank(id) < t.max and talent_points >= t.cost


func upgrade_talent(id: String) -> bool:
	if not can_upgrade(id):
		return false
	talent_points -= Talents.by_id(id).cost
	talents[id] = talent_rank(id) + 1
	save_profile()
	return true


## Все прибавки к герою: экипировка класса + таланты. {стат: значение}
func total_bonus(cls: String) -> Dictionary:
	var bonus := {}
	for it in worn_items(cls):
		for k in it.stats:
			bonus[k] = bonus.get(k, 0.0) + float(it.stats[k])
	for t in Talents.TALENTS:
		var r := talent_rank(t.id)
		if r > 0:
			bonus[t.stat] = bonus.get(t.stat, 0.0) + t.per_rank * r
	return bonus


# ---------- Сундуки ----------

func buy_chest() -> bool:
	if gold < CHEST_PRICE:
		return false
	gold -= CHEST_PRICE
	chests += 1
	save_profile()
	return true


## Открыть сундук. Возвращает что выпало:
## {"type": "item", "item": {...}} / {"type": "duplicate", "item": {...}, "gold": n}
## {"type": "talent", "points": n} / {"type": "gold", "gold": n}
func open_chest() -> Dictionary:
	if chests <= 0:
		return {}
	chests -= 1
	var r := randf()
	var res := {}
	if r < 0.5:
		var it := _roll_item()
		if it.id in owned:
			var g: int = DUPLICATE_GOLD[it.rarity]
			gold += g
			res = {"type": "duplicate", "item": it, "gold": g}
		else:
			owned.append(it.id)
			var key := Items.equip_key(it)
			if not equipped.has(key):
				equipped[key] = it.id   # пустой слот — сразу надеваем
			res = {"type": "item", "item": it}
	elif r < 0.8:
		var p := 1 if randf() < 0.75 else 2
		talent_points += p
		res = {"type": "talent", "points": p}
	else:
		var g := randi_range(30, 80)
		gold += g
		res = {"type": "gold", "gold": g}
	save_profile()
	return res


func _roll_item() -> Dictionary:
	var r := randf()
	var rarity := "common" if r < 0.5 else ("rare" if r < 0.8 else ("epic" if r < 0.95 else "legendary"))
	var pool := Items.ITEMS.filter(func(it): return it.rarity == rarity)
	return pool[randi() % pool.size()]


# ---------- Итоги забега ----------

## Золото из забега (с талантом «Жадность»), сундуки за мини-боссов и победу, очко таланта за победу.
func add_run_rewards(run_gold: int, minibosses: int, victory: bool, time_s: float, level: int, kills: int) -> void:
	runs += 1
	var bonus_gold := int(time_s / 10.0)
	var new_chests := minibosses + (2 if victory else 0)
	var new_points := 1 if victory else 0
	if victory:
		wins += 1
		bonus_gold += 100
	var total := int((run_gold + bonus_gold) * (1.0 + total_bonus(selected_class).get("gold_mult", 0.0)))
	best_time = max(best_time, time_s)
	gold += total
	chests += new_chests
	talent_points += new_points
	last_run = {"victory": victory, "gold": total, "chests": new_chests, "points": new_points,
		"time": time_s, "level": level, "kills": kills}
	save_profile()
