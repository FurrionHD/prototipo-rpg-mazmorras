# ============================================================
#  rata_aire.gd  (class_name RataAire)
#  LOS EFECTOS DE LOS MUTANTES DE LA RATA en el mapa (30/10/2026: la sombria, la drusa y la de cuarzo ahumado; memoria rata-mutante), EN PIXEL ART
#  (04/11/2026, memoria efectos-a-pixel-art): sus hojas salen de tools/sprites_sdf/rata_efectos_horno.py; aqui, que hoja sale y donde.
#  El cristal de la de cuarzo es AHUMADO: lo decide el color de quien ataca (oscuro = ahumado).
#  POR EL SUELO (SueloRoto.Tipo.RATA_*, en el orden de Modo): ESTELA_SOMBRA (jirones por donde pasa el salto y la mancha donde cae),
#    ANILLO_ESQUIRLAS, SURCO_CRISTAL, DESTELLO y TRAICION (remolino donde estaba y otro a la espalda de su presa).
#  SOBRE EL CUERPO (CombatFX.Estilo.RATA_*: la mandibula la pone BestiaAire y esto va encima): JIRONES, ESQUIRLAS, CORTE y VELO.
#  Y EL SIGILO (onda_sigilo): cada pocos segundos el aire ONDULA donde esta y se le insinua la silueta, a franjas de celdas y a trama.
# ============================================================
extends Node2D
class_name RataAire

# Los del suelo, en el orden de SueloRoto.Tipo.RATA_*: no reordenar.
enum Modo { ESTELA_SOMBRA, ANILLO_ESQUIRLAS, SURCO_CRISTAL, DESTELLO, TRAICION,
	JIRONES, ESQUIRLAS, CORTE, VELO, ONDA }

const Z_ENCIMA := Game.Z_ENCIMA_PERSONAJES + 80
const SILUETA := Color(0.72, 0.70, 0.82)   # el velo de la onda (ver _SHADER_ONDA)
const CELDA: float = SpriteLienzo.UNIDADES_POR_CELDA

const T_SALTO := 0.22          # lo que tarda en caer (CombatTactico.T_SALTO_BICHO)
const T_ANILLO := 0.26         # lo que tarda el anillo de esquirlas en llegar al borde
const T_PASA := 0.2            # lo que tarda la Embestida en recorrer su linea (BestiaAire.T_ESTELA)
const T_FOGONAZO := 0.16       # lo que tarda el Destello en llegar al borde de su abanico
const T_ONDA := 1.1            # lo que dura la ondulacion del sigilo
const ONDA_FRANJAS := 16
# (10/11, el jefe: "se le ve la silueta en gris completamente; que se vea menos y mas sutil") 0,3 como mucho, en 4 escalones
# de transparencia de verdad (sin trama), y solo ALGUNAS franjas a la vez (un temblor del aire, no su silueta entera).
const ONDA_ALFA := 1.0   # (ahora es la FUERZA del temblor: el shader no pone color)
const ESPALDA := 14.0          # (la Traicion aparece un poco mas alla de su presa, en la direccion del salto)
const JIRONES_SALTO := 5
const ALTO_SALTO := 10.0

var _t: float = 0.0
var _ritmo: float = 1.0
var _tex: Texture2D = null
var _xf: Transform2D = Transform2D.IDENTITY
var _rect: Rect2 = Rect2()
var _al_reves: bool = false
var _fase: float = 0.0


