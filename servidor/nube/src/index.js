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
//    crear   JSON {quien_soy}      -> {ok}  (quien_soy = el primer MIEMBRO)
//    abrir   JSON {direcciones, sello_version, sello_build, forzar_build, quien_soy, quien, pid,
//                  equipo, reclamar}
//                                  -> {ok, resultado: host|unirse|comprobar, ...}
//    bajar   X-Token               -> los bytes del save (200) o JSON de error (409)
//    latido  X-Token               -> {ok}
//    subir   X-Token, X-Sello-Version, X-Sello-Build, X-Meta; cuerpo = bytes del save -> {ok}
//            (X-Meta puede llevar "miembros": la lista de identidades con personaje en el save)
//    cerrar  igual que subir, y ademas suelta el cerrojo -> {ok}
//    estado  JSON {quien_soy}?     -> {ok, abierto, caducado, quien, es_mio, direcciones?, meta, ...}
//  Las respuestas son siempre {"ok": bool} y, si falla, "error" (codigo estable) y "mensaje".
//
//  LA BASE DE DATOS DEL MUNDO (fase 2 de la BD, 07/10/2026): el mundo deja de ser un fichero entero y
//  pasa a ser FILAS (las mismas de scripts/core/bd_filas.gd: tabla campos/objetos/contables, clave,
//  valor) en el SQLite del propio objeto. Cada cambio sube "rev"; cada fila lleva el rev en que cambio,
//  asi que bajarse lo nuevo es "dame lo de despues del rev X". Lo borrado queda como lapida (borrada=1)
//  para que el que baja a partir de X se entere.
//    sync      X-Token, X-Sello-*, X-Meta; JSON {base, lote, parte, fin, completa, soltar, foto,
//              filas: [[tabla, clave, valor|null], ...]}
//              -> {ok, rev, escritas}  (o, en las partes que no son la ultima, {ok, parte})
//              Las filas grandes van en varias partes del mismo lote y solo se aplican con la ULTIMA,
//              todas de golpe: o entra el guardado entero o nada. "base" es el rev del que parte quien
//              sube: si no es el de aqui -> rev_distinto (nadie machaca a ciegas). completa = sustituye
//              TODO (la primera subida, la migracion de un mundo viejo). soltar = es el cierre: suelta
//              el cerrojo. foto = haz una copia para el historial.
//    bajar_bd  X-Token; JSON {desde, tras} -> {ok, rev, completa, filas, mas, tras}  (por paginas)
//    fotos     X-Token -> {ok, fotos: [{id, fecha, rev, bytes, motivo}], legado}
//    restaurar X-Token; JSON {foto: id | "legado"} -> {ok, rev}
//  Un mundo con formato "bd" solo lo abre un juego que lo entiende (abrir lleva formato_bd >= 1): el
//  juego viejo se lleva "version_nueva" en vez de abrir el save de antes de migrar. El save viejo se
//  queda como LEGADO 30 dias (vuelta atras: restaurar "legado").
//
//  EL VINCULO DE STEAM (22/09/2026): que tu cuenta de Steam recuerde tu identidad de jugador (el id
//  de 24 hex de identidad.cfg), para no ser otro jugador al cambiar de PC. Va a /v1/<op>?steam=<SteamID>
//  y lo guarda OTRO objeto del mismo tipo, uno por cuenta (nombre "steam:<SteamID>"): nada de los
//  mundos cambia.
//    vinculo_leer   JSON {ticket?}            -> {ok, id ("" = sin vinculo), anterior, desde}
//    vinculo_poner  JSON {id, ticket?}        -> {ok, id, anterior}   (anterior = el que habia)
//  ⚠ SEGURIDAD: con Spacewar (appID 480) no se puede comprobar que quien pregunta es de verdad esa
//  cuenta (validar el ticket pide la clave Web API del editor, que solo existe con appID propio). El
//  SteamID es publico, asi que quien lo sepa podria leer o cambiar tu vinculo. Riesgo bajo: para entrar
//  a un mundo sigue haciendo falta su codigo y su contraseña. CON APPID PROPIO: validar `ticket` con
//  ISteamUserAuth/AuthenticateUserTicket antes de dar o cambiar un vinculo.
// ============================================================

