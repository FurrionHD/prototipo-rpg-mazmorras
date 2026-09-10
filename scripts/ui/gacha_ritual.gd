# ============================================================
#  gacha_ritual.gd  --  LA ANIMACION PREVIA de la Meditacion.
#
#  Lo que se ve antes de que se voltee la primera carta, y es el equivalente de la animacion de
#  invocacion de cualquier gacha: el momento en que ya no puedes hacer nada y solo miras.
#
#  LAS CINCO FASES, tal y como se pidieron:
#    1. Una estanteria. El maestro entra POR ABAJO y se acerca a ella (de espaldas: se aleja de la
#       camara, que es lo que dice "va hacia el fondo" sin mover el fondo).
#    2. Estira el brazo y saca un tomo del hueco.
#    3. Se da la vuelta y lo enseña.
#    4. El tomo se acerca a la pantalla creciendo, se abre y le pasan las paginas.
#    5. Y empieza a brillar DEL COLOR DE LO MEJOR QUE HA SALIDO en la tirada.
#
#  LA QUINTA ES LA UNICA QUE IMPORTA MECANICAMENTE, y por eso el color entra al final y no antes: es
#  la unica informacion que da esta pantalla. El jugador aprende en dos tiradas que el morado pica y
#  el naranja es la buena, y a partir de ahi la animacion deja de ser un adorno y pasa a ser la parte
#  que se mira con la boca seca. Si el color saliera desde el primer fotograma, las cuatro fases de
#  antes sobrarian.
#
#  SE SALTA CON UN CLIC, entero. Son casi seis segundos y se van a ver cientos de veces; un gacha que
#  no deja saltar la animacion se odia a la tercera tirada.
#
#  EL COLOR NO SE DECIDE AQUI. Se lo pasa quien la lanza, ya resuelto (ver maestro_menu). Esta
#  pantalla no sabe lo que es una rareza ni un grimorio: recibe un color y una llamada para cuando
#  termine, y con eso le basta. Asi el dia que haya un banner de otra cosa, esto no se toca.
#
#  Y EL Z, que es la trampa de siempre con los muñecos (ver la nota de gacha_banner.montar y la de
#  character_menu._ver_muneco): MunecoJugador dibuja sus capas con z ABSOLUTO de hasta 2051, asi que
#  se cuela por delante de cualquier Control de z 0 -- pero tambien queda POR DEBAJO de cualquier
#  Control al que se le suba el z para taparlo. O sea que no se puede poner un velo por encima de los
#  retratos Y que el maestro se vea encima del velo. La unica salida es la que ya usa la ficha de
#  personaje: ESCONDER los otros muñecos mientras dura esto, y quedarse en z 0.
#     velo y estanteria -> z 0        (tapan el menu, que va detras en el arbol)
#     el maestro        -> z 2047..2051 absoluto, o sea encima de ellos
#     el tomo y su luz  -> z 2600, o sea encima del maestro
# ============================================================

extends Control

# --- LOS TIEMPOS, en segundos ---
# Suman 5,7. Se ha probado mas largo y la animacion empieza a pesar justo donde tiene que tirar: lo
# que se alarga no es la espera buena (el brillo) sino el paseo, que solo cuenta la primera vez.
const T_ACERCA := 1.5
const T_BRAZO := 0.8
const T_GIRA := 0.7
const T_ZOOM := 1.4
const T_BRILLO := 1.3

# El color con el que arranca el brillo: un blanco de vela, deliberadamente NEUTRO. Es el que tiene
# que no decir nada todavia.
const LUZ_VELA := Color(1.0, 0.94, 0.80)

# --- La escena, en unidades logicas de 1280x720 (ver project.godot) ---
const SUELO_Y := 470.0
const ESTANTE_X := 640.0
const ESTANTE_ANCHO := 560.0
const ESTANTE_ARRIBA := 80.0
const BALDAS := 4
# EL HUECO del que sale el tomo: la balda de ABAJO, y a la izquierda del centro.
#
# LA DE ABAJO PORQUE ES LA QUE ALCANZA. Estuvo en la tercera y el tomo salia cien pixeles por encima
# de la mano: se veia al maestro estirar el brazo y al libro aparecer muy por encima, o sea dos cosas
# a la vez en vez de una. Un gesto y su consecuencia tienen que tocarse en pantalla.
#
# Y A UN LADO PARA QUE EL MAESTRO NO LO TAPE: plantado delante, su propio cuerpo cubre el hueco justo
# cuando hay que verlo vacio. Se coloca EL a la misma x (ver _maestro_x), asi que el brazo sale hacia
# arriba y el tomo aparece justo encima -- no cruzando la pantalla en diagonal.
const HUECO_BALDA := 3
const HUECO_X := 0.34      # fraccion del ancho de la estanteria, desde su izquierda
const HUECO_ANCHO := 26.0  # lo ancho que es el vacio, en unidades logicas

