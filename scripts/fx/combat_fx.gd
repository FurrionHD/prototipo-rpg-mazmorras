# ============================================================
#  combat_fx.gd  (class_name CombatFX)
#  TODO lo que se MUEVE y BRILLA en la pantalla de combate. Vive aparte de combat.gd por dos
#  razones: ese archivo ya pasa de 5800 lineas, y porque esto es una capa PASIVA -- no decide
#  nada de la pelea, solo pinta lo que le cuentan.
#
#  Hace cuatro cosas, y las cuatro cuelgan de las TARJETAS que crea _crear_bloque:
#
#   1. ESTADOS       particulas y tinte del recuadro segun lo que sufre cada uno (arde si esta
#                    quemado, centellea si esta pegajoso, borde dorado si esta potenciado).
#   2. BARRAS        la vida no salta: se desliza hasta su destino.
#   3. IMPACTOS      la tarjeta del atacante EMBISTE a la del objetivo, pum, y la otra tiembla.
#   4. NUMEROS       el daño flotando encima de quien lo ha comido.
#
#  DOS DECISIONES DE FONDO, las dos con motivo:
#
#  * NADA de Tween ni de await, todo se evalua en _process restando delta. Es el mismo motor que
#    ya lleva el combate (_pause_left) y, sobre todo, hace IMPOSIBLE el bug feo: con un await vivo,
#    la tecla P (_desatascar) puede forzar el estado del turno por debajo de la corrutina y dejarte
#    un turno duplicado o perdido. Una cola pasiva que solo pinta no puede romper el orden de turnos
#    ni queriendo.
#
#  * Los estados se leen del ARRAY DE CHIPS YA RESUELTO, nunca de c.has_status(). En multijugador
#    el que ESPEJA la pelea tiene maniquis con statuses vacio: lo unico que le llega son los chips
#    que resolvio el anfitrion (ver _chips_de en combat.gd). Leyendo de ahi, esto funciona igual en
#    las dos pantallas y sin mandar un solo byte de mas.
#
#  Todo nodo que cuelgue de aqui va en PROCESS_MODE_ALWAYS. En SOLITARIO el arbol del juego esta
#  PAUSADO durante el combate y en multijugador NO (ver game.gd, _modal_stack): sin eso, los
#  efectos funcionan con un compañero y se quedan congelados jugando solo.
# ============================================================

extends Node
class_name CombatFX

# El tinte de un recuadro ha cambiado. Se avisa por señal en vez de repintar el estilo aqui:
# quien sabe si esa tarjeta esta SELECCIONADA (borde blanco) o APAGADA (cadaver gris) es
# combat.gd, y el stylebox tiene que salir de un solo sitio o el borde de seleccion se perderia
# en cuanto te entrara un veneno.
signal tinte_cambiado(bloque: Dictionary)

# A esta tarjeta ya le ha caido el ULTIMO golpe que tenia pendiente, asi que ya se puede apagar
# (el gris del cadaver). Existe porque los muertos se rematan al final de la accion, o sea antes
# de que la animacion haya reproducido un solo golpe: sin esto el bicho se ponia gris y despues
# le llegaba volando el hechizo que lo mataba.
signal apagar_ahora(bloque: Dictionary)

# COMO se presenta un impacto. MELEE es lo de siempre: la tarjeta del que pega EMBISTE a la del
# que lo recibe. Todos los demas son de hechizo y NINGUNO embiste -- el que lanza se queda en su
# sitio y lo que viaja es el efecto, que es lo que diferencia lanzar un conjuro de dar un tajo.
#
# Son OCHO justos porque en la red viajan en 3 bits (ver _apuntar_impacto_red en combat.gd).
enum Estilo { MELEE = 0, PROYECTIL = 1, ARCANO = 2, RAYO = 3, CAIDA_RAYO = 4,
		CAIDA_GOTA = 5, BARRIDO = 6, ARCO = 7 }

# Cuanto tarda cada efecto en llegar desde que nace. Se usa para dar de alta el dibujo ANTES del
# instante del golpe, de forma que el impacto aterrice EXACTAMENTE cuando salen el numero y la
# sacudida: si el rayo llegara despues del temblor, se leeria al reves.
const T_VUELO := {
	Estilo.MELEE: 0.0, Estilo.PROYECTIL: 0.20, Estilo.ARCANO: 0.18, Estilo.RAYO: 0.10,
	Estilo.CAIDA_RAYO: 0.16, Estilo.CAIDA_GOTA: 0.22, Estilo.BARRIDO: 0.26, Estilo.ARCO: 0.14,
}

# --- ritmo de un impacto -------------------------------------------------------------------
# Manda la ANIMACION: el turno dura lo que dura esto, no hay espera muerta detras. Un golpe
# suelto (0.55) sale mas rapido que el segundo fijo que habia antes; una racha se nota.
const T_IDA := 0.22          # la tarjeta se lanza hacia el objetivo
const T_PUM := 0.12          # el instante del impacto (flash + sacudida)
const T_VUELTA := 0.21       # y se vuelve a su sitio
const T_ENCADENADO := 0.20   # separacion entre impactos de una misma racha
const TOPE_RACHA := 0.75     # techo de lo que suman TODOS los extras de una racha
const TOPE_TOTAL := 1.40     # techo duro: ninguna accion puede comerse mas turno que esto

# LOS HECHIZOS VAN A SU AIRE. Una racha de magia no es una racha de espada: los impactos se
# encadenan MUCHO mas apretados (una tormenta es un chaparron, no veinte tajos) pero el conjunto
# puede durar mas, porque es el momentazo del mago. Tormenta son ~32 impactos -> ~1.9s.
# El melee no se entera de nada de esto: sigue con las constantes de arriba.
const TOPE_TOTAL_MAGIA := 2.00
const TOPE_RACHA_MAGIA := 1.30
const T_ENCADENADO_MAGIA := 0.075
const T_ARRANQUE_MAGIA := 0.22   # lo que tarda en llegar el efecto mas lento (el barrido)
const T_COLA_MAGIA := 0.25       # margen para que la ultima sacudida y salpicadura terminen

# Del 7º impacto en adelante ya no hay embestida (seria un temblor ilegible): solo numero y
# sacudida. Solo afecta al melee -- la magia no embiste nunca.
const MAX_IMPACTOS_ANIMADOS := 6
# A partir de aqui se descartan: son cosmeticos. 40 y no 24 porque Tormenta encola ~32 impactos
# (20 golpes, y los de RAYO ademas salpican a los adyacentes) y con el tope viejo los ultimos
# desaparecian EN SILENCIO: el daño se aplicaba igual, solo faltaba el dibujo.
const MAX_EVENTOS := 40

const DIST_EMBESTIDA := 26.0   # cuanto se desplaza la tarjeta que pega
const AMP_SACUDIDA := 7.0      # y cuanto tiembla la que la recibe
const T_SACUDIDA := 0.22
const T_FLASH := 0.06

# --- numeros flotantes ---------------------------------------------------------------------
const MAX_NUMEROS := 32
const T_NUMERO := 0.65
const SUBIDA_NUMERO := 26.0
const RETRASO_CRIT := 0.05   # el critico entra un pelin tarde para que se lea antes el impacto

