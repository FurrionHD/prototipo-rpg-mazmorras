extends Node2D

# Tienda: presionar F para vender SOLO cristales por dinero
# Precio = valor_base(categoria^2) × multiplicador_calidad × (1 ± azar 20%)

func _ready() -> void:
	add_to_group("interactable")


func interact_with_player() -> void:
	if Game.crystals.is_empty():
		print("[Tienda] No tienes cristales para vender.")
		return

	var total_dinero: int = 0
	var cantidad: int = 0

	# Vender todos los cristales.
	for cristal in Game.crystals:
		var precio_base: int = cristal.valor_estimado()
		var azar: float = randf_range(-0.2, 0.2)
		var precio_final: int = maxi(1, int(round(precio_base * (1.0 + azar))))
		total_dinero += precio_final
		cantidad += 1

	Game.money += total_dinero
	Game.crystals.clear()
	print("[Tienda] Vendiste %d cristales por %d monedas. Total dinero: %d" % [
		cantidad, total_dinero, Game.money])