# Lo que mide el maestro en pantalla. El muñeco ocupa ALTO_MUNDO por encima de su origen y
# PIES_BAJO_NODO por debajo (los pies), asi que la escala se calcula contra las dos cosas o la figura
# queda cortada por los tobillos -- misma cuenta que character_menu._muneco_grande.
const MAESTRO_ALTO := 320.0

var _color: Color = Color.WHITE
# Los dos nombres que llegan ya resueltos (ver montar), y por donde va la banda sonora: 0 = aun no
# ha sonado nada, 1 = la estanteria, 2 = las paginas, 3 = el brillo. Un contador y no tres banderas
# porque las fases van en orden y lo unico que hay que saber es por cual se va.
var _sfx_brillo: String = ""
var _mus_final: String = ""
var _hito: int = 0
var _al_acabar: Callable = Callable()
var _t: float = 0.0
var _acabado: bool = false
var _mu: MunecoJugador = null
var _fondo: Control = null
var _frente: Control = null
# Lo que se esconde mientras dura esto y hay que volver a enseñar al terminar (ver la nota del z).
var _tapados: Array = []


# ============================================================
#  EL MAESTRO
# ============================================================
# QUIEN ES, en un solo sitio. Es un PersonajeData de mentira -- no esta en la plantilla, no tiene
# stats y no se guarda --: aqui solo se usa como bolsa de aspecto, que es lo unico que MunecoJugador
# necesita para montar sus capas.
#
# El aspecto lo eligio el en el creador, pieza por pieza: tunica y faldon azules, sombrero de mago
# del mismo azul, y pelo largo y barba larga en gris. El sombrero y la barba son justo las dos piezas
# que se hicieron PARA esto (ver la memoria de barbas y gorros): un viejo con sombrero picudo se
# reconoce a cuarenta pixeles, que es lo que hace falta cuando la figura entra andando de espaldas.
const AZUL := Color(0.451, 0.722, 1.0)
const CANAS := Color(0.49, 0.49, 0.49)

static func maestro() -> PersonajeData:
	var pj := PersonajeData.new()
	pj.nombre = "Maestro"
	pj.color = AZUL
	pj.aspecto = PersonajeData.aspecto_nuevo(AZUL)
	pj.poner_pieza("torso", "tunica", AZUL)
	pj.poner_pieza("piernas", "faldon", AZUL)
	pj.poner_pieza("gorro", "mago", AZUL)
	pj.poner_pieza("pelo", "largo", CANAS)
	pj.poner_pieza("barba", "larga", CANAS)
	pj.poner_pieza("cara", "linea", CANAS)
	return pj


# ============================================================
#  MONTAR
# ============================================================
# 'color' es el de lo mejor que ha salido; 'al_acabar' se llama UNA sola vez, al terminar o al
# saltarsela.
func montar(padre: Control, color: Color, al_acabar: Callable,
		sfx_brillo: String = "", mus_final: String = "") -> void:
	_color = color
	_al_acabar = al_acabar
	# EL SONIDO DEL BRILLO Y EL REMATE LLEGAN RESUELTOS, igual que el color y por el mismo motivo:
	# esta pantalla no sabe lo que es una rareza (ver la cabecera). Recibe un color, dos nombres y
	# una llamada para cuando termine, y con eso le basta.
	_sfx_brillo = sfx_brillo
	_mus_final = mus_final
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	padre.add_child(self)

	# EL VELO. Se come los clics ademas de tapar: sin el se puede volver a pulsar "Meditar" a traves
	# de la animacion, que es gastarse otras 2.000 monedas sin haber visto lo que salio.
	var velo := ColorRect.new()
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	velo.color = Color(0.03, 0.03, 0.05, 1.0)
	velo.mouse_filter = Control.MOUSE_FILTER_STOP
	velo.gui_input.connect(_pulsado)
	add_child(velo)

	_fondo = Control.new()
	_fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fondo)
	_fondo.draw.connect(_dibujar_fondo)

	_montar_maestro()

	# EL FRENTE va POR ENCIMA DEL MUÑECO (2051 es su capa mas alta) y por eso lleva z propio: aqui
	# viven el tomo y su luz, que en la ultima fase se comen la pantalla entera.
	_frente = Control.new()
	_frente.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frente.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frente.z_index = 2600
	add_child(_frente)
	_frente.draw.connect(_dibujar_frente)

	set_process(true)


