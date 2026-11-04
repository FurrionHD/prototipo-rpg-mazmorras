# ============================================================
#  trent_aire.gd  (class_name TrentAire)
#  LOS EFECTOS DE LOS MUTANTES DEL TRENT en el mapa (02/11/2026: el Tocon ambarino y el Espantajo; memoria trent-mutante), EN PIXEL ART
#  (04/11/2026, memoria efectos-a-pixel-art): sus hojas salen de tools/sprites_sdf/trent_efectos_horno.py; aqui, que sale y donde.
#    GEISER     sale por la grieta de su espalda (el chorro: CintaPixel, mide lo que toque) y forma una NUBE negra que llueve sobre su circulo.
#    CHUPAR     HILOS violeta que reptan de la victima a sus pies, con bolitas de luz (CintaPixel).
#    GOTERON    la Resina y la Savia negra: el pegote vuela desde su boca y revienta al caer.
#    ESTALLIDO  se le rompe la costra al Tocon: los grumos revientan y caen.
#  LO QUE SE QUEDA PEGADO (pegado(): seguir, poner_nivel y secar, como siempre):
#    RESINA     el cepo de ambar en los pies; al soltarle, a trozos.   HUMO  el humo violeta de la Savia negra, mas cuantas mas cargas.
#    CARGA      el Geiser cargando: le laten SUS grietas (GrietaPixel). SECO  cuanto mas seco, mas le laten y se extienden.
# ============================================================
extends RefCounted
class_name TrentAire

enum Modo { GEISER, CHUPAR, RESINA, ESTALLIDO, HUMO, CARGA, SECO, GOTERON }

const NEGRO := Color(0.05, 0.03, 0.07)
const SAVIA := Color(0.12, 0.07, 0.16)
const BORDE := Color(0.55, 0.42, 0.78)
const VIOLETA := Color(0.62, 0.40, 0.95)
const AMBAR := Color(0.95, 0.62, 0.15)
const AMBAR_OSCURO := Color(0.45, 0.22, 0.04)
const AMBAR_CLARO := Color(1.0, 0.9, 0.55)
# las cintas, en pixel: [borde, cuerpo, luz]
const PAL_NEGRA: PackedColorArray = [Color8(6, 3, 10), Color8(34, 20, 54), Color8(84, 56, 138)]
const PAL_HILO: PackedColorArray = [Color8(44, 28, 74), Color8(78, 52, 124), Color8(126, 92, 188)]

const T_SALE := 0.28        # el chorro sale cuando se arquea (su 'geiser': 8 a 10, el arqueo en el 0,35)
const T_CHORRO := 0.2       # lo que tarda en llegar a la nube
const T_CHUPAR := 1.3
const T_GOTERON := 0.4      # lo que vuela el pegote hasta caer (= retraso del golpe)
const GRIETA_NODO := 35.0
const BOCA_TOCON := 25.0
const BOCA_ESPANTAJO := 85.0
const ALTO_NUBE := 110.0    # (mundo) a que altura se forma la nube sobre su circulo (la de su hoja)
const ARCO_CHORRO := 52.0


static func _r() -> float:
	return maxf(BarridoAire.ritmo, 0.05)


static func _marca(n: Node, m: int) -> Node:
	if n != null:
		n.set_meta("trent", m)
	return n


# GEISER desde 'grieta' sobre el circulo de 'centro'. ('version' ya no cuenta: el jefe eligio la nube.)
static func geiser(padre: Node, grieta: Vector2, centro: Vector2, _rr: float, _version: int, _semilla: int, espera: float = 0.0) -> Node:
	CintaPixel.lanzar(padre, grieta, centro - Vector2(0.0, ALTO_NUBE), PAL_NEGRA, T_CHORRO, 0.15, 0.25, espera, _r()).forma(1, 0.0, 3.5, 0.4, ARCO_CHORRO, 1.0)
	return _marca(EfectoPixel.lanzar(padre, "trent", "nube", centro, 0, null, espera + T_CHORRO, -1.0, _r()), Modo.GEISER)


# CHUPAR: de 'victima' (sus pies) a 'pies' (los del Espantajo).
static func chupar(padre: Node, victima: Vector2, pies: Vector2, _version: int, _semilla: int) -> Node:
	var c: CintaPixel = CintaPixel.lanzar(padre, victima, pies, PAL_HILO, 0.4, T_CHUPAR - 0.8, 0.4, 0.0, _r())
	if c != null:
		c.forma(3, 9.0, 1.0, 0.0, 0.0, 1.5).con_bolitas(Color8(206, 186, 250))
		c.z_index = SueloRoto.Z_SUELO + 1
	return _marca(c, Modo.CHUPAR)


