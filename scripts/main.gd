extends Control

const TileView = preload("res://scripts/tile_view.gd")
const TARGET := 100

var engine
var hand_box: HBoxContainer
var board_box: HBoxContainer
var board_scroll: ScrollContainer
var status_lbl: Label
var score_lbl: Label
var info_lbl: Label
var draw_btn: Button
var side_panel: HBoxContainer
var overlay: PanelContainer
var overlay_lbl: Label
var pending_index := -1
var busy := false
var match_over := false

func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	engine = ClassDB.instantiate("DominoEngine")
	_build_ui()
	if engine == null:
		status_lbl.text = "خطأ: مكتبة اللعبة (C++) لم تُحمَّل"
		return
	engine.reset_scores()
	_start_round()

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
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.33, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 16)
	add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	margin.add_child(vb)

	score_lbl = _label(34)
	vb.add_child(score_lbl)
	info_lbl = _label(26)
	vb.add_child(info_lbl)

	board_scroll = ScrollContainer.new()
	board_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(board_scroll)
	board_box = HBoxContainer.new()
	board_box.alignment = BoxContainer.ALIGNMENT_CENTER
	board_box.add_theme_constant_override("separation", 4)
	board_scroll.add_child(board_box)

	status_lbl = _label(30)
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
	hs.custom_minimum_size = Vector2(0, 150)
	hs.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(hs)
	hand_box = HBoxContainer.new()
	hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_box.add_theme_constant_override("separation", 8)
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

func _start_round() -> void:
	overlay.hide()
	side_panel.hide()
	pending_index = -1
	busy = false
	engine.new_game()
	_refresh()
	if engine.get_turn() == 1:
		status_lbl.text = "الخصم يبدأ"
		_ai_move()
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
	for c in board_box.get_children():
		c.queue_free()
	draw_btn.hide()

	var hand: Array = engine.get_player_hand()
	for i in hand.size():
		var t: Vector2i = hand[i]
		var v = TileView.new()
		v.setup(t.x, t.y, false, i)
		var playable: bool = engine.get_turn() == 0 and engine.can_play(i) > 0
		v.modulate.a = 1.0 if playable else 0.6
		v.tapped.connect(_on_tile_tapped)
		hand_box.add_child(v)

	for t in engine.get_board():
		var v = TileView.new()
		v.setup(t.x, t.y, t.x != t.y, -1)
		v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		board_box.add_child(v)
	board_box.custom_minimum_size.x = board_scroll.size.x

	score_lbl.text = "أنت %d   |   الخصم %d   (الهدف %d)" % [engine.get_player_score(), engine.get_ai_score(), TARGET]
	var ends := ""
	if engine.get_board().size() > 0:
		ends = "الطرفان: %d ⟷ %d     " % [engine.get_left_end(), engine.get_right_end()]
	info_lbl.text = ends + "حجارة الخصم: %d   المخزن: %d" % [engine.get_ai_count(), engine.get_bone_count()]
	_center_board.call_deferred()

func _center_board() -> void:
	await get_tree().process_frame
	board_scroll.scroll_horizontal = int((board_box.size.x - board_scroll.size.x) / 2.0)

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
		_refresh()
		if engine.is_over():
			_show_result()
		else:
			await get_tree().create_timer(0.4).timeout
			_ai_move()

func _on_draw() -> void:
	if busy:
		return
	engine.player_draw()
	_refresh()
	_check_player_state("سحبت حجر. ")

func _ai_move() -> void:
	busy = true
	status_lbl.text = "دور الخصم..."
	await get_tree().create_timer(0.9).timeout
	var r: Dictionary = engine.ai_turn()
	var act: String = r.get("action", "none")
	var drawn: int = r.get("drawn", 0)
	var msg := ""
	if drawn > 0:
		msg += "الخصم سحب %d. " % drawn
	if act == "play":
		msg += "الخصم لعب. "
	elif act == "pass":
		msg += "الخصم مرّ دوره. "
	_refresh()
	busy = false
	if engine.is_over():
		_show_result()
	else:
		_check_player_state(msg)

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
		engine.player_pass()
		_refresh()
		if engine.is_over():
			_show_result()
		else:
			busy = true
			await get_tree().create_timer(1.0).timeout
			busy = false
			_ai_move()

func _show_result() -> void:
	_refresh()
	side_panel.hide()
	draw_btn.hide()
	var w: int = engine.get_winner()
	var pts: int = engine.get_round_points()
	var txt := ""
	if w == 1:
		txt = "فزت بالجولة!\n+%d نقطة" % pts
	elif w == 2:
		txt = "خسرت الجولة\nالخصم +%d نقطة" % pts
	else:
		txt = "تعادل"
	var ps: int = engine.get_player_score()
	var ais: int = engine.get_ai_score()
	txt += "\nأنت %d  —  الخصم %d" % [ps, ais]
	if ps >= TARGET or ais >= TARGET:
		match_over = true
		txt += "\n\n" + ("مبروك! فزت بالمباراة" if ps >= ais else "الخصم فاز بالمباراة")
	overlay_lbl.text = txt
	overlay.show()
