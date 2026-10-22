# LA RANURA PASA A FORMATO DE MUNDO (fase 2, 20/10): toda partida va por la sala, tambien la de solo, y la sala abre
# mundos. Perfil.convertir_a_mundo la convierte UNA vez sin dejar de ser tu ranura. Aqui se mira que no se pierde
# NADA: lo de cada persona (grupo, dinero, bolsa, inventario, piso y posicion) despues de que lo adopte el jugador como
# lo haria al entrar en la sala, y lo del mundo (almacen, cofre, encargos, mazmorra, mapa) en lo que carga la sala.
# Y que la copia de seguridad es identica al original.
# Usa la RANURA 96 (no existe en el juego) con la nube apagada: las ranuras de verdad no se tocan. La borra al acabar.
#   godot --headless --path . res://tools/prueba_ranura_a_mundo.tscn
extends Node

const SLOT := 96

var _mal: int = 0


func _ready() -> void:
	call_deferred("_correr")


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


# Lo de una persona, tal y como lo tiene Game ahora.
func _persona() -> Dictionary:
	return {
		"dinero": Game.money,
		"grupo": Game.party.map(func(p): return p.nombre),
		"plantilla": Game.plantilla.map(func(p): return p.nombre),
		"bolsa": Game.bolsa.a_lista().size(),
		"armas_sueltas": Game._baul_sin_equipar().size(),
	}


# Lo del mundo.
func _mundo() -> Dictionary:
	return {
		"almacen": Game.baul.a_lista().size(),
		"cofre": Game.cofre_equipo.size(),
		"encargos": Game.encargos.size(),
		"pisos": Game.memoria_pisos.keys().size(),
		"mapa": Game.mapa_snapshot.size(),
	}


func _borrar_ranura() -> void:
	Perfil._cerrar_bd()
	PartidaBD.borrar(Perfil.ruta_bd(SLOT))
	if FileAccess.file_exists(Perfil.ruta(SLOT)):
		DirAccess.remove_absolute(Perfil.ruta(SLOT))


