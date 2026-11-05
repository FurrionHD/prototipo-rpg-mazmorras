# ============================================================
#  segadora_mut_sdf.py -- LOS MUTANTES DE LA SEGADORA, con sus animaciones (05/11/2026, segadora-mutante).
#  Los cuerpos son los elegidos en segadora_mutantes_versiones.py, sobre SU mantis de siempre (segadora_sdf):
#    SEG_VAR=sierra    SEGADORA DE SIERRA  1a C: garras de metal x1,4 con dientes, hombreras, cuernos y cresta; oscura hacia rojo.
#    SEG_VAR=vendaval  VENDAVAL ROJO       2a B: garras x1,6 anchas y mas dentadas, hombreras, cuernos y alas entreabiertas; muy roja.
#  "que se vea que puede doblar las garras": en reposo van PLEGADAS (su reposo es acecho); los golpes ya las abren.
#  Uso: SEG_VAR=sierra python tools/sprites_sdf/segadora_mut_sdf.py [anim ...] -> assets/sprites/enemigos/segadora_sdf_<var>/
#       SEG_VAR=sierra python tools/sprites_sdf/segadora_mut_sdf.py hoja [anim ...] -> la hoja para mirarla, al escritorio
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import segadora_sdf as base
import segadora_mutantes_versiones as ver

V = np.array
VAR = os.environ.get('SEG_VAR', 'sierra')
SALIDA = 'assets/sprites/enemigos/segadora_sdf_%s/' % VAR
VISTAS = 'tools/salida/sdf/'
_cono = base._cono
_elip = base._elip
_unit = base._unit

# LA TRANSICION DE COLOR (memoria transiciones-de-color): en la evolucion cada material se mezcla poco a poco.
PASOS_TINTE = 10
_FINAL = ver.MAT1 if VAR == 'sierra' else ver.MAT2


def _de(m):
    """De que color sale cada material en la evolucion: de la segadora normal (lo que no tenia, de lo mas parecido) o de la sierra."""
    if VAR == 'vendaval':
        return ver.MAT1.get(m, _FINAL[m])
    return base.MAT.get({'placa': 'cuerpo', 'diente': 'hoja', 'brillo': 'cuerpo'}.get(m, m))


def _cuatro(tonos, n):
    # Los que llevan reflejo tienen un cuarto tono: si el de origen no lo tiene, el suyo de luz.
    return list(tonos) + [tonos[-1]] * (n - len(tonos))


_MAT = dict(_FINAL)
_ESPECULAR = ['ojo', 'hoja']
for _m, _tonos in _FINAL.items():
    _origen = _cuatro(_de(_m), len(_tonos))
    for _k in range(PASOS_TINTE):
        _u = _k / PASOS_TINTE
        _MAT['%s>%d' % (_m, _k)] = [tuple(x + (y - x) * _u for x, y in zip(a, b)) for a, b in zip(_origen, _tonos)]
    if _m in ('ojo', 'hoja'):
        _ESPECULAR += ['%s>%d' % (_m, _k) for _k in range(PASOS_TINTE)]

_LIENZO = (220, 220)
MODELO = Modelo(2.5, _LIENZO, (110, 122), _MAT, (0.05, 0.02, 0.03), suaves=('cuerpo', 'cabeza'),
                brillan=['pupila', 'brillo'] + ['pupila>%d' % k for k in range(PASOS_TINTE)] + ['brillo>%d' % k for k in range(PASOS_TINTE)],
                corta_suelo=True, especular=tuple(_ESPECULAR), umbral_especular=0.78)

# (tibia, ancho, dientes, tamaño de diente) de cada una: las de la lamina elegida.
_SIERRA = (1.4, 1.0, 4, 1.0)
_VENDAVAL = (1.6, 1.3, 5, 1.25)


def POSE(**k):
    p = base.POSE(evo=1.0, tinte=1.0, barre=0.0, sube=0.0, alas=0.0, vibra=0.0)
    p.update(k)
    return p


