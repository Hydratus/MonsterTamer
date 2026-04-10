extends RefCounted
class_name MTDebugLog

static func debug(enabled: bool, channel: String, message: String) -> void:
	if not enabled:
		return
	print("[%s] %s" % [channel, message])

static func warning(channel: String, message: String) -> void:
	push_warning("[%s] %s" % [channel, message])

static func error(channel: String, message: String) -> void:
	push_error("[%s] %s" % [channel, message])