# ============================================================
#  bestia_aire.gd
#  LOS EFECTOS DE LAS BESTIAS DE LOS PISOS BAJOS en el mapa (28/09/2026): rata, rey rata, jabali y trent, uno a
#  uno y con su visto bueno (ver la memoria enemigos-bajos-tactico). Empieza por la RATA:
#  SOBRE UN CUERPO (CombatTactico._on_dibujo_mapa, CombatFX.Estilo.BESTIA_*):
#    MORDISCO        el basico: dos MANDIBULAS en media luna, con sus colmillos, que se cierran de golpe sobre el
#                    cuerpo; un destello al cerrar y un tiron hacia quien muerde. Orientadas segun de donde viene
#                    el golpe, y cada una con su variacion.
#    MORDISCO_SANGRA el Mordisco sangrante: lo mismo (la sangre la pone CombatTactico._on_impacto, solo si entra).
#    FRENESI         el Frenesi de dentelladas: mandibulas mas pequeñas y rapidas, cada una desde un angulo
#                    cualquiera: un remolino de mordiscos.
#  Y EL REY RATA (29/09):
#    DENTELLADA      la Dentellada real: los mismos paletos, tres tarascadas mas lentas y con mas peso.
#    YUGULAR         A la yugular: paletos mas grandes que muerden ALTO, al cuello, y el destello rojo en estrella.
#    TEMBLOR         al que le pasa el Chillido por encima: el cuerpo tiembla y le vibra el sonido a los lados de
#                    la cabeza.
#  POR EL SUELO (SueloRoto.Tipo.BESTIA_*, en el orden de Modo):
#    POLVO           el aterrizaje del Frenesi: un anillo de polvo que se abre desde donde cae y unas piedrecitas.
#    CHILLIDO        el Chillido del rey rata: cuatro frentes de sonido finos y seguidos que se abren en el cono y
#                    TIEMBLAN (el Grito del mandoble, pero agudo). Mas vivos en el tramo de cerca. Sin polvo.
#    ESTELA          la estela de polvo corta de la Yugular, por la linea, detras del cuerpo que se lanza.
#  EL JABALI (29/09):
#    SURCO           la Embestida por el suelo: las rodadas de las pezuñas, terrones que saltan a los lados y polvo.
#    PISOTON         los dos pisotones: grietas cortas desde sus patas (las del martillo, en pequeño) y un anillo
#                    de polvo a ras; el segundo agranda las grietas del primero.
#    COLMILLO        (sobre un cuerpo) el basico: una media luna de hueso que engancha de ABAJO ARRIBA (la pincelada
#                    del mandoble, en hueso).
#    CORNADA         (sobre un cuerpo) lo mismo, mas grande y mas lento, terrones y un desgarro en la punta, y al
#                    que engancha lo LEVANTA un palmo (su dibujo sube y cae).
#    CHOQUE          (sobre un cuerpo) lo que arrolla la Embestida: el frente del choque y un chorro de polvo hacia
#                    donde sale despedido.
#  NADA DE LINEAS: siluetas llenas con filo duro y un halo difuminado detras (ver efectos-sin-lineas).
#  Coordenadas de MUNDO.
# ============================================================
extends Node2D
class_name BestiaAire

# Los del suelo van en el orden de SueloRoto.Tipo.BESTIA_*: no reordenar.
enum Modo { POLVO, CHILLIDO, ESTELA, SURCO, PISOTON,
	MORDISCO, MORDISCO_SANGRA, FRENESI, DENTELLADA, YUGULAR, TEMBLOR, COLMILLO, CORNADA, CHOQUE }

const K := 0.7071
const Z_ENCIMA := Game.Z_PERSONAJES + 80
const T_POLVO := 0.28             # lo que tarda el anillo de polvo en llegar al borde
const T_CERRADO := 0.22           # lo que se quedan las mandibulas cerradas antes de irse
const T_IRSE := 0.18
const T_ONDA_CH := 0.36           # lo que tarda el Chillido en llegar a su borde (el Grito, 0.45: el agudo corre mas)
const T_ENTRE_CH := 0.07          # entre frente y frente del Chillido
const T_ESTELA := 0.2             # = CombatTactico.T_EMBESTIDA_BICHO (la estela va con el cuerpo, como el Placaje)
const T_TIEMBLA := 0.45           # lo que tiembla el que se come el Chillido
const SONIDO := Color(0.86, 0.82, 1.0)
const T_PISA_ENTRE := 0.2         # entre los dos pisotones (CombatFX.T_ENCADENADO)
const T_GRIETA := 0.1             # lo que tarda una grieta del pisoton en abrirse entera
const T_LEVANTA := 0.32           # lo que dura el palmo que levanta la Cornada (sube y cae)
const TIERRA := Color(0.36, 0.28, 0.2)

const HUESO := Color(0.96, 0.93, 0.84)
const HUESO_SOMBRA := Color(0.62, 0.55, 0.46)
const BOCA := Color(0.16, 0.04, 0.05)
const POLVO := Color(0.55, 0.47, 0.38)
const POLVO_CLARO := Color(0.78, 0.71, 0.6)

var modo: int = Modo.MORDISCO
var forma: CombatFormas.Forma = null
var _t: float = 0.0
var _ritmo: float = 1.0
var _rng := RandomNumberGenerator.new()
var _desde: Vector2 = Vector2.ZERO
var _hasta: Vector2 = Vector2.ZERO
var _ancho: float = 16.0
var _viaje: float = 0.12
var _eje: Vector2 = Vector2.RIGHT     # hacia donde muerde (de quien muerde a quien recibe): el tiron va al reves
var _boca: Vector2 = Vector2.RIGHT    # el eje en el que se cierran las mandibulas (el del mordisco, variado)
var _tam: float = 10.0
var _o: Vector2 = Vector2.ZERO
var _r: float = 25.0
var _dir: Vector2 = Vector2.RIGHT
var _largo: float = 40.0
var _lento: float = 1.0               # la Dentellada y la Yugular cierran y sueltan mas despacio: pesan mas
var _dibujo: CanvasItem = null        # lo que tiembla (el muñeco de los tuyos, el sprite de un enemigo)
var _base_dibujo: Vector2 = Vector2.ZERO
var _a_colmillo: float = 0.0          # hacia donde se comba la media luna del colmillo (el lado de quien embiste)
var _grietas: Array = []              # las del pisoton: {pts, w0, w1, t0}
var _puffs: Array = []
var _piedras: Array = []
var _delante: Node2D = null
var _brillo: Node2D = null
var _suelo: Node2D = null


