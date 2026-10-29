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
	var columns := mini(4, cards.size())
	var rows := ceili(float(cards.size()) / float(columns))
	var gap_x := 30.0
	var gap_y := 24.0
	var width := minf(220.0, (size.x - gap_x * (columns - 1)) / columns)
	var height := minf(226.0, (size.y - gap_y * (rows - 1)) / rows)
	for row in range(rows):
		var first := row * columns
		var count := mini(columns, cards.size() - first)
		var total := count * width + gap_x * (count - 1)
		var start_x := (size.x - total) * 0.5
		var y := (size.y - (height * rows + gap_y * (rows - 1))) * 0.5 + row * (height + gap_y)
		for column in range(count):
			var index := first + column
			cards[index].position = Vector2(start_x + column * (width + gap_x), y)
			cards[index].size = Vector2(width, height)
	queue_redraw()

func _draw() -> void:
	for index in range(1, 8):
		var x := size.x * float(index) / 8.0
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.22, 0.37, 0.48, 0.16), 1.0, true)
	for index in range(1, 3):
		var y := size.y * float(index) / 3.0
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.22, 0.37, 0.48, 0.12), 1.0, true)
	var columns := mini(4, cards.size())
	for i in range(cards.size() - 1):
		if (i + 1) % columns == 0:
			continue
		var from: Vector2 = cards[i].position + Vector2(cards[i].size.x, cards[i].size.y * 0.24)
		var to: Vector2 = cards[i + 1].position + Vector2(0, cards[i + 1].size.y * 0.24)
		draw_dashed_line(from, to, Color("3b5a70"), 2.0, 6.0, true)
