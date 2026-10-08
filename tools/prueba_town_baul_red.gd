# PRUEBA DE RED DEL BAUL COMPARTIDO (08/10/2026, "el taller al instante"): este proceso es el HOST y lanza al jugador B
# (tools/prueba_town_baul_cliente.tscn) como otro Godot sin ventana. El nombre lleva "town" por la guarda de Net.hostear.
#   godot --headless --path . res://tools/prueba_town_baul_red.tscn
# Con un baul GORDO (19.000 materiales, como el del usuario):
#   1) B gasta 6 unidades de baba (3 normales) y añade una runa: en B es instantaneo y al host le llega solo el cambio, en menos de 2 s;
#   2) el host gasta 2 runas: B lo ve;
#   3) los dos van a por la ULTIMA runa a la vez: uno espera al otro y se gasta una sola (sin duplicados).
extends "res://tools/prueba_town_dos_comun.gd"

const PUERTO := 24611
const REGISTRO_B := "user://logs/prueba_baul_b.log"
const RELLENO := 19000
var _pid_b := 0


func _ready() -> void:
	prefijo = ""
	escribir_fase(0)
	if FileAccess.file_exists(REGISTRO_B):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(REGISTRO_B))
	var relleno: MaterialData = load("res://resources/materials/baba_fuego.tres")
	var baba: MaterialData = load("res://resources/materials/baba_slime.tres")
	var runa: MaterialData = load("res://resources/materials/runa_slime.tres")
	Game.almacen_materiales.clear()
	for i in RELLENO:
		Game.almacen_materiales.append(MaterialItem.crear(relleno, MaterialItem.Calidad.NORMAL))
	for i in 30:
		Game.almacen_materiales.append(MaterialItem.crear(baba, MaterialItem.Calidad.NORMAL))
	for i in 10:
		Game.almacen_materiales.append(MaterialItem.crear(runa, MaterialItem.Calidad.NORMAL))
	await _esperar(0.5)
	_ok(Net.hostear("abc", PUERTO) == OK, "sala abierta")
	_pid_b = _lanzar_b()
	var t := 0.0
	while Net._num_humanos < 2 and t < 40.0:
		await _esperar(0.5)
		t += 0.5
	_ok(Net._num_humanos == 2, "B entra en la sala (%.1f s)" % t)
	if Net._num_humanos < 2:
		await _fin()
		return
	_ok(await _dato_de_b("baul_listo", 40.0) == Game.almacen_materiales.size(), "B tiene el espejo del baul entero")

	# 1) B gasta y añade.
	escribir_fase(1)
	t = 0.0
	while (_cuantos(baba) != 27 or _cuantos(runa) != 11) and t < 10.0:
		await _esperar(0.1)
		t += 0.1
	_ok(_cuantos(baba) == 27 and _cuantos(runa) == 11, "al host le llega lo de B: 30->27 babas (6 uds = 3 normales), 10->11 runas (%.1f s)" % t)
	_ok(t < 2.0, "y llega rapido (%.1f s)" % t)
	var ms: int = await _dato_de_b("ms_accion", 10.0)
	_ok(ms >= 0 and ms < 300, "en B la accion entera tarda %d ms" % ms)

	# 2) El host gasta 2 runas.
	Net.hogar.abrir_taller()
	for k in 2:
		_quitar(runa)
	Net.hogar.cerrar_taller()
	escribir_fase(2)
	_ok(await _dato_de_b("visto_host", 10.0) == 9, "B ve las 2 runas que gasto el host")

	# 3) LOS DOS A POR LA ULTIMA RUNA REAL A LA VEZ. Solo hay una. El host coge el permiso y lo retiene 1 s (como quien
	#    tarda); B lo intenta en ese momento: tiene que ESPERAR, y cuando le toca la runa ya no esta. Se gasta UNA.
	var real: MaterialData = load("res://resources/materials/runa_real.tres")
	Net.hogar.abrir_taller()
	Game.almacen_materiales.append(MaterialItem.crear(real, MaterialItem.Calidad.NORMAL))
	Net.hogar.cerrar_taller()
	await _esperar(1.0)
	_ok(await Net.hogar.abrir_taller(), "el host coge el permiso")
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
	_ok(Game.almacen_materiales.size() == RELLENO + 27 + 9, "el baul del host cuadra (%d)" % Game.almacen_materiales.size())
	_ok(await _dato_de_b("baul_b", 10.0) == Game.almacen_materiales.size(), "y el de B es igual")
	await _fin()


func _cuantos(mat: MaterialData) -> int:
	var n := 0
	for m in Game.almacen_materiales:
		if m != null and m.data == mat:
			n += 1
	return n


func _quitar(mat: MaterialData) -> void:
	for i in range(Game.almacen_materiales.size() - 1, -1, -1):
		if Game.almacen_materiales[i].data == mat:
			Game.almacen_materiales.remove_at(i)
			return


func _lanzar_b() -> int:
	var args: PackedStringArray = ["--headless"]
	if OS.has_feature("editor"):
		args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	args.append_array(["--log-file", ProjectSettings.globalize_path(REGISTRO_B),
		"res://tools/prueba_town_baul_cliente.tscn", "--", "cliente", "127.0.0.1", str(PUERTO), "abc"])
	return OS.create_process(OS.get_executable_path(), args)


func _texto_b() -> String:
	if not FileAccess.file_exists(REGISTRO_B):
		return ""
	var f := FileAccess.open(REGISTRO_B, FileAccess.READ)
	var s := f.get_as_text()
	f.close()
	return s


func _dato_de_b(clave: String, plazo: float) -> int:
	var t := 0.0
	while t <= plazo:
		for linea in _texto_b().split("\n"):
			if linea.begins_with("[B] dato " + clave):
				return int(linea.get_slice("=", 1)) if linea.contains("=") else 1
		await _esperar(0.25)
		t += 0.25
	return -1


func _fin() -> void:
	escribir_fase(9)
	await _esperar(4.0)
	var texto := _texto_b()
	var fallos_b := 0
	for linea in texto.split("\n"):
		if linea.begins_with("[B] [PASA]") or linea.begins_with("[B] [FALLA]") or linea.begins_with("[B] RESULTADO"):
			print(linea)
		if linea.begins_with("[B] [FALLA]"):
			fallos_b += 1
	if not texto.contains("[B] RESULTADO"):
		_ok(false, "B no ha llegado al final de su guion")
	var pids: Array = Net._trab._pids.duplicate()
	Net.desconectar()
	await _esperar(3.0)
	if _pid_b > 0 and OS.is_process_running(_pid_b):
		OS.kill(_pid_b)
	for p in pids:
		if OS.is_process_running(p):
			OS.kill(p)
	print("[dev] RESULTADO: ", "TODO PASA" if fallos.is_empty() and fallos_b == 0 else "FALLAN %d (+%d de B)" % [fallos.size(), fallos_b])
	get_tree().quit()
