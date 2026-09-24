// ============================================================
//  aura_imbue.gdshader
//  LA IMBUICION PUESTA: el arma HECHA del elemento (Filo) o el cuerpo envuelto en el (Manto).
//
//  Va en una COPIA de la capa (mismo SpriteFrames, mismo fotograma, ver MunecoJugador.poner_imbue),
//  asi que sigue al dibujo en cualquier animacion y direccion sin medir nada. Dos usos:
//    FILO    copia de las capas del ARMA, por ENCIMA del arma. La HOJA (los tonos de metal de la
//            rampa, ver ArmaSprites.ROLES: 5, 6 y 7) se repinta con los colores del elemento, con
//            vida por dentro, y de sus bordes sale lo que suelta el elemento: llamas, rayitos,
//            gotas... La empuñadura (tonos 3 y 4) no se toca. Referencias del usuario (24/09): espadas
//            de pixel-art "como si tuvieran realmente el elemento en el arma", no particulas encima.
//    MANTO   copias de TODAS las capas, por DETRAS del cuerpo: lo mismo, saliendo de la silueta.
//
//  SIN LINEAS (regla de los efectos): nada de contorno de un pixel alrededor; lo que sale del borde es
//  llama, chispa o gota, con nucleo duro y escalones de pixel.
//
//  Todo se mide en PIXELES DE LA TEXTURA (TEXTURE_PIXEL_SIZE), que es la rejilla del dibujo. Con un
//  AtlasTexture el UV recorre el atlas entero: los fotogramas horneados llevan aire alrededor, asi que
//  mirar unos pixeles al lado no se mete en el fotograma vecino. Arriba en la textura es arriba en
//  pantalla (cada direccion se hornea aparte), asi que el fuego sube y el veneno cae de verdad.
// ============================================================
shader_type canvas_item;

// La rampa del elemento: sombra, base, luz y el nucleo (lo mas encendido). Ver ImbueVisual.rampa.
uniform vec4 c_oscuro : source_color = vec4(0.12, 0.30, 0.05, 1.0);
uniform vec4 c_base : source_color = vec4(0.35, 0.72, 0.12, 1.0);
uniform vec4 c_claro : source_color = vec4(0.62, 0.95, 0.30, 1.0);
uniform vec4 c_nucleo : source_color = vec4(0.85, 1.0, 0.60, 1.0);
// Ver ImbueVisual.Modo: 0 LLAMA, 1 GOTA, 2 CHISPA, 3 ESTRELLA, 4 HUMO, 5 VENENO.
uniform int modo = 0;
// true = capa de ARMA: la hoja se vuelve del elemento y el efecto sale SOLO de ella.
uniform bool filo = false;
// La capa va por RAMPA DE INDICES (equipo: arma, armadura, escudo). Ahi el gris es el numero de tono,
// y el tono 1 es la SOMBRA DE SUELO, que no es cuerpo y no puede echar llamas.
uniform bool indexada = false;
uniform float tonos = 16.0;
uniform float fuerza : hint_range(0.0, 1.0) = 1.0;

// DONDE ACABA EL FOTOGRAMA de verdad, en UV del atlas (x0, y0, x1, y1). Lo pone aura_capa.gd, que
// dibuja el trozo con aire alrededor: lo de fuera de aqui es el aire (o el fotograma vecino de la
// hoja) y se lee como vacio.
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);

