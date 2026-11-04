# ============================================================
#  jabali_aire.gd  (class_name JabaliAire)
#  LOS EFECTOS DE LOS MUTANTES DEL JABALI en el mapa (31/10/2026: el Colmillo de cristal y el Jabali ancestral; memoria jabali-mutante), EN PIXEL ART
#  (04/11/2026, memoria efectos-a-pixel-art): sus hojas salen de tools/sprites_sdf/jabali_efectos_horno.py; aqui, que hoja sale y donde.
#    ESTALLIDO  al acabar la Cornada de cristal se le PARTEN los colmillos: lluvia de esquirlas cian.
#    ESPORAS    al recibir un golpe cuerpo a cuerpo sus setas sueltan una bocanada ocre-verdosa, con motitas claras.
#    REFLEJO    sus drusas le devuelven la magia que le entra por delante: destello en el morro y una bola cian que vuelve.
#    QUEMA      le queman el musgo: EL FUEGO LO TRAE SU SPRITE ('quemandose'); aqui solo el HUMO que sale de donde arde.
# ============================================================
extends RefCounted
class_name JabaliAire

enum Modo { ESTALLIDO, ESPORAS, REFLEJO, QUEMA }

const T_DESTELLO := 0.18
const T_VUELO := 0.32       # lo que tarda la bola del reflejo en llegar
const T_LLAMARADA := 1.4    # lo que tarda el fuego en recorrer el lomo (= su animacion 'quemandose': 14 a 10)
const ALTO_BOLA := 4.0


static func _ritmo() -> float:
	return maxf(BarridoAire.ritmo, 0.05)


static func _marcado(e: EfectoPixel, m: int) -> EfectoPixel:
	if e != null:
		e.set_meta("jabali", m)
	return e


# ESTALLIDO: 'morro' = donde estan los colmillos.
static func estallido(padre: Node, morro: Vector2, _dir: Vector2, _suelo_y: float, _semilla: int) -> EfectoPixel:
	return _marcado(EfectoPixel.lanzar(padre, "jabali", "estallido", morro, 0, null, 0.0, -1.0, _ritmo()), Modo.ESTALLIDO)


# ESPORAS: en 'centro' (sus pies).
static func esporas(padre: Node, centro: Vector2, _r: float, _semilla: int, espera: float = 0.0) -> EfectoPixel:
	return _marcado(EfectoPixel.lanzar(padre, "jabali", "esporas", centro, 0, null, espera, -1.0, _ritmo()), Modo.ESPORAS)


# REFLEJO: de 'morro' (las drusas) a 'hasta' (quien lanzo el hechizo).
static func reflejo(padre: Node, morro: Vector2, hasta: Vector2, _semilla: int, espera: float = 0.0) -> EfectoPixel:
	EfectoPixel.lanzar(padre, "jabali", "reflejo_sale", morro, 0, null, espera, -1.0, _ritmo())
	var e: EfectoPixel = EfectoPixel.lanzar(padre, "jabali", "reflejo_llega", hasta, 0, null, espera + T_DESTELLO + T_VUELO, -1.0, _ritmo())
	if e != null:
		e.poner_vuelo("jabali", "reflejo_bola", morro, hasta, ALTO_BOLA, T_VUELO)
	return _marcado(e, Modo.REFLEJO)


# QUEMA: 'centro' = el centro de su dibujo, 'dir' = hacia donde mira.
static func quema(padre: Node, centro: Vector2, dir: Vector2, _semilla: int) -> EfectoPixel:
	return _marcado(EfectoPixel.lanzar(padre, "jabali", "quema", centro, SpriteLienzo.dir8(dir) if dir.length_squared() > 0.0001 else 0, null, 0.0, -1.0, _ritmo()), Modo.QUEMA)
