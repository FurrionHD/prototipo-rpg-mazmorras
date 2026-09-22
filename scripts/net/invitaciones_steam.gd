# ============================================================
#  invitaciones_steam.gd  (hijo de Net: /root/Net/Invitaciones)
#  INVITAR AMIGOS POR STEAM, y lo que pasa cuando te invitan a ti.
#
#  EL QUE INVITA (dentro de un mundo compartido, boton de la pausa):
#    1. Se inventa un TOKEN y se lo da a la sala (Net._registrar_invitacion). Con el, quien llegue
#       invitado entra sin el "Aceptar / Rechazar": invitar YA es dejar pasar (decision del usuario).
#    2. Arma la cadena CONNECT con todo lo que hace falta para entrar: codigo del mundo, contraseña,
#       token y el nombre del mundo. Solo la recibe el amigo invitado.
#    3. Abre el dialogo de invitar del overlay de Steam. Si el overlay no esta (Godot arrancado fuera de
#       Steam puede quedarse sin el), la pausa enseña una lista propia de amigos y se invita con
#       inviteUserToGame, que no necesita overlay: al amigo le llega igual por el chat de Steam.
#
#  EL INVITADO (con el juego ABIERTO: con el appID 480 un juego cerrado lanzaria Spacewar):
#    Steam emite join_game_requested(amigo, connect) -> se lee la cadena, se deja como INVITACION
#    PENDIENTE en Mundos y se le lleva al menu de Multijugador guardando lo que estuviera jugando. Ese
#    menu la atiende (multi_menu.atender_invitacion): entra directo si tiene personaje, crea uno si no,
#    y pregunta si quiere quedarse el mundo en su lista.
#
#  STEAM SE ENCIENDE AL ARRANCAR, no al entrar en Multijugador: si no, un juego en el menu o jugando a
#  solas no se enteraria de que le invitan. Sin Steam no pasa nada, como siempre.
# ============================================================
extends Node

const _TUNEL = preload("res://scripts/net/tunel_steam.gd")
const MULTI_MENU := "res://scenes/ui/multi_menu.tscn"

# La marca de nuestras cadenas. Cualquier otra cosa que llegue por join_game_requested (con el 480 lo
# comparte todo el que pruebe con Spacewar) se ignora.
const MARCA := "+oratoria"
# Lo que vale un token en la sala. Se puede invitar a varios con el mismo.
const SEG_TOKEN := 30 * 60
# getFriendCount / getFriendByIndex: k_EFriendFlagImmediate, los amigos de verdad.
const _AMIGOS := 4

var listo := false        # Steam encendido con la cuenta del jugador
var _token := ""          # el token de esta sesion (se reusa: la sala ya lo conoce)
var _token_hasta := 0

# Para la UI de la pausa: el overlay no esta y hay que enseñar la lista propia.
signal sin_overlay(connect: String)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # las invitaciones llegan tambien con un menu pausando
	# La SALA y los TRABAJADORES no son jugadores: la sala usa SteamServer y los trabajadores nada. Y en
	# headless (pruebas) tampoco: las que quieren Steam lo arrancan ellas.
	if DisplayServer.get_name() == "headless" or not Net._SALA.argumentos().is_empty() \
			or not Net._trab.argumentos().is_empty():
		return
	var motivo: String = _TUNEL.iniciar_cuenta()
	if motivo != "":
		print("[invitar] sin Steam: %s" % motivo)
		return
	listo = true
	Engine.get_singleton("Steam").join_game_requested.connect(_al_pedir_unirse)


func _process(_delta: float) -> void:
	# El tunel ya los corre mientras esta abierto; correrlos dos veces en un fotograma no hace nada.
	if listo:
		Engine.get_singleton("Steam").run_callbacks()


# ============================================================
#  INVITAR
# ------------------------------------------------------------

# ¿Se puede invitar desde aqui? Dentro de un mundo compartido con codigo de nube, conectado y con Steam.
func puedo_invitar() -> bool:
	return listo and Net.activo and Net.mundo_compartido and _codigo_mundo() != ""


func _codigo_mundo() -> String:
	var clave: String = Mundos.abierto if Mundos.abierto != "" else Mundos.uniendome
	if clave == "":
		return ""
	return String(Mundos.entrada(clave).get("id_nube", ""))


func _nombre_mundo() -> String:
	var clave: String = Mundos.abierto if Mundos.abierto != "" else Mundos.uniendome
	return String(Mundos.entrada(clave).get("nombre", "Mundo"))


# Abre el dialogo de invitar de Steam. Si no hay overlay, emite sin_overlay para que la pausa enseñe la
# lista propia. Devuelve "" o el motivo por el que no se puede.
func invitar() -> String:
	if not puedo_invitar():
		return "Solo se puede invitar dentro de un mundo compartido, con Steam abierto."
	var cadena: String = _cadena()
	var st: Object = Engine.get_singleton("Steam")
	if st.isOverlayEnabled():
		st.activateGameOverlayInviteDialogConnectString(cadena)
	else:
		print("[invitar] sin overlay de Steam: lista propia de amigos")
		sin_overlay.emit(cadena)
	return ""


