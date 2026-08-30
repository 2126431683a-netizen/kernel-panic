extends CanvasLayer
## 全套终端动漫风 UI：主菜单 / 操作说明 / 暂停菜单 / HUD / 升级面板 / 结算屏

signal menu_start
signal menu_quit_app
signal pause_requested
signal resume_requested
signal pause_to_title
signal restart_requested
signal upgrade_chosen(id)

var font: Font

var hp_label: Label
var wave_label: Label
var kill_label: Label
var log_label: Label
var xp_label: Label
var banner_label: Label
var dmg_rect: ColorRect
var low_hp_rect: ColorRect
var low_hp_tween: Tween
var boss_root: Control
var boss_name: Label
var boss_fill: ColorRect
var world_elements: Array = []

var menu_root: Control
var help_root: Control
var pause_root: Control
var pause_build: Label
var go_root: Control
var go_stats: Label
var go_build: Label
var lu_root: Control
var lu_level: Label
var lu_buttons: Array = []
var lu_options: Array = []

var menu_buttons: Array = []
var log_lines: Array = []

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = KP.font()
	_build_hud()
	_build_menu()
	_build_help()
	_build_pause()
	_build_gameover()
	_build_levelup()
	show_menu()

func _mk_label(fs: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", KP.ui_font())
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	return l

func _set_anchors(c: Control, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = l
	c.anchor_top = t
	c.anchor_right = r
	c.anchor_bottom = b

func _full_rect(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _focus_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.03, 0.03, 0.45)
	sb.border_color = KP.GOLD
	sb.border_width_left = 4
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 16.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	return sb

func _menu_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", KP.UI)
	b.add_theme_color_override("font_hover_color", KP.GOLD)
	b.add_theme_color_override("font_focus_color", KP.GOLD)
	b.add_theme_color_override("font_pressed_color", KP.VERMILION)
	var idle := StyleBoxFlat.new()
	idle.bg_color = Color(0, 0, 0, 0.25)
	idle.set_corner_radius_all(4)
	idle.content_margin_left = 16.0
	idle.content_margin_top = 6.0
	idle.content_margin_bottom = 6.0
	b.add_theme_stylebox_override("normal", idle)
	b.add_theme_stylebox_override("hover", _focus_style())
	b.add_theme_stylebox_override("pressed", _focus_style())
	b.add_theme_stylebox_override("focus", _focus_style())
	b.pressed.connect(cb)
	return b

func _lacquer_panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.035, 0.03, 0.94)
	sb.border_color = KP.GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 34.0
	sb.content_margin_right = 34.0
	sb.content_margin_top = 24.0
	sb.content_margin_bottom = 24.0
	p.add_theme_stylebox_override("panel", sb)
	return p

# ---------------- HUD（游戏中） ----------------

func _build_hud() -> void:
	hp_label = _mk_label(20, KP.JADE)
	_set_anchors(hp_label, 0.0, 0.0, 0.0, 0.0)
	hp_label.offset_left = 18.0
	hp_label.offset_top = 12.0
	add_child(hp_label)

	wave_label = _mk_label(20, KP.GOLD)
	_set_anchors(wave_label, 0.5, 0.0, 0.5, 0.0)
	wave_label.offset_left = -200.0
	wave_label.offset_right = 200.0
	wave_label.offset_top = 12.0
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(wave_label)

	kill_label = _mk_label(20, KP.VERMILION)
	kill_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_set_anchors(kill_label, 1.0, 0.0, 1.0, 0.0)
	kill_label.offset_left = -280.0
	kill_label.offset_right = -18.0
	kill_label.offset_top = 12.0
	kill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(kill_label)

	log_label = _mk_label(15, Color(0.55, 0.9, 0.68, 0.9))
	log_label.add_theme_font_override("font", font)
	_set_anchors(log_label, 0.0, 1.0, 0.0, 1.0)
	log_label.offset_left = 18.0
	log_label.offset_top = -132.0
	log_label.offset_bottom = -12.0
	add_child(log_label)

	xp_label = _mk_label(20, KP.YELLOW)
	_set_anchors(xp_label, 1.0, 1.0, 1.0, 1.0)
	xp_label.offset_left = -340.0
	xp_label.offset_right = -18.0
	xp_label.offset_top = -40.0
	xp_label.offset_bottom = -12.0
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(xp_label)

	banner_label = _mk_label(34, KP.GOLD)
	_set_anchors(banner_label, 0.5, 0.0, 0.5, 0.0)
	banner_label.offset_left = -460.0
	banner_label.offset_right = 460.0
	banner_label.offset_top = 110.0
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.modulate.a = 0.0
	add_child(banner_label)

	dmg_rect = ColorRect.new()
	dmg_rect.color = Color(1.0, 0.1, 0.1, 0.0)
	_full_rect(dmg_rect)
	add_child(dmg_rect)

	low_hp_rect = ColorRect.new()
	low_hp_rect.color = Color(0.8, 0.0, 0.0, 0.0)
	_full_rect(low_hp_rect)
	add_child(low_hp_rect)

	boss_root = Control.new()
	_full_rect(boss_root)
	add_child(boss_root)
	boss_name = _mk_label(16, KP.RED)
	boss_name.text = "BOSS"
	_set_anchors(boss_name, 0.5, 0.0, 0.5, 0.0)
	boss_name.offset_left = -300.0
	boss_name.offset_right = 300.0
	boss_name.offset_top = 42.0
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_root.add_child(boss_name)
	var boss_bg := ColorRect.new()
	boss_bg.color = Color(0, 0, 0, 0.55)
	_set_anchors(boss_bg, 0.5, 0.0, 0.5, 0.0)
	boss_bg.offset_left = -300.0
	boss_bg.offset_right = 300.0
	boss_bg.offset_top = 64.0
	boss_bg.offset_bottom = 72.0
	boss_root.add_child(boss_bg)
	boss_fill = ColorRect.new()
	boss_fill.color = KP.RED
	_set_anchors(boss_fill, 0.5, 0.0, 0.5, 0.0)
	boss_fill.offset_left = -298.0
	boss_fill.offset_top = 66.0
	boss_fill.offset_bottom = 70.0
	boss_fill.offset_right = 298.0
	boss_root.add_child(boss_fill)
	boss_root.visible = false

	world_elements = [hp_label, wave_label, kill_label, log_label, xp_label, boss_root, low_hp_rect]

# ---------------- 主菜单 ----------------

func _build_menu() -> void:
	menu_root = Control.new()
	_full_rect(menu_root)
	add_child(menu_root)

	var bg := KP.tex("title_bg")
	if bg != null:
		var tr := TextureRect.new()
		tr.texture = bg
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_full_rect(tr)
		tr.modulate = Color(1, 1, 1, 0.5)
		menu_root.add_child(tr)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.0, 0.01, 0.55)
	_full_rect(dim)
	menu_root.add_child(dim)

	var mascot_tex := KP.tex("logo_mascot")
	if mascot_tex != null:
		var mascot := TextureRect.new()
		mascot.texture = mascot_tex
		mascot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mascot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mascot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_anchors(mascot, 0.5, 0.0, 0.5, 0.0)
		mascot.offset_left = -95.0
		mascot.offset_right = 95.0
		mascot.offset_top = 34.0
		mascot.offset_bottom = 224.0
		menu_root.add_child(mascot)
		var mtw := mascot.create_tween().set_loops()
		mtw.tween_property(mascot, "offset_top", 20.0, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		mtw.parallel().tween_property(mascot, "offset_bottom", 210.0, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		mtw.tween_property(mascot, "offset_top", 34.0, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		mtw.parallel().tween_property(mascot, "offset_bottom", 224.0, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var logo := _mk_label(64, KP.GOLD)
	logo.text = "KERNEL PANIC"
	_set_anchors(logo, 0.5, 0.0, 0.5, 0.0)
	logo.offset_left = -500.0
	logo.offset_right = 500.0
	logo.offset_top = 224.0
	logo.add_theme_constant_override("outline_size", 12)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_root.add_child(logo)

	var sub := _mk_label(18, KP.JADE)
	sub.text = "— 内 核 恐 慌 · 北 京 篇 —"
	_set_anchors(sub, 0.5, 0.0, 0.5, 0.0)
	sub.offset_left = -420.0
	sub.offset_right = 420.0
	sub.offset_top = 320.0
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_root.add_child(sub)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_set_anchors(box, 0.5, 0.0, 0.5, 0.0)
	box.offset_left = -170.0
	box.offset_right = 170.0
	box.offset_top = 408.0
	box.offset_bottom = 640.0
	menu_root.add_child(box)

	var b_start := _menu_button("▸  开始游戏", func(): menu_start.emit())
	var b_help := _menu_button("▸  操作说明", _show_help)
	var b_quit := _menu_button("▸  退出游戏", func(): menu_quit_app.emit())
	box.add_child(b_start)
	box.add_child(b_help)
	box.add_child(b_quit)
	menu_buttons = [b_start, b_help, b_quit]

	var hint := _mk_label(14, Color(1.0, 0.9, 0.6, 0.8))
	hint.text = "↑↓ 选择  ·  ENTER 确认  ·  支持鼠标点击"
	_set_anchors(hint, 0.5, 1.0, 0.5, 1.0)
	hint.offset_left = -300.0
	hint.offset_right = 300.0
	hint.offset_top = -46.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_root.add_child(hint)

	var ver := _mk_label(12, Color(1, 1, 1, 0.4))
	ver.text = "KERNEL PANIC v2.0-anime  ·  godot 4.7.2"
	_set_anchors(ver, 0.0, 1.0, 0.0, 1.0)
	ver.offset_left = 14.0
	ver.offset_top = -28.0
	menu_root.add_child(ver)

# ---------------- 操作说明 ----------------

func _build_help() -> void:
	help_root = Control.new()
	_full_rect(help_root)
	add_child(help_root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	_full_rect(dim)
	help_root.add_child(dim)

	var cc := CenterContainer.new()
	_full_rect(cc)
	help_root.add_child(cc)

	var panel := _lacquer_panel()
	cc.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := _mk_label(28, KP.GOLD)
	title.text = "操 作 说 明"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var lines := [
		["移动", "WASD / 方向键"],
		["开火", "自动锁定最近的敌对进程"],
		["升级", "按 1 / 2 / 3 或点击选择补丁"],
		["暂停", "ESC"],
		["敌对进程", "▓ glitch 杂兵 · ◆ runner 疾行 · █ tank 石狮卫士 · ★ elite 神龙"],
		["目标", "在北京地图上活得越久越好"],
	]
	for ln in lines:
		var row := _mk_label(17, KP.UI)
		row.text = "%s   %s" % [ln[0], ln[1]]
		box.add_child(row)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	box.add_child(spacer)

	var back := _menu_button("▸  返回  [ESC]", show_menu)
	box.add_child(back)

	help_root.visible = false

# ---------------- 暂停菜单 ----------------

func _build_pause() -> void:
	pause_root = Control.new()
	_full_rect(pause_root)
	add_child(pause_root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	_full_rect(dim)
	pause_root.add_child(dim)

	var cc := CenterContainer.new()
	_full_rect(cc)
	pause_root.add_child(cc)

	var panel := _lacquer_panel()
	cc.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := _mk_label(32, KP.GOLD)
	title.text = "‖ 暂  停 ‖"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 6)
	box.add_child(sep)

	var build_title := _mk_label(15, KP.JADE)
	build_title.text = "—— 本次构建 ——"
	build_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(build_title)

	pause_build = _mk_label(15, KP.UI)
	pause_build.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(pause_build)

	var sep2 := Control.new()
	sep2.custom_minimum_size = Vector2(0, 6)
	box.add_child(sep2)

	var b_resume := _menu_button("▸  继续游戏", func(): resume_requested.emit())
	var b_title := _menu_button("▸  返回主菜单", func(): pause_to_title.emit())
	var b_quit := _menu_button("▸  退出游戏", func(): menu_quit_app.emit())
	box.add_child(b_resume)
	box.add_child(b_title)
	box.add_child(b_quit)

	var hint := _mk_label(14, Color(1.0, 0.9, 0.6, 0.8))
	hint.text = "ESC 继续"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	pause_root.visible = false

# ---------------- 结算屏 ----------------

func _build_gameover() -> void:
	go_root = Control.new()
	_full_rect(go_root)
	add_child(go_root)

	var gbg := KP.tex("gameover_bg")
	if gbg != null:
		var gtr := TextureRect.new()
		gtr.texture = gbg
		gtr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		gtr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_full_rect(gtr)
		gtr.modulate = Color(1, 1, 1, 0.85)
		go_root.add_child(gtr)

	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.0, 0.0, 0.45)
	_full_rect(dim)
	go_root.add_child(dim)

	var cc := CenterContainer.new()
	_full_rect(cc)
	go_root.add_child(cc)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	cc.add_child(box)

	var t := _mk_label(52, KP.RED)
	t.text = "KERNEL PANIC"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)

	var st := _mk_label(15, KP.ORANGE)
	st.text = "> doom_fire protocol engaged — system halted"
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(st)

	go_stats = _mk_label(20, KP.UI)
	go_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(go_stats)

	go_build = _mk_label(15, Color(1.0, 0.9, 0.6, 0.9))
	go_build.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(go_build)

	var p := _mk_label(22, KP.YELLOW)
	p.text = ">>  按 R 重新引导系统  <<"
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(p)
	var tw := p.create_tween().set_loops()
	tw.tween_property(p, "modulate:a", 0.15, 0.55)
	tw.tween_property(p, "modulate:a", 1.0, 0.55)

	go_root.visible = false

# ---------------- 升级面板 ----------------

func _build_levelup() -> void:
	lu_root = Control.new()
	_full_rect(lu_root)
	add_child(lu_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.0, 0.0, 0.6)
	_full_rect(dim)
	lu_root.add_child(dim)

	var cc := CenterContainer.new()
	_full_rect(cc)
	lu_root.add_child(cc)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	cc.add_child(box)

	var title := _mk_label(30, KP.GOLD)
	title.text = "▲  系统升级 — 注入补丁  ▲"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	lu_level = _mk_label(17, KP.JADE)
	lu_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(lu_level)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)

	for i in 3:
		var b := Button.new()
		b.custom_minimum_size = Vector2(250, 140)
		b.focus_mode = Control.FOCUS_NONE

		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.04, 0.04, 0.94)
		sb.border_color = KP.VERMILION
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		var sbh: StyleBoxFlat = sb.duplicate()
		sbh.border_color = KP.GOLD
		sbh.bg_color = Color(0.18, 0.07, 0.05, 0.96)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sbh)
		b.add_theme_stylebox_override("pressed", sbh)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 10)
		var nm := _mk_label(22, KP.GOLD)
		nm.name = "nm"
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var ds := _mk_label(14, KP.DIM)
		ds.name = "ds"
		ds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(nm)
		vb.add_child(ds)
		b.add_child(vb)
		b.pressed.connect(_on_button.bind(i))
		row.add_child(b)
		lu_buttons.append(b)

	var hint := _mk_label(14, Color(1.0, 0.9, 0.6, 0.8))
	hint.text = "按 [1] [2] [3] 或点击选择"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	lu_root.visible = false