def _huesos(p):
    X = _huesos_base(p)
    # El salto atras y el temblor de la evolucion: el bicho entero. (Las poses de las anims de la normal no llevan estas claves.)
    sube, vibra = p.get('sube', 0.0), p.get('vibra', 0.0)
    if sube or vibra:
        m = mover((vibra, 0.0, sube))
        X = {k: comp(m, v) for k, v in X.items()}
    return X


_huesos_base = base.huesos
base.huesos = _huesos


def _cfg(p):
    """Como va el arma en esta pose: en la evolucion crece desde lo que era."""
    e = p.get('evo', 1.0)
    if VAR == 'sierra':
        t, a, n, d = _SIERRA
        return dict(tibia=1.0 + (t - 1.0) * e, ancho=a, n=n, tam=d * e, panza=e, u0=None, garfio=1.0 - e, plegado=e)
    t, a, n, d = _VENDAVAL
    t0, a0, n0, d0 = _SIERRA
    return dict(tibia=t0 + (t - t0) * e, ancho=a0 + (a - a0) * e, n=n, tam=d0 + (d - d0) * e, panza=1.0, u0=n0, garfio=0.0, plegado=1.0)


def _hoja(add, g, codo, dt, largo, cfg):
    """La hoja de metal, un poco curva, con los dientes por el filo: la de la lamina elegida."""
    an = cfg['ancho']
    n = 8
    panza = ver._panza(dt) * cfg['panza']
    pts = [codo + dt * largo * (i / n) + panza * math.sin(math.pi * i / n) * largo * 0.2 for i in range(n + 1)]
    prev = None
    for i, q in enumerate(pts):
        w = (1.15 - 0.72 * (i / n) ** 1.6) * an
        if prev is not None:
            _cono(add, prev[0], q, prev[1], w, 'hoja', 0, g)
        prev = (q, w)
    # El garfio de la normal se va metiendo en la hoja.
    if cfg['garfio'] > 0.02:
        _cono(add, pts[-1], pts[-1] - dt * 0.5 * cfg['garfio'] + panza * 0.0 + ver._panza(dt) * -1.2 * cfg['garfio'], 0.42, 0.12, 'hoja', 0, g)
    nd = cfg['n']
    for k in range(nd):
        u = 0.14 + 0.72 * k / max(nd - 1, 1)
        tam = cfg['tam'] * (1.0 - 0.35 * u)
        # De 4 dientes a 5 en la evolucion: los cuatro se reparten y el quinto sale en la punta.
        if cfg['u0']:
            e = max(0.0, min(1.0, (cfg['tibia'] - _SIERRA[0]) / (_VENDAVAL[0] - _SIERRA[0])))
            if k < cfg['u0']:
                u = (0.14 + 0.72 * k / max(cfg['u0'] - 1, 1)) * (1.0 - e) + u * e
            else:
                tam *= e
        if tam < 0.04:
            continue
        i0 = int(u * n)
        q = pts[i0] * (1.0 - (u * n - i0)) + pts[min(i0 + 1, n)] * (u * n - i0)
        w = (1.15 - 0.72 * u ** 1.6) * an
        fuera = ver._panza(dt)
        pie = q + fuera * w * 0.5
        _cono(add, pie, pie + fuera * 2.2 * tam + dt * 0.7 * tam, 0.62 * tam, 0.14, 'diente', 0, g + 'd')


