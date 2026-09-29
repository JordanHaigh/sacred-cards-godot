extends RefCounted
class_name BattleCalculator

## Numeric battle.c port. Battle presentation, effects and animation remain
## separate systems, as in the recovered code.

const ATTRIBUTE_BEATS := [0, 2, 3, 4, 1, 6, 7, 8, 9, 10, 5, 0]
const ATTRIBUTE_LOSES_TO := [0, 4, 1, 2, 3, 10, 5, 6, 7, 8, 9, 0]
const DEFEAT_FLAGS := [4, 16]
const MAX_LIFE_POINTS := 9999

class BattleSide:
	var attack: int = 0
	var defense: int = 0
	var life_points: int = 8000
	var attribute: int = 0
	var owner: int = 0

class BattleResult:
	var side_a: BattleSide
	var side_b: BattleSide
	var flags: int = 0
	var code: int = 0

	func _init(a: BattleSide, b: BattleSide, previous_code: int = 0) -> void:
		side_a = a
		side_b = b
		code = previous_code

static func compare_attributes(a: int, b: int) -> int:
	if a == 11 or b == 11:
		return 1
	if a < 0 or a >= ATTRIBUTE_BEATS.size() or b < 0 or b >= ATTRIBUTE_BEATS.size():
		return 1
	if ATTRIBUTE_BEATS[a] == b:
		return 0
	if ATTRIBUTE_LOSES_TO[a] == b:
		return 2
	return 1

static func resolve(a: BattleSide, b: BattleSide, command: int, previous_code: int = 0) -> BattleResult:
	var result := BattleResult.new(a, b, previous_code)
	result.flags = 0
	match command:
		1: _attack_against_attack(result)
		2: _attack_against_defense(result)
		3: pass
		4:
			result.code = 0
			_damage(result, b, a.attack)
			result.code = 10
		5: _defense_against_attack(result)
		6:
			result.code = 0
			_damage(result, a, b.attack)
			result.code = 15
		7: _heal(a, a.attack)
		8: _damage(result, a, a.attack)
		9: _damage(result, b, b.attack)
		10: _heal(b, b.attack)
	return result

static func _damage(result: BattleResult, side: BattleSide, amount: int) -> void:
	if side.life_points <= amount:
		side.life_points = 0
		if side.owner >= 0 and side.owner < DEFEAT_FLAGS.size():
			result.flags |= DEFEAT_FLAGS[side.owner]
	else:
		side.life_points -= amount

static func _heal(side: BattleSide, amount: int) -> void:
	side.life_points = mini(MAX_LIFE_POINTS, side.life_points + amount)

static func _attack_against_attack(r: BattleResult) -> void:
	var relation := compare_attributes(r.side_a.attribute, r.side_b.attribute)
	r.code = 0
	if relation == 0:
		r.flags |= 2
		r.code = 16
		if r.side_a.attack > r.side_b.attack:
			_damage(r, r.side_b, r.side_a.attack - r.side_b.attack)
	elif relation == 2:
		r.flags |= 1
		r.code = 17
		if r.side_a.attack < r.side_b.attack:
			_damage(r, r.side_a, r.side_b.attack - r.side_a.attack)
	elif r.side_a.attack > r.side_b.attack:
		r.flags |= 2
		_damage(r, r.side_b, r.side_a.attack - r.side_b.attack)
		r.code = 1
	elif r.side_a.attack == r.side_b.attack:
		r.flags |= 3
		r.code = 2
	else:
		r.flags |= 1
		_damage(r, r.side_a, r.side_b.attack - r.side_a.attack)
		r.code = 3

static func _attack_against_defense(r: BattleResult) -> void:
	var relation := compare_attributes(r.side_a.attribute, r.side_b.attribute)
	r.code = 0
	if relation == 0:
		r.flags |= 2
		r.code = 16
	elif relation == 2:
		r.flags |= 1
		r.code = 17
		if r.side_a.attack < r.side_b.defense:
			_damage(r, r.side_a, r.side_b.defense - r.side_a.attack)
	elif r.side_a.attack > r.side_b.defense:
		r.flags |= 2
		r.code = 4
	elif r.side_a.attack == r.side_b.defense:
		r.code = 5
	else:
		_damage(r, r.side_a, r.side_b.defense - r.side_a.attack)
		r.code = 6

static func _defense_against_attack(r: BattleResult) -> void:
	var relation := compare_attributes(r.side_a.attribute, r.side_b.attribute)
	r.code = 0
	if relation == 0:
		r.flags |= 2
		r.code = 16
		if r.side_a.defense > r.side_b.attack:
			_damage(r, r.side_b, r.side_a.defense - r.side_b.attack)
	elif relation == 2:
		r.flags |= 1
		r.code = 17
	elif r.side_a.defense > r.side_b.attack:
		_damage(r, r.side_b, r.side_a.defense - r.side_b.attack)
		r.code = 7
	elif r.side_a.defense == r.side_b.attack:
		r.code = 8
	else:
		r.flags |= 1
		r.code = 9
