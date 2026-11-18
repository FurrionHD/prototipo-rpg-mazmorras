#!/usr/bin/env python3
# ============================================================
#  chupasimas_efectos_horno.py -- HORNEA LOS EFECTOS DE LA CHUPASIMAS Y SUS MUTANTES, los de su lamina aprobada (18/11/2026:
#  "si asi estaran bien", tools/sprites_sdf/chupasimas_efectos_pixel.py), SIN REJILLA (transparencia de verdad: 4 pasadas,
#  alfa en 4 escalones). La receta de polilla_efectos_horno.py.
#  SOBRE QUIEN RECIBE, (CX, CY) = sus pies:
#    ventosa_dientes   el basico y el Adherirse (la normal, el Coagulo y el Adherirse de la Madre): llega abierta y se cierra
#    ventosa_mana      lo mismo en azul: el Mordisco vidriado y el Sorbo (la Vidriada) y el basico de la Madre
#  LO QUE VIAJA DE LA VICTIMA A SU BOCA (EfectoPixel.poner_vuelo: la distancia la dice cada pelea), una gota cada vez:
#    gota_sangre / gota_mana            la gota en vuelo (la mueve el codigo)
#    gota_entra_sangre / gota_entra_mana  al llegar a la boca: se encoge y entra
#  SOBRE ELLA (origen = el CENTRO DE SU SPRITE, como lo pone escena; el juego usa EfectoPixel.centro_sprite), 5 direcciones:
#    cuaja_coagulo / cuaja_madre        la costra se cuaja: gotas rojas que suben por el lomo y se oscurecen a marron
#    chorrea_coagulo / chorrea_madre    le entra agua con la costra puesta: salpica y la costra chorrea (el x1,3)
#    postillas_coagulo / postillas_madre  le rompen la costra: las postillas saltan y una salpicadura roja
#  EL RAYO DE MANA: el haz lo pinta RayoPixel (lo que mide lo dice la pelea; grosor = la carga). Aqui lo de alrededor:
#    rayo_boca_0|1|2   (origen = la boca) el mana que se le junta en la boca antes de soltarlo, segun la carga
#    chispa_mana       las chispas a lo largo del haz cuando va lleno
#    python tools/sprites_sdf/chupasimas_efectos_horno.py
# ============================================================
import chupasimas_efectos_pixel as cp      # (trae su lienzo: va antes que los demas)
import miconido_efectos_pixel as mi
import escarabajo_efectos_pixel as ep
import slime_efectos_pixel as sl
import rata_efectos_pixel as rt
import ciempies_efectos_pixel as ce
import horno_efectos as ho
import transparencia as tr
from slime_efectos_pixel import nuevo, estrella

LA = 'chupasimas'
W, H = cp.W, cp.H
CX, CY = W // 2, H // 2 + 20
MODS = [ce, ep, sl, rt, mi, cp]
# El sprite se pone por su CENTRO (como hace escena): lo que sale de su cuerpo se lanza desde el centro de su sprite.
A = (CX, CY - 10)
CON_COSTRA = {'coagulo': cp.COAGULO_C, 'madre': cp.MADRE_C}
SIN_COSTRA = {'coagulo': cp.COAGULO, 'madre': cp.MADRE}


def V():
    return (CX, CY)


def guardar(nombre, gen, fps, n_filas=1, bucle=False, origen=None):
    filas = tr.filas_con_alfa(gen, MODS)
    return ho.guardar_efecto(LA, nombre, filas, [origen or (CX, CY)] * n_filas, fps, bucle)


# ------------------------------------------------------------
#  SOBRE QUIEN RECIBE
# ------------------------------------------------------------
def g_ventosa(pal):
    """La de su lamina (mordisco): se cierra de golpe en el marco 2 (ahi toca), y se va en el 5."""
    def gen():
        hx, hy = mi.cabeza(V())
        out = []
        for e in range(6):
            s, a = nuevo(), nuevo()
            cp.ventosa(a, hx, hy, e, pal)
            out.append((s, a))
        return [out]
    return gen


