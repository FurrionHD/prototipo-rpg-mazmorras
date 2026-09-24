# ============================================================
#  combat_figuras.gd  (tema de la pantalla de combate: combat.figuras)
#  LAS FIGURAS de la pelea: la tarjeta de cada combatiente, su sprite o muñeco y sus POSES (reposo,
#  encaje, gesto, muerte), el mutante, el zoom, la seleccion con el raton y la ficha de detalle al
#  mantener pulsado. Lo demas, a _pantalla.
# ============================================================
extends RefCounted

# La pantalla de la que es este tema: todo lo que no es del tema se le pide a ella. Tipada con su
# script para que Godot deduzca los tipos (los := sobre ella); los NOMBRES no los comprueba al compilar:
# de eso se encarga tools/verificar_pantalla.py.
const Pantalla = preload("res://scripts/ui/combat.gd")
var _pantalla: Pantalla = null


func _init(pantalla: Pantalla) -> void:
	_pantalla = pantalla


# Alto RESERVADO para los estados. Se reserva SIEMPRE, haya estados o no, para que entrar o salir
# uno no mueva de sitio la barra de vida ni nada de lo que hay debajo.
#
# UNA fila. Eran dos porque el chip llevaba escrito dentro el icono, la magnitud y los turnos, y
# asi solo cabian ~3 por fila. Desde que el chip es SOLO EL ICONO (ver StatusChip) cabe de sobra
# el veneno + quemadura + pegajoso + imbuicion del bicho mas castigado, y la fila que sobraba se
# la queda el escenario, que es donde hace falta el sitio.
const ALTO_CHIPS := 26.0
# Las barras: estrechas. El numero va DENTRO y se lee igual con 16 px que con 24, asi que cada
# pixel de mas era sitio robado al centro de la pantalla (y son hasta tres barras por aliado).
const ALTO_BARRA_HP := 17.0
# EL AIRE que se le deja a cada bicho a los lados dentro de su columna. Sin el, dos que llenen su
# hueco justo se tocan y se lee como un solo borron; con el, siempre hay una linea de fondo que los
# separa. Ver _ajustar_zoom_sprites.
const MARGEN_SPRITE := 8.0
const HOLD_DETALLE := 1.0
var _golpe_mano: Dictionary = {}    # Combatant -> 0/1, la ULTIMA mano usada en dual (ver _anim_golpe_de)


