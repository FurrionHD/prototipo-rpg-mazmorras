# PRUEBA DE RED DEL BAUL COMPARTIDO (08/10/2026, "el taller al instante"). POR LA SALA (fase 2, paso 6): A (este
# proceso) y B entran como clientes en la sala de la RANURA 89 (ver prueba_town_sala_comun.gd).
#   godot --headless --path . res://tools/prueba_town_baul_red.tscn -- nube_local
# Con un baul GORDO (19.000 materiales, como el del usuario), puesto en la ranura:
#   1) B gasta 6 unidades de baba (3 normales) y añade una runa: en B es instantaneo y a A le llega solo el cambio, en menos de 2 s;
#   2) A gasta 2 runas: B lo ve;
#   3) los dos van a por la ULTIMA runa a la vez: uno espera al otro y se gasta una sola (sin duplicados).
extends "res://tools/prueba_town_sala_comun.gd"

const RELLENO := 19000
const TOTAL := RELLENO + 30 + 10


func _ready() -> void:
	prefijo = ""
	slot = 89
	puerto = 24612
	registro_b = "user://logs/prueba_baul_b.log"
	falta_b = -1
	escribir_fase(0)
	var relleno: MaterialData = load("res://resources/materials/baba_fuego.tres")
	var baba: MaterialData = load("res://resources/materials/baba_slime.tres")
	var runa: MaterialData = load("res://resources/materials/runa_slime.tres")
	var llenar := func(d: SaveData) -> void:
		var m := Monton.new()
		for i in RELLENO:
			m.anadir(MaterialItem.crear(relleno, MaterialItem.Calidad.NORMAL))
		for i in 30:
			m.anadir(MaterialItem.crear(baba, MaterialItem.Calidad.NORMAL))
		for i in 10:
			m.anadir(MaterialItem.crear(runa, MaterialItem.Calidad.NORMAL))
		d.almacen_materiales = m.a_lista()
	if not preparar_mundo(GRUPO_A, CASA_A, GRUPO_B, CASA_B, llenar) or not await abrir_sala_y_entrar():
		await _fin()
		return
	var t := 0.0
	while Game.baul.total() < TOTAL and t < 40.0:
		await _esperar(0.5)
		t += 0.5
	_ok(Game.baul.total() == TOTAL, "tengo el espejo del baul entero (%d, %.1f s)" % [Game.baul.total(), t])
	if not await lanzar_b("prueba_town_baul_cliente"):
		await _fin()
		return
	_ok(await _dato_de_b("baul_listo", 40.0) == Game.baul.total(), "B tiene el espejo del baul entero")

	# 1) B gasta y añade. Antes, 3 s: justo al entrar, lo que B le pide a la sala va en cola detras de lo que la sala
	# le esta mandando (el baul de 19.000 y lo demas del alta) y el permiso tarda 1-2 s (la sala va a 20 fotogramas; en
	# la etapa 2 sube a 60). Lo que se mide aqui es la accion del taller, no la entrada.
	await _esperar(3.0)
	escribir_fase(1)
	t = 0.0
	while (_cuantos(baba) != 27 or _cuantos(runa) != 11) and t < 10.0:
		await _esperar(0.1)
		t += 0.1
	_ok(_cuantos(baba) == 27 and _cuantos(runa) == 11, "a A le llega lo de B: 30->27 babas (6 uds = 3 normales), 10->11 runas (%.1f s)" % t)
	_ok(t < 2.0, "y llega rapido (%.1f s)" % t)
	var ms: int = await _dato_de_b("ms_accion", 10.0)
	_ok(ms >= 0 and ms < 300, "en B la accion entera tarda %d ms" % ms)

	# 2) A gasta 2 runas.
	await Net.hogar.abrir_taller()
	for k in 2:
		_quitar(runa)
	Net.hogar.cerrar_taller()
	escribir_fase(2)
	_ok(await _dato_de_b("visto_host", 10.0) == 9, "B ve las 2 runas que gasto A")

	# 3) LOS DOS A POR LA ULTIMA RUNA REAL A LA VEZ. Solo hay una. A coge el permiso y lo retiene 1 s (como quien
	#    tarda); B lo intenta en ese momento: tiene que ESPERAR, y cuando le toca la runa ya no esta. Se gasta UNA.
	var real: MaterialData = load("res://resources/materials/runa_real.tres")
	await Net.hogar.abrir_taller()
	Game.baul.anadir(MaterialItem.crear(real, MaterialItem.Calidad.NORMAL))
	Net.hogar.cerrar_taller()
	await _esperar(1.0)
	_ok(await Net.hogar.abrir_taller(), "A coge el permiso")
	escribir_fase(3)
	await _esperar(1.0)   # B lo esta pidiendo ahora mismo
	_ok(_cuantos(real) == 1, "mientras lo tengo, nadie me toca la runa")
	_quitar(real)
	Net.hogar.cerrar_taller()
	var la_tuvo_b: int = await _dato_de_b("gasto_real", 10.0)
	_ok(la_tuvo_b == 0, "B esperó y, al tocarle, ya no estaba: no la gasta")
	var espera_b: int = await _dato_de_b("ms_espera_real", 10.0)
	_ok(espera_b >= 500 and espera_b < 3000, "B esperó a que soltara (%d ms)" % espera_b)
	await _esperar(1.0)
	_ok(_cuantos(real) == 0, "se gasto UNA runa, no dos ni ninguna de mas")
	_ok(Game.baul.total() == RELLENO + 27 + 9, "el baul de A cuadra (%d)" % Game.baul.total())
	_ok(await _dato_de_b("baul_b", 10.0) == Game.baul.total(), "y el de B es igual")
	await _fin()


func _cuantos(mat: MaterialData) -> int:
	return Game.en_hogar(mat)


func _quitar(mat: MaterialData) -> void:
	Game.baul.quitar_material(mat, MaterialItem.Calidad.NORMAL, 1)