# ---------------- 页面切换 ----------------

func show_menu() -> void:
	menu_root.visible = true
	help_root.visible = false
	pause_root.visible = false
	go_root.visible = false
	lu_root.visible = false
	if menu_buttons.size() > 0:
		menu_buttons[0].call_deferred("grab_focus")

func _show_help() -> void:
	menu_root.visible = false
	help_root.visible = true

func show_pause(build_lines: Array) -> void:
	pause_build.text = "\n".join(PackedStringArray(build_lines))
	pause_root.visible = true

func hide_pause() -> void:
	pause_root.visible = false

func hide_menu() -> void:
	menu_root.visible = false
	help_root.visible = false

func hide_gameover() -> void:
	go_root.visible = false

func set_low_hp(active: bool) -> void:
	if active == low_hp_rect.visible:
		return
	low_hp_rect.visible = active
	if low_hp_tween != null:
		low_hp_tween.kill()
		low_hp_tween = null
	if active:
		low_hp_tween = low_hp_rect.create_tween().set_loops()
		low_hp_tween.tween_property(low_hp_rect, "color:a", 0.22, 0.5)
		low_hp_tween.tween_property(low_hp_rect, "color:a", 0.05, 0.5)
	else:
		low_hp_rect.color.a = 0.0

func set_boss(bname: String, frac: float) -> void:
	boss_root.visible = true
	boss_name.text = bname
	boss_fill.offset_right = lerpf(-298.0, 298.0, clampf(frac, 0.0, 1.0))

