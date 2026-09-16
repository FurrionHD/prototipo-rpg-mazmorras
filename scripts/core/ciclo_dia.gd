# ============================================================
#  ciclo_dia.gd  (class_name CicloDia)
#  LA HORA DEL PUEBLO. Estatico y sin nodos, como Lampara: solo dice en que momento del dia estamos
#  y de que color es la luz. Quien lo pinta es LuzPueblo (scripts/town/luz_pueblo.gd).
#
#  DECIDIDO CON EL USUARIO (16/09/2026):
#    - Solo el PUEBLO. La mazmorra ya esta a oscuras siempre y no mira la hora.
#    - Un dia entero son 40 minutos reales: 28 de dia y 12 de noche, contando en el dia el
#      amanecer y el atardecer (2 minutos cada uno).
#    - Solo VISUAL: ni tiendas cerradas ni peces de noche (eso ultimo, a futuro).
#    - Noche AZULADA en la que se ve todo; lo calido lo ponen las antorchas y las ventanas.
#
#  POR QUE EL RELOJ DE PARED. La hora sale de la hora real del ordenador (con el desfase de pruebas
#  de Encargos), no de un contador que avance jugando: asi dos jugadores en el mismo pueblo ven el
#  mismo cielo sin mandarse nada, cerrar el juego no para el dia y un menu abierto tampoco.
#  En sesion el anfitrion manda su desfase (ver `desfase`) por si el reloj de algun PC va mal.
# ============================================================
extends RefCounted
class_name CicloDia

# El ciclo, en segundos reales. Los tramos van en ese orden empezando en 0.
const CICLO := 2400.0
const AMANECER := 120.0      # 0 .. 120      noche -> dia
const DIA := 1440.0          # 120 .. 1560   pleno dia
const ATARDECER := 120.0     # 1560 .. 1680  dia -> noche
# y el resto, 1680 .. 2400 (720 s = 12 min), noche cerrada.

const T_DIA := AMANECER
const T_ATARDECER := AMANECER + DIA
const T_NOCHE := AMANECER + DIA + ATARDECER

# Los colores por los que pasa la luz. Multiplican la pantalla: blanco = sin tocar.
const COLOR_DIA := Color(1.0, 1.0, 1.0)
const COLOR_ATARDECER := Color(1.0, 0.70, 0.52)     # naranja
const COLOR_AMANECER := Color(1.0, 0.78, 0.80)      # rosa
const COLOR_NOCHE := Color(0.34, 0.40, 0.66)        # azul oscuro, pero se ve todo

# Segundos que el anfitrion le lleva a este PC (lo pone la red). 0 sin sesion.
static var desfase: float = 0.0

# Para visores y pruebas: fija el momento del ciclo en SEGUNDOS (0..CICLO). -1 = la hora de verdad.
static var hora_forzada: float = -1.0


# Para el panel de debug: el ciclo entero en CICLO / ACELERACION segundos (40 s), sin tocar el reloj.
const ACELERACION := 60.0
static var acelerado: bool = false
# Para el panel de debug: SALTAR a otra hora y que siga corriendo desde ahi (no congela). Solo en
# este PC y hasta cerrar el juego.
static var salto_debug: float = 0.0


# Segundo dentro del ciclo, 0..CICLO.
static func segundo() -> float:
	if hora_forzada >= 0.0:
		return fposmod(hora_forzada, CICLO)
	if acelerado:
		return fposmod(float(Time.get_ticks_msec()) / 1000.0 * ACELERACION + salto_debug, CICLO)
	# Con decimales (y no Encargos.ahora(), que es entero): si no, el color del atardecer iria a saltos
	# de un segundo, y eso con un fundido de dos minutos se ve.
	var t: float = Time.get_unix_time_from_system() + float(Encargos.desfase_prueba) + desfase + salto_debug
	return fposmod(t, CICLO)


# Debug: pon el reloj en el segundo 's' del ciclo y deja que siga corriendo.
static func saltar_a(s: float) -> void:
	var congelada: bool = hora_forzada >= 0.0
	hora_forzada = -1.0
	salto_debug = fposmod(salto_debug + s - segundo(), CICLO)
	if congelada:
		hora_forzada = s


# 0 = pleno dia, 1 = noche cerrada, con las rampas del amanecer y el atardecer.
static func noche(s: float = -1.0) -> float:
	if s < 0.0:
		s = segundo()
	if s < T_DIA:
		return 1.0 - _suave(s / AMANECER)
	if s < T_ATARDECER:
		return 0.0
	if s < T_NOCHE:
		return _suave((s - T_ATARDECER) / ATARDECER)
	return 1.0


# El color por el que se multiplica el pueblo.
static func tinte(s: float = -1.0) -> Color:
	if s < 0.0:
		s = segundo()
	if s < T_DIA:
		return _pasar(COLOR_NOCHE, COLOR_AMANECER, COLOR_DIA, s / AMANECER)
	if s < T_ATARDECER:
		return COLOR_DIA
	if s < T_NOCHE:
		return _pasar(COLOR_DIA, COLOR_ATARDECER, COLOR_NOCHE, (s - T_ATARDECER) / ATARDECER)
	return COLOR_NOCHE


# Cuanto estan encendidas las luces (antorchas, ventanas), 0..1. Se encienden en la segunda mitad
# del atardecer y se apagan en la primera del amanecer. 'retraso' (0..1) adelanta o atrasa cada luz
# un poco dentro de esa mitad, para que no se enciendan todas en el mismo fotograma.
static func luces(retraso: float = 0.0, s: float = -1.0) -> float:
	if s < 0.0:
		s = segundo()
	var margen: float = 0.35 * clampf(retraso, 0.0, 1.0)
	if s < T_DIA:
		var u: float = s / AMANECER            # 0 .. 1
		return 1.0 - clampf((u - margen) / 0.15, 0.0, 1.0)
	if s < T_ATARDECER:
		return 0.0
	if s < T_NOCHE:
		var u: float = (s - T_ATARDECER) / ATARDECER
		return clampf((u - 0.5 - margen) / 0.15, 0.0, 1.0)
	return 1.0


# Como se llama el momento, para el panel de debug.
static func momento(s: float = -1.0) -> String:
	if s < 0.0:
		s = segundo()
	if s < T_DIA:
		return "amanecer"
	if s < T_ATARDECER:
		return "día"
	if s < T_NOCHE:
		return "atardecer"
	return "noche"


# ¿Hay que pintar algo? De pleno dia la capa entera se esconde y no cuesta nada.
static func es_pleno_dia(s: float = -1.0) -> bool:
	if s < 0.0:
		s = segundo()
	return s >= T_DIA and s < T_ATARDECER


static func _suave(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


# De 'a' a 'c' pasando por 'b' a mitad de camino.
static func _pasar(a: Color, b: Color, c: Color, u: float) -> Color:
	u = clampf(u, 0.0, 1.0)
	if u < 0.5:
		return a.lerp(b, _suave(u * 2.0))
	return b.lerp(c, _suave((u - 0.5) * 2.0))
