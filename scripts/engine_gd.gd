extends RefCounted

var ph: Array = []
var ah: Array = []
var bone: Array = []
var board: Array = []
var left_end := -1
var right_end := -1
var turn := 0
var passes := 0
var winner := 0
var round_points := 0
var pscore := 0
var ascore := 0
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
        left_end = t.x
        right_end = t.y
        return
    if side == 0:
        var n: Vector2i = t if t.y == left_end else Vector2i(t.y, t.x)
        board.push_front(n)
        left_end = n.x
    else:
        var n2: Vector2i = t if t.x == right_end else Vector2i(t.y, t.x)
        board.append(n2)
        right_end = n2.y

func _finish_empty(who: int) -> void:
    over = true
    winner = who
    if who == 1:
        round_points = _pips(ah)
        pscore += round_points
    else:
        round_points = _pips(ph)
        ascore += round_points

func _finish_blocked() -> void:
    over = true
    var p := _pips(ph)
    var a := _pips(ah)
    if p < a:
        winner = 1
        round_points = a - p
        pscore += round_points
    elif a < p:
        winner = 2
        round_points = p - a
        ascore += round_points
    else:
        winner = 3
        round_points = 0

func new_game() -> void:
    var all: Array = []
    for i in range(7):
        for j in range(i, 7):
            all.append(Vector2i(i, j))
    all.shuffle()
    ph = all.slice(0, 7)
    ah = all.slice(7, 14)
    bone = all.slice(14)
    board = []
    left_end = -1
    right_end = -1
    passes = 0
    over = false
    winner = 0
    round_points = 0
    var mp := -1
    var ma := -1
    for t in ph:
        mp = maxi(mp, _key(t))
    for t in ah:
        ma = maxi(ma, _key(t))
    turn = 0 if mp >= ma else 1

func reset_scores() -> void:
    pscore = 0
    ascore = 0

func get_player_hand() -> Array:
    return ph.duplicate()

func get_board() -> Array:
    return board.duplicate()

func get_ai_count() -> int:
    return ah.size()

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

func get_player_score() -> int:
    return pscore

func get_ai_score() -> int:
    return ascore

func get_left_end() -> int:
    return left_end

func get_right_end() -> int:
    return right_end

func can_play(index: int) -> int:
    if index < 0 or index >= ph.size():
        return 0
    return _mask(ph[index])

func player_has_move() -> bool:
    return _has_move(ph)

func play_player(index: int, side: int) -> bool:
    if over or turn != 0:
        return false
    if index < 0 or index >= ph.size():
        return false
    var m := _mask(ph[index])
    if not board.is_empty():
        var need := 1 if side == 0 else 2
        if (m & need) == 0:
            return false
    _place(ph[index], side)
    ph.remove_at(index)
    passes = 0
    if ph.is_empty():
        _finish_empty(1)
    else:
        turn = 1
    return true

func player_draw() -> Vector2i:
    if over or turn != 0 or bone.is_empty() or _has_move(ph):
        return Vector2i(-1, -1)
    var t: Vector2i = bone.pop_back()
    ph.append(t)
    return t

func player_pass() -> bool:
    if over or turn != 0 or _has_move(ph) or not bone.is_empty():
        return false
    passes += 1
    if passes >= 2:
        _finish_blocked()
    else:
        turn = 1
    return true

func ai_turn() -> Dictionary:
    var d := {"action": "none", "drawn": 0}
    if over or turn != 1:
        return d
    var drawn := 0
    while not _has_move(ah) and not bone.is_empty():
        ah.append(bone.pop_back())
        drawn += 1
    d["drawn"] = drawn
    var bi := -1
    var bs := 0
    var best := -1
    for i in range(ah.size()):
        var t: Vector2i = ah[i]
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
        var tt: Vector2i = ah[bi]
        _place(tt, bs)
        ah.remove_at(bi)
        passes = 0
        d["action"] = "play"
        d["tile"] = tt
        d["side"] = bs
        if ah.is_empty():
            _finish_empty(2)
        else:
            turn = 0
    else:
        passes += 1
        d["action"] = "pass"
        if passes >= 2:
            _finish_blocked()
        else:
            turn = 0
    return d
