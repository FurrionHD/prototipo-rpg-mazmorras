# ============================================================
#  sdf_comun.py -- EL MOTOR 3D de los enemigos (02/10/2026), sacado del Minotauro (minotauro_sdf.py, aprobado: ese no
#  se toca). Lo mismo que alli -- formas que se funden (smin), huesos rigidos, raymarching ortografico desde la camara
#  del juego (45 grados), tres tonos PLANOS por material y el contorno con lineas de dentro por salto de profundidad --
#  pero con lo de cada enemigo (escala, lienzo, materiales, grupos que se funden) en un Modelo.
#
#  Ejes del modelo: X a su izquierda/derecha, Y hacia DONDE MIRA, Z arriba. Unidades del modelo; 1 celda del juego =
#  1,15 unidades del mundo (SpriteLienzo.UNIDADES_POR_CELDA), asi que PPU = escala_visual / 1,15 celdas por unidad.
# ============================================================
import math, json, os, importlib
from multiprocessing import Pool
import numpy as np
from PIL import Image

# --- CAMARA (la del juego: pantalla_y = y*cos - z*sin) ---
CAM = math.radians(45.0)
C, S = math.cos(CAM), math.sin(CAM)
R_ = np.array([1.0, 0.0, 0.0])
U_ = np.array([0.0, -C, S])          # arriba en pantalla
F_ = np.array([0.0, -S, -C])         # hacia dentro de la pantalla
DIR_VECS = [(0, 1), (0.7, 0.7), (1, 0), (0.7, -0.7), (0, -1), (-0.7, -0.7), (-1, 0), (-0.7, 0.7)]


# --- PRIMITIVAS (P: N x 3) ---
def sd_esfera(P, c, r):
    return np.linalg.norm(P - c, axis=1) - r

def sd_elipsoide(P, c, rad):
    q = (P - c) / rad
    k0 = np.linalg.norm(q, axis=1)
    k1 = np.linalg.norm(q / rad, axis=1)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-6)

def sd_cono(P, a, b, ra, rb):
    """Capsula con radio que va de ra (en a) a rb (en b)."""
    pa = P - a; ba = b - a
    h = np.clip((pa @ ba) / max(ba @ ba, 1e-6), 0.0, 1.0)
    return np.linalg.norm(pa - np.outer(h, ba), axis=1) - (ra + (rb - ra) * h)

def sd_caja(P, c, ejes, medio, redondeo=0.2):
    """Caja orientada: 'ejes' = 3 vectores unitarios (filas), 'medio' = semilados."""
    q = (P - c) @ np.array(ejes).T
    d = np.abs(q) - (np.array(medio) - redondeo)
    return np.linalg.norm(np.maximum(d, 0.0), axis=1) + np.minimum(d.max(axis=1), 0.0) - redondeo

def sd_triangulo(P, a, b, c, grosor):
    """Una lamina triangular de 'grosor' (05/10, las membranas del chillon: un ala de murcielago es ancha en dos ejes
    y finisima en el tercero, y con bolas sale un churro)."""
    ba = b - a; pa = P - a; cb = c - b; pb = P - b; ac = a - c; pc = P - c
    nor = np.cross(ba, ac)
    lado = (np.sign(pa @ np.cross(ba, nor)) + np.sign(pb @ np.cross(cb, nor)) + np.sign(pc @ np.cross(ac, nor)))
    def seg(pq, q):
        h = np.clip((pq @ q) / max(q @ q, 1e-9), 0.0, 1.0)
        return np.sum((np.outer(h, q) - pq) ** 2, axis=1)
    fuera = np.minimum(np.minimum(seg(pa, ba), seg(pb, cb)), seg(pc, ac))
    dentro = (pa @ nor) ** 2 / max(nor @ nor, 1e-9)
    return np.sqrt(np.where(lado < 2.0, fuera, dentro)) - grosor


def smin(a, b, k):
    if k <= 0: return np.minimum(a, b)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b + (a - b) * h - k * h * (1.0 - h)


