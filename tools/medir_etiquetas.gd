extends Node
# Mide en pixeles, con la fuente y el tamaño reales del tema, lo que ocupan las etiquetas de las fichas (pase de
# textos 06/11: con los nombres completos hay que saber cuanto ensanchar la columna, no adivinarlo). Sin ventana:
#   godot --headless --path . res://tools/medir_etiquetas.tscn

const ETIQUETAS := [
	"Multiplicador de daño", "Probabilidad de crítico", "Probabilidad de aturdir", "Acierto", "Esquiva",
	"Resistencia a estados", "Resistencia a críticos", "Penalización a la esquiva", "Amplificación mágica",
	"Regeneración de maná", "Velocidad de recitado", "Daño crítico mágico", "Ignora Defensa",
	"Probabilidad de crítico mágico", "Daño con el tiempo recibido", "Curación recibida",
	"Defensa mágica de la pieza", "Reducción mágica de la pieza", "Respuesta al bloquear", "Alcance 5 pisos más abajo",
	"Defensa al bloquear", "Ataque mágico",
	"13/13 (100 %)", "100/100 (100 %)", "+3 pts máx", "+12 pts máx", "(+0,4)", "(+7 %)", "×1,35", "+19,7 %", "+31 %",
]


func _ready() -> void:
	await get_tree().process_frame
	var l := Label.new()
	add_child(l)
	var fuente: Font = l.get_theme_font("font")
	var tam: int = l.get_theme_font_size("font_size")
	print("fuente: %s  tamaño: %d" % [fuente.resource_path if fuente.resource_path != "" else str(fuente), tam])
	var maxw: float = 0.0
	for e in ETIQUETAS:
		var w: float = fuente.get_string_size(e, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		maxw = maxf(maxw, w)
		print("%4d  %s" % [roundi(w), e])
	print("MAS ANCHA: %d px" % roundi(maxw))
	get_tree().quit()