# BLOQUE de un combatiente: la unidad que se ve, se señala y se clica. Junta en una caja su
# numero, su nombre, sus estados y su barra de vida, y esa caja ENTERA es la que se rodea con
# el borde blanco al seleccionarlo (por eso es un PanelContainer y no un apaño de Labels).
#   numero > 0 -> enemigo numerado y clicable;  numero <= 0 -> el jugador (ni numero ni clic).
#   idx = indice en _enemies (-1 para el jugador).
# Devuelve {panel, vbox, nombre, chips, hp, hp_lbl}.
func _crear_bloque(c: Combatant, numero: int, idx: int) -> Dictionary:
	# LA COLUMNA de este combatiente: su tarjeta y su sitio en el escenario, pegados. Es lo que
	# entra en la banda, y va en el orden de cada bando -los de enfrente con la ficha ARRIBA y su
	# sprite colgando hacia el centro, los tuyos al reves- para que las dos fichas queden en los
	# bordes de la pantalla y los dos sprites se miren en el medio.
	#
	# Que tarjeta y sprite vayan en el MISMO nodo no es cosmetico: si fueran dos bandas separadas,
	# cada alta, cada muerte y cada reordenacion (el jefe al centro) habria que hacerla dos veces y
	# en el mismo orden, y el dia que una se olvidara tendrias la ficha de un bicho encima de otro.
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 4)
	columna.mouse_filter = Control.MOUSE_FILTER_PASS
	# Contra el borde del que cuelga su banda: los enemigos crecen desde el techo, los tuyos desde
	# el suelo. Asi una tarjeta mas alta (mas chips) no descoloca a sus vecinas.
	columna.alignment = BoxContainer.ALIGNMENT_BEGIN if numero > 0 else BoxContainer.ALIGNMENT_END

	# EL SITIO DEL SPRITE. De momento va vacio: lo que importa ahora es que el hueco este reservado
	# y con el tamaño definitivo, para que el reparto de la pantalla sea el de verdad.
	var actor_wrap := Control.new()
	actor_wrap.custom_minimum_size = Vector2(0, _pantalla.ALTO_ACTOR)   # el ancho, el de la columna
	actor_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Al enemigo se le puede APUNTAR clicando su figura, que es lo natural cuando estas mirando el
	# escenario. La ficha de arriba sigue valiendo igual (y es la comoda en el movil, donde las
	# figuras se aprietan): el clic entra por el hueco, no por la figura, asi el area que responde
	# es la celda entera y es predecible.
	actor_wrap.mouse_filter = Control.MOUSE_FILTER_STOP if numero > 0 \
		else Control.MOUSE_FILTER_IGNORE
	if numero > 0:
		actor_wrap.gui_input.connect(_on_bloque_gui_input.bind(idx))
	actor_wrap.clip_contents = false
	# EL SITIO exacto de la figura dentro del hueco: centrada a lo ancho y en el extremo del hueco
	# que da AL CENTRO DE LA PANTALLA -- los de enfrente abajo del suyo y los tuyos arriba del tuyo,
	# porque los huecos estan en lados opuestos de su tarjeta. Asi los dos bandos se miran a la
	# misma distancia y cada figura deja el mismo aire con su ficha.
	#
	# Mide lo que la figura y no el hueco entero porque de este rectangulo salen el punto al que van
	# los golpes y donde nacen los numeros; con el tamaño del hueco, ese centro caia muy por encima
	# de la figura y los numeros salian flotando en el aire.
	var sitio := Control.new()
	sitio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sitio.clip_contents = false
	sitio.anchor_left = 0.5
	sitio.anchor_right = 0.5
	sitio.offset_left = -LADO_FIGURA * 0.5
	sitio.offset_right = LADO_FIGURA * 0.5
	if numero > 0:
		sitio.anchor_top = 1.0
		sitio.anchor_bottom = 1.0
		sitio.offset_top = -LADO_FIGURA
		sitio.offset_bottom = 0.0
	else:
		sitio.anchor_top = 0.0
		sitio.anchor_bottom = 0.0
		sitio.offset_top = 0.0
		sitio.offset_bottom = LADO_FIGURA
	actor_wrap.add_child(sitio)

	# Y DENTRO, el que mueve CombatFX (embestidas, sacudidas, el destello al recibir).
	#
	# Hacen falta los dos niveles, igual que wrap/panel y por el mismo motivo: CombatFX escribe la
	# position ENTERA cada frame (position = el desplazamiento del golpe, o cero en reposo), asi que
	# ese nodo no puede ser ademas el que este colocado en su sitio -- el cero le borraria la
	# colocacion y la figura se iria a la esquina de su hueco. Uno coloca, el otro se mueve.
	var actor := Control.new()
	actor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actor.clip_contents = false
	sitio.add_child(actor)
	# El tamaño se copia A MANO y no con anclajes, que recalculan tambien la position.
	actor.size = sitio.size
	sitio.resized.connect(func() -> void:
		if is_instance_valid(actor):
			actor.size = sitio.size)
	var figura: ColorRect = _montar_figura(actor, c, numero)

	# LA MARCA DE OBJETIVO: una flecha encima del enemigo apuntado.
	#
	# Cuelga del HUECO, arriba del todo. No de la figura, porque el sprite crece hacia arriba
	# saliendose de ella y la flecha le quedaba dentro; y no del nodo que mueve CombatFX, porque
	# entonces se iria de paseo con cada embestida -- señala el puesto, no al que se mueve.
	#
	# Y es un nodo aparte, no un tinte: modulate de la figura es de CombatFX (se reescribe cada
	# frame) y el de la columna lleva el gris del cadaver, asi que cualquiera de los dos se lo
	# comeria al instante.
	var cursor: Control = null
	if numero > 0:
		cursor = Control.new()
		cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cursor.visible = false
		cursor.set_anchors_preset(Control.PRESET_TOP_WIDE)
		cursor.offset_top = 0.0
		cursor.offset_bottom = 14.0
		cursor.draw.connect(func() -> void:
			var w: float = cursor.size.x
			cursor.draw_colored_polygon(PackedVector2Array([
				Vector2(w * 0.5 - 9.0, 0.0), Vector2(w * 0.5 + 9.0, 0.0),
				Vector2(w * 0.5, 12.0)]), Color(1, 1, 1, 0.9)))
		actor_wrap.add_child(cursor)

	# ENVOLTORIO DE LA TARJETA. La tarjeta va DENTRO de un Control pelado, y es el envoltorio -no el
	# panel- el que entra en la columna. Motivo: un Container reescribe la 'position' de sus hijos en
	# cada re-layout, y aqui hay re-layouts a punta pala (_refrescar_chips borra y recrea los chips en
	# CADA _update_hp). Sin esto, la embestida de una tarjeta se deshacia a mitad de golpe.
	# Con el envoltorio, el HBox coloca el envoltorio y el panel queda fuera del alcance de
	# cualquier Container: su position, su scale y su rotation son de CombatFX.
	var wrap := Control.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE   # el clic sigue siendo del panel, que va en STOP
	wrap.clip_contents = false                        # la embestida TIENE que poder desbordar
	# Mismo ancho para todos los de su fila, tuyo o enemigo: es lo que les permite ir en fila.
	wrap.custom_minimum_size = Vector2(_pantalla.montaje._ancho_bloque(
		_pantalla._enemies.size() if numero > 0 else _pantalla._aliados.size()), 0)

	var panel := PanelContainer.new()
	# El panel es quien recibe el clic; sus hijos van en PASS para no comerselo (ver _crear_bloque
	# de la barra: una ProgressBar es STOP por defecto y ocupa media caja).
	panel.mouse_filter = Control.MOUSE_FILTER_STOP if numero > 0 else Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _sb_bloque(false))
	wrap.add_child(panel)
	# El tamaño se copia A MANO y no con anclajes: los anclajes recalculan la 'position' en cada
	# resized, que es exactamente lo que el envoltorio existe para evitar.
	wrap.resized.connect(func() -> void:
		if is_instance_valid(panel):
			panel.size = wrap.size)
	panel.minimum_size_changed.connect(func() -> void:
		if is_instance_valid(wrap):
			wrap.custom_minimum_size.y = panel.get_combined_minimum_size().y)

	var margen := MarginContainer.new()
	margen.mouse_filter = Control.MOUSE_FILTER_PASS
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 6)
	panel.add_child(margen)

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_PASS
	margen.add_child(vb)

	# Fila del nombre: [nº] nombre.
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	fila.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.add_child(fila)

	if numero > 0:
		var num := Label.new()
		num.text = "%d." % numero
		num.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fila.add_child(num)

	var nombre := Label.new()
	nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# clip_text hace DOS cosas, y la segunda es la que importa aqui: ademas de recortar, pone el
	# ancho MINIMO del Label a 0. Sin eso, un bicho con nombre largo ("Slime venenoso (Nv.1)")
	# exigiria mas de ANCHO_BLOQUE, el bloque creceria (custom_minimum_size es un MINIMO, no un
	# tope) y la fila de enemigos dejaria de tener columnas iguales.
	nombre.clip_text = true
	nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(nombre)

	# Los chips van en su PROPIA zona, bajo el nombre, con el alto SIEMPRE reservado (aunque no
	# haya ninguno): asi entrar o salir un estado no mueve nada de sitio. Antes iban al lado del
	# nombre porque la UI era una columna a lo ancho y sobraba sitio horizontal; en un bloque de
	# 260 px ya no caben al lado, y apretarlos ahi recortaria el nombre.
	#
	# El envoltorio es un Control PELADO a proposito: un Container propagaria el tamaño minimo de
	# los chips hacia arriba y 3-4 estados volverian a ensanchar el bloque, rompiendo el ancho
	# fijo. Un Control normal no agrega el minimo de sus hijos, asi que el ancho queda blindado.
	var chips_wrap := Control.new()
	chips_wrap.custom_minimum_size = Vector2(0, ALTO_CHIPS)
	chips_wrap.clip_contents = true   # lo que no entre en las dos filas se recorta, no desborda
	chips_wrap.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.add_child(chips_wrap)

	# HFlow y no HBox: reparte los chips en varias filas EL SOLO cuando no caben a lo ancho. Con
	# un HBox se saldrian en linea recta y el clip_contents se los comeria.
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 4)
	chips.add_theme_constant_override("v_separation", 4)
	chips.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chips.mouse_filter = Control.MOUSE_FILTER_PASS
	chips_wrap.add_child(chips)

	# Barra de VIDA gorda y con el numero DENTRO, como las del mapa (ver player.gd).
	var hp := ProgressBar.new()
	hp.max_value = c.max_hp
	hp.show_percentage = false
	hp.custom_minimum_size = Vector2(0, ALTO_BARRA_HP)
	hp.self_modulate = Color(1.0, 0.4, 0.4)
	# PASS y no el STOP por defecto: la barra ocupa media caja, y en STOP se tragaria el clic
	# de seleccion en toda esa mitad.
	hp.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.add_child(hp)
	var hp_lbl: Label = _pantalla.efectos._crear_label_barra(hp, 13)

	if numero > 0:
		panel.gui_input.connect(_on_bloque_gui_input.bind(idx))

	# La ficha en el borde de la pantalla y el sprite hacia el centro, cada bando en su orden.
	if numero > 0:
		columna.add_child(wrap)
		columna.add_child(actor_wrap)
	else:
		columna.add_child(actor_wrap)
		columna.add_child(wrap)

	# 'margen', 'fila_nombre' y 'chips_wrap' no los usa la fila de siempre: los pide el MODO MINI del
	# combate en el mapa, que encoge la tarjeta a una barrita sobre la cabeza del bicho (ver
	# combat_figuras_mapa._poner_mini). Van en el dict y no se buscan por get_node para que el dia que
	# aqui cambie el arbol, el que se rompa sea ESTE archivo y no el otro.
	var bloque: Dictionary = {"columna": columna, "wrap": wrap, "panel": panel, "vbox": vb,
		"margen": margen, "fila_nombre": fila, "chips_wrap": chips_wrap,
		"actor_wrap": actor_wrap, "actor": actor, "figura": figura, "cursor": cursor,
		"nombre": nombre, "chips": chips, "hp": hp, "hp_lbl": hp_lbl, "idx": idx}
	# Le cuelga su capa de efectos (particulas de estado) y lo da de alta para las animaciones.
	if _pantalla._fx != null:
		_pantalla._fx.registrar(bloque)
	return bloque


