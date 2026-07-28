# ============================================================
#  cloud.gd  (autoload "Nube")
#  EL CERROJO del mundo compartido. Un mundo lo puede abrir cualquiera, pero solo UNO a la vez:
#  quien lo abre se lleva el cerrojo y el save; quien llega despues no abre nada, SE UNE al que lo
#  tiene. O sea que el cerrojo es a la vez el DIRECTORIO DE SALAS, y por eso la direccion del host
#  vive DENTRO del registro del cerrojo (se escribe al abrir, se borra al cerrar): nunca se reparte
#  la IP del que jugo ayer, y como se publica de nuevo en cada apertura, siempre es la de ahora.
#
#  ⚠ ESTO NO SUSTITUYE A HAMACHI. La partida sigue siendo ENet directo entre las dos maquinas
#  (Net.hostear / Net.unirse). Lo que desaparece es ESCRIBIR la IP, no la necesidad de que esa IP
#  sea alcanzable.
#
#  FASE 1 (esto): toda la maquina de estados contra un almacen FALSO LOCAL (user://nube_test/), sin
#  cuenta, sin Cloudflare y sin red. FASE 2: el mismo objeto pero hablando HTTP con un Worker +
#  R2; se cambia `_almacen` y nada mas, porque las cuatro operaciones y sus respuestas ya son las
#  del Worker (ver cloud_store_local.gd).
#
#  Por eso las funciones publicas son COROUTINES (`await Nube.abrir(...)`) aunque el almacen falso
#  responda al instante: el dia que detras haya un HTTPRequest, quien llama no cambia.
#
#  LAS TRES REGLAS DEL CERROJO, que es donde se falla:
#    1. ARRENDAMIENTO CON LATIDO, no candado eterno. Si solo se soltara al cerrar bien, un cuelgue
#       congelaria el mundo para siempre. Late cada SEGUNDOS_LATIDO y caduca sin latido.
#    2. TOKEN DE VALLADO. A se cuelga -> caduca -> B abre y juega -> A revive y sube, pisando a B.
#       Se evita con un contador que sube en CADA apertura: subir con un token viejo se rechaza.
#    3. SUBIR ANTES DE SOLTAR. Si la subida falla el mundo sigue siendo tuyo, y se avisa fuerte.
# ============================================================

extends Node

const _ALMACEN_LOCAL := preload("res://scripts/net/cloud_store_local.gd")

# Cada cuanto se manda el latido. Cuatro latidos caben en el arrendamiento
# (NubeAlmacenLocal.SEGUNDOS_ARRENDAMIENTO): un pico de lag no te quita el mundo.
const SEGUNDOS_LATIDO := 30.0

# EN QUE ANDO. Es el estado del CERROJO, no de la partida.
enum {
	CERRADA,          # no tengo ningun mundo abierto
	TRABAJANDO,       # hablando con el almacen (abriendo, subiendo...)
	HOST,             # tengo el cerrojo: el mundo es mio y estoy latiendo
	PENDIENTE_SUBIR,  # jugue y la subida FALLO: el cerrojo sigue mio y la partida esta sin subir
	PERDIDO,          # se me caduco el cerrojo y lo tiene otro: lo que juegue ya no se puede subir
}

signal estado_cambiado(nuevo: int)
# El cerrojo se ha ido de las manos en mitad de la partida (sin red demasiado tiempo). Quien
# escuche esto tiene que avisar al jugador FUERTE: siga jugando o no, eso ya no se va a subir.
signal cerrojo_perdido(motivo: String)
# La subida fallo al cerrar. El mundo sigue reservado; se puede reintentar.
signal subida_pendiente(mensaje: String)

var estado: int = CERRADA

# El mundo que tengo entre manos y con que llave.
var mundo_id: String = ""
var _contrasena: String = ""
# El TOKEN DE VALLADO de esta apertura. Es lo unico que autoriza a latir y a subir.
var _token: int = 0

# El almacen. En Fase 2 esto pasa a ser el cliente HTTP del Worker y ya esta.
# Publico a proposito: las pruebas necesitan compartirlo y moverle el reloj.
var almacen: NubeAlmacenLocal = null

# Se puede apagar para que las pruebas manden el latido a mano.
var latido_automatico := true
var _desde_ultimo_latido := 0.0

