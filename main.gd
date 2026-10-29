extends Control

const TileView = preload("res://scripts/tile_view.gd")
const GameEngine = preload("res://scripts/engine.gd")
const TARGET := 100
const TL := 1.1
const TW := 0.55
const TH := 0.16
const X_LIM := 3.0
const Z_LIM := 3.3
const SEATS := {2: [2], 3: [1, 2], 4: [1, 2, 3]}

var engine
var n_players := 2
var round_id := 0
var busy := false
var match_over := false
var pending_index := -1

var board_root: Node3D
var seats_root: Node3D
var body_mesh: BoxMesh
var pip_mesh: CylinderMesh
var line_mesh: BoxMesh
var back_mesh: BoxMesh
var mat_ivory: StandardMaterial3D
var mat_pip: StandardMaterial3D
var mat_line: StandardMaterial3D
var mat_back: StandardMaterial3D
var mat_back_turn: StandardMaterial3D

var hand_box: HBoxContainer
var status_lbl: Label
var score_lbl: Label
var info_lbl: Label
var draw_btn: Button
var side_panel: HBoxContainer
var overlay: PanelContainer
var overlay_lbl: Label
var menu_overlay: PanelContainer

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	engine = GameEngine.new()
	engine.new_game(2)
	_build_world()
	_build_ui()
	_refresh()
	menu_overlay.show()