# LA FIGURA de un combatiente en el escenario. De momento es un placeholder: los tuyos con su
# aspecto del mapa (color, foto y metal, via material_de) y los de enfrente con su color. Los
# sprites de verdad entran aqui mismo, en la siguiente tanda.
#
# Va anclada a los PIES (abajo y centrada), no al centro del hueco, y no es un detalle: "recibir un
# golpe" es un aplastado en Y con el pivote en el suelo, y con la figura centrada cualquier escalado
# la hunde o la levanta en el aire. Anclada abajo, crece y encoge apoyada.
#
# CUADRADA a proposito: el shader del cuerpo mapea la imagen por UV del rect, asi que uno no
# cuadrado deformaria la foto del personaje (mismo motivo que en turn_timeline).
const LADO_FIGURA := 124.0

func _montar_figura(actor: Control, c: Combatant, numero: int) -> ColorRect:
	var fig := ColorRect.new()
	fig.color = _pantalla._color_de(c) if numero <= 0 else c.color_visual
	fig.material = _pantalla._material_de(c) if numero <= 0 else null
	fig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Llena a su actor, que ya viene con el tamaño y apoyado en el suelo (ver _crear_bloque).
	fig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	actor.add_child(fig)
	if numero > 0:
		_poner_sprite(fig, c)
	else:
		_poner_muneco(fig, c)
	# LA FIRMA DEL MUTANTE. Va aqui y no dentro de _poner_sprite porque _poner_sprite se va de vacio
	# para los bichos que aun no tienen generador (se quedan con el cuadrado de color), y un mutante
	# sin sprite tiene el mismo derecho a avisar de que lo es.
	_marcar_mutante(actor, fig, c)
	# El numero NO se repite aqui: cada figura tiene su tarjeta justo encima y ya lo lleva, asi que
	# ponerlo tambien en el escenario es decir dos veces lo mismo en dos sitios que se miran.
	return fig


# ============================================================
#  EL MUTANTE, EN COMBATE
# ============================================================
# El mini-jefe se leia de un vistazo en el mapa (tinte carmesi que late, aura roja y mas bulto) y al
# entrar en combate se volvia un bicho corriente con "mutante" pegado al nombre. Se perdia el aviso
# justo donde se decide si peleas o huyes.
#
# Las tres piezas van cada una por su sitio, y no por capricho:
#   - EL TAMAÑO lo pone _poner_sprite en el alto_base, porque quien reparte el tamaño de todos es
#     _ajustar_zoom_sprites y tiene que ver a este ya crecido para escalar al resto contra el.
#   - EL AURA cuelga del ACTOR, no de la figura: el modulate de la figura tiñe a sus hijos (y el aura
#     saldria carmesi en vez de roja), y _revivir_bloque tira los hijos de la figura para rehacer el
#     sprite, lo que se llevaria las particulas por delante.
#   - EL TINTE no se puede pintar aqui y ya: CombatFX._aplicar reescribe el modulate de cada figura EN
#     CADA FRAME. Se registra como color DE REPOSO en CombatFX y es el quien lo compone. Es el mismo
#     reparto que en el mapa, donde el latido vive en enemy._tinte_reposo por la misma razon.
#
# ES IDEMPOTENTE, y tiene que serlo: un hueco se REESTRENA (_revivir_bloque), asi que la rata que
# entra donde murio un mutante se quedaria con su aura pegada, y al reves. Se limpia siempre lo de
# antes y luego se pone lo que toque.
const _META_AURA_MUT := "aura_mutante"

func _marcar_mutante(actor: Control, fig: ColorRect, c: Combatant) -> void:
	# Lo de antes, fuera. El aura cuelga del ACTOR y no de la figura, asi que no se la lleva el vaciado
	# de hijos de _revivir_bloque: hay que tirarla a mano, y por eso va marcada con un meta.
	if actor.has_meta(_META_AURA_MUT):
		var vieja = actor.get_meta(_META_AURA_MUT)
		if vieja != null and is_instance_valid(vieja):
			(vieja as Node).queue_free()
		actor.remove_meta(_META_AURA_MUT)
	if _pantalla._fx != null:
		_pantalla._fx.marcar_mutante(fig, c.mutante)
	if not c.mutante:
		return
	# El tamaño del aura sigue al del bicho, igual que en enemy._marcar_mutante: en una rata diminuta
	# un aura de trent seria una nube que tapa la pelea.
	var alto: float = LADO_FIGURA * 0.5 * float(EnemyData.mult_mutante(c.es_jefe)["escala"])
	# Mas densa que en el mapa (intensidad 2 = el doble de particulas). Alli el bicho ocupa unas
	# decenas de pixeles y siete motas ya lo envuelven; aqui la figura mide LADO_FIGURA y con las
	# mismas siete el aura se leia como cuatro puntitos sueltos.
	var p := Particulas.ascendentes(actor, EnemyData.MUT_AURA, 2.0, maxf(8.0, alto))
	# ascendentes() coloca la boquilla dando por hecho un cuerpo CENTRADO EN EL ORIGEN (es lo que pasa
	# en el mapa, donde el padre es el propio bicho). Aqui el padre es un Control y su origen es la
	# esquina de arriba a la izquierda. Se ASIGNA, no se suma: el desplazamiento hacia los pies que
	# trae puesto (alto * 0.2) es relativo a un cuerpo centrado, y sumandolo el aura nacia por DEBAJO
	# del suelo de la figura. El ancla es el punto de apoyo del sprite (ver _poner_sprite).
	p.position = Vector2(LADO_FIGURA * 0.5, LADO_FIGURA)
	actor.set_meta(_META_AURA_MUT, p)


