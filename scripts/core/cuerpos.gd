# ============================================================
#  cuerpos.gd  (class_name Cuerpos)
#  EL HUECO ENTRE DOS CUERPOS, en UN solo sitio.
#
#  Es la cuenta que decide si un golpe conecta, si un bicho te ha alcanzado y si el boton de atacar
#  se enciende. Y NO HAY NINGUN NODO DETRAS: en todo el proyecto no existe un solo Area2D -- el
#  contacto se resuelve con un rectangulo calculado desde el centro de cada uno. Eso no es un atajo,
#  es lo que permite que el mismo numero valga para el jugador, para un compañero, para el otro
#  humano en multijugador y para cualquier bicho, sin montar formas de fisica que ademas habria que
#  mantener sincronizadas con el dibujo.
#
#  POR QUE ESTA AQUI Y NO EN CADA UNO. Vivia duplicada: Enemy.hueco_hasta por un lado y
#  Player._hueco_hasta por otro, cada una con su version de la formula -- y ya se habian separado,
#  porque una usaba una constante con nombre y la otra un 32 escrito a mano. Con las cajas centradas
#  la duplicacion colaba, porque la cuenta era un simple |distancia| - suma. Desde que el jugador
#  tiene la caja DESPLAZADA (su cuerpo dibujado cae casi entero por encima del nodo, ver
#  PoseJugador.CAJA_CUERPO) la cuenta es un AABB contra AABB de verdad, y dos copias de eso se
#  separan seguro.
#
#  NOMBRE NEUTRO A PROPOSITO: lo usan el jugador y el enemigo, asi que no puede vivir en
#  PoseJugador -- ese es el esqueleto del personaje, y un slime no tiene por que depender de el.
# ============================================================

extends RefCounted
class_name Cuerpos

# El medio cuerpo que se le supone a quien no sepa decir cuanto ocupa: el cuerpo base de 32x32 que
# tienen el bicho normal y cualquier Node2D suelto.
const MEDIO_BASE := 16.0


# La caja de un nodo, YA en coordenadas de mundo.
#
# Se pregunta por 'caja_cuerpo' con has_method y no por el tipo: asi el bicho no tiene que saber si
# lo que tiene delante es el jugador, un compañero o el otro humano -- solo si sabe contestar. Quien
# no lo sepa se queda con el cuadrado base, y eso ES el comportamiento correcto para un bicho.
#
# 'radio_extra' es lo que sobresale un ELITE por encima del cuerpo base (ver Enemy). Se suma aqui y
# no en quien llama, que es donde se olvidaba: un elite del 1,6 sobresale 16 px por lado, o sea un
# cuerpo entero, y sin contarlo era intocable en diagonal.
static func caja_de(n: Node2D) -> Rect2:
	if n == null or not is_instance_valid(n):
		return Rect2()
	var r: Rect2
	if n.has_method("caja_cuerpo"):
		r = n.caja_cuerpo()
	else:
		var m: float = MEDIO_BASE
		if "radio_extra" in n:
			m += float(n.radio_extra)
		r = Rect2(-m, -m, m * 2.0, m * 2.0)
	r.position += n.global_position
	return r


# Cuanto SEPARA a los dos cuerpos: 0 = tocandose (de lado o de esquina), < 0 = solapados.
#
# SE MIDE POR EJES Y SE COGE EL MAYOR, que es lo que hace que tocarse de ESQUINA cuente igual que
# tocarse de frente. Con la distancia entre centros no: dos cuadrados de 32 que se tocan por la
# esquina tienen los centros a 45 px, mas de lo que valia attack_range (44) -- estabas pegado al
# slime y no podias pegarle.
static func hueco(a: Node2D, b: Node2D) -> float:
	if a == null or b == null or not is_instance_valid(a) or not is_instance_valid(b):
		return INF
	return hueco_entre(caja_de(a), caja_de(b))


# Lo mismo con las cajas ya resueltas, por si quien llama ya las tiene.
static func hueco_entre(ra: Rect2, rb: Rect2) -> float:
	var gx: float = maxf(rb.position.x - ra.end.x, ra.position.x - rb.end.x)
	var gy: float = maxf(rb.position.y - ra.end.y, ra.position.y - rb.end.y)
	return maxf(gx, gy)