# --- HUESOS: transformaciones rigidas (M, t): p_mundo = M p_reposo + t ---
IDENT = (np.eye(3), np.zeros(3))

def rx(a):
    """Gira en el plano Y-Z: con 'a' positivo, lo que esta ENCIMA del pivote se va hacia DELANTE (+Y)."""
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, s], [0, -s, c]], dtype=float)

def ry(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]], dtype=float)

def rz(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]], dtype=float)

def sobre(pivote, M):
    return (M, pivote - M @ pivote)

def comp(X2, X1):
    """Primero X1, luego X2."""
    return (X2[0] @ X1[0], X2[0] @ X1[1] + X2[1])

def aplica(X, p):
    return X[0] @ p + X[1]


class Modelo:
    """Lo de cada enemigo. 'lienzo' (W, H) y 'pies' (x, y) en celdas: donde el juego espera el dibujo (los del generador
    viejo, para que lo coloque igual). 'mat' = {nombre: [sombra, base, luz]}; 'suaves' = los grupos que se funden por
    dentro (los demas se unen duro); 'brillan' = materiales que van siempre en su tono de luz (los ojos)."""
    def __init__(self, escala, lienzo, pies, mat, borde, suaves=('cuerpo',), brillan=('ojo',), estira=1.0,
                 salto_linea=2.6, salto_grupos=1.6, lejos=90.0, corta_suelo=False, especular=(), umbral_especular=0.86,
                 translucidos=(), alfa=0.7):
        self.ppu = escala / 1.15
        self.W, self.H = lienzo
        self.OX, self.OY = pies
        self.mat = mat
        self.nombres = list(mat.keys())
        self.borde = borde
        self.suaves = suaves
        self.brillan = brillan
        self.estira = estira
        self.salto_linea = salto_linea
        self.salto_grupos = salto_grupos
        self.lejos = lejos
        # Nada por debajo del suelo (z < 0): lo que se hunde (el golem que se derrumba) queda cortado a ras.
        self.corta_suelo = corta_suelo
        # BRILLO ESPECULAR (05/10, el gel de los slimes): los materiales de 'especular' llevan un CUARTO tono, el del
        # reflejo, que se pone donde la superficie mira de lleno a la luz (la luz esta fija en pantalla, asi que el
        # brillo cae siempre arriba a la izquierda, como en el viejo). Los demas no cambian.
        self.especular = especular
        self.umbral_especular = umbral_especular
        # TRANSLUCIDOS (05/10, el gel de los slimes: "estan hechos de baba y se ve un poco a traves"): esos materiales se
        # pintan con opacidad 'alfa' y DEJAN VER lo opaco que tengan detras (los ojos, a traves del cuerpo, de espaldas)
        # y el suelo. El contorno se queda opaco: la silueta se tiene que seguir leyendo.
        self.translucidos = translucidos
        self.alfa = alfa


class Piezas(list):
    """La lista de piezas, y ademas las SOMBRAS del suelo: [(x, y, rx, ry, alfa)] en el modelo (z = 0)."""
    sombras = ()


