class_name NoteSoundConfig
extends Resource

@export var sound: AudioStream
@export_range(-40.0, 0.0, 0.5) var volume_db := -12.0
@export var enabled_by_default := true
@export var demo_enabled := true
@export var input_enabled := true
@export var preview_enabled := true
@export var combine_simultaneous := true
@export_range(1, 16, 1) var polyphony := 8
