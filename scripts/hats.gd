extends RefCounted
## Hats the player can wear, made of small blocks. Each hat is built on a node whose
## origin is the top center of the head, with the face looking toward -Z.

const U := preload("res://scripts/util.gd")

const NAMES: Array[String] = ["crown", "snowman", "bear", "bunny", "flower"]

const GOLD := Color(1.0, 0.8, 0.15)
const SNOW := Color(0.97, 0.98, 1.0)
const BLACK := Color(0.1, 0.1, 0.12)
const BROWN := Color(0.58, 0.38, 0.22)
const TAN := Color(0.85, 0.68, 0.48)
const PINK := Color(1.0, 0.6, 0.75)


static func build(hat_name: String, parent: Node3D) -> void:
	match hat_name:
		"crown": _crown(parent)
		"snowman": _snowman(parent)
		"bear": _bear(parent)
		"bunny": _bunny(parent)
		"flower": _flower(parent)


static func _crown(p: Node3D) -> void:
	for z: float in [-0.25, 0.25]:
		U.mesh_box(p, Vector3(0.55, 0.14, 0.05), Vector3(0, 0.07, z), GOLD)
	for x: float in [-0.25, 0.25]:
		U.mesh_box(p, Vector3(0.05, 0.14, 0.55), Vector3(x, 0.07, 0), GOLD)
	for x: float in [-0.25, 0.0, 0.25]:
		for z: float in [-0.25, 0.0, 0.25]:
			if x == 0.0 and z == 0.0:
				continue
			U.mesh_box(p, Vector3(0.08, 0.12, 0.08), Vector3(x, 0.2, z), GOLD)
	U.mesh_box(p, Vector3(0.09, 0.09, 0.03), Vector3(0, 0.07, -0.28), Color(0.9, 0.1, 0.2))
	U.mesh_box(p, Vector3(0.06, 0.06, 0.03), Vector3(-0.15, 0.07, -0.28), Color(0.2, 0.5, 1.0))
	U.mesh_box(p, Vector3(0.06, 0.06, 0.03), Vector3(0.15, 0.07, -0.28), Color(0.2, 0.8, 0.4))


## A little snowman sitting on your head, with a carrot nose and a top hat.
static func _snowman(p: Node3D) -> void:
	U.mesh_box(p, Vector3(0.42, 0.4, 0.42), Vector3(0, 0.2, 0), SNOW)
	U.mesh_box(p, Vector3(0.3, 0.3, 0.3), Vector3(0, 0.55, 0), SNOW)
	for x: float in [-0.065, 0.065]:
		U.mesh_box(p, Vector3(0.05, 0.05, 0.02), Vector3(x, 0.6, -0.155), BLACK)
	U.mesh_box(p, Vector3(0.05, 0.05, 0.16), Vector3(0, 0.54, -0.22), Color(1.0, 0.5, 0.1))
	for y: float in [0.12, 0.26]:
		U.mesh_box(p, Vector3(0.05, 0.05, 0.02), Vector3(0, y, -0.215), BLACK)
	U.mesh_box(p, Vector3(0.36, 0.03, 0.36), Vector3(0, 0.715, 0), BLACK)
	U.mesh_box(p, Vector3(0.22, 0.2, 0.22), Vector3(0, 0.83, 0), BLACK)
	U.mesh_box(p, Vector3(0.23, 0.04, 0.23), Vector3(0, 0.75, 0), Color(0.9, 0.2, 0.2))


## A teddy bear sitting on your head.
static func _bear(p: Node3D) -> void:
	U.mesh_box(p, Vector3(0.3, 0.28, 0.24), Vector3(0, 0.15, 0.02), BROWN)
	U.mesh_box(p, Vector3(0.16, 0.16, 0.02), Vector3(0, 0.14, -0.105), TAN)
	for x: float in [-1.0, 1.0]:
		U.mesh_box(p, Vector3(0.08, 0.18, 0.08), Vector3(0.19 * x, 0.17, -0.02), BROWN)
		U.mesh_box(p, Vector3(0.1, 0.08, 0.16), Vector3(0.08 * x, 0.04, -0.14), BROWN)
	U.mesh_box(p, Vector3(0.28, 0.26, 0.26), Vector3(0, 0.42, 0), BROWN)
	for x: float in [-0.12, 0.12]:
		U.mesh_box(p, Vector3(0.1, 0.1, 0.06), Vector3(x, 0.58, 0), BROWN)
		U.mesh_box(p, Vector3(0.05, 0.05, 0.02), Vector3(x, 0.58, -0.035), TAN)
		U.mesh_box(p, Vector3(0.04, 0.05, 0.02), Vector3(x * 0.6, 0.46, -0.135), BLACK)
	U.mesh_box(p, Vector3(0.12, 0.08, 0.05), Vector3(0, 0.38, -0.15), TAN)
	U.mesh_box(p, Vector3(0.05, 0.03, 0.02), Vector3(0, 0.4, -0.18), BLACK)


static func _bunny(p: Node3D) -> void:
	U.mesh_box(p, Vector3(0.54, 0.05, 0.1), Vector3(0, 0.02, 0), PINK)
	for x: float in [-1.0, 1.0]:
		var ear := Node3D.new()
		ear.position = Vector3(0.12 * x, 0.03, 0)
		ear.rotation.z = -0.18 * x
		p.add_child(ear)
		U.mesh_box(ear, Vector3(0.11, 0.45, 0.06), Vector3(0, 0.22, 0), SNOW)
		U.mesh_box(ear, Vector3(0.05, 0.34, 0.02), Vector3(0, 0.22, -0.035), PINK)


## A straw sun hat with a big flower on top.
static func _flower(p: Node3D) -> void:
	var straw := Color(0.95, 0.85, 0.55)
	U.mesh_box(p, Vector3(0.82, 0.03, 0.82), Vector3(0, 0.02, 0), straw)
	U.mesh_box(p, Vector3(0.5, 0.16, 0.5), Vector3(0, 0.11, 0), straw)
	U.mesh_box(p, Vector3(0.52, 0.05, 0.52), Vector3(0, 0.07, 0), PINK)
	for i in 5:
		var a := TAU * i / 5.0
		U.mesh_box(p, Vector3(0.12, 0.04, 0.12), Vector3(cos(a) * 0.1, 0.21, sin(a) * 0.1), Color(0.95, 0.35, 0.55))
	U.mesh_box(p, Vector3(0.09, 0.06, 0.09), Vector3(0, 0.22, 0), Color(1.0, 0.85, 0.2))
	U.mesh_box(p, Vector3(0.14, 0.03, 0.06), Vector3(0.14, 0.2, 0.06), Color(0.3, 0.7, 0.3))
