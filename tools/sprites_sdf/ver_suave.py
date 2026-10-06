# ============================================================
#  ver_suave.py -- los modelos SDF vistos EN 3D, sin pasarlos a pixel art (06/10/2026, curiosidad del jefe: "ver los
#  modelos 3d en 3d y no solo en pixelart"). Mismo trazado de rayos que sdf_comun.render, pero a mas resolucion, con luz
#  CONTINUA (sin las 3 bandas), brillo especular, oclusion suave y SIN contorno. El gel translucido deja ver lo de dentro.
#  Uso: python tools/sprites_sdf/ver_suave.py [salida.png] [aumento]
#       (de momento, las filas de slime_veneno_versiones.py)
# ============================================================
import sys, os, math, copy
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
from sdf_comun import evalua, DIR_VECS, R_, U_, F_


def _trazar(mo, L, dir_i):
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
    for _ in range(200):
        idx = np.where(vivo)[0]
        if len(idx) == 0: break
        P = a_local(O[idx] + np.outer(t[idx], F_))
        d, _m = evalua(mo, P, L)
        hit = d < 0.01
        toca[idx[hit]] = True; vivo[idx[hit]] = False
        t[idx[~hit]] += np.maximum(d[~hit] * 0.8, 0.01)
        vivo &= ~(t > mo.lejos * 2.1)
    return O, a_local, ca, sa, t, np.where(toca)[0]


def render_suave(mo, L, dir_i):
    W, H = mo.W, mo.H
    O, a_local, ca, sa, t, hi = _trazar(mo, L, dir_i)
    img = np.zeros((H * W, 4))
    if len(hi) == 0:
        return img.reshape(H, W, 4)
    P = a_local(O[hi] + np.outer(t[hi], F_))
    _d, mats = evalua(mo, P, L)
    e = 0.03
    n = np.zeros_like(P)
    for a in range(3):
        dv = np.zeros(3); dv[a] = e
        n[:, a] = evalua(mo, P + dv, L)[0] - evalua(mo, P - dv, L)[0]
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-6)
    luz = np.array([-0.75, 0.35, 0.6]); luz /= np.linalg.norm(luz)
    lv = np.array([luz[0] * ca - luz[1] * sa, luz[0] * sa + luz[1] * ca, luz[2]])
    ndl = n @ lv
    # Oscurecer los huecos: cuanto espacio libre hay saliendo de la superficie (dos muestras).
    ao = 0.5 * np.clip(evalua(mo, P + n * 0.8, L)[0] / 0.8, 0, 1) + 0.5 * np.clip(evalua(mo, P + n * 2.0, L)[0] / 2.0, 0, 1)
    # Brillo especular hacia la camara (Blinn): la camara mira por -F_, en local.
    cam = -F_
    cam = np.array([cam[0] * ca - cam[1] * sa, cam[0] * sa + cam[1] * ca, cam[2]])
    hv = lv + cam; hv /= np.linalg.norm(hv)
    spec = np.clip(n @ hv, 0, 1) ** 40
    # Luz de borde (rim): el canto que da la espalda a la camara se aclara un poco, se lee el volumen.
    rim = (1.0 - np.clip(n @ cam, 0, 1)) ** 3
    col = np.zeros((len(hi), 3))
    for i, nom in enumerate(mo.nombres):
        sel = mats == i
        base = np.array(mo.mat[nom][1])
        if nom in mo.brillan:
            col[sel] = np.array(mo.mat[nom][-1])
            continue
        dif = 0.45 + 0.55 * np.clip(ndl[sel], -0.4, 1)
        c = base[None, :] * (dif * (0.55 + 0.45 * ao[sel]))[:, None]
        brillo = 0.75 if nom in mo.especular else 0.15
        c = c + spec[sel][:, None] * brillo + rim[sel][:, None] * 0.12 * base[None, :]
        col[sel] = c
    img[hi, :3] = col
    img[hi, 3] = 1.0
    img = img.reshape(H, W, 4)
    if mo.translucidos:
        matmap = np.full(H * W, -1); matmap[hi] = mats; matmap = matmap.reshape(H, W)
        idx_t = [mo.nombres.index(m) for m in mo.translucidos if m in mo.nombres]
        gel = np.isin(matmap, idx_t)
        L_op = [x for x in L if x[1] not in mo.translucidos]
        detras = np.zeros((H, W, 4))
        if L_op:
            mo2 = copy.copy(mo); mo2.translucidos = ()
            detras = render_suave(mo2, L_op, dir_i)
        ad = detras[:, :, 3]
        a = np.where(ad > 0, getattr(mo, 'alfa_dentro', mo.alfa), mo.alfa)
        claros = getattr(mo, 'claros_dentro', ())
        L_cl = [x for x in L_op if x[1] in claros]
        if L_cl:
            solo = render_suave(mo2, L_cl, dir_i)
            es_claro = (solo[:, :, 3] > 0) & (np.abs(solo[:, :, :3] - detras[:, :, :3]).sum(axis=2) < 0.02)
            a = np.where(es_claro, getattr(mo, 'alfa_claro', 0.15), a)
        fuera = a + (1.0 - a) * ad
        for ch in range(3):
            mezcla = (img[:, :, ch] * a + detras[:, :, ch] * ad * (1.0 - a)) / np.maximum(fuera, 1e-6)
            img[:, :, ch] = np.where(gel, mezcla, img[:, :, ch])
        img[:, :, 3] = np.where(gel, fuera, img[:, :, 3])
    return img


