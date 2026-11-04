# ============================================================
#  abisal_aire.gd  (class_name AbisalAire)
#  LOS EFECTOS DE LOS MUTANTES DEL SLIME ABISAL en el mapa (06/10/2026: el slime de cielo nocturno y el de mil ojos), EN PIXEL ART
#  (04/11/2026, memoria efectos-a-pixel-art): aqui solo se decide que hoja sale y donde, y los tiempos que usa el combate. Las hojas
#  salen de tools/sprites_sdf/slime_abisal_efectos_horno.py; las estrellas y los rayos son LUZ y la oscuridad, nuestro lenguaje.
#  POR EL SUELO (SueloRoto.Tipo.ABISAL_*):
#    LLUVIA     Lluvia de estrellas: una estrella fugaz por punto (puntos_lluvia), una tras otra.
#    RAYO       un rayo de la Constelacion (RayoPixel: mide lo que toque).
#    MIRADA     un rayo de la Mirada estelar: gordo, con los bordes cian y magenta (los iris de sus ojos).
#    PARPADEO   el Parpadeo cegador: un fogonazo de luz en abanico.
#    ECLIPSE    el Eclipse: la luna negra tapa la estrella sobre su cabeza y su noche se derrama por el suelo.
#    AGUJERO    el Agujero negro: una bolita de noche vuela hasta el sitio y alli se abre el remolino que se traga las estrellas.
#  SOBRE EL SUELO, quieta mientras dure la pelea:
#    estrella() la estrella que deja al moverse (PiezaPixel: titila y al secarse se apaga en un destello).
#  Todo sale de la forma: el mismo dibujo en todas las maquinas.
# ============================================================
extends RefCounted
class_name AbisalAire

enum Modo { LLUVIA, RAYO, MIRADA, PARPADEO, ECLIPSE, AGUJERO, ESTRELLA }

# LA LLUVIA
const FUGACES := 4
const T_MARCA := 0.25          # la marca del suelo se enciende antes de que caiga
const T_ENTRE := 0.16          # entre estrella y estrella
const T_CAE := 0.32            # lo que tarda cada una en bajar (T_MARCA + T_CAE = el marco 6 de su hoja, ver su horno)
const R_IMPACTO := 18.0

# LOS RAYOS
const T_TRAZA := 0.14
const T_RAYO := 0.35
const T_APAGA_RAYO := 0.3
const ALTO_RAYO := 6.4          # a que altura van (de pecho a pecho)
const RAYO_PAL: PackedColorArray = [Color8(122, 162, 255), Color8(204, 222, 255), Color8(255, 255, 255)]
const CIAN := Color8(90, 240, 255)
const MAGENTA := Color8(255, 104, 240)

# EL PARPADEO
const T_FOGONAZO := 0.22

# EL ECLIPSE
const T_ENCIENDE := 0.22         # la estrella sobre su cabeza
const T_TAPA := 0.3              # la luna negra se le pone delante (a la vez se derrama la noche)

# EL AGUJERO NEGRO
const V_BOLITA := 320.0
const T_ABRE := 0.3
const ALTO_BOLITA := 20.0


static func area(padre: Node, f: CombatFormas.Forma, m: int, _semilla: int, espera: float, n: int = 0) -> Node2D:
	if padre == null or f == null:
		return null
	var ritmo: float = maxf(BarridoAire.ritmo, 0.05)
	match m:
		Modo.LLUVIA:
			var pts: Array = puntos_lluvia(f, n if n > 0 else (f.tramos if f.tramos > 0 else FUGACES))
			var primera: Node2D = null
			for i in pts.size():
				var e: EfectoPixel = EfectoPixel.lanzar(padre, "slime", "fugaz", pts[i], 0, null, espera, -1.0, ritmo)
				if e != null:
					e.retardo = T_ENTRE * float(i)
					if primera == null:
						primera = e
			return primera
		Modo.RAYO, Modo.MIRADA:
			var alto := Vector2(0.0, ALTO_RAYO)
			var gordo: bool = m == Modo.MIRADA
			return RayoPixel.lanzar(padre, f.origen - alto, f.origen + f.dir * f.largo - alto, 4.0 if gordo else 2.6, RAYO_PAL,
				T_TRAZA, T_RAYO, T_APAGA_RAYO, espera, ritmo, CIAN if gordo else Color(0, 0, 0, 0), MAGENTA if gordo else Color(0, 0, 0, 0))
		Modo.PARPADEO:
			var dir: int = SpriteLienzo.dir8(f.dir) if f.dir.length_squared() > 0.0001 else 0
			return EfectoPixel.lanzar(padre, "slime", "parpadeo", f.origen, dir, null, espera, -1.0, ritmo)
		Modo.ECLIPSE:
			return EfectoPixel.lanzar(padre, "slime", "eclipse_mil" if f.radio > 90.0 else "eclipse", f.centro, 0, null, espera, -1.0, ritmo)
		Modo.AGUJERO:
			var tv: float = t_vuela(f)
			var ag: EfectoPixel = EfectoPixel.lanzar(padre, "slime", "agujero_mil" if f.radio > 77.0 else "agujero", f.centro, 0, null, espera + tv, -1.0, ritmo)
			if ag != null and tv > 0.01 and f.dir != Vector2.ZERO:
				ag.poner_vuelo("slime", "agujero_bola", f.centro - f.dir.normalized() * f.ancho, f.centro, ALTO_BOLITA, tv)
			return ag
	return null


