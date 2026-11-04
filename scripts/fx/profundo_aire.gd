# ============================================================
#  profundo_aire.gd  (class_name ProfundoAire)
#  LOS EFECTOS DE LOS MUTANTES DEL SLIME PROFUNDO en el mapa (07/10/2026: el slime de arrecife y el de escarcha), EN PIXEL ART (04/11/2026,
#  memoria efectos-a-pixel-art): aqui solo se decide que hoja sale y donde, y los tiempos que usa el combate. Las hojas salen de
#  tools/sprites_sdf/slime_profundo_efectos_horno.py. El AGUA del arrecife es agua de mar con sus CORALES; el FRIO de la escarcha, blanco azulado.
#  POR EL SUELO (SueloRoto.Tipo.PROFUNDO_*): MAREA, CHORRO, CORAL, ESTALLIDO, ALIENTO y CARAMBANOS (uno por circulo de la fila, uno tras otro).
#  SOBRE EL CUERPO (CombatFX.Estilo.PROFUNDO_*, ver sobre_cuerpo): ANEMONA (los tentaculos, por celdas: TentaculosPixel, y donde pican) y HELADA.
#  Todo sale de la forma: el mismo dibujo en todas las maquinas.
# ============================================================
extends RefCounted
class_name ProfundoAire

enum Modo { MAREA, CHORRO, CORAL, ESTALLIDO, ALIENTO, CARAMBANOS, ANEMONA, HELADA }

# (estos tiempos estan tambien en las hojas: ver su horno)
const T_OLA := 0.32
const T_CHORRO := 0.16
const T_VUELO := 0.22
const T_ESTALLA := 0.2
const T_SOPLO := 0.32
const T_MARCA := 0.22
const T_ENTRE := 0.12
const T_CAE := 0.2
const T_ESTIRA := 0.12          # lo que tardan los tentaculos en llegar (= su vuelo en CombatFX.T_VUELO)
const T_PICA := 0.1
const T_RECOGE := 0.16


static func area(padre: Node, f: CombatFormas.Forma, m: int, _semilla: int, espera: float) -> Node2D:
	if padre == null or f == null:
		return null
	var ritmo: float = maxf(BarridoAire.ritmo, 0.05)
	var dir: int = SpriteLienzo.dir8(f.dir) if f.dir.length_squared() > 0.0001 else 0
	match m:
		Modo.MAREA:
			return EfectoPixel.lanzar(padre, "slime", "marea", f.centro, 0, null, espera, -1.0, ritmo)
		Modo.ESTALLIDO:
			return EfectoPixel.lanzar(padre, "slime", "estallido", f.centro, 0, null, espera, -1.0, ritmo)
		Modo.CHORRO:
			return EfectoPixel.lanzar(padre, "slime", "chorro", f.origen, dir, null, espera, -1.0, ritmo)
		Modo.CORAL:
			return EfectoPixel.lanzar(padre, "slime", "coral", f.origen, dir, null, espera, -1.0, ritmo)
		Modo.ALIENTO:
			return EfectoPixel.lanzar(padre, "slime", "aliento", f.origen, dir, null, espera, -1.0, ritmo)
		Modo.CARAMBANOS:
			var primero: Node2D = null
			var pts: Array = f.centros_bolas()
			for i in pts.size():
				var e: EfectoPixel = EfectoPixel.lanzar(padre, "slime", "carambano", pts[i], 0, null, espera, -1.0, ritmo)
				if e != null:
					e.retardo = T_ENTRE * float(i)
					if primero == null:
						primero = e
			return primero
	return null


# LOS DE SOBRE EL CUERPO (CombatFX.dibujo_en_mapa -> CombatTactico._on_dibujo_mapa). 'desde' = el cuerpo del slime,
# 'caja' y 'pies_v' = los del que lo recibe; 'espera' = lo que falta para el golpe (su vuelo).
static func sobre_cuerpo(padre: Node, m: int, desde: Rect2, caja: Rect2, pies_v: Vector2, _semilla: int, espera: float, ritmo: float) -> Node2D:
	if padre == null:
		return null
	var r: float = maxf(ritmo, 0.05)
	if m != Modo.ANEMONA:
		return EfectoPixel.lanzar(padre, "slime", "helada", pies_v, 0, null, espera, -1.0, r)
	# Pican en su cuerpo, un pelo por debajo del centro; salen del borde del slime hacia el, por abajo (donde lleva la anemona su sprite).
	var hasta: Vector2 = caja.get_center() + Vector2(0.0, caja.size.y * 0.1)
	var c_desde: Vector2 = desde.get_center() if desde.has_area() else hasta - Vector2(36.0, 0.0)
	var eje: Vector2 = (hasta - c_desde).normalized() if hasta.distance_squared_to(c_desde) > 1.0 else Vector2.RIGHT
	var a: float = maxf(desde.size.x * 0.5, 4.0)
	var b: float = maxf(desde.size.y * 0.5, 4.0)
	var borde: float = 1.0 / sqrt((eje.x / a) * (eje.x / a) + (eje.y / b) * (eje.y / b))
	var o: Vector2 = c_desde + eje * borde * 0.8 + Vector2(0.0, desde.size.y * 0.12)
	var llega: float = maxf(espera, 0.0)
	return TentaculosPixel.lanzar(padre, o, hasta, T_ESTIRA, T_PICA, T_RECOGE, maxf(llega - T_ESTIRA, 0.0), r)


# CUANDO LE LLEGA a 'p' (en segundos desde que se lanza). El mismo numero manda el dibujo y el golpe.
static func retraso(m: int, f: CombatFormas.Forma, p: Vector2) -> float:
	if f == null:
		return 0.0
	match m:
		Modo.MAREA:
			var u: float = clampf(p.distance_to(f.centro) / maxf(f.radio, 1.0), 0.0, 1.0)
			return T_OLA * (1.0 - sqrt(1.0 - u))
		Modo.ESTALLIDO:
			var u2: float = clampf(p.distance_to(f.centro) / maxf(f.radio, 1.0), 0.0, 1.0)
			return T_ESTALLA * (1.0 - sqrt(1.0 - u2))
		Modo.CHORRO:
			return T_CHORRO * clampf((p - f.origen).dot(f.dir) / maxf(f.largo, 1.0), 0.0, 1.0)
		Modo.CORAL:
			return T_VUELO * clampf(p.distance_to(f.origen) / maxf(f.radio, 1.0), 0.0, 1.0)
		Modo.ALIENTO:
			return T_SOPLO * clampf(p.distance_to(f.origen) / maxf(f.radio, 1.0), 0.0, 1.0)
		Modo.CARAMBANOS:
			# El carambano que le cae mas cerca.
			var pts: Array = f.centros_bolas()
			var mejor: int = 0
			for i in pts.size():
				if (pts[i] as Vector2).distance_to(p) < (pts[mejor] as Vector2).distance_to(p):
					mejor = i
			return T_MARCA + T_ENTRE * float(mejor) + T_CAE
	return 0.0


static func t_salir(m: int) -> float:
	match m:
		Modo.MAREA: return T_OLA
		Modo.ESTALLIDO: return T_ESTALLA
		Modo.CHORRO: return T_CHORRO
		Modo.CORAL: return T_VUELO
		Modo.ALIENTO: return T_SOPLO
		Modo.CARAMBANOS: return T_MARCA + T_CAE
	return 0.2
