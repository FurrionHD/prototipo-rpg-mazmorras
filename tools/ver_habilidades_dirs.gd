# FOTOS DE LAS HABILIDADES DEL MAPA EN CINCO DIRECCIONES (N, NE, E, SE, S), para mirarlas todas de un
# vistazo (lo pidio el usuario el 24/09). Entra en la arena de pruebas, abre una pelea con enemigos
# alrededor y, en tu turno, apunta cada habilidad hacia cada direccion: huella en el suelo, el
# personaje mirando hacia alli y su efecto (suelo que se rompe, estela, cuchilla...) congelado en su
# mejor momento. Sin interfaz y recortado alrededor del personaje. CON VENTANA.
#   HAB_SALIDA=/carpeta HAB_LISTA=molinete,segar godot --path . res://tools/ver_habilidades_dirs.tscn
extends Node

const HABILIDADES := [
	"golpe_sismico", "martillo_de_guerra", "rompecorazas", "onda_expansiva", "temblor",
	"molinete", "segar", "tajo_devastador", "tajo_del_verdugo", "grito_de_guerra",
]
const ARMA := {"golpe_sismico": "martillo", "martillo_de_guerra": "martillo", "rompecorazas": "martillo",
	"onda_expansiva": "martillo", "temblor": "martillo"}
const DIRS := [["N", Vector2(0, -1)], ["NE", Vector2(1, -1)], ["E", Vector2(1, 0)],
	["SE", Vector2(1, 1)], ["S", Vector2(0, 1)]]
# Un enemigo en cada direccion, a la distancia a la que suele estar uno en una pelea.
const DIST_BICHO := 62.0
# El momento de cada efecto que se fotografia (segundos desde el golpe), por SueloRoto.Tipo.
const MOMENTO := {0: 0.9, 1: 0.75, 2: 0.2, 3: 0.2, 4: 0.2}
var _salida: String = ""


func _ready() -> void:
	_salida = OS.get_environment("HAB_SALIDA")
	if _salida == "":
		_salida = "user://habilidades"
	DirAccess.make_dir_recursive_absolute(_salida)
	call_deferred("_empezar")


func _empezar() -> void:
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	_correr()


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _esperar_a(cond: Callable, tope_s: float) -> bool:
	var t0: int = Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > tope_s * 1000.0:
			return false
		await get_tree().process_frame
	return true


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	await _esperar(5)
	Game.entrar_arena_de_pruebas()
	await _esperar(15)
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if jug == null:
		print("MAL: no hay jugador")
		get_tree().quit(1)
		return
	var tipos := ["rata", "slime", "rata", "slime", "rata"]
	for i in DIRS.size():
		Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/%s.tres" % tipos[i],
			jug.global_position + (DIRS[i][1] as Vector2).normalized() * DIST_BICHO, {})
		await _esperar(3)
	await _esperar(20)
	var enemigos: Array = get_tree().get_nodes_in_group("enemy")
	# Tan cerca, alguno puede haberla empezado ya al verte: entonces se usa esa.
	if not Game.start_combat(enemigos, false):
		print("(la pelea ya estaba abierta)")
	var combat: Node = null
	await _esperar(5)
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	if combat == null or not combat.tactico:
		print("MAL: la pelea no es tactica")
		get_tree().quit(1)
		return
	var t = combat.turno_mapa
	if not await _esperar_a(func() -> bool: return t._fase == t.Fase.MOVIENDO, 20.0):
		print("MAL: no llego un turno en el que se pueda andar")
		get_tree().quit(1)
		return
	var pedidas: String = OS.get_environment("HAB_LISTA")
	var capa: CanvasLayer = combat.get_parent() as CanvasLayer
	for nom in HABILIDADES:
		if pedidas != "" and not (nom in pedidas.split(",")):
			continue
		var ab: AbilityData = load("res://resources/abilities/%s.tres" % nom)
		for d in DIRS:
			var pies: Vector2 = t.pies_de(t._quien)
			var hacia: Vector2 = pies + (d[1] as Vector2).normalized() * 70.0
			t.apuntar(ab)
			t._refrescar_apunte(hacia)
			var f = t.forma_de(ab, t._quien, hacia)
			# El efecto, congelado en su momento.
			var fx: Node2D = null
			if ab.suelo_roto >= 0:
				var f_suelo = f
				if ab.suelo_roto == SueloRoto.Tipo.ESTELA:
					f_suelo = CombatFormas.cono(pies, f.centro - pies, EstelaGolpe.RADIO, 0.0)
				fx = SueloRoto.lanzar(t._arena(), f_suelo, ab.suelo_roto, 777, ab.forma_nucleo)
				await _esperar(1)
				fx.set_process(false)
				fx.set("_t", float(MOMENTO.get(ab.suelo_roto, 0.5)))
				for hijo in ["_geiser", "_aire"]:
					if fx.get(hijo) != null:
						(fx.get(hijo) as Node2D).queue_redraw()
				fx.queue_redraw()
			if capa != null:
				capa.visible = false
			# El raton de verdad manda en la huella (cada movimiento la rehace): se lleva al punto apuntado.
			var vp: Viewport = get_tree().root.get_viewport()
			vp.warp_mouse(vp.get_canvas_transform() * hacia)
			await _esperar(2)
			t._refrescar_apunte(hacia)
			await _esperar(2)
			await _foto(nom, d[0], pies, f)
			if capa != null:
				capa.visible = true
			if fx != null:
				fx.queue_free()
			t._cancelar_apunte()
			await _esperar(2)
	print("=== FIN ===")
	get_tree().quit(0)


# Recorta alrededor del personaje lo justo para que entre la forma entera, igual en las cinco
# direcciones de una misma habilidad.
func _foto(nom: String, dir: String, pies: Vector2, f) -> void:
	await RenderingServer.frame_post_draw
	var vp: Viewport = get_tree().root.get_viewport()
	var img: Image = vp.get_texture().get_image()
	var xf: Transform2D = vp.get_canvas_transform()
	var zoom: float = xf.get_scale().x
	var medida: float = maxf(maxf(f.radio, f.largo), 40.0) + 45.0
	var centro: Vector2 = xf * (pies + Vector2(0, -10))
	var lado: int = int(medida * 2.0 * zoom)
	var r := Rect2i(Vector2i(centro) - Vector2i(lado, lado) / 2, Vector2i(lado, lado))
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var recorte: Image = img.get_region(r)
	# A doble tamaño y con el pixel nitido: asi se miran bien en el escritorio.
	recorte.resize(recorte.get_width() * 2, recorte.get_height() * 2, Image.INTERPOLATE_NEAREST)
	var pref: String = ARMA.get(nom, "mandoble")
	var ruta: String = "%s/%s_%s_%s.png" % [_salida, pref, nom, dir]
	recorte.save_png(ruta)
	print("[foto] ", ruta)
