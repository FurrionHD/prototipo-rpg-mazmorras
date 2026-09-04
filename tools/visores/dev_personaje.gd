# ============================================================
#  dev_personaje.gd  --  HERRAMIENTA, no parte del juego.
#
#  Abre el menu de PERSONAJE de verdad (scripts/ui/character_menu.gd) con un grupo de cuatro, el
#  baul lleno y el lider equipado, y saca una captura de CADA seccion. Es la unica forma de juzgar
#  la pantalla: hay que ver si el muñeco cabe, si la ficha de la derecha se lee, si las dos filas
#  de pestañas caen una debajo de la otra y si los atributos cambian al ponerse un baston.
#
#  Se llena a mano y no se carga una partida guardada a proposito: hacen falta a la vez un grupo de
#  cuatro, armas de varias rarezas, un baston (para la rama MAGICA de los atributos), hechizos (para
#  las subpestañas de Trazos) y desarrollos y pasivas (para las de Eidolon). Una partida real casi
#  nunca los tiene todos, y ademas asi la captura es siempre la misma y dos versiones se comparan.
#
#  Va CON VENTANA (nada de --headless): un Control no se coloca ni se dibuja sin superficie de
#  render, y en headless la captura sale en negro.
#
#  Y con process_mode = ALWAYS: el menu PAUSA el arbol al abrirse (Game.fijar_modal), asi que sin
#  esto el propio visor se congela en el primer await y no llega a capturar nada.
#
#  Doble clic en herramientas/ver_personaje.bat, o:
#    godot --path . res://tools/visores/dev_personaje.tscn
#  Guarda tools/salida/personaje_<n>_<seccion>.png y se cierra solo.
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"
# El BASTON y la ESPADA CORTA no son de adorno en esta lista: el baston es lo unico que enciende la
# rama MAGICA de los atributos (Game.lleva_arma_magica) y la espada corta es la unica de una mano
# que admite escudo. Sin ellos, dos de las cinco ramas de la pantalla no se capturan nunca.
const ARMAS := ["espada_larga", "espada_corta", "daga", "mandobles", "hacha_grande", "estoque",
	"maza_peq", "baston"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(1280, 720))
	_llenar()
	_falso_jugador()
	# EL PUEBLO DE MENTIRA. Game.en_pueblo() mira si la escena actual es town.tscn, y el equipo SOLO
	# se cambia alli. Sin esto el boton de Equipar sale apagado en todas las capturas y la mitad de
	# las secciones de Armas y Armadura -- justo la que hace algo -- no se puede juzgar.
	if get_tree().current_scene != null:
		get_tree().current_scene.scene_file_path = "res://scenes/town.tscn"

	var men: CanvasLayer = preload("res://scripts/ui/character_menu.gd").new()
	add_child(men)
	men._set_open(true)

	DirAccess.make_dir_recursive_absolute(SALIDA)

	# 1) DETALLES, con arma NORMAL: la rama fisica de los atributos.
	men._on_seccion(men.SEC_FICHA)
	await _captura("0_detalles_atributos")
	men._pagina_a(1)
	await _captura("0_detalles_habilidades")
	men._pagina_a(0)
	# La lupa, que es donde sale TODO lo que la pagina de fuera esconde.
	men._abrir_modal_atributos()
	await _captura("0_detalles_lupa")
	men._cerrar_modal()

	# 2) ARMA: las dos manos, y la rejilla del baul al pulsar Cambiar.
	men._on_seccion(men.SEC_ARMAS)
	await _captura("1_arma_principal")
	men._pick(1)
	await _captura("1_arma_secundaria")
	men._pick(0)
	men._abrir_cambio()
	await _captura("1_arma_cambiar")
	# EQUIPAR DE VERDAD, que es lo unico que comprueba que el boton hace algo: se elige otra arma del
	# baul, se pulsa Equipar y se captura la seccion YA con el arma nueva puesta. Si la ficha de la
	# derecha no cambia, el camino esta roto.
	men._pick_cand(3)
	await _captura("1_arma_candidato")
	men._equipar()
	await _captura("1_arma_equipada")

	# 3) TRAZOS, con y sin la subpestaña de magias. El personaje 0 lleva hechizos y el 3 no: es lo
	# unico que enseña que la fila desaparece cuando no hay nada que elegir.
	men._on_seccion(men.SEC_HABILIDADES)
	await _captura("2_trazos_habilidades")
	men._on_sub(1)
	await _captura("2_trazos_magias")

	# 4) ARMADURA: los cinco slots y la rejilla de cambio de uno de ellos.
	men._on_seccion(men.SEC_ARMADURA)
	await _captura("3_armadura")
	men._pick(1)   # pecho, que es el slot con mas piezas en el baul
	men._abrir_cambio()
	await _captura("3_armadura_cambiar")
	men._cancelar_cambio()

	# 5) EIDOLON: con las dos clases (subpestañas) y sin ninguna (el hueco vacio, que es justo lo
	# que hay que comprobar que se explica solo).
	men._on_seccion(men.SEC_DESARROLLO)
	await _captura("4_eidolon_desarrollo")
	men._on_sub(1)
	await _captura("4_eidolon_pasivas")

	# EL PERSONAJE 3 (pelado: sin hechizos, sin desarrollos, sin pasivas y con las manos vacias).
	# Es la mitad de las ramas de esta pantalla, y es la que no se ve nunca en una partida madura.
	men._pick_persona(3)
	men._on_seccion(men.SEC_FICHA)
	await _captura("5_pelado_detalles")
	men._on_seccion(men.SEC_HABILIDADES)
	await _captura("5_pelado_trazos")
	men._on_seccion(men.SEC_DESARROLLO)
	await _captura("5_pelado_eidolon")
	men._on_seccion(men.SEC_ARMAS)
	await _captura("5_pelado_arma")

	# EL MAGO: el personaje 1 lleva baston, asi que sus atributos principales son los MAGICOS
	# (ataque magico, vel. recitado, criticos magicos). Es la bifurcacion que se pidio, y con el
	# lider solo no se ve.
	men._pick_persona(1)
	men._on_seccion(men.SEC_FICHA)
	await _captura("6_mago_atributos")
	men._abrir_modal_atributos()
	await _captura("6_mago_lupa")
	men._cerrar_modal()

	get_tree().quit()


