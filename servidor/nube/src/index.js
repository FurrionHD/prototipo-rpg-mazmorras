// ============================================================
//  LA NUBE de los mundos compartidos (Cloudflare Worker + un Durable Object por mundo)
//
//  Es el MISMO portero que scripts/net/cloud_store_local.gd, pasado a JavaScript: test-and-set del
//  cerrojo, contraseña con huella, arrendamiento con latido y token de vallado. Si cambias una regla
//  aqui, cambiala alli tambien (las pruebas del juego usan el local).
//
//  POR QUE UN DURABLE OBJECT POR MUNDO y no KV: KV es "eventualmente consistente" y no tiene
//  test-and-set, asi que dos personas abriendo a la vez podrian salir las DOS como anfitrion, que es
//  justo el desastre que evita todo el diseño. Un Durable Object atiende las peticiones de SU mundo de
//  una en una, y eso es el cerrojo.
//
//  EL SAVE VA DENTRO DEL OBJETO, en trozos de 1 MB (cada valor admite 2 MB como mucho y un mundo ya
//  pesa 4). Asi no hace falta R2, que pide tarjeta aunque sea gratis.
//
//  PROTOCOLO (todo POST, a /v1/<op>?id=<24 hex>; la contraseña va en la cabecera X-Pass,
//  codificada con encodeURIComponent, para que no salga en las URLs de los registros):
//    crear                         -> {ok}
//    abrir   JSON {direcciones, sello_version, sello_build, forzar_build, quien_soy, quien, pid,
//                  equipo, reclamar}
//                                  -> {ok, resultado: host|unirse|comprobar, ...}
//    bajar   X-Token               -> los bytes del save (200) o JSON de error (409)
//    latido  X-Token               -> {ok}
//    subir   X-Token, X-Sello-Version, X-Sello-Build, X-Meta; cuerpo = bytes del save -> {ok}
//    cerrar  igual que subir, y ademas suelta el cerrojo -> {ok}
//    estado                        -> {ok, abierto, caducado, quien, direcciones?, meta, ...}
//  Las respuestas son siempre {"ok": bool} y, si falla, "error" (codigo estable) y "mensaje".
// ============================================================

import { DurableObject } from "cloudflare:workers";

// Cuanto vive un arrendamiento sin latido. El juego late cada 30 s (Nube.SEGUNDOS_LATIDO).
const SEGUNDOS_ARRENDAMIENTO = 120;
const TROZO = 1024 * 1024;
const MAX_SAVE = 48 * 1024 * 1024;
const ID_VALIDO = /^[0-9a-f]{24}$/;
const OPS = new Set(["crear", "abrir", "bajar", "latido", "subir", "cerrar", "estado"]);

export default {
	async fetch(req, env) {
		const url = new URL(req.url);
		if (req.method === "GET" && url.pathname === "/") {
			return new Response("Dungeon Oratoria: nube de mundos compartidos\n");
		}
		const partes = url.pathname.split("/").filter((p) => p !== "");
		if (req.method !== "POST" || partes.length !== 2 || partes[0] !== "v1" || !OPS.has(partes[1])) {
			return json(fallo("peticion_mala", "Esa petición no existe."), 404);
		}
		const id = url.searchParams.get("id") || "";
		if (!ID_VALIDO.test(id)) {
			return json(fallo("peticion_mala", "El código de mundo no es válido."), 400);
		}
		const talla = parseInt(req.headers.get("content-length") || "0", 10);
		if (talla > MAX_SAVE) {
			return json(fallo("demasiado_grande", "La partida es demasiado grande para subirla."), 413);
		}
		const obj = env.MUNDO.get(env.MUNDO.idFromName(id));
		return obj.fetch(req);
	},
};

