extends Node2D

# Tienda: presionar F para vender SOLO cristales por dinero.
# Precio de cada cristal = valor_estimado (categoria^2 x calidad) con un
# margen ALEATORIO de +/- PRECIO_AZAR (20%) para arriba o para abajo.

# Margen de aleatoriedad del precio respecto al valor estimado (0.2 = +/-20%).
const PRECIO_AZAR := 0.2

func _ready() -> void:
	add_to_group("interactable")


func interact_with_player() -> void:
	if Game.crystals.is_empty():
		print("[Tienda] No tienes cristales para vender.")
		return

	var total_dinero: int = 0
	var cantidad: int = 0

	# Vender todos los cristales. Cada uno tira su propio +/-20%.
	for cristal in Game.crystals:
		var estimado: int = cristal.valor_estimado()
		var azar: float = randf_range(-PRECIO_AZAR, PRECIO_AZAR)
		var precio_final: int = maxi(1, int(round(estimado * (1.0 + azar))))
		total_dinero += precio_final
		cantidad += 1
		# Desglose por cristal para VER la aleatoriedad (estimado -> real).
		print("[Tienda]   Cat %d (%s): estimado %d -> vendido %d" % [
			cristal.categoria, cristal.calidad_texto(), estimado, precio_final])

	Game.money += total_dinero
	Game.crystals.clear()
	print("[Tienda] Vendiste %d cristales por %d monedas. Total dinero: %d" % [
		cantidad, total_dinero, Game.money])