def aumentar(mo, k):
    m = copy.copy(mo)
    m.ppu = mo.ppu * k; m.W = mo.W * k; m.H = mo.H * k; m.OX = mo.OX * k; m.OY = mo.OY * k
    return m


def a_imagen(arr):
    return Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8), 'RGBA')


# LOS DEFINITIVOS: los que estan horneados en el juego (assets/sprites/enemigos/*_sdf*). (nombre, modulo, entorno)
TODOS = [
    ('slime', 'slime_sdf', {'SLIME_VAR': 's100'}),
    ('slime venenoso', 'slime_sdf', {'SLIME_VAR': 's115'}),
    ('slime profundo', 'slime_sdf', {'SLIME_VAR': 's150'}),
    ('slime abisal', 'slime_sdf', {'SLIME_VAR': 's170'}),
    ('slime de lava', 'slime_sdf', {'SLIME_VAR': 'lava160'}),
    ('rey slime', 'slime_sdf', {'SLIME_VAR': 'rey280'}),
    ('slime brotado', 'slime_sdf', {'SLIME_VAR': 'mut120'}),
    ('slime punzante', 'slime_sdf', {'SLIME_VAR': 'pun120'}),
    ('brotado punzante', 'slime_sdf', {'SLIME_VAR': 'evo2'}),
    ('rata', 'rata_sdf', {}),
    ('rey rata', 'rata_sdf', {'RATA_VAR': 'rey'}),
    ('jabali', 'jabali_sdf', {}),
    ('trent', 'trent_sdf', {}),
    ('golem', 'golem_sdf', {}),
    ('arana', 'arana_sdf', {}),
    ('escarabajo', 'escarabajo_sdf', {}),
    ('ciempies', 'ciempies_sdf', {}),
    ('miconido', 'miconido_sdf', {}),
    ('chupasimas', 'chupasimas_sdf', {}),
    ('chillon', 'chillon_sdf', {}),
    ('polilla A', 'polilla_variante_sdf', {'POLILLA_VAR': 'a'}),
    ('polilla D', 'polilla_variante_sdf', {'POLILLA_VAR': 'd'}),
    ('segadora', 'segadora_sdf', {}),
    ('acechador', 'acechador_sdf', {}),
    ('aberracion', 'aberracion_sdf', {}),
    ('bestia acorazada', 'bestia_acorazada_sdf', {}),
    ('gargola', 'gargola_sdf', {}),
    ('coloso', 'coloso_sdf', {}),
    ('minotauro', 'minotauro_sdf', {}),
    ('escarabajo de cristal', 'escarabajo_cristal_sdf', {}),
]
ALTO_FILA = 300     # cada enemigo se aumenta hasta mas o menos este alto de lienzo


def _modelo_y_escena(mod, modname):
    if modname == 'minotauro_sdf':
        # El minotauro va con su motor propio (el primero), pero sus piezas tienen el mismo formato.
        mo = Modelo(3.1, (mod.W, mod.H), (mod.OX, mod.OY), mod.MAT, mod.BORDE, suaves=mod.SUAVES)
        return mo, lambda d: mod.escena(mod.POSE())
    if modname == 'polilla_variante_sdf':
        return mod.MODELO, lambda d: mod.escena(mod.pm.POSE())
    if hasattr(mod, 'escena_dir'):
        return mod.MODELO, lambda d: mod.escena_dir(mod.POSE(), d)
    return mod.MODELO, lambda d: mod.escena(mod.POSE())


