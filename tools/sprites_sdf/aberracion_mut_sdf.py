# ============================================================
#  aberracion_mut_sdf.py -- LOS MUTANTES DE LA ABERRACION (13/11/2026, memoria aberracion-mutante), ANIMADOS.
#    galvanica  MASA GALVANICA (rango 1): la R1 c de aberracion_medusa_versiones.py -- la forma de la base, translucida
#               (carne lechosa), con los NERVIOS cian a la vista (con nudos de luz) y anillos cian donde nacen los tentaculos.
#    tormenta   OJO DE LA TORMENTA (rango 2): la E a. VUELA de verdad: sus animaciones son todas nuevas (otro archivo de
#               claves, mas abajo, cuando toque).
#  La Masa usa el cuerpo y las CLAVES DE TIEMPO de aberracion_sdf.py (las del viejo) y las mismas anims que la base (el
#  jefe, 13/11): idle walk embestida basico encaje muerte + alarido (= su DESCARGA) + mirada (= su MIRADA CHISPEANTE).
#  Los nervios van pegados al cuerpo (escalan con el latido y el aplastarse, avanzan con el) y BRILLAN POR ESCALONES
#  ('luz' 0..5, uno por fotograma como mucho: memoria transiciones-de-color): laten en reposo, se encienden del todo en
#  la Descarga y se apagan al morir. La sombra NO va en el sprite (memoria sombras-fuera-del-sprite).
#  Uso: ABERRACION_MUT=galvanica python tools/sprites_sdf/aberracion_mut_sdf.py hoja [anim ...]
#         -> Desktop/ataques_mapa/enemigos/prueba_3d/mutantes/aberracion_<mut>_hojas/ (para mirarla; no toca assets)
#       ... aberracion_mut_sdf.py [anim ...]   -> assets/sprites/enemigos/aberracion_sdf_<mut>/ (EL HORNO, tras su visto bueno)
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import aberracion_sdf as ab
import aberracion_medusa_versiones as amv

V = np.array
MUT = os.environ.get('ABERRACION_MUT', 'galvanica').lower()
_elip, _cono, _unit = ab._elip, ab._cono, ab._unit

# LA LUZ DE LOS NERVIOS: 0 (apagados, del color de la carne) .. 3 (normal, el cian de la lamina) .. 5 (a tope, casi
# blanco). Cada material que brilla tiene una copia por nivel ('nervio@4').
LUZ_NORMAL = 3
_APAGADO = (0.34, 0.22, 0.44)
_CIAN = (0.45, 0.95, 1.0)
_A_TOPE = (0.88, 1.0, 1.0)


def _nivel(c, k):
    """El tono del nivel k: de apagado a cian (0..3) y de cian a casi blanco (3..5)."""
    if k <= LUZ_NORMAL:
        u = k / LUZ_NORMAL
        return tuple(a + (b - a) * u for a, b in zip(_APAGADO, c))
    u = (k - LUZ_NORMAL) / (5 - LUZ_NORMAL)
    return tuple(a + (b - a) * u for a, b in zip(c, _A_TOPE))


MAT = dict(amv.MAT)
for _k in range(6):
    MAT['nervio@%d' % _k] = amv.tonos(_nivel(_CIAN, _k))[:3]
    MAT['nudo@%d' % _k] = amv.tonos(_nivel((0.80, 1.0, 1.0), _k))[:3]
    MAT['iris@%d' % _k] = amv.tonos(_nivel(_CIAN, _k))[:3]
_BRILLAN = tuple(m for m in MAT if m.startswith(('nervio@', 'nudo@', 'iris@'))) + ('pupila',)

