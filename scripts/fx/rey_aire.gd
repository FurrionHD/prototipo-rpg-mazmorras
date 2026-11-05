# ============================================================
#  rey_aire.gd  (class_name ReyAire)
#  LOS EFECTOS DE LOS MUTANTES DEL REY SLIME en el mapa (07/10/2026: el Rey tirano y el Rey destronado), EN PIXEL ART (04/11/2026, memoria
#  efectos-a-pixel-art): aqui solo se decide que hoja sale y donde. Las hojas salen de tools/sprites_sdf/rey_slime_efectos_horno.py.
#  POR EL SUELO (SueloRoto.Tipo.REY_*): ESQUIRLAS de la corona, en abanico.
#  LO QUE SE QUEDA (piezas: CombatTactico.poner_piezas, charco_estilo 9 y 10; 'queda' / secar como los charcos): CLAVADA, que vuela desde su corona
#  (f.origen) y al pisarla se parte en motas; PEDAZO de su gel, de su color, que cae, rebota y tiembla (volver_a: se le vuelve a juntar).
#  SOBRE EL CUERPO (CombatFX.Estilo.REY_*, ver sobre_cuerpo): DECRETO (la coronita sobre el senalado) y TRIBUTO (el cristal del caido vuela al rey).
# ============================================================
extends RefCounted
class_name ReyAire

enum Modo { ESQUIRLAS, CLAVADA, PEDAZO, DECRETO, TRIBUTO }

const T_VUELO := 0.2
const T_ESPERA_CLAVA := 0.5     # (sale con el respingo de su animacion: CombatFX.IMPACTO_ANIM_MAPA 'esquirlas')
const T_CLAVA := 0.26
const ALTO_CLAVA := 30.0
const T_ESPERA_PEDAZO := 0.25
const T_SUBE := 0.18
const T_ARCO := 0.42
const ALTO_TRIBUTO := 40.0


static func area(padre: Node, f: CombatFormas.Forma, _m: int, _semilla: int, espera: float) -> Node2D:
	if padre == null or f == null:
		return null
	var dir: int = SpriteLienzo.dir8(f.dir) if f.dir.length_squared() > 0.0001 else 0
	return EfectoPixel.lanzar(padre, "slime", "esq_corona", f.origen, dir, null, espera, -1.0, maxf(BarridoAire.ritmo, 0.05))


# LAS PIEZAS QUE SE QUEDAN (las crea CombatTactico._charco_visible): la esquirla clavada y el pedazo de gel.
static func pieza(padre: Node, f, m: int, col: Color, _semilla: int) -> PiezaPixel:
	if padre == null or f == null:
		return null
	var ritmo: float = maxf(BarridoAire.ritmo, 0.05)
	if m == Modo.PEDAZO:
		return PiezaPixel.crear(padre, "slime", "pedazo_sale", "pedazo_dura", "pedazo_vete", f.centro, 0, SlimeAire.paleta_pixel(col), T_ESPERA_PEDAZO, ritmo)
	var p: PiezaPixel = PiezaPixel.crear(padre, "slime", "clavada_sale", "clavada_dura", "clavada_vete", f.centro, 0, PackedColorArray(), T_ESPERA_CLAVA + T_CLAVA, ritmo)
	if p != null and f.origen != Vector2.ZERO:
		p.poner_vuelo("cristal_vuela", f.origen, ALTO_CLAVA, T_CLAVA)
	return p


# LOS DE SOBRE EL CUERPO (CombatFX.dibujo_en_mapa -> CombatTactico._on_dibujo_mapa). DECRETO: 'caja' = el senalado.
# TRIBUTO: 'desde' = el cuerpo del subdito caido, 'caja' = el rey.
static func sobre_cuerpo(padre: Node, m: int, desde: Rect2, caja: Rect2, _semilla: int, espera: float, ritmo: float) -> Node2D:
	if padre == null:
		return null
	var r: float = maxf(ritmo, 0.05)
	if m == Modo.DECRETO:
		return EfectoPixel.lanzar(padre, "slime", "decreto", Vector2(caja.get_center().x, caja.position.y), 0, null, espera, -1.0, r)
	var hasta: Vector2 = caja.get_center() if caja.has_area() else Vector2.ZERO
	var de: Vector2 = desde.get_center() if desde.has_area() else hasta + Vector2(-40.0, 0.0)
	EfectoPixel.lanzar(padre, "slime", "tributo_sube", de, 0, null, espera, -1.0, r)
	var llega: EfectoPixel = EfectoPixel.lanzar(padre, "slime", "tributo_llega", hasta, 0, null, espera + T_SUBE + T_ARCO, -1.0, r)
	if llega != null:
		llega.poner_vuelo("slime", "cristal_vuela", de, hasta, ALTO_TRIBUTO, T_ARCO)
	return llega


# CUANDO LE LLEGA a 'p' (en segundos desde que se lanza). El mismo numero manda el dibujo y el golpe.
static func retraso(m: int, f: CombatFormas.Forma, p: Vector2) -> float:
	if f == null:
		return 0.0
	if m == Modo.ESQUIRLAS:
		return T_VUELO * clampf(p.distance_to(f.origen) / maxf(f.radio, 1.0), 0.0, 1.0)
	return 0.0


static func t_salir(m: int) -> float:
	return T_VUELO if m == Modo.ESQUIRLAS else 0.2
