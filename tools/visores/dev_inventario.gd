# ============================================================
#  dev_inventario.gd  --  HERRAMIENTA, no parte del juego.
#
#  Abre el INVENTARIO de verdad (scripts/ui/inventory_menu.gd) con la bolsa y el baul llenos de
#  cosas inventadas, y saca una captura de CADA pestaña. Es la unica forma de juzgar la pantalla:
#  el visor de celdas enseña la pieza suelta, pero lo que hay que mirar aqui es el conjunto --
#  cuanto respira la rejilla, si la ficha de la derecha cabe, si las pestañas de arriba se leen.
#
#  Se llena a mano y no se carga una partida guardada a proposito: hace falta que salgan LOS OCHO
#  peldaños de rareza y las cinco clases de consumible a la vez, y una partida real casi nunca los
#  tiene todos. Ademas asi la captura es siempre la misma y dos versiones se pueden comparar.
#
#  Va CON VENTANA (nada de --headless): un Control no se coloca ni se dibuja sin superficie de
#  render, y en headless la captura sale en negro.
#
#  Y con process_mode = ALWAYS: el inventario PAUSA el arbol al abrirse (Game.abrir_menu), asi que
#  sin esto el propio visor se congela en el primer await y no llega a capturar nada.
#
#  Doble clic en herramientas/ver_inventario.bat, o:
#    godot --path . res://tools/visores/dev_inventario.tscn
#  Guarda tools/salida/inventario_<n>_<pestaña>.png y se cierra solo.
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"
const MATS := ["cobre", "cobre_veteado", "cobre_profundo", "acero", "madera_comun", "madera_negra",
	"cuero_simple", "cuero_curtido", "baba_slime", "baba_venenosa", "nucleo_slime",
	"nucleo_minotauro", "carbon_veta", "carbon_negro", "ajo", "cebolla"]
const CONS := ["pocion_menor", "pocion_media", "pocion_mana_menor", "pocion_mana_media",
	"grimorio_bola_fuego", "grimorio_rayo", "plato_kebab_bestia", "plato_sopa_setas",
	"cebo_gusano", "piedra_retorno"]
const ARMAS := ["daga", "espada_corta", "espada_larga", "mandobles", "hacha_grande", "baston",
	"estoque", "maza_peq"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(1280, 720))
	_llenar()

	var inv: CanvasLayer = preload("res://scripts/ui/inventory_menu.gd").new()
	add_child(inv)
	inv._set_open(true)

	DirAccess.make_dir_recursive_absolute(SALIDA)
	for i in inv.TABS.size():
		inv._on_tab(i)
		# EQUIPO tiene tres SUBpestañas y son pantallas distintas: la del farolillo mezcla lamparas
		# con carbon y es la que mas cabecera tenia. Sin recorrerlas, la captura de "Equipo" solo
		# enseña una de las tres y las otras dos no las mira nadie.
		if String(inv.TABS[i]) == "Equipo":
			for j in inv.SUBS_EQUIPO.size():
				inv._on_sub_equipo(j)
				await _captura("%d_equipo_%s" % [i, String(inv.SUBS_EQUIPO[j]).to_lower()])
			continue
		await _captura("%d_%s" % [i, String(inv.TABS[i]).to_lower()])
		# ARMAS y ARMADURAS llevan fila de filtros: se captura ademas UNO puesto, para ver que la
		# rejilla se queda solo con lo suyo y que el subrayado se mueve. Con la de "todas" sola no
		# se comprueba nada de eso.
		if String(inv.TABS[i]) == "Armas":
			inv._on_filtro_armas(11)   # escudo pequeño: ademas prueba la rama de otra clase
			await _captura("%d_armas_filtrada" % i)
			inv._on_filtro_armas(0)
		elif String(inv.TABS[i]) == "Armaduras":
			inv._on_filtro_armadura(1)   # casco
			await _captura("%d_armaduras_filtrada" % i)
			inv._on_filtro_armadura(0)

	# LOS DOS MODALES DE LA BARRA DE ABAJO. Se abren sobre la pestaña que mejor los enseña: el de
	# orden sobre la BOLSA (que es la que tiene los criterios raros: peso y valor por peso) y el de
	# filtros sobre ARMADURAS (que es la que mas grupos tiene y donde se ven los recuentos).
	inv._on_tab(0)
	inv._abrir_modal_orden()
	await _captura("modal_orden")
	inv._cerrar_modal_barra()

	inv._on_tab(5)
	inv._abrir_modal_filtros()
	await _captura("modal_filtros")
	inv._cerrar_modal_barra()

	# Y una rejilla YA ORDENADA por valor por peso, que es el criterio propio: sin verla ordenada
	# no se sabe si el orden hace algo.
	inv._on_tab(0)
	inv._pulsa_criterio(2)   # "Valor por peso"
	await _captura("bolsa_por_valor_peso")

	# EL MODAL DE "¿A QUIEN SE LO DAS?", en sus dos estados: apuntando a alguien a quien SI se le
	# puede dar, y apuntando al que esta a tope de vida -- que es el que saca la franja roja y apaga
	# el boton de confirmar. Sin las dos, la mitad de la pantalla no se ha mirado.
	inv._on_tab(2)
	for nombre in CONS:
		var c: ConsumableData = load("res://resources/consumables/%s.tres" % nombre) as ConsumableData
		if c == null or not c.cura_hp():
			continue
		inv._abrir_modal_usar(c)
		await _captura("modal_usar")
		inv._usar_sel = 0   # el lider va a tope de vida en los datos de prueba
		inv._pintar_modal_usar()
		await _captura("modal_usar_bloqueado")
		inv._cerrar_modal_barra()
		break
	get_tree().quit()