# Esconde los Controles que traigan muñecos dentro. Ver la nota del z de la cabecera: no es que
# molesten, es que no hay forma de taparlos sin tapar tambien al maestro.
func tapar(quien: Array) -> void:
	for c in quien:
		if c != null and is_instance_valid(c) and c.visible:
			c.visible = false
			_tapados.append(c)


func _exit_tree() -> void:
	for c in _tapados:
		if c != null and is_instance_valid(c):
			c.visible = true
	_tapados.clear()


func _montar_maestro() -> void:
	var pj: PersonajeData = maestro()
	_mu = MunecoJugador.new()
	_mu.montar(pj)
	_mu.tenir(pj.color, 0.0)
	if not _mu.hay_dibujo():
		# Sin atlas horneados no hay animacion que valga: se va directa al revelado en vez de
		# enseñar una habitacion vacia. Es la misma red que tiene character_menu.
		_mu.queue_free()
		_mu = null
		return
	_mu.scale = Vector2.ONE * (MAESTRO_ALTO
		/ (PoseJugador.ALTO_MUNDO + PoseJugador.PIES_BAJO_NODO))
	add_child(_mu)
	_mu.animar("walk_4")


# ============================================================
#  EL RELOJ
# ============================================================
func _process(delta: float) -> void:
	_t += delta
	_sonar_si_toca()
	if _mu != null and is_instance_valid(_mu):
		_colocar_maestro()
	if _fondo != null:
		_fondo.queue_redraw()
	if _frente != null:
		_frente.queue_redraw()
	if _t >= duracion():
		_terminar()


# LA BANDA SONORA, colgada del mismo reloj que dibuja. Tres momentos y en este orden:
#   1. la estanteria y los pasos, en cuanto arranca
#   2. las paginas, cuando el tomo se viene encima (fase 4)
#   3. el brillo y el remate de la musica, cuando vira el color (fase 5)
#
# VA EN _process Y NO EN UN TWEEN a proposito: aqui el reloj es _t, y el visor puede clavarlo
# (plantar) o correrlo a otra velocidad. Colgado de _t, el sonido acompaña siempre a lo que se ve;
# con tiempos propios, en el visor a media velocidad se oiria el brillo con el maestro aun andando.
#
# Y por eso mismo un salto (clic o Esc) no dispara nada de lo que faltaba: quien se la salta no
# quiere oir el final, quiere ver las cartas.
func _sonar_si_toca() -> void:
	if _hito == 0:
		_hito = 1
		Sonido.ui("gacha_estante")
	if _hito == 1 and _t >= T_ACERCA + T_BRAZO + T_GIRA:
		_hito = 2
		Sonido.ui("gacha_paginas")
	if _hito == 2 and _t >= T_ACERCA + T_BRAZO + T_GIRA + T_ZOOM:
		_hito = 3
		if _sfx_brillo != "":
			Sonido.ui(_sfx_brillo)
		# EL REMATE Y NO UN CAMBIO DE PISTA: un remate suena ENCIMA del fondo y se va solo, asi que
		# la base del ritual sigue por debajo mientras el color vira. Cambiando la cima, la base se
		# cortaria justo en el momento que tiene que sostener.
		if _mus_final != "":
			Musica.remate(_mus_final)


# Saltarsela desde fuera (Esc). Es la misma puerta que el clic: no cancela nada, adelanta el final.
func saltar() -> void:
	_terminar()


# CLAVA EL RELOJ en un instante concreto, para el visor. Es lo mismo que MunecoJugador.fijar y existe
# por el mismo motivo: una animacion de seis segundos no se puede juzgar esperandola: hay que poder
# plantarse en el fotograma que interesa y sacarle una foto. Y sin esto la unica forma de fotografiar
# la fase del brillo seria dejar correr el visor cinco segundos y confiar en el momento en que cae la
# captura, que es como no comprobar nada.
#
# LLEVAR EL RELOJ DE FUERA APAGA EL DE DENTRO. Quien conduzca esto tiene que hacer set_process(false)
# sobre la capa, o los dos reloj es avanzan a la vez y la animacion va al doble de velocidad -- un
# fallo que no da ningun error y que en un visor se lee como "esto va demasiado rapido", que es
# justo lo que uno ha venido a juzgar.
func plantar(t: float) -> void:
	_t = clampf(t, 0.0, duracion())
	if _mu != null and is_instance_valid(_mu):
		_colocar_maestro()
	if _fondo != null:
		_fondo.queue_redraw()
	if _frente != null:
		_frente.queue_redraw()
	if _t >= duracion():
		_terminar()