def g_gota(pal):
    def gen():
        s, a = nuevo(), nuevo()
        cp.bolita(a, CX, CY, 1.6, pal)
        return [[(s, a)]]
    return gen


def g_gota_entra(pal):
    def gen():
        out = []
        for r in (1.2, 0.8):
            s, a = nuevo(), nuevo()
            cp.bolita(a, CX, CY, r, pal)
            out.append((s, a))
        return [out]
    return gen


# ------------------------------------------------------------
#  SOBRE ELLA
# ------------------------------------------------------------
def _caja(var, fila):
    return mi.caja_dibujo(cp.marco(var, 'idle', 0, fila), A)


def g_cuaja(quien):
    var = SIN_COSTRA[quien]

    def gen():
        filas = []
        for fila in range(5):
            box = _caja(var, fila)
            out = []
            for f in range(13):
                s, a = nuevo(), nuevo()
                cp.cuaja(a, box, f, fila)
                out.append((s, a))
            filas.append(out)
        return filas
    return gen


def g_chorrea(quien):
    var = CON_COSTRA[quien]

    def gen():
        filas = []
        for fila in range(5):
            box = _caja(var, fila)
            out = []
            for f in range(12):
                s, a = nuevo(), nuevo()
                cp.chorrea(a, box, f, 9)
                out.append((s, a))
            filas.append(out)
        return filas
    return gen


def g_postillas(quien):
    var = CON_COSTRA[quien]

    def gen():
        filas = []
        for fila in range(5):
            x0, y0, x1, y1 = _caja(var, fila)
            out = []
            for e in range(10):
                s, a = nuevo(), nuevo()
                cp.postillas(a, (x0 + x1) / 2, (y0 + y1) / 2 - 2, e, 5)
                out.append((s, a))
            filas.append(out)
        return filas
    return gen


# ------------------------------------------------------------
#  EL RAYO
# ------------------------------------------------------------
def g_rayo_boca(carga):
    """Los dos primeros marcos de cp.rayo: el mana se le junta en la boca, mas cuanto mas lleva."""
    def gen():
        out = []
        for e in range(2):
            s, a = nuevo(), nuevo()
            cp.rayo(a, (CX, CY), (CX + 40, CY), e, carga, cp.MANA)
            out.append((s, a))
        return [out]
    return gen


def g_chispa():
    out = []
    for r in (3, 2, 1):
        s, a = nuevo(), nuevo()
        estrella(a, CX, CY, r, cp.MANA)
        out.append((s, a))
    return [out]


def principal():
    d = {}
    d['ventosa_dientes'] = guardar('ventosa_dientes', g_ventosa(cp.DIENTE), 12.0)
    d['ventosa_mana'] = guardar('ventosa_mana', g_ventosa(cp.MANA), 12.0)
    for nom, pal in (('sangre', cp.SANGRE), ('mana', cp.MANA)):
        d['gota_' + nom] = guardar('gota_' + nom, g_gota(pal), 12.0)
        d['gota_entra_' + nom] = guardar('gota_entra_' + nom, g_gota_entra(pal), 12.0)
    for quien in ('coagulo', 'madre'):
        d['cuaja_' + quien] = guardar('cuaja_' + quien, g_cuaja(quien), 11.0, 5, origen=A)
        d['chorrea_' + quien] = guardar('chorrea_' + quien, g_chorrea(quien), 12.0, 5, origen=A)
        d['postillas_' + quien] = guardar('postillas_' + quien, g_postillas(quien), 12.0, 5, origen=A)
    for i, carga in enumerate((0.15, 0.55, 1.0)):
        d['rayo_boca_%d' % i] = guardar('rayo_boca_%d' % i, g_rayo_boca(carga), 11.0)
    d['chispa_mana'] = guardar('chispa_mana', g_chispa, 14.0)
    ho.apuntar(LA, d)


if __name__ == '__main__':
    principal()