class Escena:
    """Lista de piezas: add(fn, material, k, grupo, hueso). Las de un grupo de 'suaves' se FUNDEN con su k.
    sombra(x, y, rx, ry): una mancha oscura en el SUELO (05/10, los que vuelan: el chillon y la polilla). Los demas no la
    llevan; en uno que vuela, la separacion entre el cuerpo y su sombra es lo unico que se lee como altura."""
    def __init__(self, huesos):
        self.X = huesos
        self.L = Piezas()
        self.L.sombras = []

    def sombra(self, x, y, rx, ry, alfa=0.26):
        self.L.sombras.append((x, y, rx, ry, alfa))

    def add(self, fn, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
        self.L.append((fn, mat, grupo, k, self.X.get(hueso, IDENT), hueso))


def evalua(mo, P, L, con_grupo=False):
    acc = {}; mat = {}; mat_d = {}
    dur = np.full(len(P), 1e9); dur_mat = np.zeros(len(P), dtype=int); dur_g = np.zeros(len(P), dtype=int)
    gid = {g: i for i, g in enumerate(mo.suaves)}
    cache = {}
    otros = {}
    for fn, m, g, k, Xh, nh in L:
        if nh not in cache:
            # Al reposo: p_reposo = M^-1 (p - t). Con la TRASPUESTA solo valia para giros: un hueso que ESCALA (la rata
            # que se estira, el slime que se aplasta) salia al reves (05/10).
            cache[nh] = (P - Xh[1]) @ np.linalg.inv(Xh[0]).T
        d = fn(cache[nh])
        mi = mo.nombres.index(m)
        if g in gid:
            if g not in acc:
                acc[g] = d; mat[g] = np.full(len(P), mi); mat_d[g] = d
            else:
                acc[g] = smin(acc[g], d, k)
                mejor = d < mat_d[g]
                mat[g] = np.where(mejor, mi, mat[g]); mat_d[g] = np.where(mejor, d, mat_d[g])
        else:
            if g not in otros: otros[g] = len(mo.suaves) + len(otros)
            mejor = d < dur
            dur_mat = np.where(mejor, mi, dur_mat); dur_g = np.where(mejor, otros[g], dur_g); dur = np.minimum(dur, d)
    dist = dur; mats = dur_mat; grp = dur_g
    for g, dg in acc.items():
        mejor = dg < dist
        dist = np.where(mejor, dg, dist); mats = np.where(mejor, mat[g], mats); grp = np.where(mejor, gid[g], grp)
    if mo.corta_suelo:
        dist = np.maximum(dist, -P[:, 2])
    if con_grupo:
        return dist, mats, grp
    return dist, mats


def render(mo, L, dir_i):
    """Pinta la escena 'L' mirando hacia la direccion 'dir_i' (0 = S, a camara)."""
    W, H, PPU = mo.W, mo.H, mo.ppu
    v = DIR_VECS[dir_i]
    ang = math.atan2(v[1], v[0]) - math.atan2(1, 0)
    ca, sa = math.cos(-ang), math.sin(-ang)
    jj, ii = np.mgrid[0:H, 0:W]
    u = (ii.ravel() + 0.5 - mo.OX) / PPU
    vv = (mo.OY - (jj.ravel() + 0.5)) / PPU
    O = np.outer(u, R_) + np.outer(vv, U_) - F_ * mo.lejos
    def a_local(P):
        x = P[:, 0] * ca - P[:, 1] * sa; y = P[:, 0] * sa + P[:, 1] * ca
        return np.stack([x, y, P[:, 2]], axis=1)
    t = np.zeros(len(O)); vivo = np.ones(len(O), dtype=bool); toca = np.zeros(len(O), dtype=bool)
    for _ in range(160):
        idx = np.where(vivo)[0]
        if len(idx) == 0: break
        P = a_local(O[idx] + np.outer(t[idx], F_))
        d, _m = evalua(mo, P, L)
        hit = d < 0.02
        toca[idx[hit]] = True; vivo[idx[hit]] = False
        t[idx[~hit]] += np.maximum(d[~hit] * 0.8, 0.02)
        vivo &= ~(t > mo.lejos * 2.1)
    hi = np.where(toca)[0]
    img = np.zeros((H * W, 4))
    # LA SOMBRA DEL SUELO: donde el rayo corta z = 0, si cae dentro de alguna mancha (y no hay cuerpo delante).
    sombra = np.zeros(H * W)
    for (sx, sy, srx, sry, sa_) in getattr(L, 'sombras', ()):
        Ps = a_local(O + np.outer(-O[:, 2] / F_[2], F_))
        dentro = ((Ps[:, 0] - sx) / srx) ** 2 + ((Ps[:, 1] - sy) / sry) ** 2 <= 1.0
        sombra = np.where(dentro, np.maximum(sombra, sa_), sombra)
    if len(hi) == 0:
        img[:, 3] = sombra
        return Image.fromarray((img.reshape(H, W, 4) * 255).astype(np.uint8), 'RGBA')
    P = a_local(O[hi] + np.outer(t[hi], F_))
    _d, mats, grupos = evalua(mo, P, L, True)
    e = 0.05
    n = np.zeros_like(P)
    for a in range(3):
        dv = np.zeros(3); dv[a] = e
        n[:, a] = evalua(mo, P + dv, L)[0] - evalua(mo, P - dv, L)[0]
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-6)
    # La luz, FIJA EN PANTALLA (arriba a la izquierda y algo de delante): se gira con el bicho al reves.
    luz_mundo = np.array([-0.75, 0.35, 0.6]); luz_mundo /= np.linalg.norm(luz_mundo)
    lx = luz_mundo[0] * ca - luz_mundo[1] * sa; ly = luz_mundo[0] * sa + luz_mundo[1] * ca
    ndl = n @ np.array([lx, ly, luz_mundo[2]])
    ao = np.clip(evalua(mo, P + n * 1.2, L)[0] / 1.2, 0, 1)
    # PLANO, como los demas enemigos: casi todo en el tono BASE; la LUZ solo en lo que mira hacia arriba y la SOMBRA en
    # lo que da la espalda a la luz y en los huecos hondos.
    arriba = n[:, 2]
    banda = np.where(arriba > 0.72, 2, np.where(ndl < -0.12, 0, 1))
    banda = np.where(ao < 0.3, 0, banda)
    for i, nom in enumerate(mo.nombres):
        sel = mats == i
        bb = np.full(sel.sum(), 2) if nom in mo.brillan else banda[sel]
        if nom in mo.especular:
            bb = np.where(ndl[sel] > mo.umbral_especular, 3, bb)
        img[hi[sel], :3] = np.array(mo.mat[nom])[bb]
    img[hi, 3] = 1.0
    prof = np.full(H * W, np.inf); prof[hi] = t[hi]
    matmap = np.full(H * W, -1); matmap[hi] = mats
    grpmap = np.full(H * W, -1); grpmap[hi] = grupos; grpmap = grpmap.reshape(H, W)
    img = img.reshape(H, W, 4); prof = prof.reshape(H, W); matmap = matmap.reshape(H, W)
    brilla = np.isin(matmap, [mo.nombres.index(b) for b in mo.brillan if b in mo.nombres])
    sal = img.copy()
    opaco = img[:, :, 3] > 0
    ns = len(mo.suaves)
    lineas = np.zeros_like(opaco)
    # Lo que se ve A TRAVES del gel va sin contorno: los ojos pequeños, vistos de espaldas, eran todo linea oscura.
    for dx, dy in (() if getattr(mo, 'sin_lineas', False) else ((1, 0), (-1, 0), (0, 1), (0, -1))):
        vec_op = np.zeros_like(opaco); vec_pr = np.full_like(prof, np.inf)
        ys = slice(max(0, dy), H + min(0, dy)); yd = slice(max(0, -dy), H + min(0, -dy))
        xs = slice(max(0, dx), W + min(0, dx)); xd = slice(max(0, -dx), W + min(0, -dx))
        vec_op[yd, xd] = opaco[ys, xs]; vec_pr[yd, xd] = prof[ys, xs]
        vec_g = np.full_like(grpmap, -1); vec_g[yd, xd] = grpmap[ys, xs]
        cruza = (vec_g != grpmap) & (grpmap < ns) & (vec_g >= 0) & (vec_g < ns) & (vec_pr - prof > mo.salto_grupos)
        borde = opaco & (~vec_op | ((~brilla) & (vec_pr - prof > mo.salto_linea)) | cruza)
        sal[borde, :3] = mo.borde
        lineas = lineas | borde
    if sombra.any():
        sm = sombra.reshape(H, W) * (~opaco)
        sal[:, :, 3] = np.where(opaco, sal[:, :, 3], sm)
    if mo.translucidos:
        # LO OPACO DE DETRAS: la misma escena sin las piezas translucidas, y se mezcla bajo el gel.
        idx_t = [mo.nombres.index(m) for m in mo.translucidos if m in mo.nombres]
        gel = np.isin(matmap, idx_t) & ~lineas
        L_op = [x for x in L if x[1] not in mo.translucidos]
        if L_op:
            import copy
            mo2 = copy.copy(mo); mo2.translucidos = (); mo2.sin_lineas = True
            detras = np.asarray(render(mo2, L_op, dir_i)).astype(float) / 255.0
        else:
            detras = np.zeros((H, W, 4))
        ad = detras[:, :, 3]
        # Lo que va DENTRO del gel (los ojos) se ve mas que el suelo de detras: esta pegado a la piel, no al fondo.
        a = np.where(ad > 0, getattr(mo, 'alfa_dentro', mo.alfa), mo.alfa)
        # LO QUE BRILLA DENTRO (05/10, los cristales del slime mutante): el gel apenas lo tapa. Mezclado al 42 % con el
        # gel salia GRIS (el cian y el rojo se anulan). Solo donde ESO es lo que se ve detras: se compara con una pasada
        # de solo esas piezas, y si coincide con 'detras', es que no hay otra cosa por delante (un nucleo).
        claros = getattr(mo, 'claros_dentro', ())
        L_cl = [x for x in L_op if x[1] in claros] if L_op else []
        if L_cl:
            solo = np.asarray(render(mo2, L_cl, dir_i)).astype(float) / 255.0
            es_claro = (solo[:, :, 3] > 0) & (np.abs(solo[:, :, :3] - detras[:, :, :3]).sum(axis=2) < 0.02)
            a = np.where(es_claro, getattr(mo, 'alfa_claro', 0.15), a)
        fuera = a + (1.0 - a) * ad
        for ch in range(3):
            mezcla = (sal[:, :, ch] * a + detras[:, :, ch] * ad * (1.0 - a)) / np.maximum(fuera, 1e-6)
            sal[:, :, ch] = np.where(gel, mezcla, sal[:, :, ch])
        sal[:, :, 3] = np.where(gel, fuera, sal[:, :, 3])
    return Image.fromarray((np.clip(sal, 0, 1) * 255).astype(np.uint8), 'RGBA')