# Lo ultimo que dijo el almacen sobre un mundo ocupado (a quien unirse). Lo lee la UI.
var union: Dictionary = {}


func _ready() -> void:
	almacen = _ALMACEN_LOCAL.new()
	set_process(true)


func _process(delta: float) -> void:
	# Solo se late con el cerrojo en la mano. Con la subida pendiente TAMBIEN: el mundo sigue
	# reservado y hay que sostener la reserva hasta que la partida suba.
	if not latido_automatico:
		return
	if estado != HOST and estado != PENDIENTE_SUBIR:
		return
	_desde_ultimo_latido += delta
	if _desde_ultimo_latido < SEGUNDOS_LATIDO:
		return
	_desde_ultimo_latido = 0.0
	await latir()


# ============================================================
#  UN MUNDO NUEVO
#  El id es LARGO Y ALEATORIO a proposito: el Worker de la Fase 2 es publico y un id adivinable es
#  un mundo que cualquiera puede aporrear. No es la seguridad (esa es la contraseña), es no salir
#  en la rifa.
# ------------------------------------------------------------
func nuevo_id() -> String:
	var s := ""
	for i in 24:
		s += "0123456789abcdef"[randi() % 16]
	return s


func crear_mundo(id: String, contrasena: String) -> Dictionary:
	return await almacen.crear(id, contrasena)


# ============================================================
#  ABRIR (o unirse, que es el mismo boton)
#  Tres desenlaces, y el que manda es r["resultado"]:
#    "host"    el cerrojo es mio: en r["save"] vienen los bytes de la partida (vacios si el mundo
#              es nuevo) y ya estoy latiendo. Quien llama monta el save y hostea con Net.
#    "unirse"  lo tiene otro y esta VIVO: en r["direcciones"] estan las suyas, en orden de
#              preferencia. Quien llama va a Net.unirse con la misma contraseña como codigo de sala.
#    (ok:false) no se puede: r["error"] dice por que ("no_autorizado", "version_nueva"...).
#  La contraseña se pide SIEMPRE, tanto para abrir como para unirse: el que se une la necesita para
#  que el almacen le de la direccion, y la reutiliza como codigo de sala. Se escribe una vez.
# ------------------------------------------------------------
func abrir(id: String, contrasena: String, direcciones: Array = []) -> Dictionary:
	if estado == HOST or estado == PENDIENTE_SUBIR:
		return {"ok": false, "error": "ya_abierto",
			"mensaje": "Ya tienes un mundo abierto. Ciérralo antes de abrir otro."}
	_cambiar(TRABAJANDO)
	var r: Dictionary = await almacen.abrir(id, contrasena, direcciones,
		SaveData.VERSION_ACTUAL, Game.VERSION)
	if not r.get("ok", false):
		_cambiar(CERRADA)
		return r

	if String(r.get("resultado", "")) == "unirse":
		# No soy host: no tengo cerrojo ni nada que soltar. Solo el sitio al que ir.
		union = r
		_cambiar(CERRADA)
		return r

	mundo_id = id
	_contrasena = contrasena
	_token = int(r.get("token", 0))
	_desde_ultimo_latido = 0.0
	union = {}
	_cambiar(HOST)
	print("[nube] mundo ", id, " ABIERTO (token ", _token, ", ", int(r.get("save", PackedByteArray()).size()), " bytes)")
	return r


# ============================================================
#  LATIDO
#  Que lo rechacen NO es un detalle tecnico: es como te enteras de que has perdido el mundo
#  mientras juegas, en vez de descubrirlo al intentar subir dos horas de partida.
# ------------------------------------------------------------
func latir() -> Dictionary:
	if mundo_id == "" or _token == 0:
		return {"ok": false, "error": "sin_cerrojo", "mensaje": "No tienes ningún mundo abierto."}
	var r: Dictionary = await almacen.latido(mundo_id, _token)
	if not r.get("ok", false):
		var motivo: String = String(r.get("mensaje", "Se perdió el mundo."))
		push_warning("[nube] latido rechazado: %s" % motivo)
		_cambiar(PERDIDO)
		cerrojo_perdido.emit(motivo)
	return r