# --- barras --------------------------------------------------------------------------------
# Velocidad de acercamiento, en fracciones del maximo por segundo. 3.0 = un golpe que se lleva
# un tercio de la vida tarda ~0.11s; uno que se la lleva entera, ~0.33s. Va con el ritmo de la
# embestida a proposito: la barra acaba de bajar justo cuando la tarjeta vuelve a su sitio.
const VEL_BARRA := 3.0

# QUE ESTADO SE VE COMO QUE.
#
# Van por TRES FAMILIAS, y cada una tiene su forma. La forma es lo que hace la lectura: antes
# todos eran el mismo cuadradito brillante con distinto color, asi que el Pegajoso (verde) se leia
# igual que una curacion. Un cuadradito que centellea significa "algo bueno" en TODO el juego (es
# el destello de las vetas y del equipo raro), asi que no puede ser tambien un debuff.
#
#   DAÑO   algo te esta consumiendo    -> motas que SUBEN y se deshacen
#   CAPA   algo te cubre               -> pelicula que se acumula + goterones que escurren
#   AYUDA  algo te esta ayudando       -> CRUCES que suben (curar) o destellos (los demas buffs)
#
# CABE UNA DE CADA FAMILIA A LA VEZ, no dos de la misma: si estas ardiendo Y envenenado se ve el
# fuego (el primero de la lista manda), pero si estas ardiendo Y pringado Y regenerando se ven las
# tres cosas, porque son tres familias distintas y no compiten entre si. Con eso, lo que ves
# siempre responde a tres preguntas separadas: ¿me estan haciendo daño?, ¿llevo algo encima?,
# ¿tengo algo a favor?
#
# Lo que no sale en ninguna lista se sigue viendo, pero solo por el TINTE del recuadro, que es
# informacion suficiente para un "lento" o un "marcado". Con los 31 a la vez esto seria una sopa.
#
# Se guardan los Id (enteros), NUNCA los emojis: el catalogo es la fuente de iconos y colores, y
# asi un estado nuevo entra solo (como "solo tinte", que es el fallback correcto).
# CADA FAMILIA tiene su hueco y su forma. Ojo a las dos curaciones: van en familias SEPARADAS a
# proposito, porque son dos recursos distintos y tienes que poder ver a la vez que te sube la vida
# y que te sube el maná. Juntas, la de vida ganaba siempre y la azul no salia nunca.
const FAMILIAS: Array = [
	# [nombre, forma, ids...] -- el orden dentro de la lista es quien gana el hueco de su familia.
	# ARDE POR ABAJO: una hoguera en el borde inferior de la tarjeta (dibujada, como el agua) mas
	# las llamitas que suben de ella. Un cuadradito naranja subiendo no es una quemadura.
	["fuego", "llama", [StatusEffects.Id.QUEMADURA]],
	# CALAVERITAS subiendo, y mas cuantas mas dosis lleves: el veneno APILA y se tiene que notar.
	["veneno", "veneno", [StatusEffects.Id.VENENO]],
	# SANGRA, y tambien apila: gotas que caen por toda la tarjeta.
	["sangra", "sangre", [StatusEffects.Id.SANGRADO]],
	# UN CORTE ABIERTO dibujado en un sitio fijo, del que gotea sangre. Las motas genericas no
	# dicen "herida"; un tajo que no cierra, si.
	["herida", "raja", [StatusEffects.Id.HERIDA_PROFUNDA]],
	["dano", "ascendente", [StatusEffects.Id.CORROSION]],
	# Te CHORREA encima: pelicula que se acumula + goterones. Es lo unico que pinta CapaEstado.
	["capa", "capa", [
		StatusEffects.Id.PEGAJOSO, StatusEffects.Id.MOJADO,
	]],
	# Algo tuyo ha BAJADO: flechas cayendo despacio.
	["merma", "flecha", [
		StatusEffects.Id.LENTO, StatusEffects.Id.DEBIL, StatusEffects.Id.VULNERABLE,
	]],
	# TE HAN SEÑALADO: una diana en el centro de la tarjeta que late. Va dibujada y no con
	# particulas porque es un MARCADOR -- tiene que estar siempre en el mismo sitio y con la misma
	# pinta, o deja de servir para encontrar de un vistazo a quien has marcado.
	["marca", "diana", [StatusEffects.Id.MARCA]],
	# Te quitan el turno o te lo capan: el corro de estrellitas girando SOBRE LA CABEZA, tal cual el
	# gag de dibujos animados de toda la vida.
	["control", "estrella", [
		StatusEffects.Id.ATURDIDO, StatusEffects.Id.MIEDO, StatusEffects.Id.SILENCIO,
	]],
	# No te hace nada por si mismo, esta ahi crepitando y sube lo siguiente que te caiga. Van
	# RAYITOS (zigzags) y no chispas genericas: una X se lee como "algo brilla", un zigzag como
	# "esto esta electrificado".
	["ampli", "rayito", [
		StatusEffects.Id.RAYO,
	]],
	# Las dos curaciones: cruces verdes la vida, azules el maná.
	["vida", "cruz", [StatusEffects.Id.REGENERACION]],
	["mana", "cruz", [StatusEffects.Id.REGEN_MANA]],
	# Algo tuyo ha SUBIDO: las mismas flechas de la merma pero hacia arriba. Al ser el espejo
	# exacto se leen de un vistazo sin tener que aprenderse nada nuevo.
	["buff", "flecha_arriba", [
		StatusEffects.Id.FORTALEZA, StatusEffects.Id.BALUARTE,
	]],
	# VELOCIDAD: lineas de velocidad cruzando la tarjeta. Unos puntitos brillantes no dicen "vas
	# mas rapido"; estas si, y sin tener que explicarlas.
	["veloz", "estela", [StatusEffects.Id.PRESTEZA]],
	# TE TAPA: un velo de niebla sobre la tarjeta entera, sin una sola particula. El Sigilo se dice
	# haciendo que cueste verte, no echandote puntitos grises encima.
	["velo", "niebla", [StatusEffects.Id.SIGILO]],
	# El resto de cosas a tu favor, que no son ni "un numero que sube" ni nada con forma propia:
	# el destello de siempre, que en todo el juego significa "esto es bueno".
	["favor", "destello", [
		StatusEffects.Id.GUARDIA_CARNE, StatusEffects.Id.ESCOLTA,
	]],
]
# Los 8 PLATOS se quedan SOLO con el tinte a proposito, y no es un olvido: duran 20 minutos de
# reloj, asi que un emisor suyo estaria encendido toda la partida y no diria nada -- lo que
# informa de un estado es que aparezca y desaparezca.

# CUANTOS se pintan a la vez. NO es uno por familia: eso hacia que dos estados de la misma familia
# se taparan entre si (te ponias Sigilo y Guardia de carne y solo salia uno), que es el mismo tipo
# de mentira que enseñar un estado que no tienes. Se pintan los CUATRO primeros, salgan de donde
# salgan, y el orden es el de FAMILIAS: lo que te esta matando antes que lo que te viene bien.
#
# Cuatro y no mas porque la tarjeta mide 216x120: con cinco o seis emisores encima deja de leerse
# nada. Los que se caen del corte se siguen viendo en su chip y en el tinte del recuadro.
const MAX_EMISORES := 4

# Lo TRANSPARENTES que van todos los efectos de estado. Se pintan encima del nombre, de la barra
# de vida y de los numeros, asi que ninguno puede taparlos: informan de algo, pero lo que hay
# debajo importa mas.
const OPACIDAD := 0.7

