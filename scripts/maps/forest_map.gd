extends RefCounted
## Карта «Лес» — нарисована вручную данными: стены, камни, лагеря монстров и боссы.
## Ось -Z ведёт вперёд по карте: старт (z=0) → зона 1 → зона 2 → арена босса.

const START := Vector3(0, 0.1, 0)

## Стены и препятствия: [центр, размер]
const WALLS := [
	# Внешние границы
	[Vector3(-24, 2, -92), Vector3(1, 4, 200)],
	[Vector3(24, 2, -92), Vector3(1, 4, 200)],
	[Vector3(0, 2, 8), Vector3(49, 4, 1)],
	[Vector3(0, 2, -192), Vector3(49, 4, 1)],
	# Ворота между зонами (проход в центре шириной 8)
	[Vector3(-14, 2, -62), Vector3(20, 4, 1.5)],
	[Vector3(14, 2, -62), Vector3(20, 4, 1.5)],
	[Vector3(-14, 2, -126), Vector3(20, 4, 1.5)],
	[Vector3(14, 2, -126), Vector3(20, 4, 1.5)],
]

const ROCKS := [
	Vector3(-7, 0, -10), Vector3(9, 0, -14), Vector3(-15, 0, -36), Vector3(2, 0, -32),
	Vector3(16, 0, -48), Vector3(-6, 0, -50),
	Vector3(-17, 0, -72), Vector3(6, 0, -78), Vector3(-3, 0, -94), Vector3(17, 0, -100),
	Vector3(-14, 0, -110), Vector3(8, 0, -116),
	Vector3(-12, 0, -150), Vector3(12, 0, -150), Vector3(-12, 0, -172), Vector3(12, 0, -172),
]

## Лагеря: [центр, сила зоны, список типов]
const CAMPS := [
	# Зона 1
	[Vector3(-10, 0.1, -20), 1.0, ["grunt", "grunt", "grunt"]],
	[Vector3(12, 0.1, -26), 1.0, ["grunt", "grunt", "archer"]],
	[Vector3(-12, 0.1, -42), 1.0, ["grunt", "grunt", "grunt", "archer"]],
	[Vector3(8, 0.1, -40), 1.1, ["brute", "grunt"]],
	# Зона 2
	[Vector3(-12, 0.1, -76), 1.3, ["grunt", "grunt", "archer"]],
	[Vector3(12, 0.1, -84), 1.3, ["brute", "grunt", "grunt"]],
	[Vector3(0, 0.1, -98), 1.4, ["archer", "grunt", "grunt"]],
	[Vector3(-12, 0.1, -104), 1.4, ["brute", "brute"]],
	[Vector3(13, 0.1, -110), 1.5, ["grunt", "grunt", "grunt", "archer"]],
]

## Боссы: [позиция, тип, сила, имя]
const BOSSES := [
	[Vector3(0, 0.1, -55), "miniboss", 1.0, "Вожак гоблинов"],
	[Vector3(0, 0.1, -119), "miniboss", 1.4, "Каменный страж"],
	[Vector3(0, 0.1, -165), "boss", 1.0, "Король тьмы"],
]

## Цвета зон (пол)
const ZONES := [
	[Vector3(0, -0.5, -27), Vector3(48, 1, 70), Color(0.38, 0.62, 0.3)],
	[Vector3(0, -0.5, -94), Vector3(48, 1, 64), Color(0.42, 0.52, 0.28)],
	[Vector3(0, -0.5, -159), Vector3(48, 1, 66), Color(0.36, 0.3, 0.35)],
]
