# SONDA DE LA SALA, SOLO PARA PRUEBAS (fase 2, 20/10, todo por la sala, paso 6). Las pruebas town_* ya no son el
# anfitrion: entran como un cliente mas. Lo que antes miraban dentro del anfitrion (en que piso esta cada uno, quien
# lleva cada piso, las peleas, las fotos...) lo apunta la sala en su registro con lineas
#   [S] dato <clave>=<valor>
# cada vez que cambia, y la prueba las lee de alli. La pone sala.gd si se lanza con la palabra "sonda".
extends Node

const CADA := 0.25

var _visto: Dictionary = {}
# LA VUELTA DESDE LA FOTO (etapa 2): la ultima foto de cada piso (sus sitios) y los pisos montados que ya se han mirado.
var _ultima_foto: Dictionary = {}
var _montados_mirados: Dictionary = {}
var _t := 0.0
var _reenvio_mirado := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[S] sonda puesta")


func _process(delta: float) -> void:
	if delta > 0.2:
		print("[S] tiron de %d ms (a los %d ms)" % [int(delta * 1000.0), Time.get_ticks_msec()])
	_mirar_vuelta_desde_foto()
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
		humanos += 1
		var ident: String = Net._identidad_de_peer(peer)
		if ident != "":
			d["peer_" + ident] = peer
			d["piso_" + ident] = Net.pisos._piso_de(peer)
	d["humanos"] = humanos
	for piso in Net._dueno_piso:
		d["dueno_piso_%d" % int(piso)] = int(Net._dueno_piso[piso])
	# LOS PISOS DE LA SALA (etapa 2): cuales tiene montados, cuantos enemigos lleva cada uno y cuantos trae la foto de
	# los congelados.
	if Net.servidor != null:
		d["montados"] = _lista(Net.servidor.pisos())
		for piso in Net.servidor.pisos():
			var n := 0
			for id in Net.enemigos._enemigos:
				if String(Net.enemigos._enemigos[id]["lugar"]) == "piso:%d" % int(piso):
					n += 1
			d["enem_piso_%d" % int(piso)] = n
	for piso in Net._fotos_piso:
		var en_foto: Array = Net._fotos_piso[piso].get("enemigos", [])
		d["foto_piso_%d" % int(piso)] = en_foto.size()
		# Y donde esta cada uno en la foto ("x:y;x:y", redondeado): con esto se mira que vuelven a SU sitio.
		d["foto_pos_%d" % int(piso)] = ";".join(en_foto.map(func(e): return "%d:%d" % [
			int((e.get("pos", Vector2.ZERO) as Vector2).x), int((e.get("pos", Vector2.ZERO) as Vector2).y)]))
	d["fotos"] = Net.hogar._fotos.size()
	# LAS PELEAS DE LA SALA (etapa 3): cuantas lleva, en que pisos, y cuantos enemigos tiene reservados.
	d["peleas"] = Net.peleas._peleas.size()
	var lugares: Array = []
	for pe in Net.peleas._peleas.values():
		if is_instance_valid(pe):
			lugares.append(pe.piso.lugar if is_instance_valid(pe.piso) else "?")
	d["peleas_lugares"] = _lista(lugares)
	d["reservas"] = Net.peleas._enem_ocupados.size()
	return d


func _lista(a: Array) -> String:
	var s: Array = a.duplicate()
	s.sort()
	return ",".join(s.map(func(x): return str(x)))


# ¿VUELVEN A SU SITIO? En cuanto un piso que estaba congelado se monta y salen sus enemigos (el mismo fotograma, antes de
# que anden), se cuenta cuantos estan donde decia su foto: "[S] dato vuelta_piso_N=en_su_sitio/total". Lo mira la sala
# porque al jugador le llegan despues de cargar su piso, y para entonces ya han andado.
func _mirar_vuelta_desde_foto() -> void:
	for piso in Net._fotos_piso:
		_ultima_foto[int(piso)] = (Net._fotos_piso[piso].get("enemigos", []) as Array).map(
			func(e): return e.get("pos", Vector2.INF))
	if Net.servidor == null:
		return
	for piso in _montados_mirados.keys():
		if not Net.servidor.pisos().has(piso):
			_montados_mirados.erase(piso)
	for piso in Net.servidor.pisos():
		if _montados_mirados.has(piso) or not _ultima_foto.has(int(piso)):
			continue
		var pos: Array = []
		for id in Net.enemigos._enemigos:
			var e: Dictionary = Net.enemigos._enemigos[id]
			if String(e["lugar"]) == "piso:%d" % int(piso) and is_instance_valid(e["nodo"]):
				pos.append((e["nodo"] as Node2D).global_position)
		if pos.is_empty():
			continue   # aun no han salido
		_montados_mirados[piso] = true
		var sitios: Array = _ultima_foto[int(piso)]
		var en_su_sitio := 0
		for p in pos:
			for s in sitios:
				if (p as Vector2).distance_to(s) < 4.0:
					en_su_sitio += 1
					break
		print("[S] dato vuelta_piso_%d=%d/%d" % [int(piso), en_su_sitio, pos.size()])


# UNA SEGUNDA DIFUSION DEL HOGAR NO REENVIA LAS FOTOS (lo miraba el anfitrion en prueba_town_dos_jugadores): en cuanto a
# todos los humanos se les ha mandado alguna, se difunde otra vez y se mira que lo mandado no cambia.
func _mirar_reenvio_de_fotos() -> void:
	if _reenvio_mirado:
		return
	var humanos: Array = Net._peers.keys()
	if humanos.size() < 2:
		return
	for p in humanos:
		if (Net.hogar._fotos_mandadas.get(p, {}) as Dictionary).is_empty():
			return
	_reenvio_mirado = true
	var antes: Dictionary = Net.hogar._fotos_mandadas.duplicate(true)
	Net.hogar._difundir_hogar()
	print("[S] dato reenvio_fotos_igual=%d" % int(Net.hogar._fotos_mandadas == antes))
