# ============================================================
#  ver_fx.gd  --  HERRAMIENTA, no parte del juego.
#
#  Saca una TIRA PNG con la vida entera de UN fx_estilo, instante a instante, para poder MIRARLO. Es
#  el hermano de ver_animacion.gd -- aquel es para los sprites de los bichos y este para los golpes
#  que pinta CapaHechizos -- y existe por el mismo motivo: el visor con ventana
#  (herramientas/ver_enemigos_ataques.bat) sirve para ver el MOVIMIENTO, y esto para lo otro, que es
#  juzgar el dibujo cuadro a cuadro mientras se esta haciendo.
#
#  Y ademas resuelve algo que el visor con ventana no puede: aquel hay que pilotarlo a mano con las
#  teclas hasta llegar al golpe que quieres, asi que no sirve para comprobar un efecto sin sentarse
#  delante. Esto se lanza y escupe un PNG.
#
#  Se lanza con herramientas/ver_fx.bat [estilo] [ancho] [dur], p.ej.:
#      herramientas/ver_fx.bat NUBE_ESPORAS
#      herramientas/ver_fx.bat MICELIO 120
#  'estilo' es el NOMBRE del valor de CombatFX.Estilo (da igual mayusculas) o su numero.
#  No toca nada del juego: solo escribe en tools/salida/.
#
#  OJO -- COMPRUEBA T_VUELO, que es la trampa que ya ha roto esto tres veces: un estilo sin entrada
#  ahi no se dibuja NUNCA en la partida de verdad y no da ningun error. Aqui se canta.
#
#  DOS COSAS QUE HAY QUE SABER SI SE TOCA ESTO:
#
#   1. NO VA EN --headless, al contrario que ver_animacion. Aquel compone las imagenes a mano y por
#      eso le da igual; esto tiene que RENDERIZAR de verdad (CapaHechizos dibuja en su _draw con las
#      primitivas de Godot), y sin driver de video la captura sale negra. El .bat abre ventana, y la
#      ventana se cierra sola en cuanto termina.
#   2. Se pinta en un SubViewport del tamaño del cuadro y no en la ventana, para que el resultado no
#      dependa de a que resolucion este puesto el proyecto.
# ============================================================
extends Node2D

const SALIDA := "res://tools/salida/"
const MARCOS := 10                    # cuantos instantes de su vida se dibujan
const LADO := 160                     # el cuadro de cada instante, en pixeles
const HUECO := 6
const FONDO := Color(0.11, 0.12, 0.15)
const PASO := 1.0 / 60.0              # con que delta se avanza el reloj de la capa
const VIDA_TOPE := 6.0                # por si un estilo nunca se muere: no colgar la herramienta

var _sub: SubViewport
var _capa: CapaHechizos


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var quien: String = args[0] if args.size() > 0 else "MELEE"
	var ancho: float = float(args[1]) if args.size() > 1 else 96.0
	var dur: float = float(args[2]) if args.size() > 2 else 0.30

	var estilo: int = _estilo_de(quien)
	if estilo < 0:
		push_error("[ver fx] no conozco el estilo '%s'" % quien)
		get_tree().quit(1)
		return
	var nombre: String = String(CombatFX.Estilo.keys()[estilo])
	# LA COMPROBACION QUE DE VERDAD IMPORTA. Sin entrada en T_VUELO el efecto no llega a darse de
	# alta en combate (ver el 'vuelo > 0.0' de CombatFX._process) y no lo canta nadie.
	var vuelo: float = float(CombatFX.T_VUELO.get(estilo, 0.0))
	if vuelo <= 0.0:
		push_error("[ver fx] %s (%d) NO TIENE T_VUELO: en la partida no se dibujaria nunca."
			% [nombre, estilo])

	_montar()
	await RenderingServer.frame_post_draw

	var centro := Vector2(LADO * 0.5, LADO * 0.5)
	var origen := centro + Vector2(0.0, LADO * 0.42)      # el que pega, por debajo
	var col := Color(0.52, 0.46, 0.30)                    # el ocre del miconido, de muestra

	# CUANTO DURA, medido CORRIENDOLO, no calculado aqui: se levanta un efecto de prueba y se avanza
	# hasta que la capa lo tira. Asi el numero sale de _vida() -- que es quien manda -- en vez de una
	# copia de la cuenta que se quedaria atras el dia que se toque una coleta.
	_capa.alta(estilo, origen, centro, col, 1.0, dur, ancho)
	var vida: float = 0.0
	while not _capa._efectos.is_empty() and vida < VIDA_TOPE:
		_capa._process(PASO)
		vida += PASO
	_capa.limpiar()

	DirAccess.make_dir_recursive_absolute(SALIDA)
	var tira := Image.create(LADO * MARCOS + HUECO * (MARCOS - 1), LADO, false, Image.FORMAT_RGBA8)
	tira.fill(FONDO)

	for k in MARCOS:
		# CADA CUADRO ES UNA VIDA ENTERA DESDE CERO, no un frame mas del mismo efecto. Asi cada uno
		# sale con su semilla, y se ve tambien CUANTO VARIA el dibujo entre dos golpes iguales -- que
		# en los que llevan azar (la nube, el zarpazo) es la mitad de lo que hay que juzgar.
		_capa.alta(estilo, origen, centro, col, 1.0, dur, ancho)
		var hasta: float = vida * float(k) / float(MARCOS - 1)
		var t: float = 0.0
		while t < hasta:
			_capa._process(PASO)
			t += PASO
		_sub.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var img: Image = _sub.get_texture().get_image()
		# blit_rect y no blend_rect: lo que llega ya trae su fondo pintado (ver _montar).
		tira.blit_rect(img, Rect2i(0, 0, LADO, LADO), Vector2i(k * (LADO + HUECO), 0))
		_capa.limpiar()

	var ruta: String = "%sfx_%s.png" % [SALIDA, nombre.to_lower()]
	tira.save_png(ruta)
	print("[ver fx] %s (%d)  ·  vuelo %.2fs  ·  vida %.2fs  ·  ancho %.0f"
		% [nombre, estilo, vuelo, vida, ancho])
	print("[ver fx] ", ProjectSettings.globalize_path(ruta))
	get_tree().quit()


func _montar() -> void:
	_sub = SubViewport.new()
	_sub.size = Vector2i(LADO, LADO)
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# EL FONDO VA DENTRO DEL SUBVIEWPORT Y OPACO, no transparente para mezclarlo luego. Con el
	# viewport transparente el resultado sale con el alfa PREMULTIPLICADO, y al volver a mezclarlo
	# sobre la tira los golpes salian mas APAGADOS de lo que son -- una nube blanca se veia gris
	# sucio. Es una mentira peligrosa justo en la herramienta con la que se juzga el color: te lleva a
	# subirle el brillo a un efecto que ya lo tenia. Pintando aqui el mismo gris del combate, lo que
	# sale del PNG es exactamente lo que se ve en la pantalla.
	_sub.transparent_bg = false
	add_child(_sub)
	var fondo := ColorRect.new()
	fondo.color = FONDO
	fondo.size = Vector2(LADO, LADO)
	_sub.add_child(fondo)
	_capa = CapaHechizos.new()
	_capa.size = Vector2(LADO, LADO)
	_sub.add_child(_capa)


# Acepta el nombre del enum ("NUBE_ESPORAS", sin importar mayusculas) o su numero.
func _estilo_de(quien: String) -> int:
	if quien.is_valid_int():
		return int(quien)
	for clave in CombatFX.Estilo.keys():
		if String(clave).to_lower() == quien.to_lower():
			return int(CombatFX.Estilo[clave])
	return -1
