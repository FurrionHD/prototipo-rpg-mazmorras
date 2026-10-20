# SONDA DE LA SALA, SOLO PARA PRUEBAS (fase 2, 20/10, todo por la sala, paso 6). Las pruebas town_* ya no son el
# anfitrion: entran como un cliente mas. Lo que antes miraban dentro del anfitrion (en que piso esta cada uno, quien
# lleva cada piso, los trabajadores de pelea, las fotos...) lo apunta la sala en su registro con lineas
#   [S] dato <clave>=<valor>
# cada vez que cambia, y la prueba las lee de alli. La pone sala.gd si se lanza con la palabra "sonda".
extends Node

const CADA := 0.25

var _visto: Dictionary = {}
var _t := 0.0
var _reenvio_mirado := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[S] sonda puesta")


func _process(delta: float) -> void:
	if delta > 0.2:
		print("[S] tiron de %d ms (a los %d ms)" % [int(delta * 1000.0), Time.get_ticks_msec()])
	_t += delta
	if _t < CADA:
		return
	_t = 0.0
	var d := _datos()
	for clave in d:
		var v: String = str(d[clave])
		if not _visto.has(clave) or String(_visto[clave]) != v:
			_visto[clave] = v
			print("[S] dato %s=%s" % [clave, v])
	_mirar_reenvio_de_fotos()


func _datos() -> Dictionary:
	var d := {}
	var humanos := 0
	for peer in Net._peers:
		if Net.es_trabajador(peer):
			continue
		humanos += 1
		var ident: String = Net._identidad_de_peer(peer)
		if ident != "":
			d["peer_" + ident] = peer
			d["piso_" + ident] = Net.pisos._piso_de(peer)
	d["humanos"] = humanos
	var trab = Net._trab
	if trab != null:
		d["trabajadores"] = _lista(trab._estado.keys())
		d["de_pelea"] = _lista(trab._de_pelea.keys())
		d["peleando"] = trab._peleando.size()
		d["pids_trab"] = _lista(trab._pids)
		d["pelea_libre_1"] = trab.pelea_libre_en(1)
	for piso in Net._dueno_piso:
		d["dueno_piso_%d" % int(piso)] = int(Net._dueno_piso[piso])
	d["fotos"] = Net.hogar._fotos.size()
	return d


func _lista(a: Array) -> String:
	var s: Array = a.duplicate()
	s.sort()
	return ",".join(s.map(func(x): return str(x)))


# UNA SEGUNDA DIFUSION DEL HOGAR NO REENVIA LAS FOTOS (lo miraba el anfitrion en prueba_town_dos_jugadores): en cuanto a
# todos los humanos se les ha mandado alguna, se difunde otra vez y se mira que lo mandado no cambia.
func _mirar_reenvio_de_fotos() -> void:
	if _reenvio_mirado:
		return
	var humanos: Array = Net._peers.keys().filter(func(p): return not Net.es_trabajador(p))
	if humanos.size() < 2:
		return
	for p in humanos:
		if (Net.hogar._fotos_mandadas.get(p, {}) as Dictionary).is_empty():
			return
	_reenvio_mirado = true
	var antes: Dictionary = Net.hogar._fotos_mandadas.duplicate(true)
	Net.hogar._difundir_hogar()
	print("[S] dato reenvio_fotos_igual=%d" % int(Net.hogar._fotos_mandadas == antes))
