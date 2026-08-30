extends Node2D
## KERNEL PANIC — DOOM 终端割草生存（二次元北京篇）
## 主编排：状态机 / 刷怪导演 / 碰撞判定 / 武器与升级 / 事件系统 / 背景绘制
## 灵感：DOOM · kubedoom · Vampire Survivors · Brotato · particle-life
##       edex-ui · osu · pyxel · 2048 · terminaltexteffects
## 数值调参见 game_config.gd，设计文档见 docs/GDD.md

enum State { TITLE, PLAYING, PAUSED, LEVELUP, GAMEOVER }

const ARENA_W := GameConfig.ARENA_W
const ARENA_H := GameConfig.ARENA_H
const MAX_ENEMIES := GameConfig.MAX_ENEMIES

## 升级池：kind = weapon（占武器槽）/ passive；max = 等级上限
const UPGRADES := [
	{"id": "wrench", "kind": "weapon", "name": "高频扳手", "desc": "自动射击强化：射速 +12% 伤害 +4", "max": 5},
	{"id": "orbit", "kind": "weapon", "name": "回旋扳手", "desc": "获得环绕护体的旋转扳手，+1 数量", "max": 4},
	{"id": "thunder", "kind": "weapon", "name": "引雷术", "desc": "周期天雷轰击，链式跳跃", "max": 4},
	{"id": "rate", "kind": "passive", "name": "超频射击", "desc": "射击间隔 -10%", "max": 5},
	{"id": "dmg", "kind": "passive", "name": "攻击强化", "desc": "子弹伤害 +20%", "max": 5},
	{"id": "multi", "kind": "passive", "name": "进程分叉", "desc": "弹道 +1", "max": 3},
	{"id": "pierce", "kind": "passive", "name": "穿透补丁", "desc": "子弹穿透 +1", "max": 4},
	{"id": "speed", "kind": "passive", "name": "低延迟移动", "desc": "移动速度 +12%", "max": 5},
	{"id": "hp", "kind": "passive", "name": "内存扩容", "desc": "最大HP +20，立即恢复30%", "max": 5},
	{"id": "magnet", "kind": "passive", "name": "抓包范围", "desc": "经验磁吸 +40%", "max": 4},
	{"id": "armor", "kind": "passive", "name": "防火墙", "desc": "受到伤害 -15%", "max": 3},
	{"id": "xpgain", "kind": "passive", "name": "数据挖掘", "desc": "经验获取 +18%", "max": 3},
]

var state: int = State.TITLE
var elapsed := 0.0
var wave := 0
var kills := 0
var level := 1
var xp := 0
var xp_next := GameConfig.XP_FIRST_LEVEL
var _last_second := -1

var spawn_cd := 1.0
var wave_cd := 10.0
var elite_cd := 60.0
var swarm_idx := 0
var boss_spawned := false
var boss_ref = null
var elite_ref = null

var player = null
var camera: Camera2D
var hud
var fx_node: Node2D
var enemies_node: Node2D
var bullets_node: Node2D
var gems_node: Node2D
var props_node: Node2D

var shake := 0.0
var decor: Array = []
var spatial_grid := {}

func _build_grid() -> void:
	spatial_grid.clear()
	for e in enemies_node.get_children():
		if not is_instance_valid(e) or e.dead:
			continue
		var key := Vector2i(floori(e.global_position.x / GameConfig.GRID_CELL), floori(e.global_position.y / GameConfig.GRID_CELL))
		if spatial_grid.has(key):
			spatial_grid[key].append(e)
		else:
			spatial_grid[key] = [e]

func grid_neighbors(pos: Vector2, reach: float) -> Array:
	## 返回 pos 周围 reach 范围覆盖到的网格桶里的敌人（近似邻域，够用于分离/碰撞）
	var out: Array = []
	var r := int(ceili(reach / GameConfig.GRID_CELL))
	var cx := floori(pos.x / GameConfig.GRID_CELL)
	var cy := floori(pos.y / GameConfig.GRID_CELL)
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			var arr: Array = spatial_grid.get(Vector2i(cx + dx, cy + dy), [])
			out.append_array(arr)
	return out