func _mat(c: Color, rough: float = 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

func _build_world() -> void:
	var world := Node3D.new()
	add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.06, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, 25, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	world.add_child(sun)
	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 45.0
	cam.near = 0.1
	cam.far = 60.0
	world.add_child(cam)
	cam.position = Vector3(0, 9.6, 3.4)
	cam.look_at(Vector3(0, 0, 0.2))
	cam.current = true

	var felt := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(12, 0.3, 20)
	felt.mesh = fm
	felt.material_override = _mat(Color(0.06, 0.38, 0.22), 1.0)
	felt.position = Vector3(0, -0.15, 0)
	world.add_child(felt)

	mat_ivory = _mat(Color(0.97, 0.95, 0.88), 0.5)
	mat_pip = _mat(Color(0.08, 0.08, 0.08), 0.4)
	mat_line = _mat(Color(0.35, 0.35, 0.35), 0.5)
	mat_back = _mat(Color(0.12, 0.2, 0.45), 0.5)
	mat_back_turn = _mat(Color(0.9, 0.6, 0.1), 0.5)
	body_mesh = BoxMesh.new()
	body_mesh.size = Vector3(TW, TH, TL)
	pip_mesh = CylinderMesh.new()
	pip_mesh.top_radius = 0.06
	pip_mesh.bottom_radius = 0.06
	pip_mesh.height = 0.012
	pip_mesh.radial_segments = 12
	pip_mesh.rings = 1
	line_mesh = BoxMesh.new()
	line_mesh.size = Vector3(TW * 0.9, 0.008, 0.015)
	back_mesh = BoxMesh.new()
	back_mesh.size = Vector3(0.32, 0.1, 0.6)

	board_root = Node3D.new()
	world.add_child(board_root)
	seats_root = Node3D.new()
	world.add_child(seats_root)

func _make_tile3d(a: int, b: int) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = body_mesh
	body.material_override = mat_ivory
	root.add_child(body)
	var line := MeshInstance3D.new()
	line.mesh = line_mesh
	line.material_override = mat_line
	line.position = Vector3(0, TH / 2.0 + 0.004, 0)
	root.add_child(line)
	_add_pips(root, a, -TL / 4.0)
	_add_pips(root, b, TL / 4.0)
	return root

func _add_pips(root: Node3D, n: int, zc: float) -> void:
	for p in TileView.PIPS[n]:
		var m := MeshInstance3D.new()
		m.mesh = pip_mesh
		m.material_override = mat_pip
		m.position = Vector3((p.x - 0.5) * TW * 0.85, TH / 2.0 + 0.006, zc + (p.y - 0.5) * (TL / 2.0) * 0.85)
		root.add_child(m)

func _spawn(t: Vector2i, pos: Vector2, fwd: Vector2, dbl: bool) -> void:
	var node := _make_tile3d(t.x, t.y)
	var f := fwd
	if dbl:
		f = Vector2(-fwd.y, fwd.x)
	node.position = Vector3(pos.x, TH / 2.0, pos.y)
	node.rotation.y = atan2(f.x, f.y)
	board_root.add_child(node)

func _arm(board: Array, ci: int, step: int, cursor: Vector2, dir: Vector2) -> void:
	var i := ci + step
	while i >= 0 and i < board.size():
		var t: Vector2i = board[i]
		var dbl := t.x == t.y
		var s := TW if dbl else TL
		var far := cursor + dir * s
		var center: Vector2
		if absf(far.x) > X_LIM or absf(far.y) > Z_LIM:
			var nd := Vector2(-dir.y, dir.x)
			var start := cursor + dir * (TW / 2.0) - nd * (TW / 2.0)
			center = start + nd * (s / 2.0)
			cursor = start + nd * s
			dir = nd
		else:
			center = cursor + dir * (s / 2.0)
			cursor = far
		var fwd := dir if step > 0 else -dir
		_spawn(t, center, fwd, dbl)
		i += step

func _rebuild_board() -> void:
	for c in board_root.get_children():
		c.queue_free()
	var board: Array = engine.get_board()
	if board.is_empty():
		return
	var ci: int = engine.get_center()
	var t0: Vector2i = board[ci]
	var dbl0 := t0.x == t0.y
	var s0 := TW if dbl0 else TL
	_spawn(t0, Vector2(0, 0), Vector2(1, 0), dbl0)
	_arm(board, ci, 1, Vector2(s0 / 2.0, 0), Vector2(1, 0))
	_arm(board, ci, -1, Vector2(-s0 / 2.0, 0), Vector2(-1, 0))

func _rebuild_seats() -> void:
	for c in seats_root.get_children():
		c.queue_free()
	var seats: Array = SEATS[n_players]
	for k in range(seats.size()):
		var p := k + 1
		var cnt: int = engine.get_hand_count(p)
		var seat: int = seats[k]
		var is_turn: bool = engine.get_turn() == p and not engine.is_over()
		for j in range(cnt):
			var off := (j - (cnt - 1) / 2.0) * 0.38
			var m := MeshInstance3D.new()
			m.mesh = back_mesh
			m.material_override = mat_back_turn if is_turn else mat_back
			if seat == 1:
				m.position = Vector3(-3.75, 0.05, off)
				m.rotation.y = PI / 2.0
			elif seat == 2:
				m.position = Vector3(off, 0.05, -4.3)
			else:
				m.position = Vector3(3.75, 0.05, off)
				m.rotation.y = PI / 2.0
			seats_root.add_child(m)

func _label(sz: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", sz)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _button(txt: String, sz: int) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_size_override("font_size", sz)
	b.custom_minimum_size = Vector2(0, 80)
	return b

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 16)
	add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vb)

	var top := HBoxContainer.new()
	vb.add_child(top)
	score_lbl = _label(26)
	score_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(score_lbl)
	var mb := _button("القائمة", 24)
	mb.custom_minimum_size = Vector2(130, 60)
	mb.pressed.connect(func(): menu_overlay.show())
	top.add_child(mb)

	info_lbl = _label(24)
	vb.add_child(info_lbl)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(spacer)

	status_lbl = _label(28)
	vb.add_child(status_lbl)

	side_panel = HBoxContainer.new()
	side_panel.add_theme_constant_override("separation", 12)
	var bl := _button("◀ اليسار", 30)
	bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bl.pressed.connect(func(): _do_play(pending_index, 0))
	var br := _button("اليمين ▶", 30)
	br.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	br.pressed.connect(func(): _do_play(pending_index, 1))
	side_panel.add_child(bl)
	side_panel.add_child(br)
	side_panel.hide()
	vb.add_child(side_panel)

	draw_btn = _button("اسحب حجر", 32)
	draw_btn.pressed.connect(_on_draw)
	draw_btn.hide()
	vb.add_child(draw_btn)

	var hs := ScrollContainer.new()
	hs.custom_minimum_size = Vector2(0, 120)
	hs.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(hs)
	hand_box = HBoxContainer.new()
	hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_box.add_theme_constant_override("separation", 6)
	hs.add_child(hand_box)

	overlay = PanelContainer.new()
	overlay.custom_minimum_size = Vector2(560, 320)
	var ob := VBoxContainer.new()
	ob.add_theme_constant_override("separation", 20)
	overlay_lbl = _label(36)
	overlay_lbl.custom_minimum_size = Vector2(520, 0)
	ob.add_child(overlay_lbl)
	var nb := _button("جولة جديدة", 34)
	nb.pressed.connect(_on_new_round)
	ob.add_child(nb)
	overlay.add_child(ob)
	overlay.hide()
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)

	menu_overlay = PanelContainer.new()
	menu_overlay.custom_minimum_size = Vector2(560, 420)
	var mbx := VBoxContainer.new()
	mbx.add_theme_constant_override("separation", 16)
	var title := _label(44)
	title.text = "دومينو - اختر عدد اللاعبين"
	title.custom_minimum_size = Vector2(520, 0)
	mbx.add_child(title)
	for k in [2, 3, 4]:
		var bt := _button("%d لاعبين" % k if k > 2 else "لاعبان (أنت والكمبيوتر)", 32)
		bt.pressed.connect(_new_match.bind(k))
		mbx.add_child(bt)
	menu_overlay.add_child(mbx)
	menu_overlay.hide()
	add_child(menu_overlay)
	menu_overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)

func _new_match(k: int) -> void:
	n_players = k
	match_over = false
	engine.reset_scores()
	menu_overlay.hide()
	_start_round()