# LA ESTRELLA QUE DEJA AL MOVERSE (charco_estilo 8, ver CombatTactico.poner_estrella): 'f' = su circulito.
static func estrella(padre: Node, f, _semilla: int) -> PiezaPixel:
	if padre == null or f == null:
		return null
	return PiezaPixel.crear(padre, "slime", "estrella_sale", "estrella_dura", "estrella_vete", f.centro)


# DONDE CAE CADA ESTRELLA dentro del circulo. Sale SOLO de la forma (su centro, su radio y cuantas: f.tramos), asi que
# el combate (a quien le pega) y el dibujo (donde se ve caer) dan lo mismo en todas las maquinas.
static func puntos_lluvia(f: CombatFormas.Forma, n: int = 0) -> Array:
	var out: Array = []
	if f == null:
		return out
	if n <= 0:
		n = f.tramos if f.tramos > 0 else FUGACES
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(roundi(f.centro.x * 16.0), roundi(f.centro.y * 16.0), n))
	var r: float = maxf(f.radio - R_IMPACTO * 0.4, 4.0)
	var intentos: int = 0
	while out.size() < n and intentos < 80:
		intentos += 1
		var a: float = rng.randf_range(0.0, TAU)
		var d: float = r * sqrt(rng.randf())
		var p: Vector2 = f.centro + Vector2(cos(a), sin(a)) * d
		var lejos: bool = true
		for q in out:
			if (q as Vector2).distance_to(p) < R_IMPACTO * 1.1:
				lejos = false
				break
		if lejos or intentos > 60:
			out.append(p)
	return out


# CUANDO LE LLEGA a 'p' (en segundos desde que se lanza).
static func retraso(m: int, f: CombatFormas.Forma, p: Vector2) -> float:
	if f == null:
		return 0.0
	match m:
		Modo.LLUVIA:
			# La estrella que le cae mas cerca.
			var pts: Array = puntos_lluvia(f)
			var mejor: int = 0
			for i in pts.size():
				if (pts[i] as Vector2).distance_to(p) < (pts[mejor] as Vector2).distance_to(p):
					mejor = i
			return T_MARCA + T_ENTRE * float(mejor) + T_CAE
		Modo.RAYO, Modo.MIRADA:
			var u: float = clampf((p - f.origen).dot(f.dir) / maxf(f.largo, 1.0), 0.0, 1.0)
			return T_TRAZA * u
		Modo.PARPADEO:
			return T_FOGONAZO * clampf(p.distance_to(f.origen) / maxf(f.radio, 1.0), 0.0, 1.0)
		Modo.ECLIPSE:
			return T_ENCIENDE + T_TAPA * clampf(p.distance_to(f.centro) / maxf(f.radio, 1.0), 0.0, 1.0)
		Modo.AGUJERO:
			return t_vuela(f) + T_ABRE
	return 0.0


# Lo que tarda la bolita del Agujero negro en llegar (su 'ancho' = lo lejos que esta quien la lanza).
static func t_vuela(f: CombatFormas.Forma) -> float:
	return maxf(f.ancho - 6.0, 0.0) / V_BOLITA


static func t_salir(m: int) -> float:
	match m:
		Modo.LLUVIA: return T_MARCA + T_CAE
		Modo.RAYO, Modo.MIRADA: return T_TRAZA
		Modo.PARPADEO: return T_FOGONAZO
		Modo.ECLIPSE: return T_ENCIENDE + T_TAPA
		Modo.AGUJERO: return T_ABRE
	return 0.2