# ------------------------------------------------------------
#  EN EL SUELO
# ------------------------------------------------------------
static func area(padre: Node, f: CombatFormas.Forma, m: int, semilla: int, espera: float) -> Node2D:
	if padre == null or f == null:
		return null
	var e := BestiaAire.new()
	e.modo = m
	e.forma = f
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(BarridoAire.ritmo, 0.05)
	e._t = -espera * e._ritmo
	e.z_as_relative = false
	e.z_index = SueloRoto.Z_SUELO
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	e._o = SueloRoto.origen_de(f)
	e._r = maxf(f.radio, 8.0)
	e._dir = f.dir.normalized() if f.dir.length_squared() > 0.0001 else Vector2.RIGHT
	e._largo = maxf(f.largo if f.tipo == CombatFormas.Tipo.LINEA else f.radio, 4.0)
	e._ancho = maxf(f.ancho, 8.0)
	match m:
		Modo.POLVO:
			for i in 16:
				var a: float = TAU * (float(i) + e._rng.randf_range(0.0, 0.8)) / 16.0
				e._puffs.append({"a": a, "u": e._rng.randf_range(0.7, 1.05), "tam": e._rng.randf_range(0.18, 0.3),
					"sube": e._rng.randf_range(4.0, 10.0), "sem": e._rng.randf_range(0.0, 9.0)})
			for i in 7:
				var a2: float = e._rng.randf_range(0.0, TAU)
				e._piedras.append({"a": a2, "v": e._rng.randf_range(40.0, 75.0), "sube": e._rng.randf_range(14.0, 26.0),
					"tam": e._rng.randf_range(1.2, 2.0)})
		Modo.ESTELA, Modo.SURCO:
			# Bocanadas por la linea, que se levantan al paso del cuerpo. Solo hasta el 85%: el ultimo trozo es donde
			# se queda pegado al que muerde, y ahi no hay carrera.
			var n: int = int(clampf(e._largo / 5.0, 6.0, 14.0))
			for i in n:
				e._puffs.append({"u": (float(i) + e._rng.randf_range(0.0, 0.8)) / float(n) * 0.85,
					"v": e._rng.randf_range(-0.5, 0.5), "tam": e._rng.randf_range(0.35, 0.6),
					"sube": e._rng.randf_range(3.0, 7.0)})
			# El SURCO del jabali, ademas: terrones que saltan a los dos lados al paso de las pezuñas.
			if m == Modo.SURCO:
				for i in int(clampf(e._largo / 7.0, 6.0, 16.0)):
					e._piedras.append({"u": e._rng.randf_range(0.05, 0.85), "lado": -1.0 if i % 2 == 0 else 1.0,
						"v": e._rng.randf_range(18.0, 34.0), "sube": e._rng.randf_range(10.0, 20.0),
						"tam": e._rng.randf_range(1.4, 2.4)})
		Modo.PISOTON:
			# LAS GRIETAS, las del martillo en pequeño: salen de debajo de sus patas (no del centro: ahi esta el) y el
			# segundo pisoton las alarga y abre alguna mas.
			# NACEN FUERA DE SU CUERPO (desde la mitad del radio): saliendo de debajo de el parecian patas de araña.
			var n_g: int = 6
			for i in n_g:
				var ang: float = TAU * (float(i) + e._rng.randf_range(-0.3, 0.3)) / float(n_g)
				var p1: PackedVector2Array = e._quebrada(ang, e._r * 0.5, e._r * 0.78)
				e._grietas.append({"pts": p1, "w0": 2.2, "w1": 1.0, "t0": 0.0})
				var sigue: PackedVector2Array = e._quebrada(ang + e._rng.randf_range(-0.2, 0.2), e._r * 0.76, e._r * 1.1,
					p1[p1.size() - 1])
				e._grietas.append({"pts": sigue, "w0": 1.2, "w1": 0.3, "t0": T_PISA_ENTRE})
			for i in 4:
				var ang2: float = TAU * (float(i) + 0.5 + e._rng.randf_range(-0.3, 0.3)) / 4.0
				e._grietas.append({"pts": e._quebrada(ang2, e._r * 0.52, e._r * 0.92), "w0": 1.6, "w1": 0.3,
					"t0": T_PISA_ENTRE})
			# EL BORDE DEL HUNDIMIENTO (el del martillo): un anillo quebrado alrededor de sus patas, de donde salen las
			# grietas. Es lo que las lee como suelo roto y no como patas.
			var borde := PackedVector2Array()
			for i in 41:
				var a4: float = TAU * float(i % 40) / 40.0
				borde.append(e._o + Vector2(cos(a4), sin(a4)) * e._r * 0.5 * (1.0 + 0.06 * sin(a4 * 5.0 + 1.3)
					+ e._rng.randf_range(-0.04, 0.04)))
			borde[40] = borde[0]
			e._grietas.push_front({"pts": borde, "w0": 2.4, "w1": 2.4, "t0": 0.0})
			# El anillo de polvo de cada pisoton.
			for k in 2:
				for i in 14:
					var a3: float = TAU * (float(i) + e._rng.randf_range(0.0, 0.8)) / 14.0
					e._puffs.append({"a": a3, "k": k, "u": e._rng.randf_range(0.75, 1.05),
						"tam": e._rng.randf_range(0.14, 0.24), "sube": e._rng.randf_range(2.0, 5.0)})
	e._suelo = e._capa(SueloRoto.Z_SUELO, false)
	e._delante = e._capa(Z_ENCIMA, false)
	return e


static func retraso(m: int, f: CombatFormas.Forma, p: Vector2) -> float:
	if f == null:
		return 0.0
	match m:
		Modo.POLVO:
			return clampf(p.distance_to(SueloRoto.origen_de(f)) / maxf(f.radio, 1.0), 0.0, 1.0) * T_POLVO
		# El Chillido le llega a cada uno cuando el PRIMER frente le pasa por encima (como el Grito).
		Modo.CHILLIDO:
			return clampf(p.distance_to(SueloRoto.origen_de(f)) / maxf(f.radio, 1.0), 0.0, 1.0) * T_ONDA_CH
		Modo.ESTELA, Modo.SURCO:
			return clampf((p - f.origen).dot(f.dir.normalized()) / maxf(f.largo, 1.0), 0.0, 1.0) * T_ESTELA
	return 0.0


static func t_salir(m: int) -> float:
	match m:
		Modo.POLVO: return T_POLVO
		Modo.CHILLIDO: return T_ONDA_CH
		Modo.ESTELA, Modo.SURCO: return T_ESTELA
		Modo.PISOTON: return T_GRIETA
	return 0.2


# Una grieta quebrada que sale en 'ang' de r0 a r1 (desde _o, o desde 'desde' si se da: la que sigue a otra). Se
# tuerce pero vuelve a su rumbo, como las del martillo (SueloRoto._quebrada).
func _quebrada(ang: float, r0: float, r1: float, desde: Vector2 = Vector2.INF) -> PackedVector2Array:
	var p: Vector2 = desde if desde != Vector2.INF else _o + Vector2(cos(ang), sin(ang)) * r0
	var pts := PackedVector2Array([p])
	var rumbo: float = ang
	var paso: float = 3.0
	var r: float = r0
	while r < r1:
		rumbo = lerpf(rumbo, ang, 0.35) + _rng.randf_range(-0.55, 0.55)
		p += Vector2(cos(rumbo), sin(rumbo)) * paso
		pts.append(p)
		r += paso
	return pts