func hide_boss() -> void:
	boss_root.visible = false

func show_world(b: bool) -> void:
	for c in world_elements:
		c.visible = b

func show_gameover(time_s: float, w: int, k: int, lv: int, build_lines: Array) -> void:
	go_stats.text = "存活时间   %02d:%02d\n进程击杀   %d\n波次       %d\n系统等级   LV %d" % [int(time_s / 60.0), int(time_s) % 60, k, w, lv]
	go_build.text = "构建: " + " · ".join(PackedStringArray(build_lines))
	go_root.visible = true

func reset_hud() -> void:
	log_lines.clear()
	log_label.text = ""

func set_hp(a: float, m: float) -> void:
	var f := int(round(12.0 * clampf(a / m, 0.0, 1.0)))
	hp_label.text = "HP  [%s%s]  %d/%d" % ["▓".repeat(f), "░".repeat(12 - f), int(a), int(m)]

func set_wave(w: int, t: float) -> void:
	wave_label.text = "WAVE %d    %02d:%02d" % [w, int(t / 60.0), int(t) % 60]

func set_kills(k: int) -> void:
	kill_label.text = "KILLS %d" % k

func set_xp(lv: int, c: int, n: int) -> void:
	var f := int(round(14.0 * clampf(float(c) / float(n), 0.0, 1.0)))
	xp_label.text = "LV %d  XP [%s%s] %d/%d" % [lv, "▓".repeat(f), "░".repeat(14 - f), c, n]

