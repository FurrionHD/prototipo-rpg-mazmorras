# ============================================================
#  sdf_gpu.py -- EL HORNO EN LA GRAFICA (05/11/2026, el jefe: "porque no usas la gpu").
#
#  Hace lo mismo que sdf_comun.render/evalua, numero a numero, pero muchos fotogramas a la vez. Traducir el motor tal cual
#  saldria PEOR que la CPU: en un fotograma hay unas 110 pasadas con ~3600 rayos de media, y una grafica pierde en montones
#  de operaciones pequeñas. Lo que la hace ganar es juntar el trabajo:
#   - las piezas se LEEN como datos (forma + parametros, con la SONDA de sdf_comun) y no se llaman una a una;
#   - los fotogramas con las MISMAS piezas (misma forma, grupo y hueso, en el mismo orden) van en un mismo LOTE: una tabla de
#     parametros [fotograma, pieza] y todos sus rayos juntos, cada uno sabiendo de que fotograma es;
#   - la imagen final la pinta sdf_comun.pintar, el MISMO codigo de la CPU: lineas, gel, sombras y colores no se duplican.
#  Una pieza que hace algo raro con los puntos (no se deja leer) se evalua con numpy tal cual: va lenta, pero sale igual.
#
#  Solo la NVIDIA (cuda). Para comprobarlo contra la CPU: tools/sprites_sdf/gpu_comparar.py.
# ============================================================
import copy, os, threading
from concurrent.futures.process import BrokenProcessPool
import numpy as np
import torch
from PIL import Image
import sdf_comun as sc

DISPOSITIVO = 'cuda'
# float32 va casi el doble de rapido (en float64 esta grafica va muy capada). Mueve pixeles sueltos: 8 de 1,75 millones en el Nudo,
# 7 de 626.000 en la segadora. HORNO_EXACTO=1 (float64): 0 distintos con la CPU; para volver a hornear arte ya aprobado.
TIPO = torch.float64 if os.environ.get('HORNO_EXACTO') else torch.float32
# Memoria de la grafica para una tanda de rayos. (05/11, el jefe: tiene 8 GB y no pasar de 6, para tener margen; este numero
# deja sitio a las tablas del lote: lo reservado de verdad se mide con gpu_comparar.)
MEMORIA = float(os.environ.get('HORNO_GB', 4.5)) * 1e9
# Fotogramas por lote. Mas = menos operaciones sueltas por fotograma, pero mas rayos que partir en tandas.
LOTE = int(os.environ.get('HORNO_LOTE', 64))
# EL TOPE DE DE VERDAD (05/11, el jefe: tiene 8 GB, que no pase de 6): si se llega, salta error de memoria y el lote se parte.
TOPE_GB = float(os.environ.get('HORNO_TOPE_GB', 6))
if torch.cuda.is_available():
    torch.cuda.set_per_process_memory_fraction(min(1.0, TOPE_GB * 1e9 / torch.cuda.get_device_properties(0).total_memory))


MEMORIA_TANDA = [MEMORIA]


def _ten(x, tipo=None):
    return torch.as_tensor(np.asarray(x), device=DISPOSITIVO, dtype=tipo or TIPO)


def leer_pieza(fn):
    """('cono', a, b, ra, rb)... o None si la pieza no se deja leer."""
    try:
        r = fn(sc.SONDA)
    except Exception:
        # (05/11, el slime: np.minimum de dos piezas revienta con ValueError, no TypeError) Lo que no se deja leer, a la CPU.
        return None
    return r if isinstance(r, tuple) else None


def _firma(mo, L):
    """Dos fotogramas pueden ir juntos si sus piezas son del mismo tipo, grupo y hueso, en el mismo orden."""
    firma = []; leidas = []
    for fn, m, g, k, Xh, nh in L:
        r = leer_pieza(fn)
        leidas.append(r)
        firma.append((r[0] if r else 'raro', g, nh, k <= 0))
    return tuple(firma), leidas


