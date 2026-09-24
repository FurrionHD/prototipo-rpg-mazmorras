# ============================================================
#  imbue_visual.gd  (class_name ImbueVisual)
#  COMO SE VE UNA IMBUICION PUESTA: un solo numero que dice que pintar y donde.
#
#  Lo pidio el usuario el 24/09: "el veneno no sabes si lo tienes". Habia un rastro de cuadraditos
#  que solo salia con ELEMENTO -- y el Filo emponzoñado no tiene elemento, solo estado --, y ademas
#  era igual para un Filo que para un Manto. Ahora:
#    MANTO (imbuicion de cuerpo)  un AURA del color del elemento alrededor del personaje entero.
#    FILO  (imbuicion de arma)    el efecto encima del ARMA: el veneno gotea, el fuego arde...
#  Lo pinta MunecoJugador (poner_imbue) con shaders/aura_imbue.gdshader.
#
#  EL CODIGO es un entero porque viaja por red en el canal de siempre (Net.jugadores.anunciar_imbue,
#  un PackedInt32Array con uno por personaje) sin cambiar la llamada. Los bits BAJOS siguen siendo el
#  ELEMENTO, como antes: un cliente viejo pinta bien los Filos elementales.
#    bits 0-2  elemento (Elementos.Elemento; 0 = ninguno)
#    bit  3    de CUERPO (Manto)
#    bits 4+   estado + 1 cuando NO hay elemento (el Filo emponzoñado); 0 = ninguno
#  0 = nada puesto.
# ============================================================
extends RefCounted
class_name ImbueVisual

const BIT_CUERPO := 8
const DESDE_ESTADO := 16

# Que suelta el elemento. Lo lee el shader ('modo'): el fuego LLAMAS, el agua GOTAS y un reflejo, el
# rayo RAYITOS en zigzag, la luz DESTELLOS de estrella, la oscuridad HUMO y el veneno gotas y burbujas.
enum Modo { LLAMA, GOTA, CHISPA, ESTRELLA, HUMO, VENENO }

# LA RAMPA de cada uno: sombra, base, luz y nucleo. La hoja de un Filo se repinta con las tres
# primeras (sus tres tonos de metal) y el nucleo es lo mas encendido (la base de la llama, la chispa).
# Parten de Elementos.COLOR / el color del estado Veneno, estirados a cuatro escalones.
const RAMPAS := {
	Elementos.Elemento.FUEGO: [Color(0.55, 0.12, 0.05), Color(0.95, 0.38, 0.08), Color(1.0, 0.70, 0.20), Color(1.0, 0.95, 0.65)],
	Elementos.Elemento.AGUA: [Color(0.10, 0.25, 0.60), Color(0.30, 0.60, 0.95), Color(0.65, 0.88, 1.0), Color(0.95, 1.0, 1.0)],
	Elementos.Elemento.RAYO: [Color(0.55, 0.45, 0.05), Color(0.98, 0.85, 0.20), Color(1.0, 0.97, 0.55), Color(1.0, 1.0, 0.95)],
	Elementos.Elemento.LUZ: [Color(0.70, 0.60, 0.30), Color(0.98, 0.92, 0.65), Color(1.0, 0.98, 0.85), Color(1.0, 1.0, 1.0)],
	Elementos.Elemento.OSCURIDAD: [Color(0.12, 0.04, 0.18), Color(0.32, 0.14, 0.45), Color(0.55, 0.30, 0.72), Color(0.85, 0.60, 1.0)],
}
const RAMPA_VENENO := [Color(0.12, 0.30, 0.05), Color(0.35, 0.72, 0.12), Color(0.62, 0.95, 0.30), Color(0.85, 1.0, 0.60)]


static func codigo(elem: int, estado: int, cuerpo: bool, usos: int) -> int:
	if usos <= 0:
		return 0
	var tiene_elem: bool = Elementos.tiene_color(elem)
	if not tiene_elem and estado < 0:
		return 0
	var c: int = elem if tiene_elem else 0
	if cuerpo:
		c |= BIT_CUERPO
	if not tiene_elem:
		c += (estado + 1) * DESDE_ESTADO
	return c


# El de una FICHA (fuera de pelea, o de un personaje que no esta peleando).
static func de_ficha(pj: PersonajeData) -> int:
	if pj == null or pj.imbue.is_empty():
		return 0
	var im: Dictionary = pj.imbue
	return codigo(int(im.get("elem", 0)), int(im.get("estado", -1)), bool(im.get("cuerpo", false)),
		int(im.get("usos", 0)))


# El de un COMBATIENTE (en pelea la imbuicion vive ahi y se gasta golpe a golpe; la ficha solo se pone
# al dia al cerrar). Vale tambien en el espejo: su maniqui trae los campos (combat_espejo "imbue").
static func de_combatiente(c: Combatant) -> int:
	if c == null:
		return 0
	return codigo(c.imbue_elemento, c.imbue_estado, c.imbue_cuerpo, c.imbue_usos)


static func es_cuerpo(cod: int) -> bool:
	return cod != 0 and (cod & BIT_CUERPO) != 0


static func elemento(cod: int) -> int:
	return cod & 7


# -1 = no lleva estado (es elemental).
static func estado(cod: int) -> int:
	return (cod / DESDE_ESTADO) - 1


static func color(cod: int) -> Color:
	var e: int = elemento(cod)
	if Elementos.tiene_color(e):
		return Elementos.color(e)
	var st: int = estado(cod)
	if st >= 0:
		return StatusEffects.def(st).get("color", Color.WHITE)
	return Color.WHITE


static func modo(cod: int) -> int:
	match elemento(cod):
		Elementos.Elemento.FUEGO:
			return Modo.LLAMA
		Elementos.Elemento.AGUA:
			return Modo.GOTA
		Elementos.Elemento.RAYO:
			return Modo.CHISPA
		Elementos.Elemento.LUZ:
			return Modo.ESTRELLA
		Elementos.Elemento.OSCURIDAD:
			return Modo.HUMO
	return Modo.VENENO


# [sombra, base, luz, nucleo]. Un estado que no sea el veneno (si algun dia hay otro Filo de estado)
# sale de su color, aclarado y oscurecido.
static func rampa(cod: int) -> Array:
	var e: int = elemento(cod)
	if RAMPAS.has(e):
		return RAMPAS[e]
	if estado(cod) == StatusEffects.Id.VENENO:
		return RAMPA_VENENO
	var c: Color = color(cod)
	return [c.darkened(0.6), c, c.lightened(0.35), c.lightened(0.7)]
