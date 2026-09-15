# ============================================================
#  hogar_equipo.gd  --  seccion EQUIPO del menu del HOGAR (ver home_menu.gd, que es el armazon).
#  Es un RefCounted y no un nodo: lo que pinta va en las zonas del armazon (hogar._lista, hogar._content...)
#  y el estado de la pantalla (el aviso, el guardia de _rebuild) vive alli, igual que las piezas de
#  combat.gd (combat_altas, combat_figuras...).
# ============================================================
extends RefCounted

const AMBAR := Color(0.95, 0.72, 0.36)
const VERDE := Color(0.55, 0.85, 0.55)
const GRIS := Color(0.6, 0.63, 0.7)

var hogar = null   # el armazon (home_menu.gd). Sin tipo: con CanvasLayer no se ven sus variables


func _init(pantalla: CanvasLayer) -> void:
	hogar = pantalla

# ============================================================
#  EQUIPO: los que bajan (izquierda) y el banquillo (derecha)
# ============================================================

func _build_equipo() -> void:
	MenuScaffold.titulo(hogar._header, "QUIÉN BAJA CONTIGO", 18)

	MenuScaffold.titulo(hogar._lista, "El equipo (%d de %d)" % [Game.party.size(), Game.PARTY_MAX], 14)
	for i in Game.party.size():
		_fila_equipo(i)
	if Game.party.is_empty():
		MenuScaffold.nota(hogar._lista, "No baja nadie. Si cierras así, %s (tu personaje original) se pone "
			% Game.original().nombre + "al frente solo: alguien tiene que llevar el cuerpo.")
	MenuScaffold.nota(hogar._lista, "El de la 👑 va EN CABEZA: es el cuerpo que mueves por el mapa, el "
		+ "que recolecta y el que gasta aguante. Cada uno tiene su hueco fijo (su número); cambiar "
		+ "de cabeza con «Al frente» o las teclas 1/2/3 no los mueve de sitio.")

	MenuScaffold.titulo(hogar._content, "En casa (%d)" % Game.en_el_banquillo().size(), 14)
	var banquillo: Array = Game.en_el_banquillo()
	if banquillo.is_empty():
		MenuScaffold.nota(hogar._content, "No hay nadie esperando en casa. Se contrata gente en la taberna.")
	for pj in banquillo:
		_fila_banquillo(pj)


func _fila_equipo(i: int) -> void:
	var pj: PersonajeData = Game.party[i]
	var t: Dictionary = hogar._tarjeta(hogar._lista)
	var fila: HBoxContainer = t["botones"]

	(t["info"] as HBoxContainer).add_child(hogar._punto(pj))

	var es_lider: bool = pj == Game.lider()
	var l := Label.new()
	# El numero es el de la tecla que lo pone en cabeza (1/2/3), y es FIJO: cada uno tiene su hueco.
	l.text = "%d. %s%s  ·  Nv.%d  ·  Poder %d" % [i + 1, "👑 " if es_lider else "", pj.nombre,
		pj.level, int(round(Encargos.poder(pj)))]
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if es_lider:
		l.add_theme_color_override("font_color", AMBAR)
	(t["info"] as HBoxContainer).add_child(l)

	# Ponerlo EN CABEZA. Ya no reordena el equipo (las posiciones son fijas): solo mueve la corona,
	# lo mismo que hace su tecla. Deshabilitado si ya va delante.
	var frente := Button.new()
	frente.text = "👑 Al frente"
	frente.custom_minimum_size = Vector2(0, MenuScaffold.ALTO_BOTON)
	frente.disabled = es_lider
	frente.tooltip_text = "Ponlo en cabeza (tecla %d). El cuerpo que mueves pasa a ser el suyo." % (i + 1)
	frente.pressed.connect(func():
		if Game.cambiar_lider(i):
			hogar._aviso = "%s va en cabeza." % pj.nombre
			hogar._aviso_ok = true
			_avisar_cambio_lider()
			hogar._rebuild())
	fila.add_child(frente)

	var fuera := Button.new()
	fuera.text = "A casa"
	fuera.custom_minimum_size = Vector2(0, MenuScaffold.ALTO_BOTON)
	# CUALQUIERA puede quedarse en casa, el original incluido, y el equipo puede quedarse vacio: al
	# cerrar el Hogar baja el original solo (ver hogar._cerrar).
	fuera.tooltip_text = "Lo deja en el Hogar. No se despide a nadie: sigue en tu plantilla." \
		+ ("\nSi no dejas a nadie en el equipo, al cerrar bajará tu personaje original." \
			if Game.party.size() <= 1 else "")
	fuera.pressed.connect(func():
		if Game.sacar_del_equipo(pj):
			hogar._aviso = "%s se queda en casa." % pj.nombre
			hogar._aviso_ok = true
			_avisar_cambio_lider()
			hogar._rebuild())
	fila.add_child(fuera)

	fila.add_child(_boton_aspecto(pj))


