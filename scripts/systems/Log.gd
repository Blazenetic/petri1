extends Node

# Central logging singleton with categories and levels.
# Build-aware defaults; early-out to minimize overhead when disabled.

# Level enum (low &#45;> high)
const LEVEL_TRACE := 0
const LEVEL_DEBUG := 1
const LEVEL_INFO := 2
const LEVEL_WARN := 3
const LEVEL_ERROR := 4

# Categories
const CAT_CORE := &"core"
const CAT_SYSTEMS := &"systems"
const CAT_COMPONENTS := &"components"
const CAT_AI := &"ai"
const CAT_ENVIRONMENT := &"environment"
const CAT_UI := &"ui"
const CAT_PERF := &"perf"
const CAT_EVENTS := &"events"

var global_enabled: bool = true
var level_by_category: Dictionary = {}
var editor_defaults_applied: bool = false

# Rate limiting state for Log.every
var _every_last_time: Dictionary = {} # key -> seconds (float)

func _ready() -> void:
	# Initialize category thresholds with build-aware defaults.
	_apply_build_defaults()
	set_process_unhandled_key_input(true)

func set_global_enabled(enabled: bool) -> void:
	global_enabled = enabled

func is_global_enabled() -> bool:
	return global_enabled

func set_level(category: StringName, level: int) -> void:
	level_by_category[category] = int(clamp(level, LEVEL_TRACE, LEVEL_ERROR))

func get_level(category: StringName) -> int:
	return int(level_by_category.get(category, LEVEL_WARN))

func enabled(category: StringName, level: int) -> bool:
	if not global_enabled:
		return false
	var threshold: int = get_level(category)
	return int(level) >= threshold

func log(category: StringName, level: int, parts: Array) -> void:
	if not enabled(category, level):
		return
	_emit_formatted(category, level, parts)

func trace(category: StringName, parts: Array) -> void:
	if not enabled(category, LEVEL_TRACE):
		return
	_emit_formatted(category, LEVEL_TRACE, parts)

func debug(category: StringName, parts: Array) -> void:
	if not enabled(category, LEVEL_DEBUG):
		return
	_emit_formatted(category, LEVEL_DEBUG, parts)

func info(category: StringName, parts: Array) -> void:
	if not enabled(category, LEVEL_INFO):
		return
	_emit_formatted(category, LEVEL_INFO, parts)

func warn(category: StringName, parts: Array) -> void:
	if not enabled(category, LEVEL_WARN):
		return
	_emit_formatted(category, LEVEL_WARN, parts)

func error(category: StringName, parts: Array) -> void:
	if not enabled(category, LEVEL_ERROR):
		return
	_emit_formatted(category, LEVEL_ERROR, parts)

# Rate-limited logging; emits at most once per interval per key
func every(key: StringName, interval_sec: float, category: StringName, level: int, parts: Array) -> bool:
	if not enabled(category, level):
		return false
	var now_s: float = float(Time.get_ticks_msec()) / 1000.0
	var last_s: float = float(_every_last_time.get(key, -1.0))
	if last_s < 0.0 or (now_s - last_s) >= max(0.0, interval_sec):
		_every_last_time[key] = now_s
		_emit_formatted(category, level, parts)
		return true
	return false

func _emit_formatted(category: StringName, level: int, parts: Array) -> void:
	# Build message lazily; called only when enabled(category, level) is true.
	var level_name := _level_to_name(level)
	var frames: int = Engine.get_frames_drawn()
	var ms: int = Time.get_ticks_msec()
	var sb: Array = []
	sb.append("[" + String(category) + "]")
	sb.append(level_name)
	sb.append("frames=" + str(frames))
	sb.append("ms=" + str(ms))
	for p in parts:
		sb.append(str(p))
	var msg: String = " ".join(sb)
	_sink(level, msg)

func _sink(level: int, msg: String) -> void:
	match level:
		LEVEL_ERROR:
			push_error(msg)
		LEVEL_WARN:
			push_warning(msg)
		_:
			print(msg)

func _level_to_name(level: int) -> String:
	match level:
		LEVEL_TRACE:
			return "TRACE"
		LEVEL_DEBUG:
			return "DEBUG"
		LEVEL_INFO:
			return "INFO"
		LEVEL_WARN:
			return "WARN"
		LEVEL_ERROR:
			return "ERROR"
		_:
			return str(level)

func _apply_build_defaults() -> void:
	if editor_defaults_applied:
		return
	var dev_build: bool = Engine.is_editor_hint() or OS.is_debug_build()
	# Global toggle: on in editor/dev, warn+ only logging but still enabled in export to allow toggling at runtime
	global_enabled = dev_build
	# Thresholds
	if dev_build:
		set_level(CAT_CORE, LEVEL_INFO)
		set_level(CAT_SYSTEMS, LEVEL_INFO)
		set_level(CAT_PERF, LEVEL_DEBUG)
		set_level(CAT_COMPONENTS, LEVEL_WARN)
		set_level(CAT_AI, LEVEL_WARN)
		set_level(CAT_ENVIRONMENT, LEVEL_WARN)
		set_level(CAT_UI, LEVEL_WARN)
		set_level(CAT_EVENTS, LEVEL_WARN)
	else:
		# Release: warn+ for all categories
		set_level(CAT_CORE, LEVEL_WARN)
		set_level(CAT_SYSTEMS, LEVEL_WARN)
		set_level(CAT_PERF, LEVEL_WARN)
		set_level(CAT_COMPONENTS, LEVEL_WARN)
		set_level(CAT_AI, LEVEL_WARN)
		set_level(CAT_ENVIRONMENT, LEVEL_WARN)
		set_level(CAT_UI, LEVEL_WARN)
		set_level(CAT_EVENTS, LEVEL_WARN)
	editor_defaults_applied = true

func _unhandled_key_input(event: InputEvent) -> void:
	# Crisp, non-intrusive handling: only process non-echo key press events,
	# rely strictly on InputMap actions, and do not swallow input for others.
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if event.is_action_pressed(&"debug_toggle_global"):
		global_enabled = not global_enabled
		print("[Log] global_enabled=", global_enabled)
	elif event.is_action_pressed(&"debug_cycle_perf"):
		_cycle_perf_level()

func _cycle_perf_level() -> void:
	var cur: int = get_level(CAT_PERF)
	var next: int = LEVEL_DEBUG
	match cur:
		LEVEL_DEBUG:
			next = LEVEL_INFO
		LEVEL_INFO:
			next = LEVEL_WARN
		LEVEL_WARN:
			next = LEVEL_ERROR
		LEVEL_ERROR:
			next = LEVEL_DEBUG
		_:
			next = LEVEL_DEBUG
	set_level(CAT_PERF, next)
	# Announce change regardless of thresholds
	print("[Log] perf threshold -> ", _level_to_name(next))