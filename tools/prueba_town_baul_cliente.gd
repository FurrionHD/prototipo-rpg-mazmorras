# PRUEBA DE RED DEL BAUL COMPARTIDO, guion del JUGADOR B (ver prueba_town_baul_red.gd). Obedece las fases del host y
# apunta lo que ve con el prefijo [B].
extends "res://tools/prueba_town_dos_comun.gd"


func _ready() -> void:
	prefijo = "[B] "
	var args := OS.get_cmdline_user_args()
	var i := args.find("cliente")
	if i < 0 or args.size() < i + 4:
		print("[B] faltan argumentos: cliente <ip> <puerto> <codigo>")
		get_tree().quit(1)
		return
	var baba: MaterialData = load("res://resources/materials/baba_slime.tres")
	var runa: MaterialData = load("res://resources/materials/runa_slime.tres")
	Game.almacen_materiales.clear()
	await _esperar(0.5)
	_ok(Net.unirse(args[i + 1], args[i + 3], int(args[i + 2])) == OK, "me conecto a la sala")
	var t := 0.0
	while Game.almacen_materiales.size() < 19000 and t < 40.0:
		await _esperar(0.5)
		t += 0.5
	print("[B] dato baul_listo=%d" % Game.almacen_materiales.size())

	# 1) Gasto 6 babas (3 normales) y añado una runa, como hace un taller. Tiene que ser instantaneo.
	await esperar_fase(1, 60.0)
	var t0 := Time.get_ticks_msec()
	var ok: bool = await Net.hogar.abrir_taller()
	Game._consumir_unidades(baba, 6)
	Game.almacen_materiales.append(MaterialItem.crear(runa, MaterialItem.Calidad.NORMAL))
	Net.hogar.cerrar_taller()
	var ms: int = Time.get_ticks_msec() - t0
	_ok(ok, "el taller se abre sin esperar a nadie")
	print("[B] dato ms_accion=%d" % ms)

	# 2) Lo que gasta el host me llega.
	await esperar_fase(2, 30.0)
	t = 0.0
	while _cuantos(runa) != 9 and t < 10.0:
		await _esperar(0.1)
		t += 0.1
	print("[B] dato visto_host=%d" % _cuantos(runa))

	# 3) Baul ABIERTO (como la pestaña de materiales del hogar): meto 5 babas y NO cierro.
	await esperar_fase(3, 30.0)
	Net.hogar.abrir_taller()
	for k in 5:
		Game.almacen_materiales.append(MaterialItem.crear(baba, MaterialItem.Calidad.NORMAL))
	await esperar_fase(9, 30.0)
	Net.hogar.cerrar_taller()
	print("[B] RESULTADO: ", "TODO PASA" if fallos.is_empty() else "FALLAN %d" % fallos.size())
	get_tree().quit()


func _cuantos(mat: MaterialData) -> int:
	var n := 0
	for m in Game.almacen_materiales:
		if m != null and m.data == mat:
			n += 1
	return n