vec4 leer(sampler2D tx, vec2 uv) {
	if (uv.x < region.x || uv.y < region.y || uv.x > region.z || uv.y > region.w) {
		return vec4(0.0);
	}
	return texture(tx, uv);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

int tono(vec4 t) {
	float l = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	return int(floor(l * (tonos - 1.0) + 0.5));
}

bool es_hoja(vec4 t) {
	if (t.a < 0.5) {
		return false;
	}
	int i = tono(t);
	return i >= 5 && i <= 7;
}

// ¿De este pixel sale el efecto? El Filo, de la hoja; el Manto, de todo lo que sea cuerpo.
bool fuente(sampler2D tx, vec2 uv) {
	vec4 t = leer(tx, uv);
	if (filo) {
		return es_hoja(t);
	}
	if (t.a < 0.6) {
		return false;
	}
	return !indexada || tono(t) != 1;
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 celda = floor(UV / px);
	vec2 uv = (celda + 0.5) * px;
	vec4 t = leer(TEXTURE, uv);
	float tt = TIME;
	bool aqui = fuente(TEXTURE, uv);
	vec4 res = vec4(0.0);

	if (filo && aqui) {
		// ---------------- LA HOJA, HECHA DEL ELEMENTO ----------------
		int i = tono(t);
		vec3 c = i == 5 ? c_oscuro.rgb : (i == 6 ? c_base.rgb : c_claro.rgb);
		if (modo == 0) {
			// Fuego: la hoja arde por dentro, con vetas que SUBEN.
			float n = hash(vec2(celda.x, floor(celda.y + tt * 9.0)));
			if (n > 0.78) { c = c_nucleo.rgb; } else if (n > 0.52) { c = c_claro.rgb; } else if (n < 0.12) { c = c_oscuro.rgb; }
		} else if (modo == 1) {
			// Agua: un reflejo que recorre la hoja en diagonal.
			float b = abs(fract((celda.x + celda.y) * 0.07 - tt * 0.55) - 0.5);
			if (b < 0.05) { c = c_nucleo.rgb; }
		} else if (modo == 2) {
			// Rayo: la hoja parpadea y le saltan pixeles blancos.
			if (hash(celda + floor(tt * 16.0)) > 0.84) { c = c_nucleo.rgb; }
			else if (hash(vec2(floor(tt * 11.0), 1.0)) > 0.6) { c = mix(c, c_claro.rgb, 0.6); }
		} else if (modo == 3) {
			// Luz: la hoja respira hacia el blanco.
			c = mix(c, c_nucleo.rgb, 0.25 + 0.2 * sin(tt * 2.6));
		} else if (modo == 4) {
			// Oscuridad: remolinos lentos que suben.
			float n = hash(vec2(floor(celda.x / 2.0), floor(celda.y / 2.0 + tt * 2.5)));
			if (n > 0.8) { c = c_claro.rgb; } else if (n < 0.3) { c = c_oscuro.rgb; }
		} else {
			// Veneno: burbujas que suben por dentro de la hoja.
			float n = hash(vec2(celda.x, floor(celda.y + tt * 3.5)));
			if (n > 0.9) { c = c_nucleo.rgb; } else if (n < 0.14) { c = c_oscuro.rgb; }
		}
		res = vec4(c, 1.0);
	} else if (filo && t.a >= 0.5 && tono(t) == 2) {
		// EL CONTORNO DE LA HOJA, del oscuro del elemento (el de la empuñadura se queda como esta).
		bool junto = es_hoja(leer(TEXTURE, uv + vec2(px.x, 0.0))) || es_hoja(leer(TEXTURE, uv - vec2(px.x, 0.0)))
			|| es_hoja(leer(TEXTURE, uv + vec2(0.0, px.y))) || es_hoja(leer(TEXTURE, uv - vec2(0.0, px.y)));
		if (junto) {
			res = vec4(c_oscuro.rgb * 0.55, 1.0);
		}
	} else if (!aqui && t.a < 0.5) {
		// ---------------- FUERA: LO QUE SUELTA EL ELEMENTO ----------------
		// Lo cerca que esta de la fuente, en pixeles (hasta 3).
		float d = 9.0;
		for (int y = -3; y <= 3; y++) {
			for (int x = -3; x <= 3; x++) {
				if (fuente(TEXTURE, uv + vec2(float(x), float(y)) * px)) {
					d = min(d, length(vec2(float(x), float(y))));
				}
			}
		}
		// Un resplandor corto pegado a la fuente: duro el primer pixel y a escalones despues.
		float late = 0.85 + 0.15 * sin(tt * 3.0);
		float a = 0.0;
		if (d <= 1.01) { a = filo ? 0.45 : 0.5; } else if (d <= 2.01) { a = filo ? 0.18 : 0.3; } else if (d <= 3.01 && !filo) { a = 0.14; }
		vec3 c = c_base.rgb;
		a *= late;

		float h = hash(vec2(celda.x, 7.0));
		if (modo == 0 || modo == 4) {
			// LLAMAS (y el humo de la oscuridad, mas largo y mas lento): lenguas que suben desde la fuente.
			float vel = modo == 0 ? 9.0 : 4.0;
			float tope = modo == 0 ? 8.0 : 9.0;
			// Una lengua cada DOS columnas (y que se come la de al lado al mirar abajo): de un pixel de
			// ancho se leian como pelos, no como fuego.
			float grupo = floor(celda.x / 2.0);
			float hg = hash(vec2(grupo, 3.0));
			float largo = 2.0 + tope * hash(vec2(grupo, floor(tt * vel + hg * 5.0)));
			for (int k = 1; k <= 10; k++) {
				float fk = float(k);
				if (fk > largo) { break; }
				// El humo ondula de lado a lado segun sube.
				float lado = modo == 4 ? floor(sin(celda.y * 0.6 + tt * 2.0) + 0.5) : 0.0;
				// Las lenguas se estrechan hacia la punta: abajo miran tambien a los lados.
				// Desde el SEGUNDO pixel: con los lados mirados ya en el primero, cada costado vertical del
				// dibujo se encendia entero de nucleo y salia una raya amarilla pegada al cuerpo (una LINEA).
				float ancho = (fk >= 2.0 && fk < largo * 0.6) ? 1.0 : 0.0;
				if (fuente(TEXTURE, uv + vec2(lado, fk) * px) || fuente(TEXTURE, uv + vec2(lado - ancho, fk) * px)
						|| fuente(TEXTURE, uv + vec2(lado + ancho, fk) * px)) {
					float f = fk / (largo + 0.5);
					if (modo == 0) {
						c = f < 0.3 ? c_nucleo.rgb : (f < 0.6 ? c_claro.rgb : (f < 0.85 ? c_base.rgb : c_oscuro.rgb));
						a = 1.0;
					} else {
						c = f < 0.4 ? c_base.rgb : c_oscuro.rgb;
						a = max(a, 0.85 - f * 0.5);
					}
					break;
				}
			}
			// Brasas sueltas que suben un poco mas arriba.
			if (modo == 0 && a < 0.5 && hash(vec2(celda.x, floor(celda.y + tt * 7.0))) > 0.985) {
				for (int k = 3; k <= 10; k++) {
					if (fuente(TEXTURE, uv + vec2(0.0, float(k)) * px)) { c = c_claro.rgb; a = 1.0; break; }
				}
			}
		} else if (modo == 1 || modo == 5) {
			// GOTAS: de algunas columnas cae una gota desde el borde de abajo de la fuente. Primero cuelga
			// (se hincha pegada), luego se suelta y cae.
			if (h > 0.5) {
				float fase = fract(tt * (0.45 + h * 0.4) + h * 13.0);
				if (fase < 0.35) {
					if (fuente(TEXTURE, uv - vec2(0.0, 1.0) * px)) { c = c_claro.rgb; a = 1.0; }
				} else {
					float y_gota = 1.0 + floor((fase - 0.35) / 0.65 * 11.0);
					if (fuente(TEXTURE, uv - vec2(0.0, y_gota) * px)) {
						bool libre = !fuente(TEXTURE, uv - vec2(0.0, max(1.0, y_gota - 1.0)) * px) || y_gota <= 1.0;
						if (libre) { c = modo == 5 ? c_claro.rgb : c_nucleo.rgb; a = 1.0; }
					}
				}
			}
			// El veneno ademas burbujea: pompas que suben un poco y revientan.
			if (modo == 5 && a < 0.5 && hash(vec2(celda.x, floor(celda.y + tt * 4.0))) > 0.975) {
				for (int k = 1; k <= 4; k++) {
					if (fuente(TEXTURE, uv + vec2(0.0, float(k)) * px)) { c = c_nucleo.rgb; a = 1.0; break; }
				}
			}
		} else if (modo == 2) {
			// RAYITOS: rayos quebrados de pixel que saltan desde el arma y cambian muy deprisa. La zona se
			// parte en celdas de 6x6; cada celda que TOCA la hoja tira un dado en cada destello y, si
			// sale, la cruza un rayo en zigzag (cada paso sube o baja un pixel al azar, acumulado: asi
			// sale una linea quebrada y no pixeles sueltos). Horizontal o vertical, segun la celda.
			float slot = floor(tt * 12.0);
			vec2 cel = floor(celda / 6.0);
			float n = hash(cel + vec2(slot, 0.0));
			// En el Manto el cuerpo entero es fuente: con el mismo dado salia una maraña. Menos a menudo.
			if (n > (filo ? 0.3 : 0.72)) {
				// ¿La celda (con dos pixeles de borde) toca la fuente? Una rejilla de 4x4 muestras.
				bool toca = false;
				for (int yy = 0; yy < 4; yy++) {
					for (int xx = 0; xx < 4; xx++) {
						vec2 q = (cel * 6.0 - 2.0 + vec2(float(xx), float(yy)) * 3.0) + 0.5;
						if (fuente(TEXTURE, q * px)) { toca = true; }
					}
				}
				if (toca) {
					vec2 l = celda - cel * 6.0;
					bool horiz = hash(cel + vec2(slot, 9.0)) > 0.5;
					float a_lo = horiz ? l.x : l.y;      // a lo largo del rayo
					float cruz = horiz ? l.y : l.x;      // de lado
					float y = floor(hash(cel + vec2(slot, 4.0)) * 6.0);
					for (int s = 0; s < 6; s++) {
						if (float(s) >= a_lo) { break; }
						y += floor(hash(cel + vec2(slot, float(s) + 20.0)) * 3.0) - 1.0;
					}
					y = clamp(y, 0.0, 5.0);
					if (abs(cruz - y) < 0.5) {
						c = hash(celda + vec2(slot, 2.0)) > 0.35 ? c_nucleo.rgb : c_claro.rgb;
						a = 1.0;
					}
				}
			}
			a *= 0.8 + 0.2 * step(0.5, hash(vec2(floor(tt * 20.0), 3.0)));
		} else if (modo == 3) {
			// DESTELLOS DE ESTRELLA: una cruz que crece y se apaga, de vez en cuando, pegada a la fuente.
			// Luz: ademas un resplandor mas ancho que el de los demas.
			if (d <= 3.01 && a < 0.2) { a = 0.2 * late; c = c_claro.rgb; }
			vec2 cel = floor(celda / 7.0);
			float n = hash(cel + vec2(floor(tt * 2.5), 5.0));
			if (n > 0.55 && d <= 3.01) {
				vec2 centro = cel * 7.0 + 3.0;
				vec2 r = abs(celda - centro);
				float brazo = floor(3.5 * sin(fract(tt * 2.5) * 3.14159));
				if (r.x + r.y < 0.5) { c = c_nucleo.rgb; a = 1.0; }
				else if ((r.x < 0.5 && r.y <= brazo) || (r.y < 0.5 && r.x <= brazo)) { c = c_claro.rgb; a = 1.0; }
			}
		}
		res = vec4(c, a);
	}
	// SIN multiplicar por COLOR: en Godot 4 llega YA multiplicado por la textura (ver paleta_equipo), y
	// fuera del dibujo su alfa es 0 -- justo donde vive todo lo de este shader.
	res.a = clamp(res.a * fuerza, 0.0, 1.0);
	COLOR = res;
}
