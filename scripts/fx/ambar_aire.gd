# ============================================================
#  ambar_aire.gd  (class_name AmbarAire)
#  LOS BICHOS DE LA COSTRA DEL TOCON AMBARINO en el mapa (03/11/2026), EN PIXEL ART (04/11/2026, memoria efectos-a-pixel-art): sus hojas salen
#  de tools/sprites_sdf/trent_efectos_horno.py.
#    BOLA      la Bola de caca del pelotero: rueda por su linea dejando rastro y revienta.
#    PRINGUE   (se queda) pegotes en el cuerpo que gotean y dos moscas.     PICOR  (se queda) las ronchas que laten.
#    REVIENTA  la garrapata revienta: ambar y veneno salpicando.
# ============================================================
extends RefCounted
class_name AmbarAire

enum Modo { BOLA, PRINGUE, PICOR, REVIENTA }

const T_RUEDA := 0.6        # lo que tarda la bola en recorrer su linea


static func _r() -> float:
	return maxf(BarridoAire.ritmo, 0.05)


static func bola(padre: Node, f: CombatFormas.Forma, _semilla: int, espera: float) -> Node:
	if padre == null or f == null:
		return null
	var e: EfectoPixel = EfectoPixel.lanzar(padre, "trent", "bola", SueloRoto.origen_de(f), SpriteLienzo.dir8(f.dir) if f.dir.length_squared() > 0.0001 else 0,
		null, espera, -1.0, _r())
	if e != null:
		e.set_meta("ambar", Modo.BOLA)
	return e


# Cuando le llega la bola a 'p' (segundos desde la patada).
static func retraso_bola(f: CombatFormas.Forma, p: Vector2) -> float:
	if f == null:
		return 0.0
	return clampf((p - f.origen).dot(f.dir.normalized()) / maxf(f.largo, 1.0), 0.0, 1.0) * T_RUEDA


# LO QUE SE QUEDA PEGADO (PRINGUE, PICOR): sobre 'caja' (su cuerpo), la sigue con seguir() y se va con secar().
static func pegado(padre: Node, m: int, caja: Rect2, _semilla: int) -> PiezaPixel:
	var p: PiezaPixel = PiezaPixel.crear(padre, "trent", "", "pringue" if m == Modo.PRINGUE else "picor", "", Vector2.ZERO)
	if p != null:
		p.seguir(caja)
		p.set_meta("ambar", m)
	return p


static func revienta(padre: Node, centro: Vector2, _rr: float, _semilla: int, espera: float = 0.0) -> Node:
	var e: EfectoPixel = EfectoPixel.lanzar(padre, "trent", "revienta", centro, 0, null, espera, -1.0, _r())
	if e != null:
		e.set_meta("ambar", Modo.REVIENTA)
	return e