# ------------------------------------------------------------
#  SOBRE UN CUERPO
# ------------------------------------------------------------
# 'desde' = de donde viene (quien muerde), 'caja' = el cuerpo que lo recibe, 'espera' = lo que falta para el
# golpe: las mandibulas se van cerrando en ese tiempo y se juntan justo en el golpe.
static func sobre_cuerpo(padre: Node, m: int, desde: Vector2, caja: Rect2, semilla: int, espera: float,
		ritmo: float, boca: float = -1.0, dibujo: CanvasItem = null) -> BestiaAire:
	if padre == null:
		return null
	var e := BestiaAire.new()
	e.modo = m
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(ritmo, 0.05)
	match m:
		Modo.FRENESI: e._viaje = clampf(espera, 0.06, 0.12)
		Modo.DENTELLADA, Modo.CORNADA: e._viaje = clampf(espera, 0.12, 0.24)
		Modo.CHOQUE: e._viaje = 0.0
		_: e._viaje = clampf(espera, 0.08, 0.2)
	e._t = -e._viaje
	e._desde = desde
	e._hasta = caja.get_center() + Vector2(e._rng.randf_range(-0.15, 0.15) * caja.size.x,
		e._rng.randf_range(-0.2, 0.1) * caja.size.y)
	# LA YUGULAR va al CUELLO: alto en el cuerpo, no en el centro.
	if m == Modo.YUGULAR:
		e._hasta = Vector2(caja.get_center().x + e._rng.randf_range(-0.08, 0.08) * caja.size.x,
			caja.position.y + caja.size.y * 0.28)
	e._ancho = maxf(caja.size.x, 10.0)
	var eje: Vector2 = (e._hasta - desde).normalized() if e._hasta.distance_squared_to(desde) > 1.0 else Vector2.RIGHT
	e._eje = eje
	# LAS MANDIBULAS VAN A LO LARGO DE LA LINEA DEL MORDISCO: una del lado de quien muerde y la otra al otro lado
	# del cuerpo, y se cierran sobre el (lo corrigio el usuario, 28/09: la boca no muerde de lado). Cada mordisco
	# con su variacion; el frenesi, mas revuelto, y la Dentellada un poco (tres tarascadas: que no caigan iguales).
	var revuelto: float = 2.0 if m == Modo.FRENESI else (1.4 if m == Modo.DENTELLADA else 1.0)
	e._boca = eje.rotated(e._rng.randf_range(-0.3, 0.3) * revuelto)
	# LA BOCA VA A ESCALA DE QUIEN MUERDE, no de quien recibe ("los mordiscos son muy grandes para el tamaño de la
	# rata", 28/09): 'boca' = el ancho del dibujo del que muerde. El rey rata muerde mas grande con lo mismo.
	var de_quien: float = boca if boca > 0.0 else e._ancho
	var escala: float = 1.0
	match m:
		Modo.FRENESI: escala = 0.8
		Modo.YUGULAR: escala = 1.15
		Modo.CORNADA: escala = 1.4
	e._tam = maxf(de_quien * 0.3, 4.0) * escala
	e._lento = 1.3 if m == Modo.DENTELLADA else (1.15 if m == Modo.YUGULAR else 1.0)
	# EL COLMILLO se comba hacia el lado de quien embiste (entra por ahi) y sube; si viene de arriba o de abajo, a un
	# lado cualquiera. Cada golpe con su variacion.
	if m == Modo.COLMILLO or m == Modo.CORNADA:
		var de_lado: float = -eje.x if absf(eje.x) > 0.25 else (1.0 if e._rng.randf() < 0.5 else -1.0)
		e._a_colmillo = (0.0 if de_lado > 0.0 else PI) + e._rng.randf_range(-0.3, 0.3)
		e._hasta = caja.get_center() + Vector2(e._rng.randf_range(-0.1, 0.1) * caja.size.x, -0.05 * caja.size.y)
	e._largo = maxf(caja.size.y, 10.0)   # lo alto del cuerpo: donde tiene los pies
	if m == Modo.CORNADA:
		e._tomar_dibujo(dibujo)
		for i in 6:
			e._piedras.append({"vx": e._rng.randf_range(-22.0, 22.0), "sube": e._rng.randf_range(8.0, 16.0),
				"tam": e._rng.randf_range(1.4, 2.4)})
	e.z_as_relative = false
	e.z_index = Z_ENCIMA
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	e._delante = e._capa(Z_ENCIMA, false)
	e._brillo = e._capa(Z_ENCIMA + 1, true)
	return e


# EL TEMBLOR DEL CHILLIDO sobre quien lo recibe: su DIBUJO tiembla (como la esquiva, solo el dibujo y vuelve) y a
# los lados de la cabeza le vibran dos medias lunas de sonido. 'dibujo' puede ser null (en las hojas: solo el sonido).
static func temblor(padre: Node, dibujo: CanvasItem, caja: Rect2, semilla: int, espera: float,
		ritmo: float) -> BestiaAire:
	if padre == null:
		return null
	var e := BestiaAire.new()
	e.modo = Modo.TEMBLOR
	e._rng.seed = hash(semilla)
	e._ritmo = maxf(ritmo, 0.05)
	e._t = -maxf(espera, 0.0)
	e._hasta = Vector2(caja.get_center().x, caja.position.y + caja.size.y * 0.22)
	e._ancho = maxf(caja.size.x, 10.0)
	e._tam = maxf(caja.size.y, 16.0)
	e.z_as_relative = false
	e.z_index = Z_ENCIMA
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	e._delante = e._capa(Z_ENCIMA, false)
	e._tomar_dibujo(dibujo)
	return e


# EL SITIO DE VERDAD del dibujo que se mueve (el temblor, la Cornada), compartido con la esquiva (EstoqueAire) y
# entre ellos: el segundo no puede tomar como sitio el del primero, ya movido.
func _tomar_dibujo(dibujo: CanvasItem) -> void:
	if not is_instance_valid(dibujo):
		return
	if not dibujo.has_meta(&"esq_base"):
		dibujo.set_meta(&"esq_base", dibujo.get("position"))
	dibujo.set_meta(&"esq_n", int(dibujo.get_meta(&"esq_n", 0)) + 1)
	_base_dibujo = dibujo.get_meta(&"esq_base")
	_dibujo = dibujo


func duracion() -> float:
	match modo:
		Modo.POLVO: return T_POLVO + 0.7
		Modo.CHILLIDO: return T_ONDA_CH + 3.0 * T_ENTRE_CH + 0.2
		Modo.ESTELA: return T_ESTELA + 0.75
		Modo.TEMBLOR: return T_TIEMBLA
		Modo.SURCO: return T_ESTELA + 0.9
		Modo.PISOTON: return T_PISA_ENTRE + 1.2
		Modo.COLMILLO: return 0.3
		Modo.CORNADA: return maxf(0.45, T_LEVANTA + 0.05)
		Modo.CHOQUE: return 0.6
	return (T_CERRADO + T_IRSE) * _lento


func _capa(z: int, aditiva: bool) -> Node2D:
	var n := Node2D.new()
	n.z_as_relative = false
	n.z_index = z
	if aditiva:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		n.material = mat
	add_child(n)
	n.draw.connect(_dibujar_capa.bind(n))
	return n


func _process(delta: float) -> void:
	_t += delta * _ritmo
	if _t >= duracion():
		_devolver_dibujo()
		queue_free()
		return
	aplicar_temblor()
	for n in [_suelo, _delante, _brillo]:
		if n != null:
			(n as Node2D).queue_redraw()


func _exit_tree() -> void:
	_devolver_dibujo()