func _correr() -> void:
	Perfil.nube_activa = false   # la ranura de prueba no se sube a ninguna nube
	_borrar_ranura()
	# Una ranura de SOLO hecha de la partida de referencia: sin marca de mundo, dentro de la mazmorra y con posicion.
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if not (ref is SaveData):
		print("MAL: no esta tools/huellas/mundo_ref.tres")
		get_tree().quit(1)
		return
	var d: SaveData = ref
	d.mundo_compartido = false
	d.version_mundo = 0
	d.jugadores = {}
	d.en_mazmorra = true
	d.current_floor = 7
	# Con el trazado de ESTE build (mundo_ref es v1 y con eso cualquier piso se rehace y te saca al pueblo): asi se prueba
	# la rama de seguir dentro. La de salir al pueblo la cubre el mismo _ver de abajo cuando toca.
	d.trazado = SaveData.TRAZADO_ACTUAL
	d.pos_jugador = Vector2(321, 654)
	# GUARDADA A MEDIA PELEA (etapa 3, paso 7): la pelea pasa al formato de la sala, y la marca de su enemigo viaja en la
	# foto de su piso.
	var uid_pelea: String = String((d.plantilla[0] as PersonajeData).uid)
	d.pelea_a_medias = {"aliados": [{"uid": uid_pelea, "vol": {"hp": 12.0}}],
		"enemigos": [{"id": 0, "vivo": true, "vol": {"hp": 5.0}}], "log": ["a medias"]}
	var piso_marcado: int = -1
	for piso in d.memoria_pisos:
		var ens: Array = (d.memoria_pisos[piso] as Dictionary).get("enemigos", [])
		if not ens.is_empty() and ens[0].get("data") != null:
			ens[0]["id_pelea"] = 0
			piso_marcado = int(piso)
			break
	_ver(Perfil._guardar_bd(SLOT, d), "se hace la ranura de prueba")
	Perfil._cerrar_bd()

	print("1) lo que hay en la ranura de solo")
	_ver(Perfil.cargar(SLOT), "se carga")
	# Lo que haria el menu al cargarla en solo: seguir en el piso o salir al pueblo si se rehace con este build.
	var dentro_antes: bool = d.en_mazmorra and not Game.forzar_pueblo_al_cargar
	var persona_antes: Dictionary = _persona()
	var mundo_antes: Dictionary = _mundo()
	Perfil._cerrar_bd()
	Perfil.ranura_actual = 0
	_ver(not Perfil.es_mundo(SLOT), "todavia no es un mundo")
	var bytes_antes: PackedByteArray = FileAccess.get_file_as_bytes(Perfil.ruta_bd(SLOT))

	print("2) convertir")
	var r: Dictionary = Perfil.convertir_a_mundo(SLOT)
	_ver(r.get("ok", false) and not r.get("ya", true), "se convierte (%s)" % str(r.get("mensaje", "")))
	var respaldo: String = String(r.get("respaldo", ""))
	_ver(respaldo != "" and FileAccess.file_exists(respaldo), "hay copia de seguridad (%s)" % respaldo)
	_ver(FileAccess.get_file_as_bytes(respaldo) == bytes_antes, "la copia es identica a la ranura de antes")
	_ver(Perfil.es_mundo(SLOT), "ahora es un mundo")
	_ver(Perfil.ranura_actual == 0 and Perfil._bd == null, "y este juego la suelta (la llevara su sala)")
	var r2: Dictionary = Perfil.convertir_a_mundo(SLOT)
	_ver(r2.get("ok", false) and r2.get("ya", false), "convertirla otra vez no hace nada")

	print("3) la abre la sala")
	Game.sin_jugador = true
	Game.sala_dueno = Identidad.id
	var datos: SaveData = Perfil._inspeccionar_bd(SLOT, BDFilas.Ids.new()).get("datos")
	_ver(datos != null and datos.mundo_compartido, "la sala la lee como mundo")
	Game.importar_partida(datos)
	_ver(Game.jugadores_mundo.has(Identidad.id), "y en el estan mis personajes, a mi nombre")
	_ver(Game.plantilla.is_empty() and Game.party.is_empty(), "la sala no juega con ellos (grupo vacio)")
	if dentro_antes:
		var pg: Array = datos.sesion_peleas
		var fila: Dictionary = (pg[0]["estado"]["aliados"][0] as Dictionary) if pg.size() == 1 else {}
		_ver(pg.size() == 1 and String(pg[0].get("lugar", "")) == "piso:7" and int(pg[0].get("base", -1)) == 0
			and String(fila.get("uid", "")) == uid_pelea and String(fila.get("ident", "")) == Identidad.id
			and (fila.get("ficha", {}) as Dictionary).has("nombre") and datos.pelea_a_medias.is_empty(),
			"la pelea a medias pasa a la sala, a mi nombre y con su ficha (%d)" % pg.size())
	if piso_marcado >= 0:
		var foto: Array = (datos.sesion_fotos_piso.get(piso_marcado, {}) as Dictionary).get("enemigos", [])
		_ver(not foto.is_empty() and int(foto[0].get("id_pelea", -1)) == 0, "la marca de su enemigo viaja en la foto del piso %d" % piso_marcado)
	var mundo_sala: Dictionary = _mundo()
	_ver(mundo_sala == mundo_antes, "lo del mundo, igual: %s / antes %s" % [mundo_sala, mundo_antes])

	print("4) entro yo y adopto mi ficha")
	var jd: JugadorData = Game.jugadores_mundo[Identidad.id]
	Game.sin_jugador = false
	Game.aplicar_jugador_mundo(jd, 0)
	var persona_despues: Dictionary = _persona()
	_ver(persona_despues == persona_antes, "lo mio, igual: %s / antes %s" % [persona_despues, persona_antes])
	_ver(jd.en_mazmorra == dentro_antes, "estoy donde me pondria cargarla en solo (en la mazmorra: %s)" % dentro_antes)
	if dentro_antes:
		_ver(jd.current_floor == 7 and jd.pos.distance_to(Vector2(321, 654)) < 0.5,
			"y en el piso 7, en mi sitio (%d, %s)" % [jd.current_floor, jd.pos])

	Game.sala_dueno = ""
	Game.mundo_compartido = false
	Game.jugadores_mundo.clear()
	_borrar_ranura()
	if respaldo != "":
		for extra in ["", "-wal", "-shm"]:
			DirAccess.remove_absolute(respaldo + extra)
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(0 if _mal == 0 else 1)