import { DurableObject } from "cloudflare:workers";

// Cuanto vive un arrendamiento sin latido. El juego late cada 30 s (Nube.SEGUNDOS_LATIDO).
const SEGUNDOS_ARRENDAMIENTO = 120;
const TROZO = 1024 * 1024;
const MAX_SAVE = 48 * 1024 * 1024;
const ID_VALIDO = /^[0-9a-f]{24}$/;
const OPS = new Set(["crear", "abrir", "bajar", "latido", "subir", "cerrar", "estado",
	"sync", "bajar_bd", "fotos", "restaurar"]);
const OPS_JSON = new Set(["abrir", "crear", "estado", "sync", "bajar_bd", "fotos", "restaurar"]);
// La base de datos del mundo.
const FORMATO_BD = 1;                          // lo que tiene que entender el juego para abrir uno migrado
const PAGINA_BAJAR = 1024 * 1024;              // lo que lleva cada pagina de bajar_bd (texto de las filas)
const SEGUNDOS_FOTO = 3600;                    // una foto para el historial como mucho cada hora (y al cerrar)
const SEGUNDOS_FOTOS_GUARDADAS = 7 * 86400;    // las fotos se guardan una semana...
const FOTOS_MINIMAS = 3;                       // ...pero las 3 ultimas siempre
const SEGUNDOS_LEGADO = 30 * 86400;            // el save de antes de migrar, 30 dias
const TROZO_FOTO = 1536 * 1024;                // un BLOB de SQLite en un Durable Object admite 2 MB
const LAPIDAS_MAX = 2000;                      // con mas borradas que esto, se purgan (y el que baje de antes, todo)
const OPS_CUENTA = new Set(["vinculo_leer", "vinculo_poner"]);
const STEAM_VALIDO = /^[0-9]{15,20}$/;