func _ready() -> void:
	randomize()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	gems_node = Node2D.new()
	gems_node.z_index = 1
	add_child(gems_node)
	bullets_node = Node2D.new()
	bullets_node.z_index = 2
	add_child(bullets_node)
	enemies_node = Node2D.new()
	enemies_node.z_index = 3
	add_child(enemies_node)
	props_node = Node2D.new()
	props_node.z_index = 1
	add_child(props_node)
	fx_node = Node2D.new()
	fx_node.z_index = 5
	add_child(fx_node)

	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()

	hud = load("res://scripts/hud.gd").new()
	add_child(hud)
	hud.upgrade_chosen.connect(_on_upgrade_chosen)
	hud.menu_start.connect(_start_game)
	hud.menu_quit_app.connect(func(): get_tree().quit())
	hud.pause_requested.connect(_pause_game)
	hud.resume_requested.connect(_resume_game)
	hud.pause_to_title.connect(_to_title)
	hud.restart_requested.connect(_restart)

	for i in 90:
		decor.append([Vector2(randf_range(-ARENA_W, ARENA_W), randf_range(-ARENA_H, ARENA_H)),
				["░", "▒", "·", "▪"][randi() % 4], randf_range(0.04, 0.12)])

	hud.show_world(false)

	if OS.get_environment("KP_AUTOTEST") == "1":
		Engine.max_fps = 60
		_autotest()

# ---------------- 主循环 ----------------

func _process(delta: float) -> void:
	if player != null and state != State.TITLE:
		camera.position = camera.position.lerp(player.position, minf(1.0, delta * GameConfig.CAMERA_SMOOTHING))
	shake = maxf(shake - delta * 14.0, 0.0)
	if shake > 0.05:
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake
	else:
		camera.offset = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if state != State.PLAYING or player == null:
		return
	_build_grid()
	_director(delta)
	_collisions()
	var s := int(elapsed)
	if s != _last_second:
		_last_second = s
		hud.set_wave(wave + 1, elapsed)

# ---------------- 刷怪导演 ----------------

func _director(delta: float) -> void:
	elapsed += delta
	spawn_cd -= delta
	wave_cd -= delta
	elite_cd -= delta
	var interval: float = maxf(GameConfig.SPAWN_INTERVAL_MIN, GameConfig.SPAWN_INTERVAL_BASE - elapsed * GameConfig.SPAWN_INTERVAL_DECAY)
	if spawn_cd <= 0.0 and enemies_node.get_child_count() < MAX_ENEMIES:
		spawn_cd = interval
		_spawn_enemy(_pick_type())
	if wave_cd <= 0.0:
		wave_cd = GameConfig.WAVE_PERIOD
		wave += 1
		hud.banner("WAVE %d — TRAFFIC SPIKE" % (wave + 1))
		Sfx.play("wave")
		for i in GameConfig.WAVE_BURST_BASE + wave * GameConfig.WAVE_BURST_PER_WAVE:
			if enemies_node.get_child_count() < MAX_ENEMIES:
				_spawn_enemy(_pick_type())
	if elite_cd <= 0.0:
		elite_cd = GameConfig.ELITE_PERIOD
		_spawn_enemy("elite")
		elite_ref = enemies_node.get_children().back()
		hud.set_boss("ELITE 进程", 1.0)
		hud.banner("! ELITE PROCESS DETECTED !")
	_spawn_events()

func _spawn_events() -> void:
	## 包围圈事件
	if swarm_idx < GameConfig.SWARM_TIMES.size() and elapsed >= GameConfig.SWARM_TIMES[swarm_idx]:
		swarm_idx += 1
		hud.banner("!! 包围网警报 — 环形攻势 !!")
		Sfx.play("wave")
		for i in GameConfig.SWARM_COUNT:
			var ang := TAU * float(i) / float(GameConfig.SWARM_COUNT)
			var pos: Vector2 = player.position + Vector2.from_angle(ang) * GameConfig.SWARM_RADIUS
			pos.x = clampf(pos.x, -ARENA_W + 40.0, ARENA_W - 40.0)
			pos.y = clampf(pos.y, -ARENA_H + 40.0, ARENA_H - 40.0)
			var e = load("res://scripts/enemy.gd").new()
			e.setup(self, "runner", (1.0 + elapsed / GameConfig.HP_GROWTH_TIME_DIV) * (1.0 + wave * GameConfig.HP_GROWTH_WAVE))
			e.position = pos
			enemies_node.add_child(e)
			e.reset_physics_interpolation()
	## 五分钟 Boss
	if not boss_spawned and elapsed >= GameConfig.BOSS_AT:
		boss_spawned = true
		var b = load("res://scripts/enemy.gd").new()
		b.setup(self, "elite", (1.0 + elapsed / GameConfig.HP_GROWTH_TIME_DIV) * (1.0 + wave * GameConfig.HP_GROWTH_WAVE) * GameConfig.BOSS_HP_MULT)
		b.radius *= GameConfig.BOSS_SCALE
		b.size = int(b.size * 1.5)
		b.speed *= GameConfig.BOSS_SPEED_MULT
		b.is_boss = true
		var bpos: Vector2 = player.position + Vector2.from_angle(randf() * TAU) * 700.0
		bpos.x = clampf(bpos.x, -ARENA_W + 40.0, ARENA_W - 40.0)
		bpos.y = clampf(bpos.y, -ARENA_H + 40.0, ARENA_H - 40.0)
		b.position = bpos
		enemies_node.add_child(b)
		b.reset_physics_interpolation()
		boss_ref = b
		hud.set_boss("巨型进程王", 1.0)
		hud.banner("!! BOSS : 巨型进程王 !!")
		Sfx.play("gameover")

