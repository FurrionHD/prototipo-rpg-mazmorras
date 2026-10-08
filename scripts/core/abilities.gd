# ============================================================
#  abilities.gd
#  Habilidades de COMBATE estilo DanMachi. Es un RECURSO compartido:
#  lo usan TANTO el jugador COMO los enemigos.
#  Cada habilidad va de 0 a 999 y tiene un rango por letra:
#    0-99 = I, 100-199 = H, 200-299 = G, 300-399 = F, 400-499 = E,
#    500-599 = D, 600-699 = C, 700-799 = B, 800-899 = A, 900-999 = S
# ============================================================

extends Resource
class_name Abilities

# Las 6 habilidades basicas (las 5 de DanMachi + la Voluntad). Enteros 0-999.
@export_range(0, 999) var fuerza: int = 0      # 力  - daño fisico
@export_range(0, 999) var resistencia: int = 0 # 耐久 - defensa / aguante
@export_range(0, 999) var destreza: int = 0    # 器用 - precision / crit / minijuegos
@export_range(0, 999) var agilidad: int = 0    # 敏捷 - orden de turnos
@export_range(0, 999) var magia: int = 0       # 魔力 - daño magico
# VOLUNTAD (08/10/2026): la sexta, y la unica que no es de DanMachi. Es la DEFENSA MAGICA y la
# RESISTENCIA A EFECTOS (a todos por igual, el espejo de la eficacia de la Destreza). Antes la defensa magica colgaba de la Magia, asi que solo el
# mago se protegia de la magia. Va AL FINAL a proposito: los saves y la red leen por nombre, y una
# partida vieja simplemente no la trae (vale 0).
@export_range(0, 999) var voluntad: int = 0

# LAS SEIS, por nombre y en orden. Todo lo que recorra "las basicas" (guardado, altar, nivel, red,
# fichas) tiene que leer de AQUI: antes cada sitio llevaba su propia lista de cinco, y meter la
# Voluntad era ir a cazarlas una a una -- la que se te escapa no da error, solo se la come en silencio.
const NOMBRES := ["fuerza", "resistencia", "destreza", "agilidad", "magia", "voluntad"]
# Las que cuentan para el PODER (el denominador del reto). La Voluntad se queda FUERA a proposito
# (08/10/2026): meterla subia el poder de los enemigos un ~10 % de golpe y con el la excelia de todo
# el juego, sin que nadie lo hubiera pedido. Si algun dia entra, que sea a la vez en los dos lados
# (Game.poder_jugador_* y combat._poder_enemigo), que leen esta lista.
const NOMBRES_PODER := ["fuerza", "resistencia", "destreza", "agilidad", "magia"]


# Devuelve la LETRA de rango (I..S) para un valor concreto.
# Es "static": se puede llamar sin tener un objeto, asi:  Abilities.rank_letter(750) -> "B"
static func rank_letter(value: int) -> String:
	var letters := ["I", "H", "G", "F", "E", "D", "C", "B", "A", "S"]
	# clampi mantiene el valor entre 0 y 999; /100 da el indice 0..9.
	var index := clampi(value, 0, 999) / 100
	return letters[index]


# Atajos para leer el rango de cada habilidad de ESTE objeto.
func rango_fuerza() -> String: return rank_letter(fuerza)
func rango_resistencia() -> String: return rank_letter(resistencia)
func rango_destreza() -> String: return rank_letter(destreza)
func rango_agilidad() -> String: return rank_letter(agilidad)
func rango_magia() -> String: return rank_letter(magia)
func rango_voluntad() -> String: return rank_letter(voluntad)


# Texto resumen para depurar, ej: "F:120(H) R:80(I) D:200(G) A:150(H) M:0(I)"
func resumen() -> String:
	return "F:%d(%s) R:%d(%s) D:%d(%s) A:%d(%s) M:%d(%s) V:%d(%s)" % [
		fuerza, rank_letter(fuerza),
		resistencia, rank_letter(resistencia),
		destreza, rank_letter(destreza),
		agilidad, rank_letter(agilidad),
		magia, rank_letter(magia),
		voluntad, rank_letter(voluntad),
	]
