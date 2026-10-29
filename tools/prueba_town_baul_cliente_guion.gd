# PRUEBA DE RED DEL BAUL COMPARTIDO, guion del JUGADOR B (ver prueba_town_baul_red_guion.gd). Obedece las fases de A y
# apunta lo que ve con el prefijo [B].
extends "res://tools/prueba_town_dos_comun.gd"


func _ready() -> void:
	prefijo = "[B] "
	var baba: MaterialData = load("res://resources/materials/baba_slime.tres")
	var runa: MaterialData = load("res://resources/materials/runa_slime.tres")
	Game.baul.vaciar()
	await _esperar(0.5)
	if (await entrar_en_la_sala()).is_empty():
		print("[B] RESULTADO: FALLAN %d" % maxi(1, fallos.size()))
		get_tree().quit(1)
		return
	# 0) AL ENTRAR NO ME LLEGA EL BAUL; ni el cambio que hace A mientras no lo pido. Al pedirlo, entero.
	await _esperar(3.0)
	print("[B] dato baul_al_entrar=%d" % Game.baul.total())
	await esperar_fase(1, 60.0)
	await _esperar(2.0)   # lo que tardaria en llegarme el cambio de A, si me llegara
	print("[B] dato delta_sin_baul=%d" % Game.baul.total())
	await Net.hogar.necesito_baul()
	print("[B] dato baul_listo=%d" % Game.baul.total())
	print("[B] dato danadas_b=%d" % Game.en_hogar(load("res://resources/materials/baba_fuego.tres"),
		MaterialItem.Calidad.DANADO))
	var t := 0.0

	# 1) Gasto 6 babas (3 normales) y añado una runa, como hace un taller. Tiene que ser instantaneo.
	await esperar_fase(2, 60.0)
	var t0 := Time.get_ticks_msec()
	var ok: bool = await Net.hogar.abrir_taller()
	Game._consumir_unidades(baba, 6)
	Game.baul.anadir(MaterialItem.crear(runa, MaterialItem.Calidad.NORMAL))
	Net.hogar.cerrar_taller()
	var ms: int = Time.get_ticks_msec() - t0
	_ok(ok, "el taller se abre sin esperar a nadie")
	print("[B] dato ms_accion=%d" % ms)

	# 2) Lo que gasta A me llega.
	await esperar_fase(3, 30.0)
	t = 0.0
	while _cuantos(runa) != 9 and t < 10.0:
		await _esperar(0.1)
		t += 0.1
	print("[B] dato visto_host=%d" % _cuantos(runa))

	# 3) Voy a por la ULTIMA runa real a la vez que A (que tiene el permiso cogido): espero y, si ya no esta, nada.
	await esperar_fase(4, 30.0)
	var real: MaterialData = load("res://resources/materials/runa_real.tres")
	var t1 := Time.get_ticks_msec()
	var ok3: bool = await Net.hogar.abrir_taller()
	print("[B] dato ms_espera_real=%d" % (Time.get_ticks_msec() - t1))
	var gasto := 0
	if ok3 and _cuantos(real) > 0:
		gasto = Game.baul.quitar_material(real, MaterialItem.Calidad.NORMAL, 1)
	Net.hogar.cerrar_taller()
	_ok(ok3, "me dan el permiso en cuanto lo suelta A")
	print("[B] dato gasto_real=%d" % gasto)
	await _esperar(1.5)
	print("[B] dato baul_b=%d" % Game.baul.total())
	await esperar_fase(9, 30.0)
	print("[B] RESULTADO: ", "TODO PASA" if fallos.is_empty() else "FALLAN %d" % fallos.size())
	get_tree().quit()


func _cuantos(mat: MaterialData) -> int:
	return Game.en_hogar(mat)
