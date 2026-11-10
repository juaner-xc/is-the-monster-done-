extends RefCounted
## Shared keyboard mapping, also safe when switching chapters in one session.
static func ensure() -> void:
	_bind(&"dodge", KEY_SHIFT)
	_bind(&"jump", KEY_SPACE)

static func _bind(action: StringName, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	# Replace legacy keyboard bindings while preserving non-keyboard controls.
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)