def _guadana(add, p, s):
    a = p['abre'] if (s > 0 or p['abre_izq'] < 0) else p['abre_izq']
    a = max(0.0, min(1.0, a))
    cfg = _cfg(p)
    # PLEGADA HACIA ATRAS Y ABAJO, contra el pecho (la de la lamina): si no, desde esta camara se queda en un muñon.
    tp = base.TIBIA_PLEGADO + (V((0.26, -0.58, -0.77)) - base.TIBIA_PLEGADO) * cfg['plegado']

    def mezcla(d0, d1):
        d = _unit(d0 + (d1 - d0) * a)
        return V((d[0] * s, d[1], d[2]))
    df = mezcla(base.FEMUR_PLEGADO, base.FEMUR_ABIERTO)
    dt = mezcla(tp, base.TIBIA_ABIERTO)
    # ALZAR (por encima de la cabeza) y BARRER (la Siega: las dos de lado a lado, juntas).
    R = rx(-p['alza'] * 0.9)
    bar = p.get('barre', 0.0)
    if bar:
        R = rz(bar * 1.15) @ R
    df = R @ df; dt = R @ dt
    hom = base.GUADANA_ANCLA * V((s, 1, 1))
    codo = hom + df * base.FEMUR_LARGO
    g = 'guadana_%d' % s
    _cono(add, hom - V((0.6 * s, 0.6, 0.6)), hom, 0.95, 0.95, 'guadana', 0, g)
    _cono(add, hom, codo, 1.55, 1.20, 'guadana', 0, g)
    dentro = _unit(dt - df * float(dt @ df))
    for i in range(4):
        b = hom + df * base.FEMUR_LARGO * (0.30 + 0.17 * i)
        _cono(add, b, b + dentro * 1.55 + df * 0.35, 0.42, 0.10, 'espina', 0, g)
    _hoja(add, g, codo, dt, base.TIBIA_LARGO * cfg['tibia'], cfg)


base._guadana = _guadana


# ---------- LOS DETALLES: los de la lamina, y en la evolucion crecen desde su sitio ('e' de 0 a 1) ----------
def _hombreras(add, cab, e):
    for s in (-1, 1):
        _elip(add, (2.1 * s, 13.0, 3.6), (1.7 * e, 2.1 * e, 1.0 * e), 'placa', 0, 'hombrera')
        a = V((2.6 * s, 13.2, 4.1)); b = V((4.1 * s, 12.2, 6.0))
        _cono(add, a, a + (b - a) * e, 0.65 * e, 0.14, 'espina', 0, 'hombrera')


def _cuernos(add, cab, e):
    for s in (-1, 1):
        c = base.CABEZA + V((1.3 * s, -0.2, 1.3))
        _cono(cab, c, c + V((1.0 * s, -2.4, 2.6)) * e, 0.62 * e, 0.14, 'espina', 0, 'cuerno')


def _cresta(add, cab, e):
    for i in range(4):
        y, z = 12.0 - i * 2.6, 3.4 - i * 0.55
        _cono(add, (0.0, y, z), (0.0, y - 1.1 * e, z + (2.1 - i * 0.15) * e), 0.62 * e, 0.12, 'espina', 0, 'cresta')
    for i in range(5):
        y, z = 0.5 - i * 2.9, 2.05 - i * 0.14
        _cono(add, (0.0, y, z), (0.0, y - 1.0 * e, z + (1.7 - i * 0.22) * e), 0.55 * e, 0.12, 'espina', 0, 'cresta')


def _alas(add, cab, e, abiertas):
    # Dos hojas rojas asomando por los lados, con su nervio. 'abiertas': en el Vendaval y al saltar se despliegan.
    for s in (-1, 1):
        a = V((1.2 * s, 2.0, 2.2))
        b = V(((6.6 + 3.4 * abiertas) * s, -9.5 + 3.0 * abiertas, 2.8 + 2.4 * abiertas))
        c0 = a + V((1.0 * s, -2.0, 0.6))
        c1 = V(((7.4 + 3.8 * abiertas) * s, -6.0 + 2.6 * abiertas, 3.2 + 2.0 * abiertas))
        _cono(add, a, a + (b - a) * e, 1.1 * e, 0.5 * e, 'tegmina', 0, 'ala%d' % s)
        _cono(add, a + (c0 - a) * e, a + (c1 - a) * e, 0.8 * e, 0.3 * e, 'tegmina', 0, 'ala%d' % s)
        _cono(add, a, a + (b - a) * e, 0.32 * e, 0.14 * e, 'placa', 0, 'nervio%d' % s)


def _nombre_tinte(m, u):
    if u >= 1.0:
        return m
    return '%s>%d' % (m, min(PASOS_TINTE - 1, int(u * PASOS_TINTE)))


