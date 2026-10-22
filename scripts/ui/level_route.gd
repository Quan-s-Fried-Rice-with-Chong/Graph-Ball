extends Control

signal level_selected(index: int)
const Card = preload("res://scripts/ui/level_card.gd")
var cards: Array = []

func _ready() -> void:
	resized.connect(_layout_cards)

func configure(levels: Array, unlocked: int, completed: Array) -> void:
	for card in cards:
		remove_child(card)
		card.queue_free()
	cards = []
	for i in range(levels.size()):
		var card := Card.new()
		card.name = "Level_%02d" % (i + 1)
		card.level_index = i
		card.level_title = levels[i].title
		card.concept = levels[i].get("concept", levels[i].objective)
		card.locked = i > unlocked
		card.completed = completed.has(levels[i].id)
		card.pressed.connect(func(): level_selected.emit(i))
		add_child(card)
		cards.append(card)
	_layout_cards.call_deferred()

func _layout_cards() -> void:
	if cards.is_empty():
		return
	var gap := 44.0
	var width := minf(232.0, (size.x - gap * (cards.size() - 1)) / cards.size())
	var total := cards.size() * width + gap * (cards.size() - 1)
	var start := (size.x - total) * 0.5
	for i in range(cards.size()):
		cards[i].position = Vector2(start + i * (width + gap), (size.y - 226.0) * 0.5)
		cards[i].size = Vector2(width, 226)
	queue_redraw()

func _draw() -> void:
	for i in range(cards.size() - 1):
		var from: Vector2 = cards[i].position + Vector2(cards[i].size.x, 55)
		var to: Vector2 = cards[i + 1].position + Vector2(0, 55)
		draw_dashed_line(from, to, Color("aab8d0"), 2.0, 6.0, true)