# UN JUGADOR DE MENTIRA en el grupo "player", solo con lo que la ficha le pregunta.
#
# Hace falta porque la ENERGIA MAXIMA no vive en el Combatant: crear_player_combatant la deja a cero
# y se la inyecta start_combat leyendo el aguante del mapa (ver game.gd). La ficha la pide por la
# misma via, `player.aguante_de_grupo(pj)`, y aqui no hay jugador ninguno -- asi que sin esto la
# fila salia "0" en la captura y no habia forma de saber si el arreglo funcionaba.
func _falso_jugador() -> void:
	# El script se monta ENTERO y se compila ANTES de colgarselo al nodo: un GDScript recien creado
	# no tiene clase todavia, asi que `set_script` primero y `get_script().source_code` despues deja
	# el script en Nil y no se aplica nada.
	var sc := GDScript.new()
	sc.source_code = """
extends Node
func aguante_de_grupo(pj) -> Vector2:
	# Lo mismo que hace el jugador de verdad, en pequeño: el aguante sale de la Resistencia.
	var tope := 60.0 + float(pj.resistencia) * 0.12
	return Vector2(tope, tope)
func refrescar_grupo() -> void:
	pass
"""
	sc.reload()
	var n := Node.new()
	n.name = "JugadorDePrueba"
	n.set_script(sc)
	n.add_to_group("player")
	add_child(n)


func _captura(nombre: String) -> void:
	# DOS frames: el primero coloca los contenedores (hasta entonces las celdas miden 0 y la rejilla
	# aun no sabe cuantas columnas caben) y el segundo ya dibuja lo colocado.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var ruta: String = "%spersonaje_%s.png" % [SALIDA, nombre]
	get_viewport().get_texture().get_image().save_png(ruta)
	print("[personaje] ", ProjectSettings.globalize_path(ruta))