# EN EL JUEGO, por la huella (SueloRoto.Tipo.TRENT_*): el GEISER y el GOTERON de la Resina ('m' = RESINA) o de la Savia negra ('m' = HUMO).
# De donde sale lo da el 'ancho' del circulo (lo lejos que esta quien lo lanza). 'espera' = hasta el golpe de su animacion.
static func area(padre: Node, f: CombatFormas.Forma, m: int, semilla: int, espera: float) -> Node:
	if padre == null or f == null:
		return null
	var dir: Vector2 = f.dir.normalized() if f.dir.length_squared() > 0.0001 else Vector2.RIGHT
	var pies: Vector2 = f.centro - dir * f.ancho if f.ancho > 1.0 else f.centro
	if m == Modo.GEISER:
		return geiser(padre, pies + Vector2(-signf(dir.x) * 10.0, -GRIETA_NODO), f.centro, f.radio, 1, semilla, maxf(espera - T_SALE / _r(), 0.0))
	var ambar: bool = m == Modo.RESINA
	var boca: Vector2 = pies + Vector2(dir.x * 14.0, -(BOCA_TOCON if ambar else BOCA_ESPANTAJO))
	var e: EfectoPixel = EfectoPixel.lanzar(padre, "trent", "cae_ambar" if ambar else "cae_negra", f.centro, 0, null, espera + T_GOTERON, -1.0, _r())
	if e != null:
		e.poner_vuelo("trent", "gota_ambar" if ambar else "gota_negra", boca, f.centro, 22.0, T_GOTERON)
	return _marca(e, Modo.GOTERON)


static func retraso(m: int) -> float:
	return 0.75 if m == Modo.GEISER else T_GOTERON


# LO QUE SE QUEDA PEGADO A ALGUIEN (RESINA, HUMO, CARGA, SECO): sobre 'caja' (su cuerpo). CARGA y SECO se le ponen a su SPRITE ('spr').
static func pegado(padre: Node, m: int, caja: Rect2, nivel_: int, _semilla: int, spr: AnimatedSprite2D = null) -> Node:
	if padre == null:
		return null
	if m == Modo.CARGA or m == Modo.SECO:
		return GrietaPixel.poner(spr, m == Modo.CARGA, nivel_) if spr != null else null
	var p: PiezaPixel
	if m == Modo.RESINA:
		p = PiezaPixel.crear(padre, "trent", "cepo_sale", "cepo_dura", "cepo_vete", Vector2.ZERO, 0, PackedColorArray(), 0.0, _r())
	else:
		p = PiezaPixel.crear(padre, "trent", "", "humo_1", "", Vector2.ZERO)
		if p != null:
			p.con_niveles(["humo_1", "humo_2", "humo_3", "humo_4", "humo_5"], nivel_)
	if p != null:
		p.seguir(caja)
		p.set_meta("trent", m)
	return p


# EL ESTALLIDO de la costra, en el cuerpo 'caja' del Tocon.
static func estallido(padre: Node, caja: Rect2, _semilla: int) -> Node:
	return _marca(EfectoPixel.lanzar(padre, "trent", "costra", Vector2(caja.get_center().x, caja.end.y), 0, null, 0.0, -1.0, _r()), Modo.ESTALLIDO)


# UNA CINTA rellena por 'pts' con un ancho por punto. (La usa aun la araña; se va cuando le llegue.)
static func _cinta(ci: CanvasItem, pts: PackedVector2Array, anchos: PackedFloat32Array, col: Color) -> void:
	if pts.size() < 2 or col.a <= 0.01:
		return
	var largo: float = 0.0
	for i in pts.size() - 1:
		largo += pts[i].distance_to(pts[i + 1])
	if largo < 2.0:
		return
	var izq := PackedVector2Array()
	var der := PackedVector2Array()
	for i in pts.size():
		var d: Vector2 = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)])
		if d.length_squared() < 0.0001:
			d = Vector2.RIGHT
		var n: Vector2 = d.normalized().orthogonal() * anchos[i] * 0.5
		izq.append(pts[i] + n)
		der.append(pts[i] - n)
	der.reverse()
	izq.append_array(der)
	Poligono.relleno(ci, izq, col)