func log_line(s: String) -> void:
	log_lines.append(s)
	if log_lines.size() > 6:
		log_lines.pop_front()
	log_label.text = "\n".join(PackedStringArray(log_lines))

func banner(t: String) -> void:
	banner_label.text = t
	var tw := banner_label.create_tween()
	tw.tween_property(banner_label, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.4)
	tw.tween_property(banner_label, "modulate:a", 0.0, 0.5)

func flash_damage() -> void:
	dmg_rect.color.a = 0.28
	var tw := dmg_rect.create_tween()
	tw.tween_property(dmg_rect, "color:a", 0.0, 0.3)

func show_levelup(opts: Array, lv: int) -> void:
	lu_options = opts
	lu_level.text = "LEVEL %d  ·  选择你的构建方向" % lv
	var rarity_color := {"common": Color(0.2, 0.7, 0.4), "rare": KP.CYAN, "epic": KP.GOLD}
	var rarity_tag := {"common": "", "rare": "  ◆稀有", "epic": "  ★史诗"}
	for i in 3:
		var b: Button = lu_buttons[i]
		if i >= opts.size():
			b.visible = false
			continue
		b.visible = true
		var card: Dictionary = opts[i]
		var vb := b.get_child(0)
		var nm: Label = vb.get_node("nm")
		nm.text = card["name"] + rarity_tag[card["rarity"]]
		nm.add_theme_color_override("font_color", rarity_color[card["rarity"]] if card["rarity"] != "common" else KP.GOLD)
		(vb.get_node("ds") as Label).text = "%s\nLv.%d → Lv.%d" % [card["desc"], card["lv_now"], card["lv_next"]]
		var normal_sb := b.get_theme_stylebox("normal") as StyleBoxFlat
		if normal_sb != null:
			normal_sb.border_color = rarity_color[card["rarity"]]
	lu_root.visible = true

func hide_levelup() -> void:
	lu_root.visible = false

func pick_random_upgrade() -> void:
	if lu_options.size() > 0:
		_choose(randi() % lu_options.size())

# ---------------- 内部 ----------------

func _on_button(i: int) -> void:
	_choose(i)

func _choose(i: int) -> void:
	if i >= lu_options.size():
		return
	upgrade_chosen.emit(lu_options[i])

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.keycode
	if help_root.visible:
		if k == KEY_ESCAPE or k == KEY_ENTER or k == KEY_SPACE:
			show_menu()
	elif pause_root.visible:
		if k == KEY_ESCAPE or k == KEY_P:
			resume_requested.emit()
	elif menu_root.visible:
		pass
	elif lu_root.visible:
		if k == KEY_1:
			_choose(0)
		elif k == KEY_2:
			_choose(1)
		elif k == KEY_3:
			_choose(2)
	elif go_root.visible:
		if k == KEY_R or k == KEY_ENTER:
			restart_requested.emit()
	else:
		if k == KEY_ESCAPE or k == KEY_P:
			pause_requested.emit()
