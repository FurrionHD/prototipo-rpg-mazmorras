// EL TINTE DE LOS EFECTOS EN PIXEL ART (04/11/2026): lo pintado en rojo puro 40/80/120/160/200 sale de estos cinco colores (los
// cuatro tonos y el borde: el color de quien lo lanza); lo demas (polvo, sombra...) tal cual. Sin mezclas: sigue siendo pixel art.
shader_type canvas_item;
uniform vec4 p0 : source_color;
uniform vec4 p1 : source_color;
uniform vec4 p2 : source_color;
uniform vec4 p3 : source_color;
uniform vec4 p4 : source_color;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a > 0.5 && c.g < 0.02 && c.b < 0.02) {
		float i = round(c.r * 255.0 / 40.0);
		vec4 t = i < 1.5 ? p0 : (i < 2.5 ? p1 : (i < 3.5 ? p2 : (i < 4.5 ? p3 : p4)));
		COLOR = vec4(t.rgb, c.a);
	} else {
		COLOR = c;
	}
}