def escena(pose):
    p = pose
    L = base.escena(p)
    e = Escena(base.huesos(p))
    cab = lambda fn, mat, k=0.0, grupo='cuerpo', hueso='raiz': e.add(fn, mat, k, grupo, 'cabeza')
    ev = p.get('evo', 1.0)
    if VAR == 'sierra':
        if ev > 0.03:
            _hombreras(e.add, cab, ev)
            _cuernos(e.add, cab, ev)
            _cresta(e.add, cab, ev)
    else:
        _hombreras(e.add, cab, 1.0)
        _cuernos(e.add, cab, 1.0)
        if ev < 0.97:
            _cresta(e.add, cab, 1.0 - ev)
        if ev > 0.03:
            _alas(e.add, cab, ev, p.get('alas', 0.0))
    L.extend(e.L)
    u = p.get('tinte', 1.0)
    if u < 1.0:
        L[:] = [(fn, _nombre_tinte(m, u), g, k, X, nh) for fn, m, g, k, X, nh in L]
    return L


# ------------------------------------------------------------
#  ANIMACIONES: las de su normal (los mismos tiempos: sus efectos siguen cayendo igual) y las suyas
# ------------------------------------------------------------
def a_siega_carga(t):
    # SE YERGUE con las dos garras por encima, echada atras a un lado: de aqui sale el barrido (lo que avisa).
    return POSE(abre=0.9, alza=0.95 + 0.06 * math.sin(2 * math.pi * t), barre=-0.8, avance=-1.4,
                vibra=0.12 * math.sin(4 * math.pi * t))


def a_siega(t):
    # EL BARRIDO: bajan y cruzan de lado a lado juntas por delante (toca en 0,33: IMPACTO 'siega').
    return POSE(abre=tramos(t, [(0.0, 0.9), (0.17, 1.0), (0.66, 1.0), (1.0, 0.1)]),
                alza=tramos(t, [(0.0, 0.95), (0.17, 0.55), (0.33, -0.1), (0.66, -0.15), (1.0, 0.0)]),
                barre=tramos(t, [(0.0, -0.8), (0.17, -0.5), (0.33, 0.15), (0.5, 0.85), (0.66, 1.0), (1.0, 0.0)]),
                avance=tramos(t, [(0.0, -1.4), (0.33, 2.4), (0.66, 2.6), (1.0, 0.0)]))


def _abre_arriba(t, lado):
    # El basico del Vendaval: "extiende las garras hacia delante, levanta el brazo" y lanza; toca en el mismo sitio que el de la normal.
    a = tramos(t, [(0.0, 0.0), (0.2, 0.9), (0.4, 1.0), (0.5, 1.0), (0.75, 0.8), (1.0, 0.1)])
    return POSE(abre=a if lado else 0.05, abre_izq=0.05 if lado else a,
                alza=tramos(t, [(0.0, 0.0), (0.2, 0.25), (0.4, 0.6), (0.5, -0.1), (0.75, 0.0), (1.0, 0.0)]),
                avance=tramos(t, base._AVANCE_BASICO), alas=tramos(t, [(0.0, 0.0), (0.4, 0.4), (1.0, 0.0)]))


def a_basico_viento(t):
    return _abre_arriba(t, False)


def a_basico_der_viento(t):
    return _abre_arriba(t, True)


def a_vendaval_carga(t):
    # LAS DOS GARRAS EXTENDIDAS HACIA DELANTE y las alas abriendose: se esta llenando de aire.
    return POSE(abre=1.0, alza=0.1 + 0.08 * math.sin(2 * math.pi * t), alas=0.75 + 0.25 * math.sin(2 * math.pi * t),
                avance=-1.0, vibra=0.15 * math.sin(4 * math.pi * t))


def a_vendaval(t):
    # Las levanta y las deja caer abriendose: salen los tres cortes (toca en 0,5: IMPACTO 'vendaval').
    return POSE(abre=1.0 - 0.8 * max(0.0, (t - 0.75) / 0.25),
                alza=tramos(t, [(0.0, 0.1), (0.33, 1.0), (0.5, -0.15), (0.75, -0.1), (1.0, 0.0)]),
                barre=0.0, alas=tramos(t, [(0.0, 1.0), (0.33, 1.0), (0.5, 0.6), (1.0, 0.0)]),
                avance=tramos(t, [(0.0, -1.0), (0.33, -1.4), (0.5, 1.6), (1.0, 0.0)]))