func _pick_type() -> String:
	var r := randf()
	if elapsed < GameConfig.RUNNER_UNLOCK_AT:
		return "glitch"
	if elapsed < GameConfig.TANK_UNLOCK_AT:
		return "runner" if r < GameConfig.RUNNER_WEIGHT_MID else "glitch"
	if r < GameConfig.RUNNER_WEIGHT_LATE:
		return "runner"
	if r < GameConfig.RUNNER_WEIGHT_LATE + GameConfig.TANK_WEIGHT_LATE:
		return "tank"
	return "glitch"

func _spawn_enemy(type: String, near_player := false) -> void:
	var e = load("res://scripts/enemy.gd").new()
	e.setup(self, type, (1.0 + elapsed / GameConfig.HP_GROWTH_TIME_DIV) * (1.0 + wave * GameConfig.HP_GROWTH_WAVE))
	var ang := randf() * TAU
	var dist := randf_range(150.0, 300.0) if near_player else randf_range(680.0, 820.0)
	var pos: Vector2 = (player.position if player != null else Vector2.ZERO) + Vector2.from_angle(ang) * dist
	pos.x = clampf(pos.x, -ARENA_W + 40.0, ARENA_W - 40.0)
	pos.y = clampf(pos.y, -ARENA_H + 40.0, ARENA_H - 40.0)
	e.position = pos
	enemies_node.add_child(e)
	e.reset_physics_interpolation()

# ---------------- 碰撞判定 ----------------

func _collisions() -> void:
	var enemies := enemies_node.get_children()
	## 子弹 × 敌人（网格邻域查询）
	for b in bullets_node.get_children():
		if not is_instance_valid(b):
			continue
		var near: Array = grid_neighbors(b.global_position, 48.0)
		for e in near:
			if not is_instance_valid(e) or e.dead:
				continue
			var rr: float = e.radius + 6.0
			if b.global_position.distance_squared_to(e.global_position) <= rr * rr:
				e.hit(b.damage)
				b.pierce -= 1
				Sfx.play("hit")
				if b.pierce <= 0:
					b.queue_free()
					break
	## 子弹 × 可破坏物
	for b in bullets_node.get_children():
		if not is_instance_valid(b):
			continue
		for pr in props_node.get_children():
			if not is_instance_valid(pr) or pr.dead:
				continue
			var rp: float = pr.radius + 6.0
			if b.global_position.distance_squared_to(pr.global_position) <= rp * rp:
				pr.hit(b.damage)
				b.pierce -= 1
				Sfx.play("hit")
				if b.pierce <= 0:
					b.queue_free()
					break
	## 回旋扳手 × 敌人（持续伤害，按敌冷却）
	if player.orbit_count > 0:
		for i in player.orbit_count:
			var op: Vector2 = player.global_position + Vector2.from_angle(player.orbit_angle + float(i) * TAU / float(player.orbit_count)) * GameConfig.ORBIT_RADIUS
			var near_o: Array = grid_neighbors(op, 42.0)
			for e in near_o:
				if not is_instance_valid(e) or e.dead or e.orbit_cd > 0.0:
					continue
				var ro: float = e.radius + 10.0
				if op.distance_squared_to(e.global_position) <= ro * ro:
					e.hit(player.orbit_dmg)
					e.orbit_cd = GameConfig.ORBIT_HIT_CD
	## 敌人 × 玩家（网格邻域查询）
	if player.iframes <= 0.0:
		var near_p: Array = grid_neighbors(player.global_position, 48.0)
		for e in near_p:
			if not is_instance_valid(e) or e.dead:
				continue
			var rr2: float = e.radius + 11.0
			if e.global_position.distance_squared_to(player.global_position) <= rr2 * rr2:
				player.take_damage(e.dmg)
				break