# Lo que se aparta el dibujo en este instante: un vaiven rapido de lado a lado que se va apagando. Publica para
# las hojas (ahi no corre _process: les ponen el tiempo a mano).
func aplicar_temblor() -> void:
	if not is_instance_valid(_dibujo):
		return
	var fuera := Vector2.ZERO
	if _t >= 0.0 and modo == Modo.TEMBLOR:
		var amp: float = 1.8 * (1.0 - _t / T_TIEMBLA)
		fuera = Vector2(sin(_t * 95.0) * amp, sin(_t * 61.0 + 1.3) * amp * 0.35).round()
	# LA CORNADA levanta un palmo: sube rapido y cae, con un botecito al caer.
	elif _t >= 0.0 and modo == Modo.CORNADA and _t < T_LEVANTA:
		var k: float = _t / T_LEVANTA
		fuera = Vector2(0.0, -round(6.0 * sin(PI * minf(k * 1.25, 1.0)) + 1.5 * sin(PI * clampf((k - 0.8) / 0.2, 0.0, 1.0))))
	_dibujo.set("position", _base_dibujo + fuera)


func _devolver_dibujo() -> void:
	if not is_instance_valid(_dibujo):
		return
	_dibujo.set("position", _base_dibujo)
	var n: int = int(_dibujo.get_meta(&"esq_n", 1)) - 1
	if n <= 0:
		_dibujo.remove_meta(&"esq_base")
		_dibujo.remove_meta(&"esq_n")
	else:
		_dibujo.set_meta(&"esq_n", n)
	_dibujo = null   # una sola vez (lo llaman el final y _exit_tree)


func _dibujar_capa(capa: Node2D) -> void:
	match modo:
		Modo.POLVO: _polvo(capa)
		Modo.CHILLIDO: _chillido(capa)
		Modo.ESTELA: _estela(capa)
		Modo.TEMBLOR: _temblor(capa)
		Modo.SURCO: _surco(capa)
		Modo.PISOTON: _pisoton(capa)
		Modo.COLMILLO, Modo.CORNADA: _colmillo(capa)
		Modo.CHOQUE: _choque(capa)
		_: _mordisco(capa)


# ------------------------------------------------------------
#  EL MORDISCO
# ------------------------------------------------------------
# Dos mandibulas, una a cada lado del eje, que se cierran hacia el. Mientras viaja el golpe (t < 0) se van
# juntando, cada vez mas deprisa; en el golpe chocan (destello) y tiran un pelin hacia quien muerde; luego se van.
func _mordisco(capa: Node2D) -> void:
	var perp: Vector2 = _boca
	var cierre: float    # 0 = abiertas del todo, 1 = cerradas
	var alfa: float = 1.0
	var tiron := Vector2.ZERO
	if _t < 0.0:
		var u: float = clampf(1.0 + _t / _viaje, 0.0, 1.0)
		cierre = u * u
		alfa = clampf(u * 3.0, 0.0, 1.0)
	else:
		cierre = 1.0
		var kt: float = clampf(_t / (T_CERRADO * _lento), 0.0, 1.0)
		tiron = -_eje * _tam * 0.35 * sin(PI * minf(kt * 1.6, 1.0))
		alfa = 1.0 - smoothstep(T_CERRADO * _lento, (T_CERRADO + T_IRSE) * _lento, _t)
	if capa == _brillo:
		if _t >= 0.0 and _t < 0.14:
			BarridoAire.destello(capa, _hasta + tiron, _tam * 0.9, Color(1.0, 0.95, 0.85, 0.85 * (1.0 - _t / 0.14)),
				_boca.angle())
		return
	if capa != _delante:
		return
	# EL REBOTE: al llegar a tope la boca afloja un pelin en vez de quedarse clavada (como en la fila).
	if _t > 0.03 and _t < 0.1:
		cierre = 1.0 - 0.14 * sin((_t - 0.03) / 0.07 * PI)
	# LA YUGULAR: al cerrar, el DESTELLO ROJO en estrella de la fila (va UN sitio y con todo). Detras de los dientes y
	# sin mezcla aditiva: sumado sobre el fondo el rojo salia naranja.
	if modo == Modo.YUGULAR and _t >= 0.0 and _t < 0.26:
		var kd: float = _t / 0.26
		BarridoAire.destello(capa, _hasta + tiron, _tam * lerpf(1.5, 2.1, kd), Color(0.90, 0.10, 0.12, 0.9 * (1.0 - kd)),
			_boca.angle() + PI * 0.125)
	# LOS PALETOS DE LA FILA (lo pidio el usuario, 28/09: las medias lunas, para el acechador): dos hileras de
	# dientes que se cierran, cada una de un lado de la linea del mordisco -- la de arriba del lado de quien muerde.
	var media: float = _tam
	var largo_max: float = media * 0.85
	var sep: float = lerpf(largo_max * 1.6, -largo_max * 0.12, cierre)
	var fila: Vector2 = Vector2(-perp.y, perp.x)   # a lo largo de cada hilera
	var c: Vector2 = _hasta + tiron
	for d in _P_PALETOS_ARRIBA:
		_diente(capa, c, fila, perp, media, largo_max, sep, d, alfa)
	for d in _P_PALETOS_ABAJO:
		_diente(capa, c, fila, -perp, media, largo_max, sep, d, alfa)
	# LO QUE DEJA: los dos agujeros de los paletos, con su gota escurriendo.
	if _t >= 0.0 and cierre > 0.85:
		for s in [-1.0, 1.0]:
			var p: Vector2 = c + fila * (0.13 * media * s)
			_bola(capa, p, maxf(1.6, largo_max * 0.2), Color(SANGRE, 0.95 * alfa))
			BarridoAire.cometa(capa, p, p + Vector2(0.0, largo_max * 0.55), maxf(1.2, largo_max * 0.16),
				Color(SANGRE, 0.6 * alfa))


# ROEDOR (la tabla de la fila, capa_hechizos._P_PALETOS_*): dos PALETOS anchos de punta recta que dominan la
# boca y dientecitos a los lados. Cada diente: [off_x (-1..1 sobre media boca), semiancho, largo, inclinacion, punta].
const _P_PALETOS_ARRIBA := [
	[-0.165, 0.160, 1.00, 0.0, 0.05], [0.165, 0.160, 1.00, 0.0, 0.05],
	[-0.44, 0.070, 0.34, 0.0, 0.35], [0.44, 0.070, 0.34, 0.0, 0.35],
	[-0.60, 0.065, 0.28, 0.0, 0.35], [0.60, 0.065, 0.28, 0.0, 0.35],
	[-0.75, 0.060, 0.22, 0.0, 0.40], [0.75, 0.060, 0.22, 0.0, 0.40],
]
const _P_PALETOS_ABAJO := [
	[-0.145, 0.140, 0.72, 0.0, 0.08], [0.145, 0.140, 0.72, 0.0, 0.08],
	[-0.40, 0.065, 0.28, 0.0, 0.35], [0.40, 0.065, 0.28, 0.0, 0.35],
	[-0.56, 0.060, 0.24, 0.0, 0.35], [0.56, 0.060, 0.24, 0.0, 0.35],
	[-0.71, 0.055, 0.20, 0.0, 0.40], [0.71, 0.055, 0.20, 0.0, 0.40],
]
const SANGRE := Color(0.72, 0.06, 0.08)
const ENCIA := Color(0.10, 0.03, 0.05)