# La cadena CONNECT, con un token que la sala ya conoce. El token se renueva cuando le queda poco.
func _cadena() -> String:
	var ahora: int = int(Time.get_unix_time_from_system())
	if _token == "" or _token_hasta - ahora < SEG_TOKEN / 2:
		_token = Crypto.new().generate_random_bytes(12).hex_encode()
		_token_hasta = ahora + SEG_TOKEN
		Net.registrar_invitacion(_token, SEG_TOKEN)
	return armar(_codigo_mundo(), Net._codigo, _token, _nombre_mundo())


# Los amigos que se pueden invitar: conectados, primero los que estan jugando a esto (el 480).
# [{"id", "nombre", "jugando"}]
func amigos() -> Array:
	if not listo:
		return []
	var st: Object = Engine.get_singleton("Steam")
	var out: Array = []
	for i in st.getFriendCount(_AMIGOS):
		var id: int = st.getFriendByIndex(i, _AMIGOS)
		if int(st.getFriendPersonaState(id)) == 0:   # desconectado
			continue
		var juego: Dictionary = st.getFriendGamePlayed(id)
		out.append({"id": id, "nombre": String(st.getFriendPersonaName(id)),
			"jugando": int(juego.get("id", 0)) == _TUNEL.APP_ID})
	out.sort_custom(func(a, b):
		if a["jugando"] != b["jugando"]:
			return a["jugando"]
		return String(a["nombre"]).naturalnocasecmp_to(String(b["nombre"])) < 0)
	return out


func invitar_a(amigo: int, cadena: String) -> bool:
	return listo and bool(Engine.get_singleton("Steam").inviteUserToGame(amigo, cadena))


# ============================================================
#  LA CADENA:  +oratoria <codigo> <contraseña> <token> <nombre>
#  Todo en uri_encode: la contraseña y el nombre pueden llevar espacios y acentos.
# ------------------------------------------------------------
static func armar(codigo: String, contrasena: String, token: String, nombre: String) -> String:
	return " ".join([MARCA, codigo.uri_encode(), contrasena.uri_encode(), token.uri_encode(),
		nombre.uri_encode()])


# {} si no es nuestra o le falta algo.
static func leer(cadena: String) -> Dictionary:
	var partes: PackedStringArray = cadena.strip_edges().split(" ", false)
	if partes.size() != 5 or partes[0] != MARCA:
		return {}
	var r := {"id_nube": partes[1].uri_decode().to_lower(), "contrasena": partes[2].uri_decode(),
		"token": partes[3].uri_decode(), "nombre": partes[4].uri_decode()}
	if r["id_nube"] == "" or r["contrasena"] == "" or r["token"] == "":
		return {}
	return r


# ============================================================
#  ME INVITAN
# ------------------------------------------------------------
func _al_pedir_unirse(amigo: int, cadena: String) -> void:
	var inv: Dictionary = leer(cadena)
	if inv.is_empty():
		print("[invitar] invitacion que no es nuestra: %s" % cadena)
		return
	inv["de"] = String(Engine.get_singleton("Steam").getFriendPersonaName(amigo))
	print("[invitar] %s me invita a %s (%s)" % [inv["de"], inv["nombre"], inv["id_nube"]])
	# YA ESTOY en ese mundo: nada que hacer.
	if Net.activo and Net.mundo_compartido and _codigo_mundo() == inv["id_nube"]:
		_avisar("Ya estás en «%s»." % inv["nombre"])
		return
	Mundos.invitacion = inv
	await _ir_al_menu_multi()


# Llevar al jugador al menu de Multijugador, guardando antes lo que tuviera entre manos. Si no se puede
# (una pelea delante), se le dice y la invitacion queda pendiente: la atendera el menu cuando llegue.
func _ir_al_menu_multi() -> void:
	var arbol := get_tree()
	var esc: Node = arbol.current_scene
	if esc != null and esc.scene_file_path == MULTI_MENU:
		if esc.has_method("atender_invitacion"):
			esc.atender_invitacion()
		return
	if Game.hay_pelea_en_pantalla() or Game.combate_activo():
		_avisar("Te invitan a «%s»: acaba la pelea y vuelve a pulsar Unirse." % Mundos.invitacion["nombre"])
		Mundos.invitacion = {}
		return
	if Net.activo:
		if not Net.mundo_compartido or Net.es_host:
			# Una sesion LAN de las de antes, o soy yo quien la aloja: cortarla por un clic en Steam
			# dejaria tirados a los demas.
			_avisar("Te invitan a «%s»: sal antes de esta partida en grupo." % Mundos.invitacion["nombre"])
			Mundos.invitacion = {}
			return
		# Estoy en el mundo compartido de OTRO: lo mismo que "Guardar y salir" de la pausa.
		_avisar("Guardando tu personaje para ir a «%s»…" % Mundos.invitacion["nombre"])
		await Ventana.pedir_guardado_al_anfitrion()
		await arbol.create_timer(0.2).timeout
		Net.desconectar()
	elif Mundos.abierto != "":
		await Mundos.cerrar_y_subir()
	elif Mundos.en_partida():
		# Jugando a solas en una ranura.
		Perfil.guardar_actual()
	Game.limpiar_modales()
	arbol.change_scene_to_file(MULTI_MENU)


func _avisar(texto: String) -> void:
	print("[invitar] " + texto)
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("mostrar_aviso_esquina"):
		hud.mostrar_aviso_esquina(texto, 4.0)