# ---------------- 击杀 / 掉落 / 拾取 ----------------

func kill_enemy(e) -> void:
	kills += 1
	hud.set_kills(kills)
	hud.log_line("> kill -9 PID %d [%s] — terminated" % [e.pid, e.gtype.to_upper()])
	fx_text(e.global_position, "PID %d down" % e.pid, e.color, 15)
	fx_ring(e.global_position, e.color, e.radius * 0.5, e.radius * 2.2)
	for i in 4:
		fx_shard(e.global_position, e.color)
	if e.gtype == "elite" or e.gtype == "tank":
		shake = maxf(shake, GameConfig.SHAKE_ON_HEAVY_KILL)
	_spawn_xp_gem(e.global_position, e.xp_value)
	## 概率补给
	var roll := randf()
	if roll < GameConfig.HEAL_DROP_CHANCE:
		_spawn_pickup(e.global_position, "heal")
	elif roll < GameConfig.HEAL_DROP_CHANCE + GameConfig.MAGNET_DROP_CHANCE:
		_spawn_pickup(e.global_position, "magnet")
	## 精英 / Boss 奖励
	if e == elite_ref:
		elite_ref = null
		hud.hide_boss()
		if GameConfig.ELITE_CHEST:
			_spawn_pickup(e.global_position, "chest")
	if e == boss_ref:
		boss_ref = null
		hud.hide_boss()
		for i in GameConfig.BOSS_DROP_CHEST:
			_spawn_pickup(e.global_position + Vector2(randf_range(-50.0, 50.0), randf_range(-50.0, 50.0)), "chest")
		_spawn_pickup(e.global_position, "heal")
		hud.banner("BOSS 击破 — 系统奖励已投递")
	Sfx.play("kill")
	e.dead = true
	e.queue_free()

func _spawn_xp_gem(pos: Vector2, value: int) -> void:
	var g = load("res://scripts/gem.gd").new()
	g.setup(self, pos + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0)), value)
	gems_node.add_child(g)
	g.reset_physics_interpolation()

func _spawn_pickup(pos: Vector2, kind: String) -> void:
	var g = load("res://scripts/gem.gd").new()
	g.setup(self, pos, 1, kind)
	gems_node.add_child(g)
	g.reset_physics_interpolation()

func collect_pickup(g) -> void:
	match g.kind:
		"xp":
			add_xp(int(round(g.value * player.xp_mult)))
			Sfx.play("pickup")
		"heal":
			player.heal(GameConfig.HEAL_AMOUNT)
			hud.set_hp(player.hp, player.max_hp)
			hud.set_low_hp(player.hp / player.max_hp < GameConfig.LOW_HP_THRESHOLD)
			fx_text(g.global_position, "+%d HP" % int(GameConfig.HEAL_AMOUNT), KP.JADE, 15)
			Sfx.play("pickup")
		"magnet":
			for gm in gems_node.get_children():
				if is_instance_valid(gm):
					gm.force_magnet()
			fx_text(g.global_position, "全场抓包!", KP.CYAN, 16)
			Sfx.play("levelup")
		"chest":
			hud.banner("宝箱开启 — 免费升级!")
			Sfx.play("levelup")
			_trigger_levelup()

func break_breakable(b) -> void:
	for i in 3:
		fx_shard(b.global_position, Color(1.0, 0.6, 0.3) if b.kind == "lantern" else KP.JADE)
	var roll := randf()
	if roll < 0.5:
		_spawn_xp_gem(b.global_position, 1)
	elif roll < 0.8:
		_spawn_xp_gem(b.global_position, 2)
	else:
		_spawn_pickup(b.global_position, "heal")
	Sfx.play("kill")

# ---------------- 经验 / 升级 / 武器 ----------------

func add_xp(v: int) -> void:
	xp += v
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		xp_next = GameConfig.XP_FLAT + level * GameConfig.XP_PER_LEVEL
		_trigger_levelup()
	hud.set_xp(level, xp, xp_next)

