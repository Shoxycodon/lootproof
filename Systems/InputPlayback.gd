extends Node

var samples: Array = []
var cursor := 0


func load_samples(data: Array) -> void:
	samples = data.duplicate(true)
	cursor = 0


func next_sample() -> Dictionary:
	if samples.is_empty():
		return {}
	cursor = mini(cursor + 1, samples.size() - 1)
	return samples[cursor]
