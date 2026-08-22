# ============================================================
#  capa_hechizos.gd  (class_name CapaHechizos)
#  LO QUE VUELA entre las tarjetas de la pantalla de combate: el rayo que sale disparado, la bola
#  de fuego, las gotas y los rayos de la tormenta cayendo del cielo, la ola que barre la fila y
#  el rombo arcano. Y los arcos de los rebotes, que saltan de una victima a la siguiente.
#
#  Existe porque la embestida de tarjeta (CombatFX) esta bien para un tajo y fatal para un
#  conjuro: un mago no se lanza contra el bicho, se queda quieto y lo que viaja es la magia.
#
#  UN SOLO NODO CON UNA LISTA, no un nodo por proyectil. Un turno de Tormenta son ~32 impactos:
#  con un nodo cada uno serian 32 creados y liberados en dos segundos, y limpiar la pantalla tras
#  un desatasco (la tecla P) seria una caceria de huerfanos. Con una lista es _efectos.clear().
#  Ademas el orden de dibujo pasa a ser el orden de la lista -- o sea, el orden de la cola de
#  impactos -- y no el orden de los hermanos en el arbol, que es mucho mas facil de razonar.
#
#  Las FORMAS son las de scripts/actors/player/proyectil_hechizo.gd, el proyectil que ya vuela por
#  la mazmorra: se copian y no se reutiliza el nodo porque aquel es un Node2D que da por hecho que
#  vive en el mundo (z_index absoluto, y al reventar cuelga la chispa de su padre).
#
#  Dos reglas que parecen detalles y no lo son:
#   - Los puntos A y B se CONGELAN al nacer el efecto. Si se leyeran cada frame, el proyectil
#     temblaria con la sacudida de la tarjeta a la que va, y reventaria si esa tarjeta se libera
#     a mitad de vuelo.
#   - El azar (rehacer el zigzag) va en _process, NUNCA en _draw: _draw puede llamarse cero o
#     varias veces en el mismo frame, y el rayo bailaria de forma distinta cada vez.
# ============================================================

extends Control
class_name CapaHechizos

const ZIGZAG_CADA := 0.04    # cada cuanto se rehace el chisporroteo
const FUERA := -20.0         # de que altura caen los rayos y las gotas (por encima del techo)

# Cada efecto vivo. Se reciclan los diccionarios: en una tormenta se dan de alta 32 en dos
# segundos y no hace falta que el recolector se entere.
var _efectos: Array[Dictionary] = []
var _pool: Array[Dictionary] = []

# El ritmo al que corren los dibujos. Lo mantiene igualado CombatFX (ver su escala_tiempo).
var escala_tiempo: float = 1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false   # un rayo que cae del cielo empieza FUERA de la capa
	# OBLIGATORIO: en solitario el arbol del juego esta pausado durante el combate (en multi no).
	# Sin esto los conjuros se ven jugando con un compañero y se congelan jugando solo.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# Da de alta un efecto. 'a' = de donde sale (la tarjeta del que lanza, o de la victima anterior en
# un rebote), 'b' = donde impacta. 'dur' es el tiempo de vuelo que le ha reservado la cola, para
# que el impacto aterrice justo cuando salen el numero y el temblor.
func alta(estilo: int, a: Vector2, b: Vector2, color: Color, peso: float, dur: float,
		ancho_destino: float, elem: int = 0, golpe: int = 0, escudo: int = -1) -> void:
	var e: Dictionary = _pool.pop_back() if not _pool.is_empty() else {}
	e.clear()
	e["estilo"] = estilo
	e["b"] = b
	e["col"] = color
	e["t"] = 0.0
	e["dur"] = maxf(dur, 0.05)
	e["semilla"] = randf() * TAU
	# El tamaño tambien lleva informacion: el que come el golpe entero recibe una bola mas gorda
	# que el que solo se lleva la salpicadura.
	e["r"] = lerpf(7.0, 16.0, clampf(peso, 0.0, 1.5) / 1.5)
	e["ancho"] = ancho_destino
	e["elem"] = elem
	# QUE GOLPE de la accion es este (0 el primero). Casi ningun gesto lo mira; los que encadenan una
	# figura entre varios golpes, si.
	e["golpe"] = golpe
	# QUE ESCUDO lleva el que pega (ShieldData.Tamano; -1 = ninguno, y entonces se dibuja el mediano
	# por defecto). Lo miran los gestos que pintan una chapa.
	e["escudo"] = escudo
	e["zig"] = PackedVector2Array()
	e["prox"] = 0.0
	e["curva"] = false
	e["gotas"] = []

	match estilo:
		CombatFX.Estilo.CAIDA_RAYO, CombatFX.Estilo.CAIDA_GOTA:
			# Del cielo: el origen es el techo de la pantalla, justo encima del objetivo.
			e["a"] = Vector2(b.x + randf_range(-14.0, 14.0), FUERA)
		CombatFX.Estilo.AURA, CombatFX.Estilo.CAPARAZON, CombatFX.Estilo.MURALLA, \
		CombatFX.Estilo.ESCUDO, CombatFX.Estilo.IMBUIR_FILO, CombatFX.Estilo.EN_GUARDIA, \
		CombatFX.Estilo.VOTO_GUARDIA, CombatFX.Estilo.VOZ_MANDO, CombatFX.Estilo.ACERO_EN_ALTO, \
		CombatFX.Estilo.DESVANECER, \
		CombatFX.Estilo.GRITO_ALIENTO, CombatFX.Estilo.MURO_ALIADOS, \
		CombatFX.Estilo.SED_SANGRE, CombatFX.Estilo.MARTILLO_EN_ALTO, \
		CombatFX.Estilo.FOCO_ARCANO, CombatFX.Estilo.VELO_UMBRIO, \
		CombatFX.Estilo.VIENTO_LIMPIO, \
		CombatFX.Estilo.PROVOCACION_FX, CombatFX.Estilo.GUARDIA_CARNE_FX, \
		CombatFX.Estilo.COBERTURA, \
		CombatFX.Estilo.PURIFICAR, CombatFX.Estilo.EGIDA_MENOR:
			# No viajan: nacen y mueren sobre la misma tarjeta (el bicho se lo echa ENCIMA, y el
			# picaro se unta el filo).
			e["a"] = b
		CombatFX.Estilo.MORDISCO, CombatFX.Estilo.COLMILLAZO, CombatFX.Estilo.YUGULAR, \
		CombatFX.Estilo.ZARPAZO, CombatFX.Estilo.PLACAJE, CombatFX.Estilo.CORNADA, \
		CombatFX.Estilo.PISOTON, CombatFX.Estilo.GOLPETAZO, \
		CombatFX.Estilo.DAGA_CORTE, CombatFX.Estilo.DAGA_RAFAGA, \
		CombatFX.Estilo.PUNALADA, \
		CombatFX.Estilo.ESTOQUE_PUNZADA, CombatFX.Estilo.ESTOCADA_PENETRANTE, \
		CombatFX.Estilo.FINTAS, CombatFX.Estilo.PASO_LIGERO, \
		CombatFX.Estilo.PUNZADA_NERVIO, CombatFX.Estilo.DANZA_ACERO, \
		CombatFX.Estilo.ESPADA_TAJO, CombatFX.Estilo.TAJO_QUEBRANTADOR, \
		CombatFX.Estilo.DOBLE_TAJO, CombatFX.Estilo.CAMBIO_RITMO, \
		CombatFX.Estilo.SENALAR_HUECO, CombatFX.Estilo.CORTE_TENDONES, \
		CombatFX.Estilo.ESPADA_LARGA_TAJO, CombatFX.Estilo.TAJO_PESADO, \
		CombatFX.Estilo.TAJO_DESARMANTE, CombatFX.Estilo.GUARDIA_ROTA, \
		CombatFX.Estilo.ESTOCADA_MARCIAL, CombatFX.Estilo.ESCUDAZO, \
		CombatFX.Estilo.MANDOBLE_TAJO, CombatFX.Estilo.TAJO_DEVASTADOR, \
		CombatFX.Estilo.MOLINETE, \
		CombatFX.Estilo.TAJO_VERDUGO, CombatFX.Estilo.SEGAR, \
		CombatFX.Estilo.MAZA_GOLPE, CombatFX.Estilo.GOLPE_DEMOLEDOR, \
		CombatFX.Estilo.ROMPEPIERNAS, CombatFX.Estilo.APLASTAMIENTO, \
		CombatFX.Estilo.CULATAZO, \
		CombatFX.Estilo.HACHA_TAJO, CombatFX.Estilo.HENDEDURA, \
		CombatFX.Estilo.HACHAZO_BRUTAL, CombatFX.Estilo.CARNICERIA, \
		CombatFX.Estilo.DESGARRO, \
		CombatFX.Estilo.MARTILLO_GOLPE, CombatFX.Estilo.GOLPE_SISMICO, \
		CombatFX.Estilo.ONDA_EXPANSIVA, CombatFX.Estilo.ROMPECORAZAS, \
		CombatFX.Estilo.MARTILLO_GUERRA, CombatFX.Estilo.TEMBLOR_SUELO, \
		CombatFX.Estilo.BASTON_GOLPE, CombatFX.Estilo.BASTONAZO, \
		CombatFX.Estilo.SELLO_ARCANO, \
		CombatFX.Estilo.PUNOS_GOLPE, CombatFX.Estilo.EMBESTIDA_ESCUDO:
			# Tampoco viajan, pero por el motivo CONTRARIO al aura: lo que se desplaza es la tarjeta
			# del que muerde (embiste, ver CombatFX), asi que las fauces tienen que estar ya donde
			# van a cerrarse. Si salieran del atacante se veria un par de dientes cruzando la
			# pantalla por su cuenta mientras el bicho llega por detras.
			e["a"] = b
		CombatFX.Estilo.BARRIDO:
			# RECTA, NUNCA EN DIAGONAL. Un frente de agua avanza de una fila a la otra; si sale de la
			# tarjeta del que lanza y va al centro de lo barrido, cuando esos dos no estan alineados
			# la lamina cruza la pantalla torcida y se ve rarisimo -- ademas de que una ola inclinada
			# no "barre" nada. Se le hace nacer JUSTO DEBAJO del destino: conserva la distancia (o
			# sea el tiempo de viaje) y sube derecha.
			e["a"] = Vector2(b.x, a.y)
		CombatFX.Estilo.ARCO:
			e["a"] = a
			# Un rebote puede caer OTRA VEZ en el mismo bicho (pasa siempre en 1v1). Entonces no hay
			# trayecto que dibujar, asi que el arco sale de la tarjeta, da la vuelta por arriba y
			# vuelve a ella. El lado alterna al azar, para que cinco rebotes seguidos sobre el mismo
			# se vean como cinco arcos distintos y se puedan contar.
			if a.distance_to(b) < 4.0:
				e["curva"] = true
				e["ctrl"] = a + Vector2(randf_range(60.0, 90.0) * (1.0 if randf() < 0.5 else -1.0), -70.0)
		_:
			# Si no hay tarjeta de origen (pasa en el espejo cuando el lanzador no esta en el
			# roster que le llego), el conjuro saldria de la esquina de la pantalla. Se le hace
			# nacer por debajo del objetivo, que es de donde viene lo tuyo: tu fila esta abajo.
			e["a"] = a if a != Vector2.ZERO else b + Vector2(0.0, 180.0)

	if estilo == CombatFX.Estilo.CAIDA_GOTA:
		# Un chaparron no es UNA gota: son varias, cada una con su desfase y su desvio.
		var n: int = 3 + (randi() % 3)
		for i in n:
			e["gotas"].append([randf_range(-e["r"] * 2.2, e["r"] * 2.2), randf() * 0.35])

	_efectos.append(e)


# Vacia la pantalla YA. La llama CombatFX.cancelar (o sea, la tecla P y el final de la pelea): sin
# esto se quedarian bolas y rayos pintados en el aire para siempre.
func limpiar() -> void:
	for e in _efectos:
		_pool.append(e)
	_efectos.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if _efectos.is_empty():
		return
	# AL MISMO RITMO QUE EL RESTO. Esta capa lleva su propio reloj, asi que si no se escala aqui
	# tambien, al bajar la velocidad las tarjetas se movian despacio pero los conjuros seguian
	# volando igual de rapido, y el impacto dejaba de coincidir con el golpe. Lo pone CombatFX.
	var d: float = delta * escala_tiempo
	var i: int = _efectos.size() - 1
	while i >= 0:
		var e: Dictionary = _efectos[i]
		e["t"] = float(e["t"]) + d
		# El chisporroteo del rayo se rehace AQUI y no en _draw (ver cabecera).
		if _es_rayo(int(e["estilo"])) and float(e["t"]) >= float(e["prox"]):
			e["prox"] = float(e["t"]) + ZIGZAG_CADA
			e["zig"] = _nuevo_zigzag(e)
		if float(e["t"]) >= _vida(e):
			_pool.append(e)
			_efectos.remove_at(i)
		i -= 1
	queue_redraw()


# Lo que dura el efecto ENTERO: el vuelo mas la coleta de despues (el reventon, el resplandor del
# rayo apagandose, la salpicadura de la gota).
func _vida(e: Dictionary) -> float:
	var es: int = int(e["estilo"])
	# Los mordiscos casi no tienen vuelo (van con la embestida), asi que TODO lo suyo pasa en la
	# coleta: cerrarse, el rebote de la mandibula y la marca quedandose un instante. Con los 0.12 de
	# siempre la dentellada era un parpadeo y no se llegaba a leer.
	if es == CombatFX.Estilo.MORDISCO:
		return float(e["dur"]) + 0.30
	if es == CombatFX.Estilo.COLMILLAZO:
		return float(e["dur"]) + 0.38   # fauces mas grandes, cierran mas despacio
	if es == CombatFX.Estilo.YUGULAR:
		return float(e["dur"]) + 0.40   # y ademas tiene que apagarse el destello
	if es == CombatFX.Estilo.CHILLIDO:
		return float(e["dur"]) + 0.34   # lo que tarda el ultimo anillo en salir de la fila
	if es == CombatFX.Estilo.ZARPAZO:
		return float(e["dur"]) + 0.34   # las cuatro garras entran escalonadas, no a la vez
	if es == CombatFX.Estilo.PLACAJE:
		return float(e["dur"]) + 0.32   # chafarse y escurrirse lleva su tiempo
	if es == CombatFX.Estilo.CORNADA:
		return float(e["dur"]) + 0.30
	if es == CombatFX.Estilo.CARGA:
		return float(e["dur"]) + 0.30   # la polvareda del choque se queda un poco
	if es == CombatFX.Estilo.PISOTON:
		return float(e["dur"]) + 0.38   # la grieta abre y la onda tiene que llegar a los lados
	if es == CombatFX.Estilo.GOLPETAZO:
		return float(e["dur"]) + 0.26   # un porrazo es seco: entra y se va
	# Los de ponerse a cubierto AGUANTAN puestos un buen rato: son un buff que dura turnos, y si se
	# cerraran y desaparecieran en tres cuartos de segundo no se leeria que el bicho se ha protegido.
	if es == CombatFX.Estilo.CAPARAZON or es == CombatFX.Estilo.MURALLA \
			or es == CombatFX.Estilo.ESCUDO:
		return float(e["dur"]) + 0.70
	if es == CombatFX.Estilo.MIRADA:
		return float(e["dur"]) + 0.30
	if es == CombatFX.Estilo.LATIGAZO:
		return float(e["dur"]) + 0.32
	if es == CombatFX.Estilo.PONZONA:
		return float(e["dur"]) + 0.34
	if es == CombatFX.Estilo.TELARANA:
		return float(e["dur"]) + 0.42   # se despliega y se queda tirante un momento
	if es == CombatFX.Estilo.ENROSQUE:
		return float(e["dur"]) + 0.42   # apretar lleva su tiempo
	if es == CombatFX.Estilo.PATAS:
		return float(e["dur"]) + 0.30
	if es == CombatFX.Estilo.RODADA:
		return float(e["dur"]) + 0.34
	if es == CombatFX.Estilo.RAICES:
		return float(e["dur"]) + 0.34   # brotan y se quedan un momento antes de ceder el relevo
			# al dibujo del estado, que ya las mantiene puestas mientras dure
	# EL AURA SE CORTABA A UN TERCIO. Su painter se anima sobre `dur + 0.55` ("un buff tiene que
	# lucir", dice alli), pero aqui caia en el 0.12 de por defecto: el efecto se retiraba en 0.22
	# cuando llevaba un 34% de su animacion y todavia estaba al 80% de opacidad, o sea que la
	# Ignicion del slime de fuego desaparecia de golpe en vez de apagarse. Los dos numeros tienen
	# que ser EL MISMO.
	if es == CombatFX.Estilo.AURA:
		return float(e["dur"]) + 0.55
	# LAS DEL JUGADOR. Los numeros tienen que ser LOS MISMOS que usan sus painters para dividir la
	# coleta, por lo que le paso al aura ahi arriba.
	#
	# La daga va CORTA a proposito: es el arma rapida del juego, y una coleta larga la hacia parecer
	# pesada. La RAFAGA todavia menos, que son dos tajos seguidos y con 0.26 el segundo entraba antes
	# de que el primero se hubiera ido, y se veian pisados.
	if es == CombatFX.Estilo.DAGA_CORTE:
		return float(e["dur"]) + 0.24
	if es == CombatFX.Estilo.DAGA_RAFAGA:
		return float(e["dur"]) + 0.20
	if es == CombatFX.Estilo.PUNALADA:
		return float(e["dur"]) + 0.34   # entra, se hunde y se queda un momento clavada
	if es == CombatFX.Estilo.DESVANECER:
		return float(e["dur"]) + 0.30   # la sombra tarda en deshacerse
	if es == CombatFX.Estilo.IMBUIR_FILO:
		return float(e["dur"]) + COLETA_IMBUIR
	# EL ESTOQUE. Una estocada es SECA: entra y sale, asi que sus coletas son cortas. Las unicas
	# largas son la que atraviesa (hay que ver la hoja al otro lado) y la postura, que es un buff.
	if es == CombatFX.Estilo.ESTOQUE_PUNZADA:
		return float(e["dur"]) + COLETA_ESTOCADA
	if es == CombatFX.Estilo.FINTAS:
		return float(e["dur"]) + COLETA_FINTAS
	if es == CombatFX.Estilo.ESTOCADA_PENETRANTE:
		return float(e["dur"]) + COLETA_PENETRANTE
	if es == CombatFX.Estilo.PASO_LIGERO:
		return float(e["dur"]) + COLETA_PASO
	if es == CombatFX.Estilo.PUNZADA_NERVIO:
		return float(e["dur"]) + COLETA_NERVIO
	if es == CombatFX.Estilo.DANZA_ACERO:
		return float(e["dur"]) + COLETA_DANZA
	if es == CombatFX.Estilo.EN_GUARDIA:
		return float(e["dur"]) + COLETA_GUARDIA
	# LA ESPADA CORTA. Mas larga que la de la daga: el trazo es mas amplio y tiene que recorrerse.
	if es == CombatFX.Estilo.ESPADA_TAJO:
		return float(e["dur"]) + COLETA_ESPADA
	if es == CombatFX.Estilo.CAMBIO_RITMO:
		return float(e["dur"]) + COLETA_ESPADA_RAPIDA
	if es == CombatFX.Estilo.DOBLE_TAJO:
		return float(e["dur"]) + COLETA_DOBLE_TAJO
	if es == CombatFX.Estilo.TAJO_QUEBRANTADOR:
		return float(e["dur"]) + COLETA_QUEBRANTADOR
	if es == CombatFX.Estilo.SENALAR_HUECO:
		return float(e["dur"]) + COLETA_SENALAR
	if es == CombatFX.Estilo.CORTE_TENDONES:
		return float(e["dur"]) + COLETA_TENDONES
	# LA ESPADA LARGA (y el escudo).
	if es == CombatFX.Estilo.ESPADA_LARGA_TAJO:
		return float(e["dur"]) + COLETA_LARGA
	if es == CombatFX.Estilo.TAJO_PESADO:
		return float(e["dur"]) + COLETA_PESADO
	if es == CombatFX.Estilo.TAJO_DESARMANTE:
		return float(e["dur"]) + COLETA_DESARMANTE
	if es == CombatFX.Estilo.GUARDIA_ROTA:
		return float(e["dur"]) + COLETA_GUARDIA_ROTA
	if es == CombatFX.Estilo.VOTO_GUARDIA:
		return float(e["dur"]) + COLETA_VOTO
	if es == CombatFX.Estilo.ESTOCADA_MARCIAL:
		return float(e["dur"]) + COLETA_MARCIAL
	if es == CombatFX.Estilo.VOZ_MANDO:
		return float(e["dur"]) + COLETA_VOZ
	if es == CombatFX.Estilo.ESCUDAZO:
		return float(e["dur"]) + COLETA_ESCUDAZO
	# LOS MANDOBLES.
	if es == CombatFX.Estilo.MANDOBLE_TAJO:
		return float(e["dur"]) + COLETA_MANDOBLE
	if es == CombatFX.Estilo.TAJO_DEVASTADOR:
		return float(e["dur"]) + COLETA_DEVASTADOR
	if es == CombatFX.Estilo.MOLINETE:
		return float(e["dur"]) + COLETA_MOLINETE
	if es == CombatFX.Estilo.GRITO_GUERRA:
		return float(e["dur"]) + COLETA_GRITO
	if es == CombatFX.Estilo.TAJO_VERDUGO:
		return float(e["dur"]) + COLETA_VERDUGO
	if es == CombatFX.Estilo.SEGAR:
		return float(e["dur"]) + COLETA_SEGAR
	if es == CombatFX.Estilo.ACERO_EN_ALTO:
		return float(e["dur"]) + COLETA_ACERO_ALTO
	# LA MAZA PEQUEÑA.
	if es == CombatFX.Estilo.MAZA_GOLPE:
		return float(e["dur"]) + COLETA_MAZA
	if es == CombatFX.Estilo.GOLPE_DEMOLEDOR:
		return float(e["dur"]) + COLETA_DEMOLEDOR
	if es == CombatFX.Estilo.ROMPEPIERNAS:
		return float(e["dur"]) + COLETA_ROMPEPIERNAS
	if es == CombatFX.Estilo.APLASTAMIENTO:
		return float(e["dur"]) + COLETA_APLASTAMIENTO
	if es == CombatFX.Estilo.CULATAZO:
		return float(e["dur"]) + COLETA_CULATAZO
	if es == CombatFX.Estilo.GRITO_ALIENTO:
		return float(e["dur"]) + COLETA_ALIENTO
	if es == CombatFX.Estilo.MURO_ALIADOS:
		return float(e["dur"]) + COLETA_MURO
	# EL HACHA GRANDE.
	if es == CombatFX.Estilo.HACHA_TAJO:
		return float(e["dur"]) + COLETA_HACHA
	if es == CombatFX.Estilo.HENDEDURA:
		return float(e["dur"]) + COLETA_HENDEDURA
	if es == CombatFX.Estilo.HACHAZO_BRUTAL:
		return float(e["dur"]) + COLETA_BRUTAL
	if es == CombatFX.Estilo.CARNICERIA:
		return float(e["dur"]) + COLETA_CARNICERIA
	if es == CombatFX.Estilo.DESGARRO:
		return float(e["dur"]) + COLETA_DESGARRO
	if es == CombatFX.Estilo.SED_SANGRE:
		return float(e["dur"]) + COLETA_SED
	# EL MARTILLO GRANDE.
	if es == CombatFX.Estilo.MARTILLO_GOLPE:
		return float(e["dur"]) + COLETA_MARTILLO
	if es == CombatFX.Estilo.GOLPE_SISMICO:
		return float(e["dur"]) + COLETA_SISMICO
	if es == CombatFX.Estilo.ONDA_EXPANSIVA:
		return float(e["dur"]) + COLETA_ONDA
	if es == CombatFX.Estilo.ROMPECORAZAS:
		return float(e["dur"]) + COLETA_ROMPECORAZAS
	if es == CombatFX.Estilo.MARTILLO_GUERRA:
		return float(e["dur"]) + COLETA_MARTILLO_GUERRA
	if es == CombatFX.Estilo.MARTILLO_EN_ALTO:
		return float(e["dur"]) + COLETA_MARTILLO_ALTO
	if es == CombatFX.Estilo.TEMBLOR_SUELO:
		return float(e["dur"]) + COLETA_TEMBLOR
	# EL BASTON.
	if es == CombatFX.Estilo.BASTON_GOLPE:
		return float(e["dur"]) + COLETA_BASTON
	if es == CombatFX.Estilo.BASTONAZO:
		return float(e["dur"]) + COLETA_BASTONAZO
	if es == CombatFX.Estilo.FOCO_ARCANO:
		return float(e["dur"]) + COLETA_FOCO
	if es == CombatFX.Estilo.SELLO_ARCANO:
		return float(e["dur"]) + COLETA_SELLO
	if es == CombatFX.Estilo.VELO_UMBRIO:
		return float(e["dur"]) + COLETA_VELO
	if es == CombatFX.Estilo.VIENTO_LIMPIO:
		return float(e["dur"]) + COLETA_VIENTO
	# LOS PUÑOS Y EL RESTO DEL ESCUDO.
	if es == CombatFX.Estilo.PUNOS_GOLPE:
		return float(e["dur"]) + COLETA_PUNOS
	if es == CombatFX.Estilo.EMBESTIDA_ESCUDO:
		return float(e["dur"]) + COLETA_EMBESTIDA
	if es == CombatFX.Estilo.PROVOCACION_FX:
		return float(e["dur"]) + COLETA_PROVOCACION
	if es == CombatFX.Estilo.GUARDIA_CARNE_FX:
		return float(e["dur"]) + COLETA_GUARDIA_CARNE
	if es == CombatFX.Estilo.COBERTURA:
		return float(e["dur"]) + COLETA_COBERTURA
	# LA VARITA.
	if es == CombatFX.Estilo.PURIFICAR:
		return float(e["dur"]) + COLETA_PURIFICAR
	if es == CombatFX.Estilo.CHISPA_VINCULADA:
		return float(e["dur"]) + COLETA_CHISPA
	if es == CombatFX.Estilo.EGIDA_MENOR:
		return float(e["dur"]) + COLETA_EGIDA
	var extra: float = 0.18 if _es_rayo(es) else 0.12
	return float(e["dur"]) + extra


func _es_rayo(estilo: int) -> bool:
	return estilo == CombatFX.Estilo.RAYO or estilo == CombatFX.Estilo.CAIDA_RAYO \
		or estilo == CombatFX.Estilo.ARCO


# ------------------------------------------------------------
#  DIBUJO
# ------------------------------------------------------------

func _draw() -> void:
	for e in _efectos:
		match int(e["estilo"]):
			CombatFX.Estilo.PROYECTIL: _pintar_fuego(e)
			CombatFX.Estilo.RAYO, CombatFX.Estilo.CAIDA_RAYO, CombatFX.Estilo.ARCO: _pintar_rayo(e)
			CombatFX.Estilo.CAIDA_GOTA: _pintar_gotas(e)
			CombatFX.Estilo.BARRIDO: _pintar_ola(e)
			CombatFX.Estilo.ARCANO: _pintar_arcano(e)
			CombatFX.Estilo.EXPLOSION: _pintar_explosion(e)
			CombatFX.Estilo.SPLAT: _pintar_splat(e)
			CombatFX.Estilo.ESCUPITAJO: _pintar_escupitajo(e)
			CombatFX.Estilo.AURA: _pintar_aura(e)
			CombatFX.Estilo.VORTICE: _pintar_vortice(e)
			CombatFX.Estilo.ARRASTRE: _pintar_arrastre(e)
			CombatFX.Estilo.MORDISCO: _pintar_mordisco(e)
			CombatFX.Estilo.COLMILLAZO: _pintar_colmillazo(e)
			CombatFX.Estilo.YUGULAR: _pintar_yugular(e)
			CombatFX.Estilo.CHILLIDO: _pintar_chillido(e)
			CombatFX.Estilo.ZARPAZO: _pintar_zarpazo(e)
			CombatFX.Estilo.PLACAJE: _pintar_placaje(e)
			CombatFX.Estilo.CORNADA: _pintar_cornada(e)
			CombatFX.Estilo.CARGA: _pintar_carga(e)
			CombatFX.Estilo.PISOTON: _pintar_pisoton(e)
			CombatFX.Estilo.GOLPETAZO: _pintar_golpetazo(e)
			CombatFX.Estilo.RAICES: _pintar_raices(e)
			CombatFX.Estilo.CAPARAZON: _pintar_caparazon(e)
			CombatFX.Estilo.MURALLA: _pintar_muralla(e)
			CombatFX.Estilo.ESCUDO: _pintar_escudo(e)
			CombatFX.Estilo.PONZONA: _pintar_ponzona(e)
			CombatFX.Estilo.TELARANA: _pintar_telarana(e)
			CombatFX.Estilo.ENROSQUE: _pintar_enrosque(e)
			CombatFX.Estilo.PATAS: _pintar_patas(e)
			CombatFX.Estilo.RODADA: _pintar_rodada(e)
			CombatFX.Estilo.MIRADA: _pintar_mirada(e)
			CombatFX.Estilo.LATIGAZO: _pintar_latigazo(e)
			CombatFX.Estilo.DAGA_CORTE, CombatFX.Estilo.DAGA_RAFAGA: _pintar_daga_corte(e)
			CombatFX.Estilo.PUNALADA: _pintar_punalada(e)
			CombatFX.Estilo.IMBUIR_FILO: _pintar_imbuir_filo(e)
			CombatFX.Estilo.DESVANECER: _pintar_desvanecer(e)
			CombatFX.Estilo.ESTOQUE_PUNZADA, CombatFX.Estilo.FINTAS, \
			CombatFX.Estilo.ESTOCADA_PENETRANTE: _pintar_estocada(e)
			CombatFX.Estilo.EN_GUARDIA: _pintar_en_guardia(e)
			CombatFX.Estilo.PASO_LIGERO: _pintar_paso_ligero(e)
			CombatFX.Estilo.PUNZADA_NERVIO: _pintar_punzada_nervio(e)
			CombatFX.Estilo.DANZA_ACERO: _pintar_danza_acero(e)
			CombatFX.Estilo.ESPADA_TAJO, CombatFX.Estilo.CAMBIO_RITMO: _pintar_espada_tajo(e)
			CombatFX.Estilo.DOBLE_TAJO: _pintar_doble_tajo(e)
			CombatFX.Estilo.TAJO_QUEBRANTADOR: _pintar_quebrantador(e)
			CombatFX.Estilo.SENALAR_HUECO: _pintar_senalar_hueco(e)
			CombatFX.Estilo.CORTE_TENDONES: _pintar_corte_tendones(e)
			CombatFX.Estilo.ESPADA_LARGA_TAJO, CombatFX.Estilo.TAJO_PESADO, 			CombatFX.Estilo.GUARDIA_ROTA: _pintar_espada_larga(e)
			CombatFX.Estilo.TAJO_DESARMANTE: _pintar_desarmante(e)
			CombatFX.Estilo.VOTO_GUARDIA: _pintar_voto_guardia(e)
			CombatFX.Estilo.ESTOCADA_MARCIAL: _pintar_estocada_marcial(e)
			CombatFX.Estilo.VOZ_MANDO: _pintar_voz_mando(e)
			CombatFX.Estilo.ESCUDAZO: _pintar_escudazo(e)
			CombatFX.Estilo.MANDOBLE_TAJO: _pintar_mandoble_tajo(e)
			CombatFX.Estilo.TAJO_DEVASTADOR: _pintar_devastador(e)
			CombatFX.Estilo.MOLINETE: _pintar_molinete(e)
			CombatFX.Estilo.GRITO_GUERRA: _pintar_grito_guerra(e)
			CombatFX.Estilo.TAJO_VERDUGO: _pintar_verdugo(e)
			CombatFX.Estilo.SEGAR: _pintar_segar(e)
			CombatFX.Estilo.ACERO_EN_ALTO: _pintar_acero_en_alto(e)
			CombatFX.Estilo.MAZA_GOLPE, CombatFX.Estilo.CULATAZO: _pintar_maza_golpe(e)
			CombatFX.Estilo.GOLPE_DEMOLEDOR: _pintar_demoledor(e)
			CombatFX.Estilo.ROMPEPIERNAS: _pintar_rompepiernas(e)
			CombatFX.Estilo.APLASTAMIENTO: _pintar_aplastamiento(e)
			CombatFX.Estilo.GRITO_ALIENTO: _pintar_grito_aliento(e)
			CombatFX.Estilo.MURO_ALIADOS: _pintar_muro_aliados(e)
			CombatFX.Estilo.HACHA_TAJO: _pintar_hacha_tajo(e)
			CombatFX.Estilo.HENDEDURA: _pintar_hendedura(e)
			CombatFX.Estilo.HACHAZO_BRUTAL: _pintar_hachazo_brutal(e)
			CombatFX.Estilo.CARNICERIA: _pintar_carniceria(e)
			CombatFX.Estilo.DESGARRO: _pintar_desgarro(e)
			CombatFX.Estilo.SED_SANGRE: _pintar_sed_sangre(e)
			CombatFX.Estilo.MARTILLO_GOLPE: _pintar_martillo_golpe(e)
			CombatFX.Estilo.GOLPE_SISMICO: _pintar_golpe_sismico(e)
			CombatFX.Estilo.ONDA_EXPANSIVA: _pintar_onda_expansiva(e)
			CombatFX.Estilo.TEMBLOR_SUELO: _pintar_temblor(e)
			CombatFX.Estilo.ROMPECORAZAS: _pintar_rompecorazas(e)
			CombatFX.Estilo.MARTILLO_GUERRA: _pintar_martillo_guerra(e)
			CombatFX.Estilo.MARTILLO_EN_ALTO: _pintar_martillo_en_alto(e)
			CombatFX.Estilo.BASTON_GOLPE, CombatFX.Estilo.BASTONAZO: _pintar_bastonazo(e)
			CombatFX.Estilo.FOCO_ARCANO: _pintar_foco_arcano(e)
			CombatFX.Estilo.SELLO_ARCANO: _pintar_sello_arcano(e)
			CombatFX.Estilo.VELO_UMBRIO: _pintar_velo_umbrio(e)
			CombatFX.Estilo.VIENTO_LIMPIO: _pintar_viento_limpio(e)
			CombatFX.Estilo.PUNOS_GOLPE: _pintar_punos(e)
			CombatFX.Estilo.EMBESTIDA_ESCUDO: _pintar_embestida_escudo(e)
			CombatFX.Estilo.PROVOCACION_FX: _pintar_provocacion(e)
			CombatFX.Estilo.GUARDIA_CARNE_FX: _pintar_guardia_carne(e)
			CombatFX.Estilo.COBERTURA: _pintar_cobertura(e)
			CombatFX.Estilo.PURIFICAR: _pintar_purificar(e)
			CombatFX.Estilo.CHISPA_VINCULADA: _pintar_chispa_vinculada(e)
			CombatFX.Estilo.EGIDA_MENOR: _pintar_egida_menor(e)


# BOLA DE FUEGO que vuela acelerando (u*u: sale de la mano despacio y llega lanzada), con estela
# detras, y que revienta en un anillo al llegar.
func _pintar_fuego(e: Dictionary) -> void:
	var a: Vector2 = e["a"]
	var b: Vector2 = e["b"]
	var col: Color = e["col"]
	var r: float = e["r"]
	var t: float = e["t"]
	var u: float = clampf(t / float(e["dur"]), 0.0, 1.0)
	var dir: Vector2 = (b - a).normalized() if a.distance_to(b) > 1.0 else Vector2.DOWN

	if u < 1.0:
		var p: Vector2 = a.lerp(b, u * u)
		# ESTELA: tres bolas cada vez mas pequeñas y transparentes por detras.
		for k in 3:
			var uk: float = maxf(0.0, u - 0.06 * float(k + 1))
			var pk: Vector2 = a.lerp(b, uk * uk)
			draw_circle(pk, r * (0.55 - 0.13 * float(k)), Color(col.r, col.g, col.b, 0.30 - 0.08 * float(k)))
		# LA BOLA: lengüetas que se estiran hacia atras (el aire se las peina), halo y nucleo claro.
		var pulso: float = 1.0 + 0.12 * sin(t * 14.0 + float(e["semilla"]))
		var rr: float = r * pulso
		var atras: Vector2 = -dir
		var puntas := PackedVector2Array()
		var n := 9
		for i in n:
			var ang: float = TAU * float(i) / float(n)
			var dirp := Vector2(cos(ang), sin(ang))
			var estira: float = 1.0 + 0.85 * maxf(0.0, dirp.dot(atras))
			var ondeo: float = 1.0 + 0.22 * sin(t * 18.0 + float(i) * 1.7 + float(e["semilla"]))
			puntas.append(p + dirp * rr * estira * ondeo)
		draw_colored_polygon(puntas, Color(col.r, col.g, col.b, 0.55))
		draw_circle(p, rr * 0.62, col)
		draw_circle(p, rr * 0.34, Color(1.0, 0.95, 0.75))
	else:
		# EL REVENTON: un anillo que se abre y se apaga.
		var v: float = clampf((t - float(e["dur"])) / 0.12, 0.0, 1.0)
		draw_arc(b, r * (1.0 + 3.0 * v), 0.0, TAU, 20, Color(col.r, col.g, col.b, 1.0 - v), 3.0, true)


# RAYO. NO viaja: EXISTE. La polilinea cubre el camino entero desde el primer frame y luego se
# apaga -- una bolita recorriendo la trayectoria no se lee como un rayo, se lee como una canica.
# Las tres pasadas (resplandor gordo translucido, color, nucleo blanco fino) son el estilo de la
# casa, copiado del proyectil de la mazmorra.
func _pintar_rayo(e: Dictionary) -> void:
	var zig: PackedVector2Array = e["zig"]
	if zig.size() < 2:
		return
	var col: Color = e["col"]
	var t: float = e["t"]
	var dur: float = e["dur"]
	# Brilla entero mientras "llega" y se apaga despues.
	var alfa: float = 1.0 if t < dur else clampf(1.0 - (t - dur) / 0.18, 0.0, 1.0)
	var g: float = maxf(2.0, float(e["r"]) * 0.75)
	if int(e["estilo"]) == CombatFX.Estilo.CAIDA_RAYO:
		# El FOGONAZO de la columna: una franja ancha y tenue por donde ha caido. Es lo que hace que
		# veinte rayos se lean como una tormenta y no como veinte garabatos sueltos.
		draw_line(e["a"], e["b"], Color(1, 1, 1, 0.25 * alfa), 14.0)
	draw_polyline(zig, Color(col.r, col.g, col.b, 0.30 * alfa), g, true)
	draw_polyline(zig, Color(col.r, col.g, col.b, alfa), maxf(1.5, g * 0.45), true)
	draw_polyline(zig, Color(1, 1, 1, 0.9 * alfa), maxf(1.0, g * 0.18), true)


# El camino del rayo, con el desvio lateral al azar. Los extremos van CLAVADOS (nacen en el
# lanzador y mueren en la victima); lo que baila es el medio.
func _nuevo_zigzag(e: Dictionary) -> PackedVector2Array:
	var a: Vector2 = e["a"]
	var b: Vector2 = e["b"]
	var pts := PackedVector2Array()
	var curva: bool = bool(e.get("curva", false))
	var n: int = 9 if curva else clampi(int(a.distance_to(b) / 34.0), 5, 14)
	var amp: float = 18.0 * clampf(float(e["r"]) / 12.0, 0.5, 1.5)
	for i in n:
		var u: float = float(i) / float(n - 1)
		var p: Vector2
		var tang: Vector2
		if curva:
			# Rebote que vuelve al MISMO objetivo: Bezier cuadratica que sale, sube y vuelve.
			var c: Vector2 = e["ctrl"]
			p = a.lerp(c, u).lerp(c.lerp(b, u), u)
			tang = (c - a).normalized() if u < 0.5 else (b - c).normalized()
		else:
			p = a.lerp(b, u)
			tang = (b - a).normalized() if a.distance_to(b) > 1.0 else Vector2.DOWN
		var lado := Vector2(-tang.y, tang.x)
		var desvio: float = 0.0 if i == 0 or i == n - 1 else randf_range(-0.5, 0.5) * amp
		pts.append(p + lado * desvio)
	return pts


# GOTAS que caen del cielo, cada una con su desfase, y salpican al llegar.
func _pintar_gotas(e: Dictionary) -> void:
	var b: Vector2 = e["b"]
	var col: Color = e["col"]
	var r: float = e["r"]
	var t: float = e["t"]
	var dur: float = e["dur"]
	var claro := Color(minf(1.0, col.r + 0.45), minf(1.0, col.g + 0.35), minf(1.0, col.b + 0.25), 0.95)
	for g in e["gotas"]:
		var dx: float = g[0]
		var retardo: float = float(g[1]) * dur
		var u: float = clampf((t - retardo) / maxf(dur - retardo, 0.01), 0.0, 1.0)
		if t < retardo:
			continue
		var destino: Vector2 = b + Vector2(dx, 0.0)
		if u < 1.0:
			# Cae acelerando, desde el techo.
			var p: Vector2 = Vector2(destino.x, lerpf(FUERA, destino.y, u * u))
			var largo: float = r * 0.9
			draw_colored_polygon(PackedVector2Array([
				p + Vector2(0.0, -largo),
				p + Vector2(r * 0.28, 0.0),
				p + Vector2(0.0, largo * 0.45),
				p + Vector2(-r * 0.28, 0.0),
			]), Color(col.r, col.g, col.b, 0.85))
			draw_line(p + Vector2(0.0, -largo), p, claro, 2.0, true)
		else:
			# SALPICADURA: dos arcos cortos que se abren a los lados y se apagan.
			var v: float = clampf((t - retardo - (dur - retardo)) / 0.12, 0.0, 1.0)
			var rad: float = r * (0.4 + 1.6 * v)
			var c := Color(col.r, col.g, col.b, 1.0 - v)
			draw_arc(destino, rad, PI * 1.15, PI * 1.45, 8, c, 2.0, true)
			draw_arc(destino, rad, -PI * 0.45, -PI * 0.15, 8, c, 2.0, true)


# OLA: un FRENTE ancho, no una gota. Todas las magias de agua sin dispersion son de area (Rocío
# moja a todos, Torrente arrasa a todos), asi que lo que tiene que verse venir es una lamina.
#
# 'ancho' es el ancho DEL FRENTE ENTERO, no el de una tarjeta: CombatFX._marcar_olas deja UNA sola
# ola por tanda y le pasa la medida de todo lo que barre (ver alli el porque). Antes se pintaba una
# ola por victima y del ancho de su tarjeta, asi que un Rocío a cuatro salian cuatro olitas en fila
# -- que es justo lo contrario de un barrido.
#
# El +10 es un poco de rebose por los lados: una ola que muere exactamente en el borde de la ultima
# tarjeta parece recortada.
func _pintar_ola(e: Dictionary) -> void:
	var a: Vector2 = e["a"]
	var b: Vector2 = e["b"]
	var col: Color = e["col"]
	var t: float = e["t"]
	var u: float = clampf(t / float(e["dur"]), 0.0, 1.0)
	var dir: Vector2 = (b - a).normalized() if a.distance_to(b) > 1.0 else Vector2.DOWN
	var lado := Vector2(-dir.y, dir.x)
	var p: Vector2 = a.lerp(b, u)
	var ancho: float = maxf(40.0, float(e["ancho"]) * 0.5 + 10.0)
	var fondo: float = float(e["r"]) * 0.9
	var alfa: float = 1.0 if u < 1.0 else clampf(1.0 - (t - float(e["dur"])) / 0.12, 0.0, 1.0)

	var pts := PackedVector2Array()
	var n := 7
	for i in n:
		var k: float = float(i) / float(n - 1)
		var x: float = lerpf(-1.0, 1.0, k)
		var avance: float = (1.0 - x * x) * fondo * (1.0 + 0.18 * sin(t * 11.0 + k * 5.0 + float(e["semilla"])))
		pts.append(p + lado * x * ancho + dir * avance)
	for i in n:
		var k2: float = 1.0 - float(i) / float(n - 1)
		var x2: float = lerpf(-1.0, 1.0, k2)
		var cola: float = -fondo * (0.55 + 0.45 * (1.0 - absf(x2)))
		pts.append(p + lado * x2 * ancho * 0.82 + dir * cola)
	draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.85 * alfa))
	# La CRESTA, mas clara y fina: es lo que la lee como agua y no como una mancha azul.
	var cresta := PackedVector2Array()
	for i in n:
		cresta.append(pts[i])
	draw_polyline(cresta, Color(minf(1.0, col.r + 0.45), minf(1.0, col.g + 0.35),
		minf(1.0, col.b + 0.25), 0.95 * alfa), maxf(2.0, float(e["r"]) * 0.18), true)


# EXPLOSION: no viaja, REVIENTA donde esta. Es lo que se lleva el SALPICON de las magias de fuego:
# la bola vuela hasta el objetivo principal y ahi estalla, y a los de al lado los alcanza la ONDA,
# no una segunda bola. Antes el salpicon se pintaba con el mismo estilo que el golpe principal, asi
# que Brasa y Andanada parecian tres bolas lanzadas a la vez en vez de una que revienta.
#
# Una onda que se abre y se apaga, un nucleo que se encoge y unas lenguas hacia fuera.
func _pintar_explosion(e: Dictionary) -> void:
	var b: Vector2 = e["b"]
	var col: Color = e["col"]
	# El tamaño sale de LO QUE ABARCA (ver _radio_grupo): una explosion que alcanza a tres es UNA
	# grande, no tres petardos. El 0.30 la deja algo mas chica que el vortice: una onda se lee bien
	# aunque no tape del todo, y asi no se come la pantalla en 1v1.
	var r: float = _radio_grupo(e, 0.30, 11.0)
	var t: float = e["t"]
	# La explosion vive MAS que su vuelo: el 'dur' es lo que tarda en llegar el impacto, y la onda
	# sigue abriendose despues. Se apaga sola con 'u'.
	var u: float = clampf(t / maxf(float(e["dur"]) + 0.22, 0.05), 0.0, 1.0)
	if u >= 1.0:
		return
	var claro := Color(minf(1.0, col.r + 0.45), minf(1.0, col.g + 0.3), minf(1.0, col.b + 0.15), 1.0)
	# ONDA: un anillo que se abre rapido al principio y se frena (1 - (1-u)^2), y que adelgaza.
	var rad: float = r * (0.5 + 2.6 * (1.0 - pow(1.0 - u, 2.0)))
	draw_arc(b, rad, 0.0, TAU, 28, Color(claro.r, claro.g, claro.b, 0.9 * (1.0 - u)),
		maxf(1.5, r * 0.30 * (1.0 - u)), true)
	# NUCLEO: empieza gordo y se consume.
	var nr: float = r * 1.15 * (1.0 - u)
	if nr > 0.5:
		draw_circle(b, nr, Color(col.r, col.g, col.b, 0.85 * (1.0 - u)))
		draw_circle(b, nr * 0.55, Color(claro.r, claro.g, claro.b, 0.9 * (1.0 - u)))
	# LENGUAS: seis chorros cortos hacia fuera, con la semilla para que dos explosiones seguidas no
	# salgan calcadas.
	var g: float = float(e["semilla"])
	for i in 6:
		var ang: float = g + TAU * float(i) / 6.0
		var dir := Vector2(cos(ang), sin(ang))
		var d0: float = rad * 0.55
		var d1: float = rad * (0.95 + 0.25 * sin(g * 3.0 + float(i)))
		draw_line(b + dir * d0, b + dir * d1,
			Color(claro.r, claro.g, claro.b, 0.75 * (1.0 - u)), maxf(1.5, r * 0.18), true)


# ============================================================
#  LOS DE LOS ENEMIGOS (ver CombatFX.Estilo, del 9 en adelante)
# ============================================================

# SPLAT: EL BICHO SALTA ENCIMA. UN SOLO cuerpo, gordo y redondo, que sale DE SU TARJETA, describe un
# salto y aterriza aplastando a todos los que pille debajo. Es el Reventon del slime y el
# Aplastamiento del Rey.
#
# DOS COSAS QUE SON EL 90% DE QUE FUNCIONE:
#  1. Es UNO, no uno por victima. De eso se encarga CombatFX._marcar_efectos_de_grupo, que deja una
#     sola portadora por tanda. Antes caian tres bolas sueltas sobre tres tarjetas, que es
#     justamente lo que no pasa cuando un bicho enorme te salta encima.
#  2. SALE DEL BICHO, no del cielo. Un salto tiene origen; una piedra que cae del techo, no. Por eso
#     'a' se queda siendo la tarjeta del atacante (no se toca en alta()) y aqui se dibuja el arco.
#
# El tamaño sale de 'ancho' (lo que abarca el grupo alcanzado), no del peso: si aplasta a cuatro
# tiene que TAPARLOS a los cuatro, o el dibujo estaria mintiendo sobre a quien pega.
func _pintar_splat(e: Dictionary) -> void:
	var a: Vector2 = e["a"]
	var b: Vector2 = e["b"]
	var col: Color = e["col"]
	var t: float = e["t"]
	var dur: float = float(e["dur"])
	# Radio del cuerpo: la mitad de lo que abarca, con un suelo para que en 1v1 siga siendo gordo.
	var r: float = maxf(26.0, float(e["ancho"]) * 0.5)
	var claro := Color(minf(1.0, col.r + 0.3), minf(1.0, col.g + 0.3), minf(1.0, col.b + 0.3), 1.0)
	if t < dur:
		# EL SALTO: va de su tarjeta a donde aterriza, subiendo por el camino. La altura sale de la
		# distancia, y el ARRANQUE es lento y la caida rapida (u*u), que es como cae un cuerpo.
		var u: float = clampf(t / maxf(dur, 0.01), 0.0, 1.0)
		var p: Vector2 = a.lerp(b, u)
		p.y -= sin(u * PI) * minf(150.0, a.distance_to(b) * 0.45 + 60.0)
		# Se encoge al despegar y se estira al caer: da el peso. Redondo por las dos mitades (aun
		# no toca nada), y se dibuja apoyado en su parte baja para que el aterrizaje no de un salto.
		var estira: float = 0.85 + 0.5 * u
		_masa(p + Vector2(0.0, r * estira), r / estira, r * estira, r * estira, col, claro, 0.95)
		return
	# APLASTADO. La clave: NO se encoge entero, SE CHAFA CONTRA EL SUELO. Primero se aplana la parte
	# de ABAJO (que es la que toca) mientras arriba sigue siendo una cupula redonda, y la masa se
	# escurre hacia los LADOS. Solo despues empieza a bajar el techo.
	var v: float = clampf((t - dur) / 0.34, 0.0, 1.0)
	# Abajo se chafa deprisa: a un tercio del golpe ya esta plano contra el suelo.
	var abajo: float = r * maxf(0.0, 1.0 - v * 3.0)
	# Arriba aguanta redondo bastante mas: es lo que lo mantiene con forma de slime y no de tortita.
	var arriba: float = r * (1.0 - 0.55 * v)
	# Y lo que no cabe a lo alto sale a lo ancho.
	var ancho: float = r * (1.0 + 0.6 * v)
	var alfa: float = 1.0 - v
	if arriba > 0.5:
		_masa(b, ancho, arriba, abajo, col, claro, 0.92 * alfa)
	# ONDA de impacto: un anillo bajo y ancho que se abre por el suelo. Es lo que dice "esto ha
	# pegado a TODO lo de aqui debajo" mejor que la propia mancha.
	var ro: float = r * (1.0 + 1.1 * v)
	draw_arc(b, ro, 0.0, TAU, 30, Color(claro.r, claro.g, claro.b, 0.55 * alfa),
		maxf(2.0, r * 0.10 * (1.0 - v)), true)
	# Y las GOTAS que saltan al reventar, para que no sea una tortita limpia.
	for i in 7:
		var ang: float = float(e["semilla"]) + TAU * float(i) / 7.0
		var dir := Vector2(cos(ang), -absf(sin(ang)) * 0.7)
		draw_circle(b + dir * ancho * (0.8 + 0.55 * v), maxf(1.5, r * 0.11 * (1.0 - v)),
			Color(col.r, col.g, col.b, 0.8 * alfa))


# EL RADIO DE UN EFECTO QUE CUBRE A VARIOS. 'ancho' es lo que abarca el grupo alcanzado (lo pone
# CombatFX._marcar_efectos_de_grupo en la portadora); 'k' es cuanto de eso ocupa este dibujo y
# 'suelo' el minimo para que en 1v1 siga viendose gordo.
#
# Se saca del ANCHO y no del peso del golpe a proposito: el dibujo tiene que tapar justo a quien
# pega. Si el tamaño saliera del daño, un area floja se veria pequeña aunque alcanzara a cuatro, y
# la animacion estaria mintiendo sobre a quien toca.
func _radio_grupo(e: Dictionary, k: float, suelo: float) -> float:
	return maxf(maxf(suelo, float(e["r"])), float(e["ancho"]) * k)


# UNA MASA CON LAS DOS MITADES INDEPENDIENTES: 'arriba' y 'abajo' son los radios verticales de la
# mitad de arriba y la de abajo, y 'apoyo' es el punto donde toca el suelo.
#
# Es lo que permite que un slime se aplaste COMO SE APLASTA de verdad: la parte de abajo se chafa
# contra el suelo primero (abajo -> 0) mientras la de arriba sigue siendo una cupula redonda, y solo
# despues se va bajando el techo. Con una elipse normal -las dos mitades iguales- lo unico que se
# puede hacer es encogerla entera, y eso parece una bola que se desinfla, no algo que se estampa.
#
# El punto de APOYO no se mueve en todo el aplastamiento: la masa crece hacia los lados y hacia
# arriba, nunca hacia abajo. Si se dibujara centrada, al ensancharse se hundiria en el suelo.
func _masa(apoyo: Vector2, rx: float, arriba: float, abajo: float,
		col: Color, claro: Color, alfa: float) -> void:
	var centro: Vector2 = apoyo - Vector2(0.0, abajo)
	var pts := PackedVector2Array()
	var n := 22
	for i in n:
		var ang: float = TAU * float(i) / float(n)
		var y: float = sin(ang)
		# El radio vertical cambia segun se este dibujando la mitad de arriba o la de abajo.
		pts.append(centro + Vector2(cos(ang) * rx, -y * (arriba if y > 0.0 else abajo)))
	draw_colored_polygon(pts, Color(col.r, col.g, col.b, alfa))
	# El brillo, arriba a la izquierda: es lo que le da volumen de gelatina.
	draw_circle(centro + Vector2(-rx * 0.32, -arriba * 0.42),
		maxf(1.0, minf(rx, maxf(arriba, 1.0)) * 0.3),
		Color(claro.r, claro.g, claro.b, 0.5 * alfa))


# Una masa gelatinosa: elipse rellena + brillo arriba. La usan el splat y el escupitajo.
func _blob(p: Vector2, rx: float, ry: float, col: Color, claro: Color, alfa: float) -> void:
	var pts := PackedVector2Array()
	var n := 16
	for i in n:
		var k: float = TAU * float(i) / float(n)
		pts.append(p + Vector2(cos(k) * rx, sin(k) * ry))
	draw_colored_polygon(pts, Color(col.r, col.g, col.b, alfa))
	# El brillo va ARRIBA A LA IZQUIERDA siempre: es lo que le da volumen y lo separa de una mancha.
	draw_circle(p + Vector2(-rx * 0.3, -ry * 0.35), maxf(1.0, minf(rx, ry) * 0.32),
		Color(claro.r, claro.g, claro.b, 0.55 * alfa))


# ESCUPITAJO: una bola pequeña con PARABOLA. No va en linea recta como el proyectil de fuego: sube
# y cae, que es lo que hace que se lea como algo escupido y no como algo lanzado con puntería.
# Al llegar deja un goteron que se escurre.
func _pintar_escupitajo(e: Dictionary) -> void:
	var a: Vector2 = e["a"]
	var b: Vector2 = e["b"]
	var col: Color = e["col"]
	var r: float = e["r"] * 0.7   # pequeño a proposito: la Rociada son DOS de estos
	var t: float = e["t"]
	var dur: float = float(e["dur"])
	var claro := Color(minf(1.0, col.r + 0.3), minf(1.0, col.g + 0.3), minf(1.0, col.b + 0.3), 1.0)
	var u: float = clampf(t / maxf(dur, 0.01), 0.0, 1.0)
	if u < 1.0:
		# PARABOLA: interpolacion recta + una campana hacia arriba. La altura sale de la distancia,
		# asi que un escupitajo corto no hace un arco absurdo.
		var p: Vector2 = a.lerp(b, u)
		var alto: float = minf(70.0, a.distance_to(b) * 0.32)
		p.y -= sin(u * PI) * alto
		# Se aplasta un poco en la direccion de marcha (como una gota en el aire).
		_blob(p, r * 1.15, r * 0.85, col, claro, 0.92)
		# Estela de gotitas detras, que es lo que lo hace baboso.
		for i in 3:
			var ur: float = u - 0.07 * float(i + 1)
			if ur <= 0.0:
				continue
			var q: Vector2 = a.lerp(b, ur)
			q.y -= sin(ur * PI) * alto
			draw_circle(q, maxf(1.0, r * (0.4 - 0.1 * float(i))),
				Color(col.r, col.g, col.b, 0.4 - 0.1 * float(i)))
		return
	# IMPACTO: se abre y se escurre hacia abajo.
	var v: float = clampf((t - dur) / 0.22, 0.0, 1.0)
	var alfa: float = 1.0 - v
	_blob(b, r * (1.0 + 1.3 * v), r * (1.0 - 0.4 * v), col, claro, 0.85 * alfa)
	draw_line(b, b + Vector2(0.0, r * 1.8 * v), Color(col.r, col.g, col.b, 0.6 * alfa),
		maxf(1.0, r * 0.35), true)


# AURA: el bicho se enciende A SI MISMO. No viaja: se queda en su tarjeta, latiendo. Es la Ignicion
# del slime de fuego (y vale para cualquier buff: Caparazon, Muralla, Endurecerse).
func _pintar_aura(e: Dictionary) -> void:
	var b: Vector2 = e["b"]
	var col: Color = e["col"]
	var r: float = e["r"]
	var t: float = e["t"]
	# Vive bastante mas que su "vuelo": un buff tiene que lucir.
	var u: float = clampf(t / maxf(float(e["dur"]) + 0.55, 0.05), 0.0, 1.0)
	if u >= 1.0:
		return
	var claro := Color(minf(1.0, col.r + 0.4), minf(1.0, col.g + 0.35), minf(1.0, col.b + 0.2), 1.0)
	# Entra deprisa y se va despacio, para que se vea el estallido inicial.
	var alfa: float = (u / 0.18) if u < 0.18 else (1.0 - (u - 0.18) / 0.82)
	var g: float = float(e["semilla"])
	# LENGUAS que suben, repartidas alrededor y ondeando. Son lo que lo lee como fuego y no como
	# un circulo de color.
	for i in 10:
		var ang: float = g + TAU * float(i) / 10.0
		var onda: float = sin(t * 9.0 + float(i) * 1.7)
		var largo: float = r * (1.5 + 0.5 * onda)
		var base: Vector2 = b + Vector2(cos(ang) * r * 1.25, sin(ang) * r * 0.75)
		var punta: Vector2 = base + Vector2(onda * r * 0.35, -largo)
		draw_line(base, punta, Color(claro.r, claro.g, claro.b, 0.55 * alfa),
			maxf(1.5, r * 0.22), true)
	# Y un halo pegado al cuerpo, que late.
	draw_arc(b, r * (1.5 + 0.12 * sin(t * 7.0)), 0.0, TAU, 26,
		Color(col.r, col.g, col.b, 0.45 * alfa), maxf(2.0, r * 0.3), true)


# VORTICE: una espiral que se CIERRA sobre la victima. Es lo del abismo: no te golpea, te succiona.
# Brazos que giran hacia dentro y un nucleo negro que se traga la luz.
func _pintar_vortice(e: Dictionary) -> void:
	var b: Vector2 = e["b"]
	var col: Color = e["col"]
	# Igual que la explosion: si se traga a tres, es UN remolino ancho. Los brazos ya se abren a
	# 3 x r, asi que el factor va bajo (0.17) para que con cuatro objetivos no salga de la pantalla.
	var r: float = _radio_grupo(e, 0.17, 8.0)
	var t: float = e["t"]
	var u: float = clampf(t / maxf(float(e["dur"]) + 0.35, 0.05), 0.0, 1.0)
	if u >= 1.0:
		return
	var alfa: float = 1.0 - u * u
	var claro := Color(minf(1.0, col.r + 0.5), minf(1.0, col.g + 0.5), minf(1.0, col.b + 0.55), 1.0)
	# Los brazos se cierran: el radio exterior encoge segun avanza.
	var rad: float = r * (3.0 - 1.9 * u)
	var giro: float = float(e["semilla"]) + t * 5.5
	# Cinco brazos, cada uno una polilinea que va enroscandose hacia el centro.
	for i in 5:
		var pts := PackedVector2Array()
		var base_ang: float = giro + TAU * float(i) / 5.0
		for j in 9:
			var k: float = float(j) / 8.0
			# El angulo crece con k: eso es lo que lo curva (una espiral, no un radio recto).
			var ang: float = base_ang + k * 2.1
			var d: float = rad * (1.0 - k * 0.85)
			pts.append(b + Vector2(cos(ang) * d, sin(ang) * d * 0.72))
		draw_polyline(pts, Color(claro.r, claro.g, claro.b, 0.5 * alfa), maxf(1.5, r * 0.16), true)
	# NUCLEO: negro de verdad, que es lo que le da el fondo de pozo.
	var nr: float = rad * 0.30
	draw_circle(b, nr, Color(0.02, 0.01, 0.05, 0.85 * alfa))
	draw_arc(b, nr, 0.0, TAU, 22, Color(col.r, col.g, col.b, 0.7 * alfa), maxf(1.5, r * 0.2), true)


# ARRASTRE: el bicho embiste (de eso se encarga CombatFX) y SE LLEVA UNA LLAMA por delante. La
# Llamarada del slime de fuego no se lanza: le sale el fuego encima y avanza con el.
#
# Se dibuja a lo largo del trayecto a->b, que es el mismo que recorre su tarjeta al embestir.
func _pintar_arrastre(e: Dictionary) -> void:
	var a: Vector2 = e["a"]
	var b: Vector2 = e["b"]
	var col: Color = e["col"]
	var r: float = e["r"]
	var t: float = e["t"]
	var dur: float = float(e["dur"])
	var claro := Color(minf(1.0, col.r + 0.45), minf(1.0, col.g + 0.35), minf(1.0, col.b + 0.1), 1.0)
	var u: float = clampf(t / maxf(dur, 0.01), 0.0, 1.0)
	var fin: float = clampf((t - dur) / 0.20, 0.0, 1.0)
	var alfa: float = 1.0 if u < 1.0 else 1.0 - fin
	if alfa <= 0.0:
		return
	var p: Vector2 = a.lerp(b, minf(u, 1.0))
	var g: float = float(e["semilla"])
	# CUANTO ABARCA A LO ANCHO. Es la diferencia entre la Llamarada (uno solo: una lengua estrecha
	# que va con el bicho) y la Combustion (area: el slime se pone al rojo y ARRASA de lado a lado).
	# Sale de lo alcanzado, no del daño, por lo mismo que en _radio_grupo.
	var media: float = maxf(r * 1.6, float(e["ancho"]) * 0.42)
	var dir: Vector2 = (b - a).normalized() if a.distance_to(b) > 1.0 else Vector2.RIGHT
	var lado := Vector2(-dir.y, dir.x)
	# Mas lenguas cuanto mas ancho, o al ensanchar quedaban cuatro pelos sueltos y se veia el hueco.
	var n: int = clampi(int(media / 14.0), 7, 26)
	for i in n:
		var k: float = float(i) / float(n - 1) - 0.5
		var onda: float = sin(t * 16.0 + float(i) * 1.3 + g)
		# Las de los bordes son mas cortas: le da forma de frente de fuego y no de peine.
		var perfil: float = 1.0 - 0.45 * absf(k) * 2.0
		var largo: float = r * (1.3 + 0.6 * onda) * maxf(0.35, perfil)
		var base: Vector2 = p + lado * k * media * 2.0
		draw_line(base, base + dir * largo + lado * onda * r * 0.25,
			Color(claro.r, claro.g, claro.b, 0.7 * alfa), maxf(1.5, r * 0.26), true)
	# Nucleo caliente pegado al bicho. Se estira a lo ancho con el frente.
	var pts := PackedVector2Array()
	for i in 14:
		var ang: float = TAU * float(i) / 14.0
		pts.append(p + lado * cos(ang) * media * 0.7 + dir * sin(ang) * r * 0.75)
	draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.7 * alfa))


# SIN ELEMENTO: un rombo girando dentro de un anillo. Se lee como "magia" sin tirar de ningun
# color elemental, que es justo lo que es un Pulso.
func _pintar_arcano(e: Dictionary) -> void:
	var a: Vector2 = e["a"]
	var b: Vector2 = e["b"]
	var col: Color = e["col"]
	var t: float = e["t"]
	var u: float = clampf(t / float(e["dur"]), 0.0, 1.0)
	var p: Vector2 = a.lerp(b, u * u)
	var alfa: float = 1.0 if u < 1.0 else clampf(1.0 - (t - float(e["dur"])) / 0.12, 0.0, 1.0)
	var g: float = t * 3.2 + float(e["semilla"])
	var r: float = float(e["r"]) * (1.0 + 0.08 * sin(t * 7.0)) * (1.0 + 1.5 * (1.0 - alfa))
	var eje := Vector2(cos(g), sin(g))
	var lado := Vector2(-eje.y, eje.x)
	draw_colored_polygon(PackedVector2Array([
		p + eje * r, p + lado * r * 0.55, p - eje * r, p - lado * r * 0.55,
	]), Color(col.r, col.g, col.b, alfa))
	draw_arc(p, r * 1.25, 0.0, TAU, 24, Color(col.r, col.g, col.b, 0.5 * alfa), 2.0, true)


# ============================================================
#  MORDISCOS
# ============================================================
# DOS HILERAS DE DIENTES QUE SE CIERRAN sobre la tarjeta de la victima. Lo que distingue a un bicho
# que muerde de uno que pega es la BOCA, asi que es lo que se dibuja: no un impacto generico teñido
# de otro color, sino la dentellada concreta de ese bicho.
#
# EL COLOR DEL BICHO NO SE USA para el diente. Lo demas de la capa tiñe con 'col' (que sale de
# combat.gd._color_golpe: el elemento o, si no lo hay, el color del propio enemigo), pero una rata
# es marron y una dentellada marron sobre una tarjeta no se lee. El diente va en HUESO y la marca en
# SANGRE, que ademas es la firma de la familia entera: aqui todo lo que muerde hace sangrar.
#
# El PERFIL es la tabla de dientes de una hilera; cada diente es
#     [off_x, semiancho, largo, inclinacion, punta]
# donde off_x va de -1 a 1 sobre la MEDIA boca, 'semiancho' es lo que sobresale a CADA lado (o sea
# medio diente: dos dientes se tocan cuando sus off_x distan la suma de sus semianchos), 'largo' es
# fraccion del maximo, la inclinacion desvia la punta hacia un lado (fraccion del largo) y 'punta'
# va de 0 = punta PLANA (el paleto de un roedor) a 1 = punta afilada (el colmillo de una fiera).
#
# La irregularidad de las fauces esta ESCRITA EN LA TABLA y no sacada de randf(): _draw puede
# correr varias veces en el mismo frame (ver la cabecera del fichero), asi que un colmillo con el
# largo aleatorio no seria "irregular", seria un diente vibrando.

# ROEDOR: dos PALETOS anchos de punta recta que dominan la boca, y dientecitos parejos a los lados.
const _P_PALETOS_ARRIBA := [
	[-0.165, 0.160, 1.00, 0.0, 0.05], [0.165, 0.160, 1.00, 0.0, 0.05],
	[-0.44, 0.070, 0.34, 0.0, 0.35], [0.44, 0.070, 0.34, 0.0, 0.35],
	[-0.60, 0.065, 0.28, 0.0, 0.35], [0.60, 0.065, 0.28, 0.0, 0.35],
	[-0.75, 0.060, 0.22, 0.0, 0.40], [0.75, 0.060, 0.22, 0.0, 0.40],
]
const _P_PALETOS_ABAJO := [
	[-0.145, 0.140, 0.72, 0.0, 0.08], [0.145, 0.140, 0.72, 0.0, 0.08],
	[-0.40, 0.065, 0.28, 0.0, 0.35], [0.40, 0.065, 0.28, 0.0, 0.35],
	[-0.56, 0.060, 0.24, 0.0, 0.35], [0.56, 0.060, 0.24, 0.0, 0.35],
	[-0.71, 0.055, 0.20, 0.0, 0.40], [0.71, 0.055, 0.20, 0.0, 0.40],
]

# FIERA: colmillos largos en los extremos curvados hacia DENTRO, y dientes cortos e irregulares en
# medio. Los numeros estan desparejados a proposito (-0.84 contra 0.86, -0.19 contra 0.21): la
# simetria perfecta hacia que pareciera un peine en vez de una boca.
const _P_FAUCES_ARRIBA := [
	[-0.86, 0.095, 1.00, 0.09, 0.92], [0.88, 0.090, 0.96, -0.10, 0.92],
	[-0.63, 0.080, 0.74, 0.05, 0.88], [0.65, 0.085, 0.80, -0.06, 0.88],
	[-0.42, 0.070, 0.50, 0.02, 0.80], [0.44, 0.065, 0.46, -0.02, 0.80],
	[-0.21, 0.070, 0.62, 0.0, 0.85], [0.23, 0.075, 0.56, 0.0, 0.85],
	[0.01, 0.065, 0.44, 0.0, 0.78],
]
const _P_FAUCES_ABAJO := [
	[-0.88, 0.090, 0.92, 0.08, 0.92], [0.86, 0.095, 0.98, -0.09, 0.92],
	[-0.66, 0.080, 0.70, 0.05, 0.88], [0.63, 0.080, 0.76, -0.05, 0.88],
	[-0.33, 0.065, 0.42, 0.0, 0.80], [0.35, 0.065, 0.46, 0.0, 0.80],
	[-0.11, 0.060, 0.38, 0.0, 0.78], [0.13, 0.060, 0.40, 0.0, 0.78],
]

const _HUESO := Color(0.96, 0.94, 0.87)
const _ENCIA := Color(0.10, 0.03, 0.05)     # el contorno, para que el diente se lea sobre cualquier fondo
const _SANGRE := Color(0.72, 0.06, 0.08)


func _pintar_mordisco(e: Dictionary) -> void:
	_dentellada(e, _P_PALETOS_ARRIBA, _P_PALETOS_ABAJO, 1.0, 1.0)


func _pintar_colmillazo(e: Dictionary) -> void:
	# Fauces mas anchas y que cierran mas despacio: una mandibula grande pesa.
	_dentellada(e, _P_FAUCES_ARRIBA, _P_FAUCES_ABAJO, 1.35, 1.25)


# LA YUGULAR SIGUE SIENDO UNA RATA: muerde con paletos, no con colmillos. Lo que la separa de las
# otras dentelladas no es la boca, es que va a UN SOLO SITIO y con todo -- y eso lo dice el destello.
func _pintar_yugular(e: Dictionary) -> void:
	var v: float = _dentellada(e, _P_PALETOS_ARRIBA, _P_PALETOS_ABAJO, 1.15, 0.85)
	if v >= 0.0:
		_destello(e, v, Color(0.90, 0.10, 0.12), Color(1.0, 0.55, 0.48))


# PONZOÑA: el mordisco de la araña. Muerde con las FAUCES (quelíceros, no los paletos de un roedor)
# y el destello sale VERDE en vez de rojo: no es que te desangre, es que te ha metido veneno.
func _pintar_ponzona(e: Dictionary) -> void:
	var v: float = _dentellada(e, _P_FAUCES_ARRIBA, _P_FAUCES_ABAJO, 1.0, 0.9)
	if v >= 0.0:
		# Mas pequeño que el de la yugular (el 0.62): aquella es UN golpe y este son dos o tres
		# picaduras seguidas, asi que a tamaño completo se comia la pantalla tres veces por turno.
		_destello(e, v, Color(0.35, 0.85, 0.20), Color(0.80, 1.0, 0.55), 0.62)


# Pinta la mordida entera. Devuelve el avance DESPUES del cierre (0 = acaba de morder, 1 = se ha
# ido del todo) o -1 mientras las fauces todavia se estan abriendo, que es lo que usa la yugular
# para saber cuando soltar el destello.
func _dentellada(e: Dictionary, arriba: Array, abajo: Array, escala: float, lentitud: float) -> float:
	var b: Vector2 = e["b"]
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	# La boca se ajusta a la TARJETA que muerde y no al daño: un mordisco tapa una cara. (Los
	# mordiscos no son estilos de grupo, asi que 'ancho' es el ancho de esa victima, no el del grupo.)
	var boca: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0) * escala
	var media: float = boca * 0.5
	var largo_max: float = media * 0.85
	# CADA MORDISCO CAE DISTINTO. El Frenesi son seis dentelladas seguidas sobre las mismas caras: si
	# todas salieran con el mismo angulo y en el mismo sitio, las seis se leerian como un unico
	# dibujo parpadeando en vez de como seis bocados. La semilla las ladea hasta 26 grados para
	# cualquiera de los dos lados (pasando por el recto) y ademas las desplaza un poco.
	var g: float = float(e["semilla"])
	var ang: float = sin(g * 3.3) * 0.45
	var eje := Vector2(cos(ang), sin(ang))
	var lado := Vector2(-eje.y, eje.x)
	# El desvio va en el diccionario porque el destello de la yugular tiene que salir DEL MISMO
	# sitio que la mordida, no del centro de la tarjeta.
	b += Vector2(cos(g * 2.1), sin(g * 1.7)) * media * 0.18
	e["mordida_c"] = b
	var c: float = 0.0        # 0 = boca abierta de par en par, 1 = dientes tocandose
	var alfa: float = 1.0
	var v: float = -1.0
	if t < dur:
		# Abriendose mientras la tarjeta llega. Con un T_VUELO casi cero esto dura un parpadeo, pero
		# es lo que evita que las fauces aparezcan ya cerradas y el mordisco no se vea morder.
		alfa = clampf(t / maxf(dur, 0.01), 0.0, 1.0)
	else:
		v = clampf((t - dur) / (0.30 * lentitud), 0.0, 1.0)
		c = clampf(v / 0.30, 0.0, 1.0)   # cierra de golpe en el primer tercio
		# REBOTE de la mandibula: al llegar a tope afloja un pelin en vez de quedarse clavada.
		if v > 0.30 and v < 0.48:
			c = 1.0 - 0.14 * sin((v - 0.30) / 0.18 * PI)
		alfa = 1.0 if v < 0.55 else 1.0 - (v - 0.55) / 0.45
	if alfa <= 0.0:
		return v
	# Lo que separa las dos hileras: de abiertas del todo a cruzarse un poco al cerrar.
	# Abierta de par en par tiene que caber MAS DE UN DIENTE de hueco (1.75) o la boca no se ve
	# abrirse; pasado eso la mordida sale mas alta que la propia tarjeta y deja de leerse como algo
	# que le pasa AL BICHO. Al cerrar se cruzan muy poco (-0.05), o en vez de una mordida se lee
	# una cremallera.
	var sep: float = lerpf(largo_max * 1.75, -largo_max * 0.05, c)
	for d in arriba:
		_diente(b, eje, lado, media, largo_max, sep, d, true, alfa)
	for d in abajo:
		_diente(b, eje, lado, media, largo_max, sep, d, false, alfa)
	if v >= 0.0 and c > 0.85:
		_marca_mordida(b, eje, lado, media, largo_max, alfa)
	return v


func _diente(centro: Vector2, eje: Vector2, lado: Vector2, media: float, largo_max: float,
		sep: float, d: Array, es_arriba: bool, alfa: float) -> void:
	var dir: float = 1.0 if es_arriba else -1.0   # hacia donde CRECE el diente (+lado = hacia abajo)
	var x: float = float(d[0]) * media
	var w: float = float(d[1]) * media
	var largo: float = float(d[2]) * largo_max
	var incl: float = float(d[3]) * largo
	# LA MANDIBULA VA CURVADA. Una boca abre por el CENTRO: en las comisuras las dos hileras casi se
	# tocan aunque este abierta de par en par. Sin esto los dientes salian en dos lineas rectas
	# paralelas y el dibujo se leia como una reja, no como algo que muerde.
	var k: float = float(d[0])
	var y0: float = -dir * sep * 0.5 * (1.0 - 0.55 * k * k)
	var base: Vector2 = centro + eje * x + lado * y0
	var pta: Vector2 = centro + eje * (x + incl) + lado * (y0 + dir * largo)
	# Lo que convierte un paleto en un colmillo: cuanto se estrecha la punta.
	var w2: float = w * lerpf(0.78, 0.05, float(d[4]))
	var pts := PackedVector2Array([
		base - eje * w, base + eje * w, pta + eje * w2, pta - eje * w2,
	])
	draw_colored_polygon(pts, Color(_HUESO.r, _HUESO.g, _HUESO.b, alfa))
	# Contorno oscuro: sin el, un diente hueso sobre una tarjeta clara desaparece.
	pts.append(pts[0])
	draw_polyline(pts, Color(_ENCIA.r, _ENCIA.g, _ENCIA.b, 0.75 * alfa), maxf(1.0, w * 0.22), true)


# LO QUE DEJA la mordida: los dos agujeros por donde han entrado los dientes grandes y un hilo
# escurriendo de cada uno. Es lo que ata el dibujo a la mecanica -- toda esta familia sangra.
func _marca_mordida(centro: Vector2, eje: Vector2, lado: Vector2, media: float, largo_max: float,
		alfa: float) -> void:
	for s in [-1.0, 1.0]:
		var p: Vector2 = centro + eje * (0.13 * media * s)
		draw_circle(p, maxf(1.5, largo_max * 0.13),
			Color(_SANGRE.r, _SANGRE.g, _SANGRE.b, 0.9 * alfa))
		draw_line(p, p + lado * largo_max * 0.5,
			Color(_SANGRE.r, _SANGRE.g, _SANGRE.b, 0.55 * alfa), maxf(1.0, largo_max * 0.09), true)


# EL DESTELLO de la yugular: una estrella de cuatro puntas con los lados CONCAVOS, nucleo blanco
# quemado y halo rojo. Un flash redondo no valdria: lo que hay que leer es que este mordisco es EL
# golpe del Rey rata y no uno mas de una racha.
#
# EL COLOR VIENE DE FUERA. Lo llevaba escrito dentro (rojo) hasta que la araña pidio el suyo en
# verde: no es lo mismo desangrarse que envenenarse, y son la misma forma. 'tam' encoge el conjunto
# para los mordiscos que se repiten varias veces en un turno.
func _destello(e: Dictionary, v: float, fuera: Color, dentro: Color, tam: float = 1.0) -> void:
	# Del sitio EXACTO donde ha mordido (lo deja _dentellada), no del centro de la tarjeta: la
	# mordida va desplazada un poco al azar y el destello tiene que ir con ella.
	var b: Vector2 = e.get("mordida_c", e["b"])
	# Entra de golpe pasandose de tamaño y se apaga encogiendo.
	var k: float = (v / 0.14) if v < 0.14 else maxf(0.0, 1.0 - (v - 0.14) / 0.60)
	if k <= 0.0:
		return
	var pico: float = 1.0 if v >= 0.14 else 1.0 + 0.35 * (1.0 - v / 0.14)
	var r: float = clampf(float(e["ancho"]) * 0.55, 30.0, 92.0) * 1.25 * k * pico * tam
	_estrella(b, r * 1.60, r * 1.15, 0.42, Color(fuera.r, fuera.g, fuera.b, 0.80 * k))
	_estrella(b, r * 0.58, r * 0.40, 0.75, Color(dentro.r, dentro.g, dentro.b, 0.95 * k))
	_estrella(b, r * 0.28, r * 0.20, 1.30, Color(1.0, 0.97, 0.94, k))           # el nucleo quemado
	draw_circle(b, maxf(1.5, r * 0.10), Color(1.0, 1.0, 1.0, k))


# r(a) = R * (1 - |sin 2a|^p). En los cuatro ejes vale R (la punta) y en las diagonales cae a cero,
# asi que salen cuatro puntas; lo que hace el trabajo es 'p', el filo:
#   p bajo (~0.5)  cae a plomo nada mas salir del eje -> puntas larguisimas y finas, lados COMBADOS
#   p alto (~1.3)  aguanta ancho un rato antes de caer -> un cuerpo gordo con las puntas cortas
# Por eso el destello son TRES estrellas encajadas de p creciente: las agujas rojas de fuera, el
# cuerpo naranja y el nucleo blanco. Con una sola salia una cruz de brazos rectos y no brillaba.
func _estrella(c: Vector2, rx: float, ry: float, filo: float, col: Color) -> void:
	# DEMASIADO PEQUEÑA PARA DIBUJARLA. El suelo de 'f' de abajo es RELATIVO, asi que no salva este
	# caso: cuando el destello se apaga el radio tiende a cero y TODOS los vertices caen en el mismo
	# punto -> "Invalid polygon data, triangulation failed". Y a este tamaño no se ve nada igual.
	if rx < 1.0 or ry < 1.0:
		return
	var pts := PackedVector2Array()
	for i in 56:
		var a: float = TAU * float(i) / 56.0
		# SUELO en el radio. En las cuatro diagonales exactas f vale 0, y como 56 es multiplo de 8
		# esos angulos SALEN en el bucle: los cuatro vertices caian en el mismo punto (el centro) y
		# la triangulacion fallaba ("Invalid polygon data"), asi que no se pintaba nada.
		var f: float = maxf(1.0 - pow(absf(sin(a * 2.0)), filo), 0.02)
		pts.append(c + Vector2(cos(a) * rx * f, sin(a) * ry * f))
	draw_colored_polygon(pts, col)


# CHILLIDO: el unico de la familia que no muerde. Anillos que salen del que grita y BARREN la fila
# entera. Es estilo de grupo (ver _ESTILOS_DE_GRUPO): el Rey chilla UNA vez, no una por victima.
func _pintar_chillido(e: Dictionary) -> void:
	var a: Vector2 = e["a"]
	var b: Vector2 = e["b"]
	var col: Color = e["col"]
	var t: float = float(e["t"])
	var u: float = clampf(t / maxf(float(e["dur"]) + 0.34, 0.05), 0.0, 1.0)
	if u >= 1.0:
		return
	# Hasta donde tiene que llegar: la fila alcanzada entera y un margen. Sale del ancho del grupo
	# por lo mismo que _radio_grupo -- si alcanza a cuatro, la onda tiene que pasarles por encima.
	var alcance: float = a.distance_to(b) + maxf(40.0, float(e["ancho"]) * 0.6)
	var claro := Color(minf(1.0, col.r + 0.45), minf(1.0, col.g + 0.45), minf(1.0, col.b + 0.5), 1.0)
	# CUATRO anillos desfasados: uno solo se lee como una burbuja, varios como un sonido que insiste.
	for i in 4:
		var k: float = u - float(i) * 0.16
		if k <= 0.0 or k >= 1.0:
			continue
		var rad: float = alcance * k
		# Mas anchos que altos: una onda que recorre la fila, no una esfera que se infla.
		_anillo(a, rad * 1.15, rad * 0.72,
			Color(claro.r, claro.g, claro.b, 0.55 * (1.0 - k)), maxf(1.5, 5.0 * (1.0 - k)))
	# Y el pellizco en la garganta del que grita, que es de donde sale todo.
	var p: float = 1.0 - clampf(u / 0.3, 0.0, 1.0)
	if p > 0.0:
		draw_circle(a, 9.0 * p, Color(claro.r, claro.g, claro.b, 0.5 * p))


# ZARPAZO: cuatro surcos diagonales que se abren de golpe sobre la tarjeta. Lo que hay que leer no
# es "un golpe mas fuerte", es QUE TE HAN ABIERTO: por eso los surcos van en punta por los dos
# extremos (una garra entra y sale, no se para dentro) y con el borde dentado, no como cuatro rayas
# limpias.
#
# Igual que los mordiscos, cada zarpazo cae con SU angulo y en SU sitio: dos zarpazos seguidos sobre
# la misma cara con la misma inclinacion se leen como un dibujo repitiendose.
func _pintar_zarpazo(e: Dictionary) -> void:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var g: float = float(e["semilla"])
	# Diagonal de arriba-derecha a abajo-izquierda, con hasta 30 grados de desvio a cada lado.
	var ang: float = -PI / 3.0 + sin(g * 3.3) * 0.55
	var dir := Vector2(cos(ang), sin(ang))
	var lado := Vector2(-dir.y, dir.x)
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var centro: Vector2 = e["b"] + Vector2(cos(g * 2.1), sin(g * 1.7)) * caja * 0.12
	var v: float = 0.0
	var alfa: float = 1.0
	if t < dur:
		return   # la garra todavia viene con la tarjeta: aun no ha tocado
	v = clampf((t - dur) / 0.34, 0.0, 1.0)
	alfa = 1.0 if v < 0.5 else 1.0 - (v - 0.5) / 0.5
	if alfa <= 0.0:
		return
	for i in 4:
		# ESCALONADAS. Las cuatro garras no entran a la vez: entran barriendo, que es lo que hace
		# que se lea como una zarpa pasando y no como cuatro cortes que aparecen de golpe.
		var k: float = clampf((v - float(i) * 0.055) / 0.20, 0.0, 1.0)
		if k <= 0.0:
			continue
		# Las de los extremos, mas cortas y mas finas: una zarpa es un arco de dedos, no un peine.
		var perfil: float = 1.0 - 0.30 * absf(float(i) - 1.5) / 1.5
		var largo: float = caja * 1.45 * perfil
		# EN ABANICO, no en paralelo: los dedos de una zarpa se abren. Cuatro rayas exactamente
		# paralelas y a la misma distancia se leen como un rastrillo.
		var dir_i: Vector2 = dir.rotated((float(i) - 1.5) * 0.07)
		# SE TRAZA DE UNA PUNTA A LA OTRA, no crece desde el centro. Anclando el arranque y
		# alargando solo la otra punta se lee como una garra que arrastra; creciendo desde el medio
		# los surcos a medio hacer parecian munones y las cuatro salian descuadradas entre si.
		var eje: Vector2 = centro + lado * (float(i) - 1.5) * caja * 0.21 - dir_i * largo * 0.5
		_surco(eje + dir_i * largo * k * 0.5, dir_i, largo * k, caja * 0.11 * perfil,
			g + float(i) * 7.3, alfa)


# UN SURCO: un huso largo, gordo por el centro y en punta por los dos extremos, con el borde
# mordido. El dentado sale de la SEMILLA y del indice del punto, nunca de randf(): _draw puede
# correr varias veces en el mismo frame (ver la cabecera), y con azar de verdad el corte herviria.
#
# EL COLOR VIENE DE FUERA (por defecto hueso, que es el zarpazo). Un verdugon de latigo es ROJO en
# carne viva, no un tajo blanco, y es exactamente la misma forma: gordo por el medio y en punta por
# los dos extremos.
func _surco(c: Vector2, dir: Vector2, largo: float, semi: float, sem: float, alfa: float,
		col: Color = _HUESO) -> void:
	var lado := Vector2(-dir.y, dir.x)
	var n: int = 16
	var izq := PackedVector2Array()
	var der := PackedVector2Array()
	for i in n + 1:
		var s: float = float(i) / float(n)
		# Huso: el exponente alto del interior afila las puntas y el bajo de fuera mantiene gordo
		# el centro, que es el perfil de un corte de garra.
		var w: float = semi * pow(maxf(0.0, 1.0 - pow(absf(s - 0.5) * 2.0, 1.7)), 0.62)
		# Suelo minimo: si las dos orillas se juntaran en el mismo punto exacto saldrian vertices
		# duplicados y la triangulacion se cae (le paso a la estrella del destello).
		w = maxf(w, semi * 0.03)
		var r1: float = sin(sem + float(i) * 2.7) * 0.42 + sin(sem * 1.7 + float(i) * 5.1) * 0.22
		var r2: float = sin(sem * 2.3 + float(i) * 3.1) * 0.42 + sin(sem + float(i) * 6.7) * 0.22
		izq.append(c + dir * ((s - 0.5) * largo) + lado * w * (1.0 + r1))
		der.append(c + dir * ((s - 0.5) * largo) - lado * w * (1.0 + r2))
	var pts := PackedVector2Array()
	pts.append_array(izq)
	for i in range(der.size() - 1, -1, -1):
		pts.append(der[i])
	draw_colored_polygon(pts, Color(col.r, col.g, col.b, alfa))
	# La sangre va DENTRO y fina: manda el surco blanco. Con el hilo rojo gordo el corte se leia
	# como una raya roja con reborde en vez de como algo que te han abierto.
	draw_line(c - dir * largo * 0.34, c + dir * largo * 0.34,
		Color(_SANGRE.r, _SANGRE.g, _SANGRE.b, 0.40 * alfa), maxf(1.0, semi * 0.30), true)


# ============================================================
#  CUERPO A CUERPO DE LOS BICHOS GORDOS
# ============================================================
# El desvio de angulo/sitio de cada golpe sale de la SEMILLA, igual que en los mordiscos y el
# zarpazo: dos placajes seguidos sobre la misma cara con el dibujo calcado se leen como uno solo
# parpadeando. Devuelve [avance 0..1, alfa, centro desplazado] o un avance negativo si aun no toca.
func _golpe_cuerpo(e: Dictionary, coleta: float, desvio: float) -> Array:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	if t < dur:
		return [-1.0, 0.0, Vector2.ZERO]
	var g: float = float(e["semilla"])
	var v: float = clampf((t - dur) / coleta, 0.0, 1.0)
	var alfa: float = 1.0 if v < 0.55 else 1.0 - (v - 0.55) / 0.45
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	return [v, alfa, e["b"] + Vector2(cos(g * 2.1), sin(g * 1.7)) * caja * desvio]


# PLACAJE: el slime se estampa de lado y SE ESCURRE. No es el SPLAT (aquel cae de arriba y se
# chafa contra el suelo): aqui el cuerpo llega en horizontal, se aplasta contra la victima y la
# masa se le va a los lados, chorreando.
#
# Este SI va del color del bicho, al reves que los mordiscos: un slime es su color, y ademas hay
# seis distintos (verde, veneno, fuego, abisal...) que se distinguen justo por eso.
func _pintar_placaje(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, 0.32, 0.10)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var claro := Color(minf(1.0, col.r + 0.3), minf(1.0, col.g + 0.3), minf(1.0, col.b + 0.3), 1.0)
	var r: float = clampf(float(e["ancho"]) * 0.34, 20.0, 54.0)
	# Se chafa DEPRISA y se ensancha despues: primero el impacto, luego el escurrido.
	var chafa: float = clampf(v / 0.28, 0.0, 1.0)
	var ancho: float = r * (1.0 + 0.85 * chafa)
	var alto: float = r * (1.0 - 0.45 * chafa)
	# EL CUERPO, con el borde IRREGULAR. Una elipse limpia se leia como una pastilla verde; lo que
	# lo convierte en algo blando estampado son los lobulos del contorno, que ademas se marcan mas
	# segun se escurre (el 0.20 * chafa). Los bultos salen de la semilla, no de randf().
	var pts := PackedVector2Array()
	for i in 26:
		var ang: float = TAU * float(i) / 26.0
		var bulto: float = 1.0 + (0.10 + 0.20 * chafa) \
			* (sin(g * 1.7 + ang * 3.0) * 0.6 + sin(g + ang * 5.0) * 0.4)
		pts.append(b + Vector2(cos(ang) * ancho * bulto, sin(ang) * alto * bulto))
	draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.85 * alfa))
	# El brillo arriba a la izquierda: es lo que le da volumen de gelatina y no de mancha.
	draw_circle(b + Vector2(-ancho * 0.30, -alto * 0.38), maxf(1.5, minf(ancho, alto) * 0.30),
		Color(claro.r, claro.g, claro.b, 0.5 * alfa))
	# LOS GOTERONES que salpican al reventar. Salen mas hacia los lados que hacia arriba, que es
	# por donde escapa la masa cuando algo blando se estampa de frente.
	for i in 8:
		var ang: float = float(e["semilla"]) + TAU * float(i) / 8.0
		var d: Vector2 = Vector2(cos(ang) * 1.35, sin(ang) * 0.55)
		draw_circle(b + d * ancho * (0.75 + 0.7 * v), maxf(1.5, r * 0.15 * (1.0 - v)),
			Color(col.r, col.g, col.b, 0.8 * alfa))


# CORNADA: un cuerno que engancha DE ABAJO ARRIBA y levanta. Lo que la separa de un porrazo es el
# recorrido: entra bajo, sube y saca. Por eso el cuerno se dibuja como un arco que barre hacia
# arriba, y el desgarro se queda donde ha salido la punta.
func _pintar_cornada(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, 0.30, 0.10)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	# El barrido: de abajo (y positivo) a arriba, con el cuerno inclinado a un lado u otro.
	var k: float = clampf(v / 0.30, 0.0, 1.0)
	var ladeo: float = sin(g * 3.3) * 0.5
	var subida: float = caja * 1.25
	var punta: Vector2 = b + Vector2(ladeo * caja * 0.30, subida * (0.45 - k * 0.9))
	# EL CUERNO: un cono GRUESO y curvado. Se dibuja como una tira de cuadrilateros porque tiene
	# que combarse; con un huso recto se leia como una estaca clavada, no como un cuerno.
	# La base es ancha de verdad (0.26 de la caja): un cuerno fino es un pincho, y lo que tiene que
	# leerse aqui es la masa del bicho detras del golpe.
	var n: int = 14
	var izq := PackedVector2Array()
	var der := PackedVector2Array()
	for i in n + 1:
		var s: float = float(i) / float(n)          # 0 = punta, 1 = base del cuerno
		# Curvatura: cerca de la punta va casi recto y hacia la base se tuerce al lado del ladeo.
		var x: float = ladeo * caja * 0.55 * s * s
		var y: float = subida * 0.80 * s
		# Cono con la cintura llena: el (1-s^1.6) engorda el cuerpo y deja la punta afilada.
		var w: float = caja * 0.26 * (1.0 - pow(s, 1.6)) * (0.35 + 0.65 * s)
		w = maxf(w, caja * 0.008)
		izq.append(punta + Vector2(x - w, y))
		der.append(punta + Vector2(x + w, y))
	var pts := PackedVector2Array()
	pts.append_array(izq)
	for i in range(der.size() - 1, -1, -1):
		pts.append(der[i])
	draw_colored_polygon(pts, Color(_HUESO.r, _HUESO.g, _HUESO.b, alfa))
	pts.append(pts[0])
	draw_polyline(pts, Color(_ENCIA.r, _ENCIA.g, _ENCIA.b, 0.6 * alfa), maxf(1.0, caja * 0.02), true)
	# EL DESGARRO en la punta, cuando ya ha enganchado. Se reusa el huso dentado del zarpazo.
	if k > 0.5:
		_surco(punta, Vector2(ladeo, -1.0).normalized(), caja * 0.5, caja * 0.05,
			g * 1.9, alfa * 0.9)


# CARGA: la embestida. No se dibuja el bicho -se ve venir su tarjeta-, se dibuja LO QUE DEJA:
# las lineas de velocidad del trayecto y la polvareda del choque.
#
# Es el unico de los cinco que necesita el punto de ORIGEN (por eso no entra en la rama de alta()
# que hace a = b): las lineas tienen que venir de donde estaba el bicho, no de ningun sitio.
func _pintar_carga(e: Dictionary) -> void:
	var a: Vector2 = e["a"]
	var b: Vector2 = e["b"]
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var dir: Vector2 = (b - a).normalized() if a.distance_to(b) > 1.0 else Vector2.UP
	var lado := Vector2(-dir.y, dir.x)
	var claro := Color(minf(1.0, col.r + 0.35), minf(1.0, col.g + 0.33), minf(1.0, col.b + 0.3), 1.0)
	# LAS LINEAS DE VELOCIDAD, que es lo que lo hace verse VENIR. Empiezan antes del golpe y
	# SOBREVIVEN un poco al choque: si se cortaran justo al impactar, la carga se perderia --
	# quedaria solo una polvareda y no se leeria de donde ha salido.
	var u_lin: float = clampf(t / maxf(dur, 0.01), 0.0, 1.0)
	var post: float = clampf((t - dur) / 0.16, 0.0, 1.0)   # 0 al tocar, 1 cuando ya se han ido
	if post < 1.0:
		for i in 7:
			var off: float = (float(i) - 3.0) / 3.0
			var base: Vector2 = b.lerp(a, 0.30 + 0.5 * absf(off)) + lado * off * caja * 0.42
			draw_line(base, base + dir * caja * (0.35 + 0.4 * u_lin),
				Color(claro.r, claro.g, claro.b, 0.5 * u_lin * (1.0 - post)),
				maxf(1.0, caja * 0.035), true)
	if t < dur:
		return
	var v: float = clampf((t - dur) / 0.30, 0.0, 1.0)
	var alfa: float = 1.0 - v * v
	if alfa <= 0.0:
		return
	# ARROLLA A LO LARGO DE LA FILA. La Carga acorazada alcanza hasta tres, y como este estilo es de
	# grupo (ver _ESTILOS_DE_GRUPO) se dibuja UNA sola vez con el ancho de todo lo alcanzado: el
	# frente entra por un extremo y BARRE hasta el otro, en vez de reventar en un punto. Antes, sin
	# agrupar, salia una embestida entera por victima -con sus lineas de velocidad apuntando a cada
	# una-, y se leia como tres bichos cargando a la vez.
	#
	# A UN SOLO objetivo el recorrido sale casi cero y se comporta como el choque de siempre, que es
	# lo que quieren el Picado y la Embestida del jabali.
	# El umbral (caja * 0.8) separa "arrolla una fila" de "choca contra uno": con una sola victima el
	# ancho es el de SU tarjeta y el recorrido sale corto, y ahi no tiene que barrer ni dejar surco.
	var span: float = maxf(float(e["ancho"]) * 0.5 - caja * 0.35, 0.0)
	# Entra por el lado del que carga: si viene de la izquierda, barre hacia la derecha.
	var signo: float = 1.0 if a.x <= b.x else -1.0
	var avance: float = clampf(v / 0.72, 0.0, 1.0)
	var frente: Vector2 = Vector2(b.x + signo * lerpf(-span, span, avance), b.y)
	# Cuando barre, la marcha es HORIZONTAL; cuando es a uno solo, la del que venia embistiendo.
	var mar: Vector2 = Vector2(signo, 0.0) if span > caja * 0.8 else dir
	var per := Vector2(-mar.y, mar.x)
	# LA POLVAREDA: MUCHAS motas pequeñas y translucidas, no cuatro pelotas. Con circulos gordos
	# parecian bolas de barro; el polvo se lee por cantidad y por lo tenue, no por tamaño.
	# Se queda DETRAS del frente: el polvo no avanza con el bicho, lo deja atras.
	for i in 18:
		var ang: float = g + TAU * float(i) / 18.0 + float(i) * 0.7
		var d := Vector2(cos(ang), sin(ang) * 0.55)
		var alcance: float = 0.35 + 0.9 * v * (0.6 + 0.4 * absf(sin(g * 2.1 + float(i))))
		var p: Vector2 = frente + (d * alcance - mar * (0.30 + 0.5 * avance)) * caja * 0.75
		draw_circle(p, maxf(1.0, caja * 0.055 * (1.0 - v * 0.5)),
			Color(claro.r, claro.g, claro.b, 0.30 * alfa))
	# EL FRENTE del choque: un arco COMBADO perpendicular a la marcha. Va estrecho (0.55 de la
	# caja): a lo ancho que estaba antes se salia de la tarjeta y se leia como un palo cruzado.
	var arco := PackedVector2Array()
	for i in 13:
		var s: float = float(i) / 12.0 - 0.5
		# Comba EN EL SENTIDO DE LA MARCHA (+mar por el centro): es un frente empujando hacia
		# dentro. Combado al reves salia una sonrisa -- con las motas de polvo encima haciendo de
		# ojos, la tarjeta se leia literalmente como una carita.
		arco.append(frente + per * s * caja * (0.55 + 0.35 * v)
			+ mar * (1.0 - 4.0 * s * s) * caja * 0.18 * (1.0 - v))
	draw_polyline(arco, Color(claro.r, claro.g, claro.b, 0.8 * alfa),
		maxf(2.0, caja * 0.05 * (1.0 - v * 0.7)), true)
	# EL SURCO que deja por donde ha pasado, solo cuando de verdad barre la fila.
	if span > caja * 0.8:
		draw_line(Vector2(b.x - signo * span, b.y), frente,
			Color(claro.r, claro.g, claro.b, 0.30 * alfa), maxf(2.0, caja * 0.10), true)


# PISOTON: la pata baja y el suelo se abre. Se lee en dos cosas: la GRIETA (lineas quebradas que
# salen del punto y se estrechan) y una onda baja de polvo que corre a ras.
#
# Es de grupo (ver _ESTILOS_DE_GRUPO): si alcanza a tres, es UN pisoton ancho.
func _pintar_pisoton(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, 0.38, 0.06)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	# El alcance sale de lo ALCANZADO, no del daño: si pisa para tres, la grieta los cruza. El 0.5
	# es MEDIO ancho del grupo, que es el radio justo para taparlo entero -- con mas, un pisoton a
	# cuatro llenaba la pantalla de lado a lado.
	var r: float = _radio_grupo(e, 0.5, 26.0)
	var claro := Color(minf(1.0, col.r + 0.3), minf(1.0, col.g + 0.28), minf(1.0, col.b + 0.25), 1.0)
	# LA GRIETA: seis brazos quebrados que salen del pie. Los quiebros salen de la semilla, no de
	# randf(), o la grieta cambiaria de forma en cada frame.
	#
	# VAN HACIA LOS OTROS OBJETIVOS. Los brazos no se reparten por igual: los que apuntan A LO ANCHO
	# se alargan y los que suben o bajan se quedan cortos. La fila esta en horizontal, asi que asi
	# la grieta CORRE HASTA los demas alcanzados en vez de hacer una estrella bonita centrada en el
	# pie -- que es lo que dice "el suelo se ha roto hasta alli" y por tanto por que les llega.
	var k: float = clampf(v / 0.22, 0.0, 1.0)
	for i in 6:
		var ang: float = g * 1.3 + TAU * float(i) / 6.0
		# |cos| vale 1 en horizontal y 0 en vertical: el brazo que apunta a un lado llega entero y
		# el que apunta arriba se queda en un tercio.
		var reparto: float = 0.32 + 0.68 * absf(cos(ang))
		var pts := PackedVector2Array()
		for j in 5:
			var s: float = float(j) / 4.0
			# MUY aplastada en vertical: es una grieta EN EL SUELO vista de frente, asi que tiene
			# que quedarse a ras de la fila. Con poco achatamiento los brazos subian por encima de
			# las tarjetas y parecian rayos, no suelo roto.
			var desv: float = sin(g + float(i) * 2.3 + float(j) * 3.7) * 0.30
			var a2: float = ang + desv * s
			pts.append(b + Vector2(cos(a2), sin(a2) * 0.26) * r * s * k * reparto)
		# Los grosores van CAPADOS. Salen de 'r', y como 'r' crece con el numero de alcanzados, un
		# pisoton a cuatro pintaba grietas de 30 px de gruesas: parecian vigas, no grietas.
		draw_polyline(pts, Color(0.06, 0.05, 0.06, 0.8 * alfa),
			clampf(r * 0.06 * (1.0 - 0.5 * v), 1.5, 7.0), true)
	# LA ONDA de polvo, a ras: un anillo bajo que se abre justo hasta el borde de lo alcanzado.
	_anillo(b, r * (0.35 + 0.75 * v), r * (0.10 + 0.20 * v),
		Color(claro.r, claro.g, claro.b, 0.45 * alfa), clampf(r * 0.05 * (1.0 - v), 1.5, 5.0))
	# Y los cascotes que saltan del sitio.
	for i in 7:
		var ang2: float = g * 2.7 + TAU * float(i) / 7.0
		var d := Vector2(cos(ang2), -absf(sin(ang2)) * 0.8)
		draw_circle(b + d * r * (0.30 + 0.5 * v), clampf(r * 0.05 * (1.0 - v), 1.0, 5.0),
			Color(0.35, 0.31, 0.28, 0.75 * alfa))


# GOLPETAZO: un porrazo ROMO. Ni filo ni diente: un puño de piedra, una maza, una rama. Se dibuja
# como una estrella de impacto CORTA Y GORDA -lo contrario del destello de la yugular, que es de
# agujas largas- mas un anillo que se abre. Es el basico de media docena de bichos, asi que va
# corto y seco a proposito: sale muchas veces por pelea y no puede cansar.
func _pintar_golpetazo(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, 0.26, 0.09)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var r: float = clampf(float(e["ancho"]) * 0.30, 18.0, 48.0) * (0.75 + 0.5 * clampf(v / 0.2, 0.0, 1.0))
	var claro := Color(minf(1.0, col.r + 0.42), minf(1.0, col.g + 0.4), minf(1.0, col.b + 0.35), 1.0)
	# Las puas: cortas, gordas y de largo desigual. La desigualdad sale de la semilla (fija), que
	# es lo que lo separa de una estrella de dibujo animado.
	var pts := PackedVector2Array()
	var n: int = 9
	for i in n:
		var ang: float = g + TAU * float(i) / float(n)
		var largo: float = r * (0.85 + 0.35 * sin(g * 1.7 + float(i) * 2.9))
		pts.append(b + Vector2(cos(ang), sin(ang) * 0.85) * largo)
		# El valle entre pua y pua se queda ALTO (0.52): eso es lo que lo hace romo en vez de
		# afilado. Con el valle bajo salia un sol de puntas finas.
		var med: float = ang + PI / float(n)
		pts.append(b + Vector2(cos(med), sin(med) * 0.85) * largo * 0.52)
	draw_colored_polygon(pts, Color(claro.r, claro.g, claro.b, 0.8 * alfa))
	# El anillo, APLASTADO y pegado a las puas. Redondo y ancho se leia como una burbuja alrededor
	# del golpe en vez de como la onda del porrazo.
	_anillo(b, r * (0.95 + 0.55 * v), r * (0.80 + 0.45 * v) * 0.85,
		Color(claro.r, claro.g, claro.b, 0.35 * alfa), maxf(1.5, r * 0.08 * (1.0 - v)))


# RAICES: el suelo se abre y brotan raices que suben agarrando. No las lanza nadie -- por eso este
# no embiste y si enciende la tarjeta del que las invoca.
#
# Comparte el dibujo con el estado Enraizado (CapaEstado.mata_de_raices): lo que te clava y lo que
# te tiene clavado tienen que ser LA MISMA cosa, o no se lee que sigues atado por aquello. Aqui
# CRECEN (brotan) y alli se pintan ya crecidas.
func _pintar_raices(e: Dictionary) -> void:
	var b: Vector2 = e["b"]
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var col: Color = e["col"]
	var caja: float = clampf(float(e["ancho"]) * 0.9, 50.0, 150.0)
	# Brotan MIENTRAS vuelan (el vuelo largo es justo eso: verlas subir) y se quedan un momento.
	var u: float = clampf(t / maxf(dur, 0.01), 0.0, 1.0)
	var v: float = clampf((t - dur) / 0.34, 0.0, 1.0)
	var alfa: float = 0.75 if v <= 0.0 else 0.75 * (1.0 - v * v)
	if alfa <= 0.0:
		return
	# Del BORDE DE ABAJO de la tarjeta hacia arriba: brotan del suelo, no del centro del bicho.
	var suelo: Vector2 = b + Vector2(0.0, caja * 0.36)
	CapaEstado.mata_de_raices(self, suelo, caja, caja * 0.95, float(e["semilla"]), col, alfa,
		u if v <= 0.0 else 1.0)
	# Los TERRONES que salta el suelo al abrirse, solo en el momento de brotar.
	if v <= 0.0:
		for i in 6:
			var ang: float = float(e["semilla"]) + TAU * float(i) / 6.0
			var d := Vector2(cos(ang), -absf(sin(ang)) * 0.7)
			draw_circle(suelo + d * caja * 0.35 * u, maxf(1.0, caja * 0.035 * (1.0 - u)),
				Color(0.32, 0.26, 0.18, 0.7 * alfa))


# ============================================================
#  PONERSE A CUBIERTO (Caparazon, Muralla, Endurecerse)
# ============================================================
# Los tres son la MISMA mecanica -Fortaleza sobre uno mismo, 0 de daño-, y por eso los tres pasan
# por _fx_adorno en vez de por el reparto de golpes (ver combat.gd). Lo que cambia es la FORMA,
# porque lo que se cubre no es lo mismo: un bicho con coraza, un coloso de piedra y un muñeco de
# arcilla. Con un aura para los tres, las tres habilidades se veian iguales.
#
# El ciclo lo comparten: se cierra encima (0 -> 1 durante el vuelo), aguanta puesto un rato y se
# desvanece. Devuelve [cerrado 0..1, alfa] o [-1, 0] si ya se ha ido.
func _cubrirse(e: Dictionary) -> Array:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var cierra: float = clampf(t / maxf(dur, 0.01), 0.0, 1.0)
	# Entra con un rebasamiento corto: cae encima y asienta, en vez de aparecer.
	if cierra < 1.0:
		cierra = 1.0 - pow(1.0 - cierra, 2.2)
	var fuera: float = clampf((t - dur) / 0.70, 0.0, 1.0)
	# Aguanta a tope media vida y despues se apaga.
	var alfa: float = 1.0 if fuera < 0.55 else 1.0 - (fuera - 0.55) / 0.45
	if alfa <= 0.0:
		return [-1.0, 0.0]
	return [cierra, alfa]


# CAPARAZON: el escarabajo visto DESDE ARRIBA, cerrandose sobre el bicho.
#
# La primera version era una elipse oscura con rayas finas y quedaba fatal, porque lo que hace que
# una mancha negra se lea como un escarabajo NO son las estrias:
#   1. LA DIVISION pronoto / elitro. Son dos piezas separadas por una junta clara, y el ojo la pilla
#      antes que nada. Con una sola pieza es un huevo, se le pinte lo que se le pinte encima.
#   2. EL CUERNO asomando por delante del pronoto. Es la silueta que lo hace ESE bicho.
#   3. UN BRILLO ANCHO Y BLANDO. Un caparazon es charolado: el reflejo es una mancha grande, no dos
#      lineas -- dos lineas finas se leen como arañazos, que es justo lo contrario de "coraza".
# Las estrias van al final y sirven de poco; el trabajo lo hacen esas tres.
func _pintar_caparazon(e: Dictionary) -> void:
	var r0: Array = _cubrirse(e)
	var k: float = r0[0]
	if k < 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = e["b"]
	var caja: float = clampf(float(e["ancho"]) * 0.9, 50.0, 150.0)
	# Baja desde arriba al cerrarse: es una tapa, no algo que crece.
	var c: Vector2 = b + Vector2(0.0, -caja * 0.62 * (1.0 - k))
	var rx: float = caja * 0.42
	# Corta y con cuerpo: es una daga. Larga y fina se leia como un estoque.
	var largo: float = caja * 0.44      # de la junta hacia abajo (el elitro)
	var y0: float = c.y - largo * 0.30  # donde acaba el pronoto y empieza el elitro
	# Negro charolado, pero NO negro puro: sobre una tarjeta oscura desaparecia. Y translucido,
	# porque esto va sobre el nombre y la barra de vida -- mismo criterio que CapaEstado.
	var quitina := Color(0.13, 0.12, 0.15, 0.80 * alfa)
	var canto := Color(0.62, 0.60, 0.58, 0.85 * alfa)

	# --- EL ELITRO: ancho arriba (donde encaja con el pronoto) y en punta redondeada abajo.
	var eli := PackedVector2Array()
	var n := 20
	for i in n + 1:                       # lado derecho, de arriba abajo
		var s: float = float(i) / float(n)
		eli.append(Vector2(c.x + _hw_elitro(s) * rx, y0 + s * largo))
	for i in n + 1:                       # y de vuelta por el izquierdo
		var s2: float = 1.0 - float(i) / float(n)
		eli.append(Vector2(c.x - _hw_elitro(s2) * rx, y0 + s2 * largo))
	draw_colored_polygon(eli, quitina)

	# --- EL BRILLO: una mancha ANCHA por el lomo izquierdo, no una raya.
	var luz := PackedVector2Array()
	for i in 13:
		var s3: float = 0.06 + 0.62 * float(i) / 12.0
		luz.append(Vector2(c.x - _hw_elitro(s3) * rx * 0.62, y0 + s3 * largo))
	for i in 13:
		var s4: float = 0.68 - 0.62 * float(i) / 12.0
		luz.append(Vector2(c.x - _hw_elitro(s4) * rx * 0.16, y0 + s4 * largo))
	draw_colored_polygon(luz, Color(0.78, 0.80, 0.86, 0.30 * alfa))

	# --- LA COSTURA por el centro y un par de estrias por lado, cortas y pegadas a ella.
	draw_line(Vector2(c.x, y0 + largo * 0.04), Vector2(c.x, y0 + largo * 0.94),
		Color(0.02, 0.02, 0.03, 0.9 * alfa), maxf(1.5, caja * 0.024), true)
	for i in 4:
		var lado: float = -1.0 if i < 2 else 1.0
		var f: float = 0.34 + 0.30 * float(i % 2)
		var pts2 := PackedVector2Array()
		for j in 7:
			var s5: float = 0.10 + 0.76 * float(j) / 6.0
			pts2.append(Vector2(c.x + lado * _hw_elitro(s5) * rx * f, y0 + s5 * largo))
		draw_polyline(pts2, Color(0.05, 0.05, 0.06, 0.5 * alfa), maxf(1.0, caja * 0.009), true)
	draw_polyline(eli, canto, maxf(1.5, caja * 0.016), true)

	# --- EL PRONOTO: la pieza de delante, mas estrecha, con su propio canto. La JUNTA entre las dos
	# piezas es lo que mas dice "escarabajo", asi que se deja ver.
	var ph: float = largo * 0.34
	var pro := PackedVector2Array()
	for i in 13:
		var s6: float = float(i) / 12.0
		# Trapecio de esquinas redondeadas: estrecho arriba y ancho abajo, donde encaja.
		var w: float = rx * (0.55 + 0.42 * s6) * (1.0 - 0.28 * pow(1.0 - s6, 2.6))
		pro.append(Vector2(c.x + w, y0 - ph + s6 * ph))
	for i in 13:
		var s7: float = 1.0 - float(i) / 12.0
		var w2: float = rx * (0.55 + 0.42 * s7) * (1.0 - 0.28 * pow(1.0 - s7, 2.6))
		pro.append(Vector2(c.x - w2, y0 - ph + s7 * ph))
	draw_colored_polygon(pro, Color(quitina.r * 1.25, quitina.g * 1.25, quitina.b * 1.25, quitina.a))
	draw_polyline(pro, canto, maxf(1.5, caja * 0.015), true)
	# Su propio reflejo, arriba a la izquierda.
	draw_circle(Vector2(c.x - rx * 0.34, y0 - ph * 0.55), maxf(1.5, caja * 0.05),
		Color(0.78, 0.80, 0.86, 0.28 * alfa))

	# --- EL CUERNO, asomando por delante y curvado hacia arriba. Es la silueta del bicho.
	var base := Vector2(c.x, y0 - ph * 0.92)
	var cu := PackedVector2Array()
	var cd := PackedVector2Array()
	for i in 9:
		var s8: float = float(i) / 8.0
		var p := Vector2(c.x - largo * 0.10 * s8 * s8, base.y - largo * 0.46 * s8)
		var w3: float = rx * 0.13 * (1.0 - pow(s8, 1.5)) + 0.4
		cu.append(p + Vector2(w3, 0.0))
		cd.append(p - Vector2(w3, 0.0))
	for i in range(cd.size() - 1, -1, -1):
		cu.append(cd[i])
	draw_colored_polygon(cu, Color(quitina.r * 1.4, quitina.g * 1.4, quitina.b * 1.4, quitina.a))
	draw_polyline(cu, canto, maxf(1.0, caja * 0.012), true)


# El PERFIL del elitro: media anchura (0..1) segun lo que se ha bajado por el (s: 0 arriba, 1 abajo).
# Ancho arriba, donde encaja con el pronoto, y cerrandose en punta REDONDEADA abajo. Con una elipse
# normal el bicho salia con forma de huevo y no de escarabajo.
func _hw_elitro(s: float) -> float:
	return sqrt(maxf(0.0, 1.0 - pow(clampf(s, 0.0, 1.0), 2.6))) * (0.90 + 0.10 * (1.0 - s))


# MURALLA: un muro de LADRILLO que se levanta delante del coloso, hilada a hilada. Lo que lo lee
# como muro es el APAREJO -las hiladas desplazadas media pieza- y la junta oscura entre ellas, no
# el color; con los ladrillos alineados en rejilla parece un azulejo.
func _pintar_muralla(e: Dictionary) -> void:
	var r0: Array = _cubrirse(e)
	var k: float = r0[0]
	if k < 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = e["b"]
	var caja: float = clampf(float(e["ancho"]) * 0.95, 50.0, 160.0)
	var ancho: float = caja * 0.96
	var alto: float = caja * 0.92
	var filas: int = 7
	var h: float = alto / float(filas)
	var abajo: float = b.y + alto * 0.5
	var g: float = float(e["semilla"])
	for f in filas:
		# SE LEVANTA de abajo arriba: cada hilada entra cuando le toca.
		var kf: float = clampf((k - float(f) * 0.09) / 0.55, 0.0, 1.0)
		if kf <= 0.0:
			continue
		var y: float = abajo - h * (float(f) + 1.0)
		# APAREJO A SOGA: las impares van desplazadas MEDIA pieza. Es el escalonado lo que lo
		# convierte en muro.
		var w: float = ancho / 3.4
		var off: float = (w * 0.5) if f % 2 == 1 else 0.0
		var x: float = b.x - ancho * 0.5 - w + off
		while x < b.x + ancho * 0.5:
			var x0: float = maxf(x, b.x - ancho * 0.5)
			var x1: float = minf(x + w, b.x + ancho * 0.5)
			if x1 - x0 > 1.0:
				# Cada pieza con su tono: un muro de ladrillos identicos parece papel pintado.
				var tono: float = 0.46 + 0.10 * sin(g + float(f) * 2.7 + x * 0.07)
				var alto_f: float = h * kf
				# TRANSLUCIDO: un muro opaco tapaba la tarjeta entera durante casi un segundo, o sea
				# el nombre y la barra de vida. Se tiene que leer el bicho DETRAS del muro.
				draw_rect(Rect2(x0 + 1.0, y + (h - alto_f) + 1.0, x1 - x0 - 2.0, alto_f - 2.0),
					Color(tono, tono * 0.97, tono * 0.94, 0.70 * alfa))
			x += w
	# La junta se lee sola por el hueco de 2 px entre piezas, pero el muro necesita SOMBRA abajo
	# para no flotar.
	draw_line(Vector2(b.x - ancho * 0.5, abajo), Vector2(b.x + ancho * 0.5, abajo),
		Color(0.05, 0.05, 0.06, 0.75 * alfa), maxf(2.0, caja * 0.03), true)


# ESCUDO (Endurecerse): placas que se cierran sobre el golem. No es un muro delante ni una coraza
# de bicho: es la propia arcilla que se acartona, asi que son PLACAS que encajan unas con otras.
func _pintar_escudo(e: Dictionary) -> void:
	var r0: Array = _cubrirse(e)
	var k: float = r0[0]
	if k < 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = e["b"]
	var caja: float = clampf(float(e["ancho"]) * 0.9, 50.0, 150.0)
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var placas: int = 7
	for i in placas:
		var ang: float = g + TAU * float(i) / float(placas)
		# Vienen de FUERA y encajan hacia dentro: se ve el cierre.
		var d: float = caja * (0.62 - 0.16 * k)
		var c: Vector2 = b + Vector2(cos(ang) * d, sin(ang) * d * 0.72)
		var eje := Vector2(cos(ang), sin(ang) * 0.72).normalized()
		var lado := Vector2(-eje.y, eje.x)
		var largo: float = caja * 0.30
		var ancho2: float = caja * 0.19
		var tono: float = 0.55 + 0.12 * sin(g * 1.7 + float(i) * 2.1)
		draw_colored_polygon(PackedVector2Array([
			c - eje * largo * 0.35 - lado * ancho2, c - eje * largo * 0.35 + lado * ancho2,
			c + eje * largo * 0.5 + lado * ancho2 * 0.6,
			c + eje * largo * 0.5 - lado * ancho2 * 0.6,
		]), Color(col.r * tono + 0.18, col.g * tono + 0.16, col.b * tono + 0.12, 0.9 * alfa))
	# Y el nucleo endurecido: un halo apretado que dice que lo de dentro se ha vuelto piedra.
	draw_arc(b, caja * 0.40, 0.0, TAU, 26,
		Color(0.85, 0.8, 0.7, 0.35 * alfa * k), maxf(1.5, caja * 0.03), true)


# ============================================================
#  BICHOS (araña, ciempies, escarabajo)
# ============================================================

# TELARAÑA: lo unico de los insectos que VIAJA de verdad -se la lanzan a uno- y por eso llega
# volando y se despliega al tocar. Lo que la lee como red son los RADIOS mas los hilos en espiral
# entre ellos; una maraña de rayas sueltas no dice "red", dice "arañazos".
func _pintar_telarana(e: Dictionary) -> void:
	var a: Vector2 = e["a"]
	var b: Vector2 = e["b"]
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.62, 34.0, 100.0)
	var hilo := Color(0.92, 0.94, 0.90)
	var u: float = clampf(t / maxf(dur, 0.01), 0.0, 1.0)
	if u < 1.0:
		# EN VUELO va hecha un ovillo: una red abierta cruzando la pantalla parece una cometa.
		var p: Vector2 = a.lerp(b, u * u)
		var r: float = caja * (0.16 + 0.10 * u)
		draw_arc(p, r, 0.0, TAU, 12, Color(hilo.r, hilo.g, hilo.b, 0.75), 2.0, true)
		draw_arc(p, r * 0.55, 0.0, TAU, 10, Color(hilo.r, hilo.g, hilo.b, 0.5), 1.5, true)
		return
	var v: float = clampf((t - dur) / 0.40, 0.0, 1.0)
	var alfa: float = 1.0 if v < 0.5 else 1.0 - (v - 0.5) / 0.5
	if alfa <= 0.0:
		return
	# SE DESPLIEGA de golpe y se queda TIRANTE: crece deprisa hasta su tamaño y ahi se planta.
	var k: float = clampf(v / 0.18, 0.0, 1.0)
	var radios: int = 9
	var rr: float = caja * k
	# Los radios, con el largo desigual: una red de verdad no es un abanico perfecto.
	var largos: Array = []
	for i in radios:
		largos.append(rr * (0.78 + 0.22 * absf(sin(g * 1.7 + float(i) * 2.3))))
	for i in radios:
		var ang: float = g + TAU * float(i) / float(radios)
		draw_line(b, b + Vector2(cos(ang), sin(ang) * 0.8) * float(largos[i]),
			Color(hilo.r, hilo.g, hilo.b, 0.55 * alfa), 1.5, true)
	# Y las vueltas en espiral entre radio y radio, que es lo que la convierte en RED.
	for anillo in range(1, 4):
		var f: float = float(anillo) / 3.5
		var pts := PackedVector2Array()
		for i in radios + 1:
			var idx: int = i % radios
			var ang2: float = g + TAU * float(i) / float(radios)
			# Cada tramo cuelga un poco hacia dentro: los hilos no van tensos entre radios.
			pts.append(b + Vector2(cos(ang2), sin(ang2) * 0.8) * float(largos[idx]) * f * 0.94)
		draw_polyline(pts, Color(hilo.r, hilo.g, hilo.b, 0.42 * alfa), 1.5, true)


# ENROSQUE: el ciempies se enrolla alrededor y APRIETA. La clave es que los anillos se CIERREN --
# si se quedaran del mismo tamaño seria un adorno; lo que duele es que encojan.
func _pintar_enrosque(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, 0.40, 0.05)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.62, 34.0, 100.0)
	var claro := Color(minf(1.0, col.r + 0.28), minf(1.0, col.g + 0.22), minf(1.0, col.b + 0.2), 1.0)
	# APRIETA: de 1.15 a 0.62 del tamaño. Ese encogimiento ES la habilidad.
	var apriete: float = 1.15 - 0.53 * clampf(v / 0.45, 0.0, 1.0)
	for i in 3:
		var f: float = 1.0 - float(i) * 0.16
		var y: float = (float(i) - 1.0) * caja * 0.34
		_anillo(b + Vector2(0.0, y), caja * apriete * f, caja * 0.20 * f,
			Color(col.r, col.g, col.b, 0.85 * alfa), maxf(2.5, caja * 0.11))
		# El brillo del lomo, arriba de cada vuelta: le da bulto de cuerpo y no de aro pintado.
		_anillo(b + Vector2(0.0, y - caja * 0.04), caja * apriete * f * 0.97, caja * 0.19 * f,
			Color(claro.r, claro.g, claro.b, 0.35 * alfa), maxf(1.0, caja * 0.035))
	# Y las PATAS agarrando por fuera del anillo del medio: es un ciempies, no una serpiente.
	for i in 14:
		var s: float = float(i) / 13.0 - 0.5
		var x: float = s * caja * apriete * 1.9
		var lado: float = -1.0 if i % 2 == 0 else 1.0
		var base := Vector2(b.x + x, b.y + lado * caja * 0.18)
		draw_line(base, base + Vector2(sin(g + float(i)) * caja * 0.05, lado * caja * 0.16),
			Color(claro.r, claro.g, claro.b, 0.6 * alfa), maxf(1.0, caja * 0.03), true)


# OLEADA DE PATAS: decenas de patas finas recorriendote de arriba abajo. Cada una pincha poco -por
# eso son finas y muchas-, y lo que se lee es la CANTIDAD y el barrido, no cada pinchazo.
func _pintar_patas(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, 0.30, 0.10)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var claro := Color(minf(1.0, col.r + 0.3), minf(1.0, col.g + 0.26), minf(1.0, col.b + 0.2), 1.0)
	# El barrido BAJA por la tarjeta: la franja de patas activas recorre de arriba abajo. El
	# recorrido se queda DENTRO de la caja (-0.48 a 0.48): pasandose, la ultima mitad de las patas
	# salia por debajo de la tarjeta y parecia que pinchaban el suelo.
	var frente: float = -0.48 + 0.96 * v
	for i in 22:
		var s: float = float(i) / 21.0 - 0.5
		# Cada pata entra cuando el frente pasa por su altura, y se apaga detras.
		var y: float = sin(g * 1.3 + float(i) * 1.9) * 0.42
		var d: float = absf(y - frente)
		if d > 0.30:
			continue
		var k: float = 1.0 - d / 0.30
		var lado: float = -1.0 if i % 2 == 0 else 1.0
		var base := Vector2(b.x + s * caja * 1.5, b.y + y * caja)
		# En gancho: un tramo recto y una uña corta al final. Una raya suelta no pincha.
		var pta: Vector2 = base + Vector2(lado * caja * 0.28 * k, caja * 0.19 * k)
		draw_line(base, pta, Color(claro.r, claro.g, claro.b, 0.85 * alfa * k),
			maxf(1.5, caja * 0.032), true)
		draw_line(pta, pta + Vector2(lado * caja * 0.08, -caja * 0.09) * k,
			Color(_HUESO.r, _HUESO.g, _HUESO.b, 0.85 * alfa * k), maxf(1.0, caja * 0.026), true)


# RODADA: el escarabajo se hace una bola y ARROLLA. Es la carga con giro, asi que lo que la separa
# de una embestida normal son las estelas circulares y el polvo saliendo por debajo.
func _pintar_rodada(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, 0.34, 0.06)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	# UNA BOLA ES DEL TAMAÑO DE UNA BOLA. Lo que crece cuando arrolla a varios no es su diametro,
	# es SU RECORRIDO: por eso el radio va CAPADO y lo que sale del ancho del grupo es el trayecto.
	# Sacando el radio de _radio_grupo a secas, un arrollamiento a cuatro pintaba una bola de 500 px
	# quieta en el centro, que no rueda ni arrolla: solo tapa.
	var r: float = clampf(_radio_grupo(e, 0.28, 22.0), 22.0, 46.0)
	var span: float = maxf(float(e["ancho"]) * 0.5 - r, 0.0)
	# CRUZA la fila mientras dura: entra por un lado y sale por el otro.
	var cx: float = b.x + lerpf(-span, span, clampf(v / 0.75, 0.0, 1.0))
	b = Vector2(cx, b.y)
	var claro := Color(minf(1.0, col.r + 0.3), minf(1.0, col.g + 0.28), minf(1.0, col.b + 0.25), 1.0)
	# LA BOLA, con el giro marcado por dentro. El angulo avanza con v: rueda de verdad.
	var giro: float = g + v * 9.0
	draw_circle(b, r, Color(col.r * 0.55 + 0.08, col.g * 0.55 + 0.08, col.b * 0.55 + 0.08,
		0.92 * alfa))
	for i in 4:
		var a2: float = giro + PI * float(i) / 4.0
		draw_line(b - Vector2(cos(a2), sin(a2)) * r * 0.85,
			b + Vector2(cos(a2), sin(a2)) * r * 0.85,
			Color(claro.r, claro.g, claro.b, 0.30 * alfa), maxf(1.5, r * 0.09), true)
	draw_arc(b, r, 0.0, TAU, 26, Color(claro.r, claro.g, claro.b, 0.8 * alfa),
		maxf(2.0, r * 0.10), true)
	# ESTELAS de rotacion: arcos cortos detras, que es lo que dice "esto viene girando".
	for i in 3:
		var off: float = float(i) * 0.55
		var ini: float = giro - 2.4 - off
		draw_arc(b, r * (1.20 + 0.22 * float(i)), ini, ini + 1.1, 12,
			Color(claro.r, claro.g, claro.b, (0.4 - 0.1 * float(i)) * alfa),
			maxf(1.0, r * 0.06), true)
	# Y el polvo que levanta por abajo.
	for i in 6:
		var ang: float = g * 2.1 + TAU * float(i) / 6.0
		draw_circle(b + Vector2(cos(ang) * r * (1.1 + 0.5 * v), absf(sin(ang)) * r * 0.55),
			maxf(1.0, r * 0.10 * (1.0 - v)), Color(claro.r, claro.g, claro.b, 0.3 * alfa))


# MIRADA: se abre un OJO en el que mira y de el sale una onda hasta el objetivo. Lo usan la Mirada
# petrea de la gargola y la Mirada del vacio de la aberracion -- las dos son lo mismo: no te tocan,
# te MIRAN, y el efecto viaja por la vista.
#
# Es de las pocas de bicho que viaja de verdad, asi que NO embiste y SI enciende la tarjeta del que
# mira mientras la onda cruza (queda fuera de _CUERPO_A_CUERPO a proposito).
func _pintar_mirada(e: Dictionary) -> void:
	var a: Vector2 = e["a"]
	var b: Vector2 = e["b"]
	var col: Color = e["col"]
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var caja: float = clampf(float(e["ancho"]) * 0.5, 30.0, 80.0)
	var claro := Color(minf(1.0, col.r + 0.45), minf(1.0, col.g + 0.42), minf(1.0, col.b + 0.5), 1.0)
	var u: float = clampf(t / maxf(dur, 0.01), 0.0, 1.0)
	var v: float = clampf((t - dur) / 0.30, 0.0, 1.0)
	var alfa: float = 1.0 if v <= 0.0 else 1.0 - v * v
	if alfa <= 0.0:
		return
	# EL OJO, en el que mira. Se abre (el parpado sube) y se queda mirando.
	var abre: float = clampf(u / 0.45, 0.0, 1.0) * (1.0 - v * 0.7)
	if abre > 0.02:
		var rx: float = caja * 0.42
		var ry: float = caja * 0.30 * abre
		# La almendra: dos arcos enfrentados. Con una elipse sale un huevo, no un ojo.
		var ojo := PackedVector2Array()
		for i in 15:
			var s: float = float(i) / 14.0 * 2.0 - 1.0
			ojo.append(a + Vector2(s * rx, -ry * (1.0 - s * s)))
		for i in 15:
			var s2: float = 1.0 - float(i) / 14.0 * 2.0
			ojo.append(a + Vector2(s2 * rx, ry * (1.0 - s2 * s2)))
		draw_colored_polygon(ojo, Color(0.95, 0.95, 0.92, 0.9 * alfa))
		# El iris mira AL OBJETIVO: se desplaza hacia el, que es lo que lo hace inquietante.
		var haz: Vector2 = (b - a).normalized()
		var iris: Vector2 = a + haz * rx * 0.35
		draw_circle(iris, maxf(2.0, ry * 0.75), Color(col.r * 0.5, col.g * 0.5, col.b * 0.6,
			0.95 * alfa))
		draw_circle(iris, maxf(1.0, ry * 0.34), Color(0.03, 0.02, 0.05, alfa))
		draw_polyline(ojo, Color(0.1, 0.09, 0.12, 0.8 * alfa), maxf(1.0, caja * 0.03), true)
	# LA ONDA que sale del ojo y llega al objetivo: anillos que viajan por el trayecto.
	for i in 3:
		var k: float = u - float(i) * 0.22
		if k <= 0.0 or k >= 1.0:
			continue
		var p: Vector2 = a.lerp(b, k)
		var rr: float = caja * (0.22 + 0.55 * k)
		_anillo(p, rr, rr * 0.82, Color(claro.r, claro.g, claro.b, 0.5 * (1.0 - k) * alfa),
			maxf(1.5, caja * 0.06 * (1.0 - k)))
	# Y al llegar, el objetivo queda envuelto un momento.
	if v > 0.0:
		_anillo(b, caja * (0.75 + 0.5 * v), caja * (0.6 + 0.4 * v),
			Color(claro.r, claro.g, claro.b, 0.45 * alfa), maxf(1.5, caja * 0.07 * (1.0 - v)))


# LATIGAZO: el tentaculo azota desde lejos y lo que se ve es LO QUE DEJA -- los verdugones cruzados
# sobre el golpeado. Se reusa el huso de borde dentado del zarpazo (_surco), que es exactamente la
# forma de una marca de azote: gorda por el medio y en punta por los dos extremos.
#
# La diferencia con el zarpazo es que aqui son POCAS marcas, largas y cruzadas en angulos distintos
# (un latigo no da cuatro surcos paralelos), y va con el tentaculo entrando de fuera.
func _pintar_latigazo(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, 0.32, 0.10)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	# EL TENTACULO entrando: una linea gruesa y combada que llega de fuera y se retira. Es lo que
	# dice que el golpe viene de LEJOS, que es la gracia de la habilidad.
	var ent: float = clampf(v / 0.30, 0.0, 1.0)
	if v < 0.55:
		var lado: float = 1.0 if sin(g * 2.3) > 0.0 else -1.0
		var desde := b + Vector2(lado * caja * 2.2, -caja * 0.9)
		var pts := PackedVector2Array()
		for i in 9:
			var s: float = float(i) / 8.0
			var p: Vector2 = desde.lerp(b, s * ent)
			# Combado: un latigo no llega recto.
			p.y += sin(s * PI) * caja * 0.42 * (1.0 - ent * 0.5)
			pts.append(p)
		draw_polyline(pts, Color(col.r * 0.7, col.g * 0.6, col.b * 0.75,
			0.7 * alfa * (1.0 - v / 0.55)), maxf(2.0, caja * 0.07), true)
	# LOS VERDUGONES: dos o tres, largos y CRUZADOS en angulos distintos. Escalonados, para que se
	# lean como varios azotes seguidos y no como una equis dibujada de golpe.
	for i in 3:
		var k: float = clampf((v - float(i) * 0.10) / 0.22, 0.0, 1.0)
		if k <= 0.0:
			continue
		var ang: float = -0.9 + sin(g * 1.9 + float(i) * 2.7) * 1.1
		var dir := Vector2(cos(ang), sin(ang))
		var off: Vector2 = Vector2(-dir.y, dir.x) * (float(i) - 1.0) * caja * 0.22
		var largo: float = caja * 1.5 * (0.82 + 0.18 * absf(sin(g + float(i))))
		# Se traza de una punta a la otra, como el zarpazo: un latigo pasa, no aparece.
		var eje: Vector2 = b + off - dir * largo * 0.5
		# En CARNE VIVA, no en hueso: esto no te abre como una garra, te levanta la piel.
		_surco(eje + dir * largo * k * 0.5, dir, largo * k, caja * 0.075, g + float(i) * 5.1,
			alfa, Color(0.82, 0.22, 0.20))


func _anillo(c: Vector2, rx: float, ry: float, col: Color, grosor: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var ang: float = TAU * float(i) / 32.0
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	draw_polyline(pts, col, grosor, true)


# ============================================================
#  LAS ARMAS DEL JUGADOR
# ============================================================
# Hasta ahora todo lo del jugador iba con MELEE, o sea sin dibujo. Estos son los primeros gestos
# suyos, y tienen una regla que los de los bichos no tienen: EL ACERO NO SE TIÑE ENTERO.
#
# El color que llega aqui es el de la IMBUICION (verde con veneno, naranja con fuego) o el acero de
# _color_golpe si no hay ninguna. Si con eso se pintara la hoja entera, un tajo envenenado parecia
# una espada de plastico verde. Asi que la hoja va SIEMPRE en metal y el color manda en el FILO y en
# la estela, que es donde de verdad se ve el veneno: en el rastro que deja el corte.
const _ACERO := Color(0.78, 0.82, 0.88)
const _ACERO_OSCURO := Color(0.34, 0.38, 0.45)

# LO QUE DURA UNTAR LA HOJA, en tiempo de animacion (los segundos de reloj salen de dividirlo por
# CombatFX.RITMO_BASE, o sea que 1.10 son ~1.6 s). Va LARGO a proposito: no es un golpe, es un gesto
# que hay que ver entero -- el bote recorriendo la hoja y el veneno quedandose detras. Con la coleta
# corta de un ataque, el frasco cruzaba de un lado a otro antes de que te diera tiempo a mirarlo.
#
# ESTE NUMERO Y EL DE _vida TIENEN QUE SER EL MISMO: por eso es una constante y no dos literales.
# Descuadrarlos es lo que le corto la animacion al aura a un tercio (ver la nota en _vida).
const COLETA_IMBUIR := 1.10


# ¿Lleva veneno/fuego encima, o es acero pelado? Cuando NO hay imbuicion el filo se pinta de un
# blanco frio en vez de "gris sobre gris", que no se veia.
#
# Se compara con el gris EXACTO que manda combat.gd. Antes se adivinaba por lo saturado que fuera el
# color y ese mismo gris se colaba como imbuido por un error de coma flotante (ver CombatFX.ACERO):
# el resultado era que la Puñalada sin imbuir destellaba en gris.
func _imbuido(col: Color) -> bool:
	var a: Color = CombatFX.ACERO
	return absf(col.r - a.r) > 0.02 or absf(col.g - a.g) > 0.02 or absf(col.b - a.b) > 0.02


# El color del FILO: el de la imbuicion si la hay, y si no un blanco frio de reflejo.
func _filo_col(col: Color) -> Color:
	return col if _imbuido(col) else Color(0.93, 0.97, 1.0)


# UNA HOJA. Un huso afilado por un extremo y romo por el otro (el mango), en acero, con el filo
# marcado a un lado. 'dir' es hacia donde APUNTA la punta.
#
# Es el ladrillo del que salen todos los cortes: cambiando largo/ancho/curva se pasa de una daga a
# un mandoble sin escribir otro painter.
func _hoja(p: Vector2, dir: Vector2, largo: float, ancho: float, col: Color, alfa: float,
		curva: float = 0.0) -> void:
	var lado := Vector2(-dir.y, dir.x)
	var n: int = 10
	var izq := PackedVector2Array()
	var der := PackedVector2Array()
	for i in n + 1:
		var s: float = float(i) / float(n)       # 0 = punta, 1 = mango
		# El perfil: afilado del todo en la punta y con cuerpo en el resto. El pow bajo mantiene
		# ancha la parte de atras, que es lo que hace que se lea como una hoja y no como una aguja.
		var w: float = ancho * pow(s, 0.55) * (1.0 - 0.25 * s)
		w = maxf(w, ancho * 0.04)
		# La curva desplaza el lomo: con 0 sale recta (estoque, daga), con mas sale de sable.
		var desvio: float = curva * largo * s * s * 0.5
		var eje: Vector2 = p + dir * (-largo * s) + lado * desvio
		izq.append(eje + lado * w)
		der.append(eje - lado * w)
	var pts := PackedVector2Array()
	pts.append_array(izq)
	for i in range(der.size() - 1, -1, -1):
		pts.append(der[i])
	draw_colored_polygon(pts, Color(_ACERO.r, _ACERO.g, _ACERO.b, alfa))
	# EL CONTORNO OSCURO ES LO QUE LA HACE VERSE. Sin el, la hoja es acero claro encima de una estela
	# clara y las dos se funden en una cinta: no se distinguia el arma del rastro que deja.
	var cerrado := PackedVector2Array(pts)
	cerrado.append(pts[0])
	draw_polyline(cerrado, Color(_ENCIA.r, _ENCIA.g, _ENCIA.b, 0.75 * alfa),
		maxf(1.0, ancho * 0.24), true)
	# EL FILO, por un solo lado: es la linea que lleva el color de la imbuicion.
	var f: Color = _filo_col(col)
	draw_polyline(izq, Color(f.r, f.g, f.b, alfa), maxf(1.5, ancho * 0.34), true)
	# Y el lomo, mas oscuro que la hoja, que es lo que le da grosor.
	draw_polyline(der, Color(_ACERO_OSCURO.r, _ACERO_OSCURO.g, _ACERO_OSCURO.b, 0.9 * alfa),
		maxf(1.0, ancho * 0.26), true)


# EL TRAZO de un tajo: la cinta que deja el filo al CRUZAR. Va de un lado al otro pasando por el
# centro de la tarjeta, y va CASI RECTA.
#
# La comba empezo siendo generosa ("el arco que describe el brazo") y estaba mal: nadie corta a
# traves de algo describiendo una curva. El brazo gira, pero el filo que ATRAVIESA entra y sale por
# una linea. Ahora las combas son de 0.03-0.07, lo justo para que el trazo no sea una regla, y la
# unica caida recta del todo es la del Tajo del verdugo, que baja a plomo.
#
# ESTO ES TODO LO QUE SE DIBUJA DE UN CORTE: ni la hoja, ni una marca de herida aparte. Solo el
# trazo. Se probaron las dos y las dos sobran: la hoja parece un objeto flotando y la marca, una
# raya extra pegada al lado que no pinta nada.
# (mas abajo, lo de la hoja)  La hoja NO se pinta. Se intento -- primero apuntando
# hacia donde iba el trazo y despues de canto -- y las dos veces se veia raro: un arma entera
# suspendida a mitad de un arco no se lee como un tajo, se lee como un objeto flotando, y encima
# competia con la propia cinta (las dos son claras y curvas). Lo que cuenta un corte es POR DONDE HA
# PASADO EL FILO. La hoja solo se dibuja donde el arma esta QUIETA y es la protagonista: untando el
# veneno, en la postura de guardia o clavada al final de una estocada.
#
# EMPEZO SIENDO UN ARCO ALREDEDOR del objetivo (centro + radio), y estaba mal: el trazo orbitaba por
# fuera de la tarjeta en vez de atravesarla, asi que el corte se veia AL LADO del bicho y no encima.
# Un tajo cruza; lo que orbita es una honda.
#
# 'k' es cuanto lleva recorrido (0..1): la cabeza va en k y la cola se queda atras.
#
# Devuelve [cabeza, tangente, NORMAL]. La normal es la que hay que darle a _hoja: una espada que
# BARRE va de canto -- la punta apunta hacia AFUERA del arco y lo que avanza es el filo. Poniendola
# en la tangente (o sea apuntando hacia donde va) parecia una lanza volando de lado, y era justo lo
# que hacia que los tajos se vieran raros: el dibujo iba en una direccion y el movimiento en otra.
func _tajo(centro: Vector2, ang: float, largo: float, comba: float, k: float,
		col: Color, alfa: float, grosor: float, elem: int = 0, sem: float = 0.0) -> Array:
	var dir := Vector2(cos(ang), sin(ang))
	var lado := Vector2(-dir.y, dir.x)
	var a: Vector2 = centro - dir * largo * 0.5
	var b: Vector2 = centro + dir * largo * 0.5
	# El punto de control saca la curva de la recta: es lo que convierte el corte en un arco de brazo.
	var ctrl: Vector2 = centro + lado * comba * largo
	# EL ELEMENTO NO ES UN COLOR, ES UN COMPORTAMIENTO. Teñir el mismo trazo de naranja, azul o
	# amarillo no colaba: no parecia ni fuego ni agua ni rayo, parecia el mismo tajo de tres colores.
	# El rayo se QUIEBRA y parpadea, el fuego ONDEA y suelta chispas, el agua GOTEA.
	var es_rayo: bool = elem == Elementos.Elemento.RAYO
	var es_fuego: bool = elem == Elementos.Elemento.FUEGO
	var es_agua: bool = elem == Elementos.Elemento.AGUA
	var n: int = 26 if es_rayo else 14
	var izq := PackedVector2Array()
	var der := PackedVector2Array()
	var eje := PackedVector2Array()
	var cabeza: Vector2 = a
	var tang: Vector2 = dir
	var kk: float = maxf(k, 0.001)
	for i in n + 1:
		var s: float = float(i) / float(n) * kk
		var p: Vector2 = _bez(a, ctrl, b, s)
		var t2: Vector2 = (_bez(a, ctrl, b, minf(s + 0.02, 1.0)) - p)
		var d2: Vector2 = t2.normalized() if t2.length() > 0.01 else dir
		var l2 := Vector2(-d2.y, d2.x)
		# EL RAYO NO VA RECTO: el eje se quiebra a un lado y a otro, con los extremos clavados (si no,
		# el trazo se despegaria del arma y del objetivo).
		if es_rayo:
			var borde: float = sin(PI * clampf(float(i) / float(n), 0.0, 1.0))
			var q: float = sin(sem + float(i) * 2.7) * 0.6 + sin(sem * 1.7 + float(i) * 5.3) * 0.4
			p += l2 * q * grosor * 1.9 * borde
		# La cinta es GORDA en la cabeza y se afila hacia la cola: lo viejo del trazo ya se borra.
		var w: float = grosor * pow(float(i) / float(n), 1.1)
		# El FUEGO ondea por el borde de fuera, como una llama tumbada.
		if es_fuego:
			w *= 1.0 + 0.45 * sin(sem * 2.1 + float(i) * 1.9)
		# El AGUA tambien, pero suave y redondeado: es una lamina de liquido, no una llama.
		elif es_agua:
			w *= 1.0 + 0.22 * sin(sem * 1.3 + float(i) * 1.1)
		izq.append(p + l2 * w)
		der.append(p - l2 * w)
		eje.append(p)
		cabeza = p
		tang = d2
	if k > 0.02:
		var pts := PackedVector2Array()
		pts.append_array(izq)
		for i in range(der.size() - 1, -1, -1):
			pts.append(der[i])
		var f: Color = _filo_col(col)
		# El RAYO PARPADEA: no se apaga suave, va a tirones.
		var a2: float = alfa
		if es_rayo:
			a2 *= 0.55 + 0.45 * absf(sin(sem * 9.0 + k * 22.0))
		# El relleno va FLOJO: es aire cortado, no un objeto.
		draw_colored_polygon(pts, Color(f.r, f.g, f.b, 0.26 * a2))
		# El canto, mas vivo y fino: es por donde ha pasado el filo.
		draw_polyline(izq, Color(f.r, f.g, f.b, 0.9 * a2), maxf(1.5, grosor * 0.38), true)
		if es_rayo:
			# El nucleo blanco del rayo, por el eje, y unas ramitas que saltan de el.
			draw_polyline(eje, Color(1.0, 0.99, 0.92, 0.9 * a2), maxf(1.5, grosor * 0.25), true)
			for i in range(2, eje.size() - 1, 5):
				var u := Vector2(cos(sem + float(i)), sin(sem * 1.3 + float(i)))
				draw_line(eje[i], eje[i] + u * grosor * 2.6,
					Color(f.r, f.g, f.b, 0.7 * a2), maxf(1.0, grosor * 0.18), true)
		elif es_fuego:
			# CHISPAS saltando del filo hacia arriba, que es lo que dice fuego y no naranja.
			for i in range(1, eje.size(), 3):
				var sube: float = grosor * (1.2 + 2.4 * absf(sin(sem * 3.1 + float(i))))
				var p2: Vector2 = eje[i] + Vector2(sin(sem + float(i) * 2.3) * grosor * 0.8, -sube)
				draw_circle(p2, maxf(1.0, grosor * 0.22 * (1.0 - float(i) / float(eje.size()))),
					Color(1.0, 0.72 + 0.2 * absf(sin(sem + float(i))), 0.30, 0.85 * alfa))
		elif es_agua:
			# GOTAS que se desprenden y caen del trazo. Van cada DOS puntos y gordas: con menos y mas
			# pequeñas era un trazo azul con dos motas, y no se leia el agua.
			for i in range(1, eje.size(), 2):
				var cae: float = grosor * (0.9 + 3.4 * absf(sin(sem * 2.7 + float(i))))
				var p3: Vector2 = eje[i] + Vector2(sin(sem + float(i)) * grosor * 0.6, cae)
				var r3: float = maxf(1.5, grosor * 0.34 * (0.45 + 0.55 * float(i) / float(eje.size())))
				draw_circle(p3, r3, Color(f.r, f.g, minf(1.0, f.b + 0.15), 0.85 * alfa))
				# Y el hilillo por el que resbala, que es lo que la ata al corte.
				draw_line(eje[i], p3, Color(f.r, f.g, minf(1.0, f.b + 0.15), 0.45 * alfa),
					maxf(1.0, grosor * 0.10), true)
	# La normal apunta al lado de la COMBA, que es hacia donde se abre el arco.
	var signo: float = 1.0 if comba >= 0.0 else -1.0
	return [cabeza, tang, tang.rotated(PI * 0.5 * signo)]


# Bezier cuadratica. Godot trae la cubica en Vector2.bezier_interpolate, pero para una comba simple
# la cuadratica es la que se controla con UN solo punto, que es justo lo que se quiere aqui.
func _bez(a: Vector2, c: Vector2, b: Vector2, s: float) -> Vector2:
	var u: float = 1.0 - s
	return a * (u * u) + c * (2.0 * u * s) + b * (s * s)


# CORTE DE DAGA. Un tajo corto y rapido: la hoja barre un arco pequeño y deja su estela, y donde ha
# pasado queda el corte abierto. Lo usan el basico y la Rafaga (con la coleta mas corta: son dos
# tajos seguidos y con la larga se pisaban).
#
# El angulo sale de la SEMILLA, asi que dos cortes seguidos caen cruzados sin tener que dibujar la X
# a mano -- y en dual, cada mano trae el suyo.
func _pintar_daga_corte(e: Dictionary) -> void:
	var rapido: bool = int(e["estilo"]) == CombatFX.Estilo.DAGA_RAFAGA
	var coleta: float = 0.20 if rapido else 0.24
	var r0: Array = _golpe_cuerpo(e, coleta, 0.10)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	# Diagonal con hasta medio radian de desvio, y a veces del otro lado: un picaro no repite el
	# mismo tajo dos veces.
	var sentido: float = 1.0 if sin(g * 5.7) > 0.0 else -1.0
	var ang: float = (-PI * 0.30 + sin(g * 3.3) * 0.35) * sentido
	# El tajo CRUZA la tarjeta entera y se sale un poco por los lados: un corte que se queda dentro
	# del recuadro parece un rasguño.
	var largo: float = caja * (1.25 if rapido else 1.45)
	# 0.05 como el resto: un corte que atraviesa va recto. Esta se quedo en 0.20 cuando se
	# enderezaron los demas porque la comba iba en una VARIABLE y el barrido buscaba numeros sueltos.
	var comba: float = 0.05 * sentido
	# Entra de golpe y frena: 1-(1-v)^2 pone casi todo el recorrido al principio, que es como pasa
	# una hoja de verdad -- rapidisima al cruzar y lenta al rematar.
	var k: float = 1.0 - pow(1.0 - v, 2.0)
	_tajo(b, ang, largo, comba, k, col, alfa, caja * 0.075, int(e.get("elem", 0)), float(e["semilla"]))
	# EL CORTE que queda en la carne, cuando ya ha pasado la hoja. Dos lineas finas (labio y sombra)
	# y no el huso dentado del zarpazo: una daga deja un tajo limpio, y con el dentado parecia una
	# pluma pegada encima.


# PUÑALADA. NO es un corte: la hoja se arma atras, entra RECTA y se hunde hasta el mango. Por eso no
# tiene estela de arco -- lo que se ve es el retroceso, el pinchazo y la hoja clavada.
func _pintar_punalada(e: Dictionary) -> void:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	# Entra desde abajo-fuera, con el angulo desviado por la semilla.
	var ang: float = -PI * 0.5 + sin(g * 2.9) * 0.7
	var dir := Vector2(cos(ang), sin(ang))
	var b: Vector2 = e["b"] + Vector2(cos(g * 2.1), sin(g * 1.7)) * caja * 0.10
	# Corta y con cuerpo: es una daga. Larga y fina se leia como un estoque.
	var largo: float = caja * 0.44
	if t < dur:
		# ARMANDO: la hoja espera echada atras, temblando. Este instante es lo que la separa de un
		# tajo cualquiera -- se ve que va apuntada.
		var w: float = clampf(t / dur, 0.0, 1.0)
		var atras: float = caja * (0.75 - 0.15 * w) + sin(t * 40.0) * caja * 0.02
		_hoja(b - dir * atras, dir, largo, caja * 0.085, col, 0.55 + 0.45 * w)
		return
	var v: float = clampf((t - dur) / 0.34, 0.0, 1.0)
	var alfa: float = 1.0 if v < 0.62 else 1.0 - (v - 0.62) / 0.38
	if alfa <= 0.0:
		return
	# LA ENTRADA: de golpe y hasta el fondo en el primer tercio.
	var k: float = clampf(v / 0.30, 0.0, 1.0)
	var hundido: float = 1.0 - pow(1.0 - k, 3.0)
	var punta: Vector2 = b - dir * caja * 0.60 * (1.0 - hundido) + dir * caja * 0.28 * hundido
	_hoja(punta, dir, largo, caja * 0.085, col, alfa)
	# EL PINCHAZO donde entra. Una puñalada no abre un tajo: hace un AGUJERO, asi que va un ovalo
	# oscuro con el borde del color y nada mas. Antes era el huso dentado del zarpazo y a tamaño real
	# parecia una oruga pegada a la punta -- ese dentado es para algo que te ARRASTRA, no para algo
	# que entra limpio.
	if k > 0.5:
		var w2: float = (k - 0.5) / 0.5
		var f: Color = _filo_col(col)
		# EL DESTELLO. Esta habilidad es la jugada gorda de la daga y tiene que lucir como tal, no
		# quedarse en un agujerito. El color lo pone lo que lleve el arma: SANGRE a pelo, y el de la
		# imbuicion cuando la hay -- verde con veneno, naranja con fuego.
		# Sin imbuicion, ROJO VIVO y no el _SANGRE del catalogo: ese es un granate oscuro pensado para
		# pintarse SOBRE algo (la linea de una herida), y como fogonazo sobre el fondo oscuro de la
		# pelea no se veia -- solo quedaba el nucleo blanco y parecia un destello gris.
		var fuera: Color = col if _imbuido(col) else Color(0.95, 0.22, 0.16)
		var dentro: Color = Color(minf(1.0, fuera.r + 0.35), minf(1.0, fuera.g + 0.30),
			minf(1.0, fuera.b + 0.25))
		# Estalla EN LA PUNTA, no en el centro de la tarjeta: es el fogonazo de la hoja entrando.
		# 'mordida_c' es el campo que _destello ya mira para eso (lo usan las dentelladas).
		e["mordida_c"] = punta
		# EL RELOJ DEL DESTELLO ES 'v', NO 'w2'. w2 sale de la profundidad de la hoja, que se satura a
		# 1 en cuanto se hunde (v > 0.30) y ahi se queda: le llegaba siempre el final de la curva, o
		# sea el fogonazo ya apagado, y no se veia mas que una crucecita suelta. Con 'v' entra por el
		# 0.14 -- el pico de _destello -- justo al hundirse y se va apagando durante todo el resto.
		_destello(e, 0.14 + v * 0.60, fuera, dentro, 0.95)
		var lado := Vector2(-dir.y, dir.x)
		var rx: float = caja * 0.075 * w2
		var pts := PackedVector2Array()
		for i in 12:
			var ang2: float = TAU * float(i) / 12.0
			# Alargado en la direccion de entrada: por ahi ha metido la hoja.
			pts.append(punta + lado * cos(ang2) * rx + dir * sin(ang2) * rx * 1.7)
		draw_colored_polygon(pts, Color(_SANGRE.r * 0.5, _SANGRE.g * 0.3, _SANGRE.b * 0.3,
			0.85 * alfa))
		var cerrado := PackedVector2Array(pts)
		cerrado.append(pts[0])
		draw_polyline(cerrado, Color(f.r, f.g, f.b, 0.9 * alfa), maxf(1.5, caja * 0.022), true)


# FILO EMPONZOÑADO. La daga TUMBADA y un bote que la recorre de la guarda a la punta echandole el
# veneno: por donde ya ha pasado, la hoja se queda verde.
#
# EMPEZO SIENDO una hoja vertical con el liquido resbalando y no valia: no se entendia de donde
# salia el veneno ni por que la hoja cambiaba de color. Lo que lo cuenta es ver el BOTE moverse y el
# color quedandose DETRAS de el, que es como se unta una hoja de verdad.
#
# El color sale de la imbuicion (verde el veneno), asi que si algun dia se emponzoña con otra cosa,
# se tiñe de lo suyo sin tocar esto.
func _pintar_imbuir_filo(e: Dictionary) -> void:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var b: Vector2 = e["b"]
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var v: float = clampf((t - dur) / COLETA_IMBUIR, 0.0, 1.0) if t > dur else 0.0
	var alfa: float = 1.0 if v < 0.78 else 1.0 - (v - 0.78) / 0.22
	if alfa <= 0.0:
		return
	# La daga se presenta durante el vuelo (entra desde abajo) y ahi se queda quieta mientras la untan.
	var entra: float = clampf(t / dur, 0.0, 1.0)
	var centro: Vector2 = b + Vector2(0.0, caja * 0.30 * (1.0 - entra) + caja * 0.05)
	var largo: float = caja * 0.92
	var ancho: float = caja * 0.085
	# De izquierda a derecha: mango, guarda y hoja.
	var base := Vector2(centro.x - largo * 0.30, centro.y)      # donde acaba la guarda y empieza la hoja
	var punta := Vector2(base.x + largo, base.y)
	# EL AVANCE DEL BOTE. Se toma su tiempo en la primera mitad de la coleta y luego se queda: asi da
	# tiempo a leer el recorrido y a ver la hoja entera ya verde antes de que se vaya.
	var avance: float = clampf(v / 0.55, 0.0, 1.0)

	# --- LA DAGA -------------------------------------------------------------------------------
	# Mango y pomo, a la izquierda de la guarda.
	var mango_a := Vector2(base.x - largo * 0.20, base.y)
	draw_line(mango_a, base, Color(0.32, 0.24, 0.20, alfa), maxf(2.0, ancho * 0.85), true)
	draw_circle(mango_a, maxf(2.0, ancho * 0.42), Color(0.42, 0.34, 0.26, alfa))
	# La guarda: la cruz vertical entre el mango y la hoja.
	draw_line(base + Vector2(0.0, -ancho * 1.5), base + Vector2(0.0, ancho * 1.5),
		Color(_ACERO_OSCURO.r, _ACERO_OSCURO.g, _ACERO_OSCURO.b, alfa), maxf(2.0, ancho * 0.55), true)
	# La hoja en acero, entera, y encima el tramo ya mojado.
	_hoja_tumbada(base, punta, ancho, 0.0, 1.0, _ACERO, alfa, true)
	if avance > 0.01:
		_hoja_tumbada(base, punta, ancho, 0.0, avance, col, 0.92 * alfa, false)

	# --- EL BOTE -------------------------------------------------------------------------------
	# Va por delante del borde mojado, que es lo que hace que se lea que el color sale DE EL.
	var bx: float = lerpf(base.x, punta.x, avance)
	var bote := Vector2(bx, base.y - caja * 0.30)
	var rb: float = caja * 0.11
	# Cuerpo, cuello y tapon: un frasco de boticario, inclinado hacia la hoja.
	var cuerpo := PackedVector2Array()
	for i in 14:
		var a: float = TAU * float(i) / 14.0
		cuerpo.append(bote + Vector2(cos(a) * rb * 0.85, sin(a) * rb))
	# El cristal va TEÑIDO de lo que lleva dentro, no gris a secas: un frasco de veneno se ve verde
	# aunque el vidrio no lo sea. Sin esto el bote se leia como un trozo de piedra al lado de la hoja.
	var vidrio: Color = Color(0.30, 0.36, 0.34).lerp(col, 0.45)
	draw_colored_polygon(cuerpo, Color(vidrio.r, vidrio.g, vidrio.b, 0.95 * alfa))
	# El veneno que le queda dentro, por la mitad de abajo.
	var dentro := PackedVector2Array()
	for i in 9:
		var a2: float = PI * float(i) / 8.0
		dentro.append(bote + Vector2(cos(a2) * rb * 0.62, sin(a2) * rb * 0.72))
	draw_colored_polygon(dentro, Color(col.r, col.g, col.b, 0.9 * alfa))
	draw_line(bote + Vector2(0.0, rb * 0.6), bote + Vector2(0.0, rb * 1.5),
		Color(vidrio.r, vidrio.g, vidrio.b, 0.95 * alfa), maxf(2.0, rb * 0.5), true)

	# --- EL CHORRO ------------------------------------------------------------------------------
	# Del cuello del bote a la hoja, ondulando un poco. Solo mientras esta echando.
	if avance > 0.0 and avance < 1.0:
		var boca: Vector2 = bote + Vector2(0.0, rb * 1.5)
		var n: int = 7
		var hilo := PackedVector2Array()
		for i in n + 1:
			var s: float = float(i) / float(n)
			hilo.append(Vector2(
				lerpf(boca.x, bx, s) + sin(t * 13.0 + s * 5.0 + g) * caja * 0.012,
				lerpf(boca.y, base.y, s)))
		draw_polyline(hilo, Color(col.r, col.g, col.b, 0.9 * alfa), maxf(1.5, caja * 0.022), true)
		# Y la gota que salpica donde cae.
		draw_circle(Vector2(bx, base.y), caja * 0.03 * (1.0 + 0.3 * sin(t * 16.0 + g)),
			Color(col.r, col.g, col.b, 0.85 * alfa))


# Media daga tumbada: el poligono de la hoja entre dos fracciones de su largo (s0..s1), para poder
# pintar el trozo YA MOJADO encima del acero sin recortes ni mascaras.
#
# 'contorno' solo lo pide la pasada de acero: repetirlo en la del veneno dibujaba un borde oscuro en
# mitad de la hoja, justo por donde iba el bote.
func _hoja_tumbada(base: Vector2, punta: Vector2, ancho: float, s0: float, s1: float,
		col: Color, alfa: float, contorno: bool) -> void:
	var n: int = 12
	var arriba := PackedVector2Array()
	var abajo := PackedVector2Array()
	for i in n + 1:
		var s: float = lerpf(s0, s1, float(i) / float(n))
		# Perfil: casi recto y solo se afila al final, que es lo que le da aire de hoja de daga.
		var w: float = ancho * (1.0 - pow(s, 3.0)) * (0.75 + 0.25 * (1.0 - s))
		var p: Vector2 = base.lerp(punta, s)
		arriba.append(Vector2(p.x, p.y - w))
		abajo.append(Vector2(p.x, p.y + w * 0.55))   # el filo va por abajo: mas plano
	var pts := PackedVector2Array()
	pts.append_array(arriba)
	for i in range(abajo.size() - 1, -1, -1):
		pts.append(abajo[i])
	draw_colored_polygon(pts, Color(col.r, col.g, col.b, alfa))
	if contorno:
		var cerrado := PackedVector2Array(pts)
		cerrado.append(pts[0])
		draw_polyline(cerrado, Color(_ENCIA.r, _ENCIA.g, _ENCIA.b, 0.7 * alfa),
			maxf(1.0, ancho * 0.22), true)


# DESAPARECER: LA SOMBRA, y solo la sombra. Se pinta sobre TI -- el que se esfuma es el que ataca --
# mientras el corte va por su cuenta contra el enemigo (un DAGA_CORTE normal, ver su fx_estilo).
func _pintar_desvanecer(e: Dictionary) -> void:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var b: Vector2 = e["b"]
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	# LA SOMBRA se abre durante el vuelo y se deshace en la coleta.
	var abre: float = clampf(t / dur, 0.0, 1.0)
	var v: float = clampf((t - dur) / 0.30, 0.0, 1.0) if t > dur else 0.0
	var alfa: float = 1.0 if v < 0.5 else 1.0 - (v - 0.5) / 0.5
	if alfa <= 0.0:
		return
	# LA MANCHA. Muchos puntos y poca variacion: con once y un 45% de desvio salia una ESTRELLA de
	# cinco puntas enorme tapando la tarjeta, porque los picos y los valles caian alternos. Una
	# sombra es un borrón de bordes inquietos, no un pentagrama.
	var n: int = 18
	var pts := PackedVector2Array()
	for i in n:
		var ang: float = TAU * float(i) / float(n) + g
		var jiron: float = 1.0 + 0.16 * sin(g * 2.3 + float(i) * 2.1) \
			+ 0.08 * sin(g + float(i) * 5.3)
		var r: float = caja * (0.26 + 0.14 * abre) * jiron * (1.0 + v * 0.5)
		pts.append(b + Vector2(cos(ang) * r, sin(ang) * r * 0.78))
	draw_colored_polygon(pts, Color(0.05, 0.04, 0.10, 0.6 * alfa * (1.0 - v * 0.8)))
	# Y LOS JIRONES, aparte: hebras finas que salen despedidas al deshacerse. Van sueltas y no como
	# picos del contorno, que es lo que convertia la mancha en una estrella.
	if v > 0.0:
		for i in 7:
			var ang2: float = TAU * float(i) / 7.0 + g * 1.7
			var largo2: float = caja * (0.20 + 0.42 * v) * (0.7 + 0.5 * absf(sin(g + float(i) * 3.7)))
			var u2 := Vector2(cos(ang2), sin(ang2) * 0.78)
			draw_line(b + u2 * caja * 0.20, b + u2 * (caja * 0.20 + largo2),
				Color(0.06, 0.05, 0.12, 0.55 * alfa * (1.0 - v)), maxf(1.5, caja * 0.035), true)
	# AQUI NO HAY TAJO. El corte de Desaparecer es un DAGA_CORTE normal contra el enemigo (su
	# fx_estilo); esto es solo la sombra, y va sobre TI. Antes se dibujaban las dos cosas juntas
	# sobre el que recibia el golpe, o sea que el humo parecia suyo cuando el que se esfuma eres tu.


# ============================================================
#  EL ESTOQUE: todo de punta
# ============================================================
# La daga CORTA (arcos que cruzan) y el estoque PINCHA: su hoja entra en linea recta y lo que se lee
# es la profundidad y lo seco de la entrada. Por eso ninguno de estos usa _tajo.
#
# LAS COLETAS VIVEN AQUI ARRIBA porque _vida tiene que devolver EXACTAMENTE lo mismo que use el
# painter para dividir su reloj. Con dos literales sueltos, el dia que se toque uno el efecto se
# corta a media animacion sin dar ningun error (le paso al aura, ver la nota en _vida).
const COLETA_ESTOCADA := 0.26
const COLETA_FINTAS := 0.30      # son dos pinchazos: hace falta sitio para los dos
const COLETA_PENETRANTE := 0.42  # entra hasta el fondo y hay que verla salir por detras
const COLETA_PASO := 0.34        # el rastro del que se aparta tarda en irse
const COLETA_NERVIO := 0.38      # el latigazo recorre al bicho despues del pinchazo
const COLETA_DANZA := 0.40       # tres tiempos encadenados
const COLETA_GUARDIA := 0.85     # es una postura, no un golpe: tiene que quedarse puesta

# La hoja del estoque: LARGA y FINA, al reves que la daga (corta y con cuerpo). Es lo que separa las
# dos armas de un vistazo aunque las dos entren rectas.
const LARGO_ESTOQUE := 1.15
const ANCHO_ESTOQUE := 0.042


# EL GESTO BASE DE TODA ESTOCADA: la punta se arma atras, sale disparada, se hunde y vuelve.
# Devuelve [avance 0..1, alfa, punta, direccion] o avance < 0 si todavia se esta armando (en cuyo
# caso ya ha pintado la hoja esperando).
#
# 'prof' = cuanto se hunde, en fracciones de la caja. 'coleta' tiene que ser la misma constante que
# devuelva _vida para este estilo.
func _estocada_base(e: Dictionary, coleta: float, prof: float, largo_mult: float = 1.0,
		desvio_ang: float = 0.7) -> Array:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	# Entra desde abajo, con el angulo desviado por la semilla: dos estocadas seguidas no caen
	# calcadas una encima de otra.
	var ang: float = -PI * 0.5 + sin(g * 2.9) * desvio_ang
	var dir := Vector2(cos(ang), sin(ang))
	var b: Vector2 = e["b"] + Vector2(cos(g * 2.1), sin(g * 1.7)) * caja * 0.09
	var largo: float = caja * LARGO_ESTOQUE * largo_mult
	var ancho: float = caja * ANCHO_ESTOQUE
	if t < dur:
		# ARMANDO: la hoja espera echada atras, temblando. Este instante es lo que hace que se lea
		# como una estocada apuntada.
		var w: float = clampf(t / dur, 0.0, 1.0)
		var atras: float = caja * (0.85 - 0.20 * w) + sin(t * 44.0) * caja * 0.015
		_hoja(b - dir * atras, dir, largo, ancho, col, 0.5 + 0.5 * w)
		return [-1.0, 0.0, Vector2.ZERO, dir]
	var v: float = clampf((t - dur) / coleta, 0.0, 1.0)
	var alfa: float = 1.0 if v < 0.60 else 1.0 - (v - 0.60) / 0.40
	if alfa <= 0.0:
		return [-1.0, 0.0, Vector2.ZERO, dir]
	# La entrada se come el primer cuarto y luego la hoja se queda clavada un momento.
	var k: float = clampf(v / 0.25, 0.0, 1.0)
	var hundido: float = 1.0 - pow(1.0 - k, 3.0)
	var punta: Vector2 = b - dir * caja * 0.70 * (1.0 - hundido) + dir * caja * prof * hundido
	_hoja(punta, dir, largo, ancho, col, alfa)
	return [v, alfa, punta, dir]


# EL AGUJERO que deja una punta. Un ovalo alargado en la direccion de entrada, oscuro por dentro y
# con el borde del color de lo que lleve el arma. Lo comparten todas las del estoque.
func _pinchazo(p: Vector2, dir: Vector2, r: float, col: Color, alfa: float) -> void:
	var lado := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array()
	for i in 12:
		var a: float = TAU * float(i) / 12.0
		pts.append(p + lado * cos(a) * r + dir * sin(a) * r * 1.8)
	draw_colored_polygon(pts, Color(_SANGRE.r * 0.5, _SANGRE.g * 0.3, _SANGRE.b * 0.3, 0.85 * alfa))
	var f: Color = _filo_col(col)
	var cerrado := PackedVector2Array(pts)
	cerrado.append(pts[0])
	draw_polyline(cerrado, Color(f.r, f.g, f.b, 0.9 * alfa), maxf(1.5, r * 0.30), true)


# ESTOCADA. Tres habilidades comparten painter porque las tres son la misma jugada con distinto
# tamaño: el basico pincha, las Fintas pinchan dos veces seguidas y la Penetrante ATRAVIESA.
func _pintar_estocada(e: Dictionary) -> void:
	var estilo: int = int(e["estilo"])
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var coleta: float = COLETA_ESTOCADA
	var prof: float = 0.24
	var largo_mult: float = 1.0
	if estilo == CombatFX.Estilo.FINTAS:
		coleta = COLETA_FINTAS
		prof = 0.18
		largo_mult = 0.92
	elif estilo == CombatFX.Estilo.ESTOCADA_PENETRANTE:
		coleta = COLETA_PENETRANTE
		prof = 0.62      # hasta el fondo: la punta sale por el otro lado
		largo_mult = 1.15
	var r0: Array = _estocada_base(e, coleta, prof, largo_mult)
	var v: float = r0[0]
	if v < 0.0:
		return
	var alfa: float = r0[1]
	var punta: Vector2 = r0[2]
	var dir: Vector2 = r0[3]
	var k: float = clampf(v / 0.25, 0.0, 1.0)
	if k > 0.5:
		var w: float = (k - 0.5) / 0.5
		_pinchazo(punta, dir, caja * 0.055 * w, col, alfa)
	# LA PENETRANTE, ademas, revienta la guardia: un destello en el punto de entrada y la punta
	# asomando por detras. Es la jugada gorda del estoque y tiene que verse como tal.
	if estilo == CombatFX.Estilo.ESTOCADA_PENETRANTE and k > 0.4:
		var fuera: Color = col if _imbuido(col) else Color(0.95, 0.22, 0.16)
		var dentro: Color = Color(minf(1.0, fuera.r + 0.35), minf(1.0, fuera.g + 0.30),
			minf(1.0, fuera.b + 0.25))
		e["mordida_c"] = punta
		_destello(e, 0.14 + v * 0.60, fuera, dentro, 0.85)
	# LAS FINTAS SON DOS GOLPES, y cada golpe trae UNA estocada: la segunda entra desplazada porque
	# su evento tiene otra semilla. Antes este painter dibujaba las dos, asi que con los dos golpes
	# de la habilidad salian CUATRO estoques.


# EN GUARDIA. No es un golpe: es una POSTURA. La hoja se levanta delante de ti y se queda quieta,
# con el arco de la guardia abriendose alrededor. Se pinta sobre tu propia tarjeta.
func _pintar_en_guardia(e: Dictionary) -> void:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var b: Vector2 = e["b"]
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var monta: float = clampf(t / dur, 0.0, 1.0)
	var v: float = clampf((t - dur) / COLETA_GUARDIA, 0.0, 1.0) if t > dur else 0.0
	var alfa: float = 1.0 if v < 0.75 else 1.0 - (v - 0.75) / 0.25
	if alfa <= 0.0:
		return
	# LA HOJA EN ALTO, apuntando arriba y un poco ladeada: la posicion de saludo del duelista.
	var ang: float = -PI * 0.5 + 0.30 + sin(g) * 0.10
	var dir := Vector2(cos(ang), sin(ang))
	var p: Vector2 = b + Vector2(caja * 0.10, caja * (0.45 - 0.45 * monta))
	_hoja(p, dir, caja * LARGO_ESTOQUE * 0.95, caja * ANCHO_ESTOQUE, col, alfa)
	# EL ARCO DE LA GUARDIA: el semicirculo que barre la punta al cubrirse. Se abre al montar y
	# respira mientras dura.
	var f: Color = _filo_col(col)
	var r: float = caja * (0.30 + 0.32 * monta) * (1.0 + 0.04 * sin(t * 5.0 + g))
	var arco := PackedVector2Array()
	for i in 17:
		var a: float = PI * 1.15 + PI * 0.70 * float(i) / 16.0
		arco.append(b + Vector2(cos(a) * r, sin(a) * r * 0.85))
	draw_polyline(arco, Color(f.r, f.g, f.b, 0.55 * alfa), maxf(1.5, caja * 0.025), true)
	# Y las dos marcas de los pies: el paso de duelo, uno delante y otro detras.
	for i in 2:
		var lado: float = 1.0 if i == 0 else -1.0
		draw_line(b + Vector2(lado * caja * 0.22, caja * 0.62),
			b + Vector2(lado * caja * 0.38, caja * 0.62),
			Color(f.r, f.g, f.b, 0.35 * alfa * monta), maxf(1.5, caja * 0.02), true)


# PASO LIGERO. La estocada se da MIENTRAS te apartas: se ve la silueta de la hoja donde estabas,
# desvaneciendose, y la de verdad ya desplazada a un lado.
func _pintar_paso_ligero(e: Dictionary) -> void:
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var r0: Array = _estocada_base(e, COLETA_PASO, 0.20, 0.95)
	var v: float = r0[0]
	if v < 0.0:
		return
	var alfa: float = r0[1]
	var punta: Vector2 = r0[2]
	var dir: Vector2 = r0[3]
	# EL RASTRO: dos siluetas de la hoja detras, cada vez mas transparentes y mas atras, en la
	# direccion del paso. Es lo que cuenta que te has movido.
	var paso := Vector2(1.0 if sin(g * 5.7) > 0.0 else -1.0, -0.25).normalized()
	for i in 2:
		var d: float = caja * 0.22 * float(i + 1)
		_hoja(punta - paso * d, dir, caja * LARGO_ESTOQUE * 0.95, caja * ANCHO_ESTOQUE,
			col, alfa * (0.30 - 0.10 * float(i)))
	var k: float = clampf(v / 0.25, 0.0, 1.0)
	if k > 0.5:
		_pinchazo(punta, dir, caja * 0.048 * ((k - 0.5) / 0.5), col, alfa)


# PUNZADA AL NERVIO. No busca el organo, busca el cable: un pinchazo fino y, desde el, un latigazo
# que recorre al bicho en zigzag -- el nervio que se dispara.
func _pintar_punzada_nervio(e: Dictionary) -> void:
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var r0: Array = _estocada_base(e, COLETA_NERVIO, 0.26, 0.95, 0.45)
	var v: float = r0[0]
	if v < 0.0:
		return
	var alfa: float = r0[1]
	var punta: Vector2 = r0[2]
	var dir: Vector2 = r0[3]
	var k: float = clampf(v / 0.25, 0.0, 1.0)
	if k > 0.5:
		_pinchazo(punta, dir, caja * 0.042 * ((k - 0.5) / 0.5), col, alfa)
	# EL NERVIO: una linea quebrada que sale del pinchazo y sube, como una descarga. Crece por
	# tramos, que es lo que hace que se lea como algo que RECORRE y no como un dibujo puesto.
	if v <= 0.35:
		return
	var w: float = clampf((v - 0.35) / 0.45, 0.0, 1.0)
	var f: Color = _filo_col(col)
	var n: int = 7
	var linea := PackedVector2Array()
	for i in n + 1:
		var s: float = float(i) / float(n) * w
		# SUBE POR EL CUERPO del bicho, no por la hoja. Iba en la direccion de la estocada (o sea de
		# vuelta hacia el mango) y el zigzag caia justo encima del arma: parecia que la hoja estaba
		# rota, no que algo recorriera al que lo ha recibido.
		linea.append(punta + Vector2(sin(g + s * 11.0) * caja * 0.13 * s, -caja * 0.75 * s))
	if linea.size() >= 2:
		draw_polyline(linea, Color(f.r, f.g, f.b, 0.85 * alfa), maxf(1.5, caja * 0.022), true)
		# Los nudos del recorrido: donde el latigazo salta, un punto mas gordo.
		for i in range(1, linea.size(), 2):
			draw_circle(linea[i], caja * 0.022, Color(f.r, f.g, f.b, 0.7 * alfa))


# DANZA DE ACERO. Tres tiempos encadenados sin bajar la punta: tres estocadas en abanico que entran
# escalonadas, como las garras del zarpazo, pero de punta.
func _pintar_danza_acero(e: Dictionary) -> void:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var b: Vector2 = e["b"]
	if t < dur:
		# Se arma UNA vez, apuntando al centro: las tres salen de la misma guardia.
		var w0: float = clampf(t / dur, 0.0, 1.0)
		_hoja(b + Vector2(0.0, caja * (0.90 - 0.20 * w0)), Vector2.UP,
			caja * LARGO_ESTOQUE, caja * ANCHO_ESTOQUE, col, 0.5 + 0.5 * w0)
		return
	var v: float = clampf((t - dur) / COLETA_DANZA, 0.0, 1.0)
	var alfa_g: float = 1.0 if v < 0.62 else 1.0 - (v - 0.62) / 0.38
	if alfa_g <= 0.0:
		return
	# UN TIEMPO POR GOLPE. La habilidad pega TRES veces y cada una clava en su sitio del abanico.
	# Pintando los tres tiempos en cada golpe salian NUEVE estocadas para una habilidad de tres.
	var i: int = mini(int(e.get("golpe", 0)), 2)
	var k: float = clampf(v / 0.28, 0.0, 1.0)
	if k <= 0.0:
		return
	# EL ABANICO SE ABRE POR DONDE CLAVA, no por el mango. Girando la direccion desde un mismo
	# punto, las tres puntas acababan JUNTAS arriba y los mangos abiertos abajo: salia un tripode
	# con los tres pinchazos apilados en el mismo sitio. Lo que hace falta es al reves -- tres
	# sitios distintos donde clavar, y las hojas entrando casi paralelas desde abajo.
	var destino: Vector2 = b + Vector2((float(i) - 1.0) * caja * 0.30,
		sin(g + float(i) * 2.1) * caja * 0.10)
	var ang: float = -PI * 0.5 + (float(i) - 1.0) * 0.12 + sin(g + float(i)) * 0.05
	var dir := Vector2(cos(ang), sin(ang))
	var hundido: float = 1.0 - pow(1.0 - k, 3.0)
	var punta: Vector2 = destino - dir * caja * 0.75 * (1.0 - hundido) \
		+ dir * caja * 0.14 * hundido
	var alfa: float = alfa_g * (1.0 if k < 0.75 else 1.0 - (k - 0.75) / 0.25 * 0.45)
	_hoja(punta, dir, caja * LARGO_ESTOQUE * 0.90, caja * ANCHO_ESTOQUE, col, alfa)
	if k > 0.6:
		_pinchazo(punta, dir, caja * 0.040 * ((k - 0.6) / 0.4), col, alfa)


# ============================================================
#  LA ESPADA CORTA: cortar con cuerpo
# ============================================================
# Corta como la daga, pero la hoja pesa: trazos mas amplios, mas anchos y menos nerviosos. Reusa el
# mismo _tajo (la cinta combada que cruza la tarjeta) con otros numeros -- que es justo para lo que
# se hizo parametrizable.
#
# Las coletas, en constantes, porque _vida tiene que devolver EXACTAMENTE lo mismo que divida el
# painter (ver la nota del aura en _vida).
const COLETA_ESPADA := 0.30
const COLETA_ESPADA_RAPIDA := 0.24   # Cambio de ritmo: encadena, no puede pisarse
const COLETA_DOBLE_TAJO := 0.52      # los dos cortes, la cruz cerrandose y el destello
const COLETA_QUEBRANTADOR := 0.42    # hay que ver saltar la guardia
const COLETA_SENALAR := 0.40         # los dos cortes y la diana que se queda
const COLETA_TENDONES := 0.36

const LARGO_ESPADA := 0.52    # de caja: casi el doble que la daga (0.34)
const ANCHO_ESPADA := 0.135


# EL TAJO DE ESPADA. Lo comparten el basico, el Doble tajo y el Cambio de ritmo: los tres son el
# mismo corte con distinto tempo. Devuelve [avance, alfa, centro, angulo, sentido] para que las
# habilidades le puedan añadir lo suyo encima sin recalcularlo.
func _espada_tajo_base(e: Dictionary, coleta: float, largo_mult: float = 1.0) -> Array:
	var r0: Array = _golpe_cuerpo(e, coleta, 0.09)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return [-1.0, 0.0, Vector2.ZERO, 0.0, 1.0]
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var sentido: float = 1.0 if sin(g * 5.7) > 0.0 else -1.0
	var ang: float = (-PI * 0.28 + sin(g * 3.3) * 0.30) * sentido
	var largo: float = caja * 1.55 * largo_mult
	var k: float = 1.0 - pow(1.0 - v, 2.0)
	_tajo(b, ang, largo, 0.05 * sentido, k, col, alfa, caja * 0.095, int(e.get("elem", 0)), float(e["semilla"]))
	return [v, alfa, b, ang, sentido]


func _pintar_espada_tajo(e: Dictionary) -> void:
	var estilo: int = int(e["estilo"])
	var coleta: float = COLETA_ESPADA
	var largo_mult: float = 1.0
	if estilo == CombatFX.Estilo.DOBLE_TAJO or estilo == CombatFX.Estilo.CAMBIO_RITMO:
		coleta = COLETA_ESPADA_RAPIDA
		largo_mult = 0.88
	var r: Array = _espada_tajo_base(e, coleta, largo_mult)
	var v: float = r[0]
	if v < 0.0:
		return
	# CAMBIO DE RITMO: el compas que se rompe. Cuatro marcas en fila que se van juntando -- la
	# cadencia acelerando-- y la ultima adelantada del todo. No hace daño de verdad; lo que cuenta
	# es que se lea "he cambiado el tempo".
	if estilo != CombatFX.Estilo.CAMBIO_RITMO:
		return
	var alfa: float = r[1]
	var b: Vector2 = r[2]
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var f: Color = _filo_col(e["col"])
	var w2: float = clampf(v / 0.55, 0.0, 1.0)
	for i in 4:
		# Las marcas se acercan entre si segun avanza: empiezan repartidas y acaban apretadas.
		var sep: float = lerpf(0.30, 0.13, w2)
		var x: float = (float(i) - 1.5) * caja * sep
		var alt: float = caja * (0.16 + 0.06 * float(i % 2))
		var y: float = -caja * 0.62
		var a2: float = alfa * clampf((w2 - float(i) * 0.12) / 0.3, 0.0, 1.0)
		if a2 <= 0.0:
			continue
		draw_line(b + Vector2(x, y - alt * 0.5), b + Vector2(x, y + alt * 0.5),
			Color(f.r, f.g, f.b, 0.8 * a2), maxf(1.5, caja * 0.022), true)


# TAJO QUEBRANTADOR. El tajo entra y REVIENTA LA GUARDIA: delante del bicho hay un arco -- su
# defensa-- que se raja y salta en pedazos. Es lo que cuenta que ha quedado expuesto.
func _pintar_quebrantador(e: Dictionary) -> void:
	var r: Array = _espada_tajo_base(e, COLETA_QUEBRANTADOR, 1.12)
	var v: float = r[0]
	if v < 0.0:
		return
	var alfa: float = r[1]
	var b: Vector2 = r[2]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	# LA GUARDIA REVENTANDO. El dibujo vive en _guardia_rompiendose (mas abajo, con la maza): esta y
	# el Aplastamiento hacen LA MISMA jugada -- abrirle la defensa -- y tienen que verse igual.
	_guardia_rompiendose(b, caja * 0.62, _filo_col(e["col"]), alfa,
		clampf((v - 0.18) / 0.45, 0.0, 1.0), g, caja)


# SEÑALAR EL HUECO. Dos cortes EN EL MISMO SITIO -- no repartidos, insistiendo en el mismo punto -- y
# una diana que se queda puesta encima: es una MARCA para los tuyos, no un golpe mas.
#
# UN CORTE POR GOLPE, como el Doble tajo: la habilidad pega dos veces y cada vez traza uno. Pintar
# los dos en cada golpe sacaba cuatro cortes y dos dianas.
func _pintar_senalar_hueco(e: Dictionary) -> void:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	if t < dur:
		return
	var v: float = clampf((t - dur) / COLETA_SENALAR, 0.0, 1.0)
	var alfa: float = 1.0 if v < 0.62 else 1.0 - (v - 0.62) / 0.38
	if alfa <= 0.0:
		return
	# El punto EXACTO donde se insiste: siempre el mismo para los dos cortes.
	var p: Vector2 = e["b"] + Vector2(cos(g * 2.1), sin(g * 1.7)) * caja * 0.14
	var f: Color = _filo_col(col)
	# EL CORTE QUE LE TOCA A ESTE GOLPE. El segundo cruza al primero sobre el mismo punto.
	var segundo: bool = int(e.get("golpe", 0)) > 0
	var k: float = clampf(v / 0.34, 0.0, 1.0)
	var ang: float = -PI * 0.25 + (PI * 0.5 if segundo else 0.0)
	_tajo(p, ang, caja * 0.85, 0.03, k, col, alfa, caja * 0.075,
		int(e.get("elem", 0)), float(e["semilla"]))
	# LA DIANA: dos anillos y una cruz sobre el punto. La pone el SEGUNDO corte, cuando ya se ha
	# insistido -- es lo que ven los tuyos, y va una, no una por golpe.
	if not segundo or v <= 0.45:
		return
	var w: float = clampf((v - 0.45) / 0.35, 0.0, 1.0)
	var rr: float = caja * 0.30 * (1.4 - 0.4 * w)   # se cierra sobre el punto
	_anillo(p, rr, rr * 0.9, Color(f.r, f.g, f.b, 0.9 * alfa * w), maxf(1.5, caja * 0.026))
	_anillo(p, rr * 0.55, rr * 0.5, Color(f.r, f.g, f.b, 0.7 * alfa * w), maxf(1.5, caja * 0.020))
	for i in 4:
		var a: float = TAU * float(i) / 4.0
		var u := Vector2(cos(a), sin(a))
		draw_line(p + u * rr * 1.05, p + u * rr * 1.45,
			Color(f.r, f.g, f.b, 0.85 * alfa * w), maxf(1.5, caja * 0.022), true)


# CORTE DE TENDONES. No busca el pecho: busca lo que lo sostiene. El corte va ABAJO, corto y seco, y
# de el cuelgan los tendones cortados.
func _pintar_corte_tendones(e: Dictionary) -> void:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	if t < dur:
		return
	var v: float = clampf((t - dur) / COLETA_TENDONES, 0.0, 1.0)
	var alfa: float = 1.0 if v < 0.58 else 1.0 - (v - 0.58) / 0.42
	if alfa <= 0.0:
		return
	# ABAJO del todo de la tarjeta: a la altura de las piernas, no del pecho.
	var b: Vector2 = e["b"] + Vector2(sin(g) * caja * 0.10, caja * 0.52)
	var f: Color = _filo_col(col) if _imbuido(col) else _HUESO
	# El corte: casi horizontal y corto, de un lado al otro.
	var k: float = 1.0 - pow(1.0 - v, 2.0)
	_tajo(b, 0.12 + sin(g * 2.3) * 0.10, caja * 0.95, 0.03, k, col, alfa, caja * 0.070, int(e.get("elem", 0)), float(e["semilla"]))
	if v <= 0.40:
		return
	# LOS TENDONES: tres hilos que se sueltan y se enrollan hacia abajo. Es lo que dice que lo que se
	# ha cortado es lo que lo sostenia.
	var w: float = (v - 0.40) / 0.60
	for i in 3:
		var x: float = (float(i) - 1.0) * caja * 0.20 + sin(g + float(i) * 2.7) * caja * 0.04
		var largo: float = caja * (0.16 + 0.14 * w)
		var hilo := PackedVector2Array()
		for j in 6:
			var s: float = float(j) / 5.0
			# Se riza al soltarse: la punta se va para un lado.
			hilo.append(b + Vector2(x + sin(g + float(i) + s * 4.5) * caja * 0.05 * s * w,
				largo * s))
		draw_polyline(hilo, Color(f.r, f.g, f.b, 0.85 * alfa), maxf(1.5, caja * 0.020), true)
		draw_circle(hilo[hilo.size() - 1], caja * 0.018,
			Color(_SANGRE.r, _SANGRE.g, _SANGRE.b, 0.7 * alfa))


# ============================================================
#  LA ESPADA LARGA (y el escudo)
# ============================================================
# Los tajos de la espada larga CAEN, no barren: pesan, y lo que se lee es la caida. Por eso casi
# todos van de arriba abajo en vez de cruzar en diagonal como los de la corta.
const COLETA_LARGA := 0.34
const COLETA_PESADO := 0.46        # tiene que verse caer, y el polvo se queda
const COLETA_DESARMANTE := 0.40
const COLETA_GUARDIA_ROTA := 0.34
const COLETA_VOTO := 0.85          # postura: se queda puesta
const COLETA_MARCIAL := 0.34
const COLETA_VOZ := 0.55
const COLETA_ESCUDAZO := 0.30

# CUANTO SE APARTAN las dos manos, en fracciones de caja. El golpe de ARMA cae a un lado y el de
# ESCUDO al otro, para que dos golpes de la misma habilidad no se pinten uno encima del otro.
#
# Es UNA constante y no dos literales porque los dos painters (_pintar_escudazo y el del arma que
# toque) tienen que sumar y restar EXACTAMENTE lo mismo: descuadrarlos deja los golpes o pegados o
# tan separados que se salen de la tarjeta.
const DESVIO_MANO := 0.26

const LARGO_LARGA := 0.78          # de caja: la hoja mas larga hasta ahora
# 0.105 y no 0.155: con aquel, la hoja salia tan ancha respecto a su largo que parecia un cono
# cayendo, no una espada. Una espada larga es larga, no gorda.
const ANCHO_LARGA := 0.105


# EL TAJO QUE CAE. Base del basico, del Tajo pesado y del Desarmante: los tres son la misma hoja
# cayendo con distinta fuerza. 'alto' = desde donde arranca (1.0 = por encima de la tarjeta).
# Devuelve [avance, alfa, centro] o avance < 0 si aun no toca.
func _tajo_que_cae(e: Dictionary, coleta: float, largo_mult: float, alto: float) -> Array:
	var r0: Array = _golpe_cuerpo(e, coleta, 0.08)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return [-1.0, 0.0, Vector2.ZERO]
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	# Cae casi vertical, con un poco de inclinacion segun la semilla (a veces de un lado, a veces
	# del otro): un mandoble no barre de lado a lado, se deja caer.
	var inclina: float = sin(g * 3.3) * 0.35
	# LA HOJA APUNTA HACIA DONDE CAE. Se calculaba el angulo por un lado (PI/2 + inclina) y la
	# trayectoria por otro (sin(inclina), 1), y los dos NO COINCIDIAN: la X salia con el signo
	# cambiado, asi que la espada apuntaba en diagonal hacia un lado mientras se desplazaba hacia el
	# otro. Se veia rarisimo, y con razon. Ahora hay UNA sola direccion y de ella salen las dos cosas.
	var dir_caida := Vector2(sin(inclina), 1.0).normalized()
	var ang: float = dir_caida.angle()
	var largo: float = caja * 1.30 * largo_mult
	# La caida se come el primer tercio y frena de golpe al llegar: es un impacto, no un barrido.
	var k: float = clampf(v / 0.34, 0.0, 1.0)
	var caida: float = 1.0 - pow(1.0 - k, 2.6)
	var arriba: Vector2 = b - dir_caida * caja * alto
	var p: Vector2 = arriba.lerp(b, caida)
	# EL TRAZO DEL FILO CAYENDO. Es el MISMO lenguaje que los tajos de arco: lo que se ve es por
	# donde ha pasado el filo, no la espada flotando en el aire. Antes se dibujaba la hoja entera
	# bajando y se leia como una cuchilla suspendida; ademas la estela quedaba tan floja que no
	# contaba nada.
	#
	# Se reusa _tajo con la comba a cero: una caida es un tajo recto. El centro va a mitad de camino
	# para que el trazo arranque arriba y su cabeza llegue justo al objetivo.
	var recorrido: float = arriba.distance_to(b)
	_tajo(arriba.lerp(b, 0.5), ang, recorrido, 0.0, caida, col, alfa,
		caja * 0.10 * largo_mult, int(e.get("elem", 0)), float(e["semilla"]))
	return [v, alfa, b]


func _pintar_espada_larga(e: Dictionary) -> void:
	var estilo: int = int(e["estilo"])
	var coleta: float = COLETA_LARGA
	var largo_mult: float = 1.0
	var alto: float = 0.95
	if estilo == CombatFX.Estilo.TAJO_PESADO:
		coleta = COLETA_PESADO
		largo_mult = 1.15
		alto = 1.35        # arranca MUY arriba: es lo que le da el peso
	elif estilo == CombatFX.Estilo.GUARDIA_ROTA:
		coleta = COLETA_GUARDIA_ROTA
		largo_mult = 0.95
	var r: Array = _tajo_que_cae(e, coleta, largo_mult, alto)
	var v: float = r[0]
	if v < 0.0 or estilo != CombatFX.Estilo.TAJO_PESADO:
		return
	# EL TAJO PESADO levanta polvo al llegar: una onda baja a ras, como la del pisoton. Es lo que
	# cuenta que ha caido con todo el peso y no es un tajo mas.
	#
	# EMPIEZA EN 0.36 y no antes: la caida termina en 0.34 (ver _tajo_que_cae), asi que con el 0.30
	# el polvo se levantaba ANTES de que la hoja llegara al suelo.
	if v <= 0.36:
		return
	var alfa: float = r[1]
	var b: Vector2 = r[2]
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var w: float = (v - 0.36) / 0.64
	var rr: float = caja * (0.25 + 0.85 * w)
	_anillo(b + Vector2(0.0, caja * 0.20), rr, rr * 0.26,
		Color(0.72, 0.68, 0.62, 0.55 * alfa * (1.0 - w)), maxf(1.5, caja * 0.030 * (1.0 - w * 0.6)))


# TAJO DESARMANTE. El corte va ALTO, al brazo con el que sujeta el arma, y del golpe sale despedida
# el arma del bicho: eso es lo que dice "ahora pega menos".
func _pintar_desarmante(e: Dictionary) -> void:
	var r: Array = _tajo_que_cae(e, COLETA_DESARMANTE, 0.95, 0.85)
	var v: float = r[0]
	if v < 0.0 or v <= 0.32:
		return
	var alfa: float = r[1]
	var b: Vector2 = r[2]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var col: Color = e["col"]
	# EL ARMA QUE SALTA: una hoja pequeña girando y cayendo hacia un lado.
	var w: float = (v - 0.32) / 0.68
	var lado: float = 1.0 if sin(g * 5.7) > 0.0 else -1.0
	# Parabola: sale hacia arriba y se cae.
	var p: Vector2 = b + Vector2(lado * caja * 0.85 * w,
		-caja * 0.55 * sin(w * PI) + caja * 0.20 * w)
	var giro: float = w * 7.0 * lado
	_hoja(p, Vector2(cos(giro), sin(giro)), caja * 0.42, caja * 0.075,
		col, alfa * (1.0 - w * 0.6), 0.15)


# VOTO DE GUARDIA. Clavas los pies y cierras: no es un ataque. Un escudo grande delante de tu propia
# tarjeta, las marcas de los pies clavados y la espada apoyada detras.
func _pintar_voto_guardia(e: Dictionary) -> void:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var b: Vector2 = e["b"]
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var monta: float = clampf(t / dur, 0.0, 1.0)
	var v: float = clampf((t - dur) / COLETA_VOTO, 0.0, 1.0) if t > dur else 0.0
	var alfa: float = 1.0 if v < 0.78 else 1.0 - (v - 0.78) / 0.22
	if alfa <= 0.0:
		return
	var f: Color = _filo_col(col)
	# LA ESPADA, apoyada en vertical por detras del escudo.
	_hoja(b + Vector2(caja * 0.30, -caja * 0.10), Vector2.UP, caja * LARGO_LARGA, caja * ANCHO_LARGA,
		col, alfa * 0.85, 0.0)
	# EL ESCUDO: sube desde abajo hasta cubrirte. Es la forma de _escudo_cara, comun con el ESCUDAZO.
	var c: Vector2 = b + Vector2(0.0, caja * (0.50 - 0.50 * monta))
	_escudo_cara(c, caja * 0.46, col, alfa, 0.0, int(e.get("escudo", -1)))
	# LOS PIES CLAVADOS: dos marcas gordas debajo, y unas rayas de que no se mueve de ahi.
	for i in 2:
		var lado: float = 1.0 if i == 0 else -1.0
		var p: Vector2 = b + Vector2(lado * caja * 0.30, caja * 0.66)
		draw_line(p - Vector2(caja * 0.10, 0.0), p + Vector2(caja * 0.10, 0.0),
			Color(f.r, f.g, f.b, 0.7 * alfa * monta), maxf(2.0, caja * 0.030), true)
		for j in 2:
			var d: float = caja * (0.05 + 0.05 * float(j))
			draw_line(p + Vector2(lado * (caja * 0.12 + d), -caja * 0.03),
				p + Vector2(lado * (caja * 0.12 + d), caja * 0.03),
				Color(f.r, f.g, f.b, 0.35 * alfa * monta), maxf(1.0, caja * 0.016), true)
	# Y un aro de "por aqui no pasa nadie" que respira.
	var rr: float = caja * 0.62 * (1.0 + 0.03 * sin(t * 4.0 + g))
	_anillo(b, rr, rr * 0.52, Color(f.r, f.g, f.b, 0.30 * alfa * monta), maxf(1.5, caja * 0.022))


# EL PERFIL DE CADA ESCUDO, en fracciones de su radio. Los tres del juego se distinguen por el
# TAMAÑO -- es su eje de balance: el bloqueo va por ahi y ni el tier ni la rareza lo tocan --, asi
# que tienen que distinguirse tambien de un vistazo, y durante mucho tiempo los tres pintaron la
# misma chapa.
#
# No basta con hacerlos mas grandes o mas pequeños: a tamaño de tarjeta esa diferencia no se lee, y
# ademas cada gesto ya escala el suyo por su cuenta. Lo que se lee es la SILUETA:
#   PEQUENO  RODELA: redondo. Es el de esquivar y responder, no el de taparse
#   NORMAL   HEATER: recto arriba y en punta abajo, el escudo de caballero de toda la vida
#   GRANDE   TORRE: un rectangulo alto, casi una puerta. El del que se planta y no se mueve
# DOCE vertices y no ocho: con ocho sale un OCTOGONO, y un octogono no es un escudo redondo -- se
# lee como una señal de trafico. A partir de doce el ojo ya lo da por circular.
const _PERFIL_RODELA := [Vector2(0.0, -1.0), Vector2(0.50, -0.87), Vector2(0.87, -0.50),
	Vector2(1.0, 0.0), Vector2(0.87, 0.50), Vector2(0.50, 0.87), Vector2(0.0, 1.0),
	Vector2(-0.50, 0.87), Vector2(-0.87, 0.50), Vector2(-1.0, 0.0), Vector2(-0.87, -0.50),
	Vector2(-0.50, -0.87)]
const _PERFIL_HEATER := [Vector2(-1.0, -0.85), Vector2(1.0, -0.85), Vector2(1.0, 0.05),
	Vector2(0.72, 0.62), Vector2(0.0, 1.0), Vector2(-0.72, 0.62), Vector2(-1.0, 0.05)]
# La TORRE va mas estrecha (0.82) y mucho mas alta (1.30) que las otras dos: lo que la hace enorme
# no es ocupar mas a lo ancho -- eso se sale de la tarjeta -- sino tapar de arriba abajo.
const _PERFIL_TORRE := [Vector2(-0.82, -1.30), Vector2(-0.62, -1.42), Vector2(0.62, -1.42),
	Vector2(0.82, -1.30), Vector2(0.82, 1.22), Vector2(0.62, 1.34), Vector2(-0.62, 1.34),
	Vector2(-0.82, 1.22)]


# LA CARA DE UN ESCUDO, con su reborde y su blason. La comparten el Voto de guardia, el ESCUDAZO, la
# Provocacion, la Guardia de carne, la Cobertura y la Embestida.
#
# 'tam' es un ShieldData.Tamano y viene del que pega (Combatant.fx_escudo). -1 = no se sabe o no
# lleva escudo: se queda con el heater, que es el de en medio y el que menos chirria.
func _escudo_cara(c: Vector2, r: float, col: Color, alfa: float, giro: float = 0.0,
		tam: int = -1) -> void:
	var perfil: Array = _PERFIL_HEATER
	if tam == 0:
		perfil = _PERFIL_RODELA
	elif tam == 2:
		perfil = _PERFIL_TORRE
	var pts := PackedVector2Array()
	for q in perfil:
		var p: Vector2 = (q as Vector2) * r
		pts.append(c + p.rotated(giro))
	draw_colored_polygon(pts, Color(0.42, 0.45, 0.52, 0.95 * alfa))
	var cerrado := PackedVector2Array(pts)
	cerrado.append(pts[0])
	# El REBORDE lleva el color del arma: si vas imbuido, el escudo tambien va.
	var f: Color = _filo_col(col)
	draw_polyline(cerrado, Color(f.r, f.g, f.b, 0.9 * alfa), maxf(2.0, r * 0.10), true)
	# EL BLASON, distinto por escudo: es lo que remata la lectura cuando la silueta se ve pequeña.
	if tam == 0:
		# La rodela lleva BOLLON (el chichon central) y un aro: es lo que la hace redonda de verdad
		# y no un circulo pelado.
		_anillo(c, r * 0.62, r * 0.62, Color(f.r, f.g, f.b, 0.40 * alfa), maxf(1.5, r * 0.08))
		draw_circle(c, maxf(2.0, r * 0.26), Color(f.r, f.g, f.b, 0.55 * alfa))
	elif tam == 2:
		# La torre lleva REFUERZOS verticales, como los tablones de una puerta.
		for i in 2:
			var x: float = (float(i) * 2.0 - 1.0) * r * 0.34
			draw_line(c + Vector2(x, -r * 1.30).rotated(giro),
				c + Vector2(x, r * 1.22).rotated(giro),
				Color(f.r, f.g, f.b, 0.35 * alfa), maxf(1.5, r * 0.09), true)
	else:
		# Y el heater, la banda cruzada de siempre.
		draw_line(c + Vector2(-r * 0.75, -r * 0.30).rotated(giro),
			c + Vector2(r * 0.75, r * 0.10).rotated(giro),
			Color(f.r, f.g, f.b, 0.45 * alfa), maxf(1.5, r * 0.11), true)


# ESCUDAZO. El golpe con el escudo: el canto entra de frente, sin filo ni estela -- es una plancha
# que se estampa. Y suelta el anillo de impacto de un golpe romo.
#
# NO ES DE NINGUN ARMA: lo pide cualquier golpe que la habilidad marque como de escudo (la Guardia
# rota de la espada larga, el Aplastamiento de la maza, los Golpes de escudo...). Ver combat.gd.
func _pintar_escudazo(e: Dictionary) -> void:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	if t < dur:
		return
	var v: float = clampf((t - dur) / COLETA_ESCUDAZO, 0.0, 1.0)
	var alfa: float = 1.0 if v < 0.55 else 1.0 - (v - 0.55) / 0.45
	if alfa <= 0.0:
		return
	var b: Vector2 = e["b"] + Vector2(cos(g * 2.1), sin(g * 1.7)) * caja * 0.08
	# EL ESCUDO ENTRA POR EL OTRO LADO. Un golpe de escudo nunca es el primero de su habilidad (lo
	# pide escudo_desde_golpe, siempre despues del golpe de arma), y las dos manos no pegan en el
	# mismo sitio: la del arma por un lado y la del escudo por el otro.
	#
	# Sin esto se SOLAPABAN. En el Aplastamiento el mazazo y el escudazo caian los dos en el centro de
	# la tarjeta con dos decimas de diferencia, asi que el escudo entraba encima de la mancha del
	# mazazo y no se leia que fueran dos golpes distintos -- que es justo lo que cuenta esa habilidad.
	# Vale igual para la Guardia rota de la espada larga.
	if int(e.get("golpe", 0)) > 0:
		b.x += caja * DESVIO_MANO
	# Entra de golpe desde abajo y rebota un poco: es un empujon, no un corte.
	var k: float = clampf(v / 0.26, 0.0, 1.0)
	var entra: float = 1.0 - pow(1.0 - k, 3.0)
	var retro: float = 0.0 if v < 0.30 else minf((v - 0.30) / 0.40, 1.0) * 0.22
	var p: Vector2 = b + Vector2(0.0, caja * (0.70 * (1.0 - entra) + retro))
	# 0.36 y no 0.42: la plancha se comia su propio impacto -- el anillo y las rayas quedaban DEBAJO
	# del escudo y solo asomaban por el borde.
	_escudo_cara(p, caja * 0.36, col, alfa, sin(g) * 0.12, int(e.get("escudo", -1)))
	# EL PORRAZO: anillo romo y corto, nada de filos. Y unas rayas de impacto.
	if k <= 0.55:
		return
	var w: float = (k - 0.55) / 0.45
	var f: Color = _filo_col(col)
	# El anillo arranca ya POR FUERA del escudo (0.38) y se abre desde ahi: asi el porrazo se ve
	# alrededor de la plancha en vez de por debajo.
	var rr: float = caja * (0.38 + 0.55 * w)
	_anillo(b, rr, rr * 0.62, Color(f.r, f.g, f.b, 0.75 * alfa * (1.0 - w)),
		maxf(1.5, caja * 0.034 * (1.0 - w * 0.5)))
	for i in 5:
		var a: float = -PI * 0.5 + (float(i) - 2.0) * 0.42 + sin(g + float(i)) * 0.10
		var u := Vector2(cos(a), sin(a))
		draw_line(b + u * rr * 0.80, b + u * rr * (1.15 + 0.25 * w),
			Color(f.r, f.g, f.b, 0.6 * alfa * (1.0 - w)), maxf(1.5, caja * 0.024), true)


# VOZ DE MANDO. No es un golpe ni va contra nadie: es una orden, y se pinta sobre LOS TUYOS (llega
# por _fx_adorno con la lista de aliados). Dos arcos que salen hacia arriba y una flecha corta que
# los empuja: los pies se mueven antes de pensarla.
func _pintar_voz_mando(e: Dictionary) -> void:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var b: Vector2 = e["b"]
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var sale: float = clampf(t / dur, 0.0, 1.0)
	var v: float = clampf((t - dur) / COLETA_VOZ, 0.0, 1.0) if t > dur else 0.0
	var alfa: float = 1.0 if v < 0.55 else 1.0 - (v - 0.55) / 0.45
	if alfa <= 0.0:
		return
	var f: Color = _filo_col(col)
	# LOS ARCOS de la voz: tres, saliendo de abajo y abriendose hacia arriba, escalonados.
	for i in 3:
		var k: float = clampf((sale + v * 1.4 - float(i) * 0.22) / 0.6, 0.0, 1.0)
		if k <= 0.0:
			continue
		var rr: float = caja * (0.20 + 0.42 * k)
		var arco := PackedVector2Array()
		for j in 9:
			var a: float = PI * 1.18 + PI * 0.64 * float(j) / 8.0
			arco.append(b + Vector2(0.0, caja * 0.34) + Vector2(cos(a) * rr, sin(a) * rr * 0.75))
		draw_polyline(arco, Color(f.r, f.g, f.b, 0.55 * alfa * (1.0 - k * 0.55)),
			maxf(1.5, caja * 0.026 * (1.0 - k * 0.4)), true)
	# LA FLECHA que empuja: corta, hacia arriba, con la punta bien marcada.
	if v <= 0.15:
		return
	var w: float = clampf((v - 0.15) / 0.45, 0.0, 1.0)
	var subida: float = caja * (0.30 - 0.55 * w) + sin(g) * caja * 0.03
	var punta: Vector2 = b + Vector2(0.0, subida)
	draw_line(punta + Vector2(0.0, caja * 0.34), punta,
		Color(f.r, f.g, f.b, 0.9 * alfa), maxf(2.0, caja * 0.032), true)
	var tri := PackedVector2Array([punta + Vector2(0.0, -caja * 0.12),
		punta + Vector2(caja * 0.11, caja * 0.06), punta + Vector2(-caja * 0.11, caja * 0.06)])
	draw_colored_polygon(tri, Color(f.r, f.g, f.b, 0.95 * alfa))


# ESTOCADA MARCIAL. Una punta limpia POR ENCIMA del escudo: es la unica de la espada larga que no
# cae, sino que entra recta. Reusa la maquinaria del estoque -- la jugada es la misma-- pero con la
# hoja gorda de esta arma, que es lo que la separa de un estoquazo.
func _pintar_estocada_marcial(e: Dictionary) -> void:
	var col: Color = e["col"]
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var r0: Array = _estocada_base(e, COLETA_MARCIAL, 0.26, 0.80, 0.35)
	var v: float = r0[0]
	if v < 0.0:
		return
	var alfa: float = r0[1]
	var punta: Vector2 = r0[2]
	var dir: Vector2 = r0[3]
	# La hoja del estoque que ha pintado _estocada_base es fina; encima va la de espada larga, mas
	# ancha, para que se lea el arma que de verdad esta entrando.
	_hoja(punta, dir, caja * LARGO_LARGA * 0.80, caja * ANCHO_LARGA * 0.80, col, alfa, 0.06)
	var k: float = clampf(v / 0.25, 0.0, 1.0)
	if k > 0.5:
		_pinchazo(punta, dir, caja * 0.062 * ((k - 0.5) / 0.5), col, alfa)


# ============================================================
#  LOS MANDOBLES: ancho y lento
# ============================================================
# El arma grande. Todo lo suyo es mas ancho, mas lento y con mas cola que las demas, y tres de sus
# tecnicas cogen a VARIOS: esas usan e["ancho"], que en un estilo de grupo trae el ancho de TODO lo
# alcanzado (ver _marcar_efectos_de_grupo). Por eso un molinete a tres sale grande de verdad y no
# tres molinetes pequeños.
const COLETA_MANDOBLE := 0.40
const COLETA_DEVASTADOR := 0.52
const COLETA_MOLINETE := 0.46
const COLETA_GRITO := 0.44
const COLETA_VERDUGO := 0.60      # el mas largo del juego: se anuncia y hay que verlo caer
const COLETA_SEGAR := 0.44
const COLETA_ACERO_ALTO := 0.60   # el acero se queda en alto mientras dura el grito


# El tajo del mandoble: el mismo trazo de siempre pero ENORME y con mucha comba, que es lo que hace
# que se lea como un espadon y no como una espada mas.
func _pintar_mandoble_tajo(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, COLETA_MANDOBLE, 0.08)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var sentido: float = 1.0 if sin(g * 5.7) > 0.0 else -1.0
	var ang: float = (-PI * 0.22 + sin(g * 3.3) * 0.24) * sentido
	var k: float = 1.0 - pow(1.0 - v, 2.0)
	_tajo(b, ang, caja * 2.05, 0.07 * sentido, k, col, alfa, caja * 0.135, int(e.get("elem", 0)), float(e["semilla"]))


# TAJO DEVASTADOR. El descendente con toda la masa del espadon. Cae a plomo y, al llegar, levanta
# una onda gorda: es el golpe mas bruto del arsenal y tiene que verse el impacto, no solo el corte.
func _pintar_devastador(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, COLETA_DEVASTADOR, 0.06)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var inclina: float = sin(g * 3.3) * 0.28
	var dir_caida := Vector2(sin(inclina), 1.0).normalized()
	var k: float = clampf(v / 0.30, 0.0, 1.0)
	var caida: float = 1.0 - pow(1.0 - k, 2.8)
	var arriba: Vector2 = b - dir_caida * caja * 1.55
	_tajo(arriba.lerp(b, 0.5), dir_caida.angle(), arriba.distance_to(b), 0.0, caida,
		col, alfa, caja * 0.16, int(e.get("elem", 0)), float(e["semilla"]))
	# LA ONDA del impacto: dos anillos bajos que se abren. Es lo que dice "esto ha pesado".
	if v <= 0.32:
		return
	var w: float = (v - 0.32) / 0.68
	for i in 2:
		var kk: float = clampf(w - float(i) * 0.22, 0.0, 1.0)
		if kk <= 0.0:
			continue
		var rr: float = caja * (0.28 + 1.05 * kk)
		_anillo(b + Vector2(0.0, caja * 0.24), rr, rr * 0.28,
			Color(0.74, 0.70, 0.64, 0.5 * alfa * (1.0 - kk)),
			maxf(1.5, caja * 0.034 * (1.0 - kk * 0.5)))


# MOLINETE. DOS barridos que cruzan la fila entera de lado a lado. Empezo siendo un giro completo
# alrededor de los alcanzados y, aunque el aro quedaba vistoso, no se entendia lo que hacia: un
# molinete reparte TAJOS por delante, y lo que se tiene que ver es el filo pasando por encima de
# todos, no un circulo rodeandolos.
#
# Es de grupo, asi que e["ancho"] trae el ancho de TODO lo alcanzado: los barridos lo cruzan entero.
func _pintar_molinete(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, COLETA_MOLINETE, 0.05)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var largo: float = _radio_grupo(e, 1.15, caja * 1.40)
	var sentido: float = 1.0 if sin(g * 5.7) > 0.0 else -1.0
	# UN BARRIDO POR GOLPE. El espadon va y vuelve: el primer golpe cruza en un sentido y por arriba,
	# el segundo en el contrario y mas abajo. Pintar las dos pasadas en cada golpe sacaba cuatro
	# barridos para una habilidad que da dos.
	var i: int = mini(int(e.get("golpe", 0)), 1)
	var lado: float = sentido if i == 0 else -sentido
	var ang: float = (-0.16 + sin(g * 2.3 + float(i)) * 0.10) * lado
	var alto: float = caja * (-0.16 if i == 0 else 0.18)
	var c: Vector2 = b + Vector2(0.0, alto)
	var kk: float = 1.0 - pow(1.0 - clampf(v / 0.46, 0.0, 1.0), 2.0)
	_tajo(c, ang, largo, 0.04 * lado, kk, col, alfa, caja * 0.125,
		int(e.get("elem", 0)), float(e["semilla"]))


# GRITO DE GUERRA. Igual que el CHILLIDO de los bichos, porque es lo mismo: la onda SALE DEL QUE
# GRITA y barre la fila de enfrente. Ni espada ni nada que se le parezca -- el arma no toca a nadie.
#
# Se intento dos veces por el otro camino y las dos salio mal: primero pintando el espadon en alto
# sobre el que RECIBE el grito (parecia que le pegabas con el arma) y despues quitandolo de ahi pero
# poniendolo sobre el que grita, con lo que en pantalla seguia habiendo una espada y las ondas
# seguian naciendo en el enemigo. Lo que hace falta es lo que ya hacian los bichos: mirar
# _pintar_chillido y hacer lo mismo.
func _pintar_grito_guerra(e: Dictionary) -> void:
	var a: Vector2 = e["a"]          # el que grita
	var b: Vector2 = e["b"]          # a donde llega
	var col: Color = e["col"]
	var t: float = float(e["t"])
	var u: float = clampf(t / maxf(float(e["dur"]) + COLETA_GRITO, 0.05), 0.0, 1.0)
	if u >= 1.0:
		return
	var f: Color = _filo_col(col)
	# Hasta donde tiene que llegar: la fila alcanzada entera y un margen, igual que el chillido.
	var alcance: float = a.distance_to(b) + maxf(40.0, float(e["ancho"]) * 0.6)
	# CUATRO ondas desfasadas saliendo de su garganta. Mas anchas que altas: recorren la fila, no se
	# inflan como una burbuja.
	for i in 4:
		var k: float = u - float(i) * 0.15
		if k <= 0.0 or k >= 1.0:
			continue
		var rad: float = alcance * k
		_anillo(a, rad * 1.15, rad * 0.70,
			Color(f.r, f.g, f.b, 0.6 * (1.0 - k)), maxf(2.0, 7.0 * (1.0 - k)))
	# El fogonazo en la garganta, que es de donde sale todo.
	var p: float = 1.0 - clampf(u / 0.28, 0.0, 1.0)
	if p > 0.0:
		draw_circle(a, 11.0 * p, Color(f.r, f.g, f.b, 0.55 * p))


# TAJO DEL VERDUGO. Se anuncia un TURNO ENTERO y es lo mas gordo del mandoble, asi que no corta:
# REVIENTA. La referencia es el impacto de manga -- la columna de luz bajando, el anillo de choque
# abriendose a ras de suelo, los cascotes gordos saltando y las esquirlas subiendo del crater.
#
# LO MISMO VALE PARA EL MARTILLO (Golpe sismico, Temblor): esto es el lenguaje de "algo enorme ha
# caido aqui", no un adorno de esta habilidad. Cuando toque el martillo, se saca a un helper.
func _pintar_verdugo(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, COLETA_VERDUGO, 0.04)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var f: Color = _filo_col(col)
	# LA CAIDA: recta, sin inclinacion. No hay finta que valga.
	var k: float = clampf(v / 0.24, 0.0, 1.0)
	var caida: float = 1.0 - pow(1.0 - k, 3.2)
	var arriba: Vector2 = b - Vector2.DOWN * caja * 2.40
	# EL TRAZO DE LA CAIDA, y SOLO MIENTRAS CAE: en cuanto toca el suelo lo releva la columna de luz.
	# Dejandolo puesto quedaba una raya fina de mas pegada a la columna, que no contaba nada.
	if k < 1.0:
		_tajo(arriba.lerp(b, 0.5), PI * 0.5, arriba.distance_to(b), 0.0, caida, col, alfa,
			caja * 0.24, int(e.get("elem", 0)), float(e["semilla"]))
		return   # sigue bajando: el reventon es AL LLEGAR
	var w: float = clampf((v - 0.24) / 0.76, 0.0, 1.0)
	var suelo: Vector2 = b + Vector2(0.0, caja * 0.30)
	# LA COLUMNA DE LUZ. Lo que mas cuenta de todo: una barra vertical enorme que sube del crater y
	# se estrecha arriba. Entra de golpe y se apaga.
	var brillo: float = (w / 0.16) if w < 0.16 else maxf(0.0, 1.0 - (w - 0.16) / 0.84)
	if brillo > 0.0:
		var alto: float = caja * 3.4 * (0.55 + 0.45 * brillo)
		var ancho: float = caja * 0.30 * brillo
		for capa in 3:
			var m: float = 1.0 - float(capa) * 0.32
			var c: Color = Color(f.r, f.g, f.b, 0.35 * alfa * brillo) if capa == 0 				else Color(1.0, 0.99, 0.95, (0.65 if capa == 1 else 1.0) * alfa * brillo)
			var pts := PackedVector2Array([
				suelo + Vector2(-ancho * m, 0.0),
				suelo + Vector2(-ancho * m * 0.35, -alto),
				suelo + Vector2(ancho * m * 0.35, -alto),
				suelo + Vector2(ancho * m, 0.0)])
			draw_colored_polygon(pts, c)
	# Y TODO LO DEMAS -- el anillo, el crater, las esquirlas y los cascotes -- es el lenguaje de "algo
	# enorme ha caido aqui", que no es de esta habilidad: lo comparte con el martillo entero.
	_reventon_de_suelo(suelo, caja, f, alfa, w, g, 1.0)
	# Y EL FOGONAZO en la base, que es de donde sale todo. Este si es suyo: va con la columna.
	if brillo > 0.0:
		_estrella(suelo, caja * 0.85 * brillo, caja * 0.30 * brillo, 0.45,
			Color(f.r, f.g, f.b, 0.7 * alfa * brillo))
		draw_circle(suelo, maxf(2.0, caja * 0.14 * brillo), Color(1.0, 1.0, 0.98, alfa * brillo))


# ALGO ENORME HA CAIDO AQUI: el anillo de choque a ras, el crater agrietado, las esquirlas subiendo y
# los cascotes saltando en parabola. Todo lo que pasa EN EL SUELO cuando le llega un golpe que pesa.
#
# Nacio dentro del Tajo del verdugo y se saco aqui al llegar el MARTILLO GRANDE, que es el arma que
# vive de esto: tres de sus cinco tecnicas (Golpe sismico, Onda expansiva, Temblor) no golpean al
# bicho, golpean el suelo y se propagan. Es justo lo que lo separa de la maza -- la maza pega al
# CUERPO y el martillo al SUELO.
#
# NO INCLUYE la columna de luz ni el fogonazo: esos se quedan en el verdugo, que es su firma.
#
# 'esc' escala el alcance: 1.0 es el reventon del verdugo y valores mayores lo abren mas (un temblor
# que coge a cuatro tiene que llegar a los cuatro).
func _reventon_de_suelo(suelo: Vector2, caja: float, f: Color, alfa: float, w: float, g: float,
		esc: float) -> void:
	# EL ANILLO DE CHOQUE a ras de suelo: dos elipses abriendose, la de dentro mas viva.
	for i in 2:
		var kk: float = clampf((w - float(i) * 0.10) / 0.80, 0.0, 1.0)
		if kk <= 0.0:
			continue
		var rr: float = caja * (0.25 + 1.85 * kk) * esc
		_anillo(suelo, rr, rr * 0.26,
			Color(f.r, f.g, f.b, (0.75 if i == 0 else 0.45) * alfa * (1.0 - kk)),
			maxf(2.0, caja * 0.055 * (1.0 - kk * 0.55)))
	# EL CRATER: grietas gordas y negras saliendo del punto de impacto.
	for i in 6:
		var lado: float = -1.0 if i % 2 == 0 else 1.0
		var largo: float = caja * (0.50 + 1.15 * w) * esc * (0.6 + 0.5 * absf(sin(g + float(i) * 1.7)))
		var grieta := PackedVector2Array()
		for j in 5:
			var s: float = float(j) / 4.0
			grieta.append(suelo + Vector2(
				lado * largo * s * (0.55 + 0.45 * float(i) / 5.0),
				sin(g + float(i) * 2.1 + s * 6.0) * caja * 0.07 * s))
		# El grosor NO se escala con 'esc': si no, un temblor que coge a cuatro pinta grietas de 30 px
		# de gruesas y parecen vigas. (El mismo tope que ya lleva el pisoton de los bichos.)
		draw_polyline(grieta, Color(0.09, 0.08, 0.10, 0.9 * alfa * (1.0 - w * 0.3)),
			maxf(2.0, caja * 0.045 * (1.0 - w * 0.35)), true)
	# LAS ESQUIRLAS: agujas finas que salen despedidas hacia arriba desde el crater.
	for i in 9:
		var ang: float = -PI * 0.5 + (float(i) - 4.0) * 0.19 + sin(g + float(i)) * 0.07
		var u := Vector2(cos(ang), sin(ang))
		# EL ALCANCE VERTICAL TAMBIEN VA POR 'esc'. Sin escalarlo, un mazazo normal lanzaba esquirlas a
		# 1,5 cajas de altura -- o sea muy por encima de la tarjeta -- porque estos numeros salieron del
		# Tajo del verdugo, que es un espectaculo y se lo puede permitir.
		var d0: float = caja * (0.20 + 1.10 * w) * esc
		var d1: float = d0 + caja * (0.22 + 0.30 * (1.0 - w)) * esc 			* (0.6 + 0.6 * absf(sin(g * 2.0 + float(i))))
		draw_line(suelo + u * d0, suelo + u * d1,
			Color(f.r, f.g, f.b, 0.85 * alfa * (1.0 - w)), maxf(1.5, caja * 0.020), true)
	# LOS CASCOTES: trozos GORDOS de suelo levantados, subiendo y cayendo en parabola.
	for i in 7:
		var ang2: float = -PI * 0.5 + (float(i) - 3.0) * 0.26 + sin(g * 1.7 + float(i)) * 0.10
		var u2 := Vector2(cos(ang2), sin(ang2))
		var d: float = caja * (0.28 + 1.35 * w) * esc
		var p: Vector2 = suelo + u2 * d + Vector2(0.0, caja * 0.70 * w * w * esc)
		var tam: float = caja * 0.085 * (1.0 - w * 0.35) * (0.7 + 0.5 * absf(sin(g + float(i) * 3.1)))
		var giro: float = w * 5.0 * (1.0 if i % 2 == 0 else -1.0)
		var roca := PackedVector2Array()
		for j in 5:
			var a: float = TAU * float(j) / 5.0 + giro
			var rad: float = tam * (0.75 + 0.35 * absf(sin(g + float(i) + float(j) * 2.3)))
			roca.append(p + Vector2(cos(a) * rad, sin(a) * rad))
		draw_colored_polygon(roca, Color(0.34, 0.31, 0.29, 0.95 * alfa * (1.0 - w * 0.8)))
		var cerr := PackedVector2Array(roca)
		cerr.append(roca[0])
		draw_polyline(cerr, Color(0.10, 0.09, 0.11, 0.8 * alfa * (1.0 - w * 0.8)),
			maxf(1.0, tam * 0.20), true)


# SEGAR. Dos barridos BAJOS, a la altura de las piernas: el trazo va casi horizontal y muy abajo, y
# cruza a todos los alcanzados de lado a lado.
func _pintar_segar(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, COLETA_SEGAR, 0.05)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	# ABAJO del todo: esto va a las piernas, no al pecho.
	var b: Vector2 = Vector2(float(e["b"].x), float(e["b"].y) + caja * 0.34)
	# De lado a lado de TODO lo alcanzado (por eso es de grupo).
	var largo: float = _radio_grupo(e, 1.05, caja * 1.30)
	var sentido: float = 1.0 if sin(g * 5.7) > 0.0 else -1.0
	var ang: float = (0.10 + sin(g * 2.3) * 0.07) * sentido
	var k: float = 1.0 - pow(1.0 - v, 2.0)
	_tajo(b, ang, largo, 0.03 * sentido, k, col, alfa, caja * 0.135, int(e.get("elem", 0)), float(e["semilla"]))


# DOBLE TAJO. La habilidad pega DOS golpes y cada golpe es UNO de los dos cortes: el primero deja
# su corte puesto, el segundo entra cruzandolo y, al cerrarse la cruz, DESTELLA. Una sola estrella
# por habilidad, no una por golpe.
#
# Antes cada golpe pintaba la cruz entera con su destello, asi que salian dos aspas y dos estrellas
# encima -- justo el doble de lo que hace la habilidad.
func _pintar_doble_tajo(e: Dictionary) -> void:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	if t < dur:
		return
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var b: Vector2 = e["b"] + Vector2(cos(g * 2.1), sin(g * 1.7)) * caja * 0.08
	var v: float = clampf((t - dur) / COLETA_DOBLE_TAJO, 0.0, 1.0)
	var alfa: float = 1.0 if v < 0.72 else 1.0 - (v - 0.72) / 0.28
	if alfa <= 0.0:
		return
	# CUAL DE LOS DOS ES. El segundo cruza al primero y es el que remata con el destello.
	var segundo: bool = int(e.get("golpe", 0)) > 0
	var f: Color = _filo_col(col)
	var largo: float = caja * 1.60
	var ang: float = (PI * 0.28 if segundo else -PI * 0.28) + sin(g * 3.3) * 0.06
	var k: float = 1.0 - pow(1.0 - clampf(v / 0.34, 0.0, 1.0), 2.2)
	_tajo(b, ang, largo, 0.03 * (-1.0 if segundo else 1.0), k, col, alfa, caja * 0.090,
		int(e.get("elem", 0)), g)
	# EL DESTELLO lo suelta SOLO el segundo, cuando el aspa ya esta cerrada.
	if not segundo or v <= 0.42:
		return
	var w: float = clampf((v - 0.42) / 0.30, 0.0, 1.0)
	var brillo: float = (w / 0.22) if w < 0.22 else maxf(0.0, 1.0 - (w - 0.22) / 0.78)
	if brillo <= 0.0:
		return
	# Las dos barras del aspa encendidas: la cruz entera, aunque este golpe solo haya trazado una.
	for i in 2:
		var a2: float = (-PI * 0.28 if i == 0 else PI * 0.28) + sin(g * 3.3) * 0.06
		var dir := Vector2(cos(a2), sin(a2))
		var lado := Vector2(-dir.y, dir.x)
		var ancho: float = caja * 0.115 * brillo
		var pts := PackedVector2Array([
			b + dir * largo * 0.5 + lado * ancho * 0.25,
			b + lado * ancho,
			b - dir * largo * 0.5 + lado * ancho * 0.25,
			b - dir * largo * 0.5 - lado * ancho * 0.25,
			b - lado * ancho,
			b + dir * largo * 0.5 - lado * ancho * 0.25])
		draw_colored_polygon(pts, Color(f.r, f.g, f.b, 0.55 * alfa * brillo))
		draw_line(b - dir * largo * 0.5, b + dir * largo * 0.5,
			Color(1.0, 0.99, 0.96, 0.95 * alfa * brillo), maxf(2.0, caja * 0.045 * brillo), true)
	# El nucleo y las agujas, donde se cruzan los dos filos.
	_estrella(b, caja * 1.45 * brillo, caja * 1.15 * brillo, 0.38,
		Color(f.r, f.g, f.b, 0.55 * alfa * brillo))
	_estrella(b, caja * 0.72 * brillo, caja * 0.58 * brillo, 0.62,
		Color(f.r, f.g, f.b, 0.85 * alfa * brillo))
	_estrella(b, caja * 0.34 * brillo, caja * 0.28 * brillo, 1.15,
		Color(1.0, 0.99, 0.96, alfa * brillo))
	draw_circle(b, maxf(2.0, caja * 0.085 * brillo), Color(1.0, 1.0, 1.0, alfa * brillo))


# EL ACERO EN ALTO. Lo que se echa encima el que grita (Grito de guerra, por fx_sobre_mi): el
# espadon levantado por encima de la cabeza. Va sobre SU tarjeta -- dibujarlo sobre el que recibe el
# grito parecia que le estabas pegando con el arma, que es justo lo que no hace esta habilidad.
func _pintar_acero_en_alto(e: Dictionary) -> void:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var b: Vector2 = e["b"]
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var sube: float = clampf(t / dur, 0.0, 1.0)
	var v: float = clampf((t - dur) / COLETA_ACERO_ALTO, 0.0, 1.0) if t > dur else 0.0
	var alfa: float = 1.0 if v < 0.70 else 1.0 - (v - 0.70) / 0.30
	if alfa <= 0.0:
		return
	# Sube durante el vuelo y se queda arriba, temblando un poco: el brazo aguanta el peso.
	var alto: float = caja * (0.10 + 0.62 * sube) + sin(t * 9.0 + g) * caja * 0.02 * sube
	_hoja(b + Vector2(sin(g) * caja * 0.06, -alto), Vector2.UP,
		caja * 1.05, caja * 0.105, col, alfa, 0.0)
	# El destello del filo al levantarlo, que es lo que hace que se lea el gesto.
	if v <= 0.0:
		return
	var f: Color = _filo_col(col)
	var brillo: float = maxf(0.0, 1.0 - v / 0.5)
	if brillo > 0.0:
		_estrella(b + Vector2(sin(g) * caja * 0.06, -alto - caja * 0.95),
			caja * 0.30 * brillo, caja * 0.24 * brillo, 0.55,
			Color(f.r, f.g, f.b, 0.8 * alfa * brillo))


# ============================================================
#  LA MAZA PEQUEÑA: lo romo
# ============================================================
# La primera arma del jugador que NO CORTA, y por eso es la primera que no usa _tajo ni una sola vez.
# Un tajo se cuenta con POR DONDE HA PASADO el filo -- una cinta que cruza la tarjeta --, y un mazazo
# no pasa por ningun sitio: llega a un punto, revienta ahi y se para. Lo suyo es el PUNTO, no la
# linea.
#
# TAMPOCO DIBUJA EL ARMA (decidido con el usuario). Una maza si se para donde golpea, o sea que
# entraria en la excepcion que ya admite la regla (la hoja untando veneno, la estocada clavada), pero
# se ha dejado fuera: las cinco armas anteriores no enseñan acero y esta tampoco.
#
# Y NO PINTA NI UNA ESTRELLITA DE ATURDIMIENTO, que es lo primero que pide el cuerpo tratandose del
# arma que aturde. Ya esta contado: el estado Aturdido saca el corro de estrellitas girando sobre la
# cabeza (familia "control" de las particulas, ver CombatFX). Repetirlo aqui seria decirlo dos veces
# -- y encima mentir las tres de cada cuatro veces que el aturdir NO prende, porque es probabilidad.
# Lo que dice el gesto es el PESO.
const COLETA_MAZA := 0.28            # el basico: sale mucho por pelea, corto y seco
const COLETA_DEMOLEDOR := 0.46       # el gordo: hay que oir la resonancia entera
const COLETA_ROMPEPIERNAS := 0.40    # el porrazo y luego la pierna cediendo
const COLETA_APLASTAMIENTO := 0.42   # el porrazo y la guardia saltando
const COLETA_CULATAZO := 0.22        # el mas corto del arma: es un mangazo, entra y se va
const COLETA_ALIENTO := 0.55         # es un buff: tiene que quedarse puesto un rato
const COLETA_MURO := 0.62            # y este mas, que las placas se cierran una a una


# EL PORRAZO. El ladrillo de toda la maza: una estrella CORTA Y GORDA (nada de agujas: lo que ha
# entrado es una masa, no una punta) con el nucleo encendido y un anillo APLASTADO abriendose.
#
# Es el mismo lenguaje del GOLPETAZO de los bichos -- un puño de piedra y una maza hacen lo mismo --
# pero pasado a colores de jugador: alli el color es el del bicho y aqui sale de la imbuicion o del
# acero (ver _filo_col). Se dejan los dos painters aparte a proposito: el del bicho tiene su propio
# ritmo ya rodado y no compensa parametrizarlo para ahorrar quince lineas.
#
# 'v' es el avance (0..1) y gobierna cuanto se ha abierto el anillo; 'r' es el tamaño del golpe, que
# es LO QUE SEPARA un mazazo del basico.
func _porrazo(b: Vector2, r: float, col: Color, alfa: float, v: float, g: float,
		elem: int = 0) -> void:
	var f: Color = _filo_col(col)
	var claro := Color(minf(1.0, f.r + 0.22), minf(1.0, f.g + 0.20), minf(1.0, f.b + 0.18))
	# LA MANCHA ROMA. Lo que decide si esto se lee como una maza o como una estrella ninja son DOS
	# numeros, y la primera version los tenia los dos mal (9 puas y valle 0.55): salia un shuriken de
	# puntas largas, que es exactamente lo que NO hace un arma contundente.
	#   - MUCHAS puas (13): pocas y separadas se leen como puntas; muchas y juntas, como un borde
	#     irregular, que es lo que deja algo que revienta por igual en todas direcciones.
	#   - Y el VALLE ALTO (0.70): es la profundidad de la muesca entre pua y pua. Con el valle bajo la
	#     silueta baja hasta el centro y salen agujas; con el alto se queda una mancha compacta con el
	#     borde picado.
	# Los largos son desiguales -- sacados de la semilla, que es fija, no de randf(), o la forma
	# cambiaria en cada frame -- pero MENOS que antes: mucha variacion tambien hace puntas.
	var pts := PackedVector2Array()
	var n: int = 13
	for i in n:
		var ang: float = g + TAU * float(i) / float(n)
		var largo: float = r * (0.80 + 0.20 * sin(g * 1.7 + float(i) * 2.9))
		pts.append(b + Vector2(cos(ang), sin(ang) * 0.80) * largo)
		var med: float = ang + PI / float(n)
		pts.append(b + Vector2(cos(med), sin(med) * 0.80) * largo * 0.70)
	# Y el relleno va mas FLOJO (0.55): esto es el fogonazo del impacto, no una chapa blanca. Con 0.72
	# tapaba lo que va encima -- la guardia del Aplastamiento y las patas del Rompepiernas quedaban
	# detras de la mancha, que es lo unico que diferencia unos golpes de otros.
	draw_colored_polygon(pts, Color(claro.r, claro.g, claro.b, 0.55 * alfa))
	draw_circle(b, maxf(1.5, r * 0.20), Color(1.0, 0.99, 0.96, 0.85 * alfa))
	# EL ANILLO: la onda del porrazo. Muy achatado -- recorre la fila, no se infla como una burbuja.
	var rr: float = r * (0.95 + 0.75 * v)
	_anillo(b, rr, rr * 0.58, Color(f.r, f.g, f.b, 0.42 * alfa * (1.0 - v)),
		maxf(1.5, r * 0.11 * (1.0 - v)))
	# EL ELEMENTO ES UN COMPORTAMIENTO, NO UN COLOR (la misma regla que _tajo). Aqui no hay trazo que
	# quebrar ni borde que ondee, asi que se cuenta con lo que SALTA del punto de impacto.
	if elem == Elementos.Elemento.RAYO:
		# Ramitas quebradas saliendo del golpe, con el codo a media altura.
		for i in 5:
			var a: float = g * 1.3 + TAU * float(i) / 5.0
			var u := Vector2(cos(a), sin(a) * 0.8)
			var codo: Vector2 = b + u * r * 0.9 + Vector2(-u.y, u.x) * r * 0.28 * sin(g + float(i) * 3.1)
			draw_polyline(PackedVector2Array([b + u * r * 0.4, codo, b + u * r * (1.5 + 0.5 * v)]),
				Color(1.0, 0.99, 0.92, 0.75 * alfa * (1.0 - v)), maxf(1.0, r * 0.07), true)
	elif elem == Elementos.Elemento.FUEGO:
		# Chispas subiendo del punto: el calor tira hacia arriba, no se reparte en circulo.
		for i in 7:
			var a2: float = -PI * 0.5 + (float(i) - 3.0) * 0.26 + sin(g + float(i)) * 0.10
			var d: float = r * (0.7 + 1.5 * v) * (0.6 + 0.6 * absf(sin(g * 2.0 + float(i))))
			draw_circle(b + Vector2(cos(a2), sin(a2)) * d, maxf(1.0, r * 0.13 * (1.0 - v)),
				Color(1.0, 0.72 + 0.2 * absf(sin(g + float(i))), 0.30, 0.85 * alfa * (1.0 - v)))
	elif elem == Elementos.Elemento.AGUA:
		# Y el agua SALPICA: gotas que salen y caen, con su hilillo detras.
		for i in 6:
			var a3: float = g + TAU * float(i) / 6.0
			var u3 := Vector2(cos(a3), sin(a3) * 0.7)
			var p3: Vector2 = b + u3 * r * (0.8 + 1.3 * v) + Vector2(0.0, r * 0.9 * v * v)
			draw_line(b + u3 * r * 0.6, p3, Color(f.r, f.g, minf(1.0, f.b + 0.15), 0.4 * alfa),
				maxf(1.0, r * 0.06), true)
			draw_circle(p3, maxf(1.2, r * 0.14 * (1.0 - v * 0.5)),
				Color(f.r, f.g, minf(1.0, f.b + 0.15), 0.85 * alfa * (1.0 - v)))


# LA RESONANCIA: anillos concentricos escalonados saliendo del punto. Es lo que dice que el golpe ha
# SONADO, y lo que separa un mazazo de los gordos del porrazo de todos los dias.
#
# Van muy achatados (0.5) por lo mismo que el anillo del porrazo: la fila de tarjetas es ancha y baja,
# y un circulo redondo se sale por arriba aunque el radio horizontal este bien.
func _resonancia(b: Vector2, r: float, f: Color, alfa: float, w: float, n: int) -> void:
	for i in n:
		var k: float = clampf((w - float(i) * 0.16) / 0.84, 0.0, 1.0)
		if k <= 0.0:
			continue
		# 1.3 y no 2.1: con el radio viejo, a un demoledor con la caja grande los anillos le salian el
		# doble de anchos que la tarjeta y parecian una onda de hechizo, no un golpe.
		var rr: float = r * (0.5 + 1.3 * k)
		_anillo(b, rr, rr * 0.50, Color(f.r, f.g, f.b, 0.5 * alfa * (1.0 - k)),
			maxf(1.5, r * 0.10 * (1.0 - k * 0.6)))


# EL BASICO Y EL CULATAZO. El mismo porrazo con dos tallas y dos alturas, que es toda la diferencia
# que hay entre ellos: el basico cae al cuerpo y el Culatazo va ARRIBA, a la cabeza ("con el mango,
# corto y seco, donde se piensa"), y es el mas pequeño del arma.
#
# Comparten painter porque son literalmente el mismo gesto a distinta escala. En cuanto uno de los
# dos pida algo propio, se parten.
func _pintar_maza_golpe(e: Dictionary) -> void:
	var mango: bool = int(e["estilo"]) == CombatFX.Estilo.CULATAZO
	var r0: Array = _golpe_cuerpo(e, COLETA_CULATAZO if mango else COLETA_MAZA, 0.09)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	# EL CULATAZO VA ARRIBA. Es lo unico que lo hace legible como "a la cabeza": si cayera en el
	# centro como el basico, dos gestos del mismo arma se verian iguales.
	if mango:
		b += Vector2(0.0, -caja * 0.30)
	# Entra de golpe y se para: 1-(1-v)^3 mete casi todo el crecimiento en el primer tramo, que es
	# como llega una masa -- de golpe, y ahi se queda.
	var k: float = 1.0 - pow(1.0 - clampf(v / 0.22, 0.0, 1.0), 3.0)
	var r: float = caja * (0.17 if mango else 0.26) * (0.35 + 0.65 * k)
	_porrazo(b, r, e["col"], alfa, v, float(e["semilla"]), int(e.get("elem", 0)))


# GOLPE DEMOLEDOR. El mazazo concusivo: el porrazo GORDO y, encima, la resonancia -- tres anillos
# escalonados abriendose y el propio impacto VIBRANDO un par de veces.
#
# La vibracion es lo que mas cuenta y es tambien lo mas barato: el porrazo se pinta dos veces con un
# desplazamiento minusculo que oscila rapido. A tamaño real no se lee como "hay dos dibujos", se lee
# como metal resonando, que es exactamente lo que hace una maza al reventar contra algo.
func _pintar_demoledor(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, COLETA_DEMOLEDOR, 0.07)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var elem: int = int(e.get("elem", 0))
	var k: float = 1.0 - pow(1.0 - clampf(v / 0.20, 0.0, 1.0), 3.0)
	var r: float = caja * 0.40 * (0.30 + 0.70 * k)
	# LA VIBRACION, solo mientras dura el golpe (primer tercio): despues el metal ya se ha calmado y
	# dejarla puesta se veria como un dibujo mal centrado. El eco va en gris y flojo -- es el rastro
	# de donde estaba, no un segundo golpe.
	var tiembla: float = maxf(0.0, 1.0 - v / 0.34)
	if tiembla > 0.0:
		var d: Vector2 = Vector2(sin(v * 78.0 + g), cos(v * 61.0 + g) * 0.5) * caja * 0.030 * tiembla
		_porrazo(b + d, r * 0.94, col, alfa * 0.42 * tiembla, v, g + 1.7, 0)
	_porrazo(b, r, col, alfa, v, g, elem)
	# Y LA RESONANCIA saliendo del punto, ya con el golpe dado.
	if v <= 0.16:
		return
	_resonancia(b, r, _filo_col(col), alfa, (v - 0.16) / 0.84, 3)


# ROMPEPIERNAS. El mazazo BAJO: el porrazo cae abajo del todo, el suelo se hunde bajo el golpe y el
# polvo escapa a ras hacia los lados. Lo que ralentiza no es un hueso roto: es que te han CLAVADO.
#
# EL NOMBRE NO ES EL DIBUJO. Se intento primero con "el desplome" -- rayas cayendo desde el golpe, la
# pierna cediendo -- y esta mal de raiz, no de estetica: la mitad de los bichos del juego no tienen
# piernas. A un slime no se le rompe ninguna. "Rompepiernas" es el nombre de una jugada, igual que un
# gancho no va a la barbilla de una gelatina, y el gesto tiene que valer para CUALQUIER cosa que se
# coma el golpe. Lo que si vale para todos es el sitio (abajo) y el peso (hundir).
#
# Es el espejo romo del Corte de tendones (la espada corta): mismo sitio de la tarjeta, pero alli se
# secciona algo y aqui se aplasta contra el suelo.
func _pintar_rompepiernas(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, COLETA_ROMPEPIERNAS, 0.07)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	# ABAJO, pero no en el suelo: en el tercio de abajo de la tarjeta. Ahi es donde se lee "te ha
	# pegado por debajo" sea lo que sea el bicho.
	var b: Vector2 = Vector2(float(r0[2].x), float(e["b"].y) + caja * 0.44)
	var k: float = 1.0 - pow(1.0 - clampf(v / 0.22, 0.0, 1.0), 3.0)
	var r: float = caja * 0.25 * (0.35 + 0.65 * k)
	_porrazo(b, r, col, alfa, v, g, int(e.get("elem", 0)))
	if v <= 0.28:
		return
	var f: Color = _filo_col(col)
	var w: float = (v - 0.28) / 0.72
	var suelo: Vector2 = b + Vector2(0.0, caja * 0.16)
	# LA HUELLA HUNDIDA: un arco combado HACIA ABAJO justo bajo el golpe, que se hunde mas segun pasa
	# el tiempo. Es la abolladura que deja el peso, y funciona igual sobre un goblin que sobre un
	# slime -- lo que se hunde es el suelo, no el bicho.
	var hondo: float = caja * (0.06 + 0.10 * w)
	var ancho_h: float = caja * (0.24 + 0.16 * w)
	var huella := PackedVector2Array()
	for i in 9:
		var s: float = float(i) / 8.0
		huella.append(suelo + Vector2((s - 0.5) * 2.0 * ancho_h, sin(PI * s) * hondo))
	draw_polyline(huella, Color(0.12, 0.11, 0.13, 0.85 * alfa * (1.0 - w * 0.35)),
		maxf(2.0, caja * 0.040 * (1.0 - w * 0.3)), true)
	# EL POLVO ESCAPANDO A RAS, a los dos lados: es por donde ha salido lo que no cabia debajo, y lo
	# que dice que el golpe ha ido hacia ABAJO y no hacia dentro.
	for i in 6:
		var lado: float = -1.0 if i % 2 == 0 else 1.0
		var d: float = ancho_h * (0.9 + 1.5 * w) * (0.6 + 0.5 * absf(sin(g + float(i) * 1.9)))
		var p: Vector2 = suelo + Vector2(lado * d, -caja * 0.03 * absf(sin(g * 2.1 + float(i))))
		draw_line(p, p - Vector2(lado * caja * (0.06 + 0.05 * w), 0.0),
			Color(f.r, f.g, f.b, 0.55 * alfa * (1.0 - w)), maxf(1.5, caja * 0.024), true)
	# Y la onda a ras: el sitio donde ha ido a parar todo el peso.
	var rr: float = caja * (0.20 + 0.75 * w)
	_anillo(suelo, rr, rr * 0.18,
		Color(0.74, 0.70, 0.64, 0.45 * alfa * (1.0 - w)), maxf(1.5, caja * 0.030 * (1.0 - w * 0.5)))


# APLASTAMIENTO. El mazazo que ROMPE LA GUARDIA: el porrazo y, tras el, el arco de la guardia
# partiendose en dos y saltando en pedazos.
#
# SOLO PINTA EL PRIMER GOLPE. La habilidad pega dos y el segundo es DE ESCUDO (escudo_desde_golpe =
# 1): ese lo dibuja ESCUDAZO, que lo fuerza _resolver_golpe_hab en combat.gd igual que le fuerza a
# pegar con la Defensa. Sin el corte de aqui saldrian dos mazazos y ningun escudo, que es justo al
# reves de lo que dice la ficha.
func _pintar_aplastamiento(e: Dictionary) -> void:
	if int(e.get("golpe", 0)) > 0:
		return
	var r0: Array = _golpe_cuerpo(e, COLETA_APLASTAMIENTO, 0.07)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	# EL MAZAZO ENTRA POR SU LADO, el contrario del que usa el escudazo que viene detras (ver
	# DESVIO_MANO): si no, los dos golpes de esta habilidad se pintan en el mismo punto con dos
	# decimas de diferencia y se tapan el uno al otro.
	b.x -= caja * DESVIO_MANO
	var k: float = 1.0 - pow(1.0 - clampf(v / 0.20, 0.0, 1.0), 3.0)
	var r: float = caja * 0.28 * (0.32 + 0.68 * k)
	_porrazo(b, r, col, alfa, v, g, int(e.get("elem", 0)))
	# LA GUARDIA REVENTANDO, con el mismo lenguaje que el Tajo quebrantador de la espada corta: es la
	# misma jugada (abrirle la defensa) y tiene que leerse igual, la de un arma o la de la otra.
	# Se queda CENTRADA en la tarjeta aunque el mazazo entre por un lado: lo que se rompe es la
	# guardia del bicho, que esta donde esta, no donde le hayas pegado.
	_guardia_rompiendose(e["b"], caja * 0.62, _filo_col(col), alfa,
		clampf((v - 0.16) / 0.45, 0.0, 1.0), g, caja)


# LA GUARDIA QUE SE PARTE: un arco por delante, entero al principio, abriendose en dos mitades que
# giran y se apartan, y al final los cascotes saliendo despedidos.
#
# Sacado de _pintar_quebrantador cuando el Aplastamiento pidio lo mismo. Es LA forma de decir "le has
# abierto la defensa", y tiene que ser la misma la pegue quien la pegue.
func _guardia_rompiendose(b: Vector2, rr: float, f: Color, alfa: float, abre: float, g: float,
		caja: float) -> void:
	if abre <= 0.0:
		return
	for mitad in 2:
		var lado: float = 1.0 if mitad == 0 else -1.0
		var giro: float = lado * abre * 0.55
		var desp: Vector2 = Vector2(lado * abre * caja * 0.30, -abre * caja * 0.10)
		var arco := PackedVector2Array()
		for i in 9:
			# Media cupula por mitad: de la vertical hacia su lado.
			var a: float = -PI * 0.5 + lado * PI * 0.42 * float(i) / 8.0 + giro
			arco.append(b + desp + Vector2(cos(a) * rr, sin(a) * rr * 0.9))
		draw_polyline(arco, Color(f.r, f.g, f.b, 0.55 * alfa * (1.0 - abre * 0.5)),
			maxf(2.0, caja * 0.030), true)
	# LOS CASCOTES: trocitos que salen despedidos del punto donde ha reventado.
	if abre <= 0.25:
		return
	var w: float = (abre - 0.25) / 0.75
	for i in 6:
		var ang: float = -PI * 0.5 + (float(i) - 2.5) * 0.42 + sin(g + float(i)) * 0.12
		var d: float = rr * (0.45 + 0.9 * w)
		var p: Vector2 = b + Vector2(cos(ang) * d, sin(ang) * d * 0.9)
		var s: float = caja * 0.065 * (1.0 - w * 0.4)
		var tri := PackedVector2Array([
			p + Vector2(-s, s * 0.6), p + Vector2(s * 0.8, s * 0.2), p + Vector2(0.0, -s)])
		draw_colored_polygon(tri, Color(f.r, f.g, f.b, 0.8 * alfa * (1.0 - w)))


# GRITO DE ALIENTO. No es un golpe ni va contra nadie: se pinta sobre CADA UNO DE LOS TUYOS (llega
# por _fx_adorno con la lista de aliados). "No das ninguna orden: solo haces saber que sigues de pie
# delante" -- asi que lo que se ve no es una instruccion, es que el aliado SE YERGUE.
#
# Tiene que separarse de la VOZ DE MANDO de la espada larga, que es la otra que se echa a los tuyos:
# aquella son arcos que se abren y una FLECHA (una orden, con su direccion). Esta son GALONES
# subiendo por el cuerpo y el suelo empujando -- ningun icono de mando, solo empuje.
func _pintar_grito_aliento(e: Dictionary) -> void:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var b: Vector2 = e["b"]
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var sale: float = clampf(t / dur, 0.0, 1.0)
	var v: float = clampf((t - dur) / COLETA_ALIENTO, 0.0, 1.0) if t > dur else 0.0
	var alfa: float = 1.0 if v < 0.62 else 1.0 - (v - 0.62) / 0.38
	if alfa <= 0.0:
		return
	var f: Color = _filo_col(col)
	# EL EMPUJE DEL SUELO: un arco bajo y ancho bajo los pies, que se enciende primero. De ahi sale
	# todo lo demas, y es lo que hace que los galones se lean como "sube" y no como "cae".
	var pie: Vector2 = b + Vector2(0.0, caja * 0.42)
	var enc: float = maxf(0.0, 1.0 - v / 0.55) * (0.35 + 0.65 * sale)
	if enc > 0.0:
		_anillo(pie, caja * (0.30 + 0.22 * v), caja * 0.10,
			Color(f.r, f.g, f.b, 0.55 * alfa * enc), maxf(1.5, caja * 0.032 * enc))
	# LOS GALONES: tres uves invertidas que suben por el cuerpo, escalonadas, y se desvanecen arriba.
	# Suben en fila india (cada una con su desfase) porque lo que hay que leer es el MOVIMIENTO hacia
	# arriba; las tres a la vez se leerian como un adorno pintado encima y no como algo que pasa.
	for i in 3:
		var k: float = clampf((sale * 0.55 + v * 1.25 - float(i) * 0.20) / 0.70, 0.0, 1.0)
		if k <= 0.0 or k >= 1.0:
			continue
		var y: float = caja * (0.34 - 1.00 * k)
		var an: float = caja * (0.30 - 0.06 * k)
		var alto: float = caja * 0.15
		# Se apaga por los dos extremos: entra suave y sale suave.
		var op: float = sin(PI * k)
		var uve := PackedVector2Array([
			b + Vector2(-an, y + alto), b + Vector2(0.0, y), b + Vector2(an, y + alto)])
		draw_polyline(uve, Color(f.r, f.g, f.b, 0.8 * alfa * op), maxf(2.0, caja * 0.034 * op), true)
	# Y unas chispas subiendo con ellos, para que el aire tambien se mueva.
	for i in 5:
		var kk: float = fposmod(v * 1.6 + float(i) * 0.21 + g * 0.1, 1.0)
		var x: float = sin(g + float(i) * 2.7) * caja * 0.30
		draw_circle(b + Vector2(x, caja * (0.40 - 1.05 * kk)),
			maxf(1.0, caja * 0.022 * (1.0 - kk)),
			Color(f.r, f.g, f.b, 0.7 * alfa * sin(PI * kk)))


# MURO DE ALIADOS. El otro que se echa a los tuyos: "cierras la formacion a voces, nadie se queda
# solo". Tres placas que BAJAN y se cierran solapandose delante del aliado, con la costura
# encendiendose al juntarse, y dos trazos cortos hacia los lados -- los vecinos.
#
# Los trazos laterales son lo que lo separa de un escudo cualquiera (el ESCUDAZO, el Voto de
# guardia): esos son UNO cubriendose y este es una FILA cerrandose. Sin ellos era otra plancha mas.
func _pintar_muro_aliados(e: Dictionary) -> void:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var b: Vector2 = e["b"]
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var baja: float = clampf(t / dur, 0.0, 1.0)
	var v: float = clampf((t - dur) / COLETA_MURO, 0.0, 1.0) if t > dur else 0.0
	var alfa: float = 1.0 if v < 0.68 else 1.0 - (v - 0.68) / 0.32
	if alfa <= 0.0:
		return
	var f: Color = _filo_col(col)
	# EL CIERRE se toma su tiempo. Con `baja + v*1.8` las placas nacian ya casi juntas y lo unico que
	# hacia esta habilidad era estar ahi puesta: lo que hay que VER es la formacion cerrandose, asi que
	# el vuelo solo las trae a medio camino y el resto pasa en la coleta.
	var cerrado: float = clampf(baja * 0.45 + v * 1.30, 0.0, 1.0)
	# LAS TRES PLACAS. Nacen separadas y arriba, y caen juntandose hasta solaparse. El ancho es el
	# mismo para las tres: es una empalizada, no un escudo con forma.
	var an: float = caja * 0.21
	var alto: float = caja * 0.46
	var cy: float = b.y + caja * 0.12
	for i in 3:
		var lado: float = float(i) - 1.0
		# De fuera hacia dentro: empiezan a caja*0.34 de separacion y acaban solapadas (0.19).
		var sep: float = caja * lerpf(0.34, 0.19, cerrado)
		var cae: float = caja * 0.55 * (1.0 - cerrado)
		var c := Vector2(b.x + lado * sep, cy - cae)
		var pts := PackedVector2Array([
			c + Vector2(-an * 0.5, -alto * 0.5), c + Vector2(an * 0.5, -alto * 0.5),
			c + Vector2(an * 0.5, alto * 0.42), c + Vector2(0.0, alto * 0.5),
			c + Vector2(-an * 0.5, alto * 0.42)])
		draw_colored_polygon(pts, Color(_ACERO_OSCURO.r, _ACERO_OSCURO.g, _ACERO_OSCURO.b,
			0.80 * alfa * (0.45 + 0.55 * cerrado)))
		var borde := PackedVector2Array(pts)
		borde.append(pts[0])
		draw_polyline(borde, Color(f.r, f.g, f.b, 0.85 * alfa), maxf(1.5, caja * 0.024), true)
	# LA COSTURA: cuando ya estan juntas, las dos junturas se encienden. Es el instante en que la
	# formacion se cierra, y sin el las placas solo "estaban ahi".
	if cerrado > 0.75:
		var w: float = (cerrado - 0.75) / 0.25
		for i in 2:
			var x: float = b.x + (float(i) * 2.0 - 1.0) * caja * 0.095
			draw_line(Vector2(x, cy - alto * 0.5), Vector2(x, cy + alto * 0.5),
				Color(1.0, 0.99, 0.96, 0.75 * alfa * w * maxf(0.0, 1.0 - v / 0.6)),
				maxf(1.5, caja * 0.020), true)
	# LOS VECINOS: dos trazos cortos saliendo a los lados, a la altura del hombro. Nadie se queda
	# solo -- la fila continua fuera de esta tarjeta.
	var hom: float = cy - alto * 0.22
	for i in 2:
		var s: float = float(i) * 2.0 - 1.0
		var d0: float = caja * 0.34
		var d1: float = d0 + caja * (0.10 + 0.16 * cerrado)
		draw_line(Vector2(b.x + s * d0, hom + sin(g + float(i)) * caja * 0.02),
			Vector2(b.x + s * d1, hom),
			Color(f.r, f.g, f.b, 0.6 * alfa * cerrado), maxf(1.5, caja * 0.026), true)


# ============================================================
#  EL HACHA GRANDE: muerde y sangra
# ============================================================
# NO ES UN MANDOBLE MAS PEQUEÑO, y ese es todo el problema de esta arma: las dos son a dos manos,
# las dos son lentas y las dos cortan, asi que si sus trazos se dibujan igual son la misma arma con
# otro nombre. Lo que las separa es COMO ACABA EL GOLPE:
#
#   el mandoble ATRAVIESA -- su trazo cruza la tarjeta entera y sale por el otro lado
#   el hacha MUERDE       -- el suyo entra y SE PARA dentro, gordo en la cabeza y cortado en seco
#
# Eso lo hace _mordisco_de_filo, que no es mas que _tajo colocado de forma que el FINAL del recorrido
# caiga dentro de la tarjeta en vez de fuera. No hay dibujo nuevo: hay un sitio distinto donde parar.
#
# Y SANGRA. Tres de sus cinco tecnicas dejan Sangrado o Herida profunda, asi que es la primera con
# _salpicadura. Ojo con lo que NO es: no es una marca de herida pintada sobre el bicho (eso se probo
# en la daga y sobra, ver la nota larga de _tajo) -- es lo que sale VOLANDO cuando el filo frena.
const COLETA_HACHA := 0.34
const COLETA_HENDEDURA := 0.44      # hay que ver la brecha abrirse
const COLETA_BRUTAL := 0.52         # el golpe gordo del arma
const COLETA_CARNICERIA := 0.42     # tres hachazos encadenados
const COLETA_DESGARRO := 0.46       # entra, tira, y lo que arranca tarda en caer
const COLETA_SED := 0.60            # es un buff: se queda puesto

# LO QUE HACE QUE UN TRAZO SE LEA COMO UN CORTE ES SU PROPORCION, no su tamaño. Esto costo dos
# intentos:
#   1.15 de largo con 0.150 de grosor -> el trazo TERMINA en la tarjeta, asi que toda la cinta queda
#        por detras y cruzaba el fondo entero: salia un triangulo gigante y ni un hachazo.
#   0.78 con 0.115 -> ya cabia, pero la proporcion quedo en 1:3 y una cinta tan corta y tan ancha
#        tampoco es un corte: es una cuña maciza. (El mandoble va a 1:7,6, y por eso el suyo si se
#        lee como un filo pasando.)
# La solucion no era acortar el trazo sino mover DONDE PARA: el filo recorre casi toda la tarjeta
# -- largo de mandoble, proporcion de mandoble -- pero se queda dentro en vez de salir por el otro
# lado. Eso es morder: no es un golpe corto, es un golpe que no termina de salir.
const LARGO_HACHA := 1.20
const GROSOR_HACHA := 0.105
# Hasta donde llega el filo, medido desde el centro de la tarjeta en la direccion del golpe. Positivo
# = pasa del centro y se para antes del borde. El mandoble, para comparar, sale mas de medio ancho
# POR FUERA.
const HASTA_HACHA := 0.30


# EL MORDISCO DEL FILO. Un _tajo normal, pero colocado para que el recorrido TERMINE en el punto que
# se le da en vez de pasar por ahi de largo: el filo entra desde fuera y se queda dentro.
#
# _tajo centra el trazo en el punto que recibe y lo extiende medio largo a cada lado, asi que para
# que el final caiga donde toca hay que retrasar el centro medio largo. Con el centro puesto en la
# tarjeta (que es lo que hacen todas las demas armas) el trazo la cruzaba y salia por el otro lado,
# o sea: salia un mandoble.
#
# Devuelve donde esta la cabeza del filo AHORA (k es cuanto lleva recorrido), que es de donde sale
# todo lo demas: la salpicadura, la brecha, el tiron del Desgarro.
func _mordisco_de_filo(donde: Vector2, ang: float, largo: float, k: float, col: Color,
		alfa: float, grosor: float, elem: int, sem: float, comba: float = 0.05) -> Vector2:
	var dir := Vector2(cos(ang), sin(ang))
	var centro: Vector2 = donde - dir * largo * 0.5
	_tajo(centro, ang, largo, comba, k, col, alfa, grosor, elem, sem)
	return centro - dir * largo * 0.5 + dir * largo * k


# LA SALPICADURA. Gotas que salen despedidas del punto donde el filo ha frenado, abiertas en abanico
# hacia donde iba el golpe. Es la firma del hacha: es la unica arma que sangra de serie.
#
# Van en SANGRE cuando no hay imbuicion y del color de lo que lleve el arma cuando la hay -- un hacha
# envenenada salpica verde, que es lo que se espera. Y cada gota lleva su hilillo, igual que las del
# agua en _tajo: sin el, las motas sueltas parecen confeti.
func _salpicadura(p: Vector2, dir: Vector2, col: Color, alfa: float, w: float, caja: float,
		sem: float, n: int = 7) -> void:
	if w <= 0.0:
		return
	# ROJO OSCURO, no rojo vivo: a tamaño real las gotas claras y gordas se leian como confeti pegado
	# encima del bicho en vez de como sangre saliendo de el.
	var c: Color = col if _imbuido(col) else Color(0.60, 0.07, 0.08)
	for i in n:
		# El abanico se abre alrededor de la marcha del filo: lo que salta, salta hacia donde iba.
		var a: float = dir.angle() + (float(i) - float(n - 1) * 0.5) * 0.30 \
			+ sin(sem * 1.7 + float(i) * 2.3) * 0.12
		var u := Vector2(cos(a), sin(a))
		var d: float = caja * (0.10 + 0.62 * w) * (0.5 + 0.7 * absf(sin(sem + float(i) * 1.9)))
		# CAEN mientras vuelan: sin la parabola las gotas salen en linea recta y parecen chispas.
		var q: Vector2 = p + u * d + Vector2(0.0, caja * 0.30 * w * w)
		# Pequeñas: 0.026 de caja eran bolas de 2-3 px de radio a tamaño real y de 4-5 ampliadas, o sea
		# lunares. Lo que se lee como sangre es MUCHAS y CHICAS, no pocas y gordas.
		var r: float = caja * 0.020 * (0.6 + 0.7 * absf(sin(sem * 2.1 + float(i)))) * (1.0 - w * 0.45)
		draw_line(p + u * caja * 0.04, q, Color(c.r, c.g, c.b, 0.30 * alfa * (1.0 - w)),
			maxf(1.0, r * 0.8), true)
		draw_circle(q, maxf(1.2, r), Color(c.r, c.g, c.b, 0.9 * alfa * (1.0 - w * 0.75)))


# UN FILAMENTO DE GRIETA: una linea QUEBRADA que sale de un punto, se va afinando y se BIFURCA. Es
# lo que convierte un corte en una rasgadura -- la fuerza no se para en el borde, sigue agrietando
# alrededor (sale de una referencia que mando el usuario: una raja en el cielo con el borde lleno de
# ramitas).
#
# 'prof' es cuantas veces mas se puede bifurcar. Con 2 basta y sobra: a 3 ya no se distinguen las
# ramas y el coste se dispara (cada nivel dobla las llamadas), y a 1 se ve un palo torcido y ya.
#
# El azar sale de la SEMILLA, nunca de randf(): _draw puede llamarse varias veces por frame y las
# grietas bailarian.
func _filamento(desde: Vector2, dir: Vector2, largo: float, sem: float, col: Color, alfa: float,
		grosor: float, prof: int) -> void:
	if largo < 1.5 or alfa <= 0.01:
		return
	var n: int = 4
	var pts := PackedVector2Array([desde])
	var p: Vector2 = desde
	var d: Vector2 = dir.normalized()
	for i in n:
		# Se tuerce un poco en cada tramo, siempre para el mismo lado un rato y luego para el otro:
		# eso es lo que hace que parezca una grieta y no un garabato.
		d = d.rotated(sin(sem * 1.9 + float(i) * 2.3) * 0.55)
		p += d * (largo / float(n))
		pts.append(p)
	draw_polyline(pts, Color(col.r, col.g, col.b, alfa), grosor, true)
	if prof <= 0:
		return
	# LA BIFURCACION: sale de un punto intermedio, no de la punta. Saliendo de la punta serian ramas
	# en Y todas iguales; saliendo del medio se lee como una grieta que se ha ido abriendo.
	var i2: int = 1 + int(absf(sin(sem * 3.1)) * 2.0)
	_filamento(pts[i2], (pts[i2] - pts[i2 - 1]).rotated(sin(sem * 2.7) * 0.9 + 0.5),
		largo * 0.55, sem * 1.7 + 3.3, col, alfa * 0.8, maxf(1.0, grosor * 0.7), prof - 1)


# EL HACHAZO BASICO. Entra en diagonal, se hunde y se para. Corto y gordo: lo contrario del barrido
# largo y fino del mandoble.
func _pintar_hacha_tajo(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, COLETA_HACHA, 0.08)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var sentido: float = 1.0 if sin(g * 5.7) > 0.0 else -1.0
	# Baja en diagonal: un hacha se lleva arriba y cae, no barre en horizontal.
	var ang: float = (PI * 0.30 + sin(g * 3.3) * 0.18) * sentido
	# Frena de golpe al final (pow 2.6): eso es el hundirse. Con la salida suave del mandoble parecia
	# que el filo seguia de largo.
	var k: float = 1.0 - pow(1.0 - clampf(v / 0.34, 0.0, 1.0), 2.6)
	var dir := Vector2(cos(ang), sin(ang))
	var p: Vector2 = _mordisco_de_filo(b + dir * caja * HASTA_HACHA, ang, caja * LARGO_HACHA, k,
		col, alfa, caja * GROSOR_HACHA, int(e.get("elem", 0)), g, 0.05 * sentido)
	# La sangre sale CUANDO FRENA, no mientras entra.
	if v > 0.26:
		_salpicadura(p, dir, col, alfa, (v - 0.26) / 0.74, caja, g)


# HENDEDURA. El que RAJA: cae en VERTICAL -- es el unico del arma que no entra en diagonal -- y por
# donde ha pasado el filo se separan dos labios. Eso es lo que deja al bicho expuesto (Vulnerable),
# y por eso la brecha se queda abierta en vez de cerrarse.
#
# LOS DOS LABIOS SON EL PROPIO CORTE, no una marca encima: es el mismo corte pintado por sus dos
# bordes, apartandose uno del otro. La regla de "un corte es una sola linea" se sigue cumpliendo
# mientras lo que se separa sea el corte y no un adorno pegado al lado.
func _pintar_hendedura(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, COLETA_HENDEDURA, 0.06)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var inclina: float = sin(g * 3.3) * 0.16
	var ang: float = PI * 0.5 + inclina
	var k: float = 1.0 - pow(1.0 - clampf(v / 0.30, 0.0, 1.0), 2.8)
	# Cae desde arriba y se para en el centro: parte por la mitad, no atraviesa.
	var p: Vector2 = _mordisco_de_filo(b + Vector2(0.0, caja * (0.10 + HASTA_HACHA)), ang,
		caja * 1.30, k, col, alfa, caja * 0.115, int(e.get("elem", 0)), g, 0.0)
	if v <= 0.26:
		return
	var w: float = (v - 0.26) / 0.74
	var f: Color = _filo_col(col)
	# LA GRIETA. Sale de una referencia que mando el usuario -- una rasgadura vertical en el cielo --
	# y de ella salen las TRES cosas que hacen que esto se lea como algo RAJADO y no como dos rayas:
	#
	#  1. El borde va DENTADO, no liso, y los dos lados con su propio dentado. Dos curvas limpias y
	#     paralelas son un dibujo tecnico; lo que rasga deja los bordes rotos.
	#  2. De los bordes salen FILAMENTOS ramificandose hacia fuera. Es lo que mas cuenta de la
	#     referencia: la fuerza no se para en el corte, sigue agrietando alrededor.
	#  3. La abertura es un HUSO LARGO: ancha en el medio y en punta por los dos extremos. La version
	#     anterior era una cuña (ancha arriba, cerrada abajo) y por eso parecia un trozo de pizza.
	#
	# Lo de dentro va OSCURO y el borde ENCENDIDO: aqui se raja carne, no el espacio, asi que el
	# resplandor se queda en el filo de la herida en vez de salir de ella.
	var largo_gr: float = caja * 1.05
	# Lo bastante ancha para que se vea lo OSCURO de dentro: con menos, la grieta se lee como una
	# raya brillante con pelos y se pierde que es una abertura.
	var an_max: float = caja * 0.135 * w
	var n: int = 15
	var izq := PackedVector2Array()
	var der := PackedVector2Array()
	for i in n:
		var u: float = float(i) / float(n - 1)
		var eje: Vector2 = b + Vector2(sin(inclina) * largo_gr * (u - 0.5),
			largo_gr * (u - 0.5) * cos(inclina))
		# pow 0.65 en vez de un seno pelado: aguanta ancha mas rato por el medio y se cierra de golpe
		# en las puntas, que es como se abre algo desgarrado.
		var perfil: float = pow(sin(PI * u), 0.65)
		# Cada lado con SU dentado, y con dos frecuencias para que no salga un zigzag regular.
		var d_i: float = 1.0 + 0.42 * sin(g * 3.1 + float(i) * 2.7) + 0.20 * sin(g + float(i) * 6.1)
		var d_d: float = 1.0 + 0.42 * sin(g * 5.3 + float(i) * 3.1) + 0.20 * sin(g * 2.0 + float(i) * 5.7)
		izq.append(eje + Vector2(an_max * perfil * d_i, 0.0))
		der.append(eje - Vector2(an_max * perfil * d_d, 0.0))
	var dentro := PackedVector2Array(izq)
	for i in range(der.size() - 1, -1, -1):
		dentro.append(der[i])
	draw_colored_polygon(dentro, Color(0.07, 0.02, 0.03, 0.85 * alfa))
	# El borde, en dos pasadas: una gorda y floja (el resplandor) y otra fina y viva (el filo).
	var halo: Color = Color(f.r, f.g, f.b, 0.30 * alfa)
	draw_polyline(izq, halo, maxf(2.0, caja * 0.055), true)
	draw_polyline(der, halo, maxf(2.0, caja * 0.055), true)
	var borde: Color = Color(f.r, f.g, f.b, 0.9 * alfa)
	draw_polyline(izq, borde, maxf(1.5, caja * 0.022), true)
	draw_polyline(der, borde, maxf(1.5, caja * 0.022), true)
	# LOS FILAMENTOS: salen de los dos bordes hacia fuera, se quiebran y se bifurcan. Van escalonados
	# (los del medio salen antes y llegan mas lejos) para que la grieta parezca extenderse.
	for i in range(1, n - 1, 2):
		for lado2 in 2:
			var desde: Vector2 = izq[i] if lado2 == 0 else der[i]
			var s2: float = 1.0 if lado2 == 0 else -1.0
			var centralidad: float = sin(PI * float(i) / float(n - 1))
			var largo_f: float = caja * (0.12 + 0.42 * w) * centralidad \
				* (0.5 + 0.7 * absf(sin(g * 1.7 + float(i) * 2.3 + float(lado2) * 4.1)))
			_filamento(desde, Vector2(s2, 0.0).rotated(sin(g + float(i) * 1.9 + float(lado2)) * 0.7),
				largo_f, g + float(i) * 3.7 + float(lado2) * 11.0, f, 0.55 * alfa * (1.0 - w * 0.3),
				maxf(1.0, caja * 0.016), 2)
	_salpicadura(p, Vector2(cos(ang), sin(ang)), col, alfa, w, caja, g, 9)


# HACHAZO BRUTAL. El golpe gordo del arma (x2.45) y el mas salvaje del juego: no hay tecnica, hay
# todo el cuerpo detras. Arco enorme, el trazo mas grueso, y la sangre saliendo por los dos lados.
#
# Es el UNICO del hacha que si cruza la tarjeta entera. No es una incoherencia con lo de "el hacha
# muerde": es la excepcion que hace que se note: cuatro de sus cinco se quedan dentro y esta se lleva
# por delante todo lo que habia. Si se parase como las demas seria un hachazo basico mas gordo.
func _pintar_hachazo_brutal(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, COLETA_BRUTAL, 0.07)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var sentido: float = 1.0 if sin(g * 5.7) > 0.0 else -1.0
	var ang: float = (PI * 0.26 + sin(g * 3.3) * 0.14) * sentido
	var k: float = 1.0 - pow(1.0 - clampf(v / 0.32, 0.0, 1.0), 2.2)
	var dir := Vector2(cos(ang), sin(ang))
	_tajo(b, ang, caja * 2.05, 0.06 * sentido, k, col, alfa, caja * 0.150,
		int(e.get("elem", 0)), g)
	if v <= 0.22:
		return
	var w: float = (v - 0.22) / 0.78
	# Por los DOS extremos del arco: ha entrado por un lado y ha salido por el otro.
	_salpicadura(b + dir * caja * 0.55, dir, col, alfa, w, caja, g, 9)
	_salpicadura(b - dir * caja * 0.55, -dir, col, alfa, w, caja, g + 2.1, 6)


# CARNICERIA. Tres hachazos y ninguno limpio: "dejas de buscar el golpe bueno y empiezas a repartir".
#
# UN HACHAZO POR GOLPE (mira e["golpe"]), que si no salen nueve. Y lo que dice que es un reparto y no
# una combinacion ensayada es que cada uno va POR SU LADO: el angulo y el sitio salen del INDICE del
# golpe y no de la semilla, asi que los tres caen desordenados a proposito y siempre distintos entre
# si. Sacandolos de la semilla los tres salian parecidos, o sea: ordenados.
func _pintar_carniceria(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, COLETA_CARNICERIA, 0.04)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var i: int = clampi(int(e.get("golpe", 0)), 0, 2)
	# Tres angulos bien distintos y tres sitios distintos de la tarjeta.
	var angs := [PI * 0.32, -PI * 0.28, PI * 0.62]
	var sitios := [Vector2(-0.16, -0.14), Vector2(0.18, 0.06), Vector2(-0.06, 0.20)]
	var ang: float = float(angs[i]) + sin(g * 2.3 + float(i) * 1.7) * 0.12
	var b: Vector2 = Vector2(r0[2]) + Vector2(sitios[i]) * caja
	var k: float = 1.0 - pow(1.0 - clampf(v / 0.30, 0.0, 1.0), 2.4)
	# Cortos: son hachazos atropellados, no arcos completos.
	# GRANDES. La primera version los hizo cortos "porque son atropellados" y quedaron en tres
	# rayitas: repartir a lo bestia con un hacha de dos manos no es dar hachazos pequeños, es dar
	# hachazos enteros sin apuntar. Lo que dice el atropello es que van desordenados (angulos y sitios
	# distintos, y el adelanto mas corto del juego), no que sean chicos.
	var p: Vector2 = _mordisco_de_filo(b + Vector2(cos(ang), sin(ang)) * caja * 0.26, ang,
		caja * 1.15, k, col, alfa, caja * 0.088, int(e.get("elem", 0)), g + float(i) * 3.1, 0.04)
	if v > 0.24:
		_salpicadura(p, Vector2(cos(ang), sin(ang)), col, alfa, (v - 0.24) / 0.76, caja,
			g + float(i) * 3.1, 5)


# DESGARRO. "Entra y tira hacia fuera." Dos tiempos y DOS TRAZOS: el filo entra (mordisco) y despues
# cambia de direccion y sale tirando. Los dos juntos hacen un GANCHO, y un gancho es lo unico que se
# lee como arrancar en vez de como cortar.
#
# ANTES ERA UNA BRECHA y estaba mal. El tiron se pintaba como un huso oscuro -- ancho en el medio y
# cerrado en los dos extremos, para que "se leyera como algo abierto" -- y lo que salia delante del
# tajo era un OJO. Un huso simetrico es una hoja o un ojo, nunca una herida, y encima incumplia lo de
# no pintar marcas de herida aparte del trazo.
#
# Lo que cuenta el gesto es el RECORRIDO, no una forma pegada al final: el filo va por un sitio, se
# para, y sale por otro. Eso se dice con dos trazos y ya esta.
func _pintar_desgarro(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, COLETA_DESGARRO, 0.07)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var lado: float = 1.0 if sin(g * 5.7) > 0.0 else -1.0
	var ang: float = PI * 0.38 * lado
	# PRIMER TIEMPO: entra. Se para pronto (0.22) porque lo que cuenta viene despues.
	var k: float = 1.0 - pow(1.0 - clampf(v / 0.22, 0.0, 1.0), 2.6)
	var p: Vector2 = _mordisco_de_filo(b + Vector2(cos(ang), sin(ang)) * caja * 0.18, ang,
		caja * 0.80, k, col, alfa, caja * 0.075, int(e.get("elem", 0)), g, 0.04 * lado)
	if v <= 0.24:
		return
	# SEGUNDO TIEMPO: tira. Sale del punto donde se quedo clavado el filo y va hacia AFUERA de la
	# tarjeta y hacia arriba -- el gesto de arrancar, no el de cortar. Y va CASI PERPENDICULAR al de
	# entrada: si saliera por donde entro seria el mismo hachazo mas largo, y lo que hace que se lea
	# el tiron es justo el quiebro entre los dos.
	var w: float = clampf((v - 0.24) / 0.55, 0.0, 1.0)
	var tiron := Vector2(lado, -0.75).normalized()  # hacia fuera y hacia arriba
	var largo_t: float = caja * 0.95
	# El trazo del tiron ARRANCA en 'p' (donde se paro el filo), asi que su centro va medio largo por
	# delante. Crece con w, o sea que se ve salir en vez de aparecer entero.
	var centro_t: Vector2 = p + tiron * largo_t * 0.5
	# Acelera (w*w): un tiron empieza costando y acaba saliendo de golpe.
	_tajo(centro_t, tiron.angle(), largo_t, 0.05 * lado, w * w, col, alfa, caja * 0.085,
		int(e.get("elem", 0)), g + 1.7)
	# Y lo que se lleva por delante, saliendo despedido por donde ha salido el filo.
	_salpicadura(p + tiron * largo_t * w * w, tiron, col, alfa, w, caja, g, 8)


# SED DE SANGRE. Se pinta sobre TI, no sobre el bicho (llega por fx_sobre_mi): el hachazo es un
# HACHA_TAJO normal contra el enemigo y esto es lo que se te suelta por dentro al notar que ha
# entrado.
#
# NI ARMA NI GOLPE NI UNA SOLA GOTA DE SANGRE. Lo primero que pide el nombre es salpicar tu tarjeta,
# y eso diria justo lo contrario: que el herido eres tu. Lo que se pinta es un LATIDO -- un
# resplandor que sube desde abajo y pulsa cada vez mas rapido.
func _pintar_sed_sangre(e: Dictionary) -> void:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var b: Vector2 = e["b"]
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var sube: float = clampf(t / dur, 0.0, 1.0)
	var v: float = clampf((t - dur) / COLETA_SED, 0.0, 1.0) if t > dur else 0.0
	var alfa: float = 1.0 if v < 0.66 else 1.0 - (v - 0.66) / 0.34
	if alfa <= 0.0:
		return
	# EL COLOR es el de la imbuicion si la hay y ROJO VIVO si no. No el _SANGRE del catalogo: ese es
	# un granate pensado para pintarse SOBRE algo, y aqui va sobre el fondo oscuro de la pelea (el
	# mismo motivo por el que la Puñalada no lo usa para su fogonazo).
	var c: Color = col if _imbuido(col) else Color(0.90, 0.16, 0.14)
	# EL LATIDO, ACELERANDO. Un parpadeo a ritmo constante se lee como un aura cualquiera; uno que va
	# a mas se lee como algo que se te esta subiendo, que es lo que dice la ficha.
	var ritmo: float = t * (7.0 + 9.0 * v)
	var pulso: float = 0.55 + 0.45 * pow(absf(sin(ritmo)), 3.0)
	# ES LA TARJETA LA QUE LATE, no una forma puesta encima. Dos intentos fallidos antes de dar con
	# esto, los dos por el mismo motivo -- dibujar un OBJETO sobre el personaje:
	#   1. Tres poligonos macizos subiendo del suelo -> una CUPULA roja opaca tapando media tarjeta.
	#      Parecia una gelatina puesta encima de el, no algo que le pasa por dentro.
	#   2. Los mismos, huecos -> tres arcos concentricos, o sea un arcoiris. Peor: ya ni se sabia que
	#      era.
	# Lo que le pasa al personaje se dice encendiendo AL PERSONAJE. El borde de su recuadro se pone al
	# rojo y late: no tapa nada, se ve quien lo lleva, y a un vistazo en plena pelea se lee al
	# instante -- ese de ahi esta encendido.
	var w2: float = float(e["ancho"])
	var h2: float = w2 * 1.33          # la proporcion de las tarjetas de combate
	var media := Vector2(w2, h2) * 0.5
	# El resplandor va HACIA DENTRO desde el borde: tres marcos cada vez mas pequeños y mas flojos.
	# Crece con 'sube' (mientras se te sube) y respira con el pulso.
	for capa in 3:
		var dentro: float = float(capa) * w2 * 0.050 * (0.6 + 0.6 * pulso)
		var m: Vector2 = media - Vector2(dentro, dentro)
		if m.x <= 2.0 or m.y <= 2.0:
			continue
		var marco := PackedVector2Array([
			b + Vector2(-m.x, -m.y), b + Vector2(m.x, -m.y),
			b + Vector2(m.x, m.y), b + Vector2(-m.x, m.y), b + Vector2(-m.x, -m.y)])
		var op: float = (0.50 - 0.13 * float(capa)) * alfa * pulso * (0.35 + 0.65 * sube)
		draw_polyline(marco, Color(c.r, c.g, c.b, op),
			maxf(1.5, w2 * 0.020 * (0.7 + 0.5 * pulso)), true)
	# Y las vetas que trepan con el y se apagan arriba.
	for i in 4:
		var kk: float = fposmod(v * 1.5 + float(i) * 0.26 + g * 0.1, 1.0)
		var x: float = sin(g + float(i) * 2.3) * caja * 0.26
		var y0: float = caja * (0.40 - 1.00 * kk)
		var hilo := PackedVector2Array()
		for j in 5:
			var s: float = float(j) / 4.0
			hilo.append(b + Vector2(x + sin(g * 1.7 + float(i) + s * 4.0) * caja * 0.05,
				y0 + s * caja * 0.16))
		draw_polyline(hilo, Color(c.r, c.g, c.b, 0.45 * alfa * sin(PI * kk) * pulso),
			maxf(1.0, caja * 0.014), true)


# ============================================================
#  EL MARTILLO GRANDE: lo suyo pasa en el suelo
# ============================================================
# COMPARTE ARMA CON LA MAZA -- las dos son romas y las dos usan _porrazo -- asi que el peligro aqui
# es sacar "una maza mas grande". No se separan por el tamaño, se separan por CONTRA QUE PEGAN:
#
#   la maza     golpea AL BICHO   -- el porrazo pasa en su tarjeta y ahi se acaba
#   el martillo golpea EL SUELO   -- revienta abajo y lo que hace daño es lo que SE PROPAGA
#
# Por eso casi todos sus gestos nacen ABAJO (en `suelo`, no en el centro de la tarjeta) y tiran de
# _reventon_de_suelo, que se saco del Tajo del verdugo justo para esta arma. Y por eso tres de las
# cinco son de grupo: un terremoto es UNO.
#
# LA UNICA QUE PEGA ARRIBA es el Rompecorazas, y es a proposito: "no busca la carne, busca la chapa".
# Que sea la excepcion es lo que la hace reconocible entre cuatro demoliciones.
const COLETA_MARTILLO := 0.42          # el basico, y aun asi mas largo que el de la maza
const COLETA_SISMICO := 0.56
const COLETA_ONDA := 0.50
const COLETA_ROMPECORAZAS := 0.36      # el seco del arma
const COLETA_MARTILLO_GUERRA := 0.62   # empata con el Tajo del verdugo
const COLETA_MARTILLO_ALTO := 0.62     # el martillo se queda arriba mientras dura la carga
const COLETA_TEMBLOR := 0.66           # la mas larga: lo suyo es que NO PARA

# DONDE ESTA EL SUELO, en fracciones de caja por debajo del centro de la tarjeta. Una constante y no
# un literal repetido en seis painters: si el suelo de un gesto cae dos pixeles mas abajo que el de
# otro, la misma arma parece pegar a dos alturas distintas.
const SUELO_MARTILLO := 0.34


# LA CABEZA DEL MARTILLO, para los dos gestos en los que el arma esta QUIETA y es la protagonista (la
# carga del Martillo de guerra). En los golpes NO se dibuja: ahi vale la misma regla que en la maza,
# solo la marca del impacto.
#
# Un rectangulo con el mango: no hace falta mas, y cualquier detalle de mas a este tamaño se
# convierte en ruido. El contorno oscuro es obligatorio o se funde con su propio resplandor.
func _cabeza_martillo(c: Vector2, dir: Vector2, tam: float, col: Color, alfa: float) -> void:
	var lado := Vector2(-dir.y, dir.x)
	# EL MANGO sale por detras de la cabeza, en la direccion contraria a donde apunta. GORDO y oscuro:
	# fino y claro parecia el palo de un cartel, y con el la cabeza pasaba a ser el cartel.
	draw_line(c - dir * tam * 0.30, c - dir * tam * 2.6,
		Color(0.26, 0.18, 0.13, alfa), maxf(3.0, tam * 0.42), true)
	# LA CABEZA ES UN BLOQUE RECTANGULAR, ancho y chato: 0.95 a lo ancho por 0.42 a lo largo del
	# mango. Dos intentos antes de esto y los dos por la SILUETA:
	#   medidas parecidas -> un cuadrado con un palo, o sea una pala o un cartel;
	#   estrechandose por detras -> un trapecio con un palo, o sea una COPA.
	# Un rectangulo limpio y ancho no se parece a nada mas.
	var cuerpo := PackedVector2Array([
		c + dir * tam * 0.42 + lado * tam * 0.95,
		c + dir * tam * 0.42 - lado * tam * 0.95,
		c - dir * tam * 0.42 - lado * tam * 0.95,
		c - dir * tam * 0.42 + lado * tam * 0.95])
	# Y EN ACERO MEDIO, no en el _ACERO claro de las hojas: a este tamaño una mancha casi blanca se
	# lee como papel. Una masa de hierro es oscura y lo que brilla es el reflejo.
	draw_colored_polygon(cuerpo, Color(0.46, 0.49, 0.55, alfa))
	var cerr := PackedVector2Array(cuerpo)
	cerr.append(cuerpo[0])
	draw_polyline(cerr, Color(_ENCIA.r, _ENCIA.g, _ENCIA.b, 0.9 * alfa), maxf(2.0, tam * 0.20), true)
	# EL REFLEJO: una banda clara cruzando el bloque por el medio. Es lo que dice metal, y ademas
	# marca por donde entra el mango.
	var f: Color = _filo_col(col)
	draw_line(c - dir * tam * 0.42 + lado * tam * 0.30, c + dir * tam * 0.42 + lado * tam * 0.30,
		Color(_ACERO.r, _ACERO.g, _ACERO.b, 0.85 * alfa), maxf(2.0, tam * 0.22), true)
	# LA CARA que golpea, del color de la imbuicion: la unica parte que se tiñe, igual que el filo de
	# las armas de corte (el acero no se tiñe entero).
	draw_line(c + dir * tam * 0.42 + lado * tam * 0.95, c + dir * tam * 0.42 - lado * tam * 0.95,
		Color(f.r, f.g, f.b, alfa), maxf(2.0, tam * 0.24), true)


# EL MAZAZO BASICO. Revienta abajo: el porrazo va en el suelo, no en el pecho, y de el sale el
# reventon. Es lo mismo que hace la maza pero UNA FILA MAS ABAJO, y esa diferencia de altura es la
# que dice de un vistazo cual de las dos armas llevas.
func _pintar_martillo_golpe(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, COLETA_MARTILLO, 0.06)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var suelo := Vector2(float(r0[2].x), float(e["b"].y) + caja * SUELO_MARTILLO)
	var k: float = 1.0 - pow(1.0 - clampf(v / 0.20, 0.0, 1.0), 3.0)
	_porrazo(suelo, caja * 0.34 * (0.32 + 0.68 * k), col, alfa, v, g, int(e.get("elem", 0)))
	if v <= 0.14:
		return
	_reventon_de_suelo(suelo, caja, _filo_col(col), alfa, (v - 0.14) / 0.86, g, 0.55)


# GOLPE SISMICO. "Revienta el suelo y sacude a todo lo que hay alrededor": el mismo reventon pero
# ANCHO, cubriendo a todos los alcanzados.
#
# Es de grupo, asi que e["ancho"] trae el ancho de TODO lo alcanzado: de ahi sale el alcance (ver
# _radio_grupo). Un sismico a tres tiene que partir el suelo bajo los tres, no tres veces bajo uno.
func _pintar_golpe_sismico(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, COLETA_SISMICO, 0.04)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var suelo := Vector2(float(r0[2].x), float(e["b"].y) + caja * SUELO_MARTILLO)
	var k: float = 1.0 - pow(1.0 - clampf(v / 0.18, 0.0, 1.0), 3.0)
	_porrazo(suelo, caja * 0.44 * (0.30 + 0.70 * k), col, alfa, v, g, int(e.get("elem", 0)))
	if v <= 0.12:
		return
	# El alcance sale de LO ALCANZADO, no del daño: el 0.5 es medio ancho del grupo, que es el radio
	# justo para taparlo entero (el mismo criterio que el pisoton de los bichos).
	var esc: float = maxf(0.8, _radio_grupo(e, 0.5, caja) / caja)
	_reventon_de_suelo(suelo, caja, _filo_col(col), alfa, (v - 0.12) / 0.88, g, esc)


# ONDA EXPANSIVA. Un martillazo al suelo y lo que cuenta es lo que sale de el: anillos BAJOS que se
# abren y barren la fila. Casi no hay crater -- aqui no se rompe el suelo, se sacude.
#
# Se separa del Sismico porque son la misma jugada con distinto reparto (aquel pega y esto controla):
# el Sismico es CRATER (grietas, cascotes) y este es ONDA (anillos que se van). Sin ese contraste
# eran dos terremotos iguales con distinto nombre.
func _pintar_onda_expansiva(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, COLETA_ONDA, 0.04)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var f: Color = _filo_col(col)
	var suelo := Vector2(float(r0[2].x), float(e["b"].y) + caja * SUELO_MARTILLO)
	var k: float = 1.0 - pow(1.0 - clampf(v / 0.16, 0.0, 1.0), 3.0)
	_porrazo(suelo, caja * 0.30 * (0.32 + 0.68 * k), col, alfa, v, g, int(e.get("elem", 0)))
	# LAS ONDAS: cuatro anillos escalonados, MUY achatados, que llegan hasta el borde de lo alcanzado.
	# Achatados de verdad (0.16) porque van A RAS: redondos se leerian como burbujas subiendo.
	# El suelo va a caja*1.25 y no a 0.9: contra UN solo bicho la onda tiene que salirse de su
	# tarjeta igual, o no se lee que barre nada.
	var alcance: float = _radio_grupo(e, 0.62, caja * 1.25)
	for i in 4:
		var kk: float = clampf((v - float(i) * 0.13) / 0.72, 0.0, 1.0)
		if kk <= 0.0:
			continue
		var rr: float = alcance * kk
		_anillo(suelo, rr, rr * 0.16, Color(f.r, f.g, f.b, 0.70 * alfa * (1.0 - kk)),
			maxf(2.0, caja * 0.060 * (1.0 - kk * 0.6)))
	# Y el polvo que levanta cada onda al pasar, a los dos lados.
	if v <= 0.20:
		return
	var w: float = (v - 0.20) / 0.80
	for i in 8:
		var lado: float = -1.0 if i % 2 == 0 else 1.0
		var d: float = alcance * (0.25 + 0.75 * w) * (0.4 + 0.6 * absf(sin(g + float(i) * 1.9)))
		var p: Vector2 = suelo + Vector2(lado * d, -caja * 0.10 * sin(PI * w) \
			* (0.5 + 0.7 * absf(sin(g * 2.1 + float(i)))))
		draw_circle(p, maxf(1.0, caja * 0.030 * (1.0 - w)),
			Color(0.74, 0.70, 0.64, 0.45 * alfa * (1.0 - w)))


# TEMBLOR. "Golpeas el suelo y NO PARAS." Es la unica del arma que no es un golpe sino una duracion:
# tres martillazos seguidos, cada uno con su onda, y las grietas abriendose un poco mas en cada uno.
#
# Lo que la separa de la Onda expansiva es justo eso -- aquella es UN martillazo y su onda; esta
# insiste. Y por eso tiene la coleta mas larga del arma: si durara lo mismo, seria la misma.
func _pintar_temblor(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, COLETA_TEMBLOR, 0.03)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var f: Color = _filo_col(col)
	var alcance: float = _radio_grupo(e, 0.58, caja * 0.9)
	# LOS TRES MARTILLAZOS. Cada uno cae en un sitio distinto a lo largo de la fila y en su momento:
	# repartidos en el espacio y en el tiempo es lo que dice "no para", frente a uno solo mas gordo.
	for i in 3:
		var t_i: float = float(i) * 0.22
		if v < t_i:
			continue
		var vi: float = (v - t_i) / maxf(1.0 - t_i, 0.01)
		var x: float = (float(i) - 1.0) * alcance * 0.42 + sin(g + float(i) * 2.7) * caja * 0.10
		var suelo := Vector2(float(e["b"].x) + x, float(e["b"].y) + caja * SUELO_MARTILLO)
		var k: float = 1.0 - pow(1.0 - clampf(vi / 0.16, 0.0, 1.0), 3.0)
		_porrazo(suelo, caja * 0.24 * (0.32 + 0.68 * k), col, alfa * (1.0 - vi * 0.35), vi,
			g + float(i) * 3.1, int(e.get("elem", 0)))
		# Su onda, baja y corta: son tres sacudidas, no tres explosiones.
		for j in 2:
			var kk: float = clampf((vi - float(j) * 0.14) / 0.62, 0.0, 1.0)
			if kk <= 0.0:
				continue
			var rr: float = alcance * 0.52 * kk
			_anillo(suelo, rr, rr * 0.18, Color(f.r, f.g, f.b, 0.45 * alfa * (1.0 - kk)),
				maxf(1.5, caja * 0.032 * (1.0 - kk * 0.6)))
	# LA GRIETA QUE SE VA ABRIENDO a lo largo de toda la fila, y que crece con el gesto entero (no con
	# cada martillazo): es el hilo que ata los tres y lo que dice que esto sigue pasando.
	var abre: float = clampf(v / 0.72, 0.0, 1.0)
	var y0: float = float(e["b"].y) + caja * SUELO_MARTILLO
	# VA A TROMPICONES, no ondulando. La primera version la trazaba con dos senos y salia una linea
	# lisa y gruesa serpenteando: un CABLE tirado por el suelo. Una grieta cambia de direccion de
	# golpe y no vuelve atras -- pocos puntos, quiebros secos y el grosor bajando hacia las puntas.
	var n: int = 9
	var grieta := PackedVector2Array()
	for i in n:
		var u: float = float(i) / float(n - 1)
		# El quiebro alterna de lado (i % 2) con magnitud desigual: eso es lo que lo hace roto en vez
		# de zigzag de dibujo animado.
		var quiebro: float = (1.0 if i % 2 == 0 else -1.0) 			* caja * 0.055 * (0.4 + 0.9 * absf(sin(g * 2.3 + float(i) * 1.9)))
		grieta.append(Vector2(
			float(e["b"].x) + (u - 0.5) * 2.0 * alcance * abre,
			y0 + quiebro * sin(PI * u)))
	draw_polyline(grieta, Color(0.08, 0.07, 0.09, 0.85 * alfa * (1.0 - v * 0.25)),
		maxf(2.0, caja * 0.030 * (1.0 - v * 0.3)), true)
	# Y las ramitas que salen de ella, que es lo que la separa de una raya: el suelo se agrieta hacia
	# los lados segun se abre.
	for i in range(1, n - 1, 2):
		var lado2: float = 1.0 if i % 4 == 1 else -1.0
		_filamento(grieta[i], Vector2(sin(g + float(i)) * 0.5, lado2),
			caja * 0.22 * abre * (0.5 + 0.6 * absf(sin(g * 1.7 + float(i)))),
			g + float(i) * 4.3, Color(0.08, 0.07, 0.09), 0.7 * alfa * (1.0 - v * 0.3),
			maxf(1.0, caja * 0.016), 1)


# ROMPECORAZAS. "No busca la carne, busca la chapa." LA UNICA DEL ARMA QUE PEGA ARRIBA, al pecho, y
# la unica que no toca el suelo: ser la excepcion es lo que la hace reconocible entre cuatro
# demoliciones que se parecen.
#
# Lo que se ve no es la armadura sino LO QUE LE PASA: el porrazo arriba, las abolladuras hundiendose
# alrededor y los pedazos PLANOS de chapa saltando. La Corrosion que deja (el estado) es eso -- la
# chapa sigue puesta pero ya no sirve.
func _pintar_rompecorazas(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, COLETA_ROMPECORAZAS, 0.07)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var f: Color = _filo_col(col)
	# ARRIBA, a la altura del pecho.
	var p: Vector2 = b + Vector2(0.0, -caja * 0.14)
	# NO SE DIBUJA LA PIEZA DE ARMADURA, y eso costo dos intentos. Un trapecio grande parecia una
	# PANTALLA plantada delante del bicho, y al darle forma de peto (hombros arriba, punta abajo) pasó
	# a ser un ESCUDO HERALDICO -- que encima ya es otra cosa en este juego (ver _escudo_cara).
	#
	# La chapa no hace falta pintarla: se cuenta con LO QUE LE PASA. Un porrazo arriba, en el pecho,
	# las ABOLLADURAS hundiendose alrededor y los pedazos PLANOS saltando. Eso dice "le has reventado
	# la coraza" sin plantar ningun objeto nuevo en pantalla que se pueda confundir con otro.
	var k: float = 1.0 - pow(1.0 - clampf(v / 0.24, 0.0, 1.0), 3.0)
	_porrazo(p, caja * 0.26 * (0.32 + 0.68 * k), col, alfa, v, g, int(e.get("elem", 0)))
	if v <= 0.22:
		return
	var w: float = (v - 0.22) / 0.78
	# LAS ABOLLADURAS: dos arcos que se cierran sobre el punto en vez de abrirse. Al reves que la onda
	# de un porrazo normal -- aqui la chapa se mete HACIA DENTRO, no sale nada.
	for i in 2:
		var kk: float = clampf(w - float(i) * 0.18, 0.0, 1.0)
		if kk <= 0.0:
			continue
		var rr: float = caja * (0.34 - 0.10 * kk) * (1.0 - float(i) * 0.30)
		var arco := PackedVector2Array()
		for j in 9:
			var a: float = PI * 0.15 + PI * 0.70 * float(j) / 8.0
			arco.append(p + Vector2(cos(a) * rr, sin(a) * rr * 0.62 - caja * 0.04 * kk))
		draw_polyline(arco, Color(_ACERO_OSCURO.r, _ACERO_OSCURO.g, _ACERO_OSCURO.b,
			0.85 * alfa * kk), maxf(2.0, caja * 0.026), true)
	# Y LA GRIETA en la chapa, ramificandose desde el golpe (el mismo _filamento de la Hendedura: lo
	# que se raja se raja igual sea carne o sea metal).
	for i in 3:
		var a2: float = -PI * 0.5 + (float(i) - 1.0) * 1.15 + sin(g + float(i)) * 0.25
		_filamento(p, Vector2(cos(a2), sin(a2)), caja * 0.30 * w, g + float(i) * 5.1, f,
			0.6 * alfa * (1.0 - w * 0.4), maxf(1.0, caja * 0.016), 1)
	# Y LOS PEDAZOS de chapa saltando. Van PLANOS y girando, no redondos: es metal arrancado, no
	# cascotes de suelo (esos son de las otras cuatro, y tienen que distinguirse).
	for i in 5:
		var ang: float = -PI * 0.5 + (float(i) - 2.0) * 0.44 + sin(g + float(i)) * 0.14
		var u2 := Vector2(cos(ang), sin(ang))
		var d: float = caja * (0.20 + 0.60 * w)
		var q: Vector2 = p + u2 * d + Vector2(0.0, caja * 0.45 * w * w)
		var tam: float = caja * 0.070 * (1.0 - w * 0.4)
		var giro: float = w * 6.0 * (1.0 if i % 2 == 0 else -1.0) + g
		var d1 := Vector2(cos(giro), sin(giro))
		var d2 := Vector2(-d1.y, d1.x)
		var trozo := PackedVector2Array([
			q + d1 * tam + d2 * tam * 0.22, q - d1 * tam + d2 * tam * 0.30,
			q - d1 * tam - d2 * tam * 0.22, q + d1 * tam - d2 * tam * 0.30])
		draw_colored_polygon(trozo, Color(_ACERO_OSCURO.r, _ACERO_OSCURO.g, _ACERO_OSCURO.b,
			0.9 * alfa * (1.0 - w * 0.8)))
		draw_line(q + d1 * tam, q - d1 * tam, Color(f.r, f.g, f.b, 0.7 * alfa * (1.0 - w)),
			maxf(1.0, tam * 0.22), true)


# MARTILLO DE GUERRA. El verdugo del martillo: se anuncia un TURNO ENTERO (carga_turnos) y cae desde
# muy arriba. x3.2 de daño, el golpe mas gordo del arma.
#
# Reusa el reventon de suelo como el Tajo del verdugo, pero SIN la columna de luz: esa se queda en el
# verdugo, que es lo suyo. Aqui lo que sube del crater es POLVO, que es lo que levanta una masa de
# hierro y no una hoja mistica -- y de paso los dos golpes gordos del juego no se confunden.
func _pintar_martillo_guerra(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, COLETA_MARTILLO_GUERRA, 0.03)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var f: Color = _filo_col(col)
	var suelo := Vector2(b.x, float(e["b"].y) + caja * SUELO_MARTILLO)
	# LA CAIDA. Aqui SI se dibuja la cabeza: es lo unico que baja, y sin ella caeria una raya suelta.
	# El arma esta sola en pantalla y es la protagonista, que es la excepcion de siempre.
	var k: float = clampf(v / 0.26, 0.0, 1.0)
	if k < 1.0:
		var cae: float = 1.0 - pow(1.0 - k, 3.2)
		var desde: Vector2 = suelo - Vector2(0.0, caja * 2.30)
		_cabeza_martillo(desde.lerp(suelo, cae), Vector2.DOWN, caja * 0.30, col, alfa)
		# Las lineas de velocidad detras, que es lo que dice cuanto pesa lo que viene.
		for i in 3:
			var x: float = (float(i) - 1.0) * caja * 0.22
			var p0: Vector2 = desde.lerp(suelo, cae) + Vector2(x, -caja * (0.45 + 0.5 * cae))
			draw_line(p0, p0 + Vector2(0.0, -caja * 0.55 * cae),
				Color(f.r, f.g, f.b, 0.35 * alfa), maxf(1.5, caja * 0.020), true)
		return   # sigue bajando: el reventon es AL LLEGAR
	var w: float = clampf((v - 0.26) / 0.74, 0.0, 1.0)
	_porrazo(suelo, caja * 0.52 * (1.0 - w * 0.25), col, alfa, w, g, int(e.get("elem", 0)))
	_reventon_de_suelo(suelo, caja, f, alfa, w, g, 1.15)
	# EL POLVO: nubes que suben del crater y se abren. Es el relevo de la columna de luz del verdugo,
	# y lo que separa "ha caido una masa de hierro" de "ha caido algo mistico".
	for i in 7:
		var kk: float = clampf(w - float(i) * 0.045, 0.0, 1.0)
		if kk <= 0.0:
			continue
		var ang: float = -PI * 0.5 + (float(i) - 3.0) * 0.30 + sin(g + float(i) * 1.7) * 0.12
		var u := Vector2(cos(ang), sin(ang))
		var d: float = caja * (0.20 + 1.35 * kk)
		var r: float = caja * (0.14 + 0.26 * kk) * (0.6 + 0.5 * absf(sin(g * 2.3 + float(i))))
		draw_circle(suelo + u * d, r, Color(0.62, 0.58, 0.53, 0.30 * alfa * (1.0 - kk)))


# EL MARTILLO EN ALTO. Lo que se echa encima el que carga (por fx_sobre_mi): el martillo levantado
# con las dos manos y aguantado ahi, temblando por el peso.
#
# ES EL PRIMO DEL ACERO_EN_ALTO (67) DE LOS MANDOBLES, y se hizo aparte en vez de reusarlo por una
# razon tonta pero definitiva: aquel dibuja una HOJA. Un espadon levantado sobre la cabeza de alguien
# que lleva un martillo se lee como que ha cambiado de arma.
func _pintar_martillo_en_alto(e: Dictionary) -> void:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var b: Vector2 = e["b"]
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var sube: float = clampf(t / dur, 0.0, 1.0)
	var v: float = clampf((t - dur) / COLETA_MARTILLO_ALTO, 0.0, 1.0) if t > dur else 0.0
	var alfa: float = 1.0 if v < 0.72 else 1.0 - (v - 0.72) / 0.28
	if alfa <= 0.0:
		return
	# Sube durante el vuelo y se queda arriba TEMBLANDO. El temblor no es un adorno: es lo que dice
	# que eso pesa y que aguantarlo cuesta, o sea por que la habilidad tarda un turno.
	var alto: float = caja * (0.15 + 0.72 * sube)
	var tiembla := Vector2(sin(t * 11.0 + g), cos(t * 8.0 + g) * 0.5) * caja * 0.022 * sube
	_cabeza_martillo(b + Vector2(0.0, -alto) + tiembla, Vector2.UP, caja * 0.32, col, alfa)
	# Y el peso que se junta arriba: un resplandor que crece mientras aguanta.
	if v <= 0.0:
		return
	var f: Color = _filo_col(col)
	var brillo: float = sin(PI * clampf(v / 0.9, 0.0, 1.0))
	if brillo > 0.0:
		_estrella(b + Vector2(0.0, -alto - caja * 0.32) + tiembla,
			caja * 0.42 * brillo, caja * 0.30 * brillo, 0.55,
			Color(f.r, f.g, f.b, 0.55 * alfa * brillo))


# ============================================================
#  EL BASTON: barre romo, y lo demas es arcano
# ============================================================
# NO SE PARECE A NINGUNA DE LAS OCHO ANTERIORES, y no por capricho: es el arma del mago y lo suyo
# casi no es pegar. motion_value 0.4, el mas flojo del juego. Eso hay que dibujarlo -- sus dos golpes
# tienen que verse POCA COSA al lado de un hachazo, porque es lo que son.
#
# El problema al empezar era que no cabia en ninguno de los dos lenguajes que ya habia:
#   con el trazo de las armas de corte (_tajo) sale un canto brillante y pasa a ser una ESPADA;
#   con el porrazo de la maza (_porrazo) sale una masa que revienta y pasa a ser un MAZAZO.
# Un palo es lo de en medio: BARRE, pero no corta. De ahi _barrido_romo -- la misma cinta pero mate,
# sin canto -- y una marquita al final.
#
# La otra mitad del kit es ARCANA y no toca a nadie: el Foco, el Sello, el Velo y el Viento. Ninguna
# embiste (un mago no se lanza contra nadie) y esa quietud es la mitad de su personalidad.
const COLETA_BASTON := 0.24        # corto y sin gracia: es lo que es
const COLETA_BASTONAZO := 0.34
const COLETA_FOCO := 0.75          # hay que ver los signos juntarse
const COLETA_SELLO := 0.55         # trazar el signo y cerrarlo de golpe
const COLETA_VELO := 0.80          # es un buff largo: el velo se queda puesto
const COLETA_VIENTO := 0.60


# UNA CINTA MATE. Lo mismo que _tajo pero SIN el canto vivo: es por donde ha pasado un palo, no un
# filo. La diferencia son dos lineas de codigo y es lo que separa el baston de una espada.
#
# Tampoco lleva el comportamiento del elemento (ni chispas, ni goteo, ni zigzag): un baston imbuido
# sigue siendo un palo. El color solo tiñe la cinta, y flojito.
func _barrido_romo(centro: Vector2, ang: float, largo: float, comba: float, k: float,
		col: Color, alfa: float, grosor: float) -> void:
	if k <= 0.02:
		return
	var dir := Vector2(cos(ang), sin(ang))
	var lado := Vector2(-dir.y, dir.x)
	var a: Vector2 = centro - dir * largo * 0.5
	var b: Vector2 = centro + dir * largo * 0.5
	var ctrl: Vector2 = centro + lado * comba * largo
	var n: int = 14
	var izq := PackedVector2Array()
	var der := PackedVector2Array()
	for i in n + 1:
		var s: float = float(i) / float(n) * k
		var p: Vector2 = _bez(a, ctrl, b, s)
		var t2: Vector2 = _bez(a, ctrl, b, minf(s + 0.02, 1.0)) - p
		var d2: Vector2 = t2.normalized() if t2.length() > 0.01 else dir
		var l2 := Vector2(-d2.y, d2.x)
		# Gorda en la cabeza y afilandose hacia la cola, igual que el tajo: lo viejo del trazo se
		# borra. Lo que cambia es como se remata, no como se mueve.
		var w: float = grosor * pow(float(i) / float(n), 1.1)
		izq.append(p + l2 * w)
		der.append(p - l2 * w)
	var pts := PackedVector2Array(izq)
	for i in range(der.size() - 1, -1, -1):
		pts.append(der[i])
	var f: Color = _filo_col(col)
	# MATE: el relleno un poco mas fuerte que en un tajo (0.34) para que se vea la cinta, y el borde
	# APAGADO en vez del canto vivo. Con el canto brillante esto era un espadazo, sin mas.
	draw_colored_polygon(pts, Color(f.r, f.g, f.b, 0.34 * alfa))
	draw_polyline(izq, Color(f.r * 0.7, f.g * 0.7, f.b * 0.72, 0.45 * alfa),
		maxf(1.0, grosor * 0.22), true)


# EL BASTONAZO. Los dos golpes del arma: el basico y la tecnica, que es el mismo gesto con ganas.
# Barrido romo que cruza y una marquita al final, y ya. Se queda corto a proposito.
func _pintar_bastonazo(e: Dictionary) -> void:
	var fuerte: bool = int(e["estilo"]) == CombatFX.Estilo.BASTONAZO
	var r0: Array = _golpe_cuerpo(e, COLETA_BASTONAZO if fuerte else COLETA_BASTON, 0.08)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var sentido: float = 1.0 if sin(g * 5.7) > 0.0 else -1.0
	# Tirando a horizontal -- un palo se maneja a dos manos y se barre de lado -- pero NO plano. La
	# primera version iba a 9-19 grados y la cinta salia tan tumbada y tan fina que parecia una raya
	# de interfaz cruzando la tarjeta, no un golpe. Con algo de diagonal ya se lee el gesto.
	var ang: float = (0.34 + sin(g * 3.3) * 0.20) * sentido
	var k: float = 1.0 - pow(1.0 - clampf(v / 0.30, 0.0, 1.0), 2.4)
	var largo: float = caja * (1.55 if fuerte else 1.20)
	_barrido_romo(b, ang, largo, 0.05 * sentido, k, col, alfa, caja * (0.105 if fuerte else 0.078))
	if v <= 0.24:
		return
	var w: float = (v - 0.24) / 0.76
	# La marca del palo: un porrazo PEQUEÑO donde ha llegado. Nada de crateres -- esto no pesa.
	var dir := Vector2(cos(ang), sin(ang))
	_porrazo(b + dir * largo * 0.30, caja * (0.21 if fuerte else 0.15) * (1.0 - w * 0.3),
		col, alfa * (1.0 - w * 0.4), w, g, int(e.get("elem", 0)))
	# Y SOLO EL FUERTE deja al bicho frenandose: tres rayas cortas tirando hacia atras, que es el
	# Lento que aplica. El basico no lo aplica y por eso no las tiene.
	if not fuerte or w <= 0.2:
		return
	var f: Color = _filo_col(col)
	# Van pegadas al bicho y ALARGANDOSE hacia atras, con la de en medio la mas larga: es el rastro de
	# algo que se ha quedado frenado. Sueltas y del mismo largo parecian tres rectangulos flotando.
	for i in 3:
		var y: float = (float(i) - 1.0) * caja * 0.18
		var lg: float = caja * (0.34 + 0.30 * w) * (1.0 if i == 1 else 0.65)
		var x0: float = -dir.x * caja * 0.16
		draw_line(b + Vector2(x0, y), b + Vector2(x0 - dir.x * lg, y),
			Color(f.r, f.g, f.b, 0.6 * alfa * (1.0 - w * 0.7)), maxf(1.5, caja * 0.018), true)


# UN SIGNO ARCANO: un poligono regular con su circulo y unos radios. El ladrillo de lo arcano del
# baston, que es medio kit.
#
# 'lados' cambia el signo entero sin tocar nada mas: 5 para el Foco (una estrella cerrada, algo que
# se junta) y 6 para el Sello (un candado, algo que se cierra sobre otro). Que no sean el mismo
# poligono es lo unico que impide que las dos habilidades se lean igual.
func _signo(c: Vector2, r: float, lados: int, giro: float, col: Color, alfa: float,
		grosor: float) -> void:
	if r < 2.0 or alfa <= 0.01:
		return
	var pts := PackedVector2Array()
	for i in lados:
		var a: float = giro + TAU * float(i) / float(lados) - PI * 0.5
		# Achatado: la fila de tarjetas es ancha y baja, y un signo redondo se sale por arriba.
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * 0.78))
	var cerr := PackedVector2Array(pts)
	cerr.append(pts[0])
	draw_polyline(cerr, Color(col.r, col.g, col.b, alfa), grosor, true)
	_anillo(c, r * 1.18, r * 1.18 * 0.78, Color(col.r, col.g, col.b, 0.55 * alfa),
		maxf(1.0, grosor * 0.7))
	# Los radios, del centro a cada vertice: es lo que lo hace un SIGNO y no un poligono suelto.
	for i in lados:
		var a2: float = giro + TAU * float(i) / float(lados) - PI * 0.5
		draw_line(c, c + Vector2(cos(a2) * r * 0.92, sin(a2) * r * 0.78 * 0.92),
			Color(col.r, col.g, col.b, 0.40 * alfa), maxf(1.0, grosor * 0.6), true)


# FOCO ARCANO. Sobre TI: "canalizas tu aguante fisico en potencia magica". Los signos aparecen
# alrededor, se ENCOGEN hacia ti y se meten dentro. Nada sale: todo entra, que es justo lo contrario
# de lo que hace cualquier otra cosa de este archivo.
func _pintar_foco_arcano(e: Dictionary) -> void:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var b: Vector2 = e["b"]
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var sale: float = clampf(t / dur, 0.0, 1.0)
	var v: float = clampf((t - dur) / COLETA_FOCO, 0.0, 1.0) if t > dur else 0.0
	var alfa: float = 1.0 if v < 0.74 else 1.0 - (v - 0.74) / 0.26
	if alfa <= 0.0:
		return
	var f: Color = _filo_col(col)
	# TRES SIGNOS, escalonados, cada uno cerrandose sobre ti. El escalonado es lo que hace que se lea
	# como algo que se ACUMULA (son dos cargas de Foco) y no como un aura puesta de golpe.
	for i in 3:
		var k: float = clampf((sale * 0.5 + v * 1.35 - float(i) * 0.20) / 0.70, 0.0, 1.0)
		if k <= 0.0:
			continue
		var r: float = caja * (0.62 - 0.46 * k)          # se encoge: entra hacia ti
		var op: float = sin(PI * clampf(k, 0.0, 1.0))     # aparece y se apaga con el recorrido
		_signo(b, r, 5, g + float(i) * 0.7 + k * 1.2, f, 0.75 * alfa * op,
			maxf(1.5, caja * 0.020))
	# LAS MOTAS que caen hacia dentro con ellos. Van del borde al centro, al reves que las chispas de
	# todo lo demas.
	for i in 7:
		var kk: float = fposmod(sale * 0.6 + v * 1.5 + float(i) * 0.14, 1.0)
		var a: float = g + TAU * float(i) / 7.0
		var r2: float = caja * 0.70 * (1.0 - kk)
		draw_circle(b + Vector2(cos(a) * r2, sin(a) * r2 * 0.78),
			maxf(1.0, caja * 0.022 * kk), Color(f.r, f.g, f.b, 0.8 * alfa * sin(PI * kk)))
	# Y el nucleo encendiendose segun se llena.
	var carga: float = clampf(sale * 0.4 + v * 0.9, 0.0, 1.0)
	draw_circle(b, maxf(1.5, caja * 0.10 * carga), Color(f.r, f.g, f.b, 0.55 * alfa * carga))
	draw_circle(b, maxf(1.0, caja * 0.045 * carga), Color(1.0, 0.99, 0.96, 0.9 * alfa * carga))


# SELLO ARCANO. "Trazas un signo en el aire y lo cierras de golpe. Lo que iba a decir se queda
# dentro." Va sobre el ENEMIGO (hace daño, 0.5) y tiene dos tiempos que hay que ver los dos: el signo
# TRAZANDOSE despacio y el CIERRE, seco.
#
# Se distingue del Foco por el poligono (seis lados, no cinco), por donde se pinta (encima del bicho,
# no de ti) y sobre todo por la direccion: el Foco se encoge hacia dentro y este se cierra sobre
# OTRO. Y el cierre es de golpe -- un candado no se cierra despacio.
func _pintar_sello_arcano(e: Dictionary) -> void:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var b: Vector2 = e["b"]
	var f: Color = _filo_col(col)
	# PRIMER TIEMPO, durante el vuelo: el signo se traza. Se dibuja creciendo en radio y girando.
	if t < dur:
		var u: float = clampf(t / dur, 0.0, 1.0)
		_signo(b, caja * 0.52 * u, 6, g + u * 1.6, f, 0.75 * u, maxf(1.5, caja * 0.022))
		return
	var v: float = clampf((t - dur) / COLETA_SELLO, 0.0, 1.0)
	var alfa: float = 1.0 if v < 0.66 else 1.0 - (v - 0.66) / 0.34
	if alfa <= 0.0:
		return
	# SEGUNDO TIEMPO: se cierra. El radio cae de golpe (pow 4) y el signo se queda pequeño y apretado
	# sobre el bicho. Ese frenazo es todo el gesto.
	var cierra: float = 1.0 - pow(1.0 - clampf(v / 0.22, 0.0, 1.0), 4.0)
	var r: float = caja * (0.52 - 0.30 * cierra)
	_signo(b, r, 6, g + 1.6 + cierra * 0.5, f, 0.9 * alfa, maxf(2.0, caja * 0.026))
	# EL FOGONAZO del cierre, corto y seco.
	if cierra > 0.5:
		var br: float = maxf(0.0, 1.0 - (v - 0.11) / 0.30)
		if br > 0.0:
			_estrella(b, caja * 0.40 * br, caja * 0.30 * br, 0.62,
				Color(f.r, f.g, f.b, 0.7 * alfa * br))
	if v <= 0.26:
		return
	# LAS BARRAS DEL CANDADO: dos trazos cruzados dentro del signo, que se quedan puestos. Es lo que
	# dice que eso esta CERRADO y no solo dibujado -- y es lo que se lee como Silencio de un vistazo.
	var w: float = clampf((v - 0.26) / 0.30, 0.0, 1.0)
	for i in 2:
		var a: float = (-PI * 0.25 if i == 0 else PI * 0.25)
		var u2 := Vector2(cos(a), sin(a) * 0.78)
		draw_line(b - u2 * r * 0.92 * w, b + u2 * r * 0.92 * w,
			Color(f.r, f.g, f.b, 0.85 * alfa), maxf(2.0, caja * 0.026), true)


# VELO UMBRIO. Sobre TI: "te echas encima un poco de la oscuridad de al lado".
#
# CUIDADO CON EL DESVANECER de la daga (39), que aplica el MISMO estado (Sigilo) y por tanto es el
# que se puede confundir. Se separan por como llega la sombra:
#   DESVANECER  es un BORRON que te envuelve y se deshace -- te esfumas tu
#   VELO_UMBRIO es un MANTO que CAE desde arriba y se queda puesto -- te tapas con algo de fuera
# Por eso este se dibuja como una cortina bajando y con el borde de abajo ondeando, y aquel como una
# mancha de bordes inquietos.
func _pintar_velo_umbrio(e: Dictionary) -> void:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var g: float = float(e["semilla"])
	var b: Vector2 = e["b"]
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var cae: float = clampf(t / dur, 0.0, 1.0)
	var v: float = clampf((t - dur) / COLETA_VELO, 0.0, 1.0) if t > dur else 0.0
	var alfa: float = 1.0 if v < 0.76 else 1.0 - (v - 0.76) / 0.24
	if alfa <= 0.0:
		return
	# LA CORTINA. Nace por encima de la tarjeta y baja tapandola. El borde de abajo ondea, que es lo
	# unico que la separa de un rectangulo gris.
	var an: float = caja * 0.52
	var techo: float = -caja * 0.62
	# Baja hasta cubrir y despues respira un poco: un velo puesto no se queda tieso.
	var hasta: float = lerpf(techo, caja * 0.46, cae) + sin(t * 2.6 + g) * caja * 0.02 * (1.0 - cae * 0.5)
	# TODAVIA NO HA BAJADO NADA. Con la tela a altura cero todos los vertices caen en la misma linea y
	# el poligono no se puede triangular ("Invalid polygon data"): no se pinta y ademas escupe dos
	# errores por frame. Es el mismo caso que ya tenia _estrella al apagarse.
	if hasta - techo < 3.0:
		return
	# LOS LADOS TAMBIEN SE MUEVEN. La primera version tenia los cantos rectos y el techo de borde a
	# borde: salia un RECTANGULO NEGRO plantado sobre la tarjeta, o sea una caja, no una tela. Una
	# tela colgada no tiene ni un lado recto.
	var n: int = 13
	var pts := PackedVector2Array()
	pts.append(b + Vector2(-an * 0.82, techo))
	pts.append(b + Vector2(an * 0.82, techo))
	# Los lados van por DENTRO del recorrido, sin tocar ni el techo ni el suelo (s de 0.25 a 0.75).
	# Llegando a los extremos, el ultimo punto del lado izquierdo caia justo encima del primero del
	# poligono y el contorno RETROCEDIA sobre si mismo: Godot no puede triangular eso ("Invalid
	# polygon data") y el velo no se pintaba, escupiendo dos errores por frame.
	for i in 3:
		var s2: float = 0.25 + 0.25 * float(i)
		pts.append(b + Vector2(an * (0.82 + 0.22 * sin(PI * s2) + 0.06 * sin(t * 2.3 + g)),
			lerpf(techo, hasta, s2)))
	for i in n:
		var u: float = 1.0 - float(i) / float(n - 1)
		var x: float = lerpf(-an, an, u)
		# El ondeo va con el tiempo real y desfasado por la x: una tela que se mueve, no una linea.
		var onda: float = sin(t * 3.1 + u * 6.4 + g) * caja * 0.055 * (0.4 + 0.6 * cae)
		pts.append(b + Vector2(x, hasta + onda))
	# Y el izquierdo, subiendo (igual: sin llegar al techo).
	for i in 3:
		var s3: float = 0.75 - 0.25 * float(i)
		pts.append(b + Vector2(-an * (0.82 + 0.22 * sin(PI * s3) + 0.06 * sin(t * 2.7 + g)),
			lerpf(techo, hasta, s3)))
	# MENOS OPACO (0.52): un velo tapa pero tiene que dejar ver QUIEN lo lleva. A 0.62 el personaje
	# desaparecia debajo y esto pasaba a ser un agujero en la pantalla.
	draw_colored_polygon(pts, Color(0.05, 0.04, 0.08, 0.52 * alfa))
	# El borde de abajo, un poco mas claro: es donde se ve que es una tela y no un agujero.
	var borde := PackedVector2Array()
	for i in n:
		var u2: float = float(i) / float(n - 1)
		borde.append(b + Vector2(lerpf(-an, an, u2),
			hasta + sin(t * 3.1 + u2 * 6.4 + g) * caja * 0.055 * (0.4 + 0.6 * cae)))
	draw_polyline(borde, Color(0.34, 0.30, 0.44, 0.55 * alfa), maxf(1.5, caja * 0.022), true)
	# LOS PLIEGUES: tres lineas verticales que bajan por la tela. Es lo que dice que hay un paño ahi
	# y no una mancha -- y a la vez deja ver que lo de detras sigue existiendo.
	for i in 3:
		var x3: float = (float(i) - 1.0) * an * 0.52 + sin(g + float(i) * 2.1) * caja * 0.03
		var pl := PackedVector2Array()
		for j in 5:
			var s4: float = float(j) / 4.0
			pl.append(b + Vector2(x3 + sin(t * 2.4 + g + float(i) + s4 * 3.0) * caja * 0.022 * s4,
				lerpf(techo, hasta, s4)))
		draw_polyline(pl, Color(0.20, 0.17, 0.26, 0.45 * alfa), maxf(1.0, caja * 0.014), true)
	# Y unos jirones desprendiendose por debajo, que es lo que dice que la sombra sigue viva.
	for i in 4:
		var kk: float = fposmod(v * 1.2 + float(i) * 0.27 + g * 0.1, 1.0)
		var x2: float = sin(g + float(i) * 2.3) * an * 0.75
		draw_circle(b + Vector2(x2, hasta + caja * 0.20 * kk),
			maxf(1.0, caja * 0.030 * (1.0 - kk)),
			Color(0.10, 0.08, 0.14, 0.5 * alfa * sin(PI * kk)))


# VIENTO LIMPIO. Sobre CADA UNO DE LOS TUYOS (llega por _fx_adorno con la lista de aliados): "una
# corriente de aire limpio los recorre y se lleva algo de encima de cada uno".
#
# Lo que hay que leer es que ALGO SE VA, no que llegue nada. Por eso las rachas cruzan de lado a lado
# y arrastran motas oscuras HACIA FUERA de la tarjeta: si las motas entraran o se quedaran, parecia
# que le estabas echando algo encima en vez de quitandoselo.
func _pintar_viento_limpio(e: Dictionary) -> void:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var b: Vector2 = e["b"]
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var sale: float = clampf(t / dur, 0.0, 1.0)
	var v: float = clampf((t - dur) / COLETA_VIENTO, 0.0, 1.0) if t > dur else 0.0
	var alfa: float = 1.0 if v < 0.64 else 1.0 - (v - 0.64) / 0.36
	if alfa <= 0.0:
		return
	var f: Color = _filo_col(col)
	# LAS RACHAS: cinco lineas horizontales que cruzan la tarjeta a distintas alturas y en distinto
	# momento. Cada una es un trazo CORTO que se desplaza, no una raya de lado a lado: lo que se ve
	# pasar es el aire, y el aire no es una regla.
	for i in 5:
		var k: float = clampf(sale * 0.45 + v * 1.5 - float(i) * 0.11, 0.0, 1.0)
		if k <= 0.0 or k >= 1.0:
			continue
		var y: float = (float(i) - 2.0) * caja * 0.22 + sin(g + float(i) * 1.7) * caja * 0.04
		# LARGAS Y MARCADAS. Cortas y tenues no se leia que pasara nada: parecian motas de polvo.
		var largo: float = caja * (0.52 + 0.22 * sin(g * 2.1 + float(i)))
		var x: float = lerpf(-caja * 0.85, caja * 0.85, k)
		var op: float = sin(PI * k)
		draw_line(b + Vector2(x - largo, y + caja * 0.03), b + Vector2(x, y),
			Color(f.r, f.g, f.b, 0.95 * alfa * op), maxf(2.0, caja * 0.028), true)
	# LO QUE SE LLEVA: motas OSCURAS despegandose y saliendo por el lado, siempre hacia fuera. Son la
	# porqueria que tenia encima, asi que van en sucio y no del color del viento.
	for i in 6:
		var kk: float = fposmod(sale * 0.5 + v * 1.35 + float(i) * 0.17, 1.0)
		var y2: float = (float(i) - 2.5) * caja * 0.18 + sin(g * 1.3 + float(i)) * caja * 0.05
		var x2: float = lerpf(-caja * 0.15, caja * 0.95, kk)
		draw_circle(b + Vector2(x2, y2 - caja * 0.10 * kk),
			maxf(1.5, caja * 0.038 * (1.0 - kk * 0.6)),
			Color(0.26, 0.21, 0.17, 0.9 * alfa * sin(PI * kk)))


# ============================================================
#  LOS PUÑOS Y EL RESTO DEL ESCUDO
# ============================================================
# LOS PUÑOS no tienen ni una habilidad: son el arma de cuando no llevas arma, asi que solo hay que
# darles el basico. Y lo unico que tiene que decir ese basico es "vas a mano limpia", que se dice
# haciendolo PEQUEÑO: al lado de cualquiera de los otros nueve gestos tiene que quedarse corto.
#
# DEL ESCUDO ya estaba el ESCUDAZO (60) -- que es el Golpe de escudo tal cual, y por eso esa
# habilidad no pide dibujo propio: se queda con el respaldo. Faltaban sus otras cuatro, y tres de
# ellas ni siquiera pegan: esta arma es la del que aguanta, no la del que reparte.
const COLETA_PUNOS := 0.20             # lo mas corto del juego: es un puñetazo
const COLETA_EMBESTIDA := 0.44
const COLETA_PROVOCACION := 0.60
const COLETA_GUARDIA_CARNE := 0.85     # es una postura: se queda puesta
const COLETA_COBERTURA := 0.70


# EL PUÑETAZO. Un porrazo pequeño y dos lineas de nudillo, y ya. Reusa el _porrazo de la maza porque
# es lo mismo -- algo romo que entra -- solo que a la escala de una mano.
#
# Lo que lo separa del mazazo es el TAMAÑO y las dos rayitas: sin ellas, un puñetazo pequeño y un
# mazazo pequeño son el mismo dibujo, y con ellas se lee que ha entrado un puño.
func _pintar_punos(e: Dictionary) -> void:
	var r0: Array = _golpe_cuerpo(e, COLETA_PUNOS, 0.14)
	var v: float = r0[0]
	if v < 0.0 or float(r0[1]) <= 0.0:
		return
	var alfa: float = r0[1]
	var b: Vector2 = r0[2]
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	# Entra de golpe: un puñetazo es lo mas rapido que hay aqui.
	var k: float = 1.0 - pow(1.0 - clampf(v / 0.16, 0.0, 1.0), 3.0)
	_porrazo(b, caja * 0.155 * (0.35 + 0.65 * k), col, alfa, v, g, int(e.get("elem", 0)))
	if v <= 0.18:
		return
	# LOS NUDILLOS: dos rayas cortas y paralelas junto al impacto, en la direccion del brazo. Es la
	# unica pista de que esto lo ha dado una MANO.
	var w: float = (v - 0.18) / 0.82
	var f: Color = _filo_col(col)
	var ang: float = -PI * 0.25 + sin(g * 3.3) * 0.5
	var dir := Vector2(cos(ang), sin(ang))
	var lado := Vector2(-dir.y, dir.x)
	for i in 2:
		var o: Vector2 = lado * (float(i) * 2.0 - 1.0) * caja * 0.055
		draw_line(b + o - dir * caja * 0.20, b + o - dir * caja * (0.06 + 0.10 * w),
			Color(f.r, f.g, f.b, 0.6 * alfa * (1.0 - w)), maxf(1.5, caja * 0.024), true)


# EMBESTIDA. "Bajas el hombro detras del escudo y le entras encima." NO ES UN ESCUDAZO -- ese es el
# empujon seco de la plancha, que ya tiene su gesto (ESCUDAZO, 60) y lo comparten media docena de
# habilidades. Esto es una CARGA: lo que hace daño no es el escudo, es todo tu peso llegando.
#
# Y por eso existe AbilityData.es_toda_de_escudo: un golpe de escudo se dibuja como escudazo por
# defecto, y esta habilidad necesitaba poder decir que no.
#
# Se cuenta con el RECORRIDO: lineas de velocidad que vienen de lejos, el escudo llegando de canto y
# el impacto con el polvo saliendo hacia atras.
func _pintar_embestida_escudo(e: Dictionary) -> void:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var b: Vector2 = e["b"] + Vector2(cos(g * 2.1), sin(g * 1.7)) * caja * 0.06
	var f: Color = _filo_col(col)
	var lado: float = 1.0 if sin(g * 5.7) > 0.0 else -1.0
	# DURANTE EL VUELO: se ve VENIR. Es lo unico que la separa de un empujon, asi que el adelanto se
	# usa entero para eso en vez de para armar el golpe.
	if t < dur:
		var u: float = clampf(t / dur, 0.0, 1.0)
		var desde: Vector2 = b - Vector2(lado * caja * 1.30 * (1.0 - u), 0.0)
		# El alfa aqui es 1: durante el vuelo todavia no hay coleta de la que sacarlo.
		_escudo_cara(desde, caja * 0.30, col, 0.35 + 0.65 * u, -lado * 0.35,
			int(e.get("escudo", -1)))
		# Las lineas de velocidad, detras y a distintas alturas.
		for i in 4:
			var y: float = (float(i) - 1.5) * caja * 0.16
			var lg: float = caja * (0.25 + 0.45 * u) * (0.6 + 0.5 * absf(sin(g + float(i))))
			draw_line(desde + Vector2(-lado * caja * 0.30, y),
				desde + Vector2(-lado * (caja * 0.30 + lg), y),
				Color(f.r, f.g, f.b, 0.35 * (0.3 + 0.7 * u)), maxf(1.5, caja * 0.020), true)
		return
	var v: float = clampf((t - dur) / COLETA_EMBESTIDA, 0.0, 1.0)
	var alfa: float = 1.0 if v < 0.55 else 1.0 - (v - 0.55) / 0.45
	if alfa <= 0.0:
		return
	# EL CHOQUE. El escudo llega, se para y rebota un poco.
	var retro: float = 0.0 if v < 0.28 else minf((v - 0.28) / 0.40, 1.0) * 0.22
	_escudo_cara(b - Vector2(lado * caja * retro, 0.0), caja * 0.34, col, alfa, -lado * 0.20,
		int(e.get("escudo", -1)))
	# Y EL PESO que llega detras: un porrazo ancho y el polvo escapando hacia atras, que es por donde
	# venia. Sin el polvo esto se queda en un escudo apoyado en el bicho.
	_porrazo(b + Vector2(lado * caja * 0.20, 0.0), caja * 0.30 * (1.0 - v * 0.25), col, alfa, v, g,
		int(e.get("elem", 0)))
	for i in 7:
		var a: float = PI * (0.5 if lado > 0.0 else -0.5) + (float(i) - 3.0) * 0.22
		var u2 := Vector2(cos(a) * -lado, sin(a) * 0.5)
		var d: float = caja * (0.20 + 0.85 * v) * (0.5 + 0.6 * absf(sin(g * 1.9 + float(i))))
		draw_circle(b + u2 * d, maxf(1.0, caja * 0.030 * (1.0 - v)),
			Color(0.70, 0.66, 0.60, 0.40 * alfa * (1.0 - v)))


# PROVOCACION. "Golpeas el escudo y ruges, y te cubres tras el." Sobre TI, y con los tres tiempos
# puestos: el golpe en la plancha, la onda del grito saliendo, y el escudo quedandose delante.
#
# La onda usa el mismo lenguaje que el Grito de guerra y el Chillido de los bichos -- anillos que
# salen del que grita -- porque es lo mismo: algo que se oye. Lo que cambia es que aqui NO barre la
# fila de enfrente, se queda alrededor tuyo: no ataca a nadie, solo llama la atencion.
func _pintar_provocacion(e: Dictionary) -> void:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var b: Vector2 = e["b"]
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var sale: float = clampf(t / dur, 0.0, 1.0)
	var v: float = clampf((t - dur) / COLETA_PROVOCACION, 0.0, 1.0) if t > dur else 0.0
	var alfa: float = 1.0 if v < 0.68 else 1.0 - (v - 0.68) / 0.32
	if alfa <= 0.0:
		return
	var f: Color = _filo_col(col)
	# EL ESCUDO, delante de ti y temblando por el golpe que le acabas de dar. El temblor se apaga.
	var tiembla: float = maxf(0.0, 1.0 - v / 0.30) * sale
	var d := Vector2(sin(t * 34.0 + g), cos(t * 27.0 + g) * 0.5) * caja * 0.030 * tiembla
	_escudo_cara(b + d, caja * 0.34, col, alfa, sin(g) * 0.10, int(e.get("escudo", -1)))
	# LOS ANILLOS del grito, saliendo de ti y quedandose CERCA: cuatro, escalonados y muy achatados.
	for i in 4:
		var k: float = clampf(sale * 0.5 + v * 1.4 - float(i) * 0.15, 0.0, 1.0)
		if k <= 0.0 or k >= 1.0:
			continue
		var rr: float = caja * (0.34 + 0.80 * k)
		_anillo(b, rr, rr * 0.62, Color(f.r, f.g, f.b, 0.6 * alfa * (1.0 - k)),
			maxf(2.0, caja * 0.034 * (1.0 - k * 0.5)))
	# Y LAS MIRADAS QUE ATRAE: tres flechas cortas apuntandote desde fuera. Es lo unico que dice para
	# que sirve esto -- sin ellas es un grito mas, y lo que hace es que le peguen A EL.
	if v <= 0.20:
		return
	var w: float = clampf((v - 0.20) / 0.45, 0.0, 1.0)
	for i in 3:
		var a: float = -PI * 0.5 + (float(i) - 1.0) * 0.85 + sin(g + float(i)) * 0.12
		var u := Vector2(cos(a), sin(a) * 0.7)
		var d0: float = caja * (1.15 - 0.45 * w)
		var punta: Vector2 = b + u * d0
		draw_line(punta + u * caja * 0.26, punta, Color(f.r, f.g, f.b, 0.7 * alfa * w),
			maxf(1.5, caja * 0.022), true)
		var perp := Vector2(-u.y, u.x)
		draw_colored_polygon(PackedVector2Array([punta, punta + u * caja * 0.11 + perp * caja * 0.055,
			punta + u * caja * 0.11 - perp * caja * 0.055]),
			Color(f.r, f.g, f.b, 0.85 * alfa * w))


# GUARDIA DE CARNE. "Te abres la guardia a proposito y te plantas." Sobre TI, y es la unica del juego
# que dibuja algo MALO para quien la usa: aguantas el doble y te duele el doble.
#
# Por eso el escudo se APARTA -- baja y se va a un lado -- y en su sitio quedan los pies clavados y
# el pecho al descubierto. Es el espejo del Voto de guardia de la espada larga, que cierra la guardia
# donde esta la abre; si las dos dibujaran una postura firme se leerian igual.
func _pintar_guardia_carne(e: Dictionary) -> void:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var b: Vector2 = e["b"]
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var abre: float = clampf(t / dur, 0.0, 1.0)
	var v: float = clampf((t - dur) / COLETA_GUARDIA_CARNE, 0.0, 1.0) if t > dur else 0.0
	var alfa: float = 1.0 if v < 0.80 else 1.0 - (v - 0.80) / 0.20
	if alfa <= 0.0:
		return
	var f: Color = _filo_col(col)
	# EL ESCUDO SE APARTA: baja y se va al lado, girando. Que se vea IRSE es medio gesto.
	var fuera: Vector2 = Vector2(caja * 0.62 * abre, caja * 0.34 * abre)
	_escudo_cara(b + fuera, caja * 0.28, col, alfa * (1.0 - abre * 0.45), 0.55 * abre,
		int(e.get("escudo", -1)))
	# LOS PIES CLAVADOS: dos cuñas en el suelo, con unas rayas de agarre. "Te plantas".
	var suelo: Vector2 = b + Vector2(0.0, caja * 0.44)
	for i in 2:
		var s: float = float(i) * 2.0 - 1.0
		var x: float = s * caja * 0.18
		var pie := PackedVector2Array([
			suelo + Vector2(x - caja * 0.10, 0.0), suelo + Vector2(x + caja * 0.10, 0.0),
			suelo + Vector2(x + caja * 0.055, -caja * 0.13),
			suelo + Vector2(x - caja * 0.055, -caja * 0.13)])
		draw_colored_polygon(pie, Color(f.r, f.g, f.b, 0.35 * alfa * abre))
		var cerr := PackedVector2Array(pie)
		cerr.append(pie[0])
		draw_polyline(cerr, Color(f.r, f.g, f.b, 0.7 * alfa * abre), maxf(1.5, caja * 0.018), true)
		# Las rayas de agarre, saliendo del pie hacia fuera.
		for j in 2:
			var y2: float = -caja * 0.02 - float(j) * caja * 0.05
			draw_line(suelo + Vector2(x + s * caja * 0.11, y2),
				suelo + Vector2(x + s * caja * (0.11 + 0.13 * abre), y2),
				Color(f.r, f.g, f.b, 0.45 * alfa * abre), maxf(1.0, caja * 0.014), true)
	# EL PECHO AL DESCUBIERTO: un arco ABIERTO por arriba, latiendo. Es lo contrario de la cupula
	# cerrada de una postura defensiva -- ahi esta el aviso de que te va a doler el doble.
	var pulso: float = 0.65 + 0.35 * sin(t * 4.5 + g)
	for i in 2:
		var s2: float = float(i) * 2.0 - 1.0
		var rr: float = caja * (0.40 + 0.06 * float(i))
		var arco := PackedVector2Array()
		for j in 7:
			# Media cupula por lado, y con un HUECO en el medio: la guardia no cierra.
			var a: float = -PI * 0.5 + s2 * (0.30 + PI * 0.42 * float(j) / 6.0)
			arco.append(b + Vector2(cos(a) * rr, sin(a) * rr * 0.92))
		draw_polyline(arco, Color(f.r, f.g, f.b, 0.5 * alfa * abre * pulso),
			maxf(1.5, caja * 0.024), true)


# COBERTURA. "Adelantas el escudo lo justo para que quepan otros detras." Sobre CADA UNO DE LOS TUYOS.
#
# CUIDADO CON EL MURO DE ALIADOS de la maza (73): aplica EL MISMO estado (Baluarte) al MISMO grupo, o
# sea que mecanicamente son gemelas y si se dibujaran parecido pareceria un fallo. Se separan por
# QUIEN pone el hierro:
#   MURO_ALIADOS  son VARIAS placas cerrando la formacion -- cada uno arrima la suya
#   COBERTURA     es UN escudo, el tuyo, adelantado, y los demas metiendose detras
# Por eso aqui hay una sola plancha y lo que se mueve son las siluetas que se refugian.
func _pintar_cobertura(e: Dictionary) -> void:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var b: Vector2 = e["b"]
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var adelanta: float = clampf(t / dur, 0.0, 1.0)
	var v: float = clampf((t - dur) / COLETA_COBERTURA, 0.0, 1.0) if t > dur else 0.0
	var alfa: float = 1.0 if v < 0.72 else 1.0 - (v - 0.72) / 0.28
	if alfa <= 0.0:
		return
	var f: Color = _filo_col(col)
	# LAS SILUETAS PRIMERO, que van DETRAS: dos figuras que se arriman al centro y se quedan. Se
	# dibujan antes para que el escudo las tape, que es justo lo que cuenta la habilidad.
	var mete: float = clampf(adelanta * 0.5 + v * 1.6, 0.0, 1.0)
	for i in 2:
		var s: float = float(i) * 2.0 - 1.0
		# SE ARRIMAN, PERO ASOMAN. Con el destino en 0.26 acababan enteras detras de la plancha (que
		# mide 0.46) y desaparecian: quedaba un escudo suelto y no se entendia que hubiera nadie
		# refugiado. Media silueta fuera es lo que cuenta la habilidad -- caben, pero justo.
		var x: float = s * caja * lerpf(0.78, 0.44, mete)
		var alto: float = caja * 0.30
		var fig := PackedVector2Array()
		for j in 9:
			var a: float = PI + PI * float(j) / 8.0
			fig.append(b + Vector2(x + cos(a) * caja * 0.13, caja * 0.10 + sin(a) * alto * 0.55))
		fig.append(b + Vector2(x + caja * 0.13, caja * 0.34))
		fig.append(b + Vector2(x - caja * 0.13, caja * 0.34))
		draw_colored_polygon(fig, Color(0.16, 0.17, 0.21, 0.85 * alfa))
		var cerr := PackedVector2Array(fig)
		cerr.append(fig[0])
		draw_polyline(cerr, Color(f.r, f.g, f.b, 0.35 * alfa), maxf(1.0, caja * 0.014), true)
	# EL ESCUDO, uno solo y GRANDE, adelantandose hacia el frente (hacia abajo, que es de donde viene
	# lo que hay que parar).
	var p: Vector2 = b + Vector2(0.0, caja * (0.02 + 0.20 * adelanta))
	_escudo_cara(p, caja * 0.46, col, alfa, sin(g) * 0.06, int(e.get("escudo", -1)))
	# Y EL HUECO que deja: dos rayas abriendose a los lados por debajo del escudo. "No paras sus
	# golpes, pero les das donde meterse."
	if v <= 0.18:
		return
	var w: float = clampf((v - 0.18) / 0.40, 0.0, 1.0)
	for i in 2:
		var s2: float = float(i) * 2.0 - 1.0
		var y: float = p.y + caja * 0.30
		draw_line(b + Vector2(s2 * caja * 0.22, y), b + Vector2(s2 * caja * (0.22 + 0.34 * w), y),
			Color(f.r, f.g, f.b, 0.5 * alfa * (1.0 - w * 0.4)), maxf(1.5, caja * 0.020), true)


# ============================================================
#  LA VARITA: soporte puro
# ============================================================
# LA UNICA COSA DEL JUEGO DE LA QUE NO SALE NI UN GOLPE. Sus cuatro tecnicas tienen dano_mult 0 y
# ninguna apunta a un enemigo: se las echas a los tuyos y ya. Eso es lo que hay que dibujar -- nada
# de impactos, nada de cintas, nada que entre en nadie.
#
# Su Foco arcano REUSA el del baston (FOCO_ARCANO, 90): es la misma habilidad con menos cargas, y
# tener dos gemelos con distinto numero solo sirve para que un dia se descuadren.
const COLETA_PURIFICAR := 0.85     # "cuesta caro y TARDA": tiene que verse durar
const COLETA_CHISPA := 0.70
const COLETA_EGIDA := 0.70


# PURIFICAR. "Le pones la varita encima y esperas a que se le pase todo." Sobre UN aliado, y limpia
# los debuffs ENTEROS (99), no uno como el Viento limpio del baston.
#
# Se separan por eso mismo: el Viento PASA (rachas cruzando, se lleva algo de cada uno) y esto se
# QUEDA (una columna quieta sobre uno solo hasta que sale limpio). Que uno cruce y el otro se pare es
# lo que dice, sin leer nada, cual es el barato y cual el caro.
func _pintar_purificar(e: Dictionary) -> void:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var b: Vector2 = e["b"]
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var baja: float = clampf(t / dur, 0.0, 1.0)
	var v: float = clampf((t - dur) / COLETA_PURIFICAR, 0.0, 1.0) if t > dur else 0.0
	var alfa: float = 1.0 if v < 0.80 else 1.0 - (v - 0.80) / 0.20
	if alfa <= 0.0:
		return
	var f: Color = _filo_col(col)
	# LA COLUMNA: baja desde arriba y se queda puesta, respirando. No se abre ni se cierra -- es una
	# luz sostenida, que es lo que hace un lanzador que espera a que se le pase.
	var an: float = caja * 0.30 * (0.35 + 0.65 * baja)
	var arriba: float = -caja * 0.72
	var abajo: float = caja * 0.46
	var resp: float = 0.88 + 0.12 * sin(t * 3.4 + g)
	for capa in 3:
		var m: float = (1.0 - float(capa) * 0.30) * resp
		var pts := PackedVector2Array([
			b + Vector2(-an * m * 0.72, arriba), b + Vector2(an * m * 0.72, arriba),
			b + Vector2(an * m, abajo), b + Vector2(-an * m, abajo)])
		draw_colored_polygon(pts, Color(f.r, f.g, f.b, (0.10 + 0.07 * float(2 - capa)) * alfa))
	# LO QUE SE LE SACA: motas oscuras que SUBEN por la columna y se apagan arriba. Suben y no caen:
	# lo que se va, se va. (En el Viento limpio salen de lado; aqui salen por arriba, que es la otra
	# forma de decir lo mismo sin repetir el dibujo.)
	for i in 7:
		var kk: float = fposmod(baja * 0.4 + v * 1.25 + float(i) * 0.15, 1.0)
		var x: float = sin(g + float(i) * 2.3) * an * 0.62
		var y: float = lerpf(abajo, arriba, kk)
		# Se van aclarando segun suben: salen sucias y se deshacen en luz.
		var c: Color = Color(0.30, 0.26, 0.22).lerp(Color(f.r, f.g, f.b), kk)
		draw_circle(b + Vector2(x, y), maxf(1.0, caja * 0.030 * (1.0 - kk * 0.6)),
			Color(c.r, c.g, c.b, 0.85 * alfa * sin(PI * kk)))
	# Y EL ANILLO a los pies, que es lo que ancla la columna al que la recibe.
	_anillo(b + Vector2(0.0, abajo), an * 1.25 * resp, an * 0.32 * resp,
		Color(f.r, f.g, f.b, 0.55 * alfa * baja), maxf(1.5, caja * 0.024))


# CHISPA VINCULADA. "Un hilo fino de tu varita a la suya. Va goteando por el lo que a ti te sobra."
#
# EL UNICO GESTO DEL JUEGO QUE VIAJA DE TI A UN COMPAÑERO, y por eso es el unico del jugador que NO
# esta en la lista de los que nacen sobre la tarjeta de destino: necesita los dos puntos, el tuyo y
# el suyo, porque lo que se dibuja es justamente el trecho entre los dos.
#
# Lo que se ve es el HILO y lo que baja por el. Ni impacto ni destino: si al llegar reventara algo,
# se leeria como que le has lanzado un hechizo encima.
func _pintar_chispa_vinculada(e: Dictionary) -> void:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var a: Vector2 = e["a"]
	var b: Vector2 = e["b"]
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var tiende: float = clampf(t / dur, 0.0, 1.0)
	var v: float = clampf((t - dur) / COLETA_CHISPA, 0.0, 1.0) if t > dur else 0.0
	var alfa: float = 1.0 if v < 0.74 else 1.0 - (v - 0.74) / 0.26
	if alfa <= 0.0:
		return
	var f: Color = _filo_col(col)
	# EL HILO. Se tiende de ti a el durante el vuelo y despues se queda. Va COMBADO -- cuelga un poco
	# por su propio peso -- porque una recta entre dos tarjetas se lee como un rayo o como una linea
	# de interfaz, y esto es un hilo.
	var n: int = 15
	var hilo := PackedVector2Array()
	var caida: float = a.distance_to(b) * 0.14
	for i in n:
		var s: float = float(i) / float(n - 1) * tiende
		var p: Vector2 = a.lerp(b, s)
		p.y += sin(PI * s) * caida + sin(t * 2.4 + s * 5.0 + g) * caja * 0.02
		hilo.append(p)
	if hilo.size() >= 2:
		draw_polyline(hilo, Color(f.r, f.g, f.b, 0.30 * alfa), maxf(2.0, caja * 0.030), true)
		draw_polyline(hilo, Color(f.r, f.g, f.b, 0.85 * alfa), maxf(1.0, caja * 0.012), true)
	# LAS GOTAS que bajan por el. Se calculan sobre la MISMA curva que el hilo (no en linea recta) o
	# irian por su cuenta, al lado de la cuerda.
	if tiende < 1.0:
		return
	for i in 4:
		var kk: float = fposmod(v * 1.15 + float(i) * 0.25 + g * 0.1, 1.0)
		var p2: Vector2 = a.lerp(b, kk)
		p2.y += sin(PI * kk) * caida + sin(t * 2.4 + kk * 5.0 + g) * caja * 0.02
		draw_circle(p2, maxf(1.5, caja * 0.030 * (0.6 + 0.4 * sin(PI * kk))),
			Color(f.r, f.g, f.b, 0.9 * alfa))
	# Y los dos extremos encendidos: tu punta y la suya. Es lo que dice que el hilo esta ATADO a algo
	# por los dos lados y no colgando en el aire.
	for p3 in [a, b]:
		draw_circle(p3, maxf(1.5, caja * 0.045 * (0.85 + 0.15 * sin(t * 5.0 + g))),
			Color(f.r, f.g, f.b, 0.55 * alfa))
		draw_circle(p3, maxf(1.0, caja * 0.020), Color(1.0, 0.99, 0.96, 0.9 * alfa))


# EGIDA MENOR. "Un escudo pequeño de luz, pegado a quien lo necesita."
#
# ES EL TERCER BALUARTE DEL JUEGO -- el mismo estado que el Muro de aliados (maza) y la Cobertura
# (escudo) --, asi que hay que separarlo de los dos a la vez. Las tres se distinguen por DE QUE ESTAN
# HECHAS y a cuantos van:
#   MURO_ALIADOS  varias placas de hierro cerrando la formacion, a todo el grupo
#   COBERTURA     una plancha, la tuya, adelantada, a todo el grupo
#   EGIDA_MENOR   un hexagono de LUZ, pequeño, pegado a UNO solo
# Nada de hierro aqui: esto lo pone un mago con una varita, y "no es gran cosa" -- lo dice su propia
# ficha, asi que tiene que verse modesto al lado de los otros dos.
func _pintar_egida_menor(e: Dictionary) -> void:
	var t: float = float(e["t"])
	var dur: float = float(e["dur"])
	var col: Color = e["col"]
	var g: float = float(e["semilla"])
	var b: Vector2 = e["b"]
	var caja: float = clampf(float(e["ancho"]) * 0.72, 38.0, 118.0)
	var monta: float = clampf(t / dur, 0.0, 1.0)
	var v: float = clampf((t - dur) / COLETA_EGIDA, 0.0, 1.0) if t > dur else 0.0
	var alfa: float = 1.0 if v < 0.74 else 1.0 - (v - 0.74) / 0.26
	if alfa <= 0.0:
		return
	var f: Color = _filo_col(col)
	# LA PLACA DE LUZ: un hexagono achatado que se monta y se queda flotando delante, latiendo suave.
	# Pequeño a proposito (0.34 de caja, contra el 0.46 de la Cobertura).
	var r: float = caja * 0.34 * (0.45 + 0.55 * monta)
	var pulso: float = 0.85 + 0.15 * sin(t * 3.2 + g)
	var pts := PackedVector2Array()
	for i in 6:
		var ang: float = g * 0.3 + TAU * float(i) / 6.0 - PI * 0.5
		pts.append(b + Vector2(cos(ang) * r * pulso, sin(ang) * r * 0.86 * pulso))
	draw_colored_polygon(pts, Color(f.r, f.g, f.b, 0.16 * alfa * pulso))
	var cerr := PackedVector2Array(pts)
	cerr.append(pts[0])
	draw_polyline(cerr, Color(f.r, f.g, f.b, 0.85 * alfa), maxf(2.0, caja * 0.024), true)
	# LAS COSTURAS: los radios del hexagono, flojos. Es lo que lo hace una placa de luz y no un
	# poligono suelto -- y lo que lo emparenta con el Sello y el Foco del baston, que es de donde
	# viene esta arma.
	for i in 6:
		var a2: float = g * 0.3 + TAU * float(i) / 6.0 - PI * 0.5
		draw_line(b, b + Vector2(cos(a2) * r * 0.9 * pulso, sin(a2) * r * 0.86 * 0.9 * pulso),
			Color(f.r, f.g, f.b, 0.25 * alfa), maxf(1.0, caja * 0.012), true)
	# Y EL DESTELLO de cuando termina de montarse, una vez.
	if v <= 0.0 or v > 0.35:
		return
	var brillo: float = sin(PI * clampf(v / 0.35, 0.0, 1.0))
	_estrella(b, r * 1.5 * brillo, r * 1.1 * brillo, 0.55,
		Color(f.r, f.g, f.b, 0.5 * alfa * brillo))