def vistas_lado_a_lado(fotos_nuevas, nombre_viejo, salida, escala=4, anim='idle'):
    """Arriba el horneado VIEJO (assets/sprites/enemigos/<nombre_viejo>.json), abajo el NUEVO, las 5 direcciones."""
    d = json.load(open('assets/sprites/enemigos/%s.json' % nombre_viejo))
    im = Image.open('assets/sprites/enemigos/%s.png' % nombre_viejo).convert('RGBA')
    Wv, Hv = d['w'], d['h']
    viejas = []
    for k in range(5):
        a = [x for x in d['anims'] if x['n'] == '%s_%d' % (anim, k)][0]
        x, y, w, h, ox, oy = a['f'][0]
        c = Image.new('RGBA', (Wv, Hv), (0, 0, 0, 0)); c.paste(im.crop((x, y, x + w, y + h)), (ox, oy)); viejas.append(c)
    Wn, Hn = fotos_nuevas[0].size
    Wc, Hc = max(Wv, Wn), max(Hv, Hn)
    v = Image.new('RGB', (Wc * 5, Hc * 2), (40, 42, 50))
    for i in range(5):
        v.paste(viejas[i], (i * Wc + (Wc - Wv) // 2, (Hc - Hv) // 2), viejas[i])
        v.paste(fotos_nuevas[i], (i * Wc + (Wc - Wn) // 2, Hc + (Hc - Hn) // 2), fotos_nuevas[i])
    v = v.resize((v.width * escala, v.height * escala), Image.NEAREST)
    v.save(salida)
    return salida


# ------------------------------------------------------------
#  HORNEAR: hojas (filas = direcciones, columnas = fotogramas) + hojas.json + vistas para mirarlas
# ------------------------------------------------------------
# El modulo del enemigo tiene MODELO, escena(pose) y ANIMS = {nombre: (fotogramas, fps, loop, dirs, fn t -> pose)}.
def _trabajo(args):
    modname, nombre, d, i = args
    mod = importlib.import_module(modname)
    n, fps, loop, dirs, fn = mod.ANIMS[nombre]
    t = i / n if loop else (i / (n - 1) if n > 1 else 0.0)
    # 'escena_dir' (05/10, el latigo del miconido): la escena que depende de hacia donde se mira (que brazo da a camara).
    pose = fn(t)
    L = mod.escena_dir(pose, d) if hasattr(mod, 'escena_dir') else mod.escena(pose)
    im = render(mod.MODELO, L, d)
    # LOS PARPADOS (05/10, los slimes: "que parpadeen y que no sea una vez por repeticion de la animacion"): la misma pose
    # con los ojos CERRADOS, y se guarda SOLO lo que cambia. El juego lo pone encima a ratos, a su aire.
    par = None
    if getattr(mod, 'PARPADOS', False):
        cerr = render(mod.MODELO, mod.escena(dict(pose, cerrados=True)), d)
        a = np.asarray(im).astype(int); b = np.asarray(cerr).astype(int)
        cambia = (np.abs(a - b).max(axis=2) > 2) & (b[:, :, 3] > 0)
        o = np.zeros_like(b); o[cambia] = b[cambia]
        par = Image.fromarray(o.astype(np.uint8), 'RGBA')
    return (nombre, d, i, im, par)


def hornear(modname, nombres, salida, vistas):
    mod = importlib.import_module(modname)
    W, H = mod.MODELO.W, mod.MODELO.H
    os.makedirs(salida, exist_ok=True); os.makedirs(vistas, exist_ok=True)
    trabajos = [(modname, nm, d, i) for nm in nombres for d in range(mod.ANIMS[nm][3]) for i in range(mod.ANIMS[nm][0])]
    with Pool() as pool:
        hechos = pool.map(_trabajo, trabajos)
    meta_path = salida + 'hojas.json'
    meta = json.load(open(meta_path)) if os.path.exists(meta_path) else {}
    meta['lienzo'] = [W, H]
    meta.setdefault('anims', {})
    for nm in nombres:
        n, fps, loop, dirs, fn = mod.ANIMS[nm]
        hoja = Image.new('RGBA', (W * n, H * dirs), (0, 0, 0, 0))
        hoja_p = Image.new('RGBA', (W * n, H * dirs), (0, 0, 0, 0))
        hay_p = False
        for (a, d, i, im, par) in hechos:
            if a == nm:
                hoja.paste(im, (i * W, d * H))
                if par is not None:
                    hoja_p.paste(par, (i * W, d * H)); hay_p = True
        hoja.save(salida + nm + '.png')
        if hay_p:
            hoja_p.save(salida + nm + '_parpado.png')
        meta['anims'][nm] = {'fotogramas': n, 'fps': fps, 'loop': loop, 'dirs': dirs, 'parpado': hay_p}
        filas = min(dirs, 5)
        vista = Image.new('RGB', (W * n, H * filas), (40, 42, 50))
        recorte = hoja.crop((0, 0, W * n, H * filas))
        vista.paste(recorte, (0, 0), recorte)
        vista = vista.resize((vista.width * 2, vista.height * 2), Image.NEAREST)
        vista.save(vistas + modname + '_' + nm + '.png')
        print(nm, 'ok')
    json.dump(meta, open(meta_path, 'w'), indent=1)


def tramos(t, claves):
    """Interpolacion suave entre claves [(t, valor), ...] ordenadas (fuera, el extremo)."""
    if t <= claves[0][0]: return claves[0][1]
    for (t0, v0), (t1, v1) in zip(claves, claves[1:]):
        if t <= t1:
            u = (t - t0) / max(t1 - t0, 1e-6)
            u = u * u * (3 - 2 * u)
            return v0 + (v1 - v0) * u
    return claves[-1][1]


def mover(v):
    return (np.eye(3), np.array(v, dtype=float))
