# ============================================================
#  tactico_pixel.gd  (class_name TacticoPixel)
#  LOS EFECTOS EN PIXEL ART, EN LA PELEA (04/11/2026, memoria efectos-a-pixel-art). Salen del GESTO del cuerpo: el gesto ya llega a
#  todas las pantallas (gesto_bicho_en_mapa) y lo que carga viaja con los estados, asi que se ven iguales en cada maquina sin
#  mandar nada por la red. Hoy, el escarabajo; los demas enemigos se iran sumando a _GESTOS.
# ============================================================
extends RefCounted
class_name TacticoPixel

const T_TOCA_PICADO := 0.34   # como CombatFX.IMPACTO_ANIM_MAPA "picado"
const T_TOCA_CAER := 4.0 / 14.0
const T_TOCA_PINZA := 0.07     # la Pinza cierra a 0,21 y su hoja llega al frente en su marco 2 (a 14 fps)
const T_TOCA_DERRUMBE := 0.145 # como CombatFX.IMPACTO_ANIM_MAPA "derrumbe"
const PASO_POLVO := 16.0      # cada cuanto levanta polvo el que embiste, en px
# Los gestos de la Segadora que llevan estela de garra (tools/sprites_sdf/segadora_efectos_horno.py).
const _HOJAS_SEGADORA := ["basico", "basico_der", "guadanas", "ensarte", "siega", "vendaval", "salto_atras"]

var _t = null   # CombatTactico (sin tipo: se nombran el uno al otro)
var _cargas: Dictionary = {}    # Combatant -> {ab, nodos, marca}: lo que dura mientras carga
var _marcas: Dictionary = {}    # Combatant -> donde esta su marca (la huella se va en cuanto suelta)
var _embisten: Dictionary = {}  # Combatant -> {cuerpo, ult}


func _init(t) -> void:
	_t = t


# LLAMADO POR gesto_bicho_en_mapa cuando un cuerpo empieza 'base'.
func al_gesto(c: Combatant, cuerpo: Node2D, base: String, dur: float) -> void:
	if base == "afilar":   # Afilarse, de la obsidiana: sus destellos, sobre el
		EfectoPixel.lanzar(_t._arena(), "slime", "afilar", _t.pies_de(c), 0, null, 0.0, dur)
		return
	# LA SEGADORA Y SUS MUTANTES (05/11): la ESTELA DE SUS GARRAS, pegada a la hoja (sale de sus pies, la sigue y dura lo que
	# su gesto). Se reconoce por el Ensarte; la de sierra por la Siega y el Vendaval rojo por su Vendaval.
	if base in _HOJAS_SEGADORA and _t._tiene_anim_bicho(cuerpo, "ensarte"):
		var quien: String = "vendaval" if _t._tiene_anim_bicho(cuerpo, "vendaval") \
			else ("sierra" if _t._tiene_anim_bicho(cuerpo, "siega") else "normal")
		var ritmo_s: float = _t._pantalla._fx.escala_tiempo if _t._pantalla._fx != null else 1.0
		EfectoPixel.lanzar(_t._arena(), "segadora", "%s_%s" % [quien, base], _t.pies_de(c),
			SpriteLienzo.dir8(_t._mirada_de(cuerpo)), cuerpo, 0.0, dur, ritmo_s)
		return
	# EL MICONIDO Y SUS MUTANTES (10/11): la estela de la espada del Florecido (tajo y estocada), los filamentos de luz de la
	# Campana y el Destello (las motas que se juntan mientras carga y el cono). Los de la Campana y el Florecido se
	# reconocen por su Destello.
	if _t._tiene_anim_bicho(cuerpo, "micelio") and _t._tiene_anim_bicho(cuerpo, "destello"):
		var cual: String = "florecido" if _t._tiene_anim_bicho(cuerpo, "estocada") else "campana"
		var ritmo_m: float = _t._pantalla._fx.escala_tiempo if _t._pantalla._fx != null else 1.0
		# (salen del cuerpo: desde el centro de su sprite, como se hornearon)
		var pies_m: Vector2 = EfectoPixel.centro_sprite(cuerpo, _t.pies_de(c))
		var dir_m: int = SpriteLienzo.dir8(_t._mirada_de(cuerpo))
		match base:
			"embestida":
				EfectoPixel.lanzar(_t._arena(), "miconido", "tajo" if cual == "florecido" else "filamentos", pies_m, dir_m,
					cuerpo, 0.0, dur, ritmo_m)
			"estocada":
				EfectoPixel.lanzar(_t._arena(), "miconido", "estocada", pies_m, dir_m, cuerpo, 0.0, dur, ritmo_m)
			"destello_carga":
				var ab_m: AbilityData = (_t._poses_carga.get(c, {}) as Dictionary).get("ab")
				_mientras_carga(c, ab_m, [EfectoPixel.lanzar(_t._arena(), "miconido", cual + "_destello_carga", pies_m, dir_m,
					cuerpo, 0.0, -1.0, ritmo_m)])
			"destello":
				# (el cono de luz y el haz los pinta su suelo, con la forma del golpe: FocoAire)
				_quitar_carga(c)
		return
	# (los mutantes del ciempies, por su cabeza libre: la Pinza y el Derrumbe)
	if _t._tiene_anim_bicho(cuerpo, "libre_idle"):
		var ritmo_c: float = _t._pantalla._fx.escala_tiempo if _t._pantalla._fx != null else 1.0
		var pies_c: Vector2 = _t.pies_de(c)
		match base:
			"pinza":
				EfectoPixel.lanzar(_t._arena(), "ciempies", "pinza", pies_c, SpriteLienzo.dir8(_t._mirada_de(cuerpo)), null, T_TOCA_PINZA / maxf(ritmo_c, 0.05), -1.0, ritmo_c)
			"derrumbe_carga":
				var ab_c: AbilityData = (_t._poses_carga.get(c, {}) as Dictionary).get("ab")
				_mientras_carga(c, ab_c, [EfectoPixel.lanzar(_t._arena(), "ciempies", "derrumbe_carga", pies_c, 0, cuerpo, 0.0, -1.0, ritmo_c)])
			"derrumbe":
				_quitar_carga(c)
				EfectoPixel.lanzar(_t._arena(), "ciempies", "derrumbe", pies_c, 0, null, T_TOCA_DERRUMBE / maxf(ritmo_c, 0.05), -1.0, ritmo_c)
		return
	# (los mutantes del escarabajo se reconocen por lo que trae su hoja: el Pulso o la Pasada)
	if not _t._tiene_anim_bicho(cuerpo, "pulso") and not _t._tiene_anim_bicho(cuerpo, "pasada"):
		return
	var pies: Vector2 = _t.pies_de(c)
	var dir: int = SpriteLienzo.dir8(_t._mirada_de(cuerpo))
	var ab: AbilityData = (_t._poses_carga.get(c, {}) as Dictionary).get("ab")
	var mag: bool = ab != null and ab.atrae > 0.0 and ab.en_vuelo
	match base:
		"pulso_carga":
			_mientras_carga(c, ab, [_lanzar("pulso_carga", pies, dir, cuerpo)])
		"pulso":
			_lanzar("pulso_tiron", pies, dir)
		"embestir_carga":
			_mientras_carga(c, ab, [_lanzar("emb_carga", pies, dir, cuerpo)])
		"embestir":
			_lanzar("emb_sale", pies, dir, cuerpo, 0.0, dur)
			_embisten[c] = {"cuerpo": cuerpo, "ult": pies}
		"pasada":
			_lanzar("pasada", pies, dir, cuerpo, 0.0, dur)
			_lanzar("polvo_subir", pies, dir)
		"subir":
			_lanzar("polvo_subir", pies, dir)
			var marca: Vector2 = centro_marca(c, pies)
			_marcas[c] = marca
			var nodos: Array = [_lanzar("sombra", marca, dir)]
			if mag:
				nodos.append(_lanzar("mag_carga", marca, dir))
			_mientras_carga(c, ab, nodos, true)
		"picado":
			var donde: Vector2 = _marcas.get(c, pies)
			_lanzar("estela_roja" if mag else "estela_verde", pies, dir, cuerpo)
			if mag:
				_lanzar("mag_impacto", donde, dir)
			else:
				_lanzar("picado_impacto", donde, dir, null, T_TOCA_PICADO)
		"caparazon":
			if c.mutacion != &"":   # (el normal hace su Caparazon de siempre)
				_lanzar("coraza", pies, dir)
		"elitros":
			_lanzar("elitros", pies, dir)
		"caer":
			_lanzar("caer", pies, dir, null, T_TOCA_CAER)