# EL TAMAÑO: x1,2 de la base (1,80 -> 2,16; lienzo 102 -> 122, origen en el centro). Un mutante con sprite propio NO se
# estira el x1,2 de los mutantes (SpritesEnemigo.mutante_propio): tiene que venir ya grande.
MUT_GRANDE = 1.2
_LADO = int(round(102 * MUT_GRANDE / 2)) * 2
MODELO = Modelo(1.8 * MUT_GRANDE, (_LADO, _LADO), (_LADO // 2, _LADO // 2), MAT, (0.12, 0.04, 0.12), suaves=('cuerpo',), brillan=_BRILLAN,
                corta_suelo=True, especular=('carne', 'tent', 'globo', 'carne_t', 'tent_t'), umbral_especular=0.90,
                translucidos=('carne_t', 'tent_t'), alfa=0.45)
LIENZO = (MODELO.W, MODELO.H)
SALIDA = 'assets/sprites/enemigos/aberracion_sdf_%s/' % MUT
VISTAS = 'tools/salida/sdf/aberracion_%s/' % MUT


def POSE(**k):
    p = ab.POSE()
    p.update(luz=LUZ_NORMAL, chispas=0.0, t=0.0)
    p.update(k)
    return p


# ------------------------------------------------------------
#  LA MASA GALVANICA
# ------------------------------------------------------------
# Donde van los nervios, en las coordenadas de la base SIN deformar (las mismas que la R1 c de la lamina).
_CENTRO = (0.0, -0.4, 5.6)
_PUNTAS = [(4.4, -3.0, 8.4), (-4.8, 1.6, 7.0), (-0.8, -2.8, 10.6), (0.0, 3.6, 8.6)]


def _punto_tent(p, i, an, al, k_obj=3):
    """Donde pasa el tentaculo i en su tramo k_obj (la misma cuenta que aberracion_sdf._tentaculo, sin pintar): asi el
    anillo cian de su raiz va pegado al tentaculo aunque se levante para azotar."""
    ang = math.radians(30.0 + 60.0 * i + (7.0, -5.0, 9.0, -8.0, 4.0, -6.0)[i])
    fuera = V((math.sin(ang), math.cos(ang), 0.0))
    lado = V((fuera[1], -fuera[0], 0.0))
    az = p['azota'] * max(0.0, fuera[1])
    pt = V((0.0, 0.0, ab.TENT_NACE_Z * al)) + fuera * ab.TENT_NACE_R * an
    caida = min(1.45, 0.95 - az * 1.55)
    suelo = 0.0 if az <= 0.0 else -0.5 * az
    r0, r1 = 2.3, 1.0
    rr = r0
    enrosca = (0.9, -0.7, 0.8, -0.9, 0.7, -0.8)[i]
    n = ab.TENT_SEGMENTOS
    for k in range(k_obj + 1):
        u = k / (n - 1)
        caida = max(suelo, caida - 0.19) if k < n - 2 else min(caida, -0.22)
        onda = enrosca * u * u + 0.45 * math.sin(math.pi * p['onda'] + i * 1.9 + k * 0.7) * u
        d = _unit(fuera * math.cos(caida) + V((0.0, 0.0, -math.sin(caida))) + lado * onda)
        q = pt + d * ab.TENT_PASO
        q[2] = max(q[2], r1 * 0.9 + (rr - r1) * 0.55)
        rr = r0 + (r1 - r0) * min(1.0, (k + 1) / (n - 1))
        pt = q
    return pt, rr


def _escena_galvanica(pose):
    p = pose
    L = amv.recolorea(ab.escena(p), {'carne': 'carne_t', 'tent': 'tent_t', 'iris': 'iris@%d' % _luz_iris(p)})
    e = Escena(ab.huesos(p)); add = e.add
    an, al = ab._volumen(p)
    T = lambda c: V((c[0] * an, c[1] * an, c[2] * al))
    k = int(p['luz'])
    nerv, nudo = 'nervio@%d' % k, 'nudo@%d' % k
    # LOS NERVIOS: del centro a los lobulos, la joroba, detras del ojo y a la raiz de cada tentaculo, con un quiebro a
    # medio camino (el rayo no va recto) y un nudo de luz en cada quiebro (amv.nervios, con el material del nivel).
    raices = []
    for i in range(ab.TENTACULOS):
        q, _rr = _punto_tent(p, i, an, al, 1)
        raices.append(tuple(q))
    puntas = [tuple(T(c)) for c in _PUNTAS] + raices
    sub = Escena(ab.huesos(p))
    amv.nervios(sub.add, T(_CENTRO), puntas, nudos=True)
    for (fn, mat, g, kk, X, h) in sub.L:
        e.L.append((fn, {'nervio': nerv, 'nudo': nudo}.get(mat, mat), g, kk, X, h))
    # LOS ANILLOS cian donde el tentaculo toca el suelo (pegados a el).
    for i in range(ab.TENTACULOS):
        q, rr = _punto_tent(p, i, an, al, 3)
        _elip(add, q, (rr * 0.78, rr * 0.78, rr * 0.55), nerv, 0, 'nervio')
    # LAS CHISPAS DEL OJO (la Mirada chispeante): puntitos de luz delante del iris que saltan de sitio cada fotograma.
    if p['chispas'] > 0.01:
        oj = V((ab.OJO[0], ab.OJO[1] * an + 2.4, ab.OJO[2] * al))
        rng = np.random.default_rng(int(p['t'] * 997) + 7)
        for _j in range(int(3 + 6 * p['chispas'])):
            off = V((rng.uniform(-2.6, 2.6), rng.uniform(0.0, 1.2), rng.uniform(-2.4, 2.4))) * (0.6 + 0.6 * p['chispas'])
            _elip(add, oj + off, (0.32, 0.32, 0.32), 'nudo@5', 0, 'nervio')
    L.extend(e.L)
    return L


def _luz_iris(p):
    return int(min(5, max(0, round(p['luz'] + 1.5 * p['chispas']))))


def _con_luz(fn, claves=None, chispas=None, idle=False):
    """La anim de la base con la luz de los nervios encima: 'claves' = [(t, nivel)] (por tramos), 'idle' = late 2..4."""
    def g(t):
        p = POSE(**fn(t))
        p['t'] = t
        if idle:
            p['luz'] = LUZ_NORMAL + round(math.sin(2 * math.pi * t))
        elif claves:
            p['luz'] = int(round(tramos(t, claves)))
        if chispas:
            p['chispas'] = tramos(t, chispas)
        return p
    return g


if MUT == 'galvanica':
    escena = _escena_galvanica
    ANIMS = {}
    for nm, (n, fps, loop, d, fn) in ab.ANIMS.items():
        if nm == 'idle':
            g = _con_luz(fn, idle=True)
        elif nm == 'alarido':
            # LA DESCARGA: el gesto del Alarido (se encoge, se hincha, vibra) y los nervios suben de uno en uno hasta
            # encenderse TODOS en el golpe, y vuelven.
            g = _con_luz(fn, [(0.0, 3), (0.143, 3), (0.286, 4), (0.429, 5), (0.571, 5), (0.714, 4), (0.857, 3), (1.0, 3)])
        elif nm == 'mirada':
            # LA MIRADA CHISPEANTE: la de la base con el ojo lleno de chispas cuando se queda tiesa mirando.
            g = _con_luz(fn, [(0.0, 3), (0.286, 3), (0.429, 4), (0.857, 4), (1.0, 3)],
                         chispas=[(0.0, 0.0), (0.143, 0.0), (0.286, 0.6), (0.429, 1.0), (0.714, 1.0), (0.857, 0.4), (1.0, 0.0)])
        elif nm in ('embestida', 'basico'):
            # el golpe del tentaculo: un escalon mas al azotar
            g = _con_luz(fn, [(0.0, 3), (0.3, 3), (0.45, 4), (0.7, 4), (1.0, 3)])
        elif nm == 'encaje':
            g = _con_luz(fn, [(0.0, 4), (0.5, 3), (1.0, 3)])
        elif nm == 'muerte':
            # se apagan de uno en uno
            g = _con_luz(fn, [(0.0, 3), (0.3, 3), (0.5, 2), (0.7, 1), (0.9, 0), (1.0, 0)])
        else:
            g = _con_luz(fn)
        ANIMS[nm] = (n, fps, loop, d, g)
else:
    raise SystemExit('ABERRACION_MUT=%s: el Ojo de la tormenta va en su paso (anims nuevas, todavia no)' % MUT)


def modelo_de(pose):
    return MODELO


def _hoja_ver(nombres):
    """Como polilla_mut_sdf._hoja_ver: cada anim en SE (de frente) y N (de espaldas), fotograma a fotograma, x3."""
    from PIL import Image, ImageDraw
    import sdf_gpu
    DIRS = (1, 4)
    pedidas = nombres or list(ANIMS.keys())
    fotos = {}
    for nm in pedidas:
        trabajos = []; quien = []
        n, _fps, loop, _d, fn = ANIMS[nm]
        for d in DIRS:
            for i in range(n):
                t = i / n if loop else i / max(1, n - 1)
                pose = fn(t)
                trabajos.append((modelo_de(pose), escena(pose), d)); quien.append((nm, d, i))
        fotos.update(zip(quien, sdf_gpu.render_lote(trabajos)))
        print(nm, 'ok', flush=True)
    ESC = 3
    recortes = []
    for nm in pedidas:
        for d in DIRS:
            tira = [fotos[(nm, d, i)] for i in range(ANIMS[nm][0])]
            cajas = [f.getbbox() for f in tira if f.getbbox()]
            c = (min(x[0] for x in cajas) - 2, min(x[1] for x in cajas) - 2, max(x[2] for x in cajas) + 2,
                 max(x[3] for x in cajas) + 2)
            if c[0] <= 0 or c[1] <= 0 or c[2] >= LIENZO[0] or c[3] >= LIENZO[1]:
                print('OJO: %s d%d toca el borde del lienzo %s' % (nm, d, c))
            recortes.append(('%s d%d' % (nm, d), tira, c))
    ancho = 150 + max((c[2] - c[0]) * ESC * len(tira) for _, tira, c in recortes)
    alto = sum((c[3] - c[1]) * ESC + 6 for _, _, c in recortes)
    hoja = Image.new('RGB', (ancho, alto), (24, 26, 32))
    dib = ImageDraw.Draw(hoja)
    y = 0
    for nombre, tira, c in recortes:
        cw, ch = c[2] - c[0], c[3] - c[1]
        dib.text((6, y + ch * ESC // 2), nombre, fill=(235, 235, 235))
        for i, f in enumerate(tira):
            r = f.crop(c).resize((cw * ESC, ch * ESC), Image.NEAREST)
            hoja.paste(r, (150 + i * cw * ESC, y), r)
        y += ch * ESC + 6
    esc = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'enemigos', 'prueba_3d', 'mutantes',
                       'aberracion_%s_hojas' % MUT)
    os.makedirs(esc, exist_ok=True)
    os.makedirs(VISTAS, exist_ok=True)
    nombre = 'aberracion_%s_%s.png' % (MUT, '_'.join(nombres) if nombres and len(nombres) <= 3 else 'todas')
    hoja.save(os.path.join(esc, nombre))
    hoja.save(VISTAS + nombre)
    print(os.path.join(esc, nombre), hoja.size)


if __name__ == '__main__':
    args = sys.argv[1:]
    if args[:1] == ['hoja']:
        _hoja_ver(args[1:])
    else:
        hornear('aberracion_mut_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
