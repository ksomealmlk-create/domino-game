extends RefCounted

var n := 2
var hands: Array = []
var bone: Array = []
var board: Array = []
var center := 0
var left_end := -1
var right_end := -1
var turn := 0
var passes := 0
var winner := -1
var round_points := 0
var scores: Array = [0, 0, 0, 0]
var over := false

func _mask(t: Vector2i) -> int:
	if board.is_empty():
		return 1
	var m := 0
	if t.x == left_end or t.y == left_end:
		m |= 1
	if t.x == right_end or t.y == right_end:
		m |= 2
	return m

func _has_move(h: Array) -> bool:
	for t in h:
		if _mask(t) > 0:
			return true
	return false

func _pips(h: Array) -> int:
	var s := 0
	for t in h:
		s += t.x + t.y
	return s

func _key(t: Vector2i) -> int:
	return 50 + t.x if t.x == t.y else t.x + t.y

func _place(t: Vector2i, side: int) -> void:
	if board.is_empty():
		board.append(t)
		center = 0
		left_end = t.x
		right_end = t.y
		return
	if side == 0:
		var nt: Vector2i = t if t.y == left_end else Vector2i(t.y, t.x)
		board.push_front(nt)
		center += 1
		left_end = nt.x
	else:
		var nt2: Vector2i = t if t.x == right_end else Vector2i(t.y, t.x)
		board.append(nt2)
		right_end = nt2.y

func _finish_empty(who: int) -> void:
	over = true
	winner = who
	var total := 0
	for p in range(n):
		if p != who:
			total += _pips(hands[p])
	round_points = total
	scores[who] += total

func _finish_blocked() -> void:
	over = true
	var best := 100000
	var best_p := -1
	var ties := 0
	for p in range(n):
		var s := _pips(hands[p])
		if s < best:
			best = s
			best_p = p
			ties = 1
		elif s == best:
			ties += 1
	if ties > 1:
		winner = -1
		round_points = 0
		return
	winner = best_p
	var total := 0
	for p in range(n):
		if p != best_p:
			total += _pips(hands[p])
	round_points = total
	scores[best_p] += total

func _apply(p: int, idx: int, side: int) -> void:
	var t: Vector2i = hands[p][idx]
	_place(t, side)
	hands[p].remove_at(idx)
	passes = 0
	if hands[p].is_empty():
		_finish_empty(p)
	else:
		turn = (p + 1) % n

func _pass(p: int) -> void:
	passes += 1
	if passes >= n:
		_finish_blocked()
	else:
		turn = (p + 1) % n

func new_game(players: int) -> void:
	n = clampi(players, 2, 4)
	var all: Array = []
	for i in range(7):
		for j in range(i, 7):
			all.append(Vector2i(i, j))
	all.shuffle()
	hands = []
	for p in range(n):
		hands.append(all.slice(p * 7, p * 7 + 7))
	bone = all.slice(n * 7)
	board = []
	center = 0
	left_end = -1
	right_end = -1
	passes = 0
	over = false
	winner = -1
	round_points = 0
	var best := -1
	turn = 0
	for p in range(n):
		for t in hands[p]:
			var k := _key(t)
			if k > best:
				best = k
				turn = p

func reset_scores() -> void:
	scores = [0, 0, 0, 0]

func get_hand(p: int) -> Array:
	return hands[p].duplicate()

func get_hand_count(p: int) -> int:
	return hands[p].size()

func get_board() -> Array:
	return board.duplicate()

func get_center() -> int:
	return center

func get_bone_count() -> int:
	return bone.size()

func get_turn() -> int:
	return turn

func is_over() -> bool:
	return over

func get_winner() -> int:
	return winner

func get_round_points() -> int:
	return round_points

func get_score(p: int) -> int:
	return scores[p]

func get_left_end() -> int:
	return left_end

func get_right_end() -> int:
	return right_end

func can_play(index: int) -> int:
	if index < 0 or index >= hands[0].size():
		return 0
	return _mask(hands[0][index])

func player_has_move() -> bool:
	return _has_move(hands[0])

func play_player(index: int, side: int) -> bool:
	if over or turn != 0:
		return false
	if index < 0 or index >= hands[0].size():
		return false
	var m := _mask(hands[0][index])
	if not board.is_empty():
		var need := 1 if side == 0 else 2
		if (m & need) == 0:
			return false
	_apply(0, index, side)
	return true

func player_draw() -> Vector2i:
	if over or turn != 0 or bone.is_empty() or _has_move(hands[0]):
		return Vector2i(-1, -1)
	var t: Vector2i = bone.pop_back()
	hands[0].append(t)
	return t

func player_pass() -> bool:
	if over or turn != 0 or _has_move(hands[0]) or not bone.is_empty():
		return false
	_pass(0)
	return true

func ai_turn() -> Dictionary:
	var d := {"action": "none", "drawn": 0, "player": turn}
	if over or turn == 0:
		return d
	var p := turn
	var h: Array = hands[p]
	var drawn := 0
	while not _has_move(h) and not bone.is_empty():
		h.append(bone.pop_back())
		drawn += 1
	d["drawn"] = drawn
	var bi := -1
	var bs := 0
	var best := -1
	for i in range(h.size()):
		var t: Vector2i = h[i]
		for s in range(2):
			var ok := false
			if board.is_empty():
				ok = (s == 0)
			elif s == 0:
				ok = (t.x == left_end or t.y == left_end)
			else:
				ok = (t.x == right_end or t.y == right_end)
			if not ok:
				continue
			var sc := t.x + t.y + (3 if t.x == t.y else 0) + randi() % 3
			if sc > best:
				best = sc
				bi = i
				bs = s
	if bi >= 0:
		d["action"] = "play"
		_apply(p, bi, bs)
	else:
		d["action"] = "pass"
		_pass(p)
	return d