# UN DIENTE de una hilera. 'crece' = hacia donde crece (hacia la otra hilera). La mandibula va CURVADA: abre por el
# centro y en las comisuras casi se tocan (sin eso, dos rejas paralelas). Sin lineas: el contorno es el mismo diente
# un poco mas grande y oscuro detras (filo duro).
func _diente(ci: CanvasItem, centro: Vector2, fila: Vector2, crece: Vector2, media: float, largo_max: float,
		sep: float, d: Array, alfa: float) -> void:
	var x: float = float(d[0]) * media
	var w: float = float(d[1]) * media
	var largo: float = float(d[2]) * largo_max
	var incl: float = float(d[3]) * largo
	var k: float = float(d[0])
	# La ENCIA va detras de los dientes: 'sep' es el hueco entre las PUNTAS de los paletos, asi que al cerrar se
	# tocan las puntas y no se montan una hilera entera sobre la otra (salia una cruz).
	var base: Vector2 = centro + fila * x - crece * (sep * 0.5 + largo_max) * (1.0 - 0.3 * k * k)
	var pta: Vector2 = base + fila * incl + crece * largo
	var w2: float = w * lerpf(0.78, 0.05, float(d[4]))
	var pts := PackedVector2Array([base - fila * w, base + fila * w, pta + fila * w2, pta - fila * w2])
	var borde: float = maxf(0.35, w * 0.18)
	var fuera := PackedVector2Array([base - fila * (w + borde) - crece * borde, base + fila * (w + borde) - crece * borde,
		pta + fila * (w2 + borde) + crece * borde, pta - fila * (w2 + borde) + crece * borde])
	_poligono(ci, fuera, Color(ENCIA, 0.8 * alfa))
	_poligono(ci, pts, Color(HUESO, alfa))


# Una MANDIBULA: media luna llena (la boca, oscura, con un halo difuminado detras) y los colmillos de hueso
# apuntando hacia 'hacia' (el eje del mordisco). 'c' = el centro de su filo.
func _mandibula(ci: CanvasItem, c: Vector2, hacia: Vector2, alfa: float) -> void:
	if alfa <= 0.01:
		return
	var r: float = _tam
	var lado := Vector2(-hacia.y, hacia.x)
	var abre: float = deg_to_rad(62.0)
	# La media luna: el arco de fuera (lejos del eje) y el de dentro (el filo), mas plano.
	var fuera := PackedVector2Array()
	var dentro := PackedVector2Array()
	var n: int = 12
	# Los dos arcos con el MISMO lado en cada punto (antes uno iba al reves que el otro, la media luna salia
	# cruzada y no se pintaba): el de fuera abombado hacia atras, el del filo casi recto.
	for i in n + 1:
		var a: float = lerpf(-abre, abre, float(i) / float(n))
		var lat: Vector2 = lado * sin(a) * r * 0.55
		fuera.append(c + lat - hacia * (cos(a) * r * 0.6 + r * 0.05))
		dentro.append(c + lat - hacia * cos(a) * r * 0.12)
	# EL HALO: la misma media luna un poco mas grande y casi transparente (el difuminado del filo).
	var halo_f := PackedVector2Array()
	var halo_d := PackedVector2Array()
	for i in fuera.size():
		halo_f.append(c + (fuera[i] - c) * 1.3)
		halo_d.append(c + (dentro[i] - c) * 1.1)
	_tira(ci, halo_f, halo_d, Color(BOCA, 0.28 * alfa))
	_tira(ci, fuera, dentro, Color(BOCA, 0.9 * alfa))
	# LOS COLMILLOS, del filo hacia dentro: el del medio mas corto, los dos de las puntas (los caninos) largos.
	var dientes: int = 5
	for k in dientes:
		var u: float = (float(k) + 0.5) / float(dientes)
		var i0: int = int(u * float(n))
		var base: Vector2 = dentro[i0]
		var ancho_d: float = r * 0.13
		var largo_d: float = r * (0.42 if k == 0 or k == dientes - 1 else 0.24)
		var b1: Vector2 = base - lado * ancho_d
		var b2: Vector2 = base + lado * ancho_d
		var punta: Vector2 = base + hacia * largo_d
		_poligono(ci, PackedVector2Array([b1, b2, punta]), Color(HUESO_SOMBRA, alfa))
		_poligono(ci, PackedVector2Array([b1 + lado * ancho_d * 0.35, b2, punta]), Color(HUESO, alfa))


# La banda entre dos arcos del mismo numero de puntos, en triangulos sueltos (no hay que triangular).
static func _tira(ci: CanvasItem, a: PackedVector2Array, b: PackedVector2Array, col: Color) -> void:
	if a.size() < 2 or a.size() != b.size() or col.a <= 0.0:
		return
	var pv := PackedVector2Array()
	pv.append_array(a)
	pv.append_array(b)
	var pc := PackedColorArray()
	pc.resize(pv.size())
	pc.fill(col)
	var n: int = a.size()
	var pi := PackedInt32Array()
	for i in n - 1:
		pi.append_array([i, i + 1, n + i, i + 1, n + i + 1, n + i])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)


static func _poligono(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() < 3 or col.a <= 0.0:
		return
	var tri: PackedInt32Array = Geometry2D.triangulate_polygon(pts)
	if tri.is_empty():
		return
	var cols := PackedColorArray()
	cols.resize(pts.size())
	cols.fill(col)
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), tri, pts, cols)