func _fila_banquillo(pj: PersonajeData) -> void:
	var t: Dictionary = hogar._tarjeta(hogar._content)
	var fila: HBoxContainer = t["botones"]

	(t["info"] as HBoxContainer).add_child(hogar._punto(pj))

	# ¿Está fuera, de encargo? Entonces no se le puede tocar hasta que vuelva.
	var enc_id: int = Game.uid_de_encargo(String(pj.uid))
	var enc: Dictionary = Game.encargo_por_id(enc_id) if enc_id != 0 else {}
	var fuera_txt: String = ""
	if not enc.is_empty():
		fuera_txt = "  ·  De encargo (%s)" % ("¡de vuelta!" \
			if int(enc.get("estado", 0)) == Encargos.ESTADO_LISTO else Encargos.texto_restante(enc))

	var l := Label.new()
	l.text = "%s  ·  Nv.%d  ·  Poder %d%s" % [pj.nombre, pj.level,
		int(round(Encargos.poder(pj))), fuera_txt]
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if enc_id != 0:
		l.add_theme_color_override("font_color", GRIS)
	(t["info"] as HBoxContainer).add_child(l)

	var dentro := Button.new()
	dentro.text = "Que baje"
	# En sesion multi el cupo puede ser menor que PARTY_MAX (Net.cupo_party; en solitario es 4).
	var cupo: int = mini(Game.PARTY_MAX, Net.cupo_party())
	dentro.disabled = Game.party.size() >= cupo or enc_id != 0
	if enc_id != 0:
		dentro.tooltip_text = "Está fuera, en un encargo. Recógelo primero."
	dentro.pressed.connect(func():
		if Game.meter_en_equipo(pj):
			hogar._aviso = "%s se une al equipo." % pj.nombre
			hogar._aviso_ok = true
			hogar._rebuild()
		else:
			hogar._aviso = "El equipo ya va lleno (%d)." % mini(Game.PARTY_MAX, Net.cupo_party())
			hogar._aviso_ok = false
			hogar._rebuild())
	fila.add_child(dentro)

	# Quedarse en casa NO le desequipa: lo suyo sigue siendo suyo y al volver a bajar sigue vestido.
	# Pero entonces su espada no se puede vender ni fundir ni ponersela a otro sin robarsela, asi que
	# hace falta una forma de reclamarla sin tener que meterlo otra vez en el equipo.
	var lleva: int = _piezas_puestas(pj)
	var quitar := Button.new()
	quitar.text = "Recoger su equipo"
	# Y estando de encargo tampoco: su equipo es lo que decide si vuelve entero, y el pronostico ya
	# se calculo con el puesto. Desnudarlo a media faena seria hacer trampa al reves.
	quitar.disabled = lleva == 0 or enc_id != 0
	quitar.tooltip_text = "Está fuera, en un encargo: no puedes desvestirle a media faena." \
		if enc_id != 0 else ("Le quita lo que lleve puesto y lo devuelve al baúl, para dárselo a " \
		+ "otro, venderlo o fundirlo." if lleva > 0 else "No lleva nada puesto.")
	quitar.pressed.connect(func():
		var n: int = Game.desequipar_todo(pj)
		hogar._aviso = "%s deja %d pieza%s en el baúl." % [pj.nombre, n, "" if n == 1 else "s"]
		hogar._aviso_ok = true
		hogar._rebuild())
	fila.add_child(quitar)

	fila.add_child(_boton_aspecto(pj))


# Editar la CARA de cualquiera de los tuyos, esten en el equipo o en el banquillo. Antes solo el
# personaje de la ranura se podia retocar (desde el menu principal) y los companeros se quedaban
# con el aspecto del dia que los contrataste para siempre.

func _boton_aspecto(pj: PersonajeData) -> Button:
	var b := Button.new()
	b.text = "Aspecto"
	b.custom_minimum_size = Vector2(0, MenuScaffold.ALTO_BOTON)
	b.tooltip_text = "Cambia su cara, su pelo y su ropa. Ni su progreso ni su equipo se tocan."
	b.pressed.connect(func(): _editar_aspecto(pj))
	return b


func _editar_aspecto(pj: PersonajeData) -> void:
	CreadorPersonaje.abrir(hogar, "ASPECTO  ·  %s" % pj.nombre,
		"Solo cambia cómo se ve. Su progreso y su equipo no se tocan.",
		"Guardar cambios",
		{"nombre": pj.nombre, "color": pj.color, "metalico": pj.metalico,
			"color_alpha": pj.color_alpha, "imagen": pj.imagen,
			"piezas": pj.aspecto_completo()["piezas"]},
		func(nombre: String, asp: Dictionary):
			var limpio: String = nombre.strip_edges()
			pj.nombre = limpio if limpio != "" else pj.nombre
			pj.aplicar_aspecto(asp)
			# Repintar el cuerpo y el sequito: si no, el cambio no se ve hasta cambiar de escena.
			var jugador: Node = hogar.get_tree().get_first_node_in_group("player")
			if jugador != null and jugador.has_method("refrescar_grupo"):
				jugador.refrescar_grupo()
			# MULTI: y re-difundirlo, o el compañero no lo veria hasta cambiar de escena. Se anuncian
			# los DOS (lider y sequito) porque el editado puede ser cualquiera; es barato.
			if Net.activo:
				Net.pisos.anunciar_aspecto()
				Net.jugadores.anunciar_grupo()
			hogar._aviso = "%s cambia de aspecto." % pj.nombre
			hogar._aviso_ok = true
			hogar._rebuild())


# Cuantas piezas lleva puestas (para no ofrecer "recoger" a quien va desnudo).
func _piezas_puestas(pj: PersonajeData) -> int:
	var n: int = 0
	for slot in Game.EQUIP_SLOTS:
		if pj.get("equipped_" + slot) != null:
			n += 1
	return n

# Tocar el orden del equipo puede cambiar QUIEN va en cabeza, y de eso dependen el cuerpo que se
# ve por el mapa, el aguante y la velocidad. Se le avisa al jugador para que se repinte solo.
func _avisar_cambio_lider() -> void:
	var p: Node = hogar.get_tree().get_first_node_in_group("player")
	if p != null and p.has_method("refrescar_lider"):
		p.refrescar_lider()