func _trigger_levelup() -> void:
	state = State.LEVELUP
	get_tree().paused = true
	var cards := _roll_upgrades(3)
	if cards.is_empty():
		player.heal(9999.0)
		hud.set_hp(player.hp, player.max_hp)
		state = State.PLAYING
		get_tree().paused = false
		return
	hud.show_levelup(cards, level)

func _roll_upgrades(count: int) -> Array:
	var pool := []
	var owned_weapons := 0
	for u in UPGRADES:
		if u["kind"] == "weapon" and player.upgrade_levels.get(u["id"], 0) > 0:
			owned_weapons += 1
	for u in UPGRADES:
		var lv: int = player.upgrade_levels.get(u["id"], 0)
		if lv >= u["max"]:
			continue
		if u["kind"] == "weapon" and lv == 0 and owned_weapons >= GameConfig.WEAPON_SLOTS:
			continue
		pool.append(u)
	pool.shuffle()
	var picks := []
	for u in pool:
		if picks.size() >= count:
			break
		picks.append(u)
	var cards := []
	for u in picks:
		var r := randf()
		var rarity := "common"
		var times := 1
		if r < GameConfig.EPIC_CHANCE:
			rarity = "epic"
			times = 3
		elif r < GameConfig.EPIC_CHANCE + GameConfig.RARE_CHANCE:
			rarity = "rare"
			times = 2
		times = mini(times, u["max"] - player.upgrade_levels.get(u["id"], 0))
		var lv_now: int = player.upgrade_levels.get(u["id"], 0)
		var desc: String = u["desc"]
		if times > 1:
			desc += "　★ ×%d" % times
		cards.append({"id": u["id"], "name": u["name"], "desc": desc, "times": times,
				"rarity": rarity, "lv_now": lv_now, "lv_next": lv_now + times})
	return cards

func _on_upgrade_chosen(card: Dictionary) -> void:
	if state != State.LEVELUP:
		return
	state = State.PLAYING
	get_tree().paused = false
	hud.hide_levelup()
	var times: int = card.get("times", 1)
	for t in times:
		player.upgrade_levels[card["id"]] = player.upgrade_levels.get(card["id"], 0) + 1
		_apply_upgrade(card["id"])
	hud.set_hp(player.hp, player.max_hp)
	hud.set_low_hp(player.hp / player.max_hp < GameConfig.LOW_HP_THRESHOLD)
	Sfx.play("levelup")

func _apply_upgrade(id: String) -> void:
	match id:
		"wrench":
			player.fire_interval = maxf(GameConfig.FIRE_INTERVAL_MIN, player.fire_interval * 0.88)
			player.damage += 4.0
		"orbit":
			player.orbit_count = mini(4, player.orbit_count + 1)
			player.orbit_dmg += 4.0
		"thunder":
			if player.thunder_interval <= 0.0:
				player.thunder_interval = GameConfig.THUNDER_INTERVAL
			else:
				player.thunder_interval *= 0.85
				player.thunder_chain += 1
		"rate":
			player.fire_interval = maxf(GameConfig.FIRE_INTERVAL_MIN, player.fire_interval * 0.90)
		"dmg":
			player.damage *= 1.2
		"multi":
			player.multishot = mini(GameConfig.MULTISHOT_MAX, player.multishot + 1)
		"pierce":
			player.pierce = mini(GameConfig.PIERCE_MAX, player.pierce + 1)
		"speed":
			player.move_speed = minf(GameConfig.MOVE_SPEED_MAX, player.move_speed * 1.12)
		"hp":
			player.max_hp += 20.0
			player.heal(player.max_hp * 0.3)
		"magnet":
			player.magnet = minf(GameConfig.MAGNET_MAX, player.magnet * 1.4)
		"armor":
			player.armor_lv += 1
		"xpgain":
			player.xp_mult += 0.18