static func area(padre: Node, f: CombatFormas.Forma, m: int, semilla: int, espera: float) -> Node2D:
	if padre == null or f == null:
		return null
	var r: float = maxf(BarridoAire.ritmo, 0.05)
	var ahumado: bool = es_ahumado(SlimeAire.color_de_semilla(semilla))
	var d: Vector2 = f.dir.normalized() if f.dir.length_squared() > 0.0001 else Vector2.RIGHT
	var dir: int = SpriteLienzo.dir8(d)
	match m:
		Modo.ESTELA_SOMBRA:
			# DE DONDE SALTA: lo lejos que esta quien lo lanza va en el 'ancho' del circulo (CombatTactico.desde_quien_lanza).
			var de: Vector2 = f.centro - d * f.ancho if f.ancho > 1.0 else f.centro
			for i in JIRONES_SALTO:
				var u: float = (float(i) + 0.5) / float(JIRONES_SALTO)
				var pos: Vector2 = de.lerp(f.centro, u) - Vector2(0.0, sin(PI * u) * ALTO_SALTO)
				var ji: EfectoPixel = EfectoPixel.lanzar(padre, "rata", "jiron", pos, dir + (4 if i % 2 == 0 else 0), null, espera, -1.0, r)
				if ji != null:
					ji.retardo = u * T_SALTO
			return EfectoPixel.lanzar(padre, "rata", "mancha", f.centro, 0, null, espera + T_SALTO, -1.0, r)
		Modo.ANILLO_ESQUIRLAS:
			return EfectoPixel.lanzar(padre, "rata", "anillo_a" if ahumado else "anillo_c", f.centro, 0, null, espera + T_SALTO, -1.0, r)
		Modo.SURCO_CRISTAL:
			# (la del jabali mide otro largo y lleva su hoja; la de cuarzo ahumado, su color)
			if f.largo < 65.0:
				return EfectoPixel.lanzar(padre, "jabali", "surco_60" if f.largo > 55.0 else "surco_50", f.origen, dir, null, espera, -1.0, r)
			return EfectoPixel.lanzar(padre, "rata", "surco_a" if ahumado else "surco_c", f.origen, dir, null, espera, -1.0, r)
		Modo.DESTELLO:
			return EfectoPixel.lanzar(padre, "rata", "destello", f.origen, dir, null, espera, -1.0, r)
		Modo.TRAICION:
			var de_t: Vector2 = f.centro - d * f.ancho if f.ancho > 1.0 else f.centro
			EfectoPixel.lanzar(padre, "rata", "remolino", de_t, 0, null, espera, -1.0, r)
			return EfectoPixel.lanzar(padre, "rata", "remolino", f.centro + d * ESPALDA, 0, null, espera + T_SALTO * 0.6, -1.0, r)
	return null


# 'desde' = de donde viene (quien muerde), 'caja' = el cuerpo que lo recibe, 'color' = el de quien ataca (oscuro = cristal ahumado).
static func sobre_cuerpo(padre: Node, m: int, desde: Vector2, caja: Rect2, color: Color, _semilla: int, espera: float, ritmo: float) -> Node2D:
	if padre == null:
		return null
	var nombre: String = ""
	var ahumado: bool = es_ahumado(color)
	match m:
		Modo.JIRONES: nombre = "jirones"
		Modo.ESQUIRLAS: nombre = "esq_a" if ahumado else "esq_c"
		Modo.CORTE: nombre = "corte_a" if ahumado else "corte_c"
		Modo.VELO: nombre = "velo"
	if nombre == "":
		return null
	var hacia: Vector2 = caja.get_center() - desde
	return EfectoPixel.lanzar(padre, "rata", nombre, Vector2(caja.get_center().x, caja.end.y), SpriteLienzo.dir8(hacia) if hacia.length_squared() > 1.0 else 0,
		null, maxf(espera, 0.0), -1.0, maxf(ritmo, 0.05))


# LA ONDULACION DEL SIGILO sobre 'spr' (el sprite escondido de quien esta en las sombras): copia su fotograma de ahora
# y donde esta, y lo insinua temblando. null si no hay que dibujar.
static func onda_sigilo(padre: Node, spr: AnimatedSprite2D, semilla: int) -> RataAire:
	if padre == null or spr == null or spr.sprite_frames == null or not spr.sprite_frames.has_animation(spr.animation):
		return null
	var tex: Texture2D = spr.sprite_frames.get_frame_texture(spr.animation, spr.frame)
	if tex == null:
		return null
	var e := RataAire.new()
	e._tex = tex
	e._xf = spr.get_global_transform()
	var tam: Vector2 = tex.get_size()
	e._rect = Rect2((-tam * 0.5 if spr.centered else Vector2.ZERO) + spr.offset, tam)
	e._al_reves = spr.flip_h
	e._ritmo = maxf(BarridoAire.ritmo, 0.05)
	e._fase = float(hash(semilla) % 628) / 100.0
	e.z_as_relative = false
	e.z_index = Z_ENCIMA
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	# SOLO SU FORMA, en claro y a trama: el sprite de la sombria es casi negro y, tenido, seguia negro sobre el suelo negro.
	e.material = _mat_silueta()
	padre.add_child(e)
	return e


static var _silueta: ShaderMaterial = null