def a_salto_atras(t):
    # VUELO CORTO: un aletazo atras, sin dejar de mirarte, con las garras abiertas para el corte (lo lanza en 0,6).
    return POSE(sube=tramos(t, [(0.0, 0.0), (0.3, 3.4), (0.7, 3.0), (1.0, 0.0)]),
                alas=tramos(t, [(0.0, 0.2), (0.3, 1.0), (0.7, 0.8), (1.0, 0.0)]),
                abre=tramos(t, [(0.0, 0.0), (0.4, 0.3), (0.6, 1.0), (1.0, 0.1)]), abre_izq=0.05,
                agacha=tramos(t, [(0.0, 0.3), (0.2, 0.0), (0.85, 0.0), (1.0, 0.3)]))


def a_comer(t):
    # Se agacha y mastica lo que tiene entre las garras.
    return POSE(abre=tramos(t, [(0.0, 0.0), (0.2, 0.35), (1.0, 0.2)]),
                agacha=tramos(t, [(0.0, 0.0), (0.2, 0.8), (0.85, 0.8), (1.0, 0.0)]),
                cabeza=0.25 * math.sin(6 * math.pi * t) * tramos(t, [(0.0, 0.0), (0.2, 1.0), (0.85, 1.0), (1.0, 0.0)]),
                avance=tramos(t, [(0.0, 0.0), (0.2, 1.4), (0.85, 1.4), (1.0, 0.0)]))


def _paso(t, a, b):
    u = max(0.0, min(1.0, (t - a) / (b - a)))
    return u * u * (3 - 2 * u)


def a_evolucion(t):
    # Tiembla siendo lo que era, y SIN CORTES: forma y color cambian a la vez, poco a poco. Y acaba desplegando las garras.
    tiembla = (1.0 if int(t * 14) % 2 == 0 else -1.0) * (1.0 - _paso(t, 0.55, 0.72))
    return POSE(evo=_paso(t, 0.14, 0.82), tinte=_paso(t, 0.06, 0.78), vibra=0.3 * tiembla,
                agacha=tramos(t, [(0.0, 0.0), (0.3, 0.5), (0.7, 0.5), (0.88, 0.0), (1.0, 0.0)]),
                alza=tramos(t, [(0.0, 0.0), (0.75, 0.0), (0.88, 0.8), (1.0, 0.0)]),
                abre=tramos(t, [(0.0, 0.0), (0.75, 0.0), (0.88, 0.9), (1.0, 0.0)]),
                alas=tramos(t, [(0.0, 0.0), (0.75, 0.0), (0.88, 1.0), (1.0, 0.0)]))


def _con_mi_pose(fn):
    # Las de la normal, con lo mio puesto.
    return lambda t: POSE(**fn(t))


# nombre: (fotogramas, fps, loop, direcciones, funcion). Solo las que usa cada una: SUS habilidades + idle walk embestida encaje muerte comer evolucion.
ANIMS = {
    'idle': (8, 3.0, True, 8, _con_mi_pose(base.anim_idle)),
    'walk': (8, 9.0, True, 8, _con_mi_pose(base.anim_walk)),
    'embestida': (8, 12.0, False, 8, _con_mi_pose(base.anim_embestida)),
    'guadanas': (8, 13.0, False, 8, _con_mi_pose(base.anim_guadanas)),
    'basico': (6, 16.0, False, 8, a_basico_viento if VAR == 'vendaval' else _con_mi_pose(base.anim_basico)),
    'basico_der': (6, 16.0, False, 8, a_basico_der_viento if VAR == 'vendaval' else _con_mi_pose(base.anim_basico_der)),
    'ensarte': (8, 13.0, False, 8, _con_mi_pose(base.anim_ensarte)),
    'acecho': (8, 5.0, True, 8, _con_mi_pose(base.anim_acecho)),
    'siega_carga': (8, 8.0, True, 8, a_siega_carga),
    'siega': (7, 13.0, False, 8, a_siega),
    'encaje': (4, 18.0, False, 8, _con_mi_pose(base.anim_encaje)),
    'muerte': (8, 10.0, False, 8, _con_mi_pose(base.anim_muerte)),
    'comer': (10, 10.0, False, 8, a_comer),
    'evolucion': (18, 10.0, False, 8, a_evolucion),
}
if VAR == 'vendaval':
    ANIMS['vendaval_carga'] = (8, 8.0, True, 8, a_vendaval_carga)
    ANIMS['vendaval'] = (7, 13.0, False, 8, a_vendaval)
    ANIMS['salto_atras'] = (6, 14.0, False, 8, a_salto_atras)


