# HERRAMIENTA. No forma parte del juego.
#
#   godot --headless --path . res://tools/prueba_pesca_recoger.tscn
#
# RECOGER EL SEDAL CON UN PEZ PICANDO (playtest 09/10: "si al enganchar un pez pulsas F en vez de espacio se queda
# bugueado para siempre"). Mira que el pez que picaba (PICANDO o TIRON) se suelta y vuelve a la cola, como cuando
# tiras tarde; que esperando (ESPERA) los peces siguen nadando; y que el cartel de la F se esconde con un modal.
# (Etapa 4) El charco del jugador es un ESPEJO: el banco es de la sala, que saca el pez del agua al enterarse
# (Net.pesca.resolver_pesca) y lo devuelve con la siguiente foto. Aqui se mira lo del jugador: suelta el pez.
extends Node

var _mal := 0


func _ok(cond: bool, que: String) -> void:
	if cond:
		print("  ok   ", que)
	else:
		_mal += 1
		print("  MAL: ", que)


func _sitio(estado: int) -> Node:
	var f = load("res://scripts/world/fishing_spot.gd").new()
	var spr := Sprite2D.new()
	add_child(spr)
	var pez: Dictionary = {"spr": spr, "data": null, "cm": 20.0, "nonce": 7}
	f._peces = [pez]
	f._pez = pez
	f._estado = estado
	return f


func _ready() -> void:
	for est in [4, 5]:   # PICANDO, TIRON
		var f = _sitio(est)
		f._soltar_el_pez()
		_ok(f._escapados.size() == 1 and int(f._escapados[0]["nonce"]) == 7, "estado %d: y vuelve a la cola (escapado)" % est)
		_ok(f._pez.is_empty(), "estado %d: ya no hay pez enganchado" % est)
	var f2 = _sitio(3)   # ESPERA: nadie picaba
	f2._soltar_el_pez()
	_ok(f2._peces.size() == 1 and f2._escapados.is_empty(), "esperando: los peces siguen en el agua")
	print("")
	print("FIN: TODO BIEN" if _mal == 0 else "FIN: %d MAL" % _mal)
	get_tree().quit(1 if _mal > 0 else 0)