const DORADO_BUFF := Color(1.0, 0.85, 0.35)

# icono (String) -> {"tipo": "ascendente"/"destello"/"", "color": Color, "debuff": bool}
# Se construye UNA vez recorriendo el catalogo. Al ir por Id y no por emoji escrito a mano, un
# estado nuevo del catalogo entra solo (como "solo tinte", que es el fallback correcto).
static var _tabla_cache: Dictionary = {}

# La capa donde vuelan los numeros. La monta combat.gd por encima de todo (si colgaran de la
# tarjeta, el clip_contents de la zona de chips se los comeria).
#
# Al asignarla se crea DENTRO la capa de hechizos, por debajo de los numeros. Se hace aqui y no
# en _ready porque el orden de arranque manda: este nodo nace al principio de combat._ready (las
# tarjetas necesitan registrarse en el) y la capa de numeros no existe hasta _montar_columna.
var capa_numeros: Control = null:
	set(v):
		capa_numeros = v
		if v == null or _capa_fx != null:
			return
		_capa_fx = CapaHechizos.new()
		v.add_child(_capa_fx)
		# El PRIMERO de la capa: los rayos y las bolas van por DEBAJO de los numeros de daño, que
		# son lo que hay que poder leer pase lo que pase.
		v.move_child(_capa_fx, 0)

var _capa_fx: CapaHechizos = null

var _tarjetas: Array[Dictionary] = []   # las mismas Dictionary que maneja combat.gd
var _cola: Array[Dictionary] = []       # impactos de la accion en curso
var _t := 0.0                           # reloj de la racha
var _dur := 0.0                         # lo que dura la racha entera
var _activa := false
var _numeros: Array[Dictionary] = []    # los que estan volando ahora
var _pool: Array[Label] = []            # Labels reciclados: nada de crear nodos por frame


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# ============================================================
#  TARJETAS
# ============================================================

# Da de alta una tarjeta recien creada y le cuelga su capa de efectos. Se llama desde los TRES
# sitios que crean bloques (_setup_ui, _anadir_bloque_aliado y _meter_enemigo).
#
# La capa es el ULTIMO hijo del panel a proposito: los hermanos se dibujan en orden, asi que
# las particulas caen POR ENCIMA del nombre y de las barras. Y va en IGNORE para no robarle a
# la tarjeta el clic de seleccion, que es del panel.
func registrar(bloque: Dictionary) -> void:
	if bloque.is_empty() or bloque.has("fx_capa"):
		return
	var panel: Control = bloque.get("panel")
	if panel == null or not is_instance_valid(panel):
		return
	# La PELICULA va primero (debajo): es una capa sobre la tarjeta, y las particulas caen encima.
	var pelicula := CapaEstado.new()
	panel.add_child(pelicula)
	bloque["fx_pelicula"] = pelicula

	var capa := Control.new()
	capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.add_child(capa)
	bloque["fx_capa"] = capa
	bloque["fx_emisores"] = {}
	bloque["fx_firma"] = ""
	bloque["tinte"] = Color.WHITE
	if not _tarjetas.has(bloque):
		_tarjetas.append(bloque)


# Al cerrarse la pelea. No libera los nodos (se van con la escena), solo suelta las referencias
# para que no queden Dictionary vivos apuntando a paneles muertos.
func olvidar_todas() -> void:
	cancelar()
	_tarjetas.clear()


# ============================================================
#  ESTADOS: tinte + particulas
# ============================================================

# 'chips' = lo que devuelve _chips_de(c): [[etiqueta, tooltip, icono, color], ...]. Los chips de
# MECANICA (cargando, recitando, provocacion, imbuicion) vienen como pares de 2 y se ignoran
# aqui: no son estados y no tienen color de catalogo. Se mira el TAMAÑO y no el tipo por lo
# mismo que _refrescar_chips: un espejo con una instantanea vieja manda pares de 2 y no puede
# reventar por eso.
#
# 'vivo' = false apaga todo. Hace falta explicito porque _update_hp SE SALTA los chips de los
# caidos, asi que sin esta llamada un cadaver se quedaba ardiendo para siempre.
func pintar_estados(bloque: Dictionary, chips: Array, vivo: bool) -> void:
	if bloque.is_empty() or not bloque.has("fx_capa"):
		return
	var quiere: Array[Dictionary] = []      # lo que se pinta al final (como mucho MAX_EMISORES)
	var n_buff := 0
	var n_debuff := 0
	var col_debuff := Color.WHITE
	var col_buff := Color.WHITE
	if vivo:
		var tabla: Dictionary = _tabla()
		for par in chips:
			if par.size() < 4:
				continue
			var col: Color = par[3]
			var info: Dictionary = tabla.get(_clave(String(par[2]), col), {})
			if info.is_empty():
				continue
			# El recuento de buffs/debuffs es para el TINTE del recuadro, y va aparte de las
			# particulas: un estado sin forma (los platos) tiñe igual.
			if bool(info.get("debuff", false)):
				n_debuff += 1
				if col_debuff == Color.WHITE:
					col_debuff = col
			else:
				n_buff += 1
				if col_buff == Color.WHITE:
					col_buff = col
			var fam: String = String(info.get("familia", ""))
			if fam == "":
				continue   # sin forma: se queda solo con el tinte
			quiere.append({"icono": String(par[2]), "color": col,
				"tipo": String(info["tipo"]), "familia": fam,
				"fam_orden": int(info.get("fam_orden", 99)),
				"orden": int(info.get("orden", 99)),
				"stacks": _stacks_de(String(par[0]))})
	# Por FAMILIA primero y por gravedad despues: lo que te esta matando se ve antes que lo que te
	# viene bien. El orden tiene que ser estable ademas de justo, porque de el sale la firma que
	# decide si hay que recrear emisores o no.
	quiere.sort_custom(func(a, b) -> bool:
		if int(a["fam_orden"]) != int(b["fam_orden"]):
			return int(a["fam_orden"]) < int(b["fam_orden"])
		return int(a["orden"]) < int(b["orden"]))
	if quiere.size() > MAX_EMISORES:
		quiere.resize(MAX_EMISORES)

	# FIRMA: la huella de lo que deberia verse. _update_hp llama aqui constantemente (cada golpe,
	# cada tick, cada refresco de red) y casi siempre no ha cambiado nada; sin este corte se
	# estarian recreando 18 emisores por golpe.
	var tinte: Color = _tinte_de(n_buff, n_debuff, col_buff, col_debuff)
	var firma: String = "%d" % tinte.to_rgba32()
	for q in quiere:
		# Los STACKS entran en la firma: si te cae otra dosis de baba, el efecto tiene que crecer,
		# y sin esto el corte por firma decidia que "no ha cambiado nada" y se quedaba igual.
		firma += ";%s,%d,%d" % [q["icono"], (q["color"] as Color).to_rgba32(), int(q["stacks"])]
	if String(bloque.get("fx_firma", "")) == firma:
		return
	bloque["fx_firma"] = firma

	_reconciliar_emisores(bloque, quiere)

	# LA PELICULA de lo que te cubre. Va aparte de los emisores porque no es una particula: es una
	# capa pintada sobre la tarjeta, y es lo que hace que el Pegajoso se lea como "estas cubierto
	# de baba" y no como "algo verde te esta pasando".
	var pelicula: CapaEstado = bloque.get("fx_pelicula")
	if pelicula != null and is_instance_valid(pelicula):
		# Las cuatro capas son INDEPENDIENTES entre si: puedes estar pringado, escondido, marcado
		# y con un tajo abierto a la vez, y cada cosa se pinta en su sitio.
		var pintado: Dictionary = {}   # tipo -> color
		var chorreos: Array = []       # TODAS las que te chorrean (baba y agua pueden ir juntas)
		var stk: Dictionary = {}       # tipo -> dosis, para lo que escala
		for q in quiere:
			var t: String = String(q["tipo"])
			if t == "capa":
				chorreos.append({"col": q["color"], "stacks": int(q.get("stacks", 1))})
			elif not pintado.has(t):
				pintado[t] = q["color"]
				stk[t] = int(q.get("stacks", 1))
		pelicula.pintar_capas(chorreos)
		pelicula.pintar_fuego(pintado.get("llama", Color.TRANSPARENT),
			1.0 if pintado.has("llama") else 0.0)
		pelicula.pintar_niebla(pintado.get("niebla", Color.TRANSPARENT),
			1.0 if pintado.has("niebla") else 0.0)
		pelicula.pintar_diana(pintado.get("diana", Color.TRANSPARENT),
			1.0 if pintado.has("diana") else 0.0)
		pelicula.pintar_raja(pintado.get("raja", Color.TRANSPARENT),
			1.0 if pintado.has("raja") else 0.0)

	if bloque.get("tinte", Color.WHITE) != tinte:
		bloque["tinte"] = tinte
		tinte_cambiado.emit(bloque)


