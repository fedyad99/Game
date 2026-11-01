extends Node
## Профиль игрока между забегами: золото, сундуки, экипировка, дерево талантов, класс.
## Сохраняется в user://profile.json (на Windows: %APPDATA%/Godot/app_userdata/Coop Roguelite).

const Items := preload("res://scripts/meta/items.gd")
const TalentTree := preload("res://scripts/meta/talent_tree.gd")

const SAVE_PATH := "user://profile.json"
const SAVE_VERSION := 3
const CHEST_PRICE := 60
const CLASS_CHANGE_PRICE := 150
const TREE_RESET_PRICE := 100
## Шансы редкости предмета из сундука (дорогие — редко).
const RARITY_ODDS := [["common", 0.62], ["rare", 0.27], ["epic", 0.09], ["legendary", 0.02]]
const CLASSES := ["warrior", "archer", "mage"]

var gold := 0
var chests := 1                 # первый сундук в подарок
var selected_class := "warrior"
var class_chosen := false       # при первом запуске игра предлагает выбрать класс
var points := {}                # класс -> свободные очки талантов
var trees := {}                 # класс -> [id взятых узлов дерева]
var owned: Array = []           # id предметов из каталога
var equipped := {}              # "weapon_warrior" / "armor" / "amulet" / "ring" -> id предмета
var runs := 0
var wins := 0
var best_time := 0.0
var last_run := {}              # итоги последнего забега
var sound_on := true
var music_on := true
var autosave := true            # тесты выключают запись на диск


func _ready() -> void:
	load_profile()
	_apply_audio()


func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	var ver := int(data.get("version", 1))
	if ver < 2:
		return
	gold = int(data.get("gold", 0))
	chests = int(data.get("chests", 0))
	selected_class = data.get("selected_class", "warrior")
	owned = data.get("owned", [])
	owned = owned.filter(func(id): return not Items.by_id(id).is_empty())
	equipped = data.get("equipped", {})
	runs = int(data.get("runs", 0))
	wins = int(data.get("wins", 0))
	best_time = float(data.get("best_time", 0.0))
	if ver == 2:
		# Старые таланты превращаются в очки нового дерева для выбранного класса
		var spent := 0
		var old: Dictionary = data.get("talents", {})
		for k in old:
			spent += int(old[k]) * (3 if k == "second_wind" else 1)
		points = {selected_class: int(data.get("talent_points", 0)) + spent}
		class_chosen = true
	else:
		points = data.get("points", {})
		trees = data.get("trees", {})
		class_chosen = bool(data.get("class_chosen", false))
		sound_on = bool(data.get("sound_on", true))
		music_on = bool(data.get("music_on", true))


func save_profile() -> void:
	if not autosave:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"version": SAVE_VERSION, "gold": gold, "chests": chests, "selected_class": selected_class,
		"class_chosen": class_chosen, "points": points, "trees": trees, "owned": owned, "equipped": equipped,
		"runs": runs, "wins": wins, "best_time": best_time, "sound_on": sound_on, "music_on": music_on,
	}, "\t"))


func _apply_audio() -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.sfx_on = sound_on
		sfx.music_on = music_on


func set_sound(v: bool) -> void:
	sound_on = v
	_apply_audio()
	save_profile()


func set_music(v: bool) -> void:
	music_on = v
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.set_music_on(v)
	save_profile()


# ---------- Класс ----------

## Первый выбор бесплатный, дальше смена стоит золота.
func class_change_cost(cls: String) -> int:
	if not class_chosen or cls == selected_class:
		return 0
	return CLASS_CHANGE_PRICE


func change_class(cls: String) -> bool:
	var cost := class_change_cost(cls)
	if gold < cost:
		return false
	gold -= cost
	selected_class = cls
	class_chosen = true
	save_profile()
	return true


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


func slot_keys(cls: String) -> Array:
	return ["weapon_" + cls, "armor", "amulet", "ring"]


## Надетые на класс предметы (оружие этого класса + доспех + амулет + кольцо).
func worn_items(cls: String) -> Array:
	var res := []
	for key in slot_keys(cls):
		if equipped.has(key):
			var it := Items.by_id(equipped[key])
			if not it.is_empty():
				res.append(it)
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


# ---------- Дерево талантов ----------

func free_points(cls: String = "") -> int:
	return int(points.get(cls if cls != "" else selected_class, 0))


func add_points(cls: String, n: int) -> void:
	points[cls] = free_points(cls) + n


func allocated(cls: String) -> Array:
	if not trees.has(cls):
		trees[cls] = [TalentTree.start_of(cls)]
	return trees[cls]