func _captura(nombre: String) -> void:
	# DOS frames: el primero coloca los contenedores (hasta entonces las celdas miden 0 y la rejilla
	# aun no sabe cuantas columnas caben) y el segundo ya dibuja lo colocado.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var ruta: String = "%sinventario_%s.png" % [SALIDA, nombre]
	get_viewport().get_texture().get_image().save_png(ruta)
	print("[inventario] ", ProjectSettings.globalize_path(ruta))


# ============================================================
#  LLENAR LA PARTIDA
# ============================================================

func _llenar() -> void:
	Game.money = 48210
	Game.crystals = []
	Game.materiales = []
	Game.almacen_materiales = []

	# La BOLSA: cristales de varias calidades y un puñado de materiales de cada escala.
	for cat in [1, 2, 3, 5]:
		for cal in [Cristal.Calidad.INTACTO, Cristal.Calidad.NORMAL, Cristal.Calidad.DANADO]:
			for _n in 3:
				var cr := Cristal.new()
				cr.categoria = cat
				cr.calidad = cal
				Game.crystals.append(cr)
	var i: int = 0
	for id in MATS:
		var d: MaterialData = load("res://resources/materials/%s.tres" % id) as MaterialData
		if d == null:
			continue
		i += 1
		# Cantidades MUY distintas entre montones (de 1 a 400): es lo que enseña si la banda del pie
		# aguanta un "x412" sin que el numero se salga ni se encoja.
		for _n in (i * 7) % 40 + 1:
			var it := MaterialItem.new()
			it.data = d
			it.calidad = MaterialItem.Calidad.NORMAL
			Game.materiales.append(it)
		# El HOGAR (pestaña Materiales) con lo mismo pero en cantidades mayores.
		for _n in (i * 23) % 300 + 5:
			var it2 := MaterialItem.new()
			it2.data = d
			it2.calidad = MaterialItem.Calidad.INTACTO
			Game.almacen_materiales.append(it2)

	Game.consumables = {}
	var j: int = 0
	for id in CONS:
		var c: ConsumableData = load("res://resources/consumables/%s.tres" % id) as ConsumableData
		if c == null:
			continue
		j += 1
		Game.consumables[c] = (j * 5) % 47 + 1

	_armas()
	_armaduras()
	_equipo()
	_grupo()


# UN GRUPO DE CUATRO, con la vida a distintos niveles. Hace falta para el modal de "¿a quien se lo
# das?": con uno solo el menu ni lo abre (no hay nada que preguntar), asi que sin esto la pantalla
# que mas trabajo lleva es justo la que no se puede mirar.
#
# Las vidas van escalonadas a proposito -- uno a tope, uno tocado, uno muy tocado -- porque lo que
# hay que juzgar es si las BARRAS se comparan de un vistazo, y con todos iguales no se ve nada. El
# que esta a tope prueba ademas la franja roja de "esta a tope de vida, no se puede".
func _grupo() -> void:
	if Game.party.size() >= 4:
		return
	var base: PersonajeData = Game.lider()   # crea el original si aun no hay ninguno
	var nombres := ["Sedaki", "Nurit", "Bram"]
	var vidas := [1.0, 0.55, 0.18]
	for i in nombres.size():
		var pj: PersonajeData = base.duplicate(true) as PersonajeData
		pj.nombre = nombres[i]
		pj.es_original = false
		pj.color = Color.from_hsv(0.12 + 0.28 * float(i), 0.55, 0.85)
		Game.plantilla.append(pj)
		Game.party.append(pj)
	# Las vidas se ponen DESPUES de tener el grupo montado: player_max_hp mira las stats del
	# personaje, y la vida actual se guarda como valor absoluto.
	for i in Game.party.size():
		var pj2: PersonajeData = Game.party[i]
		var frac: float = 1.0 if i == 0 else float(vidas[mini(i - 1, vidas.size() - 1)])
		# current_hp / current_mp son los campos de la ficha; Game.player_hp los lee de ahi y devuelve
		# el maximo cuando valen -1 (o sea "a tope, sin tocar").
		pj2.current_hp = Game.player_max_hp(pj2) * frac
		pj2.current_mp = Game.player_max_mp(pj2) * clampf(frac + 0.15, 0.0, 1.0)


