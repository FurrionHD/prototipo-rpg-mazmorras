# ============================================================
#  turn_timeline.gd  (Control dibujado por codigo)
#  Linea de ORDEN DE TURNOS estilo Epic Seven: una barra horizontal con los
#  "iconos" de los combatientes, que avanzan segun su velocidad hacia el
#  punto de accion (derecha). Al llegar, ese actua y su icono vuelve al
#  principio. Placeholder: iconos = cuadrados de color con una letra.
# ============================================================

extends Control

var _player_ratio: float = 0.0   # 0..1 (cuanto lleno tiene su turno)
var _enemy_ratio: float = 0.0
var _player_color: Color = Color(0.3, 0.7, 1.0)
var _enemy_color: Color = Color(1.0, 0.4, 0.3)


func set_ratios(player_ratio: float, enemy_ratio: float) -> void:
	_player_ratio = clampf(player_ratio, 0.0, 1.0)
	_enemy_ratio = clampf(enemy_ratio, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var y: float = size.y * 0.5
	var x0: float = 40.0
	var x1: float = size.x - 40.0

	# Linea de la barra.
	draw_line(Vector2(x0, y), Vector2(x1, y), Color(0.45, 0.45, 0.5), 3.0)
	# Punto de accion (derecha).
	draw_line(Vector2(x1, y - 16.0), Vector2(x1, y + 16.0), Color(1, 1, 1), 2.0)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(x1 - 30.0, y - 22.0), "ACCION", HORIZONTAL_ALIGNMENT_LEFT, -1, 12)

	# Iconos (el que va mas adelantado se dibuja encima).
	if _enemy_ratio >= _player_ratio:
		_draw_icono(x0 + _player_ratio * (x1 - x0), y, _player_color, "TU")
		_draw_icono(x0 + _enemy_ratio * (x1 - x0), y, _enemy_color, "EN")
	else:
		_draw_icono(x0 + _enemy_ratio * (x1 - x0), y, _enemy_color, "EN")
		_draw_icono(x0 + _player_ratio * (x1 - x0), y, _player_color, "TU")


func _draw_icono(x: float, y: float, color: Color, letra: String) -> void:
	var r: float = 16.0
	draw_rect(Rect2(x - r, y - r, r * 2.0, r * 2.0), color)
	draw_rect(Rect2(x - r, y - r, r * 2.0, r * 2.0), Color(0, 0, 0), false, 2.0)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(x - 12.0, y + 6.0), letra, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)
