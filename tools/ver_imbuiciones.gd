# ============================================================
#  ver_imbuiciones.gd  --  HERRAMIENTA, no parte del juego.
#
#  Hojas de la IMBUICION PUESTA tal cual se ve jugando (MunecoJugador.poner_imbue + aura_imbue):
#    filo_<arma>.png   una fila por imbuicion (veneno, fuego, rayo, agua, luz, oscuridad) con el arma
#                      en guardia, y cuatro momentos seguidos en columnas: el efecto se MUEVE, y en una
#                      foto sola una llama o un rayito pueden no salir.
#    manto.png         lo mismo con el Manto (aura del cuerpo entero), sin arma.
#
#  Necesita VENTANA (con --headless no se dibuja nada):
#    Godot --path . res://tools/ver_imbuiciones.tscn -- [dir]      (dir 0..7, por defecto 1 = SE)
#  Sale en IMBUICIONES_SALIDA o, si no, en user://imbuiciones.
# ============================================================
extends Node

const LADO := 120
const ZOOM := 5
const MOMENTOS := 4
const ENTRE := 0.13   # segundos entre un momento y el siguiente
const FONDO := Color(0.11, 0.12, 0.15)
const ARMAS := ["martillo_grande", "mandoble", "hacha_grande", "daga", "estoque", "espada_corta", "espada_larga", "maza_peq"]


func _filas() -> Array:
	var E := Elementos.Elemento
	return [
		["veneno", 0, StatusEffects.Id.VENENO],
		["fuego", E.FUEGO, -1],
		["rayo", E.RAYO, -1],
		["agua", E.AGUA, -1],
		["luz", E.LUZ, -1],
		["oscuridad", E.OSCURIDAD, -1],
	]


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var dir: int = clampi(int(args[0]), 0, 7) if args.size() > 0 else 1
	var salida: String = OS.get_environment("IMBUICIONES_SALIDA")
	if salida == "":
		salida = "user://imbuiciones"
	DirAccess.make_dir_recursive_absolute(salida)
	var p: Node2D = get_tree().get_first_node_in_group("player")
	if p == null:
		push_error("[ver imbuiciones] no hay Player en la escena")
		get_tree().quit(1)
		return
	p.set_physics_process(false)
	var pj: PersonajeData = Game.lider()
	# IMBUICIONES_ARMAS=estoque,daga: solo esas (y sin la hoja del Manto).
	var pedidas: String = OS.get_environment("IMBUICIONES_ARMAS")
	for arma in ARMAS:
		if pedidas != "" and not (arma in pedidas.split(",")):
			continue
		pj.equipped_off = null
		pj.equipped_main = _arma_de_tipo(arma)
		p._pintar_cuerpo()
		await _hoja(p, "guardia_%d" % dir, false, "%s/filo_%s.png" % [salida, arma], 20)
	pj.equipped_main = null
	pj.equipped_off = null
	p._pintar_cuerpo()
	if pedidas == "":
		await _hoja(p, "idle_%d" % dir, true, "%s/manto.png" % salida, 34)
	print("[ver imbuiciones] ", ProjectSettings.globalize_path(salida))
	get_tree().quit()


# 'sube': cuanto se sube el recorte sobre el nodo (que esta en los PIES): el Manto necesita la cabeza
# entera y lo que le sale por encima.
func _hoja(p: Node2D, anim: String, cuerpo: bool, ruta: String, sube: int) -> void:
	var m: MunecoJugador = p._muneco
	var filas: Array = _filas()
	var out := Image.create(MOMENTOS * LADO, filas.size() * LADO, false, Image.FORMAT_RGBA8)
	out.fill(FONDO)
	for i in filas.size():
		var f: Array = filas[i]
		m.poner_imbue(ImbueVisual.codigo(int(f[1]), int(f[2]), cuerpo, 10))
		m.animar(anim)
		m.fijar(anim, 2)
		for k in MOMENTOS:
			await get_tree().create_timer(ENTRE).timeout
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img: Image = get_viewport().get_texture().get_image()
			var trozo: Image = img.get_region(Rect2i(img.get_width() / 2 - LADO / 2,
				img.get_height() / 2 - LADO / 2 - sube, LADO, LADO))
			out.blit_rect(trozo, Rect2i(0, 0, LADO, LADO), Vector2i(k * LADO, i * LADO))
	m.poner_imbue(0)
	out.resize(out.get_width() * ZOOM, out.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
	out.save_png(ruta)
	print("[ver imbuiciones] ", ruta)


func _arma_de_tipo(tn: String) -> WeaponData:
	var idx: int = ArmaSprites.TIPO_NOMBRE.find(tn)
	var d := DirAccess.open("res://resources/weapons/")
	if d == null or idx < 0:
		return null
	for f in d.get_files():
		if f.ends_with(".tres"):
			var w := load("res://resources/weapons/" + f) as WeaponData
			if w != null and int(w.tipo) == idx:
				return w
	return null
