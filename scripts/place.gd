extends Node3D
## Base for every place you reach through a rainbow door in the park: the jump courses,
## the giant spiral slide and the water park. A place is built the first time you enter
## it, and hidden (and taken out of physics) while you are somewhere else.
## main.gd calls enter(), leave() and skip(); a place calls go_home when you want to leave.

const U := preload("res://scripts/util.gd")
const COLORS: Array[Color] = [
	Color(0.95, 0.3, 0.3), Color(1.0, 0.6, 0.15), Color(1.0, 0.85, 0.2), Color(0.4, 0.8, 0.3),
	Color(0.25, 0.65, 0.95), Color(0.55, 0.4, 0.9), Color(0.95, 0.45, 0.75),
]

signal go_home

var player: Node
var sound: Node
var ui: Node
var active := false


func enter() -> void:
	active = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	ui.show_stage = false
	ui.queue_redraw()
	_arrive()


func leave() -> void:
	active = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	ui.show_stage = false
	ui.queue_redraw()


## The < and > stage buttons. Only places with checkpoints use them.
func skip(_step: int) -> void:
	pass


## Puts the player in the place. Each place overrides this.
func _arrive() -> void:
	pass


## A rainbow door with a little house over it that takes you back to the park.
func _home_door(pos: Vector3, facing: Basis) -> void:
	var door := U.portal(self, pos, facing, COLORS)
	door.body_entered.connect(func(body: Node3D):
		if body == player:
			go_home.emit(), CONNECT_DEFERRED)
	var house := Node3D.new()
	house.position = pos + Vector3.UP * 4.2
	add_child(house)
	U.mesh_box(house, Vector3(0.8, 0.6, 0.4), Vector3.ZERO, Color.WHITE)
	var roof := U.mesh_box(house, Vector3(0.7, 0.7, 0.42), Vector3(0, 0.4, 0), COLORS[0])
	roof.rotation.z = PI * 0.25


## Tall invisible walls around a square area, so nobody falls off the edge.
func _edge_walls(half_size: float, center := Vector3.ZERO) -> void:
	var wall := StaticBody3D.new()
	add_child(wall)
	for side: float in [-1.0, 1.0]:
		U.add_box_shape(wall, Vector3(1, 80, half_size * 2), center + Vector3(half_size * side, 40, 0))
		U.add_box_shape(wall, Vector3(half_size * 2, 80, 1), center + Vector3(0, 40, half_size * side))