# EL MUÑECO DE VERDAD encima de la figura del jugador/compañero -- calco de _poner_sprite, pero
# montando el cuerpo entero (arma, escudo, ropa, cara) en vez de un AnimatedSprite2D de bicho.
#
# SIN FICHA, NO HAY MUÑECO. Un combate suelto de pruebas (F6) o un compañero espejado en red antes
# de que llegue su roster no tienen PersonajeData detrás -- MunecoJugador.montar() necesita uno de
# verdad, así que en esos casos no se toca nada y se queda el ColorRect tintado de _montar_figura
# (que ya sabe degradar: mira Game.pj_de_combatant en _color_de/_material_de).
#
# MIRA AL NORTE (dir 4, de espaldas a cámara): en combate el jugador mira a los enemigos. Es la
# dirección CONTRARIA a la ficha de detalle (combate_detalle.gd, que lo enseña de cara) -- las dos
# van a propósito por separado, no las unifiques en una constante compartida.
func _poner_muneco(fig: ColorRect, c: Combatant) -> void:
	var pj: PersonajeData = Game.pj_de_combatant(c)
	if pj == null:
		return
	var m := MunecoJugador.new()
	m.montar(pj)
	m.tenir(pj.color, 0.0)
	m.poner_cara(pj.textura())
	if not m.hay_dibujo():
		m.queue_free()
		return
	# Apoyado en el suelo de la figura, igual que _poner_sprite -- los pies del muñeco son su propio
	# origen (sin offset que calcular).
	m.position = Vector2(LADO_FIGURA * 0.5, LADO_FIGURA)
	m.animar("idle_4")
	# EL TAMAÑO NO SE DECIDE AQUI, igual que con el sprite del enemigo: se apunta cuanto "mide de
	# fabrica" (a escala 1.0, en las MISMAS unidades que 'alto_base'/'ancho_base' del enemigo --
	# ver _poner_sprite -- porque ALTO_MUNDO ya esta en pixeles de pantalla a esa escala) y lo
	# reparte despues _ajustar_zoom_sprites, que mira a TODOS -- los tuyos y los de enfrente -- para
	# saber quien es el mas grande de la pelea entera. Un jefe gigante tiene que verse gigante junto
	# a tu personaje, no que cada fila se las arregle con su propio zoom.
	#
	# El ancho es a ojo (0.55×ALTO_MUNDO): a diferencia del bicho, que mide el pixel pintado de
	# verdad de su primer fotograma, el muñeco es una pila de ~10 capas y sacar el ancho pintado de
	# la pila entera no compensa para esto -- solo entra como tope de columna, y de sobra.
	fig.set_meta("muneco", m)
	fig.set_meta("alto_base", PoseJugador.ALTO_MUNDO)
	fig.set_meta("ancho_base", PoseJugador.ALTO_MUNDO * 0.55)
	# LA VUELTA A REPOSO, enganchada UNA SOLA VEZ aquí, que es donde nace el muñeco -- mismo motivo
	# que _poner_sprite con animation_finished (conectarla en cada encaje la acumularía).
	m.finished.connect(_on_anim_muneco_terminada.bind(m))
	fig.add_child(m)
	fig.color = Color(0, 0, 0, 0)   # manda el muñeco; el rect se queda solo como caja


# EL Combatant de un bloque ALIADO. NO se puede leer de b["idx"]: en los bloques de aliado ese
# campo va siempre a -1 (_anadir_bloque_aliado llama a _crear_bloque(c, 0, -1) -- es un resto del
# mismo parametro que en los de enemigo SÍ es su hueco en _enemies). _bloques_aliados en cambio SÍ
# va en el mismo orden que _aliados (ver su declaracion), así que se busca la POSICION del bloque
# ahí, no un campo suyo.
func _combatant_de_bloque_aliado(b: Dictionary) -> Combatant:
	var i: int = _pantalla._bloques_aliados.find(b)
	return _pantalla._aliados[i] if i >= 0 and i < _pantalla._aliados.size() else null


# QUE ANIMACION DE GOLPE le toca a ESTE combatiente ahora mismo. Calco de player._elegir_golpe(),
# pero por PersonajeData en vez de Game.equipped_main/equipped_off -- ese par es SOLO del líder, y
# aqui puede tocarle a cualquiera del grupo. "golpe_2m" si el arma principal es a dos manos; si
# tiene secundaria de una mano, alterna de mano golpe a golpe (igual que en el mapa, ver
# _golpe_mano); si no, siempre la derecha.
func _anim_golpe_de(c: Combatant) -> String:
	var pj: PersonajeData = Game.pj_de_combatant(c)
	if pj == null:
		return "golpe"
	var main = pj.equipped_main
	if main is WeaponData and bool(main.dos_manos):
		return "golpe_2m"
	if pj.equipped_off is WeaponData:
		var mano: int = 1 - int(_golpe_mano.get(c, 0))
		_golpe_mano[c] = mano
		return "golpe_izq" if mano == 1 else "golpe"
	return "golpe"


# LO QUE DURA MORIRSE, en segundos de animacion. Es la duracion natural de la animacion 'muerte' de
# los generadores (8 marcos a 10 fps), y cuadrandolas el sprite va a su ritmo en vez de estirado.
const T_MUERTE := 0.80


# ARRANCA LA MUERTE del que acaba de caer. Devuelve si de verdad se le ve morir: los que no tienen
# la animacion horneada (los aliados, los enemigos que son un cuadrado de color) siguen por el
# camino de siempre, o sea el gris.
#
# EN SEGUNDOS REALES, que es el detalle que se paga caro si se olvida: un AnimatedSprite2D corre con
# el reloj del motor y el combate con el suyo (CombatFX.escala_tiempo). A velocidad x2 el bicho se
# desvaneceria a medio derretir, porque la columna se retira con el reloj rapido y el dibujo iba con
# el lento.
func _arrancar_muerte(b: Dictionary, nodo: Node) -> bool:
	if nodo is MunecoJugador:
		# El jugador SIEMPRE tiene 'muerte' horneada. Sin 'muerte_queda': ese contador es solo para
		# _avanzar_retiradas, que retira la columna del enemigo muerto de la fila -- los ALIADOS
		# nunca se retiran (se quedan en su sitio a propósito, ver _apagar_visual), así que no aplica.
		(nodo as MunecoJugador).animar("muerte_4")
		return true
	var sp := nodo as AnimatedSprite2D
	if sp == null or sp.sprite_frames == null or not sp.sprite_frames.has_animation(&"muerte_0"):
		return false
	var esc: float = 1.0
	if _pantalla._fx != null:
		esc = maxf(_pantalla._fx.escala_tiempo, 0.01)
	var dur: float = T_MUERTE / esc
	_pose_ajustar(sp, &"muerte_0", dur)
	# Lo que le queda por morirse. Lo descuenta _avanzar_retiradas, que es quien decide cuando se
	# desvanece la columna: sin esto la tarjeta se iria con el bicho a medio caer.
	b["muerte_queda"] = dur
	return true


# EL SPRITE DE UN BLOQUE, o null si ese combatiente no tiene (los aliados y los ~15 enemigos que
# siguen siendo una figura de color).
func _sprite_de(b: Dictionary) -> AnimatedSprite2D:
	var fig: ColorRect = b.get("figura")
	if fig == null or not is_instance_valid(fig) or not fig.has_meta("sprite"):
		return null
	var sp: AnimatedSprite2D = fig.get_meta("sprite")
	return sp if sp != null and is_instance_valid(sp) else null


# EL MUÑECO de un bloque (jugador/compañero), o null si sigue siendo un cuadrado de color. Hermano
# de _sprite_de -- clave de metadata DISTINTA ("muneco", no "sprite") a propósito: _ajustar_zoom_sprites
# solo mira "sprite"/"alto_base", así que con esto YA lo ignora sin tocar esa función.
func _muneco_de(b: Dictionary) -> MunecoJugador:
	var fig: ColorRect = b.get("figura")
	if fig == null or not is_instance_valid(fig) or not fig.has_meta("muneco"):
		return null
	var m: MunecoJugador = fig.get_meta("muneco")
	return m if m != null and is_instance_valid(m) else null