# Crea los que faltan, deja en paz los que siguen y apaga los que se han ido. Reutilizar importa:
# recrear un CPUParticles2D reinicia su ciclo y el efecto daria un "tirón" en cada refresco.
func _reconciliar_emisores(bloque: Dictionary, quiere: Array[Dictionary]) -> void:
	var capa: Control = bloque["fx_capa"]
	var vivos: Dictionary = bloque.get("fx_emisores", {})
	var quedan: Dictionary = {}
	for q in quiere:
		# La clave lleva los STACKS: si te cae otra dosis, el emisor se rehace con mas cantidad en
		# vez de quedarse con la de antes. Sin ellos en la clave, "el mismo icono" se daba por
		# bueno y el efecto no crecia nunca.
		var ico: String = "%s#%d" % [q["icono"], int(q.get("stacks", 1))]
		var p: CPUParticles2D = vivos.get(ico)
		if p != null and is_instance_valid(p):
			quedan[ico] = p
			vivos.erase(ico)
			continue
		p = _crear_emisor(capa, q["tipo"], q["color"], int(q.get("stacks", 1)))
		if p != null:
			quedan[ico] = p
	# Lo que sobra: se apaga (deja de emitir sin borrar lo ya emitido) y se libera.
	for ico in vivos:
		var viejo: CPUParticles2D = vivos[ico]
		if viejo != null and is_instance_valid(viejo):
			Particulas.apagar(viejo)
			viejo.queue_free()
	bloque["fx_emisores"] = quedan


# 'stacks' = cuantas dosis lleva. Sube la CANTIDAD del efecto (mas gotas, mas calaveras), que es
# la forma honesta de enseñar que te han echado tres capas de baba y no una. Se capa por arriba:
# a partir de la tercera ya no se distingue y solo seria ruido.
func _crear_emisor(capa: Control, tipo: String, color: Color, stacks: int = 1) -> CPUParticles2D:
	var tam: Vector2 = capa.size
	if tam.x <= 0.0 or tam.y <= 0.0:
		tam = Vector2(180, 90)   # todavia sin layout: se recoloca solo en el resized de abajo
	var mult: float = 1.0 + 0.5 * float(clampi(stacks, 1, 4) - 1)
	var p: CPUParticles2D = null
	match tipo:
		"veneno":
			# Calaveritas subiendo, y mas cuantas mas dosis lleve encima.
			p = Particulas.ascendentes(capa, color, 0.85 * mult, tam.y * 0.5,
				Particulas.textura_calavera())
		"sangre":
			p = Particulas.sangre(capa, color, tam, mult)
		"ascendente":
			# 'alto' es el lado del cuerpo para Particulas: aqui el cuerpo es la tarjeta, y con la
			# mitad del alto las llamas suben ~1.5 tarjetas sin taparlo todo.
			p = Particulas.ascendentes(capa, color, 0.85, tam.y * 0.5)
		"cruz":
			p = Particulas.cruces(capa, color, 1.0, tam.y * 0.5)
		"capa":
			p = Particulas.chorretones(capa, color, tam, mult)
		"flecha":
			p = Particulas.flechas(capa, color, tam, 1.0)
		"flecha_arriba":
			p = Particulas.flechas(capa, color, tam, 1.0, true)
		"estrella":
			p = Particulas.orbitan(capa, color, tam, 1.0)
		"llama":
			p = Particulas.ascendentes(capa, color, 0.85, tam.y * 0.5, Particulas.textura_llama())
		"chispa":
			p = Particulas.chispas(capa, color, tam, 1.0)
		"rayito":
			p = Particulas.chispas(capa, color, tam, 1.0, Particulas.textura_rayito())
		"estela":
			p = Particulas.estelas(capa, color, tam, 1.0)
		"raja":
			# El corte lo dibuja CapaEstado; esto son SOLO las gotas que salen de el, asi que la
			# boquilla es diminuta (el tamaño se lo da el ajustar de abajo, en el punto del corte).
			p = Particulas.chorretones(capa, color, Vector2(8.0, 8.0), 0.6)
		"niebla", "diana":
			return null   # no llevan particulas: los pinta CapaEstado
		_:
			p = Particulas.destellos(capa, color, tam, 0.6, 0.7)
	if p == null:
		return null
	# OBLIGATORIO (ver cabecera): en solitario el arbol esta pausado durante el combate.
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	# NADA opaco encima de la tarjeta. Estos efectos van sobre el nombre, la vida y los numeros, y
	# lo que hay debajo importa mas que ellos: son un aviso, no el contenido. Se baja aqui, en el
	# emisor, y no en las rampas de Particulas -- esas las comparten las vetas y los proyectiles
	# del mundo, donde si tienen que verse a tope.
	p.modulate.a = OPACIDAD
	# El tamaño real no se sabe hasta que el contenedor coloca la tarjeta, asi que la zona de
	# emision sigue al layout en vez de clavarse a un numero. Mismo patron que MenuScaffold.brillo_en.
	var ajustar := func() -> void:
		if not is_instance_valid(p) or not is_instance_valid(capa):
			return
		p.position = capa.size * 0.5
		match tipo:
			"ascendente", "cruz", "llama":
				# Nacen en una franja ancha y baja: la cosa te sube por todo el cuerpo, no te
				# brota de un punto.
				p.emission_rect_extents = Vector2(capa.size.x * 0.45, capa.size.y * 0.12)
			"capa":
				# Los goterones nacen ARRIBA del todo y bajan por la tarjeta.
				p.position.y = capa.size.y * 0.16
				p.emission_rect_extents = Vector2(capa.size.x * 0.44, capa.size.y * 0.08)
			"flecha", "flecha_arriba":
				# Las de bajar nacen arriba y las de subir abajo, para que se vea el recorrido.
				var signo: float = 1.0 if tipo == "flecha" else -1.0
				p.position.y = capa.size.y * (0.5 - 0.28 * signo)
				p.emission_rect_extents = Vector2(capa.size.x * 0.42, capa.size.y * 0.1)
			"estrella":
				# SOBRE LA CABEZA, no en medio de la tarjeta: el corro va arriba, donde estaria la
				# cabeza del personaje, que es donde lo pone todo dibujo animado desde siempre.
				p.position.y = capa.size.y * 0.2
				p.emission_sphere_radius = minf(capa.size.x * 0.5, capa.size.y) * 0.42
			"raja":
				# Las gotas nacen EN EL CORTE, en el mismo punto donde CapaEstado lo dibuja.
				p.position = capa.size * CapaEstado.POS_RAJA
				p.emission_rect_extents = Vector2(3.0, 2.0)
			"estela":
				# Nacen pegadas al borde izquierdo y cruzan la tarjeta entera.
				p.position.x = 0.0
				p.emission_rect_extents = Vector2(2.0, capa.size.y * 0.38)
				p.initial_velocity_min = capa.size.x * 1.4
				p.initial_velocity_max = capa.size.x * 2.2
			_:
				p.emission_rect_extents = capa.size * 0.5
	capa.resized.connect(ajustar)
	ajustar.call()
	return p