# ============================================================
#  LLENAR LA PARTIDA
# ============================================================

func _llenar() -> void:
	Game.money = 4820
	_baul()
	_grupo()


# El baul, COMUN a todo el grupo: armas de varias rarezas y desgastes, un baston y una varita (la
# rama magica), escudos (la rama del escudo en la mano secundaria) y armaduras de todos los slots.
func _baul() -> void:
	Game.owned_weapons = []
	Game.owned_armor = []
	var r: int = 0
	for id in ARMAS:
		var w: WeaponData = load("res://resources/weapons/%s.tres" % id) as WeaponData
		if w == null:
			continue
		for k in 2:
			var copia: WeaponData = w.duplicate() as WeaponData
			# Desgastes distintos a proposito: la ficha aplica la durabilidad al ataque, y con todo a
			# estrenar esa parte no se mira nunca.
			Game.item_meta[copia] = {"tier": (r % 3) + 1, "rareza": (r * 2 + k) % 8,
				"mejoras": {}, "durabilidad": 1.0 - float(r) * 0.08, "banda": 0}
			Game.owned_weapons.append(copia)
		r += 1
	# Bastones, varitas y escudos, que es lo que llena la mano secundaria y la rama magica.
	for carpeta in ["shields", "wands"]:
		var d := DirAccess.open("res://resources/%s/" % carpeta)
		if d == null:
			continue
		for f in d.get_files():
			if not f.ends_with(".tres"):
				continue
			var it: Resource = load("res://resources/%s/%s" % [carpeta, f])
			if it == null:
				continue
			var c2: Resource = it.duplicate()
			Game.item_meta[c2] = {"tier": (r % 3) + 1, "rareza": r % 8, "mejoras": {},
				"durabilidad": 1.0, "banda": 0}
			Game.owned_weapons.append(c2)
			r += 1
	var da := DirAccess.open("res://resources/armor/")
	if da == null:
		return
	for f in da.get_files():
		if not f.ends_with(".tres"):
			continue
		var a: ArmorData = load("res://resources/armor/" + f) as ArmorData
		if a == null:
			continue
		var copia2: ArmorData = a.duplicate() as ArmorData
		Game.item_meta[copia2] = {"tier": (r % 3) + 1, "rareza": r % 8, "mejoras": {},
			"durabilidad": 1.0 - float(r % 5) * 0.11, "banda": 0}
		Game.owned_armor.append(copia2)
		r += 1


# UN GRUPO DE CUATRO, cada uno con un papel distinto, porque cada uno enseña una rama de la pantalla
# que los otros no:
#   0 el LIDER   - guerrero completo, con hechizos aprendidos, desarrollos y pasivas
#   1 la MAGA    - con BASTON: es la que enseña los atributos MAGICOS
#   2 el TANQUE  - espada y escudo, para la ficha del escudo en la secundaria
#   3 el PELADO  - manos vacias, sin hechizos, sin desarrollos y sin pasivas: los huecos vacios
func _grupo() -> void:
	var base: PersonajeData = Game.lider()   # crea el original si aun no hay ninguno
	base.nombre = "Ilyan"
	base.level = 14
	var nombres := ["Sedaki", "Nurit", "Bram"]
	while Game.party.size() < 4:
		var i: int = Game.party.size() - 1
		var pj: PersonajeData = base.duplicate(true) as PersonajeData
		pj.nombre = nombres[i]
		pj.es_original = false
		pj.color = Color.from_hsv(0.12 + 0.28 * float(i), 0.55, 0.85)
		Game.plantilla.append(pj)
		Game.party.append(pj)

	# Stats distintas: con los cuatro iguales, la ficha dice lo mismo se mire a quien se mire y no
	# hay forma de saber si el selector de arriba cambia algo de verdad.
	var perfiles := [
		{"fuerza": 320, "resistencia": 260, "destreza": 180, "agilidad": 150, "magia": 60},
		{"fuerza": 70, "resistencia": 120, "destreza": 210, "agilidad": 240, "magia": 480},
		{"fuerza": 240, "resistencia": 430, "destreza": 90, "agilidad": 70, "magia": 30},
		{"fuerza": 40, "resistencia": 35, "destreza": 25, "agilidad": 30, "magia": 10},
	]
	for i in Game.party.size():
		var pj2: PersonajeData = Game.party[i]
		var p: Dictionary = perfiles[mini(i, perfiles.size() - 1)]
		for clave in p:
			pj2.set(clave, int(p[clave]))
		pj2.level = 14 - i * 3
		# La vida y el maná a media asta: las barras del muñeco solo se comparan si no estan todas
		# llenas. Se guardan como valor absoluto (el −1 es el sentinel de "a tope").
		pj2.current_hp = Game.player_max_hp(pj2) * (1.0 - 0.22 * float(i))
		pj2.current_mp = Game.player_max_mp(pj2) * (1.0 - 0.15 * float(i))

	# Los trozos van como se ESCRIBE el nombre del objeto ("Espada larga"), no como se llama su
	# fichero ("espada_larga.tres"): la busqueda es por nombre (ver _equipar).
	_equipar(0, "espada larga", "daga")
	_equipar(1, "baston", "")
	_equipar(2, "espada corta", "escudo")
	# El 3 se queda a manos vacias: es el que enseña las celdas de ranura vacia y el "peleas a puños".

	_hechizos(Game.party[0])
	_hechizos(Game.party[1])
	_perks(Game.party[0])
	_perks(Game.party[1])