func reloj() -> float:
	return _t


# Cuanto dura entera. La necesita el visor para repartir sus fotos, y asi los tiempos siguen viviendo
# en un solo sitio: sumarlos alli seria la clase de copia que se queda desfasada al tocar una fase.
func duracion() -> float:
	return T_ACERCA + T_BRAZO + T_GIRA + T_ZOOM + T_BRILLO


func _pulsado(e: InputEvent) -> void:
	# Solo el boton PULSADO: un clic manda dos eventos (abajo y arriba) y con los dos se saltaria
	# ademas la primera carta del revelado, que es justo la que se ha pagado por ver.
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		get_viewport().set_input_as_handled()
		_terminar()


func _terminar() -> void:
	# UNA SOLA VEZ. Al saltarsela justo en el ultimo fotograma entrarian por aqui el clic y el reloj,
	# y el revelado se montaria dos veces (la segunda encima de la primera, con sus tweens).
	if _acabado:
		return
	_acabado = true
	set_process(false)
	if not _al_acabar.is_valid():
		return
	# DIFERIDO, y no en seco. Quien escucha es el menu, y lo primero que hace es DESTRUIR ESTA CAPA:
	# llamarlo desde dentro de _process o del manejador del clic seria sacarse a uno mismo del arbol
	# a mitad de su propio fotograma. Un frame de retraso no se ve y quita el unico camino por el que
	# esto podia reventar, que ademas es el que acaba de cobrar 2.000 monedas.
	_al_acabar.call_deferred()


# ============================================================
#  DONDE ESTA EL MAESTRO EN CADA MOMENTO
# ============================================================
# Devuelve 0..1 dentro de una fase, y por debajo/encima si aun no ha llegado o ya paso. Tenerlo en un
# sitio evita la cadena de 'if _t < a elif _t < a+b' repetida en cada dibujo, que es donde se cuela
# que una fase empiece medio fotograma antes en un sitio que en otro.
func _fase(desde: float, dura: float) -> float:
	return clampf((_t - desde) / maxf(0.001, dura), 0.0, 1.0)


# DONDE SE PLANTA EL MAESTRO. A la misma x que el hueco: asi el brazo sale hacia arriba y el tomo
# aparece justo encima de la mano. Es UNA cuenta y no dos porque en cuanto se separen, el gesto y el
# libro dejan de tocarse -- que es lo que ya paso una vez.
func _maestro_x() -> float:
	return _hueco_pos().x


func _colocar_maestro() -> void:
	var w: float = size.x
	var h: float = size.y
	var x: float = _maestro_x()
	# ENTRA POR ABAJO, desde fuera del encuadre: empieza por debajo del borde y sube hasta el pie de
	# la estanteria. 'ease out' porque quien llega a un sitio frena, y porque el frenazo es lo que
	# hace que se lea "ha llegado" sin necesidad de una pausa.
	var a: float = _fase(0.0, T_ACERCA)
	var pies: float = lerpf(h + MAESTRO_ALTO * 0.5, h * (SUELO_Y / 720.0) + 128.0,
		1.0 - pow(1.0 - a, 2.0))
	_mu.position = Vector2(x, pies)

	if _t < T_ACERCA:
		_mu.animar("walk_4")
		return
	var b: float = _fase(T_ACERCA, T_BRAZO)
	if b < 1.0:
		# ESTIRAR EL BRAZO ES MEDIO GOLPE. No hay animacion de "alcanzar" y no hacia falta inventarla:
		# la primera mitad de 'golpe' es exactamente eso -- el brazo que sale --, y la segunda es la
		# vuelta. Se conduce a mano con 'fijar' en vez de dejarla correr, que es para lo que existe:
		# asi va al ritmo de ESTA fase y se queda quieta arriba en vez de recogerse.
		_mu.fijar("golpe_4", int(round(b * 4.0)))
		return
	if _t < T_ACERCA + T_BRAZO + T_GIRA:
		# SE DA LA VUELTA. Con las ocho direcciones horneadas, "girarse" es cambiar de animacion: 4 es
		# el norte (de espaldas) y 0 el sur (de cara), y por en medio se pasa por el 5 y el 6 para que
		# el giro tenga sentido de rotacion en vez de ser un corte.
		var g: float = _fase(T_ACERCA + T_BRAZO, T_GIRA)
		var pasos: Array = [5, 6, 7, 0]
		_mu.animar("idle_%d" % int(pasos[mini(int(g * float(pasos.size())), pasos.size() - 1)]))
		return
	_mu.animar("idle_0")
	# En el zoom se aparta hacia abajo y se apaga: lo que manda ya es el libro.
	var z: float = _fase(T_ACERCA + T_BRAZO + T_GIRA, T_ZOOM)
	_mu.modulate = Color(1, 1, 1, 1.0 - z)