# Buffs = dorado, debuffs = el color del estado pero apagado, empate o nada = blanco (sin tinte).
# Manda EL BANDO QUE MAS PESA y no la suma: un envenenado con Fortaleza tiene que leerse como
# una cosa o la otra, no como un marron a medias.
func _tinte_de(n_buff: int, n_debuff: int, col_buff: Color, col_debuff: Color) -> Color:
	if n_buff == n_debuff:
		return Color.WHITE
	if n_buff > n_debuff:
		var dorado: Color = col_buff.lerp(DORADO_BUFF, 0.5)
		return Color.WHITE.lerp(dorado, clampf(0.35 + 0.15 * float(n_buff), 0.0, 0.8))
	var apagado: Color = col_debuff.darkened(0.35)
	apagado.s = minf(apagado.s, 0.65)
	return Color.WHITE.lerp(apagado, clampf(0.4 + 0.1 * float(n_debuff), 0.0, 0.8))


# El catalogo entero traducido a "que efecto lleva cada icono". 'orden' = prioridad cuando hay
# mas estados que emisores: los DoT primero (arder es lo mas urgente de leer), luego el resto.
static func _tabla() -> Dictionary:
	if not _tabla_cache.is_empty():
		return _tabla_cache
	for id in StatusEffects.all_ids():
		var d: Dictionary = StatusEffects.def(id)
		var ico: String = str(d.get("icono", ""))
		if ico == "":
			continue
		# 'familia' = de que hueco compite (uno por familia); 'orden' = quien gana dentro de ella;
		# 'tipo' = con que forma se pinta.
		var familia := ""
		var tipo := ""
		var orden := 99
		var fam_orden := 99
		for fi in FAMILIAS.size():
			var f: Array = FAMILIAS[fi]
			var i: int = (f[2] as Array).find(id)
			if i >= 0:
				familia = String(f[0])
				tipo = String(f[1])
				orden = i
				fam_orden = fi
				break
		_tabla_cache[_clave(ico, d.get("color", Color.WHITE))] = {
			"tipo": tipo, "familia": familia, "orden": orden, "fam_orden": fam_orden,
			"debuff": bool(d.get("debuff", false))}
	return _tabla_cache


# La clave de la tabla: icono Y COLOR, no solo el icono. HAY EMOJIS REPETIDOS en el catalogo --
# 🔥 lo llevan Quemadura y el plato "Fuerza", 🛡 lo llevan Baluarte y el plato "Aguante"-- asi que
# con la clave solo por icono el que se define despues (el plato, que va al final) pisaba al otro
# y Quemadura y Baluarte se quedaban SIN efecto, mudos, sin un solo error por ningun lado.
#
# El color los separa porque cada entrada del catalogo tiene el suyo, y es el mismo que viaja en
# el chip resuelto: la clave se puede reconstruir igual en el espejo, que es donde no hay Ids.
static func _clave(ico: String, col: Color) -> String:
	return "%s|%d" % [ico, col.to_rgba32()]


# CUANTAS DOSIS lleva encima, sacadas de la etiqueta del chip ("🕸x3 2t" -> 3). Se lee del texto y
# no de c.statuses a proposito, por lo mismo que todo lo demas de aqui: en el espejo de
# multijugador no hay motor de estados y la etiqueta ya resuelta es lo unico que llega.
# Los que no apilan no traen la "xN" y valen 1.
static func _stacks_de(etiqueta: String) -> int:
	var i: int = etiqueta.find("x")
	if i < 0:
		return 1
	var n := ""
	var j: int = i + 1
	while j < etiqueta.length() and etiqueta[j] >= "0" and etiqueta[j] <= "9":
		n += etiqueta[j]
		j += 1
	return maxi(1, int(n)) if n != "" else 1


# ============================================================
#  BARRAS
# ============================================================

# _update_hp sigue siendo el unico que decide el valor, pero ahora fija el DESTINO y la barra
# viaja sola. El NUMERO de al lado se queda instantaneo (lo pone _update_hp): la barra puede
# mentir medio segundo, la cifra no.
func fijar_barra(bloque: Dictionary, clave: String, valor: float, inmediato := false) -> void:
	if not bloque.has(clave):
		return
	var bar: ProgressBar = bloque[clave]
	if bar == null or not is_instance_valid(bar):
		return
	# La PRIMERA vez que se toca una barra siempre es un salto seco, nunca un viaje. Se detecta
	# por que todavia no tiene meta, y con eso quedan cubiertos de golpe TODOS los caminos que
	# crean tarjetas (el arranque, un refuerzo, un compañero que se une, el roster del espejo):
	# sin esto, cada tarjeta recien nacida hacia subir su vida desde cero como si se curara.
	var primera: bool = not bloque.has(clave + "_meta")
	# 'valor' es la vida FINAL de la accion entera, que es lo unico que sabe combat.gd. Pero la
	# barra no puede irse ya a ese numero: los golpes van cayendo uno a uno y cada uno tiene que
	# descontar LO SUYO cuando toca, o la vida baja antes de que se vea el golpe que la baja.
	# Lo que queda por descontar se guarda en '<clave>_pend' (ver arrancar_cola).
	bloque[clave + "_fin"] = valor
	bloque[clave + "_meta"] = valor + float(bloque.get(clave + "_pend", 0.0))
	if inmediato or primera:
		bar.value = bloque[clave + "_meta"]


# Olvida los destinos de las barras de UNA tarjeta, para que el siguiente fijar_barra vuelva a
# ser un salto seco. Lo usa el hueco de cadaver que se reestrena: la barra del que entra no puede
# venir viajando desde la vida del que estaba antes.
func olvidar_barras(bloque: Dictionary) -> void:
	for clave in ["hp", "en", "mp"]:
		bloque.erase(clave + "_meta")


# Le quita a la barra de UNA tarjeta lo que acaba de comerse en este golpe. Cuando ya no queda
# nada pendiente, la meta es la vida final y todo cuadra solo.
func _descontar(bloque: Dictionary, dmg: float) -> void:
	if bloque.is_empty() or not bloque.has("hp_fin"):
		return
	var pend: float = maxf(0.0, float(bloque.get("hp_pend", 0.0)) - maxf(dmg, 0.0))
	bloque["hp_pend"] = pend
	bloque["hp_meta"] = float(bloque["hp_fin"]) + pend
	if pend <= 0.0:
		_soltar_apagado(bloque)