class Fotograma:
    def __init__(self, mo, L, d):
        self.mo, self.L, self.d = mo, L, d
        self.firma, self.leidas = _firma(mo, L)
        # (lo que sale de la marcha)
        self.t = self.hi = self.mats = self.grupos = self.n = self.ao = None


class Lote:
    """Las tablas de un lote de fotogramas con la misma firma."""
    def __init__(self, fotos):
        self.fotos = fotos
        mo = fotos[0].mo
        self.mo = mo
        F = len(fotos); firma = fotos[0].firma; K = len(firma)
        self.F, self.K = F, K
        self.ca = _ten([sc.giro_de(f.d)[0] for f in fotos])
        self.sa = _ten([sc.giro_de(f.d)[1] for f in fotos])
        # EL ORDEN DE GRUPOS, como en evalua: 'suaves' por su sitio, los demas por orden de aparicion.
        gid = {g: i for i, g in enumerate(mo.suaves)}
        otros = {}
        self.suaves = {}      # grupo suave -> indices de sus piezas (en orden de aparicion del grupo)
        duras = []
        grupo_de = np.zeros(K, dtype=int)
        for i, (kind, g, nh, _k) in enumerate(firma):
            if g in gid:
                self.suaves.setdefault(g, []).append(i)
                grupo_de[i] = gid[g]
            else:
                if g not in otros: otros[g] = len(mo.suaves) + len(otros)
                duras.append(i)
                grupo_de[i] = otros[g]
        self.duras = torch.tensor(duras, device=DISPOSITIVO, dtype=torch.long)
        self.grupo_de = torch.tensor(grupo_de, device=DISPOSITIVO, dtype=torch.long)
        self.k_cero = {i: firma[i][3] for i in range(K)}
        self.ks = _ten([[x[3] for x in f.L] for f in fotos]).T
        nom = {m: i for i, m in enumerate(mo.nombres)}
        self.mat_de = torch.tensor([[nom[x[1]] for x in f.L] for f in fotos], device=DISPOSITIVO, dtype=torch.long).T
        # HUESOS: como en evalua, cada nombre de hueso se queda con la transformacion de su PRIMERA pieza.
        huesos = {}
        for kind, g, nh, _k in firma:
            if nh not in huesos: huesos[nh] = len(huesos)
        self.hueso_de = torch.tensor([huesos[x[2]] for x in firma], device=DISPOSITIVO, dtype=torch.long)
        B = len(huesos)
        Ta = np.zeros((F, B, 3)); Aa = np.zeros((F, B, 3, 3))
        for fi, f in enumerate(fotos):
            vistos = set()
            for x in f.L:
                nh = x[5]
                if nh in vistos: continue
                vistos.add(nh)
                Ta[fi, huesos[nh]] = x[4][1]
                Aa[fi, huesos[nh]] = np.linalg.inv(x[4][0]).T
        self.T = _ten(Ta).transpose(0, 1); self.A = _ten(Aa).transpose(0, 1)
        self.B = B
        # PARAMETROS por tipo de pieza: [pieza de ese tipo, fotograma, ...]
        self.tipos = {}
        for kind in ('esfera', 'elipsoide', 'cono', 'caja', 'triangulo', 'casquete'):
            ids = [i for i, x in enumerate(firma) if x[0] == kind]
            if not ids: continue
            self.tipos[kind] = (torch.tensor(ids, device=DISPOSITIVO, dtype=torch.long), self._params(kind, ids))
        self.raros = [i for i, x in enumerate(firma) if x[0] == 'raro']

    def _params(self, kind, ids):
        fotos = self.fotos
        def col(j, forma):
            return np.stack([np.stack([np.broadcast_to(np.asarray(f.leidas[i][j], dtype=float), forma) for f in fotos])
                             for i in ids])
        if kind == 'esfera':
            return (_ten(col(1, (3,))), _ten(col(2, ())))
        if kind == 'elipsoide':
            return (_ten(col(1, (3,))), _ten(col(2, (3,))))
        if kind == 'cono':
            a = col(1, (3,)); b = col(2, (3,)); ra = col(3, ()); rb = col(4, ())
            ba = b - a
            return (_ten(a), _ten(ba), _ten(np.maximum((ba * ba).sum(-1), 1e-6)), _ten(ra), _ten(rb - ra))
        if kind == 'caja':
            return (_ten(col(1, (3,))), _ten(col(2, (3, 3))), _ten(col(3, (3,))), _ten(col(4, ())))
        if kind == 'casquete':
            return (_ten(col(1, (3,))), _ten(col(2, (3, 3))), _ten(col(3, (3,))), _ten(col(4, (3,))), _ten(col(5, ())),
                    _ten(col(6, ())))
        a = col(1, (3,)); b = col(2, (3,)); c = col(3, (3,)); g = col(4, ())
        return tuple(_ten(x) for x in (a, b, c, g))

    def bytes_por_rayo(self):
        return (self.K * 20 + self.B * 10 + 30) * (8 if TIPO == torch.float64 else 4)