# EL NODO QUE LLEVA LA POSE de este bloque, sea cual sea (AnimatedSprite2D de un enemigo o
# MunecoJugador de un aliado). null si sigue siendo un cuadrado de color liso. Es el único sitio
# donde los disparadores de más abajo (_on_gesto_iniciado, _on_golpe_encajado...) deciden CUÁL de
# los dos hay -- a partir de ahí branchean por tipo, nunca duplican la función entera (ver memoria
# ramas-espejo-jugador-enemigo: ya mordió una vez en este archivo).
func _nodo_pose_de(b: Dictionary) -> Node:
	var sp: AnimatedSprite2D = _sprite_de(b)
	if sp != null:
		return sp
	return _muneco_de(b)


# QUIEN MANDA SOBRE EL SPRITE. Tres cosas quieren mover al mismo bicho a la vez -- ataca, le pegan,
# y se muere-- y sin una regla se pisan en el peor momento posible: justo en el golpe que lo mata,
# que es cuando pasan las tres.
#
# LA REGLA ES EL ORDEN DE ESTE ENUM, de menos a mas: MUERTE > GESTO > ENCAJE > REPOSO.
#   * Un GESTO pisa un ENCAJE porque el ataque que el bicho tenia planificado tiene que verse; el
#     golpe que le acaba de entrar ya se lee por el destello y la sacudida de la figura, que no
#     dependen del sprite.
#   * La MUERTE lo pisa todo y no la levanta nadie.
# El estado vive en el SPRITE y no en el bloque a proposito: al reestrenar un hueco, _revivir_bloque
# tira el sprite viejo y monta otro (ver alli), asi que el estado se limpia solo y un refuerzo no
# puede nacer heredando la muerte del cadaver cuyo sitio ocupa.
enum PoseSprite { REPOSO, ENCAJE, GESTO, MUERTE }


# 'nodo' es un AnimatedSprite2D (enemigo) o un MunecoJugador (jugador/compañero) -- get_meta/
# set_meta son de Node, así que la precedencia MUERTE>GESTO>ENCAJE>REPOSO vale para los dos sin
# ninguna copia.
func _pose_estado(nodo: Node) -> int:
	return int(nodo.get_meta("pose_estado", PoseSprite.REPOSO))


func _pose_marcar(nodo: Node, estado: int) -> void:
	nodo.set_meta("pose_estado", estado)


# A REPOSO. Un solo sitio, porque llegan aqui los dos finales (el del gesto y el del encaje) -- y
# ahora los dos tipos de nodo, sprite de bicho o muñeco de jugador.
func _pose_reposo(nodo: Node) -> void:
	_pose_marcar(nodo, PoseSprite.REPOSO)
	if nodo is AnimatedSprite2D:
		var sp: AnimatedSprite2D = nodo
		# El speed_scale hay que devolverlo aqui: se toca para ajustar la animacion al tiempo que
		# tiene (ver _pose_ajustar) y si no se resetea se queda pegado al ritmo del ultimo gesto.
		sp.speed_scale = 1.0
		if sp.sprite_frames != null and sp.sprite_frames.has_animation(&"idle_0"):
			sp.animation = &"idle_0"
			sp.frame = 0
			sp.play()
	elif nodo is MunecoJugador:
		(nodo as MunecoJugador).animar("idle_4")


# LA VUELTA A REPOSO DESPUES DE ENCAJAR. Se engancha UNA VEZ POR SPRITE (en _poner_sprite) y solo
# actua si el bicho estaba encajando: nunca para un GESTO -- hay animaciones que acaban sostenidas a
# proposito, 'inflar' se queda hinchada esperando el salto y 'raices' agarrada al suelo, y
# devolverlas a reposo aqui las cortaria justo antes de su remate -- ni para la MUERTE.
func _on_anim_sprite_terminada(sp: AnimatedSprite2D) -> void:
	if sp == null or not is_instance_valid(sp):
		return
	if _pose_estado(sp) != PoseSprite.ENCAJE:
		return
	_pose_reposo(sp)


# HERMANA de la de arriba, para el muñeco -- NO es la misma rama espejo que se evitó en el resto de
# este archivo: están enganchadas a DOS SEÑALES DE DOS TIPOS DE NODO distintos en el momento de
# conectar (animation_finished del sprite en _poner_sprite, finished del muñeco en _poner_muneco),
# así que hacen falta dos puntos de conexión -- pero las dos llaman a la MISMA _pose_reposo por
# dentro, que es donde vive la lógica de verdad.
func _on_anim_muneco_terminada(m: MunecoJugador) -> void:
	if m == null or not is_instance_valid(m):
		return
	if _pose_estado(m) != PoseSprite.ENCAJE:
		return
	_pose_reposo(m)


# LE ENTRA UN GOLPE: el cuerpo lo acusa. Es la otra mitad de gesto_iniciado -- aquel es del que
# pega, este del que lo recibe-- y llega UNA VEZ POR GOLPE, no una por accion.
#
# Un encaje SI pisa a otro encaje: seis mordiscos de un Frenesi tienen que leerse como seis
# sacudidas, no como un temblor continuo. Lo que no puede es pisar a algo de mas rango.
func _on_golpe_encajado(b: Dictionary, dur: float) -> void:
	var nodo: Node = _nodo_pose_de(b)
	if nodo == null:
		return
	if _pose_estado(nodo) >= PoseSprite.GESTO:
		return
	if nodo is AnimatedSprite2D:
		var sp: AnimatedSprite2D = nodo
		if sp.sprite_frames == null:
			return
		# Una sola direccion: en combate al bicho se le ve siempre de frente (ver los generadores).
		# El que no la tenga horneada se queda como hasta ahora, con el destello y la sacudida.
		var anim := &"encaje_0"
		if not sp.sprite_frames.has_animation(anim):
			return
		_pose_marcar(sp, PoseSprite.ENCAJE)
		_pose_ajustar(sp, anim, dur)
	else:
		# El jugador SIEMPRE tiene 'encaje' horneado (viene con el muñeco de fábrica) -- a diferencia
		# del bicho, aqui no hace falta comprobar que exista.
		_pose_marcar(nodo, PoseSprite.ENCAJE)
		(nodo as MunecoJugador).animar("encaje_4")


# Ajusta la animacion al TIEMPO QUE TIENE y la arranca. 'dur' viene en segundos reales: un
# AnimatedSprite2D corre con el reloj del motor y el combate con el suyo (CombatFX.escala_tiempo),
# asi que a x2 el cuerpo iria al doble y el dibujo a ritmo normal, cada uno por su lado.
func _pose_ajustar(sp: AnimatedSprite2D, anim: StringName, dur: float) -> void:
	var fps: float = maxf(sp.sprite_frames.get_animation_speed(anim), 0.1)
	var natural: float = float(sp.sprite_frames.get_frame_count(anim)) / fps
	sp.speed_scale = clampf(natural / maxf(dur, 0.05), 0.25, 6.0)
	sp.animation = anim
	sp.frame = 0
	sp.play()


