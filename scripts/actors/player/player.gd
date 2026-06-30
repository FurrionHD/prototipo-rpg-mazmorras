# ============================================================
#  player.gd
#  Controla el MOVIMIENTO del jugador en la exploración (top-down).
#  Se engancha a un nodo CharacterBody2D (la escena player.tscn).
#  Fase 1 del proyecto: solo moverse. Sin animaciones (placeholder cuadrado).
# ============================================================

# "extends CharacterBody2D" = este script ES un CharacterBody2D,
# o sea hereda todas sus propiedades y funciones (como velocity y move_and_slide).
extends CharacterBody2D


# @export hace que esta variable APAREZCA en el Inspector de Godot,
# así podrás cambiar la velocidad desde el editor sin tocar el código.
# Está en píxeles por segundo.
@export var speed: float = 120.0


# _physics_process() lo llama Godot automáticamente en CADA frame de física
# (un ritmo fijo y estable, ideal para movimiento). El parámetro "delta" es
# el tiempo entre frames; aquí no lo usamos (por eso el "_" delante).
func _physics_process(_delta: float) -> void:
	# Input.get_vector() lee las 4 acciones de input (las definimos en
	# project.godot) y devuelve un Vector2 con la dirección.
	# Ventaja: ya viene NORMALIZADO, así moverse en diagonal NO es más
	# rápido que moverse en recto (un error muy típico).
	#   - x negativo = izquierda, x positivo = derecha
	#   - y negativo = arriba,    y positivo = abajo
	var direction: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_up", "move_down"
	)

	# "velocity" es una propiedad que YA trae CharacterBody2D.
	# La rellenamos: dirección (hacia dónde) por velocidad (cómo de rápido).
	velocity = direction * speed

	# move_and_slide() mueve el cuerpo usando "velocity" y resuelve
	# colisiones automáticamente (cuando tengamos paredes, en la Fase 2).
	# OJO: NO hay que multiplicar por delta aquí; move_and_slide() ya lo
	# tiene en cuenta internamente al ser un cuerpo físico.
	move_and_slide()
