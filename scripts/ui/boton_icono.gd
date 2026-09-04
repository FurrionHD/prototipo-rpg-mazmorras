# ============================================================
#  boton_icono.gd
#  El boton cuadrado que se pinta solo: fondo redondeado y un icono de iconos.gd dentro.
#
#  No es un Button de Godot porque el dibujo va por _draw y porque el disparo tiene que ser AL
#  SOLTAR y no al pulsar: con los dedos uno se da cuenta a mitad de gesto de que iba a darle al
#  boton que no era, y arrastrar fuera tiene que cancelarlo. Un Button normal ya lo hace con el
#  raton, pero aqui ademas hay que atender los eventos de PANTALLA.
#
#  Lo usan la botonera del HUD (personaje, bolsa, mapa, pausa) y la ✕ del mapa. Vive aqui y no
#  dentro de hud.gd para que no haya dos copias que se separen.
# ============================================================

class_name BotonIcono


# Crea el boton. 'dibujo' es una de las funciones de Iconos (se le pasa el CanvasItem, la esquina,
# el lado y el color), y 'al_pulsar' lo que se llama al soltar dentro.
# 'con_caja' = el cuadro de fondo con su borde. Los botones del HUD lo NECESITAN: flotan sobre el
# mundo, y sin fondo un icono claro sobre un suelo claro deja de verse y de parecer pulsable.
#
# La ✕ de los menus va SIN el (ver MenuScaffold.equis_cerrar): ahi el fondo es el del propio menu,
# plano y oscuro, asi que el aspa se ve sola -- y el cuadro solo conseguia que la esquina pesara.
# Sin caja, el hundido se marca aclarando el aspa, que es lo unico que queda.
static func crear(dibujo: Callable, al_pulsar: Callable, lado: float = 72.0,
		con_caja: bool = true) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(lado, lado)
	c.size = Vector2(lado, lado)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.set_meta("hundido", false)

	c.draw.connect(func() -> void:
		var hundido: bool = bool(c.get_meta("hundido"))
		if con_caja:
			c.draw_style_box(_caja(Color(0.30, 0.32, 0.40, 0.92) if hundido
				else Color(0.10, 0.11, 0.14, 0.82)), Rect2(Vector2.ZERO, c.size))
		# El icono, con un margen para que no toque el borde del cuadro.
		var pad: float = lado * 0.18
		dibujo.call(c, Vector2(pad, pad), lado - pad * 2.0,
			Color(1, 1, 1) if (hundido and not con_caja) else Color(0.90, 0.90, 0.94))
	)

	c.gui_input.connect(func(event: InputEvent) -> void:
		var abajo: bool = false
		var suelta: bool = false
		if event is InputEventScreenTouch:
			abajo = (event as InputEventScreenTouch).pressed
			suelta = not abajo
		elif event is InputEventMouseButton:
			var m := event as InputEventMouseButton
			if m.button_index != MOUSE_BUTTON_LEFT:
				return
			abajo = m.pressed
			suelta = not m.pressed
		else:
			return
		if abajo:
			c.set_meta("hundido", true)
			c.queue_redraw()
		elif suelta:
			# Solo cuenta si el gesto EMPEZO aqui: si el dedo entro desde fuera ya arrastrando,
			# 'hundido' es false y no se dispara nada.
			var dentro: bool = bool(c.get_meta("hundido"))
			c.set_meta("hundido", false)
			c.queue_redraw()
			if dentro:
				al_pulsar.call()
	)

	# Sacar el dedo (o el raton) del boton lo suelta sin disparar: es la mitad "arrastrar fuera
	# cancela" de la regla de arriba.
	c.mouse_exited.connect(func() -> void:
		if bool(c.get_meta("hundido")):
			c.set_meta("hundido", false)
			c.queue_redraw()
	)
	return c


static func _caja(fondo: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fondo
	sb.border_color = Color(1, 1, 1, 0.28)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	return sb
