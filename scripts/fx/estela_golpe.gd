# ============================================================
#  estela_golpe.gd
#  LA ESTELA DEL ARMA AL BALANCEARLA (el Rompecorazas en el mapa, 23/09/2026). El golpe va derecho al
#  enemigo, asi que lo que se ve no esta en el suelo: es el ARMA, que deja detras una estela dentada
#  mientras baja (la referencia del usuario: una figura con un tajo de energia blanco, liso por fuera
#  y con dientes por dentro).
#
#  EL GIRO ES DE VERDAD: el martillo baja por un plano vertical que contiene la direccion al enemigo,
#  de arriba-atras a abajo-delante, y ese plano se PROYECTA a la camara de 45 grados (el suelo tal
#  cual, la altura a K). Asi vale para las ocho direcciones sin dibujar ocho: mirando al este es un arco
#  de lado; mirando al sur, baja por delante del cuerpo. Un pelin de ladeo evita que, de frente, el
#  arco se aplaste en una raya.
#
#  Acaba JUSTO en el golpe: arranca T_BALANCEO antes (la espera que le pasan menos eso), y despues de
#  golpear se apaga. Coordenadas de MUNDO, por encima de los cuerpos (el arma va por delante).
# ============================================================
extends Node2D
class_name EstelaGolpe

const T_BALANCEO := 0.22     # lo que tarda en bajar el martillo
const T_APAGAR := 0.35       # lo que dura la estela despues del golpe
const RADIO := 30.0          # del hombro a la cabeza del martillo, en unidades de mundo
const HOMBRO := 20.0         # alto del hombro sobre los pies, en px de pantalla
const DESDE := deg_to_rad(120.0)   # arriba y atras
const HASTA := deg_to_rad(-40.0)   # abajo y delante: el golpe
const LADEO := 0.3           # de lado; de frente o de espaldas sube hasta LADEO_FRENTE
const LADEO_FRENTE := 0.75
const DIENTES := 7
const K_ALTO := SueloRoto.K_ALTO
const BLANCO := Color(0.96, 0.97, 1.0)
const GRIS := Color(0.55, 0.57, 0.63)

var _pies: Vector2 = Vector2.ZERO
var _dir: Vector2 = Vector2.RIGHT
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _dientes: PackedFloat32Array = PackedFloat32Array()


# 'f' = un CONO con origen en los pies del que golpea y dir hacia el enemigo (ver fijar_suelo).
# 'espera' = segundos hasta el golpe.
static func lanzar(padre: Node, f: CombatFormas.Forma, semilla: int, espera: float) -> EstelaGolpe:
	if padre == null or f == null:
		return null
	var e := EstelaGolpe.new()
	e._pies = f.origen
	e._dir = f.dir.normalized() if f.dir.length_squared() > 0.0001 else Vector2.RIGHT
	e._rng.seed = semilla
	e._t = -maxf(espera - T_BALANCEO, 0.0)
	e.z_as_relative = false
	e.z_index = Game.Z_PERSONAJES + 80
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	padre.add_child(e)
	return e


func _ready() -> void:
	for i in DIENTES + 1:
		_dientes.append(_rng.randf_range(0.25, 1.0))


func _process(delta: float) -> void:
	_t += delta
	if _t >= T_BALANCEO + T_APAGAR:
		queue_free()
		return
	queue_redraw()


# Donde esta la cabeza del martillo a un angulo 'th' del giro, a una fraccion 'r' del radio.
func _punto(th: float, r: float) -> Vector2:
	var lado: Vector2 = _dir.orthogonal()
	var ladeo: float = lerpf(LADEO, LADEO_FRENTE, absf(_dir.y))
	var suelo: Vector2 = _dir * cos(th) + lado * (ladeo * sin(th))
	var hombro: Vector2 = _pies + Vector2(0.0, -HOMBRO)
	return hombro + suelo * RADIO * r + Vector2(0.0, -sin(th) * RADIO * r * K_ALTO)


func _draw() -> void:
	if _t < 0.0:
		return
	var baja: float = clampf(_t / T_BALANCEO, 0.0, 1.0)
	baja = baja * baja   # acelerando: el martillo cae con todo su peso
	var cabeza: float = lerpf(DESDE, HASTA, baja)
	var apaga: float = clampf((_t - T_BALANCEO) / T_APAGAR, 0.0, 1.0)
	# La COLA va detras de la cabeza; al golpear, se recoge hacia el golpe mientras se apaga.
	var cola: float = lerpf(DESDE, HASTA, apaga * 0.85)
	var a: float = 1.0 - apaga
	if a <= 0.0 or absf(cabeza - cola) < 0.01:
		return
	var n: int = 28
	var fuera := PackedVector2Array()
	var dentro := PackedVector2Array()
	for i in n + 1:
		var s: float = float(i) / float(n)      # 0 = cola, 1 = cabeza
		var th: float = lerpf(cola, cabeza, s)
		fuera.append(_punto(th, 1.0))
		# Los DIENTES: el borde de dentro sube y baja; hacia la cola la estela adelgaza.
		var k: float = s * float(DIENTES)
		var diente: float = _dientes[mini(int(k), DIENTES)]
		var sierra: float = (k - floorf(k)) * diente
		var hondo: float = lerpf(0.9, 0.5, s) - 0.42 * sierra * s
		dentro.append(_punto(th, hondo))
	for i in n:
		var s2: float = float(i) / float(n)
		var quad := PackedVector2Array([fuera[i], fuera[i + 1], dentro[i + 1], dentro[i]])
		# Blanco hacia fuera y hacia la cabeza, gris y transparente hacia la cola.
		var col: Color = GRIS.lerp(BLANCO, s2)
		draw_colored_polygon(quad, Color(col, (0.25 + 0.65 * s2) * a))
	draw_polyline(fuera, Color(BLANCO, 0.95 * a), 2.2)
	# El DESTELLO del golpe, en la cabeza, justo al llegar.
	if _t >= T_BALANCEO * 0.9 and apaga < 0.6:
		var p: Vector2 = _punto(HASTA, 1.0)
		var f: float = 1.0 - apaga / 0.6
		for j in 6:
			var ang: float = TAU * float(j) / 6.0 + 0.3
			draw_line(p, p + Vector2(cos(ang), sin(ang) * K_ALTO) * (6.0 + 8.0 * (1.0 - f)), Color(BLANCO, 0.9 * f), 1.6)
		draw_circle(p, 3.0 * f, Color(BLANCO, 0.9 * f))