def _norma(v):
    return torch.sqrt(v[..., 0] * v[..., 0] + v[..., 1] * v[..., 1] + v[..., 2] * v[..., 2])


def _punto(a, b):
    return a[..., 0] * b[..., 0] + a[..., 1] * b[..., 1] + a[..., 2] * b[..., 2]


# LA FORMA DE LAS TABLAS: [pieza, fotograma, rayo], con los rayos de cada fotograma rellenados hasta el del que mas tiene. Los
# parametros van como [pieza, fotograma, 1]: los rayos de un fotograma COMPARTEN los suyos, sin copiarlos rayo a rayo. Copiarlos
# eran ~10 GB de memoria por fotograma, y era eso lo que frenaba (no las cuentas).
def _distancias(lo, x, y, z, fs):
    """La tabla [pieza, fotograma, rayo] de distancias. x, y, z: [fotograma, rayo]; fs: que fotogramas del lote son."""
    Fc, Rm = x.shape
    # Por HUESO (hay muchos menos que piezas): al reposo, como en evalua.
    T = lo.T[:, fs, None]; A = lo.A[:, fs, None]
    vx = x[None] - T[..., 0]; vy = y[None] - T[..., 1]; vz = z[None] - T[..., 2]
    qx = vx * A[..., 0, 0] + vy * A[..., 1, 0] + vz * A[..., 2, 0]
    qy = vx * A[..., 0, 1] + vy * A[..., 1, 1] + vz * A[..., 2, 1]
    qz = vx * A[..., 0, 2] + vy * A[..., 1, 2] + vz * A[..., 2, 2]
    del vx, vy, vz
    D = torch.empty((lo.K, Fc, Rm), device=DISPOSITIVO, dtype=TIPO)
    for kind, (ids, par) in lo.tipos.items():
        hu = lo.hueso_de[ids]
        px = qx[hu]; py = qy[hu]; pz = qz[hu]
        par = [p[:, fs, None] for p in par]
        if kind == 'esfera':
            c, r = par
            px -= c[..., 0]; py -= c[..., 1]; pz -= c[..., 2]
            d = torch.sqrt(px * px + py * py + pz * pz) - r
        elif kind == 'elipsoide':
            c, rad = par
            rx_ = rad[..., 0]; ry_ = rad[..., 1]; rz_ = rad[..., 2]
            px = (px - c[..., 0]) / rx_; py = (py - c[..., 1]) / ry_; pz = (pz - c[..., 2]) / rz_
            k0 = torch.sqrt(px * px + py * py + pz * pz)
            px /= rx_; py /= ry_; pz /= rz_
            k1 = torch.sqrt(px * px + py * py + pz * pz)
            d = k0 * (k0 - 1.0) / torch.clamp(k1, min=1e-6)
        elif kind == 'cono':
            a, ba, bb, ra, drr = par
            bx = ba[..., 0]; by = ba[..., 1]; bz = ba[..., 2]
            px -= a[..., 0]; py -= a[..., 1]; pz -= a[..., 2]
            h = torch.clamp((px * bx + py * by + pz * bz) / bb, 0.0, 1.0)
            px -= h * bx; py -= h * by; pz -= h * bz
            d = torch.sqrt(px * px + py * py + pz * pz) - (ra + drr * h)
        elif kind == 'caja':
            c, ej, medio, red = par
            v2 = torch.stack([px - c[..., 0], py - c[..., 1], pz - c[..., 2]], dim=-1)
            # q @ ejes.T: cada columna es la proyeccion sobre un eje (las filas de 'ejes').
            q2 = torch.stack([_punto(v2, ej[..., j, :]) for j in range(3)], dim=-1)
            dd = q2.abs() - (medio - red[..., None])
            d = _norma(torch.clamp(dd, min=0.0)) + torch.clamp(dd.amax(-1), max=0.0) - red
        elif kind == 'casquete':
            # (09/11) como sdf_comun.sd_casquete: el elipsoide en el marco (P - o) @ M, cortado por la cuenca.
            o, M, c, rad, hh, cu = par
            vx = px - o[..., 0]; vy = py - o[..., 1]; vz = pz - o[..., 2]
            ux = vx * M[..., 0, 0] + vy * M[..., 1, 0] + vz * M[..., 2, 0]
            uy = vx * M[..., 0, 1] + vy * M[..., 1, 1] + vz * M[..., 2, 1]
            uz = vx * M[..., 0, 2] + vy * M[..., 1, 2] + vz * M[..., 2, 2]
            del vx, vy, vz
            rx_ = rad[..., 0]; ry_ = rad[..., 1]; rz_ = rad[..., 2]
            ex = (ux - c[..., 0]) / rx_; ey = (uy - c[..., 1]) / ry_; ez = (uz - c[..., 2]) / rz_
            k0 = torch.sqrt(ex * ex + ey * ey + ez * ez)
            ex /= rx_; ey /= ry_; ez /= rz_
            k1 = torch.sqrt(ex * ex + ey * ey + ez * ez)
            cap = k0 * (k0 - 1.0) / torch.clamp(k1, min=1e-6)
            d = torch.maximum(cap, -(uz - hh - cu * (ux * ux + uy * uy)))
            del ux, uy, uz, ex, ey, ez, k0, k1, cap
        else:
            d = _triangulo(torch.stack([px, py, pz], dim=-1), par)
        D[ids] = d
        del px, py, pz, d
    if lo.raros:
        # Con numpy, tal cual. (Los rayos de relleno tambien, pero no se miran.)
        for j, f in enumerate(fs.tolist()):
            for i in lo.raros:
                h = lo.hueso_de[i]
                qq = torch.stack([qx[h, j], qy[h, j], qz[h, j]], dim=1).double().cpu().numpy()
                D[i, j] = _ten(lo.fotos[f].L[i][0](qq))
    return D


