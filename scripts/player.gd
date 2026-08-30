extends Node2D
## 玩家 = 系统管理员 @：WASD 移动，自动锁定最近进程开火

var main
var max_hp := GameConfig.PLAYER_MAX_HP
var hp := GameConfig.PLAYER_MAX_HP
var move_speed := GameConfig.PLAYER_SPEED
var fire_interval := GameConfig.FIRE_INTERVAL
var fire_cd := 0.0
var damage := GameConfig.BULLET_DAMAGE
var bullet_speed := GameConfig.BULLET_SPEED
var multishot := 1
var pierce := 1
var magnet := GameConfig.MAGNET_RADIUS
var iframes := 0.0
var flash := 0.0
var t := 0.0
var walk_phase := 0.0
var move_amt := 0.0
var facing := 1.0
var lean := 0.0
var dust_cd := 0.0
var atlas_tex: Texture2D = null
var atlas_frames := {}

## ---- 多武器系统 ----
var upgrade_levels := {}           ## 补丁/武器等级表：id -> level
var xp_mult := 1.0                 ## 经验获取倍率
var armor_lv := 0                  ## 防火墙等级（受伤 ×0.85^lv）
var orbit_count := 0               ## 回旋扳手数量（0 = 未拥有）
var orbit_dmg := GameConfig.ORBIT_DMG_BASE
var orbit_angle := 0.0
var thunder_interval := 0.0        ## 引雷间隔（0 = 未拥有）
var thunder_cd := 0.0
var thunder_dmg := GameConfig.THUNDER_DMG
var thunder_chain := GameConfig.THUNDER_CHAIN

func _ready() -> void:
	atlas_tex = KP.tex("player_atlas")
	if atlas_tex == null:
		return
	var f := FileAccess.open("res://assets/sprites/player_atlas.json", FileAccess.READ)
	if f == null:
		atlas_tex = null
		return
	var data = JSON.parse_string(f.get_as_text())
	if data == null or not data.has("frame_layout"):
		atlas_tex = null
		return
	for state in data["frame_layout"]["rows"].keys():
		var arr: Array = []
		for fr in data["frame_layout"]["rows"][state]:
			arr.append(Rect2(fr["x"], fr["y"], fr["w"], fr["h"]))
		atlas_frames[state] = arr

func _physics_process(delta: float) -> void:
	if main.state != main.State.PLAYING:
		return
	t += delta
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if dir != Vector2.ZERO:
		dir = dir.normalized()
	position += dir * move_speed * delta
	position.x = clampf(position.x, -main.ARENA_W + 20.0, main.ARENA_W - 20.0)
	position.y = clampf(position.y, -main.ARENA_H + 20.0, main.ARENA_H - 20.0)
	var moving := dir != Vector2.ZERO
	move_amt = lerpf(move_amt, 1.0 if moving else 0.0, minf(1.0, delta * 9.0))
	if moving:
		walk_phase += delta * clampf(move_speed / 28.0, 5.0, 15.0)
		lean = lerpf(lean, -dir.x * 0.09, minf(1.0, delta * 10.0))
		if dir.x != 0.0:
			facing = signf(dir.x)
		dust_cd -= delta
		if dust_cd <= 0.0:
			dust_cd = 0.16
			main.fx_dust(global_position + Vector2(randf_range(-7.0, 7.0), 18.0))
	else:
		lean = lerpf(lean, 0.0, minf(1.0, delta * 8.0))
		dust_cd = 0.05
	if orbit_count > 0:
		orbit_angle = fmod(orbit_angle + delta * GameConfig.ORBIT_SPEED, TAU)
		queue_redraw()
	if thunder_interval > 0.0:
		thunder_cd -= delta
		if thunder_cd <= 0.0 and main.enemies_node.get_child_count() > 0:
			thunder_cd = thunder_interval
			main.cast_thunder()
	fire_cd -= delta
	if fire_cd <= 0.0:
		_try_fire()
	iframes = maxf(iframes - delta, 0.0)
	flash = maxf(flash - delta * 5.0, 0.0)
	queue_redraw()