# Si esta tarjeta estaba esperando a morirse en pantalla, ya puede: le ha caido todo lo que le
# tenia que caer.
func _soltar_apagado(bloque: Dictionary) -> void:
	if not bool(bloque.get("fx_apagar", false)):
		return
	bloque.erase("fx_apagar")
	apagar_ahora.emit(bloque)


# ¿Le queda a esta tarjeta algun golpe por aterrizar? Lo pregunta combat.gd antes de poner un
# cadaver en gris.
func golpes_pendientes(bloque: Dictionary) -> bool:
	return float(bloque.get("hp_pend", 0.0)) > 0.0


# Suelta lo que quedara a medias: la barra se va ya a la vida real. Se llama al acabar la racha y
# al cancelarla (tecla P), para que un golpe que no se llego a ver no deje la barra mintiendo.
func _saldar_barras() -> void:
	for b in _tarjetas:
		if float(b.get("hp_pend", 0.0)) != 0.0:
			b["hp_pend"] = 0.0
			if b.has("hp_fin"):
				b["hp_meta"] = b["hp_fin"]
		# Y si alguien se quedo esperando a morirse en pantalla, que se muera ya: la racha se ha
		# acabado (o la han cortado con la P) y no va a caerle nada mas.
		_soltar_apagado(b)


func _mover_barras(delta: float) -> void:
	for b in _tarjetas:
		for clave in ["hp", "en", "mp"]:
			if not b.has(clave) or not b.has(clave + "_meta"):
				continue
			var bar: ProgressBar = b[clave]
			if bar == null or not is_instance_valid(bar):
				continue
			var meta: float = b[clave + "_meta"]
			if is_equal_approx(bar.value, meta):
				continue
			var paso: float = maxf(bar.max_value, 1.0) * VEL_BARRA * delta
			bar.value = move_toward(bar.value, meta, paso)


func _snap_barras() -> void:
	for b in _tarjetas:
		for clave in ["hp", "en", "mp"]:
			if b.has(clave) and b.has(clave + "_meta") and is_instance_valid(b[clave]):
				b[clave].value = b[clave + "_meta"]


# ============================================================
#  IMPACTOS
# ============================================================

# Apunta UN golpe. No lo reproduce todavia: la accion puede tener 8 y hasta que no estan todos
# no se sabe cuanto tiene que durar la racha (ver arrancar_cola).
#
# 'peso' = QUE FRACCION del golpe principal se lleva este objetivo (1.0 el principal, 0.5 un
# adyacente de Brasa, 0.55 un rebote de Rayo). Manda el tamaño del temblor y del efecto: si el
# del medio come 100 y los de los lados 50, los de los lados tiemblan la mitad. Se pasa la
# FRACCION y no el daño a proposito -- el daño ya lleva dentro el critico y las resistencias, y
# entonces un objetivo que RESISTE el fuego temblaria menos que uno que no, justo al reves.
func encolar(b_atacante: Dictionary, b_victima: Dictionary, dmg: float, crit: bool,
		evadido: bool, color_elem: Color, estilo: int = Estilo.MELEE, peso: float = 1.0) -> void:
	if b_victima.is_empty() or _cola.size() >= MAX_EVENTOS:
		return
	_cola.append({
		"ba": b_atacante, "bv": b_victima, "dmg": dmg, "crit": crit,
		"evadido": evadido, "color": color_elem, "t": 0.0, "lanzado": false,
		"estilo": estilo, "peso": clampf(peso, 0.2, 1.5), "fx_lanzado": false,
	})
	# LA VIDA NO PUEDE BAJAR ANTES QUE EL GOLPE. Se apunta AQUI, en el mismo instante en que el
	# golpe se resuelve, y no al arrancar la cola: entre una cosa y otra combat.gd llama a
	# _update_hp varias veces y desde sitios distintos segun la accion, asi que hacerlo al final
	# dependia de en que orden cayeran las llamadas. Aqui no hay orden que valga.
	#
	# Lo apuntado se le DEVUELVE a la barra: mientras quede pendiente, su destino es "la vida
	# final MAS lo que aun no se ha visto caer", o sea justo donde estaba antes de la accion.
	# Cada impacto le descuenta lo suyo al aterrizar (ver _descontar).
	if not evadido and dmg > 0.0:
		b_victima["hp_pend"] = float(b_victima.get("hp_pend", 0.0)) + dmg
		if b_victima.has("hp_fin"):
			b_victima["hp_meta"] = float(b_victima["hp_fin"]) + float(b_victima["hp_pend"])


# Cierra la racha y la echa a andar. Devuelve LO QUE VA A DURAR: ese numero es el que se convierte
# en la duracion del turno (ver _pausa_lectura en combat.gd). 0.0 = no habia nada que animar, y
# entonces manda quien llama (un turno aturdido se queda su pausa corta de lectura).
func arrancar_cola() -> float:
	if _cola.is_empty():
		return 0.0
	var n: int = _cola.size()
	# ¿Es una racha de MAGIA? Se deduce de la propia cola en vez de recibirlo por parametro, y eso
	# importa: a esta funcion la llama TAMBIEN el espejo de multijugador (aplicar_impactos), asi
	# que dedurciendolo aqui las dos pantallas sacan la misma duracion sin sincronizar nada.
	var magia: bool = false
	for ev in _cola:
		if int(ev.get("estilo", Estilo.MELEE)) != Estilo.MELEE:
			magia = true
			break
	# (Lo que le queda por bajar a cada barra ya se apunto al ENCOLAR cada golpe, no aqui: ver
	# encolar. Hacerlo en este punto dependia de si combat.gd llamaba a _update_hp antes o
	# despues, y eso cambia segun la accion.)
	var t_enc: float = T_ENCADENADO_MAGIA if magia else T_ENCADENADO
	var arranque: float = T_ARRANQUE_MAGIA if magia else T_IDA
	# Los extras TOPAN: 32 impactos de una tormenta no pueden durar cinco segundos. Lo que hacen
	# es encadenarse mas apretados dentro de la misma ventana.
	var extra: float = minf(t_enc * float(n - 1), TOPE_RACHA_MAGIA if magia else TOPE_RACHA)
	var paso: float = extra / maxf(1.0, float(n - 1))
	for i in n:
		_cola[i]["t"] = arranque + paso * float(i)
		_cola[i]["lanzado"] = false
		_cola[i]["fx_lanzado"] = false
	_t = 0.0
	if magia:
		_dur = minf(arranque + T_PUM + extra + T_COLA_MAGIA, TOPE_TOTAL_MAGIA)
	else:
		_dur = minf(arranque + T_PUM + extra + T_VUELTA, TOPE_TOTAL)
	_activa = true
	return _dur


func ocupado() -> bool:
	return _activa


# Deja todo como estaba, YA. La llama _desatascar (tecla P) y el final de la pelea. Como la cola
# no decide turnos, cortarla no puede perder ni duplicar ninguno: se descarta lo que quedaba de
# animacion y punto.
func cancelar() -> void:
	_cola.clear()
	_activa = false
	_t = 0.0
	_dur = 0.0
	for b in _tarjetas:
		_reposo(b)
	for n in _numeros:
		_soltar_numero(n)
	_numeros.clear()
	# Y los rayos y bolas que estuvieran en el aire, o se quedan pintados para siempre.
	if _capa_fx != null and is_instance_valid(_capa_fx):
		_capa_fx.limpiar()
	_saldar_barras()   # los golpes que no se llegaron a ver ya han pasado: la vida, a la real
	_snap_barras()


