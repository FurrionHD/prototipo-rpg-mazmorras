# LOS EFECTOS EN PIXEL ART (04/11/2026, memoria efectos-a-pixel-art). Que cada hoja apuntada exista y mida lo que dice, que salgan
# con su tinte, que respeten la espera, los dos ritmos y el final, y que SlimeAire use lo horneado cuando le toca (y lo viejo
# cuando no: lo que aun no se ha horneado sigue saliendo).
#   godot --headless --path . res://tools/prueba_efectos_pixel.tscn
extends Node

const _DATOS := preload("res://scripts/fx/efectos_pixel_datos.gd")

var _mal: int = 0


func _ready() -> void:
	call_deferred("_correr")


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _correr() -> void:
	print("1) LAS HOJAS: existen y miden lo que dicen")
	var total: int = 0
	var rotas: Array = []
	for enemigo in _DATOS.HOJAS:
		var hojas: Dictionary = _DATOS.HOJAS[enemigo]
		for nombre in hojas:
			var d: Dictionary = hojas[nombre]
			total += 1
			for suf in ["s", "a"]:
				var medida = d.get(suf)
				if medida == null:
					continue
				var tex: Texture2D = load(EfectoPixel.CARPETA % [enemigo, nombre, suf])
				if tex == null or tex.get_width() != int(medida[0]) * int(d["n"]) or tex.get_height() != int(medida[1]) * int(d["filas"]):
					rotas.append("%s/%s_%s" % [enemigo, nombre, suf])
	_ver(rotas.is_empty(), "las %d hojas, todas bien %s" % [total, str(rotas) if not rotas.is_empty() else ""])

	print("2) EL TINTE Y LOS RITMOS")
	var col := Color(0.29, 0.78, 0.33)
	var pal: PackedColorArray = SlimeAire.paleta_pixel(col)
	_ver(pal.size() == 5, "la paleta son cinco colores")
	var e: EfectoPixel = EfectoPixel.lanzar(self, "slime", "placaje_c", Vector2.ZERO, 6, null, 0.5, -1.0, 1.0, pal)
	_ver(e != null and e.num_capas() == 2, "sale con sus dos capas")
	var s: Sprite2D = e.get_child(0)
	_ver(s.material is ShaderMaterial and (s.material as ShaderMaterial).get_shader_parameter("p1") == pal[1], "lleva el color de quien lo lanza")
	_ver(s.flip_h, "hacia el oeste va en espejo")
	_ver(not s.visible, "con espera, aun no se ve")
	e.set_process(false)
	e._t = 0.1
	_ver(s.visible and e.marco_actual() == 2, "a 25 fps, a 0,1 s va por el marco 2")
	e._t = 0.24 + 1.0 / 11.0
	_ver(e.marco_actual() == 7, "tras el corte va a su otro ritmo (11 fps): un marco por 0,09 s")
	e._t = e.duracion() + 0.01
	_ver(not s.visible, "acabado, no se ve")
	e.queue_free()
	var sin: EfectoPixel = EfectoPixel.lanzar(self, "escarabajo", "coraza", Vector2.ZERO)
	_ver(sin != null and (sin.get_child(0) as Sprite2D).material == null, "sin paleta (el escarabajo), su hoja tal cual")
	if sin != null:
		sin.queue_free()
	_ver(EfectoPixel.lanzar(self, "slime", "no_existe", Vector2.ZERO) == null, "una hoja que no existe no revienta")

	print("3) SLIMEAIRE: lo horneado cuando le toca")
	var semilla: int = SlimeAire.semilla_con_color(9, col)
	var linea := CombatFormas.linea(Vector2.ZERO, Vector2.RIGHT, 40.0, 16.0)
	_ver(SlimeAire.area(self, linea, SlimeAire.Modo.PLACAJE, semilla, 0.0) is EfectoPixel, "el Placaje, en pixel")
	var ancha := CombatFormas.linea(Vector2.ZERO, Vector2.RIGHT, 70.0, 70.0)
	_ver(SlimeAire.area(self, ancha, SlimeAire.Modo.PLACAJE, semilla, 0.0) is SlimeAire, "la Embestida cortante (aun sin hornear), como antes")
	_ver(SlimeAire.area(self, CombatFormas.circulo(Vector2.ZERO, 35.0), SlimeAire.Modo.SPLAT, semilla, 0.0) is EfectoPixel, "el Reventon, en pixel")
	_ver(SlimeAire.area(self, CombatFormas.circulo(Vector2.ZERO, 50.0), SlimeAire.Modo.SPLAT, semilla, 0.0) is SlimeAire, "la Nube de ceniza (aun sin hornear), como antes")
	_ver(SlimeAire.sobre_cuerpo(self, SlimeAire.Modo.GOLPE, Vector2.ZERO, Rect2(30, 0, 20, 30), col, semilla, 0.05, 1.0) is EfectoPixel, "el basico, en pixel")
	_ver(SlimeAire.sobre_cuerpo(self, SlimeAire.Modo.ESCUPE, Vector2.ZERO, Rect2(30, 0, 20, 30), col, semilla, 0.05, 1.0) is SlimeAire, "el Escupitajo (aun sin hornear), como antes")
	# La embestida estira el efecto a lo que tarda el cuerpo en cruzar, como a los demas (SueloRoto lo busca por nombre).
	var n: Node2D = SueloRoto.lanzar(self, linea, SueloRoto.Tipo.SLIME_PLACAJE, semilla)
	_ver(n != null and float(n.get("_ritmo")) != 1.0 or SueloRoto.t_salir_de(SueloRoto.Tipo.SLIME_PLACAJE) == SueloRoto.t_embestida(linea), "la embestida le ajusta el ritmo")
	for h in get_children():
		h.queue_free()
	print("%s" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)
