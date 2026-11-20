# ============================================================
#  acechador_mut_sdf.py -- LOS MUTANTES DEL ACECHADOR, con sus animaciones (19/11/2026, memoria acechador-mutante). Los
#  cuerpos son los aprobados en acechador_mutantes_versiones.py final:
#    ACECHADOR_VAR=sombra   SOMBRA SIN ROSTRO (negro mate, recia, humo largo en bocanadas, cara A: ojos rasgados con ceño;
#                           rescoldo apagado en quieto, AMBAR al atacar)
#    ACECHADOR_VAR=cazador  CAZADOR LUNAR (lobo de luna grande, melena y crecientes, cara A con ojos de hielo)
#  LAS ANIMACIONES (lista aprobada el 19/11):
#    SOMBRA   las del acechador (idle, walk, embestida, basico, zarpazo, yugular, desgarrar, encaje, muerte) y:
#             fundirse   al acabar su turno se deshace en humo (se encoge y todo se vuelve humo)
#             emerger    sale del humo con los ojos encendidos (el golpe desde las sombras)
#             comer      come el cristal (muerde tres veces hacia abajo)
#             evolucion  desde el acechador normal: se oscurece, engorda y le brota el humo
#    CAZADOR  idle, walk, embestida, basico, yugular, encaje, muerte y fundirse / emerger (en niebla azul), y:
#             media_luna un zarpazo en ARCO enorme con la derecha (la luna creciente la pone el efecto)
#             aullido    Caida de la luna: se yergue y AULLA a la luna del cielo, y aguanta (carga)
#             marca      señala con el hocico y una mano (Marca de la luna)
#             comer, evolucion (desde la Sombra: el humo se recoge y le crecen la melena y los crecientes)
#  Uso: ACECHADOR_VAR=sombra python tools/sprites_sdf/acechador_mut_sdf.py [anim ...] -> assets/sprites/enemigos/acechador_sdf_<var>/
#       ACECHADOR_VAR=cazador python tools/sprites_sdf/acechador_mut_sdf.py hoja [anim ...] -> la hoja para mirarla
#       (la hoja no toca assets: se hornea tras su visto bueno. PROCESOS=n, 3 por defecto)
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import acechador_sdf as base
import acechador_mutantes_versiones as vers

VAR = os.environ.get('ACECHADOR_VAR', 'sombra')
VARS = ('sombra', 'cazador')
assert VAR in VARS, 'ACECHADOR_VAR tiene que ser una de %s' % (VARS,)
SALIDA = 'assets/sprites/enemigos/acechador_sdf_%s/' % VAR
VISTAS = 'tools/salida/sdf/'
V = np.array

# ------------------------------------------------------------
#  LOS MATERIALES y sus TRANSICIONES (memoria transiciones-de-color): de lo que era a lo nuevo, sin saltos
# ------------------------------------------------------------
PASOS = 6
MAT = {}
MAT.update(vers.MAT_SOMBRA if VAR == 'sombra' else vers.MAT_LUNA)
MAT['ojo_off'] = vers.MAT_SOMBRA['ojo_off']
# el humo del cazador: niebla azul noche (se funde en ella)
MAT['humo'] = vers.MAT_SOMBRA['humo'] if VAR == 'sombra' else [(0.20, 0.24, 0.40), (0.30, 0.36, 0.55), (0.44, 0.52, 0.72)]
# De donde viene en la evolucion: la sombra desde el acechador normal; el cazador desde la sombra.
DESDE = base.MAT if VAR == 'sombra' else vers.MAT_SOMBRA
HASTA = vers.MAT_SOMBRA if VAR == 'sombra' else vers.MAT_LUNA
CUERPO = ('piel', 'pata', 'crin', 'morro', 'hueso')
for _m in CUERPO:
    for _k in range(PASOS + 1):
        MAT['evo_%s_%d' % (_m, _k)] = [tuple(DESDE[_m][i][c] + (HASTA[_m][i][c] - DESDE[_m][i][c]) * _k / PASOS
                                             for c in range(3)) for i in range(3)]
        # y al FUNDIRSE, del cuerpo al humo
        MAT['funde_%s_%d' % (_m, _k)] = [tuple(HASTA[_m][i][c] + (MAT['humo'][i][c] - HASTA[_m][i][c]) * _k / PASOS
                                               for c in range(3)) for i in range(3)]