func _lanzar(nombre: String, pos: Vector2, dir: int, sigue: Node2D = null, espera: float = 0.0, dura: float = -1.0) -> EfectoPixel:
	var ritmo: float = _t._pantalla._fx.escala_tiempo if _t._pantalla._fx != null else 1.0
	return EfectoPixel.lanzar(_t._arena(), "escarabajo", nombre, pos, dir, sigue, espera, dura, ritmo)


func _mientras_carga(c: Combatant, ab: AbilityData, nodos: Array, con_marca: bool = false) -> void:
	_quitar_carga(c)
	_cargas[c] = {"ab": ab, "nodos": nodos, "marca": con_marca}


func _quitar_carga(c: Combatant) -> void:
	var v = _cargas.get(c)
	if v != null:
		for n in v["nodos"]:
			if is_instance_valid(n):
				(n as Node).queue_free()
	_cargas.erase(c)


# Donde tiene su marca roja: la que lleva la pelea la tiene por su nombre, y en el espejo llega por la red.
func centro_marca(c: Combatant, si_no: Vector2) -> Vector2:
	var arena: ArenaCombate = _t._arena()
	if arena == null:
		return si_no
	var h = arena.huellas.get(c)
	if h == null:
		h = arena.huellas.get("red_%d_%d" % [_t._cod(c), _t.CLASE_CARGA])
	return (h["forma"].centro as Vector2) if h != null and h["forma"] != null else si_no


# Cada fotograma: lo de la carga se va con la carga (ha soltado, o se la han cortado) y la sombra sigue a la marca.
func tick() -> void:
	for c in _cargas.keys():
		var v: Dictionary = _cargas[c]
		if not (c as Combatant).is_alive() or (c as Combatant).charging != v["ab"]:
			_quitar_carga(c)
			continue
		if bool(v["marca"]):
			var m: Vector2 = centro_marca(c, _marcas.get(c, Vector2.ZERO))
			_marcas[c] = m
			for n in v["nodos"]:
				if is_instance_valid(n):
					(n as Node2D).position = m
	for c in _embisten.keys():
		var e: Dictionary = _embisten[c]
		var cu = e["cuerpo"]
		if not is_instance_valid(cu) or not _t._gestos_bicho.has(cu):
			_embisten.erase(c)
			continue
		var p: Vector2 = _t.pies_de(c)
		if p.distance_to(e["ult"]) >= PASO_POLVO:
			e["ult"] = p
			_lanzar("polvo_paso", p, 0)


func quitar() -> void:
	for c in _cargas.keys():
		_quitar_carga(c)
	_marcas.clear()
	_embisten.clear()