# ============================================================
#  EL FONDO: la estanteria
# ============================================================
# Dibujada por codigo como el resto del arte del juego. Lo que tiene que decir es "biblioteca" en un
# vistazo y a media luz, asi que son tres cosas: las baldas, los lomos apretados y un HUECO.
#
# EL HUECO ES LA PIEZA QUE CUENTA LA HISTORIA. Sin el, sacar el tomo es un objeto que aparece de la
# nada delante de una pared decorada; con el, se ve de donde ha salido y el sitio se queda vacio
# despues. Es lo mismo que hace la escalera de un piso: el agujero explica el movimiento.
func _dibujar_fondo() -> void:
	var c: Control = _fondo
	var w: float = c.size.x
	var h: float = c.size.y
	var ux: float = w / 1280.0
	var uy: float = h / 720.0
	var suelo: float = SUELO_Y * uy
	var ex: float = ESTANTE_X * ux
	var ea: float = ESTANTE_ANCHO * ux
	var earr: float = ESTANTE_ARRIBA * uy

	# LA PARED Y EL SUELO. Dos bandas y un degradado corto en la union: a media luz eso basta para
	# que se lea una habitacion y no un fondo plano.
	c.draw_rect(Rect2(Vector2(0, 0), Vector2(w, suelo)), Color(0.07, 0.065, 0.085), true)
	c.draw_rect(Rect2(Vector2(0, suelo), Vector2(w, h - suelo)), Color(0.10, 0.085, 0.075), true)
	for i in 8:
		var t: float = float(i) / 8.0
		c.draw_rect(Rect2(Vector2(0, suelo + t * 26.0 * uy), Vector2(w, 26.0 * uy / 8.0 + 1.0)),
			Color(0.0, 0.0, 0.0, 0.10 * (1.0 - t)), true)

	# EL RESPLANDOR DE LA VELA, detras de la estanteria. Es lo que separa "de noche en una biblioteca"
	# de "en negro": sin una fuente de luz, una habitacion oscura se lee como un fallo de dibujo.
	var luz := Vector2(ex, earr + (suelo - earr) * 0.45)
	for i in range(9, 0, -1):
		var t2: float = float(i) / 9.0
		c.draw_circle(luz, 60.0 * ux + t2 * 340.0 * ux,
			Color(LUZ_VELA.r, LUZ_VELA.g, LUZ_VELA.b, 0.020 * (1.0 - t2) + 0.004))

	var izq: float = ex - ea * 0.5
	var alto: float = suelo - earr
	# EL MUEBLE: la caja, los montantes y las baldas.
	c.draw_rect(Rect2(Vector2(izq, earr), Vector2(ea, alto)), Color(0.11, 0.085, 0.070), true)
	var borde := Color(0.20, 0.15, 0.11)
	c.draw_rect(Rect2(Vector2(izq, earr), Vector2(ea, alto)), borde, false, maxf(2.0, 3.0 * ux))
	var balda_h: float = alto / float(BALDAS)
	for i in range(1, BALDAS + 1):
		var y: float = earr + balda_h * float(i)
		c.draw_rect(Rect2(Vector2(izq, y - 4.0 * uy), Vector2(ea, 5.0 * uy)), borde, true)

	# LOS LOMOS. Anchos, altos y colores DETERMINISTAS (salen del indice, no de un RandomNumber-
	# Generator): con azar de verdad la estanteria cambiaria en cada fotograma y lo que se veria es
	# una pared parpadeando. Es la misma razon por la que el terreno siembra por coordenada.
	for balda in BALDAS:
		var base_y: float = earr + balda_h * float(balda + 1) - 4.0 * uy
		var x: float = izq + 8.0 * ux
		var n: int = 0
		while x < izq + ea - 12.0 * ux:
			var k: int = balda * 31 + n * 7
			var ancho: float = (7.0 + float((k * 13) % 9)) * ux
			var lomo_h: float = balda_h * (0.52 + float((k * 17) % 5) * 0.07)
			# EL HUECO: en esta balda y en este sitio no hay libro. Es de donde sale el tomo.
			#
			# SE DECIDE POR POSICION Y NO POR NUMERO DE LOMO. Estuvo puesto "el quinto de la balda" y
			# el sitio del hueco dependia entonces de los anchos aleatorios de los cuatro anteriores:
			# el tomo salia de donde saliera, y para saber de donde habia que repetir esa suma en otro
			# sitio. Ahora la x del hueco es un dato (HUECO_X) y el dibujo se limita a saltarse los
			# lomos que caen encima.
			var hx: float = _hueco_pos().x
			var ha: float = HUECO_ANCHO * ux
			var vacio: bool = balda == HUECO_BALDA \
				and x + ancho > hx - ha * 0.5 and x < hx + ha * 0.5
			if not vacio:
				var tono: float = 0.30 + float((k * 11) % 7) * 0.045
				var col := Color(tono * (0.7 + float((k * 5) % 4) * 0.12),
					tono * (0.55 + float((k * 3) % 5) * 0.09), tono * 0.55)
				c.draw_rect(Rect2(Vector2(x, base_y - lomo_h), Vector2(ancho - 2.0 * ux, lomo_h)),
					col, true)
				# Los dos filetes del lomo. A este tamaño son dos rayas, y son lo unico que separa
				# "libros" de "una fila de rectangulos de colores".
				var cl := Color(col.r * 1.5 + 0.08, col.g * 1.5 + 0.08, col.b * 1.5 + 0.08, 0.7)
				c.draw_line(Vector2(x + 1.0 * ux, base_y - lomo_h * 0.82),
					Vector2(x + ancho - 3.0 * ux, base_y - lomo_h * 0.82), cl, maxf(1.0, ux), true)
				c.draw_line(Vector2(x + 1.0 * ux, base_y - lomo_h * 0.18),
					Vector2(x + ancho - 3.0 * ux, base_y - lomo_h * 0.18), cl, maxf(1.0, ux), true)
			x += ancho
			n += 1