export default {
	async fetch(req, env) {
		const url = new URL(req.url);
		if (req.method === "GET" && url.pathname === "/") {
			return new Response("Dungeon Oratoria: nube de mundos compartidos\n");
		}
		const partes = url.pathname.split("/").filter((p) => p !== "");
		// EL VINCULO DE STEAM: su propio objeto por cuenta; no pasa por nada de los mundos.
		if (req.method === "POST" && partes.length === 2 && partes[0] === "v1" && OPS_CUENTA.has(partes[1])) {
			const steam = url.searchParams.get("steam") || "";
			if (!STEAM_VALIDO.test(steam)) {
				return json(fallo("peticion_mala", "La cuenta de Steam no es válida."), 400);
			}
			const cuenta = env.MUNDO.get(env.MUNDO.idFromName("steam:" + steam));
			return cuenta.fetch(req);
		}
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
	constructor(ctx, env) {
		super(ctx, env);
		// Las tablas de la base de datos del mundo. CREATE IF NOT EXISTS: no cuesta nada si ya estan.
		// (Los objetos de cuenta de Steam tambien son de esta clase: a ellos les sobran, y no pasa nada.)
		const sql = ctx.storage.sql;
		sql.exec(`CREATE TABLE IF NOT EXISTS filas (tabla TEXT NOT NULL, clave TEXT NOT NULL, valor,
			borrada INTEGER NOT NULL DEFAULT 0, rev INTEGER NOT NULL, PRIMARY KEY (tabla, clave))`);
		sql.exec("CREATE TABLE IF NOT EXISTS bd (clave TEXT PRIMARY KEY, valor)");
		sql.exec("CREATE TABLE IF NOT EXISTS lote (parte INTEGER, tabla TEXT, clave TEXT, valor, borrar INTEGER)");
		sql.exec(`CREATE TABLE IF NOT EXISTS fotos (id INTEGER PRIMARY KEY AUTOINCREMENT, fecha INTEGER,
			rev INTEGER, bytes INTEGER, motivo TEXT)`);
		sql.exec(`CREATE TABLE IF NOT EXISTS fotos_trozos (foto INTEGER, n INTEGER, datos BLOB,
			PRIMARY KEY (foto, n))`);
	}

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
		} else if (OPS_JSON.has(op) || OPS_CUENTA.has(op)) {
			try {
				cuerpo = await req.json();
			} catch {
				cuerpo = {};
			}
		}
		switch (op) {
			case "crear":
				return json(await this.crear(id, pass, cuerpo || {}));
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
				return json(await this.estado(id, pass, cuerpo || {}));
			case "sync":
				return json(await this.sync(id, pass, entero(req, "x-token"), cuerpo || {}, {
					sello_version: entero(req, "x-sello-version"),
					sello_build: cabecera(req, "x-sello-build"),
					meta: meta(req),
				}));
			case "bajar_bd":
				return json(await this.bajarBd(id, pass, entero(req, "x-token"), cuerpo || {}));
			case "fotos":
				return json(await this.fotos(id, pass, entero(req, "x-token")));
			case "restaurar":
				return json(await this.restaurar(id, pass, entero(req, "x-token"), cuerpo || {}));
			case "vinculo_leer":
				return json(await this.vinculoLeer());
			case "vinculo_poner":
				return json(await this.vinculoPoner(cuerpo || {}));
		}
		return json(fallo("peticion_mala", "Esa petición no existe."), 404);
	}

	// ---- EL VINCULO DE STEAM (este objeto es el de una CUENTA, "steam:<SteamID>", no un mundo) ----
	// El ticket de Steam llega en p.ticket y todavia NO se valida: ver SEGURIDAD en la cabecera.
	async vinculoLeer() {
		const v = await this.ctx.storage.get("vinculo");
		return { ok: true, id: v ? v.id : "", anterior: v ? v.anterior || "" : "", desde: v ? v.desde : 0 };
	}

	async vinculoPoner(p) {
		const nuevo = String(p.id || "");
		if (!ID_VALIDO.test(nuevo)) {
			return fallo("peticion_mala", "Esa identidad no es válida.");
		}
		const v = await this.ctx.storage.get("vinculo");
		const anterior = v ? v.id : "";
		await this.ctx.storage.put("vinculo", { id: nuevo, anterior, desde: ahora() });
		return { ok: true, id: nuevo, anterior };
	}

	// ---- ALTA ----
	async crear(id, pass, p) {
		if (!pass) {
			return fallo("peticion_mala", "Hace falta un id de mundo y una contraseña.");
		}
		if (await this.ctx.storage.get("mundo")) {
			return fallo("ya_existe", "Ese mundo ya existe.");
		}
		const quienSoy = String(p.quien_soy || "");
		await this.ctx.storage.put("mundo", {
			// LOS MIEMBROS: quien puede ABRIR el mundo estando cerrado. Empieza con quien lo crea y lo
			// mantiene al dia el propio juego al subir (son los jugadores que tienen personaje dentro, ver
			// subir). Uno de fuera, aunque tenga codigo y contraseña, solo puede UNIRSE a alguien de dentro,
			// y ese le tiene que aceptar en el juego. Vacio = mundo de antes de esto: lo abre cualquiera.
			miembros: quienSoy ? [quienSoy] : [],
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
		}
		// Nadie dentro (o el cerrojo es mio o ha caducado): lo va a abrir ESTE. Solo si es de la casa.
		const miembros = Array.isArray(mundo.miembros) ? mundo.miembros : [];
		if (miembros.length > 0 && !miembros.includes(quienSoy)) {
			return fallo("no_miembro", "Este mundo solo lo puede abrir quien ya juega en él. Entra cuando "
				+ "alguien de dentro lo tenga abierto: te tendrá que aceptar.");
		}
		// (Antes de recoger el cerrojo: un juego viejo no se lleva el de nadie.)
		// Un mundo ya pasado a base de datos no lo abre un juego que no la entiende: se bajaria el save
		// de ANTES de migrar (el legado) y lo subiria encima.
		const formato = this.bdGet("formato", "");
		if (formato === "bd" && (parseInt(p.formato_bd, 10) || 0) < FORMATO_BD) {
			return fallo("version_nueva",
				"Este mundo ya usa el guardado nuevo del juego. Actualiza antes de abrirlo.");
		}
		if (cerrojo) {
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
		await this.limpiarLegado(mundo);

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
			// tiene_save = hay un save VIEJO (un fichero entero) que bajarse; con formato "bd" lo que hay
			// son filas (bajar_bd) y el save viejo, si queda, es el legado: no se baja.
			tiene_save: formato !== "bd" && (mundo.trozos || 0) > 0,
			bytes: mundo.bytes || 0,
			formato: formato !== "" ? formato : ((mundo.trozos || 0) > 0 ? "tres" : ""),
			bd_rev: this.bdGet("rev", 0),
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
		if (this.bdGet("formato", "") === "bd") {
			// Un fichero entero encima de un mundo que ya va por filas: solo lo haria un juego viejo.
			return fallo("version_nueva", "Este mundo ya usa el guardado nuevo del juego. Actualiza.");
		}
		const viejos = mundo.trozos || 0;
		const nuevos = Math.ceil(save.byteLength / TROZO);
		const lote = {};
		for (let i = 0; i < nuevos; i++) {
			lote["save:" + i] = save.slice(i * TROZO, Math.min(save.byteLength, (i + 1) * TROZO));
		}
		mundo.trozos = nuevos;
		mundo.bytes = save.byteLength;
		// Los miembros vienen en la cabecera: son los jugadores con personaje en el save que se sube. Solo
		// los manda quien tiene el cerrojo (y ese ya es de la casa), asi que se fian.
		const m = cab.meta.miembros;
		if (Array.isArray(m) && m.length > 0) {
			mundo.miembros = m.map(String);
		}
		delete cab.meta.miembros;
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

	// ============================================================
	//  LA BASE DE DATOS DEL MUNDO
	// ------------------------------------------------------------
	// El mundo y su cerrojo, si este token es el vigente. {mundo, cerrojo} o {error: fallo}.
	async conCerrojo(id, pass, token) {
		const mundo = await this.leerMundo(id, pass);
		if (!mundo) {
			return { error: noAutorizado() };
		}
		if (mundo.token !== token) {
			return { error: fallo("token_viejo",
				"El mundo lo ha abierto alguien después de ti: tu partida no se puede subir encima de la suya.") };
		}
		const cerrojo = await this.ctx.storage.get("cerrojo");
		if (!cerrojo || cerrojo.token !== token) {
			return { error: fallo("sin_cerrojo", "El mundo ya no está a tu nombre.") };
		}
		return { mundo, cerrojo };
	}

	// ---- SYNC: subir las filas cambiadas (y, con soltar, cerrar) ----
	async sync(id, pass, token, p, cab) {
		const c = await this.conCerrojo(id, pass, token);
		if (c.error) {
			return c.error;
		}
		const { mundo, cerrojo } = c;
		const sql = this.ctx.storage.sql;
		const filas = Array.isArray(p.filas) ? p.filas : [];
		for (const f of filas) {
			if (!Array.isArray(f) || f.length !== 3 || typeof f[0] !== "string" || typeof f[1] !== "string") {
				return fallo("peticion_mala", "Una fila de la partida viene mal.");
			}
		}
		const parte = parseInt(p.parte, 10) || 0;
		const fin = !!p.fin;
		const lote = String(p.lote || "");
		let escritas = 0;

		// Un lote en varias partes: las de antes de la ultima se aparcan (lote) sin tocar nada.
		const enPartes = !fin || parte > 0;
		if (enPartes) {
			if (parte === 0) {
				escritas += sql.exec("DELETE FROM lote").rowsWritten;
				this.bdPut("lote", lote);
			} else if (this.bdGet("lote", "") !== lote || lote === "") {
				return fallo("lote_roto", "Se ha perdido una parte de la subida. Se repetira entera.");
			}
			for (const [tabla, clave, valor] of filas) {
				escritas += sql.exec("INSERT INTO lote VALUES (?, ?, ?, ?, ?)", parte, tabla, clave,
					valor === null ? null : valor, valor === null ? 1 : 0).rowsWritten;
			}
			if (!fin) {
				cerrojo.latido = ahora();
				await this.ctx.storage.put("cerrojo", cerrojo);
				return { ok: true, parte, escritas };
			}
		}

		const rev = this.bdGet("rev", 0);
		if ((parseInt(p.base, 10) || 0) !== rev) {
			if (enPartes) {
				sql.exec("DELETE FROM lote");
			}
			return { ...fallo("rev_distinto", "La partida de la nube ha cambiado desde que la abriste."), rev };
		}
		// Todo lo del lote, de golpe: o entra entero o nada.
		let todas = filas;
		if (enPartes) {
			todas = [];
			for (const r of sql.exec("SELECT tabla, clave, valor, borrar FROM lote ORDER BY parte, rowid")) {
				todas.push([r.tabla, r.clave, r.borrar ? null : r.valor]);
			}
		}
		const completa = !!p.completa;
		let nuevo = rev;
		if (todas.length > 0 || completa) {
			nuevo = rev + 1;
			const formatoAntes = this.bdGet("formato", "");
			this.ctx.storage.transactionSync(() => {
				if (completa) {
					// TODO de nuevo: sin lapidas (el que baje desde antes de aqui se lo baja entero).
					escritas += sql.exec("DELETE FROM filas").rowsWritten;
					this.bdPut("purgado_hasta", nuevo);
				}
				for (const [tabla, clave, valor] of todas) {
					if (valor === null) {
						if (!completa) {
							escritas += sql.exec("UPDATE filas SET valor = NULL, borrada = 1, rev = ? "
								+ "WHERE tabla = ? AND clave = ?", nuevo, tabla, clave).rowsWritten;
						}
					} else {
						escritas += sql.exec("INSERT OR REPLACE INTO filas VALUES (?, ?, ?, 0, ?)",
							tabla, clave, valor, nuevo).rowsWritten;
					}
				}
				if (enPartes) {
					escritas += sql.exec("DELETE FROM lote").rowsWritten;
				}
				this.bdPut("rev", nuevo);
				if (formatoAntes !== "bd") {
					this.bdPut("formato", "bd");
					if ((mundo.trozos || 0) > 0) {
						// El save de antes se queda de LEGADO (vuelta atras) unos dias.
						this.bdPut("legado_desde", ahora());
					}
				}
			});
			escritas += this.purgarLapidas(nuevo);
		}

		const m = cab.meta.miembros;
		if (Array.isArray(m) && m.length > 0) {
			mundo.miembros = m.map(String);
		}
		delete cab.meta.miembros;
		if (Object.keys(cab.meta).length > 0) {
			mundo.meta = cab.meta;
		}
		mundo.sello_version = cab.sello_version;
		mundo.sello_build = cab.sello_build;
		mundo.subido = ahora();
		await this.ctx.storage.put("mundo", mundo);
		if (nuevo > 0 && (p.foto || ahora() - this.bdGet("ult_foto", 0) >= SEGUNDOS_FOTO)) {
			escritas += await this.hacerFoto(nuevo, p.soltar ? "cierre" : "hora");
		}
		if (p.soltar) {
			await this.ctx.storage.delete("cerrojo");
		} else {
			cerrojo.latido = ahora();
			await this.ctx.storage.put("cerrojo", cerrojo);
		}
		return { ok: true, rev: nuevo, escritas };
	}

	// ---- BAJAR_BD: las filas cambiadas desde un rev (0 = todas), por paginas ----
	async bajarBd(id, pass, token, p) {
		const c = await this.conCerrojo(id, pass, token);
		if (c.error) {
			return c.error;
		}
		const sql = this.ctx.storage.sql;
		let desde = parseInt(p.desde, 10) || 0;
		// Si lo que se borro despues de su rev ya se purgo, no se puede saber que borrar: se baja todo.
		if (desde > 0 && desde < this.bdGet("purgado_hasta", 0)) {
			desde = 0;
		}
		const tras = parseInt(p.tras, 10) || 0;
		const filas = [];
		let talla = 0;
		let ultimo = tras;
		let mas = false;
		const cursor = desde === 0
			? sql.exec("SELECT rowid AS r, tabla, clave, valor FROM filas WHERE borrada = 0 AND rowid > ? "
				+ "ORDER BY rowid", tras)
			: sql.exec("SELECT rowid AS r, tabla, clave, valor, borrada FROM filas WHERE rev > ? AND rowid > ? "
				+ "ORDER BY rowid", desde, tras);
		for (const r of cursor) {
			if (talla >= PAGINA_BAJAR) {
				mas = true;
				break;
			}
			const v = r.borrada ? null : r.valor;
			filas.push([r.tabla, r.clave, v]);
			talla += r.clave.length + (typeof v === "string" ? v.length : 8) + 16;
			ultimo = r.r;
		}
		return { ok: true, rev: this.bdGet("rev", 0), completa: desde === 0, filas, mas, tras: ultimo };
	}

	// ---- EL HISTORIAL ----
	async fotos(id, pass, token) {
		const c = await this.conCerrojo(id, pass, token);
		if (c.error) {
			return c.error;
		}
		const fotos = [...this.ctx.storage.sql.exec("SELECT id, fecha, rev, bytes, motivo FROM fotos ORDER BY id DESC")];
		const legado = this.bdGet("legado_desde", 0) > 0 && (c.mundo.trozos || 0) > 0;
		return { ok: true, fotos, legado, legado_desde: legado ? this.bdGet("legado_desde", 0) : 0 };
	}

	// Vuelve a una foto (o al save de antes de migrar). Sube el rev: el que la pide se la baja entera.
	async restaurar(id, pass, token, p) {
		const c = await this.conCerrojo(id, pass, token);
		if (c.error) {
			return c.error;
		}
		const sql = this.ctx.storage.sql;
		const nuevo = this.bdGet("rev", 0) + 1;
		if (p.foto === "legado") {
			if (!((c.mundo.trozos || 0) > 0 && this.bdGet("legado_desde", 0) > 0)) {
				return fallo("sin_foto", "Este mundo no tiene save de antes de migrar.");
			}
			// Antes de nada, una foto de lo que hay: volver atras tampoco puede perder nada.
			await this.hacerFoto(nuevo - 1, "antes de restaurar");
			this.ctx.storage.transactionSync(() => {
				sql.exec("DELETE FROM filas");
				this.bdPut("rev", nuevo);
				this.bdPut("purgado_hasta", nuevo);
				this.bdPut("formato", "tres");
				this.bdPut("legado_desde", 0);
			});
			return { ok: true, rev: nuevo, formato: "tres" };
		}
		const fid = parseInt(p.foto, 10) || 0;
		const trozos = [...sql.exec("SELECT datos FROM fotos_trozos WHERE foto = ? ORDER BY n", fid)];
		if (trozos.length === 0) {
			return fallo("sin_foto", "Esa copia del historial no existe.");
		}
		const foto = JSON.parse(await descomprimir(trozos.map((t) => new Uint8Array(t.datos))));
		await this.hacerFoto(nuevo - 1, "antes de restaurar");
		this.ctx.storage.transactionSync(() => {
			sql.exec("DELETE FROM filas");
			for (const [tabla, clave, valor] of foto.filas) {
				sql.exec("INSERT INTO filas VALUES (?, ?, ?, 0, ?)", tabla, clave, valor, nuevo);
			}
			this.bdPut("rev", nuevo);
			this.bdPut("purgado_hasta", nuevo);
			this.bdPut("formato", "bd");
		});
		return { ok: true, rev: nuevo, formato: "bd" };
	}

	// Una copia comprimida de TODAS las filas, para el historial. Devuelve las filas escritas.
	async hacerFoto(rev, motivo) {
		const sql = this.ctx.storage.sql;
		const filas = [];
		for (const r of sql.exec("SELECT tabla, clave, valor FROM filas WHERE borrada = 0")) {
			filas.push([r.tabla, r.clave, r.valor]);
		}
		if (filas.length === 0) {
			return 0;
		}
		const datos = await comprimir(JSON.stringify({ rev, filas }));
		let escritas = 0;
		this.ctx.storage.transactionSync(() => {
			const fid = sql.exec("INSERT INTO fotos (fecha, rev, bytes, motivo) VALUES (?, ?, ?, ?) RETURNING id",
				ahora(), rev, datos.byteLength, motivo).one().id;
			for (let i = 0, n = 0; i < datos.byteLength; i += TROZO_FOTO, n++) {
				escritas += sql.exec("INSERT INTO fotos_trozos VALUES (?, ?, ?)", fid, n,
					datos.slice(i, Math.min(datos.byteLength, i + TROZO_FOTO)).buffer).rowsWritten;
			}
			this.bdPut("ult_foto", ahora());
			// Fuera las de mas de una semana, menos las ultimas FOTOS_MINIMAS.
			const viejas = [...sql.exec("SELECT id FROM fotos WHERE fecha < ? AND id NOT IN "
				+ "(SELECT id FROM fotos ORDER BY id DESC LIMIT ?)", ahora() - SEGUNDOS_FOTOS_GUARDADAS, FOTOS_MINIMAS)];
			for (const v of viejas) {
				escritas += sql.exec("DELETE FROM fotos_trozos WHERE foto = ?", v.id).rowsWritten;
				escritas += sql.exec("DELETE FROM fotos WHERE id = ?", v.id).rowsWritten;
			}
		});
		return escritas + 1;
	}

	// Demasiadas lapidas: se quitan y quien baje desde antes se lo baja todo (ver bajarBd).
	purgarLapidas(rev) {
		const sql = this.ctx.storage.sql;
		const n = sql.exec("SELECT COUNT(*) AS n FROM filas WHERE borrada = 1").one().n;
		if (n <= LAPIDAS_MAX) {
			return 0;
		}
		const escritas = sql.exec("DELETE FROM filas WHERE borrada = 1").rowsWritten;
		this.bdPut("purgado_hasta", rev);
		return escritas;
	}

	// El save de antes de migrar se tira pasados SEGUNDOS_LEGADO.
	async limpiarLegado(mundo) {
		const desde = this.bdGet("legado_desde", 0);
		if (desde <= 0 || ahora() - desde < SEGUNDOS_LEGADO || this.bdGet("formato", "") !== "bd") {
			return;
		}
		const claves = [];
		for (let i = 0; i < (mundo.trozos || 0); i++) {
			claves.push("save:" + i);
		}
		if (claves.length > 0) {
			await this.ctx.storage.delete(claves);
		}
		mundo.trozos = 0;
		mundo.bytes = 0;
		this.bdPut("legado_desde", 0);
		await this.ctx.storage.put("mundo", mundo);
	}

	bdGet(clave, porDefecto) {
		const r = [...this.ctx.storage.sql.exec("SELECT valor FROM bd WHERE clave = ?", clave)];
		return r.length > 0 && r[0].valor !== null ? r[0].valor : porDefecto;
	}

	bdPut(clave, valor) {
		this.ctx.storage.sql.exec("INSERT OR REPLACE INTO bd VALUES (?, ?)", clave, valor);
	}

	// ---- ESTADO: para pintar la lista sin bajarse el save ----
	// quien_soy (opcional): si viene, se dice si el cerrojo es SUYO (es_mio). Es lo que deja al juego
	// distinguir "lo tiene otro, me uno" de "lo tiene mi propia sala, que se cayo: lanzo otra".
	async estado(id, pass, p) {
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
			tiene_save: (mundo.trozos || 0) > 0 || this.bdGet("formato", "") === "bd",
			formato: this.bdGet("formato", ""),
			bd_rev: this.bdGet("rev", 0),
		};
		const cerrojo = await this.ctx.storage.get("cerrojo");
		if (cerrojo) {
			r.abierto = true;
			r.caducado = !vivo(cerrojo);
			r.quien = cerrojo.quien || "";
			r.desde = cerrojo.desde || 0;
			r.es_mio = !!p.quien_soy && cerrojo.identidad === String(p.quien_soy);
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

// gzip de un texto (las fotos del historial). Uint8Array.
async function comprimir(texto) {
	const flujo = new Blob([texto]).stream().pipeThrough(new CompressionStream("gzip"));
	return new Uint8Array(await new Response(flujo).arrayBuffer());
}

async function descomprimir(trozos) {
	const flujo = new Blob(trozos).stream().pipeThrough(new DecompressionStream("gzip"));
	return await new Response(flujo).text();
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