def _triangulo(q, par):
    a, b, c, gr = par
    ba = b - a; pa = q - a; cb = c - b; pb = q - b; ac = a - c; pc = q - c
    nor = torch.linalg.cross(ba.expand_as(q), ac.expand_as(q), dim=-1)
    lado = (torch.sign(_punto(pa, torch.linalg.cross(ba.expand_as(q), nor, dim=-1))) + torch.sign(_punto(pb, torch.linalg.cross(cb.expand_as(q), nor, dim=-1)))
            + torch.sign(_punto(pc, torch.linalg.cross(ac.expand_as(q), nor, dim=-1))))
    def seg(pq, w):
        h = torch.clamp(_punto(pq, w) / torch.clamp(_punto(w, w), min=1e-9), 0.0, 1.0)
        v = h[..., None] * w - pq
        return _punto(v, v)
    fuera = torch.minimum(torch.minimum(seg(pa, ba), seg(pb, cb)), seg(pc, ac))
    pn = _punto(pa, nor)
    dentro = pn * pn / torch.clamp(_punto(nor, nor), min=1e-9)
    return torch.sqrt(torch.where(lado < 2.0, fuera, dentro)) - gr


def _evalua_tanda(lo, x, y, z, fs, con_grupo):
    """sdf_comun.evalua en lote: el mismo orden de fusion y los mismos desempates."""
    D = _distancias(lo, x, y, z, fs)
    mats = grp = None
    if len(lo.duras):
        dist, cual = D[lo.duras].min(dim=0)
        dist = torch.minimum(dist, torch.full_like(dist, 1e9))
        if con_grupo:
            pieza = lo.duras[cual]
            grp = lo.grupo_de[pieza]; mats = lo.mat_de[pieza, fs[:, None]]
    else:
        dist = torch.full_like(x, 1e9)
        if con_grupo:
            grp = torch.zeros_like(x, dtype=torch.long); mats = torch.zeros_like(x, dtype=torch.long)
    ks = lo.ks[:, fs, None]
    for g, ids in lo.suaves.items():
        acc = D[ids[0]]
        for i in ids[1:]:
            d = D[i]
            if lo.k_cero[i]:
                acc = torch.minimum(acc, d)
            else:
                k = ks[i]
                h = torch.clamp(0.5 + 0.5 * (d - acc) / k, 0.0, 1.0)
                acc = d + (acc - d) * h - k * h * (1.0 - h)
        mejor = acc < dist
        dist = torch.where(mejor, acc, dist)
        if con_grupo:
            # El material de un grupo que se funde: el de la pieza mas cercana (la primera, si empatan).
            sub = torch.tensor(ids, device=DISPOSITIVO, dtype=torch.long)
            pieza = sub[D[sub].argmin(dim=0)]
            mats = torch.where(mejor, lo.mat_de[pieza, fs[:, None]], mats)
            grp = torch.where(mejor, lo.grupo_de[pieza], grp)
    if lo.mo.corta_suelo:
        dist = torch.maximum(dist, -z)
    return (dist, mats, grp) if con_grupo else dist