func diagnostico() -> String:
	return "fx: %d impactos en cola (%.2fs de %.2fs), %d numeros, %d tarjetas" % [
		_cola.size(), _t, _dur, _numeros.size(), _tarjetas.size()]


func _reposo(bloque: Dictionary) -> void:
	var panel: Control = bloque.get("panel")
	if panel == null or not is_instance_valid(panel):
		return
	panel.position = Vector2.ZERO
	panel.scale = Vector2.ONE
	panel.rotation = 0.0
	panel.self_modulate = Color.WHITE


func _process(delta: float) -> void:
	_mover_barras(delta)
	_mover_numeros(delta)
	if not _activa:
		return
	_t += delta

	# Lo que le toca a cada panel ESTE frame. Se acumula en un diccionario y se aplica al final:
	# un mismo atacante puede tener varios impactos solapados y hay que quedarse con uno, no
	# sumarlos (se iria a tomar viento).
	var mov: Dictionary = {}      # panel -> Vector2
	var flash: Dictionary = {}    # panel -> float 0..1
	var punch: Dictionary = {}    # panel -> float 0..1
	var aura: Dictionary = {}     # panel -> [Color, float 0..1]: el brillo del que CANALIZA

	for i in _cola.size():
		var ev: Dictionary = _cola[i]
		var t_imp: float = ev["t"]
		var estilo: int = int(ev.get("estilo", Estilo.MELEE))
		var peso: float = float(ev.get("peso", 1.0))
		var pa: Control = ev["ba"].get("panel") if not ev["ba"].is_empty() else null
		var pv: Control = ev["bv"].get("panel")
		if pv == null or not is_instance_valid(pv):
			continue

		# EL DIBUJO sale ANTES que el golpe, lo que tarde en volar, para que llegue justo a tiempo.
		var vuelo: float = float(T_VUELO.get(estilo, 0.0))
		if not ev["fx_lanzado"] and vuelo > 0.0 and _t >= t_imp - vuelo:
			ev["fx_lanzado"] = true
			if _capa_fx != null:
				_capa_fx.alta(estilo, _punto(ev["ba"]), _punto(ev["bv"]), ev["color"], peso,
					vuelo, _ancho_tarjeta(ev["bv"]))

		# EL IMPACTO: se dispara una vez, justo al cruzar su instante.
		if not ev["lanzado"] and _t >= t_imp:
			ev["lanzado"] = true
			_soltar_numero_de(ev)
			# Y ESTE golpe le quita SU parte a la barra, justo ahora: lo que baja la vida es
			# exactamente el numero que acaba de salir volando.
			_descontar(ev["bv"], float(ev["dmg"]) if not bool(ev["evadido"]) else 0.0)

		# EMBESTIDA del atacante. SOLO EN MELEE: un mago no se lanza contra el bicho para tirarle
		# una bola de fuego, se queda donde esta y lo que viaja es el conjuro. Del 7º golpe en
		# adelante tampoco se mueve nadie: con esa densidad el movimiento se lee como ruido.
		if pa != null and is_instance_valid(pa) and pa != pv \
				and estilo == Estilo.MELEE and i < MAX_IMPACTOS_ANIMADOS:
			var dir: Vector2 = _direccion(pa, pv)
			var d: float = 0.0
			if _t < t_imp and _t >= t_imp - T_IDA:
				# Acelerando (u*u): un lanzamiento arranca despacio y llega lanzado.
				var u: float = (_t - (t_imp - T_IDA)) / T_IDA
				d = DIST_EMBESTIDA * u * u
			elif _t >= t_imp and _t < t_imp + T_VUELTA:
				var u2: float = (_t - t_imp) / T_VUELTA
				d = DIST_EMBESTIDA * (1.0 - u2 * u2)
			if d > 0.0:
				var v: Vector2 = dir * d
				if not mov.has(pa) or v.length() > (mov[pa] as Vector2).length():
					mov[pa] = v

		# CANALIZACION: lo que hace el lanzador en vez de embestir. Su tarjeta se enciende del
		# color del elemento mientras el conjuro esta en el aire. Los de CAIDA no la encienden: de
		# un rayo que cae del cielo no sale nada de tu mano.
		if pa != null and is_instance_valid(pa) and estilo != Estilo.MELEE \
				and estilo != Estilo.CAIDA_RAYO and estilo != Estilo.CAIDA_GOTA \
				and estilo != Estilo.ARCO and _t >= t_imp - vuelo and _t < t_imp:
			var k: float = 1.0 - (t_imp - _t) / maxf(vuelo, 0.001)
			if not aura.has(pa) or k > float(aura[pa][1]):
				aura[pa] = [ev["color"], k]

		# SACUDIDA + FLASH + PUNCH de la victima, desde el instante del golpe.
		# Los de CAIDA pegan mas fuerte y mas rato: un rayo del cielo es un pisoton, no un empujon.
		var cae: bool = estilo == Estilo.CAIDA_RAYO or estilo == Estilo.CAIDA_GOTA
		var t_sac: float = T_SACUDIDA * (1.2 if cae else 1.0)
		if _t >= t_imp and _t < t_imp + t_sac and not bool(ev["evadido"]):
			var u3: float = (_t - t_imp) / t_sac
			# El PESO es lo que hace que el adyacente que come la mitad tiemble la mitad.
			var amp: float = AMP_SACUDIDA * peso * (1.15 if cae else 1.0) \
				* (1.0 - u3) * (1.5 if bool(ev["crit"]) else 1.0)
			# Deterministico y de frecuencias distintas en X e Y: parece un golpe, no una vibracion.
			var s: Vector2 = Vector2(sin(u3 * 71.0), cos(u3 * 53.0)) * amp
			if not mov.has(pv) or s.length() > (mov[pv] as Vector2).length():
				mov[pv] = s
			if _t < t_imp + T_FLASH:
				flash[pv] = 1.0 - (_t - t_imp) / T_FLASH
			var t_punch: float = T_PUM
			if _t < t_imp + t_punch:
				punch[pv] = (1.0 - (_t - t_imp) / t_punch) * peso

	_aplicar(mov, flash, punch, aura)

	if _t >= _dur:
		_activa = false
		_cola.clear()
		_saldar_barras()
		for b in _tarjetas:
			_reposo(b)