func is_allocated(cls: String, id: String) -> bool:
	return id in allocated(cls)


## Узел можно взять, если он свободен, не чужой старт, соединён со взятым и есть очко.
func can_allocate(cls: String, id: String) -> bool:
	var n := TalentTree.node(id)
	if n.is_empty() or is_allocated(cls, id) or n.kind == "start" or free_points(cls) <= 0:
		return false
	if n.cls != "" and n.cls != cls:
		return false
	return is_reachable(cls, id)


func is_reachable(cls: String, id: String) -> bool:
	for nb in TalentTree.neighbors(id):
		if is_allocated(cls, nb):
			return true
	return false


func allocate(cls: String, id: String) -> bool:
	if not can_allocate(cls, id):
		return false
	allocated(cls).append(id)
	points[cls] = free_points(cls) - 1
	save_profile()
	return true


## Сброс дерева класса за золото: все очки возвращаются.
func reset_tree(cls: String) -> bool:
	var spent := allocated(cls).size() - 1
	if spent <= 0 or gold < TREE_RESET_PRICE:
		return false
	gold -= TREE_RESET_PRICE
	trees[cls] = [TalentTree.start_of(cls)]
	add_points(cls, spent)
	save_profile()
	return true


## Уникальные навыки, взятые в дереве класса.
func tree_skills(cls: String) -> Array:
	var res := []
	for id in allocated(cls):
		var n := TalentTree.node(id)
		if not n.is_empty() and n.kind == "skill":
			res.append(n.skill)
	return res


## Все прибавки к герою: экипировка класса + дерево талантов. {стат: значение}
func total_bonus(cls: String) -> Dictionary:
	var bonus := {}
	for it in worn_items(cls):
		for k in it.stats:
			bonus[k] = bonus.get(k, 0.0) + float(it.stats[k])
	for id in allocated(cls):
		var n := TalentTree.node(id)
		for k in n.get("stats", {}):
			bonus[k] = bonus.get(k, 0.0) + float(n.stats[k])
	return bonus


# ---------- Сундуки ----------

func buy_chest() -> bool:
	if gold < CHEST_PRICE:
		return false
	gold -= CHEST_PRICE
	chests += 1
	save_profile()
	return true


## Открыть сундук. Золота в сундуках нет. Возвращает что выпало:
## {"type": "item", "item": {...}} или {"type": "talent", "points": n}
func open_chest() -> Dictionary:
	if chests <= 0:
		return {}
	chests -= 1
	var res := {}
	var it := _roll_item() if randf() < 0.7 else {}
	if not it.is_empty():
		owned.append(it.id)
		var key := Items.equip_key(it)
		if not equipped.has(key):
			equipped[key] = it.id   # пустой слот — сразу надеваем
		res = {"type": "item", "item": it}
	else:
		var p := 1 if randf() < 0.7 else 2
		add_points(selected_class, p)
		res = {"type": "talent", "points": p}
	save_profile()
	return res


## Предмет, которого ещё нет. Редкость по RARITY_ODDS; если этой редкости всё собрано — берём другую.
func _roll_item() -> Dictionary:
	var r := randf()
	var acc := 0.0
	var rarity := "common"
	for o in RARITY_ODDS:
		acc += o[1]
		if r < acc:
			rarity = o[0]
			break
	var missing := Items.ITEMS.filter(func(x): return not x.id in owned)
	if missing.is_empty():
		return {}
	var pool := missing.filter(func(x): return x.rarity == rarity)
	if pool.is_empty():
		# ближайшая более дешёвая редкость, иначе любая
		for o in RARITY_ODDS:
			pool = missing.filter(func(x): return x.rarity == o[0])
			if not pool.is_empty():
				break
	return pool[randi() % pool.size()]


# ---------- Итоги забега ----------

## Золото из забега (+ бонус «Удача»), сундуки и очки талантов за мини-боссов и победу.
func add_run_rewards(run_gold: int, minibosses: int, victory: bool, time_s: float, level: int, kills: int) -> void:
	runs += 1
	var bonus_gold := int(time_s / 10.0)
	var new_chests := minibosses + (2 if victory else 0)
	var new_points := minibosses + (2 if victory else 0)
	if victory:
		wins += 1
		bonus_gold += 100
	var total := int((run_gold + bonus_gold) * (1.0 + total_bonus(selected_class).get("gold_mult", 0.0)))
	best_time = max(best_time, time_s)
	gold += total
	chests += new_chests
	add_points(selected_class, new_points)
	last_run = {"victory": victory, "gold": total, "chests": new_chests, "points": new_points,
		"time": time_s, "level": level, "kills": kills}
	save_profile()