# ------------------------------------------------------------
#  LA HOJA PARA MIRARLA (sin tocar assets: se hornea tras su visto bueno)
# ------------------------------------------------------------
def _hoja_ver(nombres):
    from PIL import Image, ImageDraw
    import sdf_gpu
    DIRS = (1, 4)     # SE de frente y N de espaldas
    pedidas = nombres or list(ANIMS.keys())
    trabajos = []; quien = []
    for nm in pedidas:
        n, _fps, loop, _d, fn = ANIMS[nm]
        for d in DIRS:
            for i in range(n):
                t = i / n if loop else i / max(1, n - 1)
                trabajos.append((MODELO, escena(fn(t)), d)); quien.append((nm, d, i))
    fotos = dict(zip(quien, sdf_gpu.render_lote(trabajos)))
    ESC = 3
    recortes = []
    for nm in pedidas:
        for d in DIRS:
            tira = [fotos[(nm, d, i)] for i in range(ANIMS[nm][0])]
            cajas = [f.getbbox() for f in tira if f.getbbox()]
            c = (min(x[0] for x in cajas) - 2, min(x[1] for x in cajas) - 2, max(x[2] for x in cajas) + 2, max(x[3] for x in cajas) + 2)
            recortes.append(('%s d%d' % (nm, d), tira, c))
    ancho = 150 + max((c[2] - c[0]) * ESC * len(tira) for _, tira, c in recortes)
    alto = sum((c[3] - c[1]) * ESC + 6 for _, _, c in recortes)
    hoja = Image.new('RGB', (ancho, alto), (40, 42, 50))
    dib = ImageDraw.Draw(hoja)
    y = 0
    for nombre, tira, c in recortes:
        cw, ch = c[2] - c[0], c[3] - c[1]
        dib.text((6, y + ch * ESC // 2), nombre, fill=(235, 235, 235))
        for i, f in enumerate(tira):
            r = f.crop(c).resize((cw * ESC, ch * ESC), Image.NEAREST)
            hoja.paste(r, (150 + i * cw * ESC, y), r)
        y += ch * ESC + 6
    esc = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'enemigos', 'prueba_3d', 'mutantes')
    os.makedirs(esc, exist_ok=True)
    os.makedirs(VISTAS, exist_ok=True)
    ruta = os.path.join(esc, 'segadora_%s_hoja.png' % VAR)
    hoja.save(ruta)
    hoja.save(VISTAS + 'segadora_%s_hoja.png' % VAR)
    print(ruta, hoja.size)
    # EL SALTO DE COLOR de la evolucion, medido (memoria transiciones-de-color): el mayor entre dos fotogramas seguidos.
    if 'evolucion' in pedidas:
        for d in DIRS:
            medias = []
            for i in range(ANIMS['evolucion'][0]):
                a = np.asarray(fotos[('evolucion', d, i)]).astype(float)
                dentro = a[:, :, 3] > 0
                medias.append(a[dentro][:, :3].mean(axis=0))
            print('evolucion d%d: mayor salto de color %.1f' % (d, max(np.abs(x - y).sum() for x, y in zip(medias, medias[1:]))))


if __name__ == '__main__':
    args = sys.argv[1:]
    if args[:1] == ['hoja']:
        _hoja_ver(args[1:])
    elif args[:1] == ['puntas']:
        import json
        if len(args) > 2 and args[2] == 'normal':
            raise SystemExit('la normal: python segadora_sdf.py puntas <salida>')
        else:
            json.dump(puntas_armas(escena, MODELO, ANIMS, ('guadana_-1', 'guadana_1'), 'hoja'), open(args[1], 'w'))
    else:
        hornear('segadora_mut_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)

