# Comprueba el horno de la grafica contra el de la CPU, pixel a pixel, y mide los dos.
#   python gpu_comparar.py <modulo> <anim> [fotogramas] [dirs]      (CIEM_VAR=... etc si el modulo lo pide)
import importlib, sys, time, warnings
import numpy as np
warnings.filterwarnings('ignore')
import sdf_comun as sc
import sdf_gpu


def escenas(mod, anim, cuantos, dirs):
    n, fps, loop, nd, fn = mod.ANIMS[anim]
    sal = []
    for d in range(min(dirs, nd)):
        for i in np.linspace(0, n - 1, min(cuantos, n)).astype(int):
            t = i / n if loop else (i / (n - 1) if n > 1 else 0.0)
            pose = fn(t)
            sal.append((mod.MODELO, mod.escena_dir(pose, d) if hasattr(mod, 'escena_dir') else mod.escena(pose), d))
    return sal


if __name__ == '__main__':
    modulo, anim = sys.argv[1:3]
    cuantos = int(sys.argv[3]) if len(sys.argv) > 3 else 8
    dirs = int(sys.argv[4]) if len(sys.argv) > 4 else 2
    mod = importlib.import_module(modulo)
    tr = escenas(mod, anim, cuantos, dirs)
    f0 = sdf_gpu.Fotograma(*tr[0])
    raras = sum(1 for x in f0.firma if x[0] == 'raro')
    print('%s %s: %d fotogramas, %d piezas (%d sin leer), firmas distintas %d' % (
        modulo, anim, len(tr), len(tr[0][1]), raras, len({sdf_gpu.Fotograma(*x).firma for x in tr})))
    t0 = time.time()
    gpu = sdf_gpu.render_lote(tr)
    tg = time.time() - t0
    t0 = time.time()
    cpu = [sc.render(*x) for x in tr]
    tc = time.time() - t0
    print('GPU %.2f s (%.3f s/fotograma) | CPU, un nucleo %.2f s (%.3f s/fotograma) | x%.1f' % (
        tg, tg / len(tr), tc, tc / len(tr), tc / tg))
    print('memoria maxima de la grafica: %.2f GB' % (sdf_gpu.torch.cuda.max_memory_reserved() / 1e9))
    distintos = 0; peor = 0; total = 0
    for a, b in zip(gpu, cpu):
        x = np.asarray(a).astype(int); y = np.asarray(b).astype(int)
        dif = np.abs(x - y).max(axis=2)
        distintos += int((dif > 0).sum()); peor = max(peor, int(dif.max())); total += int((y[:, :, 3] > 0).sum())
    print('PIXELES DISTINTOS: %d de %d dibujados (diferencia maxima %d)' % (distintos, total, peor))