func _start_round() -> void:
	overlay.hide()
	side_panel.hide()
	pending_index = -1
	busy = false
	round_id += 1
	engine.new_game(n_players)
	_refresh()
	if engine.get_turn() != 0:
		_ai_loop()
	else:
		_check_player_state("أنت تبدأ. ")

func _on_new_round() -> void:
	if match_over:
		engine.reset_scores()
		match_over = false
	_start_round()

func _refresh() -> void:
	for c in hand_box.get_children():
		c.queue_free()
	draw_btn.hide()
	var hand: Array = engine.get_hand(0)
	for i in range(hand.size()):
		var t: Vector2i = hand[i]
		var v = TileView.new()
		v.setup(t.x, t.y, false, i)
		var playable: bool = engine.get_turn() == 0 and engine.can_play(i) > 0
		v.modulate.a = 1.0 if playable else 0.6
		v.tapped.connect(_on_tile_tapped)
		hand_box.add_child(v)

	_rebuild_board()
	_rebuild_seats()

	var sc := "أنت %d" % engine.get_score(0)
	for p in range(1, n_players):
		sc += "  |  الخصم %d: %d" % [p, engine.get_score(p)]
	score_lbl.text = sc + "  (الهدف %d)" % TARGET

	var ends := ""
	if engine.get_board().size() > 0:
		ends = "الطرفان: %d ⟷ %d   " % [engine.get_left_end(), engine.get_right_end()]
	var inf := ends + "المخزن: %d" % engine.get_bone_count()
	for p in range(1, n_players):
		var mark := " ◀" if (engine.get_turn() == p and not engine.is_over()) else ""
		inf += "\nالخصم %d: %d حجر%s" % [p, engine.get_hand_count(p), mark]
	info_lbl.text = inf

func _on_tile_tapped(view) -> void:
	if busy or engine.is_over() or engine.get_turn() != 0:
		return
	var mask: int = engine.can_play(view.index)
	if mask == 0:
		status_lbl.text = "هذا الحجر لا يناسب"
		return
	if mask == 3:
		pending_index = view.index
		side_panel.show()
		status_lbl.text = "اختر الجهة"
	else:
		_do_play(view.index, 0 if mask == 1 else 1)

func _do_play(idx: int, side: int) -> void:
	side_panel.hide()
	if busy:
		return
	if engine.play_player(idx, side):
		var rid := round_id
		_refresh()
		if engine.is_over():
			_show_result()
		else:
			await get_tree().create_timer(0.4).timeout
			if rid != round_id:
				return
			_ai_loop()

func _on_draw() -> void:
	if busy:
		return
	engine.player_draw()
	_refresh()
	_check_player_state("سحبت حجر. ")

func _ai_loop() -> void:
	var rid := round_id
	busy = true
	var note := ""
	while not engine.is_over() and engine.get_turn() != 0:
		var p: int = engine.get_turn()
		status_lbl.text = "دور الخصم %d..." % p
		_refresh()
		await get_tree().create_timer(0.8).timeout
		if rid != round_id:
			return
		var r: Dictionary = engine.ai_turn()
		var act: String = r.get("action", "none")
		if act == "play":
			note = "الخصم %d لعب. " % p
		elif act == "pass":
			note = "الخصم %d مرّ دوره. " % p
		_refresh()
	busy = false
	if engine.is_over():
		_show_result()
	else:
		_check_player_state(note)

func _check_player_state(note: String) -> void:
	if engine.is_over() or engine.get_turn() != 0:
		return
	if engine.player_has_move():
		status_lbl.text = note + "دورك"
	elif engine.get_bone_count() > 0:
		status_lbl.text = note + "لا يوجد حجر مناسب، اسحب"
		draw_btn.show()
	else:
		status_lbl.text = note + "لا يوجد عندك حجر، مرّ دورك"
		var rid := round_id
		engine.player_pass()
		_refresh()
		if engine.is_over():
			_show_result()
		else:
			busy = true
			await get_tree().create_timer(1.0).timeout
			if rid != round_id:
				return
			busy = false
			_ai_loop()

func _show_result() -> void:
	_refresh()
	side_panel.hide()
	draw_btn.hide()
	var w: int = engine.get_winner()
	var pts: int = engine.get_round_points()
	var txt := ""
	if w == 0:
		txt = "فزت بالجولة!\n+%d نقطة" % pts
	elif w > 0:
		txt = "فاز الخصم %d بالجولة\n+%d نقطة" % [w, pts]
	else:
		txt = "تعادل"
	var best := -1
	var best_p := 0
	for p in range(n_players):
		var s: int = engine.get_score(p)
		txt += "\n" + ("أنت" if p == 0 else "الخصم %d" % p) + ": %d" % s
		if s > best:
			best = s
			best_p = p
	if best >= TARGET:
		match_over = true
		var who := "مبروك! فزت بالمباراة" if best_p == 0 else ("الخصم %d فاز بالمباراة" % best_p)
		txt += "\n\n" + who
	overlay_lbl.text = txt
	overlay.show()