# EMPIEZA EL GESTO: el bicho pasa a su animacion de ataque, mirando hacia donde va.
#
# La animacion se ajusta al TIEMPO DEL GESTO y no al reves: 'dur' viene en segundos reales y de ahi
# sale el speed_scale. Hay que hacerlo asi porque un AnimatedSprite2D corre con el reloj del motor,
# mientras que el gesto corre con el de CombatFX (escala_tiempo) -- a velocidad x2 el cuerpo iria
# al doble y el dibujo a ritmo normal, cada uno por su lado.
func _on_gesto_iniciado(b: Dictionary, dir: int, dur: float, pide: StringName = &"") -> void:
	var nodo: Node = _nodo_pose_de(b)
	if nodo == null:
		return   # sin sprite/muñeco el gesto sigue valiendo: lo que se mueve es la figura
	# Un muerto no ataca. Ver PoseSprite: la muerte lo pisa todo.
	if _pose_estado(nodo) == PoseSprite.MUERTE:
		return
	if nodo is AnimatedSprite2D:
		var sp: AnimatedSprite2D = nodo
		if sp.sprite_frames == null:
			return
		# LA QUE PIDA LA HABILIDAD, y si no la tiene (o no pide ninguna), su gesto de atacar de
		# siempre. Pedir una animacion que ese bicho no tenga no rompe nada: ataca como cualquier
		# otro dia.
		var anim := StringName("embestida_%d" % dir)
		if pide != &"":
			var propia := StringName("%s_%d" % [pide, dir])
			# Y SI ESA ANIMACION SOLO TIENE LA DIRECCION 0, VALE IGUAL. Hay habilidades que se dibujan
			# en una sola direccion a proposito -- el pisoton y el bramido del Minotauro, igual que
			# 'encaje' y 'muerte' -- porque en la pantalla de combate al bicho se le ve siempre de
			# frente. Sin este escalon, esas animaciones solo aparecerian cuando 'dir' saliera 0 y el
			# resto de las veces el bicho atacaria con su embestida: intermitentes, que es peor que no
			# tenerlas. Es la misma degradacion que hace el visor de animaciones.
			if not sp.sprite_frames.has_animation(propia):
				propia = StringName("%s_0" % pide)
			if sp.sprite_frames.has_animation(propia):
				anim = propia
		if not sp.sprite_frames.has_animation(anim):
			return
		_pose_marcar(sp, PoseSprite.GESTO)
		_pose_ajustar(sp, anim, dur)
	else:
		# El jugador no tiene "embestida": golpe/golpe_izq/golpe_2m segun lo que lleve equipado (ver
		# _anim_golpe_de), siempre mirando al norte -- 'dir' no se usa aqui, el jugador solo tiene
		# horneada esa direccion para los golpes en combate.
		var c: Combatant = _combatant_de_bloque_aliado(b)
		if c == null:
			return
		# EN EL MAPA lo hace su cuerpo, hacia donde golpea y con la animacion de la habilidad.
		if _pantalla.tactico:
			_pantalla.turno_mapa.gesto_en_mapa(c, String(pide), dur)
		_pose_marcar(nodo, PoseSprite.GESTO)
		(nodo as MunecoJugador).animar("%s_4" % _anim_golpe_de(c))


# Y AL ACABAR, a reposo. Sin esto se queda clavado en el ultimo frame del ataque: 'embestida' es
# loop = false, asi que se congela ahi y el bicho pasa el resto de la pelea con la pose del golpe.
#
# EL QUE ESTA MURIENDO SE SALTA ESTO, y no es un caso raro: al cerrar la cola (_cerrar_gestos) se
# avisa del final a TODOS los planes vivos, asi que un bicho que muera mientras atacaba pasaria por
# aqui y resucitaria visualmente -- vuelto a su idle, tan tranquilo, al final de la racha que lo
# acababa de matar.
func _on_gesto_terminado(b: Dictionary) -> void:
	var nodo: Node = _nodo_pose_de(b)
	if nodo == null:
		return
	if _pose_estado(nodo) == PoseSprite.MUERTE:
		return
	_pose_reposo(nodo)


# EL SPRITE del enemigo encima de su figura, si es de los que ya tienen uno. Los que no (hoy la
# mayoria: solo hay generador para slime, rata, jabali y trent) se quedan con el cuadrado de color,
# que es exactamente lo que habia y no molesta.
#
# Se usa 'idle' MIRANDO A CAMARA (la direccion 0 = S), que es la vista frontal que hace falta aqui:
# las ocho direcciones del mapa son isometricas y solo esa mira de frente. El cuadrado de color se
# apaga cuando hay sprite, pero el ColorRect se queda: es el que lleva el tamaño y el que colorean
# la seleccion y el resto de la UI.
func _poner_sprite(fig: ColorRect, c: Combatant) -> void:
	if c.sprite_res == "" or not ResourceLoader.exists(c.sprite_res):
		return
	var ed: EnemyData = load(c.sprite_res) as EnemyData
	if ed == null:
		return
	var frames: SpriteFrames = SpritesEnemigo.frames_de(ed, c.sprite_t)
	if frames == null:
		return
	var anim: StringName = &"idle_0"
	if not frames.has_animation(anim):
		return
	var sp := AnimatedSprite2D.new()
	sp.sprite_frames = frames
	sp.animation = anim
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.centered = true
	# APOYADO EN EL SUELO de la figura y centrado a lo ancho, que es donde esta el pivote de los
	# golpes (ver CombatFX._aplicar): asi un aplastado lo hunde en vez de dejarlo flotando.
	sp.position = Vector2(LADO_FIGURA * 0.5, LADO_FIGURA)
	# EL TAMAÑO NO SE DECIDE AQUI. Se apunta cuanto mide este bicho "de fabrica" y lo reparte
	# despues _ajustar_zoom_sprites, que necesita ver a TODOS los de la pelea para saber cual es el
	# mas grande. Ver alli por que.
	var alto_base: float = 1.0
	var tex: Texture2D = frames.get_frame_texture(anim, 0)
	if tex != null and tex.get_height() > 0:
		# LO QUE MIDE EL BICHO DIBUJADO, no su frame. Los frames traen bastante aire transparente
		# arriba (el sitio que necesitan las animaciones que dan saltos), asi que midiendo el frame
		# entero todos salian a la mitad del tamaño que les cabia.
		# LO QUE MIDE EL BICHO y DONDE ESTA dentro de su frame. Los frames del horno son mas grandes
		# que el dibujo (el sitio que necesitan las animaciones que se mueven), y ese aire viaja en
		# el 'margin' del AtlasTexture: get_height() devuelve el frame inflado y get_image() solo el
		# recorte de verdad. Midiendo el frame, todos salian a la mitad de lo que les cabia; y
		# apoyandolos por el borde del frame, los que llevan mas aire abajo (el jabali) flotaban.
		var alto_px: float = float(tex.get_height())
		var dentro: float = float(tex.get_height())   # donde acaba el dibujo dentro del frame
		var img: Image = tex.get_image()
		if img != null and img.get_height() > 0:
			alto_px = float(img.get_height())
			dentro = alto_px
			fig.set_meta("ancho_base", float(img.get_width()))
			var at := tex as AtlasTexture
			if at != null:
				dentro += at.margin.position.y
		sp.offset.y = tex.get_height() * 0.5 - dentro
		alto_base = alto_px * SpritesEnemigo.escala_de(ed)
		if SpritesEnemigo.hay_que_estirar(ed):
			alto_base *= ed.escala_visual
		# EL BULTO DEL MUTANTE. Va en el alto_base y no en el scale del sprite porque quien reparte el
		# tamaño de toda la pelea es _ajustar_zoom_sprites, contra el mas grande: tocando el scale
		# despues, el mutante crecia por su cuenta y el reparto ya no cuadraba. Es la misma excepcion
		# que en el mapa (enemy._marcar_mutante): a los generados se les estira el pixel aunque no
		# declaren hay_que_estirar, porque la alternativa era una version mutante del generador de
		# cada uno de los veinte enemigos para decir lo mismo que ya dicen el tinte y el aura.
		if c.mutante:
			alto_base *= float(EnemyData.mult_mutante(c.es_jefe)["escala"])
	fig.set_meta("sprite", sp)
	fig.set_meta("alto_base", alto_base)
	# LA VUELTA A REPOSO, enganchada UNA SOLA VEZ y aqui, que es donde nace el sprite. Conectarla
	# cada vez que se encaja un golpe la acumularia: seis mordiscos dejarian seis conexiones y el
	# septimo llamaria siete veces. Ver _on_anim_sprite_terminada para quien la aprovecha.
	sp.animation_finished.connect(_on_anim_sprite_terminada.bind(sp))
	fig.add_child(sp)
	sp.play()
	fig.color = Color(0, 0, 0, 0)   # manda el sprite; el rect se queda solo como caja


