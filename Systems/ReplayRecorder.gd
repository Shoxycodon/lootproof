extends Node

var recording := false
var samples: Array = []


func start_recording() -> void:
	recording = true
	samples.clear()


func stop_recording() -> Array:
	recording = false
	return samples.duplicate(true)


func record_sample(sample: Dictionary) -> void:
	if recording:
		samples.append(sample.duplicate(true))
