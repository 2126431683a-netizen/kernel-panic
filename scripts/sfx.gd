extends Node
## 自动加载：纯代码合成的 8-bit 音效，无外部资源

var streams := {}
var pool: Array = []
var pool_i := 0
var last := {}

func _ready() -> void:
	streams["shoot"] = _tone(900.0, 480.0, 0.05, 0.22)
	streams["hit"] = _noise(0.035, 0.28)
	streams["kill"] = _tone(320.0, 70.0, 0.09, 0.4)
	streams["pickup"] = _tone(620.0, 1250.0, 0.05, 0.26)
	streams["hurt"] = _noise(0.14, 0.5)
	streams["levelup"] = _tone(440.0, 880.0, 0.16, 0.32)
	streams["gameover"] = _tone(240.0, 40.0, 0.7, 0.5)
	streams["wave"] = _tone(180.0, 360.0, 0.12, 0.36)
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		pool.append(p)

func play(name: String, volume_db := 0.0) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var min_gap := 0.055 if name == "shoot" else 0.045
	if last.has(name) and now - last[name] < min_gap:
		return
	last[name] = now
	var p: AudioStreamPlayer = pool[pool_i]
	pool_i = (pool_i + 1) % pool.size()
	p.stream = streams[name]
	p.pitch_scale = randf_range(0.94, 1.08)
	p.volume_db = volume_db - 8.0
	p.play()

func _tone(f0: float, f1: float, dur: float, vol: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(dur * rate)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var phase := 0.0
	for i in n:
		var k := float(i) / float(n)
		var f := lerpf(f0, f1, k)
		phase += f / float(rate)
		var s := signf(sin(phase * TAU)) * vol * (1.0 - k * 0.6)
		var v := int(clampf(s, -1.0, 1.0) * 32000.0)
		bytes[i * 2] = v & 0xFF
		bytes[i * 2 + 1] = (v >> 8) & 0xFF
	return _to_wav(bytes, rate)

func _noise(dur: float, vol: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(dur * rate)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var k := float(i) / float(n)
		var s := (randf() * 2.0 - 1.0) * vol * (1.0 - k)
		var v := int(clampf(s, -1.0, 1.0) * 32000.0)
		bytes[i * 2] = v & 0xFF
		bytes[i * 2 + 1] = (v >> 8) & 0xFF
	return _to_wav(bytes, rate)

func _to_wav(bytes: PackedByteArray, rate: int) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	return w