# Un frame de animacion sobre los paneles. Los que no participan vuelven a reposo: es lo que
# garantiza que nadie se quede torcido si una racha se corta a medias.
func _aplicar(mov: Dictionary, flash: Dictionary, punch: Dictionary, aura: Dictionary) -> void:
	for b in _tarjetas:
		var panel: Control = b.get("panel")
		if panel == null or not is_instance_valid(panel):
			continue
		panel.position = mov.get(panel, Vector2.ZERO)
		var f: float = flash.get(panel, 0.0)
		# self_modulate y NO modulate: modulate es de _apagar_bloque (el gris del cadaver) y
		# pisarlo resucitaria visualmente a los muertos cada vez que les pegan.
		#
		# El aura del que canaliza se pliega AQUI, en la misma expresion, y no se escribe aparte:
		# esta linea corre cada frame para todas las tarjetas, asi que cualquier otro que tocara
		# self_modulate por su cuenta se lo comeria al frame siguiente.
		var col: Color = Color(1.0 + 0.6 * f, 1.0 + 0.6 * f, 1.0 + 0.6 * f)
		if aura.has(panel):
			col = col.lerp((aura[panel][0] as Color) * 1.35, 0.35 * float(aura[panel][1]))
		panel.self_modulate = col
		var p: float = punch.get(panel, 0.0)
		if p > 0.0:
			panel.pivot_offset = panel.size * 0.5
			panel.scale = Vector2.ONE * (1.0 + 0.06 * p)
			panel.rotation = deg_to_rad(1.5 * p)
		else:
			panel.scale = Vector2.ONE
			panel.rotation = 0.0


# El centro de una tarjeta en coordenadas de la capa de efectos. Si el bloque esta vacio (un
# hechizo que "cae del cielo" no tiene tarjeta de origen) devuelve un punto por encima del techo,
# que es justo de donde tiene que venir.
func _punto(bloque: Dictionary) -> Vector2:
	if bloque.is_empty() or capa_numeros == null or not is_instance_valid(capa_numeros):
		return Vector2.ZERO
	var p: Control = bloque.get("panel")
	if p == null or not is_instance_valid(p):
		return Vector2.ZERO
	return p.get_global_rect().get_center() - capa_numeros.global_position


func _ancho_tarjeta(bloque: Dictionary) -> float:
	var p: Control = bloque.get("panel")
	if p == null or not is_instance_valid(p):
		return 120.0
	return p.size.x


# Hacia donde se lanza el que pega. La horizontal sale de los centros reales de las dos tarjetas;
# la vertical es fija por bando (los enemigos van arriba y tu abajo), porque dos tarjetas de la
# MISMA fila estan a la misma altura y sin esto un golpe entre vecinos no se veria ir a ningun sitio.
func _direccion(pa: Control, pv: Control) -> Vector2:
	var ca: Vector2 = pa.get_global_rect().get_center()
	var cv: Vector2 = pv.get_global_rect().get_center()
	var d: Vector2 = cv - ca
	if d.length() < 1.0:
		return Vector2.DOWN
	return d.normalized()


# ============================================================
#  NUMEROS FLOTANTES
# ============================================================

func _soltar_numero_de(ev: Dictionary) -> void:
	if capa_numeros == null or not is_instance_valid(capa_numeros):
		return
	var pv: Control = ev["bv"].get("panel")
	if pv == null or not is_instance_valid(pv):
		return
	var crit: bool = bool(ev["crit"])
	var evadido: bool = bool(ev["evadido"])
	var lbl: Label = _coger_numero()
	if evadido:
		lbl.text = "FALLA"
		lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
		lbl.add_theme_font_size_override("font_size", 18)
	else:
		# Con DOS DECIMALES, igual que el log y que los numeros de dentro de las barras: si el
		# numero que vuela dice 134 y la barra dice 134.42, parecen dos cuentas distintas.
		lbl.text = "%.2f" % maxf(float(ev["dmg"]), 0.0)
		if crit:
			lbl.text += "!"
		lbl.add_theme_color_override("font_color", ev["color"])
		lbl.add_theme_font_size_override("font_size", 28 if crit else 19)

	# El sitio: DENTRO de la tarjeta que lo come, en su tercio alto, no pegado a su borde de
	# arriba. La fila de enemigos esta casi tocando el techo de la pantalla, asi que naciendo en
	# el borde y subiendo 26 px, sus numeros se salian por arriba y no se leian.
	var r: Rect2 = pv.get_global_rect()
	var base: Vector2 = r.get_center() - capa_numeros.global_position
	base.y = (r.position.y + r.size.y * 0.34) - capa_numeros.global_position.y

	# Que una racha no se lea como un borron: cada numero sobre la MISMA tarjeta baja un poco y
	# se aparta en zigzag, asi ocho golpes seguidos quedan en escalerilla y se pueden contar.
	var seq: int = int(ev["bv"].get("fx_num_seq", 0))
	ev["bv"]["fx_num_seq"] = seq + 1
	base.y += 12.0 * float(seq % 5)
	base.x += 14.0 * (1.0 if seq % 2 == 0 else -1.0) * float((seq % 4) / 2 + 1)
	# Y por si acaso: ninguno puede nacer tan arriba que al subir se salga de la pantalla. Es el
	# cinturon para las tarjetas cortas y para las resoluciones bajas.
	base.y = maxf(base.y, SUBIDA_NUMERO + 8.0)

	lbl.position = base - Vector2(60, 24)
	lbl.modulate.a = 1.0
	lbl.scale = Vector2.ONE
	lbl.visible = true
	_numeros.append({"lbl": lbl, "t": -(RETRASO_CRIT if crit else 0.0),
		"x": lbl.position.x, "y": lbl.position.y, "crit": crit})
	# Techo: si se pasa, el mas viejo se recicla en vez de dejar la pantalla llena.
	while _numeros.size() > MAX_NUMEROS:
		_soltar_numero(_numeros.pop_front())


func _mover_numeros(delta: float) -> void:
	var i: int = _numeros.size() - 1
	while i >= 0:
		var n: Dictionary = _numeros[i]
		n["t"] = float(n["t"]) + delta
		var t: float = n["t"]
		var lbl: Label = n["lbl"]
		if not is_instance_valid(lbl):
			_numeros.remove_at(i)
			i -= 1
			continue
		if t < 0.0:
			lbl.visible = false   # el critico espera un pelin a que se lea el impacto
			i -= 1
			continue
		lbl.visible = true
		var u: float = t / T_NUMERO
		if u >= 1.0:
			_soltar_numero(n)
			_numeros.remove_at(i)
			i -= 1
			continue
		# Sube frenando (1-(1-u)^2) y se apaga en el ultimo tercio.
		lbl.position = Vector2(n["x"], float(n["y"]) - SUBIDA_NUMERO * (1.0 - pow(1.0 - u, 2.0)))
		lbl.modulate.a = 1.0 if u < 0.65 else (1.0 - (u - 0.65) / 0.35)
		if bool(n["crit"]) and u < 0.18:
			var k: float = 1.0 - u / 0.18
			lbl.scale = Vector2.ONE * (1.0 + 0.3 * k)
		else:
			lbl.scale = Vector2.ONE
		i -= 1


# Los Labels se RECICLAN, nunca se liberan en caliente: en una racha de area se crearian y
# destruirian 25 nodos en medio segundo.
func _coger_numero() -> Label:
	if not _pool.is_empty():
		var l: Label = _pool.pop_back()
		if is_instance_valid(l):
			return l
	var lbl := Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.process_mode = Node.PROCESS_MODE_ALWAYS
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(120, 0)
	lbl.size = Vector2(120, 48)
	lbl.pivot_offset = Vector2(60, 24)
	# Contorno negro: sin el, un numero claro sobre la tarjeta clara no se lee. Mismo apaño que
	# los numeros de dentro de las barras (_crear_label_barra).
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 4)
	capa_numeros.add_child(lbl)
	return lbl


func _soltar_numero(n: Dictionary) -> void:
	var lbl: Label = n.get("lbl")
	if lbl != null and is_instance_valid(lbl):
		lbl.visible = false
		_pool.append(lbl)
