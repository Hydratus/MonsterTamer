extends RefCounted
class_name MTStatusAilment

enum Type {
	NONE,
	BURN,
	WET,
	POISON,
	BLEED,
	BLIND,
	DAZE,
	SILENCE,
	ROOT,
	BIND,
	SLEEP,
	FREEZE,
	PARALYZE,
	FEAR,
	STAGGER,
	CURSED,
	CLEANSE
}

static func from_key(raw_key: String) -> int:
	var key := raw_key.strip_edges().to_lower()
	match key:
		"", "none":
			return Type.NONE
		"burn":
			return Type.BURN
		"wet":
			return Type.WET
		"poison":
			return Type.POISON
		"bleed":
			return Type.BLEED
		"blind":
			return Type.BLIND
		"daze":
			return Type.DAZE
		"silence":
			return Type.SILENCE
		"root":
			return Type.ROOT
		"bind":
			return Type.BIND
		"sleep":
			return Type.SLEEP
		"freeze", "frozen":
			return Type.FREEZE
		"paralyze", "paralysis":
			return Type.PARALYZE
		"fear":
			return Type.FEAR
		"stagger":
			return Type.STAGGER
		"curse", "cursed":
			return Type.CURSED
		"cleanse":
			return Type.CLEANSE
		_:
			return Type.NONE

static func to_key(status_type: int) -> String:
	match status_type:
		Type.BURN:
			return "burn"
		Type.WET:
			return "wet"
		Type.POISON:
			return "poison"
		Type.BLEED:
			return "bleed"
		Type.BLIND:
			return "blind"
		Type.DAZE:
			return "daze"
		Type.SILENCE:
			return "silence"
		Type.ROOT:
			return "root"
		Type.BIND:
			return "bind"
		Type.SLEEP:
			return "sleep"
		Type.FREEZE:
			return "freeze"
		Type.PARALYZE:
			return "paralyze"
		Type.FEAR:
			return "fear"
		Type.STAGGER:
			return "stagger"
		Type.CURSED:
			return "cursed"
		Type.CLEANSE:
			return "cleanse"
		_:
			return "none"

static func display_name(status_type: int) -> String:
	return TranslationServer.translate(to_key(status_type).capitalize())

static func default_duration(status_type: int) -> int:
	match status_type:
		Type.BURN, Type.WET, Type.POISON, Type.BLEED, Type.BLIND, Type.DAZE, Type.SILENCE, Type.ROOT, Type.BIND, Type.PARALYZE, Type.FEAR:
			return 3
		Type.SLEEP, Type.FREEZE, Type.STAGGER:
			return 1
		Type.CURSED:
			return 4
		_:
			return 0

static func is_persistent(status_type: int) -> bool:
	return status_type != Type.NONE and status_type != Type.CLEANSE