func _try_fire() -> void:
	var target = null
	var best := 560.0 * 560.0
	for e in main.enemies_node.get_children():
		if not is_instance_valid(e) or e.dead:
			continue
		var d := global_position.distance_squared_to(e.global_position)
		if d < best:
			best = d
			target = e
	if target == null:
		return
	fire_cd = fire_interval
	var base: float = (target.global_position - global_position).angle()
	for i in multishot:
		var off := (float(i) - float(multishot - 1) * 0.5) * 0.15
		var b = load("res://scripts/bullet.gd").new()
		b.setup(main, global_position + Vector2.from_angle(base) * 14.0,
				Vector2.from_angle(base + off) * bullet_speed, damage, pierce)
		main.bullets_node.add_child(b)
		b.reset_physics_interpolation()
	Sfx.play("shoot")
	main.fx_ring(global_position + Vector2.from_angle(base) * 20.0, KP.CYAN, 3.0, 11.0)

func take_damage(d: float) -> void:
	if iframes > 0.0:
		return
	hp -= d * pow(0.85, armor_lv)
	iframes = 0.7
	flash = 1.0
	main.on_player_hit()
	if hp <= 0.0:
		hp = 0.0
		main.game_over()

func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)

func heal_full() -> void:
	hp = max_hp

func _draw() -> void:
	var blink := iframes > 0.0 and int(t * 20.0) % 2 == 0
	draw_arc(Vector2.ZERO, magnet, 0.0, TAU, 48, Color(0.3, 1.0, 0.6, 0.06), 1.0)
	if orbit_count > 0:
		for i in orbit_count:
			var op := Vector2.from_angle(orbit_angle + float(i) * TAU / float(orbit_count)) * GameConfig.ORBIT_RADIUS
			draw_circle(op, 9.0, Color(0.35, 1.0, 0.65, 0.95))
			draw_arc(op, 11.5, 0.0, TAU, 20, Color(1, 1, 1, 0.55), 1.5)
	var bob := sin(walk_phase) * 3.5 * move_amt
	var breathe := sin(t * 2.4) * 0.02
	var sq := sin(walk_phase) * 0.055 * move_amt + breathe
	var modc := Color(1, 1, 1, 0.45) if blink else Color(1, 1, 1)
	draw_set_transform(Vector2(0.0, bob), lean, Vector2((1.0 + sq) * facing, 1.0 - sq))
	if atlas_tex != null and atlas_frames.size() > 0:
		var state := "run" if move_amt > 0.4 else "idle"
		var frames: Array = atlas_frames.get(state, [])
		if frames.size() > 0:
			var idx: int = (int(walk_phase) % frames.size()) if state == "run" else (int(t * 4.0) % frames.size())
			draw_texture_rect_region(atlas_tex, Rect2(Vector2(-32.0, -32.0), Vector2(64.0, 64.0)), frames[idx], modc)
			if flash > 0.3:
				draw_circle(Vector2.ZERO, 26.0, Color(1, 0.4, 0.4, (flash - 0.3) * 0.8))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
	var tex := KP.tex("player")
	if tex != null:
		draw_texture_rect(tex, Rect2(Vector2(-30.0, -30.0), Vector2(60.0, 60.0)), false, modc)
		if flash > 0.3:
			draw_circle(Vector2.ZERO, 26.0, Color(1, 0.4, 0.4, (flash - 0.3) * 0.8))
	else:
		var col := Color(1.0, 0.3, 0.3) if flash > 0.5 else (Color(1.0, 0.25, 0.25, 0.4) if blink else KP.GREEN)
		KP.draw_center(self, Vector2.ZERO, "@", 30, Color(KP.GREEN, 0.2))
		KP.draw_center(self, Vector2.ZERO, "@", 26, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
