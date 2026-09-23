# PRUEBA (sin ventana): LA FOTO DE LA ARENA NO SE COME AL PERSONAJE DEL MUNDO.
#
# Lo que paso el 23/09/2026: partida de un jugador nueva -> entras en la arena (se saca la foto de tu
# Aventurero) -> abres tu mundo multijugador y entras de invitado (se adopta tu personaje de alli) ->
# llegas al pueblo, que aplica la foto de la arena (town._ready -> salir_de_arena) -> tu personaje del
# mundo queda pisado por el Aventurero, y ese estado es el que se guarda en el mundo y se sube.
#
# Aqui se hace el mismo camino, sin red: los pasos del invitado son las mismas funciones que llama
# net al recibir su JugadorData (limpiar_mundo_heredado + aplicar_jugador_mundo).
#   godot --headless --path . res://tools/prueba_foto_arena_invitado.tscn   (tarda segundos)
extends Node

var _malos: int = 0


func _ok(texto: String, cond: bool) -> void:
	print(("  ok   " if cond else "  MAL  ") + texto)
	if not cond:
		_malos += 1


func _ready() -> void:
	print("=== LA FOTO DE LA ARENA Y EL INVITADO ===")
	# 1) Mi partida suelta: un Aventurero sin nada, y entro en la arena.
	Game.nueva_partida("Aventurero")
	Game.money = 0
	Game.entrar_en_arena()
	_ok("la arena ha sacado su foto", Game.en_foto_de_arena())

	# 2) Entro de invitado en mi mundo: me dan a MI personaje de alli, con su dinero.
	var mio := PersonajeData.new()
	mio.nombre = "Agirato ochinan"
	var jd := JugadorData.new()
	jd.id = "prueba"
	jd.nombre_visible = "dasui"
	jd.personajes = [mio]
	jd.equipo = [mio]
	jd.dinero = 109102
	Game.limpiar_mundo_heredado()
	Game.aplicar_jugador_mundo(jd, 0)
	_ok("tras adoptar llevo a mi personaje del mundo", Game.lider() != null and Game.lider().nombre == "Agirato ochinan")

	# 3) Llego al pueblo: su red de seguridad de la arena.
	Game.salir_de_arena()
	_ok("en el pueblo sigo siendo mi personaje del mundo (soy '%s')" % Game.lider().nombre,
		Game.lider().nombre == "Agirato ochinan")
	_ok("y con mi dinero del mundo (tengo %d)" % Game.money, Game.money == 109102)
	# Y lo que le mandaria a la sala al guardar es eso mismo.
	var enviado: JugadorData = Game.mi_jugador_data()
	_ok("lo que se manda a guardar lleva mi dinero (%d)" % enviado.dinero, enviado.dinero == 109102)

	Game.mundo_compartido = false
	print("RESULTADO: %s (%d mal)" % ["TODO BIEN" if _malos == 0 else "HAY FALLOS", _malos])
	get_tree().quit(1 if _malos > 0 else 0)