const _SHADER_ONDA := """shader_type canvas_item;
uniform vec3 velo = vec3(1.0);
uniform float fuerza = 1.0;
varying float alfa;
// (10/11, el jefe: "tiene que ser como una ondulacion del aire muy muy sutil, no una mancha gris") SIN COLOR: dentro de
// su silueta se ve LO DE DETRAS (el suelo), corrido de lado por filas hasta 3 celdas en el pico: el aire que
// tiembla sobre ella. Sobre suelo liso casi no se nota (y asi debe ser); sobre baldosas, ondula.
uniform sampler2D pantalla : hint_screen_texture, filter_nearest;
void vertex() { alfa = COLOR.a; }
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	if (t.a < 0.5 || alfa < 0.02) {
		discard;
	}
	// cuanto mide una celda de su hoja en la pantalla (para correr celdas enteras: sigue siendo pixel art)
	vec2 celda = abs(dFdx(SCREEN_UV)) / max(abs(dFdx(UV)), vec2(1e-6)) * TEXTURE_PIXEL_SIZE;
	float fila = floor(UV.y / TEXTURE_PIXEL_SIZE.y / 2.0);
	// (10/11, el jefe: "menos sutil") hasta 2 celdas, mas filas a la vez, y donde se corre el suelo brilla un poco (calor)
	// (10/11, la que eligio tras dos pruebas: "esta es la buena") hasta 3 celdas, casi todas las filas, brillo 1,14
	float onda = sin(TIME * 7.0 + fila * 1.3) * (0.75 + 0.25 * sin(TIME * 3.1 + fila * 0.7));
	float corre = round(onda * 3.0 * alfa);
	vec3 fondo = texture(pantalla, SCREEN_UV + vec2(corre * celda.x, 0.0)).rgb;
	COLOR = vec4(fondo * (corre != 0.0 ? 1.14 : 1.0), 1.0);
}
"""


static func _mat_silueta() -> ShaderMaterial:
	if _silueta == null:
		var sh := Shader.new()
		sh.code = _SHADER_ONDA
		_silueta = ShaderMaterial.new()
		_silueta.shader = sh
		_silueta.set_shader_parameter("velo", Vector3(SILUETA.r, SILUETA.g, SILUETA.b))
	return _silueta


# ¿Ese color es el de la de cuarzo ahumado? (oscuro: su cristal es ahumado; el de la drusa, cian).
static func es_ahumado(col: Color) -> bool:
	return col.get_luminance() < 0.25


static func retraso(m: int, f: CombatFormas.Forma, p: Vector2) -> float:
	if f == null:
		return 0.0
	match m:
		Modo.ESTELA_SOMBRA, Modo.TRAICION:
			return T_SALTO
		Modo.ANILLO_ESQUIRLAS:
			return T_SALTO + clampf(p.distance_to(f.centro) / maxf(f.radio, 1.0), 0.0, 1.0) * T_ANILLO
		Modo.SURCO_CRISTAL:
			return clampf((p - f.origen).dot(f.dir.normalized()) / maxf(f.largo, 1.0), 0.0, 1.0) * SueloRoto.t_embestida(f)
		Modo.DESTELLO:
			return clampf(p.distance_to(SueloRoto.origen_de(f)) / maxf(f.radio, 1.0), 0.0, 1.0) * T_FOGONAZO
	return 0.0


static func t_salir(m: int) -> float:
	match m:
		Modo.ESTELA_SOMBRA, Modo.TRAICION: return T_SALTO
		Modo.ANILLO_ESQUIRLAS: return T_SALTO + T_ANILLO
		Modo.SURCO_CRISTAL: return T_PASA   # (la de verdad, la de su linea: SueloRoto.t_embestida)
		Modo.DESTELLO: return T_FOGONAZO
	return 0.2


func _process(delta: float) -> void:
	_t += delta * _ritmo
	if _t >= T_ONDA:
		queue_free()
		return
	queue_redraw()


# A franjas, cada una corrida un numero entero de celdas: tiembla sin salirse de la rejilla.
func _draw() -> void:
	if _tex == null or _t < 0.0:
		return
	var k: float = clampf(_t / T_ONDA, 0.0, 1.0)
	var alfa: float = ONDA_ALFA * sin(PI * k)
	if alfa <= 0.02:
		return
	var tam: Vector2 = _tex.get_size()
	var alto: float = tam.y / float(ONDA_FRANJAS)
	draw_set_transform_matrix(_xf)
	for i in ONDA_FRANJAS:
		var mece: float = 0.0   # (10/11) el temblor lo hace el shader con lo de detras; la silueta no se mueve
		var src := Rect2(0.0, alto * float(i), tam.x, alto)
		var dst := Rect2(_rect.position + Vector2(mece, alto * float(i)), Vector2(tam.x, alto))
		if _al_reves:   # (el sprite va volteado: la franja, del reves)
			dst = Rect2(Vector2(-_rect.position.x - tam.x + mece, dst.position.y) + Vector2(tam.x, 0.0), Vector2(-tam.x, alto))
		draw_texture_rect_region(_tex, dst, src, Color(1.0, 1.0, 1.0, alfa))
	draw_set_transform_matrix(Transform2D.IDENTITY)
