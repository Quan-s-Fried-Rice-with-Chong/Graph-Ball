extends Control

signal level_requested(index: int)
signal back_requested

func _ready() -> void:
	%BackLevelsButton.pressed.connect(func(): back_requested.emit())
	%LevelRoute.level_selected.connect(func(index: int): level_requested.emit(index))

func configure(levels: Array, unlocked: int, completed: Array) -> void:
	%LevelRoute.configure(levels, unlocked, completed)
	%ProgressLabel.text = "%d / %d 已通关" % [completed.size(), levels.size()]

func get_lock_states() -> Array:
	var states: Array = []
	for card in %LevelRoute.cards:
		states.append(card.locked)
	return states
