# ============================================================
#  dev_noche.gd  --  HERRAMIENTA, no parte del juego.
#
#  El DIA Y LA NOCHE del pueblo (CicloDia + LuzPueblo). Monta el pueblo de verdad, fija la hora con
#  CicloDia.hora_forzada y saca capturas en tools/salida/noche_*.png de cada momento del ciclo, en
#  la plaza y en el pueblo entero.
#
#  Sin ventana solo comprueba la curva (que el ciclo cuadra: 28 min de dia, 12 de noche).
#  Con ventana: herramientas/ver_noche.bat. Se cierra sola.
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"
const PUEBLO := "res://scenes/levels/town.tscn"
const PartidaDePrueba = preload("res://tools/visores/partida_de_prueba.gd")

# Momentos del ciclo que se fotografian (segundo dentro de CicloDia.CICLO).
const MOMENTOS := {
	"1_dia": 800.0,
	"2_atardecer_empieza": 1590.0,
	"3_atardecer": 1620.0,
	"4_atardecer_acaba": 1660.0,
	"5_noche": 2000.0,
	"6_amanecer": 60.0,
}

var _fallos: int = 0
var _hechas: int = 0
var _con_ventana: bool = DisplayServer.get_name() != "headless"
var _pueblo: Node2D = null
var _jugador: Node2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_curva()
	_hoja_de_llamas()
	if _con_ventana:
		DisplayServer.window_set_size(Vector2i(1280, 720))
		DirAccess.make_dir_recursive_absolute(SALIDA)
		PartidaDePrueba.llenar()
		get_tree().current_scene.scene_file_path = PUEBLO
		_pueblo = (load(PUEBLO) as PackedScene).instantiate() as Node2D
		add_child(_pueblo)
		_jugador = _pueblo.get_node("Player") as Node2D
		await get_tree().process_frame
		await get_tree().process_frame
		await _capturas()
	CicloDia.hora_forzada = -1.0
	if _fallos == 0:
		print("\nOK: las %d comprobaciones pasan." % _hechas)
	else:
		printerr("\nFALLAN %d de %d comprobaciones." % [_fallos, _hechas])
	get_tree().quit(1 if _fallos > 0 else 0)


func _curva() -> void:
	print("=== LA CURVA ===")
	var noche_s: float = 0.0
	var dia_s: float = 0.0
	var paso: float = 1.0
	var s: float = 0.0
	while s < CicloDia.CICLO:
		if CicloDia.noche(s) >= 0.5:
			noche_s += paso
		else:
			dia_s += paso
		s += paso
	# 12 min de noche cerrada + la mitad oscura del atardecer y del amanecer (1 min cada una).
	_ok("12 min de noche cerrada y 28 de dia (oscuro %.1f / claro %.1f min)" % [noche_s / 60.0, dia_s / 60.0],
		absf(noche_s - 840.0) <= 2.0)
	_ok("mediodia es blanco", CicloDia.tinte(800.0) == Color(1, 1, 1))
	_ok("la noche es azul", CicloDia.tinte(2000.0).b > CicloDia.tinte(2000.0).r)
	_ok("el ciclo empalma (fin de noche = principio del amanecer)",
		CicloDia.tinte(CicloDia.CICLO - 0.01).is_equal_approx(CicloDia.tinte(0.0)))
	_ok("de dia las luces apagadas", CicloDia.luces(0.0, 800.0) == 0.0)
	_ok("de noche encendidas", CicloDia.luces(1.0, 2000.0) == 1.0)
	_ok("se encienden durante el atardecer", CicloDia.luces(0.0, CicloDia.T_NOCHE - 1.0) == 1.0
		and CicloDia.luces(0.0, CicloDia.T_ATARDECER + 30.0) == 0.0)


# LOS 8 FUEGOS: una fila por perfil con todos sus fotogramas, x4, sobre el azul de la noche.
func _hoja_de_llamas() -> void:
	print("\n=== LOS FUEGOS ===")
	DirAccess.make_dir_recursive_absolute(SALIDA)
	var z: int = 4
	var celda := Vector2i(40, 40) * z
	var max_f: int = 0
	for p in FuegoSprites.PERFILES:
		max_f = maxi(max_f, int(p["frames"]))
	var hoja := Image.create(celda.x * max_f, celda.y * FuegoSprites.cuantos(), false, Image.FORMAT_RGBA8)
	hoja.fill(Color(0.10, 0.12, 0.22))
	var firmas := {}
	for i in FuegoSprites.cuantos():
		var p: Dictionary = FuegoSprites.PERFILES[i]
		var firma := ""
		for k in int(p["frames"]):
			var f: Image = FuegoSprites.fotograma(i, k)
			var opacos: int = 0
			for y in f.get_height():
				for x in f.get_width():
					if f.get_pixel(x, y).a > 0.0:
						opacos += 1
			_ok("fuego %d fotograma %d tiene llama (%d px)" % [i, k, opacos], opacos > 20)
			firma += str(opacos) + ","
			f.resize(f.get_width() * z, f.get_height() * z, Image.INTERPOLATE_NEAREST)
			var o := Vector2i(k * celda.x + (celda.x - f.get_width()) / 2, i * celda.y + celda.y - f.get_height() - 8)
			hoja.blend_rect(f, Rect2i(Vector2i.ZERO, f.get_size()), o)
		firmas[firma] = true
	_ok("los %d fuegos son distintos" % FuegoSprites.cuantos(), firmas.size() == FuegoSprites.cuantos())
	hoja.save_png("%snoche_llamas.png" % SALIDA)