# DONDE ESTA EL HUECO EN PANTALLA. Lo necesitan el fondo (para dejarlo vacio) y el tomo (para salir
# de ahi), asi que se calcula UNA vez y en un solo sitio: con la cuenta duplicada, mover la
# estanteria dejaria el libro saliendo de una balda que no es.
func _hueco_pos() -> Vector2:
	var w: float = size.x
	var h: float = size.y
	var ux: float = w / 1280.0
	var uy: float = h / 720.0
	var suelo: float = SUELO_Y * uy
	var earr: float = ESTANTE_ARRIBA * uy
	var balda_h: float = (suelo - earr) / float(BALDAS)
	var izq: float = w * 0.5 - ESTANTE_ANCHO * ux * 0.5
	return Vector2(izq + ESTANTE_ANCHO * ux * HUECO_X,
		earr + balda_h * float(HUECO_BALDA + 1) - balda_h * 0.36)


# ============================================================
#  EL FRENTE: el tomo y su luz
# ============================================================
func _dibujar_frente() -> void:
	var c: Control = _frente
	var w: float = c.size.x
	var h: float = c.size.y
	if _t < T_ACERCA:
		return   # todavia esta andando: el tomo esta en la balda, dibujado como un lomo mas

	var hueco: Vector2 = _hueco_pos()
	# EL DESTINO DEL ZOOM: el centro de la pantalla, que es donde el libro se come el encuadre. Un
	# pelo por encima del centro geometrico porque debajo va a crecer el halo, y centrado del todo el
	# conjunto se lee bajo.
	var centro := Vector2(w * 0.5, h * 0.47)
	var b: float = _fase(T_ACERCA, T_BRAZO)
	var g: float = _fase(T_ACERCA + T_BRAZO, T_GIRA)
	var z: float = _fase(T_ACERCA + T_BRAZO + T_GIRA, T_ZOOM)
	var br: float = _fase(T_ACERCA + T_BRAZO + T_GIRA + T_ZOOM, T_BRILLO)

	# EL RECORRIDO. Del hueco a la mano (mientras estira el brazo), de la mano al pecho (mientras se
	# gira) y del pecho a la camara (el zoom). Tres tramos y ninguna curva: lo que da la sensacion de
	# peso es el frenado de cada tramo, no la trayectoria.
	# LOS DOS PUNTOS DE EN MEDIO VAN PEGADOS AL MAESTRO, no a la pantalla. Estuvieron escritos como
	# fracciones del alto (h * 0,50 y h * 0,44) y ahi caia LA ESTANTERIA, no el: el libro salia del
	# hueco, se quedaba dentro del mueble y el zoom no tenia de donde arrancar, asi que las tres fases
	# se veian como una sola. La regla: lo que le pasa a un personaje se ancla al personaje.
	var suelo_y: float = h * (SUELO_Y / 720.0) + 128.0     # los pies, igual que en _colocar_maestro
	var mano := Vector2(_maestro_x(), hueco.y + 34.0 * (h / 720.0))
	# 0,34 DEL ALTO Y NO 0,56: este muñeco es cabezon a proposito (la cabeza se lleva el 43% de la
	# figura, ver PoseJugador), asi que "un poco por debajo de la mitad" cae dentro de la CARA. Con
	# 0,56 el tomo quedaba flotando a la altura del ala del sombrero y no parecia que lo sujetara
	# nadie. El pecho de este cuerpo esta mucho mas abajo de lo que dice la intuicion.
	var pecho := Vector2(_maestro_x(), suelo_y - MAESTRO_ALTO * 0.30)
	var pos: Vector2 = hueco.lerp(mano, 1.0 - pow(1.0 - b, 2.0))
	if b >= 1.0:
		pos = mano.lerp(pecho, g)
	if g >= 1.0:
		pos = pecho.lerp(centro, 1.0 - pow(1.0 - z, 3.0))

	# EL TAMAÑO. De lomo a tomo en la mano, y de ahi a comerse media pantalla. El salto gordo va con
	# una curva de aceleracion (pow 3) para que el acercamiento tenga inercia: lineal se lee como un
	# objeto que crece, y con inercia como un objeto que VIENE.
	var lado: float = lerpf(34.0, 64.0, b)
	if g >= 1.0:
		lado = lerpf(64.0, minf(w, h) * 0.46, pow(z, 2.4))

	# LA LUZ, DEBAJO DEL LIBRO. Arranca en blanco de vela y solo en la ultima fase se va al color de
	# lo mejor de la tirada: ESE viraje es toda la informacion que da esta pantalla, asi que no puede
	# empezar antes ni llegar antes de tiempo. Ver la cabecera.
	var col: Color = LUZ_VELA.lerp(_color, pow(br, 1.6))
	var fuerza: float = z * 0.35 + br * 1.0
	if fuerza > 0.01:
		# El latido: un temblor pequeño y rapido. Sin el, un circulo que crece se lee como una
		# transicion de interfaz; con el, como algo que esta a punto de soltarse.
		var late: float = 1.0 + sin(_t * 11.0) * 0.035 * br
		for i in range(12, 0, -1):
			var t: float = float(i) / 12.0
			c.draw_circle(pos, lado * (0.55 + t * 1.35) * late,
				Color(col.r, col.g, col.b, 0.09 * (1.0 - t) * fuerza))

	_dibujar_tomo(c, pos, lado, col, z, br)

	# EL FOGONAZO FINAL, encima de todo: la pantalla se lava del color justo antes de que entren las
	# cartas. Es lo que corta la animacion en seco en vez de dejarla apagarse, y ademas TAPA EL CORTE
	# -- el revelado entra sobre blanco y no sobre una biblioteca que desaparece de golpe.
	if br > 0.72:
		var f: float = (br - 0.72) / 0.28
		c.draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)),
			Color(col.r, col.g, col.b, f * f * 0.85), true)


