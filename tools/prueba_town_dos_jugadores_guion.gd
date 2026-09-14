# PRUEBA DE DOS JUGADORES, guion del HOST: abre la sala, lanza al jugador B, marca las fases y comprueba lo
# que se ve desde el host y lo que B apunta en su registro (lineas "[B] ...").
#   1) los dos bajan al piso 1
#   2) DOS PELEAS A LA VEZ, cada una en un trabajador de pelea distinto
#   3) B se UNE a la pelea del host y HUYE: la pelea sigue para el host
extends "res://tools/prueba_town_dos_comun.gd"

const PUERTO := 24601
const REGISTRO_B := "user://logs/prueba_jugador_b.log"
var _pid_b := 0


func _ready() -> void:
	prefijo = ""
	escribir_fase(0)
	if FileAccess.file_exists(REGISTRO_B):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(REGISTRO_B))
	cargar_grupo([4, 0])
	Game.semilla_mundo = 424242
	await _esperar(0.5)
	_ok(Net.hostear("abc", PUERTO) == OK, "sala abierta")
	_pid_b = _lanzar_b()
	_ok(_pid_b > 0, "jugador B lanzado")
	var t := 0.0
	while Net._num_humanos < 2 and t < 40.0:
		await _esperar(0.5)
		t += 0.5
	_ok(Net._num_humanos == 2, "B entra en la sala (%.1f s)" % t)
	if Net._num_humanos < 2:
		await _fin()
		return

	# 1) Los dos al piso 1.
	Net.pisos.solicitar_entrar(1)
	escribir_fase(1)
	await _esperar(10.0)
	t = 0.0
	while Net.pisos._piso_de(_b()) != 1 and t < 20.0:
		await _esperar(0.5)
		t += 0.5
	_ok(Net.pisos._piso_de(_b()) == 1, "B esta en el piso 1")
	t = 0.0
	while Net._trab.pelea_libre_en(1) == 0 and t < 40.0:
		await _esperar(0.5)
		t += 0.5
	_ok(Net._trab.pelea_libre_en(1) != 0, "hay un trabajador de pelea esperando en el piso 1 (%.1f s)" % t)
	await _esperar(3.0)

	# 2) DOS PELEAS A LA VEZ. Abro la mia; en cuanto haya otro de pelea esperando (y haya cargado), B abre la suya.
	var excelia_antes := excelia_grupo()
	await pelear_con(enemigo_libre(Net.posicion_de_peer(_b())))
	var f_mia: int = Net.peleas._pelea_anfitrion
	_ok(Net.peleas.espejando() and Net._trab._de_pelea.has(f_mia), "mi pelea la ejecuta un trabajador de pelea (%d)" % f_mia)
	t = 0.0
	while (Net._trab.pelea_libre_en(1) == 0 or Net._trab.pelea_libre_en(1) == f_mia) and t < 30.0:
		await _esperar(0.5)
		t += 0.5
	await _esperar(4.0)   # que cargue el piso y reciba los enemigos
	escribir_fase(2)
	t = 0.0
	while Net._trab._peleando.size() < 2 and t < 20.0:
		await _esperar(0.25)
		t += 0.25
	_ok(Net._trab._peleando.size() >= 2, "DOS peleas a la vez, en %d trabajadores de pelea" % Net._trab._peleando.size())
	var f_b: int = await _dato_de_b("anfitrion_fase2", 20.0)
	_ok(f_b != 0 and f_b != f_mia and Net._trab._de_pelea.has(f_b), "la de B va en OTRO trabajador de pelea (%d, la mia %d)" % [f_b, f_mia])
	_ok(await pelear_hasta_el_final(60.0), "mi pelea termina")
	_ok(excelia_grupo() > excelia_antes, "me llega la excelia de mi pelea")
	await _dato_de_b("fase2_fin", 60.0)
	await _esperar(4.0)

	# 3) B se UNE a mi pelea y HUYE. Yo solo DEFIENDO (una rata muere de un golpe y la pelea se acabaria antes).
	await pelear_con(enemigo_libre(Net.posicion_de_peer(_b())))
	var f3: int = Net.peleas._pelea_anfitrion
	_ok(Net.peleas.espejando(), "abro la pelea a la que se va a unir B")
	var id_suyo := 0
	t = 0.0
	while id_suyo == 0 and t < 8.0:
		for nid in Net.enemigos._enem_nodos:
			var n = Net.enemigos._enem_nodos[nid]
			if is_instance_valid(n) and int(n.get("pelea_de")) == f3:
				id_suyo = int(nid)
				break
		await _esperar(0.25)
		t += 0.25
	_ok(id_suyo != 0, "veo que enemigo esta en mi pelea (%d)" % id_suyo)
	escribir_fase(3, [id_suyo, f3])
	var p: Node = pantalla()
	var entro_b := false
	var se_fue_b := false
	t = 0.0
	while t < 60.0 and not se_fue_b:
		var dentro: bool = p != null and is_instance_valid(p) and (p.get("_aliados") as Array).size() > 2
		entro_b = entro_b or dentro
		# No actuo hasta que B este dentro: el ATB espera a quien tiene el turno, asi que la pelea se queda
		# quieta y no se acaba antes de que llegue. Luego Defender para alargarla (sin energia, Atacar: si
		# no hago nada la pelea se para en mi turno y a B no le llega nunca el suyo).
		if entro_b and not pulsar(3):
			pulsar(0)
		se_fue_b = _hay_linea_b("fase3_fin")
		await _esperar(0.25)
		t += 0.25
	_ok(entro_b, "B aparece en mi pelea")
	_ok(se_fue_b and Net.peleas.espejando(), "B huye y la pelea SIGUE para mi")
	_ok(await pelear_hasta_el_final(60.0), "termino la pelea yo solo")

	await _fin()


func _b() -> int:
	for pid in Net._peers:
		if not Net.es_trabajador(pid):
			return pid
	return 0


func _lanzar_b() -> int:
	var args: PackedStringArray = ["--headless"]
	if OS.has_feature("editor"):
		args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	args.append_array(["--log-file", ProjectSettings.globalize_path(REGISTRO_B),
		"res://tools/prueba_town_dos_cliente.tscn", "--", "cliente", "127.0.0.1", str(PUERTO), "abc"])
	return OS.create_process(OS.get_executable_path(), args)


func _texto_b() -> String:
	if not FileAccess.file_exists(REGISTRO_B):
		return ""
	var f := FileAccess.open(REGISTRO_B, FileAccess.READ)
	var s := f.get_as_text()
	f.close()
	return s


func _hay_linea_b(clave: String) -> bool:
	return _texto_b().contains("[B] dato " + clave)


# El valor que B apunto como "[B] dato clave=valor" (0 si no aparece en el plazo).
func _dato_de_b(clave: String, plazo: float) -> int:
	var t := 0.0
	while t <= plazo:
		for linea in _texto_b().split("\n"):
			if linea.begins_with("[B] dato " + clave):
				return int(linea.get_slice("=", 1)) if linea.contains("=") else 1
		await _esperar(0.5)
		t += 0.5
	return 0


func _fin() -> void:
	escribir_fase(9)
	await _esperar(6.0)   # que B apunte su resultado y se vaya
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
	var vivos := pids.filter(func(x): return OS.is_process_running(x))
	_ok(vivos.is_empty(), "los trabajadores se cierran con la sala (%d vivos)" % vivos.size())
	print("[dev] RESULTADO: ", "TODO PASA" if fallos.is_empty() and fallos_b == 0 else "FALLAN %d (+%d de B)" % [fallos.size(), fallos_b])
	get_tree().quit()