# ------------------------------------------------------------
#  EL POLVO DEL ATERRIZAJE (Frenesi)
# ------------------------------------------------------------
func _polvo(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var k: float = clampf(_t / T_POLVO, 0.0, 1.0)
	var apaga: float = 1.0 - smoothstep(T_POLVO, T_POLVO + 0.7, _t)
	if capa == _suelo:
		# La mancha oscura del golpe en el suelo, que se va.
		_bola(capa, _o, _r * 0.45 * (0.6 + 0.4 * k), Color(0.2, 0.16, 0.12, 0.35 * apaga))
		return
	if capa != _delante:
		return
	# EL ANILLO DE POLVO: bocanadas que salen del centro hacia el borde, se hinchan y se desvanecen.
	for p in _puffs:
		var u: float = float(p["u"]) * (1.0 - pow(1.0 - k, 2.0))
		var c: Vector2 = _o + Vector2(cos(float(p["a"])), sin(float(p["a"]))) * _r * u \
			+ Vector2(0.0, -float(p["sube"]) * k * K)
		var rr: float = _r * float(p["tam"]) * (0.5 + 0.9 * k)
		_bola(capa, c, rr * 1.25, Color(POLVO, 0.22 * apaga))
		_bola(capa, c + Vector2(-rr * 0.2, -rr * 0.25), rr * 0.8, Color(POLVO_CLARO, 0.35 * apaga))
	# Unas piedrecitas que saltan y caen.
	for s in _piedras:
		var kv: float = clampf(_t / 0.5, 0.0, 1.0)
		if kv >= 1.0:
			continue
		var d := Vector2(cos(float(s["a"])), sin(float(s["a"])) * K)
		var p2: Vector2 = _o + d * float(s["v"]) * 0.5 * kv - Vector2(0.0, float(s["sube"]) * 4.0 * kv * (1.0 - kv) * K)
		_bola(capa, p2, float(s["tam"]), Color(0.3, 0.25, 0.2, 1.0 - kv))


# ------------------------------------------------------------
#  EL CHILLIDO (rey rata)
# ------------------------------------------------------------
# El Grito del mandoble (BarridoAire._grito) en AGUDO: cuatro frentes mas finos y mas seguidos, y ninguno es un
# arco limpio: vibran (una onda fina que les corre por encima). Filo duro claro por fuera, que se difumina hacia
# dentro, y un halo tenue por delante. En el tramo de cerca (forma_tramos: ahi pega mas) van mas gruesos y vivos.
func _chillido(capa: Node2D) -> void:
	if capa != _delante or _t < 0.0 or forma == null:
		return
	var mitad: float = deg_to_rad(forma.apertura * 0.5)
	var a0: float = _dir.angle() - mitad
	var a1: float = _dir.angle() + mitad
	var cerca: float = _r * 0.6
	var alto := Vector2(0.0, -4.0)
	for k in 4:
		var tk: float = _t - float(k) * T_ENTRE_CH
		if tk < 0.0:
			continue
		var prog: float = clampf(tk / T_ONDA_CH, 0.0, 1.0)
		var rf: float = _r * prog
		var apaga: float = clampf((tk - T_ONDA_CH) / 0.15, 0.0, 1.0)
		var tramo: float = 1.0 if rf <= cerca else lerpf(1.0, 0.55, (rf - cerca) / maxf(_r - cerca, 1.0))
		var alfa: float = (0.8 - 0.12 * float(k)) * tramo * (1.0 - 0.3 * prog) * (1.0 - apaga)
		if alfa <= 0.0 or rf < 3.0:
			continue
		var grueso: float = lerpf(2.5, 5.5, prog) * (1.2 if rf <= cerca else 0.9)
		var ondula: float = 1.4 * (0.5 + prog)
		var n: int = 32
		for i in n:
			var s0: float = float(i) / float(n)
			var s1: float = float(i + 1) / float(n)
			var borde0: float = sin(s0 * PI)
			var borde1: float = sin(s1 * PI)
			var d0 := Vector2(cos(lerpf(a0, a1, s0)), sin(lerpf(a0, a1, s0)))
			var d1 := Vector2(cos(lerpf(a0, a1, s1)), sin(lerpf(a0, a1, s1)))
			var w0: float = rf + sin(s0 * 40.0 + _t * 80.0 + float(k) * 1.9) * ondula
			var w1: float = rf + sin(s1 * 40.0 + _t * 80.0 + float(k) * 1.9) * ondula
			var f0: Vector2 = _o + d0 * w0 + alto
			var f1: Vector2 = _o + d1 * w1 + alto
			var i0: Vector2 = _o + d0 * maxf(w0 - grueso, 0.0) + alto
			var i1: Vector2 = _o + d1 * maxf(w1 - grueso, 0.0) + alto
			var h0: Vector2 = _o + d0 * (w0 + grueso * 0.7) + alto
			var h1: Vector2 = _o + d1 * (w1 + grueso * 0.7) + alto
			var c0 := Color(Color.WHITE, alfa * borde0)
			var c1 := Color(Color.WHITE, alfa * borde1)
			var nada := Color(SONIDO, 0.0)
			# El cuerpo del frente: del filo (claro y duro) a nada hacia dentro.
			capa.draw_primitive(PackedVector2Array([f0, f1, i1]), PackedColorArray([c0, c1, nada]), PackedVector2Array())
			capa.draw_primitive(PackedVector2Array([f0, i1, i0]), PackedColorArray([c0, nada, nada]), PackedVector2Array())
			# El halo por delante, tenue.
			var hc0 := Color(SONIDO, alfa * borde0 * 0.3)
			var hc1 := Color(SONIDO, alfa * borde1 * 0.3)
			capa.draw_primitive(PackedVector2Array([f0, f1, h1]), PackedColorArray([hc0, hc1, nada]), PackedVector2Array())
			capa.draw_primitive(PackedVector2Array([f0, h1, h0]), PackedColorArray([hc0, nada, nada]), PackedVector2Array())


# ------------------------------------------------------------
#  LA ESTELA DE LA YUGULAR
# ------------------------------------------------------------
# Polvo que se levanta al paso del cuerpo por la linea (va con el, como el rastro del Placaje) y una marca de
# arrastre en el suelo que se va.
func _estela(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var lat: Vector2 = _dir.orthogonal()
	for p in _puffs:
		var tp: float = _t - float(p["u"]) * T_ESTELA
		if tp < 0.0 or tp > 0.75:
			continue
		var k: float = tp / 0.75
		var c: Vector2 = _o + _dir * _largo * float(p["u"]) + lat * _ancho * float(p["v"]) * 0.6
		if capa == _suelo:
			_bola(capa, c, _ancho * 0.4, Color(0.2, 0.16, 0.12, 0.28 * (1.0 - k)))
			continue
		if capa != _delante:
			continue
		var rr: float = _ancho * float(p["tam"]) * (0.6 + 0.8 * sqrt(k))
		var cc: Vector2 = c + Vector2(0.0, -float(p["sube"]) * k * K) - _dir * rr * 0.3 * k
		_bola(capa, cc, rr * 1.25, Color(POLVO, 0.3 * (1.0 - k)))
		_bola(capa, cc + Vector2(-rr * 0.2, -rr * 0.25), rr * 0.8, Color(POLVO_CLARO, 0.4 * (1.0 - k)))


# ------------------------------------------------------------
#  EL TEMBLOR (al que le pasa el Chillido)
# ------------------------------------------------------------
# Dos medias lunas de sonido a cada lado de la cabeza, ")" y "(", que vibran y se van abriendo mientras se apagan.
func _temblor(capa: Node2D) -> void:
	if capa != _delante or _t < 0.0:
		return
	var k: float = _t / T_TIEMBLA
	var alfa: float = (1.0 - k) * clampf(_t / 0.05, 0.0, 1.0)
	for s in [-1.0, 1.0]:
		for j in 2:
			var r: float = _ancho * (0.55 + 0.28 * float(j) + 0.15 * k)
			var vib: float = sin(_t * 90.0 + float(j) * 2.0 + s) * 0.8
			_arco_sonido(capa, _hasta + Vector2(vib, 0.0), r, s, maxf(1.2, _ancho * 0.1) * (1.0 - 0.3 * float(j)),
				Color(SONIDO, alfa * (0.9 - 0.35 * float(j))))


# Una media luna de sonido: arco de ±40 grados hacia 'lado' (1 = derecha, -1 = izquierda), gruesa en medio y
# afilada en las puntas, con su halo.
func _arco_sonido(ci: CanvasItem, c: Vector2, r: float, lado: float, grueso: float, col: Color) -> void:
	if col.a <= 0.01:
		return
	var fuera := PackedVector2Array()
	var dentro := PackedVector2Array()
	var halo_f := PackedVector2Array()
	var halo_d := PackedVector2Array()
	var base: float = 0.0 if lado > 0.0 else PI
	var n: int = 10
	for i in n + 1:
		var u: float = float(i) / float(n)
		var a: float = base + lerpf(-0.7, 0.7, u)
		var g: float = grueso * sin(PI * u)
		var d := Vector2(cos(a), sin(a) * 0.9)
		fuera.append(c + d * (r + g * 0.5))
		dentro.append(c + d * (r - g * 0.5))
		halo_f.append(c + d * (r + g * 1.4))
		halo_d.append(c + d * (r - g * 1.4))
	_tira(ci, halo_f, halo_d, Color(col, col.a * 0.25))
	_tira(ci, fuera, dentro, col)


# ------------------------------------------------------------
#  EL JABALI
# ------------------------------------------------------------
# EL COLMILLO: media luna de hueso que engancha de ABAJO ARRIBA por el lado de quien embiste (la pincelada del
# mandoble, BarridoAire._tajo: filo duro y claro por fuera que se difumina hacia dentro y hacia la cola). Mientras
# viaja el golpe la cabeza sube; en el golpe llega arriba y la cola la alcanza mientras se apaga.
func _colmillo(capa: Node2D) -> void:
	var cornada: bool = modo == Modo.CORNADA
	var r: float = _tam * 1.7
	var th: float = _a_colmillo
	var s: float = 1.0 if cos(th) >= 0.0 else -1.0
	var a_abajo: float = th + 1.3 * s
	var a_arriba: float = th - 1.3 * s
	var c: Vector2 = _hasta - Vector2(cos(th), sin(th)) * r * 0.45
	var sale: float = 0.05
	var u: float = clampf((_t + _viaje) / maxf(_viaje + sale, 0.01), 0.0, 1.0)
	u = 1.0 - (1.0 - u) * (1.0 - u)
	var cabeza: float = lerpf(a_abajo, a_arriba, u)
	var k_ido: float = clampf((_t - sale) / (0.3 if cornada else 0.22), 0.0, 1.0)
	var cola: float = lerpf(a_abajo, cabeza, maxf(0.15 * u, k_ido))
	var alfa: float = clampf((_t + _viaje) / 0.04, 0.0, 1.0) * (1.0 - k_ido * k_ido)
	var punta: Vector2 = c + Vector2(cos(cabeza), sin(cabeza)) * r
	if capa == _brillo:
		if _t >= 0.0 and _t < 0.14:
			BarridoAire.destello(capa, punta, _tam * (0.7 if cornada else 0.5),
				Color(1.0, 0.96, 0.88, 0.8 * (1.0 - _t / 0.14)), th)
		return
	if capa != _delante:
		return
	var grueso: float = r * (0.5 if cornada else 0.45)
	if alfa > 0.0:
		# Detras, la misma media luna algo mayor y OSCURA (el contorno de los dientes): sin ella el hueso se perdia
		# sobre un cuerpo claro.
		_media_luna(capa, c, cola, cabeza, r * 1.06, grueso * 1.3, ENCIA, ENCIA, alfa * 0.5, false)
		_media_luna(capa, c, cola, cabeza, r, grueso, HUESO, HUESO_SOMBRA, alfa, false)
	if not cornada or _t < 0.0:
		return
	# EL DESGARRO en la punta (gotas que salen hacia fuera y caen) y los TERRONES que saltan de sus pies.
	var k: float = clampf(_t / 0.4, 0.0, 1.0)
	var fuera := Vector2(cos(cabeza), sin(cabeza))
	for i in 4:
		var d: Vector2 = fuera.rotated((float(i) - 1.5) * 0.35)
		var p: Vector2 = punta + d * _tam * (0.2 + 0.7 * k) + Vector2(0.0, _tam * 0.6 * k * k)
		BarridoAire.cometa(capa, p - d * _tam * 0.3, p, maxf(1.2, _tam * 0.12), Color(SANGRE, 0.8 * (1.0 - k)))
	var pies: Vector2 = _hasta + Vector2(0.0, _largo * 0.5)
	for pd in _piedras:
		var kt: float = clampf(_t / 0.5, 0.0, 1.0)
		if kt >= 1.0:
			continue
		var p2: Vector2 = pies + Vector2(float(pd["vx"]) * kt, -float(pd["sube"]) * 4.0 * kt * (1.0 - kt) * K)
		var tam: float = float(pd["tam"])
		capa.draw_rect(Rect2(p2 - Vector2(tam, tam) * 0.5, Vector2(tam, tam)), Color(TIERRA, 1.0 - kt * kt * kt))


# LO QUE ARROLLA LA EMBESTIDA, en cada cuerpo: el FRENTE DEL CHOQUE (una media luna combada hacia quien embiste,
# que se abre y se apaga), un destello, y un CHORRO DE POLVO desde sus pies hacia donde sale despedido.
func _choque(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var sale: Vector2 = _eje
	if capa == _brillo:
		if _t < 0.12:
			BarridoAire.destello(capa, _hasta - sale * _ancho * 0.3, _tam * 0.8,
				Color(1.0, 0.95, 0.85, 0.8 * (1.0 - _t / 0.12)), sale.angle())
		return
	if capa != _delante:
		return
	var kf: float = clampf(_t / 0.22, 0.0, 1.0)
	var r: float = _ancho * (0.55 + 0.35 * kf)
	var th: float = (-sale).angle()
	var c: Vector2 = _hasta + sale * r * 0.6
	_media_luna(capa, c, th - 1.0, th + 1.0, r, r * 0.35, Color(0.96, 0.92, 0.84), POLVO_CLARO, 0.9 * (1.0 - kf), true)
	var k: float = clampf(_t / 0.6, 0.0, 1.0)
	var lejos := Vector2(sale.x, sale.y * K).normalized()
	var pies: Vector2 = _hasta + Vector2(0.0, _largo * 0.5)
	for i in 10:
		var d: Vector2 = lejos.rotated((float(i) - 4.5) * 0.12)
		var c2: Vector2 = pies + d * (6.0 + 26.0 * sqrt(k)) * (0.6 + 0.05 * float(i)) - Vector2(0.0, 5.0 * k)
		var rr: float = _ancho * 0.18 * (0.6 + 0.9 * k)
		_bola(capa, c2, rr * 1.25, Color(POLVO, 0.3 * (1.0 - k)))
		_bola(capa, c2 + Vector2(-rr * 0.2, -rr * 0.25), rr * 0.8, Color(POLVO_CLARO, 0.4 * (1.0 - k)))


# EL SURCO DE LA EMBESTIDA: las rodadas de las pezuñas (dos hileras de huellas que aparecen al paso), el polvo de
# la estela y los terrones que saltan a los lados.
func _surco(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var lat: Vector2 = _dir.orthogonal()
	var cab: float = clampf(_t / T_ESTELA, 0.0, 1.0) * 0.85
	var seca: float = 1.0 - smoothstep(T_ESTELA + 0.4, T_ESTELA + 0.9, _t)
	if capa == _suelo:
		var paso: float = 5.0
		for i in int(_largo * cab / paso):
			var u: float = float(i) * paso / _largo
			for s in [-1.0, 1.0]:
				var p: Vector2 = _o + _dir * _largo * u + lat * _ancho * 0.22 * s \
					+ _dir * (1.5 if (i % 2 == 0) == (s > 0.0) else 0.0)
				_bola(capa, p, 2.6, Color(0.16, 0.12, 0.09, 0.55 * seca))
		return
	if capa != _delante:
		return
	_estela(capa)
	for pd in _piedras:
		var tp: float = _t - float(pd["u"]) * T_ESTELA
		if tp < 0.0 or tp > 0.45:
			continue
		var kv: float = tp / 0.45
		var base: Vector2 = _o + _dir * _largo * float(pd["u"]) + lat * _ancho * 0.3 * float(pd["lado"])
		var p2: Vector2 = base + lat * float(pd["lado"]) * float(pd["v"]) * kv \
			- Vector2(0.0, float(pd["sube"]) * 4.0 * kv * (1.0 - kv) * K)
		var tam: float = float(pd["tam"])
		capa.draw_rect(Rect2(p2 - Vector2(tam, tam) * 0.5, Vector2(tam, tam)), Color(TIERRA, 1.0 - kv * kv * kv))


# LOS DOS PISOTONES: en cada uno, la mancha del golpe bajo el, grietas que se abren desde sus patas (las del
# martillo: raja negra que se afila con su labio claro, SueloRoto._trazo) y un anillo de polvo a ras.
func _pisoton(capa: Node2D) -> void:
	if _t < 0.0:
		return
	var apaga: float = 1.0 - smoothstep(T_PISA_ENTRE + 0.6, T_PISA_ENTRE + 1.2, _t)
	if capa == _suelo:
		for k in 2:
			if _t >= float(k) * T_PISA_ENTRE:
				_bola(capa, _o, _r * (0.35 + 0.1 * float(k)), Color(0.2, 0.16, 0.12, 0.3 * apaga))
		for g in _grietas:
			var tg: float = _t - float(g["t0"])
			if tg < 0.0:
				continue
			var pts: PackedVector2Array = g["pts"]
			var n: int = clampi(int(ceil(float(pts.size()) * clampf(tg / T_GRIETA, 0.0, 1.0))), 0, pts.size())
			if n >= 2:
				_trazo_grieta(capa, pts, n, float(g["w0"]), float(g["w1"]), apaga)
		return
	if capa != _delante:
		return
	for p in _puffs:
		var tk: float = _t - float(p["k"]) * T_PISA_ENTRE
		if tk < 0.0 or tk > 0.6:
			continue
		var k2: float = tk / 0.6
		var rad: float = _r * float(p["u"]) * (0.3 + 0.7 * (1.0 - pow(1.0 - k2, 2.0)))
		var c: Vector2 = _o + Vector2(cos(float(p["a"])), sin(float(p["a"]))) * rad - Vector2(0.0, float(p["sube"]) * k2 * K)
		var rr: float = _r * float(p["tam"]) * (0.6 + 0.8 * k2)
		_bola(capa, c, rr * 1.2, Color(POLVO, 0.26 * (1.0 - k2)))
		_bola(capa, c + Vector2(-rr * 0.2, -rr * 0.25), rr * 0.75, Color(POLVO_CLARO, 0.34 * (1.0 - k2)))


static func _trazo_grieta(ci: CanvasItem, pts: PackedVector2Array, n: int, w0: float, w1: float, a: float) -> void:
	var total: float = float(maxi(1, pts.size() - 1))
	for i in n - 1:
		var w: float = lerpf(w0, w1, float(i) / total)
		ci.draw_line(pts[i] + Vector2(0.6, 1.0), pts[i + 1] + Vector2(0.6, 1.0), Color(SueloRoto.LABIO, 0.35 * a), maxf(0.6, w * 0.5))
	for i in n - 1:
		var w2: float = lerpf(w0, w1, float(i) / total)
		ci.draw_line(pts[i], pts[i + 1], Color(SueloRoto.OSCURO, 0.95 * a), w2)


# UNA MEDIA LUNA sobre un arco alrededor de 'c', de 'a_cola' a 'a_cabeza' (BarridoAire._tajo): el filo, a 'r_filo',
# duro y del color 'filo', y hacia dentro se difumina a nada. Gruesa cerca de la cabeza y afilada en las puntas; con
# 'simetrica', gruesa en medio (el frente del choque).
static func _media_luna(ci: CanvasItem, c: Vector2, a_cola: float, a_cabeza: float, r_filo: float, grueso: float,
		filo: Color, dentro: Color, alfa: float, simetrica: bool) -> void:
	if alfa <= 0.0 or absf(a_cabeza - a_cola) < 0.01:
		return
	var n: int = maxi(8, int(absf(a_cabeza - a_cola) / 0.08))
	var fr: Array = [0.0, 0.12, 0.4, 1.0]
	var al: Array = [1.0, 0.85, 0.3, 0.0]
	for i in n:
		var s0: float = float(i) / float(n)
		var s1: float = float(i + 1) / float(n)
		var d0 := Vector2(cos(lerpf(a_cola, a_cabeza, s0)), sin(lerpf(a_cola, a_cabeza, s0)))
		var d1 := Vector2(cos(lerpf(a_cola, a_cabeza, s1)), sin(lerpf(a_cola, a_cabeza, s1)))
		var g0: float = grueso * (sin(PI * s0) if simetrica else sin(PI * pow(s0, 2.2)))
		var g1: float = grueso * (sin(PI * s1) if simetrica else sin(PI * pow(s1, 2.2)))
		var l0: float = alfa * (1.0 if simetrica else 0.2 + 0.8 * s0)
		var l1: float = alfa * (1.0 if simetrica else 0.2 + 0.8 * s1)
		for k in fr.size() - 1:
			var p00: Vector2 = c + d0 * (r_filo - g0 * float(fr[k]))
			var p10: Vector2 = c + d1 * (r_filo - g1 * float(fr[k]))
			var p01: Vector2 = c + d0 * (r_filo - g0 * float(fr[k + 1]))
			var p11: Vector2 = c + d1 * (r_filo - g1 * float(fr[k + 1]))
			var col: Color = dentro.lerp(filo, 1.0 - float(fr[k]))
			var c00 := Color(col, l0 * float(al[k]))
			var c10 := Color(col, l1 * float(al[k]))
			var c01 := Color(dentro, l0 * float(al[k + 1]))
			var c11 := Color(dentro, l1 * float(al[k + 1]))
			ci.draw_primitive(PackedVector2Array([p00, p10, p11]), PackedColorArray([c00, c10, c11]), PackedVector2Array())
			ci.draw_primitive(PackedVector2Array([p00, p11, p01]), PackedColorArray([c00, c11, c01]), PackedVector2Array())


# Una bola blanda: el centro lleno y el borde que se difumina a nada.
static func _bola(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	if r <= 0.3 or col.a <= 0.01:
		return
	var n: int = 16
	var pv := PackedVector2Array([c])
	var pc := PackedColorArray([col])
	var pi := PackedInt32Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		pv.append(c + Vector2(cos(a), sin(a)) * r)
		pc.append(Color(col, 0.0))
		pi.append_array([0, 1 + i, 1 + (i + 1) % n])
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), pi, pv, pc)