func cast_thunder() -> void:
	var pool := []
	for e in enemies_node.get_children():
		if is_instance_valid(e) and not e.dead and player.global_position.distance_squared_to(e.global_position) <= GameConfig.THUNDER_RANGE * GameConfig.THUNDER_RANGE:
			pool.append(e)
	if pool.is_empty():
		return
	var first = pool.pick_random()
	var hit_set: Array = [first]
	var cur = first
	for c in player.thunder_chain:
		var best = null
		var best_d := GameConfig.THUNDER_CHAIN_RANGE * GameConfig.THUNDER_CHAIN_RANGE
		for e in pool:
			if not is_instance_valid(e) or e.dead or e in hit_set:
				continue
			var d2: float = cur.global_position.distance_squared_to(e.global_position)
			if d2 < best_d:
				best_d = d2
				best = e
		if best == null:
			break
		hit_set.append(best)
		cur = best
	var dmg: float = player.thunder_dmg
	for e in hit_set:
		fx_line(e.global_position + Vector2(0.0, -420.0), e.global_position, Color(0.65, 0.95, 1.0))
		fx_ring(e.global_position, Color(0.7, 0.95, 1.0), 6.0, 30.0)
		if is_instance_valid(e) and not e.dead:
			e.hit(dmg)
		dmg *= 0.8
	Sfx.play("hit")
	shake = maxf(shake, 3.0)

func update_boss_bar(e) -> void:
	if e == boss_ref:
		hud.set_boss("巨型进程王", clampf(e.hp / e.max_hp, 0.0, 1.0))
	elif e == elite_ref:
		hud.set_boss("ELITE 进程", clampf(e.hp / e.max_hp, 0.0, 1.0))

func build_summary() -> Array:
	var lines: Array = []
	for u in UPGRADES:
		var lv: int = player.upgrade_levels.get(u["id"], 0)
		if lv > 0:
			lines.append("%s Lv.%d" % [u["name"], lv])
	if lines.is_empty():
		lines.append("（还没有补丁）")
	return lines

func on_player_hit() -> void:
	shake = maxf(shake, GameConfig.SHAKE_ON_HIT)
	hud.set_hp(player.hp, player.max_hp)
	hud.set_low_hp(player.hp / player.max_hp < GameConfig.LOW_HP_THRESHOLD)
	hud.flash_damage()
	Sfx.play("hurt")

# ---------------- 特效 ----------------

func fx_text(p: Vector2, t: String, c: Color, s: int) -> void:
	if fx_node.get_child_count() < 48:
		var f = load("res://scripts/fx.gd").new()
		f.setup_text(p, t, c, s)
		fx_node.add_child(f)

func fx_shard(p: Vector2, c: Color) -> void:
	var f = load("res://scripts/fx.gd").new()
	f.setup_shard(p, c)
	fx_node.add_child(f)

func fx_ring(p: Vector2, c: Color, r0: float, r1: float) -> void:
	var f = load("res://scripts/fx.gd").new()
	f.setup_ring(p, c, r0, r1)
	fx_node.add_child(f)

func fx_line(a: Vector2, b: Vector2, c: Color) -> void:
	var f = load("res://scripts/fx.gd").new()
	f.setup_line(a, b, c)
	fx_node.add_child(f)

func fx_dust(p: Vector2) -> void:
	var f = load("res://scripts/fx.gd").new()
	f.setup_dust(p)
	fx_node.add_child(f)

# ---------------- 状态切换 ----------------

func _start_game() -> void:
	_clear_entities()
	hud.hide_menu()
	hud.hide_pause()
	hud.hide_gameover()
	hud.show_world(true)
	hud.reset_hud()
	kills = 0
	level = 1
	xp = 0
	xp_next = GameConfig.XP_FIRST_LEVEL
	elapsed = 0.0
	wave = 0
	_last_second = -1
	spawn_cd = 0.6
	wave_cd = 20.0
	elite_cd = 60.0
	swarm_idx = 0
	boss_spawned = false
	boss_ref = null
	elite_ref = null
	shake = 0.0
	player = load("res://scripts/player.gd").new()
	player.main = self
	player.z_index = 4
	player.position = Vector2.ZERO
	add_child(player)
	player.reset_physics_interpolation()
	camera.position = Vector2.ZERO
	## 可破坏物：街道灯笼 + 服务器机柜
	for i in GameConfig.BREAKABLE_COUNT:
		var b = load("res://scripts/breakable.gd").new()
		var bpos := Vector2(randf_range(-ARENA_W + 90.0, ARENA_W - 90.0), randf_range(-ARENA_H + 90.0, ARENA_H - 90.0))
		if bpos.length() < 260.0:
			bpos = bpos.normalized() * 320.0
		b.setup(self, bpos, "lantern" if i % 3 != 0 else "server")
		props_node.add_child(b)
		b.reset_physics_interpolation()
	state = State.PLAYING
	hud.set_hp(player.hp, player.max_hp)
	hud.set_xp(level, xp, xp_next)
	hud.set_kills(0)
	hud.set_wave(1, 0.0)
	hud.set_low_hp(false)
	hud.hide_boss()
	hud.log_line("> ./kernel_panic.exe --map=beijing --style=anime")
	hud.log_line("> map loaded: 北京 · BEIJING SECTOR — survive.")
	Sfx.play("levelup")

