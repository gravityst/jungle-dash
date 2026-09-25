extends Node
## FRAME-TIME SPIKES ON A LIVE TRACK.
##
## Measures every physics frame of a real run and reports the spikes, together
## with how far apart they are. The gap between spikes is the diagnosis: a
## piece is consumed every 30 m, which is 1.5 s at the 20 m/s cap, so spikes
## spaced like that are the recycle and spikes spaced otherwise are not.
##
## Deferred work is the reason this cannot be measured by timing randomise()
## itself — set_deferred("disabled", ...) and set_deferred("monitoring", ...)
## both land at the END of the frame, well after any timer around the call.
var _root: Node
var _last := 0
var _times := []
var _frame := 0


func _ready() -> void:
	_root = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_root)
	await get_tree().physics_frame
	await get_tree().physics_frame
	get_tree().current_scene = _root

	# DRIVE IT. Loaded with no input the runner dies within a few seconds and
	# every sample after that is of a stationary corpse on a track that never
	# recycles — 84% of this profiler's samples used to be exactly that, which
	# made it blind to the one thing it exists to find, the recycle spike.
	var bot: Node = load("res://tools/autopilot.gd").new()
	_root.add_child(bot)
	bot.setup(_root.get_node("Player"), _root.get_node("TrackManager"))

	_last = Time.get_ticks_usec()
	get_tree().physics_frame.connect(_tick)
	# What the frame actually COSTS, separately from when it happened to be
	# shown: physics-tick intervals on a 120 Hz display jitter by whole
	# refreshes whatever the load, so they cannot tell a slow frame from an
	# unlucky one. The renderer's own timers can.
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	get_tree().process_frame.connect(_render_tick)


var _gpu: Array[float] = []
var _cpu: Array[float] = []


var _render_frames := 0
var _render_start := 0


func _render_tick() -> void:
	if _frame <= 30:
		return
	if _render_frames == 0:
		_render_start = Time.get_ticks_usec()
	_render_frames += 1
	var rid := get_viewport().get_viewport_rid()
	_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid)
		+ RenderingServer.get_frame_setup_time_cpu())


func _pct(a: Array[float], p: float) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	return s[mini(int(s.size() * p), s.size() - 1)]


func _tick() -> void:
	var now := Time.get_ticks_usec()
	var dt := float(now - _last) / 1000.0
	_last = now
	_frame += 1
	if _frame > 30:
		_times.append(dt)
	if _times.size() < 2400:
		return
	get_tree().physics_frame.disconnect(_tick)
	_report()


func _report() -> void:
	var sorted := _times.duplicate()
	sorted.sort()
	var n := sorted.size()
	var median: float = sorted[n / 2]
	# A spike is anything well clear of the normal frame.
	var threshold: float = maxf(median * 2.5, median + 3.0)
	var spikes := []
	for i in _times.size():
		if _times[i] > threshold:
			spikes.append(i)

	print("===== LIVE FRAME TIMES (%d frames) =====" % n)
	print("  median %6.2f ms   p95 %6.2f ms   p99 %6.2f ms   worst %6.2f ms"
		% [median, sorted[int(n * 0.95)], sorted[int(n * 0.99)], sorted[n - 1]])
	print("  spikes over %.1f ms: %d" % [threshold, spikes.size()])
	print("  RENDER COST  gpu median %.2f  p95 %.2f  p99 %.2f ms   |   cpu median %.2f  p95 %.2f ms"
		% [_pct(_gpu, 0.5), _pct(_gpu, 0.95), _pct(_gpu, 0.99), _pct(_cpu, 0.5), _pct(_cpu, 0.95)])
	var secs := float(Time.get_ticks_usec() - _render_start) / 1e6
	print("  drawn frames per second: %.1f   (display refresh %.0f Hz)" % [
		float(_render_frames) / maxf(secs, 0.001), DisplayServer.screen_get_refresh_rate()])
	print("  draw calls this frame: %d   objects: %d   primitives: %d" % [
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	print("  ran %.0f m, still alive: %s" % [GameState.distance, GameState.is_running()])
	if not GameState.is_running():
		print("  *** the runner died — these numbers are of a stopped game ***")
	if spikes.size() >= 2:
		var gaps := []
		for i in range(1, spikes.size()):
			gaps.append(spikes[i] - spikes[i - 1])
		gaps.sort()
		var mid: int = gaps[gaps.size() / 2]
		print("  typical gap between spikes: %d frames (%.2f s)" % [mid, mid / 60.0])
		var worst_spike := 0.0
		for i in spikes:
			worst_spike = maxf(worst_spike, _times[i])
		print("  biggest spike: %.2f ms" % worst_spike)
	get_tree().quit()