export class Mundo extends DurableObject {
	async fetch(req) {
		const url = new URL(req.url);
		const op = url.pathname.split("/").pop();
		const id = url.searchParams.get("id");
		const pass = cabecera(req, "x-pass");
		// El cuerpo se lee ANTES de tocar nada: leerlo es esperar a la red, y mientras se espera a la red
		// el objeto puede atender otra peticion. Lo que va despues solo espera al almacenamiento, y eso
		// no deja colarse a nadie: el test-and-set queda de una pieza.
		let cuerpo = null;
		if (op === "subir" || op === "cerrar") {
			cuerpo = new Uint8Array(await req.arrayBuffer());
		} else if (op === "abrir") {
			try {
				cuerpo = await req.json();
			} catch {
				cuerpo = {};
			}
		}
		switch (op) {
			case "crear":
				return json(await this.crear(id, pass));
			case "abrir":
				return json(await this.abrir(id, pass, cuerpo || {}));
			case "bajar":
				return await this.bajar(id, pass, entero(req, "x-token"));
			case "latido":
				return json(await this.latido(id, pass, entero(req, "x-token")));
			case "subir":
			case "cerrar":
				return json(await this.subir(id, pass, entero(req, "x-token"), cuerpo, {
					sello_version: entero(req, "x-sello-version"),
					sello_build: cabecera(req, "x-sello-build"),
					meta: meta(req),
				}, op === "cerrar"));
			case "estado":
				return json(await this.estado(id, pass));
		}
		return json(fallo("peticion_mala", "Esa petición no existe."), 404);
	}

	// ---- ALTA ----
	async crear(id, pass) {
		if (!pass) {
			return fallo("peticion_mala", "Hace falta un id de mundo y una contraseña.");
		}
		if (await this.ctx.storage.get("mundo")) {
			return fallo("ya_existe", "Ese mundo ya existe.");
		}
		await this.ctx.storage.put("mundo", {
			id,
			pass: await huella(id, pass),   // nunca la contraseña en claro
			token: 0,                       // contador de vallado: sube en CADA apertura
			creado: ahora(),
			meta: {},
			sello_version: 0,
			sello_build: "",
			trozos: 0,
			bytes: 0,
		});
		return { ok: true, id };
	}

	// ---- ABRIR: test-and-set del cerrojo ----
	async abrir(id, pass, p) {
		const mundo = await this.leerMundo(id, pass);
		if (!mundo) {
			return noAutorizado();
		}
		const quienSoy = String(p.quien_soy || "");
		const cerrojo = await this.ctx.storage.get("cerrojo");
		if (cerrojo) {
			const esMio = quienSoy !== "" && cerrojo.identidad === quienSoy;
			if (vivo(cerrojo) && !esMio) {
				return {
					ok: true,
					resultado: "unirse",
					quien: cerrojo.quien || "",
					direcciones: cerrojo.direcciones || [],
					desde: cerrojo.desde || 0,
				};
			}
			// Mio y vivo, desde OTRO proceso de este mismo equipo: puede ser otra ventana del juego que
			// sigue abierta. El servidor no puede mirar procesos ajenos, asi que se lo pregunta al juego,
			// que vuelve con reclamar=true si ese proceso ya no existe.
			if (esMio && vivo(cerrojo) && !p.reclamar && cerrojo.equipo && cerrojo.equipo === p.equipo
					&& cerrojo.pid && cerrojo.pid !== p.pid) {
				return { ok: true, resultado: "comprobar", pid: cerrojo.pid };
			}
			// Mio (sesion anterior que no lo solto) o caducado: se recoge.
			await this.ctx.storage.delete("cerrojo");
		}

		const v = mundo.sello_version || 0;
		if (v > (p.sello_version || 0)) {
			return fallo("version_nueva",
				`Este mundo lo guardó una versión más nueva del juego (v${v}). Actualiza antes de abrirlo.`);
		}
		const b = mundo.sello_build || "";
		if (b !== "" && p.sello_build && b !== p.sello_build && !p.forzar_build) {
			return fallo("build_distinto",
				`Este mundo se guardó con el build ${b} y tú tienes el ${p.sello_build}. Tienen que ser el mismo.`);
		}

		const t = ahora();
		mundo.token = (mundo.token || 0) + 1;
		await this.ctx.storage.put({
			mundo,
			cerrojo: {
				token: mundo.token,
				quien: String(p.quien || "alguien"),
				identidad: quienSoy,
				pid: p.pid || 0,
				equipo: String(p.equipo || ""),
				desde: t,
				latido: t,
				direcciones: Array.isArray(p.direcciones) ? p.direcciones.map(String) : [],
			},
		});
		return {
			ok: true,
			resultado: "host",
			token: mundo.token,
			meta: mundo.meta || {},
			tiene_save: (mundo.trozos || 0) > 0,
			bytes: mundo.bytes || 0,
		};
	}

