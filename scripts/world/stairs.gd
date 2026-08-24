# ============================================================
#  stairs.gd
#  ESCALERA entre pisos. Interactuable con F (grupo "interactable"), como la puerta.
#   - BAJAR: en la sala mas lejana a la entrada, asi que descender obliga a cruzar la
#     mazmorra entera.
#   - SUBIR: en la sala de entrada, y solo a partir del piso 2. En el piso 1 ese sitio lo
#     ocupa la puerta al pueblo: el pueblo esta en la BOCA de la mazmorra, no en cada piso.
#  El aspecto lo dibuja PropSprites: un hueco con peldaños. Se distinguen por a donde va la luz
#  (bajando se hunde hacia lo oscuro, subiendo sale hacia la boca iluminada), no por el color.
# ============================================================

extends Node2D

var sube: bool = false   # false = baja un piso; true = sube uno


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("escalera")   # para que la libreta (Game.capturar_mapa) las cartografie
	_crear_aspecto()


func interact_with_player() -> void:
	# MULTIJUGADOR (hito 5.2): cada uno baja y sube POR SU CUENTA; el compañero se queda donde
	# este. El viaje pasa por el host porque hay que repartir quien SIMULA cada piso: sueltas el
	# que dejas (con su foto) y el host te dice si el nuevo lo simulas tu o solo lo espejas. El
	# cambio de piso local lo hace Net._viaje_ok cuando llega la respuesta.
	if Net.activo:
		if sube and Game.current_floor <= 1:
			return   # en el piso 1 no hay escalera de subir: ahi esta la puerta al pueblo
		# OJO con el segundo flag: 'por_la_bajada' NO significa "voy hacia abajo", significa "llego por
		# la escalera de BAJADA del piso de abajo", o sea que HE SUBIDO (ver Game.subir_piso, que pasa
		# true). Iba invertido: al bajar en multi aparecias en el FONDO del piso nuevo, pegado a su
		# escalera de BAJAR, mientras la de SUBIR se plantaba en la boca al otro extremo del mapa. De
		# ahi el "solo deja bajar y donde deberia estar la subida pone bajar".
		Net.solicitar_piso(Game.current_floor + (-1 if sube else 1), sube)
		return
	if sube:
		Game.subir_piso()
	else:
		Game.bajar_piso()


func _crear_aspecto() -> void:
	var s := Sprite2D.new()
	s.texture = PropSprites.textura("escalera_sube" if sube else "escalera_baja")
	# POR NODO, que el proyecto no lo pone globalmente (misma nota que en enemy.gd).
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(s)

	var lbl := Label.new()
	lbl.text = "↑ SUBIR\n[F]" if sube else "↓ BAJAR\n[F]"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.offset_left = -34.0
	lbl.offset_top = -40.0
	lbl.offset_right = 34.0
	lbl.offset_bottom = -14.0
	add_child(lbl)