def _en_tandas(lo, P, fi, con_grupo=False):
    """Evalua rayos sueltos (P [N,3], fi [N] EN ORDEN de fotograma): los coloca por fotograma y va por tandas que quepan."""
    cuentas = torch.bincount(fi, minlength=lo.F)
    inicio = torch.cumsum(cuentas, 0) - cuentas
    pos = torch.arange(len(fi), device=DISPOSITIVO) - inicio[fi]
    activos = torch.nonzero(cuentas)[:, 0].tolist()
    lista = cuentas.tolist()
    tope = MEMORIA_TANDA[0] / lo.bytes_por_rayo()
    salidas = []
    i = 0
    while i < len(activos):
        # Cuantos fotogramas entran, contando que todos se rellenan hasta el mayor.
        j = i; rm = 0
        while j < len(activos):
            r2 = max(rm, lista[activos[j]])
            if j > i and (j - i + 1) * r2 > tope: break
            rm = r2; j += 1
        fs = torch.tensor(activos[i:j], device=DISPOSITIVO)
        donde = torch.full((lo.F,), -1, device=DISPOSITIVO, dtype=torch.long); donde[fs] = torch.arange(j - i, device=DISPOSITIVO)
        m = (fi >= activos[i]) & (fi <= activos[j - 1])
        fl = donde[fi[m]]; ps = pos[m]
        tab = torch.zeros((j - i, rm, 3), device=DISPOSITIVO, dtype=TIPO)
        tab[fl, ps] = P[m]
        r = _evalua_tanda(lo, tab[..., 0], tab[..., 1], tab[..., 2], fs, con_grupo)
        salidas.append(tuple(c[fl, ps] for c in r) if con_grupo else r[fl, ps])
        i = j
    if len(salidas) == 1:
        return salidas[0]
    if con_grupo:
        return tuple(torch.cat(c) for c in zip(*salidas))
    return torch.cat(salidas)