	// ---- BAJAR el save: solo con el cerrojo en la mano ----
	async bajar(id, pass, token) {
		const mundo = await this.leerMundo(id, pass);
		if (!mundo) {
			return json(noAutorizado(), 409);
		}
		const cerrojo = await this.ctx.storage.get("cerrojo");
		if (!cerrojo || cerrojo.token !== token || mundo.token !== token) {
			return json(fallo("sin_cerrojo", "El mundo ya no está a tu nombre."), 409);
		}
		const n = mundo.trozos || 0;
		const claves = [];
		for (let i = 0; i < n; i++) {
			claves.push("save:" + i);
		}
		const salida = new Uint8Array(mundo.bytes || 0);
		let pos = 0;
		// get() admite 128 claves por llamada: con trozos de 1 MB eso son 128 MB, de sobra.
		const trozos = n > 0 ? await this.ctx.storage.get(claves) : new Map();
		for (const k of claves) {
			const t = trozos.get(k);
			if (!t) {
				return json(fallo("save_roto", "Falta un trozo de la partida en la nube."), 409);
			}
			salida.set(new Uint8Array(t), pos);
			pos += t.byteLength;
		}
		return new Response(salida, { headers: { "content-type": "application/octet-stream" } });
	}

	// ---- LATIDO: "sigo aqui" ----
	async latido(id, pass, token) {
		if (!(await this.leerMundo(id, pass))) {
			return noAutorizado();
		}
		const cerrojo = await this.ctx.storage.get("cerrojo");
		if (!cerrojo) {
			return fallo("sin_cerrojo", "El mundo ya no está a tu nombre.");
		}
		if (cerrojo.token !== token) {
			return fallo("token_viejo", "El mundo lo ha abierto alguien después de ti.");
		}
		if (!vivo(cerrojo)) {
			return fallo("caducado", "Tu turno en el mundo caducó por falta de conexión.");
		}
		cerrojo.latido = ahora();
		await this.ctx.storage.put("cerrojo", cerrojo);
		return { ok: true };
	}