func _capturas() -> void:
	var cam: Camera2D = _jugador.get_node("Camera2D") as Camera2D
	cam.position_smoothing_enabled = false
	for m in MOMENTOS:
		CicloDia.hora_forzada = float(MOMENTOS[m])
		cam.zoom = Vector2(1.8, 1.8)
		_jugador.global_position = PuebloPlano.aparicion_px()
		await _captura("plaza_" + m)
	# DE NOCHE, cerca de lo que alumbra: el altar y las casas con ventanas de cada tipo.
	CicloDia.hora_forzada = float(MOMENTOS["5_noche"])
	_jugador.global_position = PuebloPlano.centro_px(PuebloPlano.ALTAR + Vector2i(0, 2))
	await _captura("luz_altar")
	# Las luces nuevas: la plaza con sus braseros, un porton y un tramo de calle con postes.
	_jugador.global_position = PuebloPlano.aparicion_px() + Vector2(0, -40)
	await _captura("luz_plaza")
	_jugador.global_position = PuebloPlano.centro_px(Vector2i(6, 41))
	await _captura("luz_porton_oeste")
	_jugador.global_position = PuebloPlano.centro_px(Vector2i(24, 32))
	await _captura("luz_calle_alta")
	_jugador.global_position = PuebloPlano.centro_px(Vector2i(36, 52))
	await _captura("luz_orilla")
	CicloDia.hora_forzada = float(MOMENTOS["1_dia"])
	_jugador.global_position = PuebloPlano.aparicion_px() + Vector2(0, -40)
	# Apagar lleva 0.6 s (Antorcha): esperar a que acabe, o la foto sale a medias.
	await get_tree().create_timer(1.0).timeout
	await _captura("dia_plaza_apagadas")
	# Y encendiendose, a medio crecer: la llama tiene que nacer DESDE la base, pegada al soporte.
	CicloDia.hora_forzada = float(MOMENTOS["5_noche"])
	await get_tree().create_timer(0.3).timeout
	await _captura("plaza_encendiendose")
	await get_tree().create_timer(1.0).timeout
	CicloDia.hora_forzada = float(MOMENTOS["5_noche"])
	for clave in ["taberna", "herreria", "boticaria", "carpinteria"]:
		for casa in PuebloPlano.CASAS:
			if casa["clave"] == clave:
				_jugador.global_position = PuebloPlano.centro_px(PuebloPlano.puerta_de(casa)) + Vector2(0, 40)
				await _captura("luz_" + clave)
	# PRIMER PLANO de cada fachada con cartel: el vidrio encendido NO puede cortar el cartel.
	cam.zoom = Vector2(4, 4)
	for casa in PuebloPlano.CASAS:
		var dib: String = String(casa["clave"])
		if not CasaSprites.CASAS.has(dib) or String(CasaSprites.CASAS[dib]["cartel"]) == "":
			continue
		# La camara sobre la fachada (la gente, fuera: no se busca taparla).
		_jugador.global_position = PuebloPlano.centro_px(PuebloPlano.puerta_de(casa)) + Vector2(0, -40)
		await _captura("cartel_" + dib)
	cam.zoom = Vector2(1.8, 1.8)
	# El pueblo entero, solo de dia y de noche.
	var tam: Vector2 = PuebloPlano.tam_px()
	cam.limit_left = -100000
	cam.limit_top = -100000
	cam.limit_right = 100000
	cam.limit_bottom = 100000
	var z: float = minf(1280.0 / tam.x, 720.0 / tam.y)
	cam.zoom = Vector2(z, z)
	_jugador.global_position = tam * 0.5
	for m in ["1_dia", "5_noche"]:
		CicloDia.hora_forzada = float(MOMENTOS[m])
		await _captura("entero_" + m)


func _captura(nombre: String) -> void:
	await get_tree().process_frame
	for n in get_tree().get_nodes_in_group("aliado"):
		if n != _jugador and n is Node2D:
			(n as Node2D).global_position = Vector2(-5000, -5000)
	(_jugador.get_node("Camera2D") as Camera2D).reset_smoothing()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%snoche_%s.png" % [SALIDA, nombre])


func _ok(que: String, cond: bool) -> void:
	_hechas += 1
	if cond:
		print("  ok   %s" % que)
	else:
		_fallos += 1
		printerr("  FALLA %s" % que)
