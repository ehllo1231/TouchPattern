class_name HitVibration
extends RefCounted

const PULSE_MS := 35

var strength_percent := 0.0:
	set(value):
		strength_percent = clampf(value, 0.0, 100.0) if is_finite(value) else 0.0


func play(event: InputEvent) -> void:
	if strength_percent <= 0.0:
		return
	var strength := strength_percent / 100.0
	if event is InputEventJoypadButton:
		_vibrate_gamepad(event.device, strength)
	elif event is InputEventScreenTouch and event.device != InputEvent.DEVICE_ID_EMULATION:
		_vibrate_handheld(strength)


func _vibrate_gamepad(device: int, strength: float) -> void:
	Input.start_joy_vibration(device, strength, strength, PULSE_MS / 1000.0)


func _vibrate_handheld(strength: float) -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(PULSE_MS, strength)