# EL TAMAÑO DE TODOS -- enemigos Y los tuyos --, en relacion AL MAS GRANDE DE LA PELEA ENTERA: el
# mayor llena su hueco de arriba abajo y todos los demas se escalan con SU MISMO factor. UN SOLO
# factor para las dos filas: si el jefe es del doble de alto que tu personaje, tiene que VERSE del
# doble de alto que tu personaje, no que cada fila se las arregle sola y el tamaño relativo entre
# bandas salga de la nada.
#
# Se hace asi, y de una vez para toda la pelea, porque las dos alternativas obvias fallan:
#   - Un zoom fijo no sirve: cada piso trae bichos de tamaños muy distintos, y el que le viene
#     bien a un slime deja al trent saliendose por arriba (o al reves, cuatro ratas diminutas).
#   - Escalar a cada uno para que llene su hueco (SpritesEnemigo.zoom_visor) IGUALA a todos, que
#     es justo lo que no se quiere: una rata acabaria del tamaño de un trent.
# Con un factor comun sacado del mayor, se aprovecha todo el alto disponible Y un trent sigue
# siendo el doble de alto que un slime, que es lo que dicen sus dibujos (60 px contra 27).
#
# Hay que rehacerlo cada vez que cambia QUIEN esta en cualquiera de las dos filas: si entra un
# refuerzo (o un compañero) mas grande que los que habia, encoge a todos los demas para dejarle
# sitio -- en las DOS filas, porque el factor es compartido.
func _ajustar_zoom_sprites() -> void:
	var mayor: float = 0.0
	var mas_ancho: float = 0.0
	var vivos_enemigos: int = 0
	for b in _pantalla._bloques:
		var fig: ColorRect = b.get("figura")
		if fig == null or not is_instance_valid(fig) or not fig.has_meta("alto_base"):
			continue
		# Los muertos no cuentan: un jefe caido no puede seguir achicando a los que quedan vivos.
		var i: int = int(b.get("idx", -1))
		if i >= 0 and i < _pantalla._enemies.size() and not _pantalla._enemies[i].is_alive():
			continue
		mayor = maxf(mayor, float(fig.get_meta("alto_base")))
		# Y EL MAS ANCHO, que no tiene por que ser el mismo que el mas alto: el trent es alto y
		# estrecho, el slime bajo y ancho. Como el factor es UNO para toda la pelea, tiene que
		# valerle a todos.
		mas_ancho = maxf(mas_ancho, float(fig.get_meta("ancho_base", LADO_FIGURA)))
		vivos_enemigos += 1
	# LOS TUYOS cuentan IGUAL para decidir quien es "el mas grande" -- ver la cabecera. 'alto_base'/
	# 'ancho_base' de un muñeco los deja puestos _poner_muneco, en las mismas unidades (pixeles de
	# pantalla a escala 1.0) que usan los bichos, asi que se comparan sin convertir nada.
	var vivos_aliados: int = 0
	for ba in _pantalla._bloques_aliados:
		var figa: ColorRect = ba.get("figura")
		if figa == null or not is_instance_valid(figa) or not figa.has_meta("alto_base"):
			continue
		var ca: Combatant = _combatant_de_bloque_aliado(ba)
		if ca != null and not ca.is_alive():
			continue
		mayor = maxf(mayor, float(figa.get_meta("alto_base")))
		mas_ancho = maxf(mas_ancho, float(figa.get_meta("ancho_base", LADO_FIGURA)))
		vivos_aliados += 1
	if mayor <= 0.0:
		return
	# LLENAR EL ALTO ES LA INTENCION, PERO EL ANCHO MANDA CUANDO NO DA. El factor salia solo del
	# alto, y con cinco en la fila las columnas se estrechan mientras el zoom sigue siendo el
	# mismo: los anchos y bajos -- los que peor lo llevan -- se salian de su columna y se pisaban
	# unos a otros. CADA FILA TIENE SU PROPIO HUECO (el ancho de columna se reparte por separado en
	# cada banda, pueden tener distinto numero de miembros), asi que las dos limitan el MISMO factor.
	#
	# Se cuenta con TODAS las tarjetas de cada banda y no solo con las que tienen sprite/muñeco: el
	# ancho de columna lo reparte _ancho_bloque entre todas las que se ven, asi que es ese mismo
	# numero el que hay que darle o el reparto no cuadra.
	var visibles_enemigos: int = 0
	for b2 in _pantalla._bloques:
		var col: Control = b2.get("columna")
		if col != null and is_instance_valid(col) and col.visible:
			visibles_enemigos += 1
	var visibles_aliados: int = 0
	for ba2 in _pantalla._bloques_aliados:
		var cola: Control = ba2.get("columna")
		if cola != null and is_instance_valid(cola) and cola.visible:
			visibles_aliados += 1
	var factor: float = _pantalla.ALTO_ACTOR / mayor
	if mas_ancho > 0.0:
		if vivos_enemigos > 0:
			var hueco_e: float = _pantalla.montaje._ancho_bloque(maxi(visibles_enemigos, vivos_enemigos)) - MARGEN_SPRITE * 2.0
			factor = minf(factor, hueco_e / mas_ancho)
		if vivos_aliados > 0:
			var hueco_a: float = _pantalla.montaje._ancho_bloque(maxi(visibles_aliados, vivos_aliados)) - MARGEN_SPRITE * 2.0
			factor = minf(factor, hueco_a / mas_ancho)
	for b in _pantalla._bloques:
		var fig2: ColorRect = b.get("figura")
		if fig2 == null or not is_instance_valid(fig2) or not fig2.has_meta("sprite"):
			continue
		var sp2: AnimatedSprite2D = fig2.get_meta("sprite")
		if sp2 != null and is_instance_valid(sp2):
			sp2.scale = Vector2.ONE * factor
			# LO ANCHO QUE SE VE ESTE BICHO, en pixeles de pantalla. Se publica en el bloque porque
			# lo necesita CombatFX para saber cuanto tiene que hincharse el que se deja caer encima
			# de un grupo -- y se actualiza aqui, que es el unico sitio que cambia esa escala.
			b["ancho_dibujo"] = float(fig2.get_meta("ancho_base", LADO_FIGURA)) * factor
	for ba3 in _pantalla._bloques_aliados:
		var figm: ColorRect = ba3.get("figura")
		if figm == null or not is_instance_valid(figm) or not figm.has_meta("muneco"):
			continue
		var m3: MunecoJugador = figm.get_meta("muneco")
		if m3 != null and is_instance_valid(m3):
			m3.scale = Vector2.ONE * factor
			ba3["ancho_dibujo"] = float(figm.get_meta("ancho_base", LADO_FIGURA)) * factor


