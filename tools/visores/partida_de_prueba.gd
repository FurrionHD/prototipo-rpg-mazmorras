# ============================================================
#  partida_de_prueba.gd  --  HERRAMIENTA, no parte del juego.
#
#  LA PARTIDA QUE MIRAN LOS VISORES: un grupo de cuatro con papeles distintos, el baul lleno de
#  armas de varias rarezas y desgastes, armaduras de todos los slots, hechizos, tecnicas de arma,
#  desarrollos y pasivas.
#
#  Se llena a mano y no se carga una partida guardada a proposito: hacen falta a la vez todas esas
#  cosas, una partida real casi nunca las tiene todas, y ademas asi la captura es siempre la misma
#  y dos versiones se pueden comparar.
#
#  Vive aparte y no dentro de un visor porque ya la usan dos (el de personaje y el del maestro): con
#  una copia por visor, arreglar el grupo en uno deja al otro mirando otra partida.
#
#  Los visores lo cargan con preload y NO por class_name: un class_name recien creado no esta en la
#  cache de clases de Godot hasta que se abre el editor, y estas herramientas se lanzan por linea de
#  comandos -- asi que por ahi no compilaba ni una vez.
# ============================================================
extends RefCounted

# El BASTON y la ESPADA CORTA no son de adorno en esta lista: el baston es lo unico que enciende la
# rama MAGICA de los atributos (Game.lleva_arma_magica) y la espada corta es la unica de una mano
# que admite escudo. Sin ellos, dos de las cinco ramas de la pantalla no se capturan nunca.
const ARMAS := ["espada_larga", "espada_corta", "daga", "mandobles", "hacha_grande", "estoque",
	"maza_peq", "baston"]


static func llenar() -> void:
	Game.money = 4820
	_baul()
	_grupo()


# El baul, COMUN a todo el grupo: armas de varias rarezas y desgastes, un baston y una varita (la
# rama magica), escudos (la rama del escudo en la mano secundaria) y armaduras de todos los slots.
static func _baul() -> void:
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
static func _grupo() -> void:
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
	equipar(0, "espada larga", "daga")
	equipar(1, "baston", "")
	equipar(2, "espada corta", "escudo")
	# El 3 se queda a manos vacias: es el que enseña las celdas de ranura vacia y el "peleas a puños".

	_hechizos(Game.party[0])
	_hechizos(Game.party[1])
	_habilidades(Game.party[0])
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
static func equipar(i: int, main: String, off: String) -> void:
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


# Le enseña TODOS los hechizos del proyecto y le equipa los que caben. Todos y no cuatro: desde que
# aprender no tiene tope, el caso interesante es justo el de la cabeza llena -- se sabe mas de las
# que puede llevar, y esa es la pantalla que hay que mirar.
static func _hechizos(pj: PersonajeData) -> void:
	var d := DirAccess.open("res://resources/spells/")
	if d == null:
		return
	for f in d.get_files():
		if not f.ends_with(".tres"):
			continue
		var s: SpellData = load("res://resources/spells/" + f) as SpellData
		if s != null:
			Game.aprender_hechizo(s, pj)   # equipa solo mientras quepan (ver Game)


# Le enseña las tecnicas de TODAS las armas del baul, no solo las de la que lleva ahora: la
# secuencia de capturas le cambia el arma a media pantalla, y con las de una sola el pool se
# quedaba vacio justo despues de ese cambio.
#
# Hace falta porque sin aprender nada solo se sabe las `inicial` -- que ya van puestas -- y el
# bloque de abajo sale vacio: justo la mitad que hay que mirar (poner una tecnica en un hueco).
static func _habilidades(pj: PersonajeData) -> void:
	for it in Game.owned_weapons:
		for ab in Game.habilidades_de_item(it):
			if ab != null and not pj.habilidades_aprendidas.has(ab):
				pj.habilidades_aprendidas.append(ab)


# Desarrollos y pasivas: los tres primeros del catalogo con rangos distintos, y la primera pasiva.
# Con uno solo de cada no se ve si la rejilla respira ni si la letra de rango cambia de sitio.
static func _perks(pj: PersonajeData) -> void:
	var n: int = 0
	for dd in Game.DESARROLLOS:
		pj.desarrollos_rango[str(dd["id"])] = 1 + n * 2
		n += 1
		if n >= 3:
			break
	# pasivas_rng es un Dictionary id -> bool (lo lee Game.tiene_pasiva), no una lista.
	if not Game.PASIVAS_RNG.is_empty():
		pj.pasivas_rng[str(Game.PASIVAS_RNG[0]["id"])] = true