def _paso_k(f):
    return int(round(max(0.0, min(1.0, f)) * PASOS))


# LOS LIENZOS: el normal es 1,8 en 130 x 130 (pies 65, 65); los mutantes, mas grandes.
ESCALA = {'sombra': 2.05, 'cazador': 2.5}[VAR]
LIENZO = {'sombra': (150, 150, 75, 80), 'cazador': (180, 180, 90, 98)}[VAR]
BRILLAN = ('ojo',) if VAR == 'sombra' else ('ojo', 'pupila', 'luna', 'crin')
TRANSLUCIDOS = ('humo',) + tuple('funde_%s_%d' % (m, k) for m in CUERPO for k in range(PASOS // 2, PASOS + 1))
MODELO = Modelo(ESCALA, LIENZO[:2], LIENZO[2:], MAT, (0.02, 0.02, 0.03), suaves=('cuerpo', 'cabeza'), brillan=BRILLAN,
                corta_suelo=True, translucidos=TRANSLUCIDOS, alfa=0.72)
K_PATA = 1.35 if VAR == 'sombra' else 1.45
# (20/11, el jefe: "cuando te dije de hacerla mas ancha nos pasamos, miramos algun lobo de verdad") EL CUERPO DEL LOBO, a
# elegir (LOBO_CUERPO, solo el cazador; ELIGIO LA B el 20/11): A el de antes (patas x1,45, barril x1,12, pecho ancho); B LOBO DE VERDAD (patas
# largas y no tan gordas, pecho hondo pero ESTRECHO de lado, cintura algo recogida; el volumen, en la melena); C a medias.
CUERPOS_LOBO = {
    'A': dict(k_pata=1.45, tronco_x=1.0, pecho_x=1.0, vientre_z=1.0, largo=0.0),
    'B': dict(k_pata=1.15, tronco_x=0.72, pecho_x=0.72, vientre_z=0.7, largo=3.0),
    'C': dict(k_pata=1.3, tronco_x=0.85, pecho_x=0.85, vientre_z=0.85, largo=1.6),
    # D: la B con las patas aun mas largas y el cuerpo mas CORTO de delante a atras (de perfil el de hoy es el doble de
    # largo que de alto; un lobo, de la cruz a la grupa, poco mas que su altura)
    'D': dict(k_pata=1.15, tronco_x=0.72, pecho_x=0.72, vientre_z=0.7, largo=5.5, estira=-0.15),
}
CUERPO_LOBO = CUERPOS_LOBO[os.environ.get('LOBO_CUERPO', 'B')] if VAR == 'cazador' else dict(largo=0.0)
if VAR == 'cazador':
    K_PATA = CUERPO_LOBO['k_pata']
    for _k in ('tronco_x', 'pecho_x', 'vientre_z'):
        vers.ANCHO_LOBO[_k] = CUERPO_LOBO[_k]
# el tamaño de lo que era, respecto al nuevo (la evolucion crece de ahi)
ESC_DESDE = (1.8 if VAR == 'sombra' else 2.05) / ESCALA

# EL PORTE DEL LOBO: erguido (pecho alto y cabeza arriba), sumado a cada pose; se le quita al caer muerto.
LOBO = dict(empina=0.55, cabeza=5.2, hocico=-1.0, alza=CUERPO_LOBO['largo'], estira=CUERPO_LOBO.get('estira', 0.0))


# ------------------------------------------------------------
#  LA ESCENA
# ------------------------------------------------------------
_HUESOS_BASE = base.huesos   # el original (escena() lo sustituye un momento por _huesos)


def _huesos(p):
    """Los del acechador; en la evolucion y al fundirse, todo a escala desde el suelo; y 'crece', el hueso de lo nuevo
    (humo, melena, crecientes), que brota desde el lomo."""
    X = _HUESOS_BASE(p)
    sc = p.get('escala', 1.0)
    if sc != 1.0:
        S = (np.eye(3) * sc, np.zeros(3))
        X = {k: comp(S, v) for k, v in X.items()}
    kc = max(0.02, p.get('crece', 1.0))
    X['crece'] = comp(X['raiz'], sobre(V((0.0, 0.0, 13.0)), np.eye(3) * kc))
    return X


def _remap(L, f):
    out = Piezas()
    out.sombras = getattr(L, 'sombras', [])
    for fn, m, g, k, Xh, nh in L:
        out.append((fn, f(m), g, k, Xh, nh))
    return out


def escena(p):
    viejo_h = base.huesos
    base.huesos = lambda pp: _huesos(pp)
    try:
        X = _huesos(p)
        # el cuerpo recio sin los ojos redondos del de base
        L = vers._sin_ojos_base(vers.escena_recia(p, 1.0 + (K_PATA - 1.0) * p.get('recio', 1.0),
                                                   CUERPO_LOBO['largo'] * p.get('recio', 1.0)))
        e2 = Escena(X)
        add = e2.add

        def add_crece(fn, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
            add(fn, mat, k, grupo, 'crece' if hueso == 'raiz' else hueso)

        if p.get('recio', 1.0) > 0.05:
            k_tr = (1.0 if VAR == 'sombra' else 1.12) * p.get('recio', 1.0)
            vers.tronco(add, p, k_tr, k_tr * (1.0 if VAR == 'sombra' else CUERPO_LOBO['tronco_x']))
        if VAR == 'sombra':
            if p.get('crece', 1.0) > 0.03:
                vers.humo(6.0, 4.2, True)(add_crece, p)
        else:
            if p.get('crece', 1.0) > 0.03:
                vers.lobo(True, True)(add_crece, p)
            # en la evolucion, el humo de lo que era se recoge
            if p.get('humo_viejo', 0.0) > 0.03:
                X['humo_viejo'] = comp(X['raiz'], sobre(V((0.0, 0.0, 13.0)), np.eye(3) * p['humo_viejo']))
                e3 = Escena(X)
                vers.humo(6.0, 4.2, True)(lambda fn, mat, k=0.0, grupo='cuerpo', hueso='raiz':
                                          e3.add(fn, mat, k, grupo, 'humo_viejo'), p)
                e2.L.extend(e3.L)
        vers.cara('A')(add, p)
        L.extend(e2.L)
    finally:
        base.huesos = viejo_h
    # LOS COLORES: evolucion (de lo que era a lo nuevo), fundirse (del cuerpo al humo) y los OJOS
    evo = p.get('evo', 1.0)
    funde = p.get('funde', 0.0)
    ojos = p.get('ojos', 1.0 if VAR == 'cazador' else 0.0)

    def mat(m):
        if m in ('ojo', 'pupila'):
            if funde > 0.6:
                return 'humo'
            return m if ojos > 0.5 else 'ojo_off'
        if m in CUERPO:
            if evo < 0.999:
                return 'evo_%s_%d' % (m, _paso_k(evo))
            if funde > 0.0:
                return 'funde_%s_%d' % (m, _paso_k(funde))
        if m in ('crin', 'luna') and funde > 0.5:
            return 'humo'
        return m
    # LA PUNTA DE LA COLA DE LUZ del Cazador (20/11): sus ultimos tramos ('crin' de la cola) en luna, en la cola de verdad
    # (antes era una pieza aparte que flotaba suelta detras: memoria pixeles-colados-piezas-sin-hueso)
    if VAR == 'cazador':
        L2 = Piezas()
        L2.sombras = getattr(L, 'sombras', [])
        for fn, m, g, k, Xh, nh in L:
            L2.append((fn, 'luna' if (g == 'cola' and m == 'crin') else m, g, k, Xh, nh))
        L = L2
    return _remap(L, mat)


# ------------------------------------------------------------
#  LAS POSES
# ------------------------------------------------------------
def _p(t):
    """Una curva suave 0..1."""
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def _paso(x, a, b):
    if x <= a:
        return 0.0
    if x >= b:
        return 1.0
    return _p((x - a) / (b - a))


def lobo(fn, sin_porte_al_morir=False):
    """La animacion del acechador con el porte del lobo encima (solo el cazador)."""
    def g(t):
        p = fn(t)
        if VAR == 'cazador':
            k = 1.0 - p.get('tumba', 0.0) if sin_porte_al_morir else 1.0
            for kk, v in LOBO.items():
                p[kk] = p.get(kk, 0.0) + v * k
        return p
    g.__name__ = 'lobo_' + fn.__name__
    return g


def encendido(fn, desde=0.0, hasta=1.0):
    """Los ojos ENCENDIDOS entre 'desde' y 'hasta' (la sombra los lleva apagados salvo al atacar)."""
    def g(t):
        p = fn(t)
        p['ojos'] = 1.0 if desde <= t <= hasta else 0.0
        return p
    g.__name__ = 'enc_' + fn.__name__
    return g


def a_fundirse(t):
    # SE DESHACE EN HUMO: se agacha, se encoge y todo se vuelve humo (al final el juego lo esconde: En las sombras)
    p = lobo(base.anim_idle)(0.0)
    p.update(agacha=0.8 * _paso(t, 0.0, 0.5), funde=_paso(t, 0.15, 0.85), escala=1.0 - 0.45 * _paso(t, 0.35, 1.0),
             crece=1.0 + 0.6 * _paso(t, 0.2, 0.9), ojos=0.0, cola=0.6 * math.sin(t * 6.0))
    return p


def a_emerger(t):
    # SALE DEL HUMO: lo contrario de fundirse, con los ojos encendidos desde el principio, y se lanza hacia delante
    p = a_fundirse(1.0 - _paso(t, 0.0, 0.7))
    p['ojos'] = 1.0
    p['avance'] = 3.0 * _paso(t, 0.55, 0.85) - 1.5 * _paso(t, 0.85, 1.0)
    p['boca'] = tramos(t, [(0.0, 0.0), (0.55, 0.0), (0.7, 1.0), (0.85, 0.2), (1.0, 0.0)])
    p['hocico'] = p.get('hocico', 0.0) + 2.0 * tramos(t, [(0.0, 0.0), (0.55, 0.0), (0.72, 1.0), (1.0, 0.0)])
    return p


def a_comer(t):
    # COME EL CRISTAL: baja la cabeza al suelo y MUERDE tres veces.
    # (20/11, el jefe: mejorarlo como el aullido, [[poses-articular-no-girar]]) el CUELLO baja y la cabeza GIRA hasta
    # poner el hocico al suelo ('mira' negativo), y cada mordisco cabecea un poco mas abajo; el pecho baja algo con ella.
    # Al Cazador se le quita el porte erguido mientras come (si no, la cabeza se quedaria arriba).
    m = 0.5 - 0.5 * math.cos(2 * math.pi * 3 * _paso(t, 0.15, 0.85))
    baja = _paso(t, 0.0, 0.15) * (1.0 - _paso(t, 0.85, 1.0))
    porte = LOBO if VAR == 'cazador' else {}
    # (el cuerpo NO se inclina: la grupa se queda donde esta; solo baja el cuello)
    p = base.POSE(cabeza=(-5.4 - porte.get('cabeza', 0.0)) * baja - 0.7 * m,
                  hocico=(0.4 - porte.get('hocico', 0.0)) * baja + 0.4 * m,
                  mira=-0.9 * baja - 0.2 * m * baja, boca=0.2 + 0.8 * m * baja,
                  empina=-porte.get('empina', 0.0) * 0.5 * baja,
                  cola=0.5 * math.sin(2 * math.pi * 2 * t))
    return lobo(lambda _t: p)(t)


def a_media_luna(t):
    # UN ZARPAZO EN ARCO ENORME con la derecha: se empina, la mano sube alta por un lado y barre de punta a punta.
    # (20/11, el jefe: "de lado se nota poco") ademas el arco va DE ARRIBA ABAJO: la mano se echa atras por encima de la
    # cabeza mientras se empina, y baja por delante hasta el suelo mientras se lanza (de perfil se ve la media luna).
    alza = tramos(t, [(0.0, 0.0), (0.25, 1.6), (0.45, 1.2), (0.62, 0.35), (0.8, 0.0), (1.0, 0.0)])
    barre = tramos(t, [(0.0, 0.0), (0.25, 1.4), (0.5, -1.6), (0.62, -1.2), (0.8, 0.0), (1.0, 0.0)])
    dy = tramos(t, [(0.0, 0.0), (0.25, -7.0), (0.42, 1.0), (0.55, 4.0), (0.7, 2.0), (0.85, 0.0), (1.0, 0.0)])
    dz = tramos(t, [(0.0, 0.0), (0.25, 5.0), (0.42, 0.0), (0.55, -9.0), (0.7, -5.0), (0.85, 0.0), (1.0, 0.0)])
    emp = tramos(t, [(0.0, 0.0), (0.25, 2.0), (0.42, 0.6), (0.55, -0.9), (0.7, -0.5), (0.85, 0.0), (1.0, 0.0)])
    p = base.POSE(zd_alza=alza, zd_barre=barre, zd_dy=dy, zd_dz=dz, empina=emp, boca=0.6 * alza, cabeza=0.6,
                  agacha=0.35 * _paso(t, 0.4, 0.55) * (1.0 - _paso(t, 0.7, 0.9)),
                  avance=tramos(t, [(0.0, 0.0), (0.25, -1.0), (0.55, 2.6), (1.0, 0.0)]), cola=0.5 * math.sin(2 * math.pi * t))
    return lobo(lambda _t: p)(t)


def a_aullido(t):
    # CAIDA DE LA LUNA: alza el hocico al cielo y AULLA, y aguanta (la carga)
    sube = _paso(t, 0.0, 0.3) * (1.0 - _paso(t, 0.88, 1.0))
    # (20/11, el jefe con su foto, Desktop/ataques_mapa/enemigos/acechador/referencia/aullido_lobo.png: "no se dobla, se
    # dobla tieso para arriba") COMO UN LOBO DE VERDAD: las cuatro patas en el suelo y el cuerpo casi como en quieto; lo
    # que sube es el CUELLO, que se estira hacia arriba, y la CABEZA, que gira hasta poner el hocico al cielo ('mira').
    p = base.POSE(empina=0.35 * sube, cabeza=9.5 * sube, hocico=-0.8 * sube, mira=1.3 * sube, boca=0.9 * _paso(t, 0.25, 0.4) *
                  (1.0 - _paso(t, 0.85, 0.95)), cola=-0.6 * sube,
                  sacude=0.25 * math.sin(2 * math.pi * t * 6) * _paso(t, 0.35, 0.45) * (1.0 - _paso(t, 0.8, 0.88)))
    return lobo(lambda _t: p)(t)


def a_marca(t):
    # MARCA DE LA LUNA: adelanta el hocico hacia la presa y levanta una mano, quieto, señalandola
    s = _paso(t, 0.0, 0.3) * (1.0 - _paso(t, 0.8, 1.0))
    p = base.POSE(hocico=2.2 * s, cabeza=-0.6 * s, zi_alza=0.45 * s, empina=0.2 * s, agacha=0.15 * s, boca=0.15 * s,
                  cola=0.2)
    return lobo(lambda _t: p)(t)


def a_evolucion(t):
    # TIEMBLA SIENDO LO QUE ERA, se encoge, y crece en lo nuevo: el color pasa de uno a otro (del cuerpo hacia fuera), lo
    # nuevo (humo / melena y crecientes) brota del lomo, y al final se planta con su porte.
    base_p = base.anim_idle(t * 4.0 % 1.0)
    p = dict(base_p)
    enc = tramos(t, [(0.0, 0.0), (0.2, 0.7), (0.7, 0.7), (0.85, 0.0), (1.0, 0.0)])
    f = _paso(t, 0.25, 0.8)
    p.update(agacha=enc, evo=_paso(t, 0.2, 0.75), crece=_paso(t, 0.45, 0.9), recio=_paso(t, 0.2, 0.7),
             escala=ESC_DESDE + (1.0 - ESC_DESDE) * f,
             sacude=0.35 * math.sin(t * 2 * math.pi * 9) * (1.0 - _paso(t, 0.6, 0.75)),
             boca=tramos(t, [(0.0, 0.0), (0.85, 0.0), (0.93, 0.9), (1.0, 0.1)]), ojos=1.0 if t > 0.85 else 0.0)
    if VAR == 'cazador':
        # la sombra recoge su humo y se planta como lobo
        p['humo_viejo'] = 1.0 - _paso(t, 0.25, 0.65)
        k = _paso(t, 0.6, 0.95)
        for kk, v in LOBO.items():
            p[kk] = p.get(kk, 0.0) + v * k
        p['ojos'] = 1.0
    return p


# ------------------------------------------------------------
#  LAS ANIMACIONES DE CADA UNO
# ------------------------------------------------------------
ANIMS = {}
_A = base.ANIMS
if VAR == 'sombra':
    for _nm in ('idle', 'walk', 'encaje', 'muerte'):
        ANIMS[_nm] = _A[_nm]
    for _nm in ('embestida', 'basico', 'zarpazo', 'yugular', 'desgarrar'):
        n, fps, loop, dirs, fn = _A[_nm]
        ANIMS[_nm] = (n, fps, loop, dirs, encendido(fn))
else:
    for _nm in ('idle', 'walk', 'embestida', 'basico', 'yugular', 'encaje'):
        n, fps, loop, dirs, fn = _A[_nm]
        ANIMS[_nm] = (n, fps, loop, dirs, lobo(fn))
    n, fps, loop, dirs, fn = _A['muerte']
    ANIMS['muerte'] = (n, fps, loop, dirs, lobo(fn, sin_porte_al_morir=True))
    ANIMS['media_luna'] = (12, 18.0, False, 8, a_media_luna)
    ANIMS['aullido'] = (14, 10.0, False, 8, a_aullido)
    ANIMS['marca'] = (10, 12.0, False, 8, a_marca)
ANIMS['fundirse'] = (10, 12.0, False, 8, a_fundirse)
ANIMS['emerger'] = (10, 14.0, False, 8, a_emerger)
ANIMS['comer'] = (10, 10.0, False, 8, a_comer)
ANIMS['evolucion'] = (18, 10.0, False, 8, a_evolucion)


# ------------------------------------------------------------
#  LA HOJA PARA MIRARLA (sin tocar assets)
# ------------------------------------------------------------
def _dibuja(tr):
    getattr(__import__('sdf_comun'), '_prioridad_baja', lambda: None)()
    nombre, d, i = tr
    n, _fps, loop, _dirs, fn = ANIMS[nombre]
    t = i / n if loop else i / max(1, n - 1)
    return (nombre, d, i, render(MODELO, escena(fn(t)), d))


def _hoja(nombres):
    from multiprocessing import Pool
    from PIL import Image, ImageDraw
    DIRS = (1, 4)     # SE de frente y N de espaldas
    pedidas = nombres or list(ANIMS.keys())
    trabajos = []
    for nm in pedidas:
        for d in DIRS:
            trabajos += [(nm, d, i) for i in range(ANIMS[nm][0])]
    with Pool(int(os.environ.get('PROCESOS', 0)) or 3) as pool:
        hechos = pool.map(_dibuja, trabajos, chunksize=2)
    fotos = {(a, b, c): im for a, b, c, im in hechos}
    ESC = 2
    filas = []
    for nm in pedidas:
        for d in DIRS:
            filas.append(('%s d%d' % (nm, d), [fotos[(nm, d, i)] for i in range(ANIMS[nm][0])]))
    recortes = []
    for nombre, tira in filas:
        cajas = [f.getbbox() for f in tira if f.getbbox()]
        if not cajas:
            continue
        c = (min(x[0] for x in cajas) - 2, min(x[1] for x in cajas) - 2, max(x[2] for x in cajas) + 2, max(x[3] for x in cajas) + 2)
        recortes.append((nombre, tira, c))
    ancho = 150 + max((c[2] - c[0]) * ESC * len(tira) for _, tira, c in recortes)
    alto = sum((c[3] - c[1]) * ESC + 6 for _, _, c in recortes)
    hoja = Image.new('RGB', (ancho, alto), (52, 58, 70))
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
    sufijo = ('_' + '_'.join(nombres)) if nombres else ''
    ruta = os.path.join(esc, 'acechador_%s_hoja%s.png' % (VAR, sufijo))
    hoja.save(ruta)
    hoja.save(VISTAS + 'acechador_%s_hoja%s.png' % (VAR, sufijo))
    print(ruta, hoja.size)


if __name__ == '__main__':
    args = sys.argv[1:]
    if args[:1] == ['hoja']:
        _hoja(args[1:])
    else:
        hornear('acechador_mut_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