# EL TOMO. Cerrado mientras va del hueco a la mano; abierto durante el zoom, con las paginas pasando.
#
# UN LIBRO ABIERTO NO ES DOS RECTANGULOS: lo que se lee como "abierto" son las dos tapas INCLINADAS
# hacia dentro (o sea dos trapecios que se estrechan hacia el lomo) y la V del centro. Con dos
# rectangulos rectos sale una carpeta.
func _dibujar_tomo(c: Control, pos: Vector2, lado: float, col: Color, abre: float,
		br: float) -> void:
	var w: float = lado * 0.78
	var hh: float = lado
	var oscuro := Color(0.16, 0.13, 0.11)
	var tapa := Color(col.r * 0.42 + 0.08, col.g * 0.42 + 0.06, col.b * 0.42 + 0.06)
	var claro := Color(col.r, col.g, col.b, 0.95)

	if abre < 0.02:
		# CERRADO: la tapa con su emblema. Es el mismo lenguaje que la carta del cartel (el rombo),
		# para que se lea como el mismo objeto cuando aparezcan las cartas dos segundos despues.
		var r := Rect2(pos - Vector2(w, hh) * 0.5, Vector2(w, hh))
		c.draw_rect(r, tapa, true)
		c.draw_rect(r, claro, false, maxf(1.0, lado * 0.03))
		_rombo(c, pos, lado * 0.16, claro)
		return

	# ABIERTO. 'abre' separa las dos hojas; el lomo se queda en el centro.
	var ap: float = clampf(abre * 1.6, 0.0, 1.0)
	# CUANTO SE ABRE CADA HOJA. Estuvo en 0,72 y el libro salia MAS ANCHO QUE ALTO casi el doble: un
	# tomo abierto de par en par se lee como un periodico. Con 0,45 las dos hojas juntas miden ~1,5
	# veces el alto, que es la proporcion de un libro de verdad abierto.
	var media: float = w * (0.5 + ap * 0.45)
	var alto2: float = hh * 0.5
	var pliegue: float = hh * 0.06 * ap     # la V del centro: las hojas caen hacia el lomo
	for s in [-1.0, 1.0]:
		# El trapecio de una hoja: alto entero por fuera, un poco menos pegado al lomo.
		var hoja := PackedVector2Array([
			pos + Vector2(0.0, -alto2 + pliegue),
			pos + Vector2(s * media, -alto2),
			pos + Vector2(s * media, alto2),
			pos + Vector2(0.0, alto2 - pliegue)])
		c.draw_colored_polygon(hoja, Color(0.90, 0.87, 0.78))
		c.draw_polyline(hoja + PackedVector2Array([hoja[0]]), oscuro, maxf(1.0, lado * 0.012), true)
		# LOS RENGLONES. Sin ellos las dos hojas son dos manchas blancas y no se lee que son paginas.
		for i in 7:
			var ty: float = -alto2 * 0.66 + alto2 * 0.22 * float(i)
			c.draw_line(pos + Vector2(s * media * 0.14, ty), pos + Vector2(s * media * 0.86, ty),
				Color(0.42, 0.38, 0.32, 0.55), maxf(1.0, lado * 0.008), true)

	# LAS PAGINAS QUE PASAN: una hoja suelta que cruza del lado derecho al izquierdo, y vuelve a
	# empezar. Se dibuja como un trapecio que se ESTRECHA al llegar al centro, que es lo que hace la
	# perspectiva de una hoja girando -- si mantuviera el ancho pareceria una tarjeta deslizandose.
	var vuelta: float = fposmod(_t * 2.6, 1.0)
	if abre > 0.35:
		var vx: float = lerpf(1.0, -1.0, vuelta)
		# El ancho se estrecha al pasar por el centro (|vx| -> 0), que es lo que hace la perspectiva
		# de una hoja girando de canto. Manteniendo el ancho pareceria una tarjeta deslizandose.
		var ancho_p: float = media * (0.20 + absf(vx) * 0.80)
		# El borde de fuera es el que se aleja del lomo, asi que va del lado del signo de vx. En vx = 0
		# el signo no importa: ahi la hoja mide lo minimo y es simetrica.
		var s_p: float = 1.0 if vx >= 0.0 else -1.0
		var x0: float = vx * media - ancho_p * 0.5 * s_p
		var x1: float = vx * media + ancho_p * 0.5 * s_p
		var pag := PackedVector2Array([
			pos + Vector2(x0, -alto2 * 0.98), pos + Vector2(x1, -alto2 * 0.92),
			pos + Vector2(x1, alto2 * 0.92), pos + Vector2(x0, alto2 * 0.98)])
		c.draw_colored_polygon(pag, Color(0.97, 0.95, 0.88, 0.92))
		c.draw_polyline(pag + PackedVector2Array([pag[0]]), Color(0.5, 0.46, 0.40, 0.7),
			maxf(1.0, lado * 0.008), true)

	# EL LOMO, encima de las dos hojas: es lo que las une.
	c.draw_rect(Rect2(pos - Vector2(w * 0.07, alto2), Vector2(w * 0.14, alto2 * 2.0)), tapa, true)

	# Y EL SIGNO QUE SALE DE LAS PAGINAS cuando ya brilla: el mismo rombo del emblema, creciendo y
	# desvaneciendose. Es lo que dice que lo que hay dentro es un hechizo y no un texto.
	if br > 0.1:
		var e: float = lado * (0.14 + br * 0.42)
		_rombo(c, pos, e, Color(col.r, col.g, col.b, (1.0 - br) * 0.9 + 0.1))


func _rombo(c: Control, cen: Vector2, rad: float, col: Color) -> void:
	var p := PackedVector2Array([
		cen + Vector2(0, -rad), cen + Vector2(rad * 0.72, 0),
		cen + Vector2(0, rad), cen + Vector2(-rad * 0.72, 0)])
	c.draw_colored_polygon(p, Color(col.r, col.g, col.b, col.a * 0.35))
	c.draw_polyline(p + PackedVector2Array([p[0]]), col, maxf(1.5, rad * 0.12), true)
