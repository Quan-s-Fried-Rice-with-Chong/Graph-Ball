class_name GameConstants
extends RefCounted

const WORLD_SCALE := 48.0
const BALL_RADIUS := 0.28
const TRACK_HALF_THICKNESS := 0.075
const GRAVITY := 3.2
const MAX_SPEED := 16.0
const SAMPLE_STEP := 0.1
const MAX_SAMPLE_POINTS := 600
const MAX_FORMULAS := 3

const MODULE_LINE := "line"
const MODULE_QUADRATIC := "quadratic"
const MODULE_SINE := "sine"

const MATERIALS := {
	MODULE_LINE: {
		"restitution": 0.0,
		"friction": 0.30,
		"color": Color("4968b5"),
		"label": "普通材质",
	},
	MODULE_SINE: {"restitution": 0.0, "friction": 0.25, "color": Color("8b70b8"), "label": "波浪材质"},
	MODULE_QUADRATIC: {
		"restitution": 0.65,
		"friction": 0.10,
		"color": Color("ffc45c"),
		"label": "弹性材质",
	},
}

static func material_for(module_type: String) -> Dictionary:
	return MATERIALS.get(module_type, MATERIALS[MODULE_LINE]).duplicate(true)