# Estilo del bloque: seleccionado = borde blanco alrededor de todo, normal = borde transparente.
# El GROSOR es el mismo en los dos a proposito, y lo que cambia es el COLOR: si el borde
# apareciera y desapareciera, el bloque cambiaria de tamaño y la columna daria un brinco cada
# vez que cambias de objetivo.
#
# 'tinte' = el color que le pegan sus ESTADOS (dorado si manda un buff, el color del estado
# apagado si manda un debuff, blanco si nada). Lo calcula CombatFX y llega por la señal
# tinte_cambiado; el borde de seleccion siempre gana, que es lo que hay que poder ver cuando
# estas eligiendo objetivo.
func _sb_bloque(sel: bool, tinte: Color = Color.WHITE) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var tenido: bool = tinte != Color.WHITE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	if tenido:
		sb.bg_color = Color(tinte.r, tinte.g, tinte.b, 0.12 if sel else 0.10)
		sb.border_color = Color(1, 1, 1, 0.95) if sel else Color(tinte.r, tinte.g, tinte.b, 0.75)
		return sb
	sb.bg_color = Color(1, 1, 1, 0.05) if sel else Color(0, 0, 0, 0)
	sb.border_color = Color(1, 1, 1, 0.95) if sel else Color(0, 0, 0, 0)
	return sb


# Repinta el recuadro de UNA tarjeta juntando las dos cosas que deciden su estilo: si esta
# seleccionada (borde blanco) y el tinte de sus estados. Existe porque son dos fuentes que se
# pisaban: al entrar un veneno se perdia el borde de seleccion, y al cambiar de objetivo se
# perdia el tinte.
func _on_tinte_cambiado(bloque: Dictionary) -> void:
	var panel: Control = bloque.get("panel")
	if panel == null or not is_instance_valid(panel):
		return
	var idx: int = int(bloque.get("idx", -1))
	var sel: bool = idx >= 0 and idx == _pantalla._target_idx \
		and idx < _pantalla._enemies.size() and _pantalla._enemies[idx].is_alive()
	panel.add_theme_stylebox_override("panel", _sb_bloque(sel, bloque.get("tinte", Color.WHITE)))


# Clic en un bloque enemigo = pasa a ser tu objetivo.
func _on_bloque_gui_input(ev: InputEvent, idx: int) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_seleccionar(idx)


# Elige a quien van tus acciones. Ignora a los muertos (a un cadaver no se le apunta).
func _seleccionar(idx: int) -> void:
	if idx < 0 or idx >= _pantalla._enemies.size() or not _pantalla._enemies[idx].is_alive():
		return
	_pantalla._target_idx = idx
	for i in _pantalla._bloques.size():
		var vivo: bool = _pantalla._enemies[i].is_alive()
		var es: bool = vivo and i == idx
		_pantalla._bloques[i]["panel"].add_theme_stylebox_override("panel",
			_sb_bloque(es, _pantalla._bloques[i].get("tinte", Color.WHITE)))
		# Y la marca sobre la FIGURA, que es donde estas mirando cuando eliges: el borde de la
		# ficha queda arriba del todo y no dice a cual de los del escenario estas apuntando.
		var cur: Control = _pantalla._bloques[i].get("cursor")
		if cur != null and is_instance_valid(cur):
			cur.visible = es
	# Y en la barra de accion: su marcador se enmarca, le sale una flecha y pasa por encima de
	# los que lo tapen. Va por _objetivo() y no por _enemies[idx] para no duplicar la regla de
	# "si el apuntado no vale, el siguiente vivo".
	if _pantalla._timeline != null:
		_pantalla._timeline.marcar_objetivo(_pantalla._objetivo())


# ¿Se puede abrir la ficha de detalle AHORA MISMO? Solo en TU turno: cuando la barra de acciones
# propia esta a la vista esperando que elijas. En una animacion, el turno de un enemigo o -en
# multi- el de un aliado, esa barra esta oculta (_ocultar_cajas), asi que este chequeo cubre
# todos los casos: no queremos un menu abierto con el combate corriendo por detras.
func _puedo_inspeccionar() -> bool:
	return _pantalla._state != _pantalla.State.FINISHED and _pantalla._actions_box != null and _pantalla._actions_box.visible


# Abre la ficha de detalle. 'c' == null -> primer personaje de tu formacion.
func _abrir_detalle(c: Combatant = null) -> void:
	if not _puedo_inspeccionar():
		return
	if _pantalla._detalle == null or not is_instance_valid(_pantalla._detalle):
		_pantalla._detalle = preload("res://scripts/ui/combate_detalle.gd").new()
		_pantalla._detalle.preparar(_pantalla)
		_pantalla.add_child(_pantalla._detalle)
	if c == null and not _pantalla._aliados.is_empty():
		c = _pantalla._aliados[0]
	_pantalla._detalle.abrir(c)


# El combatiente VIVO cuya columna (tarjeta + figura) esta bajo 'pos_global'. Para el mantener
# pulsado: sale gratis mirar los dos bandos sin cablear el gui_input de cada bloque.
func _combatiente_bajo(pos_global: Vector2) -> Combatant:
	for i in _pantalla._bloques.size():
		if i >= _pantalla._enemies.size() or not _pantalla._enemies[i].is_alive():
			continue
		var col: Control = _pantalla._bloques[i].get("columna")
		if col != null and is_instance_valid(col) and col.visible \
				and col.get_global_rect().has_point(pos_global):
			return _pantalla._enemies[i]
	for i in _pantalla._bloques_aliados.size():
		if i >= _pantalla._aliados.size() or not _pantalla._aliados[i].is_alive():
			continue
		var col2: Control = _pantalla._bloques_aliados[i].get("columna")
		if col2 != null and is_instance_valid(col2) and col2.visible \
				and col2.get_global_rect().has_point(pos_global):
			return _pantalla._aliados[i]
	return null


# Cuenta el "mantener pulsado" que abre la ficha. Lo llama _process.
func _tick_hold_detalle(delta: float) -> void:
	if _pantalla._hold_c == null:
		return
	if not _puedo_inspeccionar() or (_pantalla._detalle != null and is_instance_valid(_pantalla._detalle) and _pantalla._detalle.abierta()):
		_pantalla._hold_c = null
		return
	_pantalla._hold_t += delta
	if _pantalla._hold_t < HOLD_DETALLE:
		return
	var c: Combatant = _pantalla._hold_c
	_pantalla._hold_c = null
	_abrir_detalle(c)