# La pestaña EQUIPO: mochilas, las cuatro herramientas, farolillos y carbon. Con una puesta de cada
# clase, que es lo unico que enseña si la marca de esquina "PUESTA" se ve en la rejilla.
func _equipo() -> void:
	Game.owned_mochilas = []
	var mo: BackpackData = load("res://resources/backpacks/mochila_basica.tres") as BackpackData
	if mo != null:
		for r in 4:
			var c: BackpackData = mo.duplicate() as BackpackData
			Game.item_meta[c] = {"tier": (r % 3) + 1, "rareza": r * 2, "mejoras": {},
				"durabilidad": 1.0, "banda": 0}
			Game.owned_mochilas.append(c)
		Game.mochila_equipo = Game.owned_mochilas[2]

	Game.owned_tools = []
	var r2: int = 0
	for id in ["pico_basico", "hoz_basica", "hacha_basica", "cana_basica", "farolillo_basico"]:
		var t: ToolData = load("res://resources/tools/%s.tres" % id) as ToolData
		if t == null:
			continue
		for k in 2:
			var c2: ToolData = t.duplicate() as ToolData
			Game.item_meta[c2] = {"tier": (r2 % 3) + 1, "rareza": (r2 * 3 + k) % 8, "mejoras": {},
				"durabilidad": 1.0, "banda": 0}
			Game.owned_tools.append(c2)
		r2 += 1

	# CARBON: dos calidades del mismo material, que es el caso que la cabecera vieja contaba mal
	# (cogia un trozo de muestra y daba SUS minutos para todo el monton).
	Game.carbon = []
	for id in ["carbon_veta", "carbon_negro", "carbon_vegetal"]:
		var d: MaterialData = load("res://resources/materials/%s.tres" % id) as MaterialData
		if d == null:
			continue
		for cal in [MaterialItem.Calidad.INTACTO, MaterialItem.Calidad.NORMAL]:
			for _n in 6:
				var it := MaterialItem.new()
				it.data = d
				it.calidad = cal
				Game.carbon.append(it)


# Las armas con LAS OCHO RAREZAS repartidas, que es lo que no sale en una partida normal y es justo
# lo que hay que mirar: si los ocho fondos se distinguen puestos uno al lado del otro.
func _armas() -> void:
	Game.owned_weapons = []
	var r: int = 0
	# DOS de cada tipo: con una sola por tipo, al filtrar quedaba siempre una celda suelta y no se
	# veia si la rejilla filtrada respira bien.
	for id in ARMAS:
		var w: WeaponData = load("res://resources/weapons/%s.tres" % id) as WeaponData
		if w == null:
			continue
		for k in 2:
			var copia: WeaponData = w.duplicate() as WeaponData
			Game.item_meta[copia] = {"tier": (r % 3) + 1, "rareza": (r * 2 + k) % 8, "mejoras": {},
				"durabilidad": 1.0 - float(r) * 0.09, "banda": 0}
			Game.owned_weapons.append(copia)
		r += 1
	# ESCUDOS Y VARITAS viven en el mismo baul que las armas (Game.owned_weapons), asi que sin
	# ellos las cuatro ultimas pestañas del filtro saldrian siempre vacias y no se veria si
	# funcionan.
	for carpeta in ["shields", "wands"]:
		var d := DirAccess.open("res://resources/%s/" % carpeta)
		if d == null:
			continue
		for f in d.get_files():
			if not f.ends_with(".tres"):
				continue
			var it: Resource = load("res://resources/%s/%s" % [carpeta, f])
			if it == null:
				continue
			var copia2: Resource = it.duplicate()
			Game.item_meta[copia2] = {"tier": (r % 3) + 1, "rareza": r % 8, "mejoras": {},
				"durabilidad": 1.0, "banda": 0}
			Game.owned_weapons.append(copia2)
			r += 1


func _armaduras() -> void:
	Game.owned_armor = []
	var d := DirAccess.open("res://resources/armor/")
	if d == null:
		return
	var r: int = 0
	for f in d.get_files():
		if not f.ends_with(".tres"):
			continue
		var a: ArmorData = load("res://resources/armor/" + f) as ArmorData
		if a == null:
			continue
		var copia: ArmorData = a.duplicate() as ArmorData
		Game.item_meta[copia] = {"tier": (r % 3) + 1, "rareza": r % 8, "mejoras": {},
			"durabilidad": 1.0, "banda": 0}
		Game.owned_armor.append(copia)
		r += 1
		if r >= 20:
			return