# Le pone a party[i] un arma en cada mano y una pieza de armadura en cada slot.
#
# Se busca por el NOMBRE del objeto y no por su resource_path: las piezas del baul son duplicate()
# de los .tres, y un duplicado NACE SIN resource_path (queda vacio). Buscando por ahi no encontraba
# nada y los cuatro salian a manos vacias -- o sea que media pantalla (las fichas de arma, el kit
# del arma, los atributos magicos) no se veia en ninguna captura.
#
# 'main' y 'off' son trozos del nombre en minusculas ("baston", "escudo"); "" = esa mano se deja
# vacia a proposito.
func _equipar(i: int, main: String, off: String) -> void:
	if i >= Game.party.size():
		return
	var pj: PersonajeData = Game.party[i]
	for it in Game.owned_weapons:
		var nom: String = String(it.get("nombre")).to_lower()
		if main != "" and pj.equipped_main == null and it is WeaponData and nom.contains(main):
			Game.equipar_arma(it as WeaponData, pj)
			continue
		if off != "" and pj.equipped_off == null and it != pj.equipped_main and nom.contains(off):
			Game.equipar_secundaria(it, pj)
	for slot in ["casco", "pecho", "manos", "pantalones", "botas"]:
		for a in Game.owned_armor_de_slot(slot):
			# Solo lo que no lleve ya otro: si no, los cuatro se pelean por la misma pieza y los tres
			# ultimos acaban desnudos (el baul es COMUN a todo el grupo).
			if Game.quien_lleva(a) == null:
				Game.equipar_armadura(slot, a as ArmorData, pj)
				break


func _hechizos(pj: PersonajeData) -> void:
	var d := DirAccess.open("res://resources/spells/")
	if d == null:
		return
	for f in d.get_files():
		if not f.ends_with(".tres") or pj.equipped_spells.size() >= 4:
			continue
		var s: SpellData = load("res://resources/spells/" + f) as SpellData
		if s != null:
			pj.equipped_spells.append(s)


# Desarrollos y pasivas: los tres primeros del catalogo con rangos distintos, y la primera pasiva.
# Con uno solo de cada no se ve si la rejilla respira ni si la letra de rango cambia de sitio.
func _perks(pj: PersonajeData) -> void:
	var n: int = 0
	for dd in Game.DESARROLLOS:
		pj.desarrollos_rango[str(dd["id"])] = 1 + n * 2
		n += 1
		if n >= 3:
			break
	# pasivas_rng es un Dictionary id -> bool (lo lee Game.tiene_pasiva), no una lista.
	if not Game.PASIVAS_RNG.is_empty():
		pj.pasivas_rng[str(Game.PASIVAS_RNG[0]["id"])] = true