def fila_de(i, carpeta):
    nombre, modname, _env = TODOS[i]
    import importlib
    mod = importlib.import_module(modname)
    mo, esc = _modelo_y_escena(mod, modname)
    k = max(1.0, ALTO_FILA / mo.H)
    mo = aumentar(mo, 1)
    mo.ppu *= k; mo.W = int(mo.W * k); mo.H = int(mo.H * k); mo.OX *= k; mo.OY *= k
    fotos = [a_imagen(render_suave(mo, esc(d), d)) for d in range(5)]
    W, H = fotos[0].size
    y0, y1 = H, 0
    for f in fotos:
        bb = f.getbbox()
        if bb: y0 = min(y0, bb[1]); y1 = max(y1, bb[3])
    y0 = max(0, y0 - 6); y1 = min(H, y1 + 6)
    fila = Image.new('RGBA', (W * 5, y1 - y0), (0, 0, 0, 0))
    for j, f in enumerate(fotos):
        fila.paste(f.crop((0, y0, W, y1)), (j * W, 0))
    fila.save(os.path.join(carpeta, '%02d.png' % i))


if __name__ == '__main__' and len(sys.argv) > 1 and sys.argv[1] == 'uno':
    fila_de(int(sys.argv[2]), sys.argv[3])
    print(TODOS[int(sys.argv[2])][0], 'ok', flush=True)
    sys.exit(0)

if __name__ == '__main__' and len(sys.argv) > 1 and sys.argv[1] == 'todos':
    import subprocess
    from concurrent.futures import ThreadPoolExecutor
    carpeta = 'tools/salida/sdf/suave'
    os.makedirs(carpeta, exist_ok=True)
    sal = sys.argv[2] if len(sys.argv) > 2 else 'tools/salida/sdf/enemigos_3d.png'
    def uno(i):
        env = dict(os.environ); env.update(TODOS[i][2])
        r = subprocess.run([sys.executable, __file__, 'uno', str(i), carpeta], env=env, capture_output=True, text=True)
        print(r.stdout.strip() or (TODOS[i][0] + ' FALLO: ' + r.stderr[-800:]), flush=True)
    # SOLO_JUNTAR=1: no vuelve a pintar, solo monta la lamina con las filas que ya hay.
    if not os.environ.get('SOLO_JUNTAR'):
        with ThreadPoolExecutor(max_workers=max(2, (os.cpu_count() or 4) - 1)) as ex:
            list(ex.map(uno, range(len(TODOS))))
    filas = []
    for i, (nombre, _m, _e) in enumerate(TODOS):
        f = os.path.join(carpeta, '%02d.png' % i)
        if os.path.exists(f):
            filas.append((nombre, Image.open(f)))
    IZQ = 190
    ancho = IZQ + max(im.width for _, im in filas)
    alto = sum(im.height for _, im in filas)
    lam = Image.new('RGB', (ancho, alto), (40, 42, 50))
    dr = ImageDraw.Draw(lam)
    y = 0
    for j, (nombre, im) in enumerate(filas):
        if j % 2:
            dr.rectangle((0, y, ancho, y + im.height), fill=(46, 48, 57))
        dr.text((10, y + im.height // 2 - 5), nombre, fill=(225, 225, 225))
        lam.paste(im, (IZQ, y), im)
        y += im.height
    lam.save(sal)
    print(sal)
    sys.exit(0)

if __name__ == '__main__':
    import slime_veneno_versiones as SV
    sal = sys.argv[1] if len(sys.argv) > 1 else 'tools/salida/sdf/slime_veneno_versiones_3d.png'
    k = int(sys.argv[2]) if len(sys.argv) > 2 else 5
    filas = []
    for nombre, esc, fn, extra in SV.FILAS:
        L = fn()
        mo = aumentar(SV.modelo(esc, **extra), k)
        filas.append((nombre, [a_imagen(render_suave(mo, L, d)) for d in range(5)]))
        print(nombre, 'ok', flush=True)
    W, H = filas[0][1][0].size
    y_ini, y_fin = H, 0
    for _, fotos in filas:
        for f in fotos:
            bb = f.getbbox()
            if bb:
                y_ini = min(y_ini, bb[1]); y_fin = max(y_fin, bb[3])
    y_ini = max(0, y_ini - 8); y_fin = min(H, y_fin + 8); h = y_fin - y_ini
    IZQ = 150
    lam = Image.new('RGB', (W * 5 + IZQ, h * len(filas)), (40, 42, 50))
    dr = ImageDraw.Draw(lam)
    for j, (nombre, fotos) in enumerate(filas):
        dr.text((8, j * h + h // 2 - 5), nombre, fill=(220, 220, 220))
        for i, f in enumerate(fotos):
            fc = f.crop((0, y_ini, f.size[0], y_fin))
            lam.paste(fc, (IZQ + i * W, j * h), fc)
    lam.save(sal)
    print(sal)