def _a_local(lo, P, fi):
    ca = lo.ca[fi]; sa = lo.sa[fi]
    return torch.stack([P[:, 0] * ca - P[:, 1] * sa, P[:, 0] * sa + P[:, 1] * ca, P[:, 2]], dim=1)


def _marchar(lo):
    """Lanza los rayos de todos los fotogramas del lote y deja en cada Fotograma lo que necesita pintar()."""
    mo = lo.mo
    O = _ten(sc.origenes(mo)); Fv = _ten(sc.F_)
    Npx = len(O); N = Npx * lo.F
    fi_todo = torch.arange(lo.F, device=DISPOSITIVO).repeat_interleave(Npx)
    px_todo = torch.arange(Npx, device=DISPOSITIVO).repeat(lo.F)
    t = torch.zeros(N, device=DISPOSITIVO, dtype=TIPO)
    toca = torch.zeros(N, device=DISPOSITIVO, dtype=torch.bool)
    vivos = torch.arange(N, device=DISPOSITIVO)
    limite = mo.lejos * 2.1
    for _ in range(160):
        if len(vivos) == 0: break
        fi = fi_todo[vivos]
        P = _a_local(lo, O[px_todo[vivos]] + t[vivos, None] * Fv, fi)
        d = _en_tandas(lo, P, fi)
        hit = d < 0.02
        toca[vivos[hit]] = True
        sigue = vivos[~hit]
        t[sigue] += torch.clamp(d[~hit] * 0.8, min=0.02)
        vivos = sigue[~(t[sigue] > limite)]
    # LOS QUE TOCAN: material, grupo, normal y oclusion, como en render.
    hi = torch.where(toca)[0]
    if len(hi):
        fi = fi_todo[hi]
        P = _a_local(lo, O[px_todo[hi]] + t[hi, None] * Fv, fi)
        _d, mats, grupos = _en_tandas(lo, P, fi, True)
        e = 0.05
        n = torch.zeros_like(P)
        for a in range(3):
            dv = torch.zeros(3, device=DISPOSITIVO, dtype=TIPO); dv[a] = e
            n[:, a] = _en_tandas(lo, P + dv, fi) - _en_tandas(lo, P - dv, fi)
        n = n / torch.clamp(_norma(n)[:, None], min=1e-6)
        ao = torch.clamp(_en_tandas(lo, P + n * 1.2, fi) / 1.2, 0.0, 1.0)
        fi_c = fi.cpu().numpy(); px_c = px_todo[hi].cpu().numpy()
        mats = mats.cpu().numpy(); grupos = grupos.cpu().numpy(); n = n.double().cpu().numpy(); ao = ao.double().cpu().numpy()
        t_hi = t[hi].double().cpu().numpy()
    for k, f in enumerate(lo.fotos):
        f.t = np.zeros(Npx); f.hi = np.zeros(0, dtype=np.int64)
        if len(hi):
            m = fi_c == k
            f.hi = px_c[m]; f.t[f.hi] = t_hi[m]
            f.mats = mats[m]; f.grupos = grupos[m]; f.n = n[m]; f.ao = ao[m]
    del O, t, toca, vivos, fi_todo, px_todo


def _clave(f):
    # id(f.mo): un lote, un modelo (el Lote usa el de su primer fotograma). Con modelo_de cada pose puede traer el suyo.
    return (f.firma, f.mo.W, f.mo.H, f.mo.lejos, f.mo.corta_suelo, tuple(f.mo.suaves), id(f.mo))


