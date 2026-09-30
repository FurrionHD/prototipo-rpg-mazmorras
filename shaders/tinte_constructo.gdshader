// EL TONO DE LA ARCILLA DEL GOLEM (30/09/2026, Barro cocido): terracota mientras esta cocido o endurecido y barro
// mojado (mas oscuro, con brillo) mientras esta blando. Va por shader y no por el modulate porque el modulate del
// sprite lo reescribe el aviso del golpe cada fotograma (ver enemy._actualizar_indicadores). Lo sube y lo baja
// CombatTactico._tick_barro. El tinte del nodo se coge en vertex(): en el fragment COLOR ya trae la textura.
// Y LA GARGOLA POSADA (30/09, 'piedra'): gris de estatua, sin color y sin brillo (lo claro se apaga, tambien los
// ojos). Lo sube y lo baja CombatTactico._tick_estatua.
shader_type canvas_item;

uniform vec3 tinte = vec3(1.0, 1.0, 1.0);
uniform float fuerza : hint_range(0.0, 1.0) = 0.0;
uniform float humedo : hint_range(0.0, 1.0) = 0.0;   // el brillo del barro mojado
uniform float piedra : hint_range(0.0, 1.0) = 0.0;   // la estatua: gris y mate

varying vec4 modul;

void vertex() {
	modul = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (fuerza > 0.001 && c.a > 0.5) {
		vec3 t = c.rgb * tinte;
		// MOJADO: un brillo en los pixeles claros que late despacio (como agua escurriendo).
		float luz = dot(c.rgb, vec3(0.3, 0.55, 0.15));
		float brillo = humedo * smoothstep(0.45, 0.75, luz) * (0.6 + 0.4 * sin(TIME * 2.5 + UV.y * 40.0));
		t += vec3(0.35, 0.38, 0.42) * brillo;
		// ESTATUA: todo al gris de su luz, y lo claro aplastado (mate: sin brillo en el lomo ni en los ojos).
		float l = dot(t, vec3(0.3, 0.55, 0.15));
		vec3 gris = vec3(l * (1.0 - 0.4 * smoothstep(0.45, 0.9, l)) * 0.95 + 0.02);
		t = mix(t, gris, piedra);
		c.rgb = mix(c.rgb, t, fuerza);
	}
	COLOR = c * modul;
}