	// ---- SUBIR (y, si soltando, CERRAR): el vallado de verdad vive aqui ----
	async subir(id, pass, token, save, cab, soltando) {
		const mundo = await this.leerMundo(id, pass);
		if (!mundo) {
			return noAutorizado();
		}
		if (mundo.token !== token) {
			return fallo("token_viejo",
				"El mundo lo ha abierto alguien después de ti: tu partida no se puede subir encima de la suya.");
		}
		const cerrojo = await this.ctx.storage.get("cerrojo");
		if (!cerrojo || cerrojo.token !== token) {
			return fallo("sin_cerrojo", "El mundo ya no está a tu nombre.");
		}
		if (!save || save.byteLength === 0) {
			return fallo("save_vacio", "No hay partida que subir.");
		}
		const viejos = mundo.trozos || 0;
		const nuevos = Math.ceil(save.byteLength / TROZO);
		const lote = {};
		for (let i = 0; i < nuevos; i++) {
			lote["save:" + i] = save.slice(i * TROZO, Math.min(save.byteLength, (i + 1) * TROZO));
		}
		mundo.trozos = nuevos;
		mundo.bytes = save.byteLength;
		mundo.meta = cab.meta;
		mundo.sello_version = cab.sello_version;
		mundo.sello_build = cab.sello_build;
		mundo.subido = ahora();
		lote.mundo = mundo;
		// Un put con varias claves es ATOMICO: o entra el save entero con su cabecera, o nada.
		await this.ctx.storage.put(lote);
		const sobran = [];
		for (let i = nuevos; i < viejos; i++) {
			sobran.push("save:" + i);
		}
		if (soltando) {
			// La direccion se va con el cerrojo: nunca se reparte la IP del que jugo ayer.
			sobran.push("cerrojo");
		} else {
			cerrojo.latido = ahora();   // subir tambien dice "sigo aqui"
			await this.ctx.storage.put("cerrojo", cerrojo);
		}
		if (sobran.length > 0) {
			await this.ctx.storage.delete(sobran);
		}
		return { ok: true };
	}

	// ---- ESTADO: para pintar la lista sin bajarse el save ----
	async estado(id, pass) {
		const mundo = await this.leerMundo(id, pass);
		if (!mundo) {
			return noAutorizado();
		}
		const r = {
			ok: true,
			id,
			abierto: false,
			caducado: false,
			quien: "",
			desde: 0,
			meta: mundo.meta || {},
			sello_version: mundo.sello_version || 0,
			sello_build: mundo.sello_build || "",
			tiene_save: (mundo.trozos || 0) > 0,
		};
		const cerrojo = await this.ctx.storage.get("cerrojo");
		if (cerrojo) {
			r.abierto = true;
			r.caducado = !vivo(cerrojo);
			r.quien = cerrojo.quien || "";
			r.desde = cerrojo.desde || 0;
			if (!r.caducado) {
				r.direcciones = cerrojo.direcciones || [];
			}
		}
		return r;
	}

	// El mundo, solo si la contraseña casa. null = no existe O contraseña mala (indistinguibles a
	// proposito: si no, el mensaje de error seria un buscador de mundos ajenos).
	async leerMundo(id, pass) {
		const mundo = await this.ctx.storage.get("mundo");
		if (!mundo || !pass || mundo.pass !== (await huella(id, pass))) {
			return null;
		}
		return mundo;
	}
}

// ---- utilidades ----
function ahora() {
	return Math.floor(Date.now() / 1000);
}

function vivo(cerrojo) {
	return ahora() - (cerrojo.latido || 0) < SEGUNDOS_ARRENDAMIENTO;
}

// La MISMA huella que NubeAlmacenLocal._huella: sha256 de "dungeon-oratoria|<id>|<contraseña>".
async function huella(id, pass) {
	const datos = new TextEncoder().encode(`dungeon-oratoria|${id}|${pass}`);
	const h = await crypto.subtle.digest("SHA-256", datos);
	return [...new Uint8Array(h)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function cabecera(req, nombre) {
	const v = req.headers.get(nombre);
	if (v === null) {
		return "";
	}
	try {
		return decodeURIComponent(v);
	} catch {
		return v;
	}
}

function entero(req, nombre) {
	return parseInt(cabecera(req, nombre) || "0", 10) || 0;
}

function meta(req) {
	try {
		const m = JSON.parse(cabecera(req, "x-meta") || "{}");
		return m && typeof m === "object" ? m : {};
	} catch {
		return {};
	}
}

function fallo(error, mensaje) {
	return { ok: false, error, mensaje };
}

function noAutorizado() {
	return fallo("no_autorizado", "No hay ningún mundo con ese id y esa contraseña.");
}

function json(obj, estado = 200) {
	return new Response(JSON.stringify(obj), {
		status: estado,
		headers: { "content-type": "application/json; charset=utf-8" },
	});
}
