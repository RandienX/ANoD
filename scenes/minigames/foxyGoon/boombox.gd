extends Sprite2D

# Spectrum analysis variables
var spectrum: AudioEffectSpectrumAnalyzerInstance
const MIN_FREQ = 20.0
const MAX_FREQ = 2000.0

# Amplitude effect settings
@export var base_scale: Vector2 = Vector2(0.9, 0.9)
@export var scale_multiplier: float = 0.3

func _ready() -> void:
	var bus_idx = AudioServer.get_bus_index("Music")
	print(bus_idx)
	spectrum = AudioServer.get_bus_effect_instance(bus_idx, 0)

func _process(_delta: float) -> void:
	if not spectrum:
		return

	var magnitude2d: Vector2 = spectrum.get_magnitude_for_frequency_range(MIN_FREQ, MAX_FREQ)
	var amplitude: float = sqrt(pow((magnitude2d.x + magnitude2d.y), 2) / 2.0 )
	var target_scale = base_scale + (base_scale * amplitude * scale_multiplier) / Settings.music_volume / Settings.master_volume

	scale = target_scale
	