func game_over() -> void:
	if state == State.GAMEOVER:
		return
	state = State.GAMEOVER
	get_tree().paused = true
	hud.show_world(false)
	hud.show_gameover(elapsed, wave + 1, kills, level, build_summary())
	Sfx.play("gameover")

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _pause_game() -> void:
	if state != State.PLAYING:
		return
	state = State.PAUSED
	get_tree().paused = true
	hud.show_pause(build_summary())

func _resume_game() -> void:
	if state != State.PAUSED:
		return
	state = State.PLAYING
	get_tree().paused = false
	hud.hide_pause()

func _to_title() -> void:
	get_tree().paused = false
	_clear_entities()
	state = State.TITLE
	hud.show_menu()
	hud.show_world(false)
	hud.hide_gameover()
	hud.hide_pause()

func _clear_entities() -> void:
	for n in [enemies_node, bullets_node, gems_node, props_node, fx_node]:
		for c in n.get_children():
			c.queue_free()
	if player != null:
		player.queue_free()
		player = null

# ---------------- 背景 ----------------

func _draw() -> void:
	var map_bg := KP.tex("arena_bg")
	if map_bg != null:
		draw_texture_rect(map_bg, Rect2(-ARENA_W, -ARENA_H, ARENA_W * 2.0, ARENA_H * 2.0), false)
	var col := Color(0.15, 0.5, 0.28, 0.06)
	var x := -ARENA_W
	while x <= ARENA_W:
		draw_line(Vector2(x, -ARENA_H), Vector2(x, ARENA_H), col, 1.0)
		x += 75.0
	var y := -ARENA_H
	while y <= ARENA_H:
		draw_line(Vector2(-ARENA_W, y), Vector2(ARENA_W, y), col, 1.0)
		y += 75.0
	draw_rect(Rect2(-ARENA_W, -ARENA_H, ARENA_W * 2.0, ARENA_H * 2.0), KP.GOLD, false, 2.0)
	for d in decor:
		KP.draw_center(self, d[0], d[1], 16, Color(0.2, 0.8, 0.4, d[2] * 0.6))
	KP.draw_center(self, Vector2(-ARENA_W + 170.0, -ARENA_H + 26.0), "MAP: 北京 · BEIJING SECTOR  ·  host: prod-node-07", 14, KP.GOLD)

# ---------------- 自动化测试（KP_AUTOTEST=1）----------------

func _autotest() -> void:
	print("[AUTOTEST] begin")
	await get_tree().create_timer(0.4).timeout
	print("[AUTOTEST] start_game")
	_start_game()
	await get_tree().create_timer(0.5).timeout
	print("[AUTOTEST] spawn burst near player")
	for i in 25:
		_spawn_enemy("glitch" if i % 3 != 0 else "tank", true)
	await get_tree().create_timer(1.0).timeout
	print("[AUTOTEST] trigger levelup")
	_trigger_levelup()
	await get_tree().create_timer(0.4).timeout
	print("[AUTOTEST] pick random upgrade")
	hud.pick_random_upgrade()
	await get_tree().create_timer(0.3).timeout
	print("[AUTOTEST] grant weapons + breakable + boss")
	_apply_upgrade("orbit")
	_apply_upgrade("orbit")
	_apply_upgrade("thunder")
	_apply_upgrade("xpgain")
	var brk = load("res://scripts/breakable.gd").new()
	brk.setup(self, player.global_position + Vector2(70.0, 0.0), "lantern")
	props_node.add_child(brk)
	elapsed = GameConfig.BOSS_AT
	_spawn_events()
	await get_tree().create_timer(1.2).timeout
	print("[AUTOTEST] game_over")
	game_over()
	await get_tree().create_timer(0.5).timeout
	print("[AUTOTEST] restart")
	_restart()
	print("[AUTOTEST] done")