# ============================================================
#  CERRAR: subir y LUEGO soltar
#  Si la subida falla el cerrojo NO se libera y se queda en PENDIENTE_SUBIR (se sigue latiendo,
#  para sostener la reserva). Es mejor un mundo bloqueado que un mundo libre con la partida de ayer
#  dentro.
#  Si el estado es PERDIDO no se intenta ni subir: el token ya no vale y subir seria pisar al que
#  abrio despues. Se dice y se suelta lo local.
# ------------------------------------------------------------
func cerrar(save: PackedByteArray, meta: Dictionary = {}) -> Dictionary:
	if estado == PERDIDO:
		var r_perdido := {"ok": false, "error": "token_viejo",
			"mensaje": "El mundo lo tiene otro: esta partida no se puede subir."}
		_olvidar()
		return r_perdido
	if estado != HOST and estado != PENDIENTE_SUBIR:
		return {"ok": false, "error": "sin_cerrojo", "mensaje": "No tienes ningún mundo abierto."}

	var id := mundo_id
	var token := _token
	_cambiar(TRABAJANDO)
	var r: Dictionary = await almacen.cerrar(id, token, save, meta,
		SaveData.VERSION_ACTUAL, Game.VERSION)
	if r.get("ok", false):
		print("[nube] mundo ", id, " CERRADO y subido (", save.size(), " bytes)")
		_olvidar()
		return r

	if String(r.get("error", "")) == "token_viejo":
		# El escenario de pisado, visto desde el que revive: caduco, otro abrio, y su partida ya
		# esta arriba. Aqui no hay nada que reintentar.
		push_warning("[nube] subida RECHAZADA por vallado: %s" % String(r.get("mensaje", "")))
		_cambiar(PERDIDO)
		cerrojo_perdido.emit(String(r.get("mensaje", "")))
		_olvidar()
		return r

	# Cualquier otro fallo (sin red, disco lleno): el mundo sigue siendo mio, la partida sin subir.
	push_warning("[nube] subida FALLIDA: %s" % String(r.get("mensaje", "")))
	mundo_id = id
	_token = token
	_cambiar(PENDIENTE_SUBIR)
	subida_pendiente.emit(String(r.get("mensaje", "No se pudo subir la partida.")))
	return r


# Reintentar una subida que fallo. Es exactamente cerrar() otra vez: el cerrojo nunca se solto.
func reintentar_subida(save: PackedByteArray, meta: Dictionary = {}) -> Dictionary:
	if estado != PENDIENTE_SUBIR:
		return {"ok": false, "error": "nada_pendiente", "mensaje": "No hay ninguna subida pendiente."}
	return await cerrar(save, meta)


# ============================================================
#  ESTADO de un mundo, para pintar la lista del menu sin bajarse el save.
#  Ojo con r["caducado"]: el cerrojo esta ahi pero sin latido, o sea que el host se cayo y su
#  direccion esta MUERTA. En ese caso el almacen NO manda direcciones y lo que se le ofrece al
#  jugador es abrirlo el.
# ------------------------------------------------------------
func consultar(id: String, contrasena: String) -> Dictionary:
	return await almacen.estado(id, contrasena)


# ============================================================
#  LAS DIRECCIONES que se publican al abrir
#  El juego NO puede adivinar cual de las direcciones de la maquina es la de Hamachi
#  (get_local_addresses() las devuelve todas, incluidas las virtuales y la del movil compartiendo).
#  Asi que esto solo LISTA: elegir es del host, una vez, y luego se publica sola en cada apertura.
# ------------------------------------------------------------
func direcciones_locales() -> Array:
	var salida: Array = []
	for ip in IP.get_local_addresses():
		var s := String(ip)
		if s.begins_with("127.") or s == "::1" or s.contains(":"):
			continue   # loopback y IPv6 fuera: ENet aqui va por IPv4
		salida.append(s)
	return salida


# ============================================================
#  Cosas de dentro
# ------------------------------------------------------------
func _cambiar(nuevo: int) -> void:
	if estado == nuevo:
		return
	estado = nuevo
	estado_cambiado.emit(nuevo)


# Suelta lo que se sabe del mundo EN LOCAL. No toca el almacen: se llama cuando el cerrojo ya no
# esta (subido y soltado, o perdido).
func _olvidar() -> void:
	mundo_id = ""
	_contrasena = ""
	_token = 0
	_desde_ultimo_latido = 0.0
	_cambiar(CERRADA)