def _lanzar(grupo):
    """Lanza un lote. Si no cabe en la grafica (el tope, o que otro programa la este usando), lo parte en dos."""
    try:
        _marchar(Lote(grupo))
    except torch.OutOfMemoryError:
        torch.cuda.empty_cache()
        if len(grupo) == 1 and MEMORIA_TANDA[0] < 2e8:
            raise
        if len(grupo) == 1:
            MEMORIA_TANDA[0] /= 2
            print('horno: la grafica va justa, tandas mas pequeñas')
            _lanzar(grupo)
            return
        _lanzar(grupo[:len(grupo) // 2]); _lanzar(grupo[len(grupo) // 2:])


def marchar_todo(fotos):
    """Los junta por firma y los lanza en lotes de LOTE."""
    por_firma = {}
    for f in fotos:
        por_firma.setdefault(_clave(f), []).append(f)
    for grupo in por_firma.values():
        for i in range(0, len(grupo), LOTE):
            _lanzar(grupo[i:i + LOTE])
    torch.cuda.empty_cache()


def _pintar(f, sub=None):
    return sc.pintar(f.mo, f.L, f.d, f.t, f.hi, f.mats, f.grupos, f.n, f.ao, sub)


def render_lote(trabajos):
    """[(mo, L, d)] -> [Image]: como sc.render de cada uno, pero todos juntos en la grafica."""
    fotos = []; planes = []
    for mo, L, d in trabajos:
        f = Fotograma(mo, L, d); fotos.append(f)
        subs = []
        if mo.translucidos:
            # LO DE DETRAS DEL GEL: las mismas sub-escenas que pide pintar(), y en el mismo orden.
            L_op = [x for x in L if x[1] not in mo.translucidos]
            if L_op:
                mo2 = copy.copy(mo); mo2.translucidos = (); mo2.sin_lineas = True
                sf = Fotograma(mo2, L_op, d); subs.append(sf); fotos.append(sf)
                claros = getattr(mo, 'claros_dentro', ())
                L_cl = [x for x in L_op if x[1] in claros]
                if L_cl:
                    sf2 = Fotograma(mo2, L_cl, d); subs.append(sf2); fotos.append(sf2)
        planes.append((f, subs))
    marchar_todo(fotos)
    sal = []
    for f, subs in planes:
        cola = iter(subs)
        sal.append(_pintar(f, (lambda m, Ls, di, c=cola: _pintar(next(c))) if subs else None))
    return sal


def _hacer_lote(mod, tareas):
    """[(nm, d, i, pose, L)] -> las tuplas de sdf_comun._trabajo (nm, d, i, imagen, parpados)."""
    trabajos = [(sc.modelo_de(mod, x[3]), x[4], x[1]) for x in tareas]
    n_base = len(trabajos)
    # LOS PARPADOS, detras: la misma pose con los ojos cerrados (ver sc._trabajo).
    parp = []
    if getattr(mod, 'PARPADOS', False):
        grupos = getattr(mod, 'GRUPOS_PARPADO', 1)
        for k, x in enumerate(tareas):
            for g in range(1, grupos + 1):
                parp.append(k)
                trabajos.append((sc.modelo_de(mod, x[3]), mod.escena(dict(x[3], cerrados=True if grupos == 1 else g)), x[1]))
    imgs = render_lote(trabajos)
    pares = {}
    for k, im in zip(parp, imgs[n_base:]):
        a = np.asarray(imgs[k]).astype(int); b = np.asarray(im).astype(int)
        cambia = (np.abs(a - b).max(axis=2) > 2) & (b[:, :, 3] > 0)
        o = np.zeros_like(b); o[cambia] = b[cambia]
        pares.setdefault(k, []).append(Image.fromarray(o.astype(np.uint8), 'RGBA'))
    return [(x[0], x[1], x[2], imgs[k], pares.get(k) if parp else None) for k, x in enumerate(tareas)]


class Cola:
    """QUIEN HACE CADA FOTOGRAMA. Los que tienen piezas que no se dejan leer son de la CPU; los demas, de la grafica, en orden
    para que los lotes salgan de la misma firma.
    HIBRIDO (05/11, el jefe: "que se complementen"; desde el 09/11 SIEMPRE, sin HORNO=): la CPU que se queda sin nada coge de los de la grafica, por el
    final. Medido: segadora 16,7 s solo grafica y 17,3 hibrido; Nudo 107,7 y 100,8. No sale a cuenta poner 12 nucleos a tope por
    defecto, pero se queda para tandas largas o bichos con muchas piezas (el Nudo tiene 152), donde gana algo."""
    def __init__(self, hibrido=False):
        self.hibrido = hibrido
        self.candado = threading.Lock()
        self.raros = []
        self.lotes = []          # [(clave, [tareas])], cada lista se gasta por los dos lados

    def para_cpu(self):
        with self.candado:
            if self.raros:
                return self.raros.pop()
            while self.hibrido and self.lotes:
                if self.lotes[-1][1]:
                    return self.lotes[-1][1].pop()
                self.lotes.pop()
        return None

    def para_gpu(self):
        with self.candado:
            while self.lotes:
                if self.lotes[0][1]:
                    t = self.lotes[0][1]
                    r = t[:LOTE]; del t[:LOTE]
                    return r
                self.lotes.pop(0)
        return None


def hechos_de(modname, mod, nombres, pool, n_cpu, hibrido=False):
    """Lo que devolvia pool.map(_trabajo, ...), de todos los fotogramas."""
    cola = Cola(hibrido)
    por_clave = {}
    for nm in nombres:
        n, fps, loop, dirs, fn = mod.ANIMS[nm]
        for d in range(dirs):
            for i in range(n):
                t = i / n if loop else (i / (n - 1) if n > 1 else 0.0)
                pose = fn(t)
                L = mod.escena_dir(pose, d) if hasattr(mod, 'escena_dir') else mod.escena(pose)
                tarea = (nm, d, i, pose, L)
                f = Fotograma(sc.modelo_de(mod, pose), L, d)
                if any(x[0] == 'raro' for x in f.firma):
                    cola.raros.append(tarea)
                else:
                    por_clave.setdefault(_clave(f), []).append(tarea)
    cola.lotes = list(por_clave.items())
    hechos = []; cuenta = {'gpu': 0, 'cpu': 0}; candado = threading.Lock(); fallos = []

    def hilo_cpu():
        try:
            while True:
                x = cola.para_cpu()
                if x is None: return
                try:
                    r = pool.submit(sc._trabajo, (modname, x[0], x[1], x[2])).result()
                except BrokenProcessPool:
                    # SE HA MUERTO UN PROCESO (05/11, medido: con Pool se quedaba esperando para siempre). Lo que llevaba y lo
                    # que queda lo acaba la grafica.
                    with cola.candado:
                        cola.raros.append(x)
                    print('horno: se ha caido un proceso; sigue la grafica')
                    return
                with candado:
                    hechos.append(r); cuenta['cpu'] += 1
        except Exception as e:
            fallos.append(e)

    hilos = [threading.Thread(target=hilo_cpu, daemon=True) for _ in range(n_cpu if (hibrido or cola.raros) else 0)]
    for h in hilos: h.start()
    while True:
        tareas = cola.para_gpu()
        if tareas is None: break
        r = _hacer_lote(mod, tareas)
        with candado:
            hechos.extend(r); cuenta['gpu'] += len(r)
    for h in hilos: h.join()
    if fallos: raise fallos[0]
    # Lo que devolvieron los procesos caidos (y lo que les hubiera tocado).
    while True:
        tareas = cola.para_gpu()
        if tareas is None and cola.raros:
            tareas = cola.raros[:LOTE]; del cola.raros[:LOTE]
        if tareas is None: break
        r = _hacer_lote(mod, tareas)
        hechos.extend(r); cuenta['gpu'] += len(r)
    print('horno: %d fotogramas en la grafica, %d en la CPU' % (cuenta['gpu'], cuenta['cpu']))
    return hechos
