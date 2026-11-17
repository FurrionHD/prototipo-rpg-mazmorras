#!/usr/bin/env python3
"""apuntar_pies.py -- EL PUNTO DEL SUELO de cada hoja SDF, para la sombra del juego (16/11, memoria sombras-fuera-del-sprite).

Cada horno dice en su Modelo(..., lienzo, pies) donde cae el suelo (z = 0) dentro del lienzo, pero ese dato no llegaba al
juego: el juego solo sabia el lienzo. La sombra ya no va horneada en el dibujo, la pinta el juego (SombraSuelo) en el
punto del suelo, asi que hace falta. Este script importa cada horno con su variante (sin hornear nada: solo lee el
MODELO) y apunta 'pies' en el hojas.json de su carpeta. hornear() ya lo escribe solo desde ahora; esto es para las
carpetas que ya estan horneadas.

  python tools/sprites_sdf/apuntar_pies.py          # todas; avisa de las carpetas que no ha sabido de que horno son
"""
import glob
import json
import os
import subprocess
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.normpath(os.path.join(AQUI, '..', '..'))

# (script, {variable: valor}) por cada carpeta que sale de un horno con variantes.
_SLIMES = ['arr180', 'cen192', 'cie204', 'des308', 'esc198', 'evo2', 'lava160', 'mia138', 'mut120', 'obs211', 'ojo224',
           'pes152', 'pun120', 'rey280', 's100', 's115', 's150', 's170', 'tir308']
COMBOS = (
    [(s, {}) for s in ['aberracion_sdf', 'acechador_sdf', 'arana_sdf', 'bestia_acorazada_sdf', 'capullo_sdf', 'chillon_sdf',
                       'chupasimas_sdf', 'ciempies_sdf', 'coloso_sdf', 'escarabajo_cristal_sdf', 'escarabajo_sdf',
                       'gargola_sdf', 'golem_sdf', 'miconido_sdf', 'minotauro_sdf', 'segadora_sdf', 'trent_sdf',
                       'jabali_sdf', 'rata_sdf']]
    + [('aberracion_mut_sdf', {'ABERRACION_MUT': v}) for v in ['galvanica', 'tormenta']]
    + [('arana_mutantes_sdf', {'ARANA_VAR': v}) for v in ['tejedora', 'tormentosa']]
    + [('bichos_ambar_sdf', {'BICHO': 'garrapata', 'HINCHA': str(h)}) for h in range(4)]
    + [('bichos_ambar_sdf', {'BICHO': v}) for v in ['mosquito', 'pelotero']]
    + [('ciempies_mut_sdf', {'CIEM_VAR': v}) for v in ['bicefalo', 'nudo']]
    + [('escarabajo_mut_sdf', {'ESC_VAR': v}) for v in ['iman', 'saeta', 'errante']]
    + [('jabali_sdf', {'JABALI_VAR': v, 'JABALI_ROTOS': r, 'JABALI_PELADO': p})
       for v in ['colmillo', 'ancestral'] for r in ['', '1'] for p in ['', '1']]
    + [('miconido_mut_sdf', {'MIC_VAR': v}) for v in ['campana', 'florecido']]
    + [('polilla_mut_sdf', {'POLILLA_MUT': v}) for v in ['vigilia', 'mortaja', 'insomne']]
    + [('polilla_variante_sdf', {'POLILLA_VAR': v}) for v in ['a', 'd']]
    + [('rata_sdf', {'RATA_VAR': v}) for v in ['rey', 'cloacas', 'desguace', 'cuarzo', 'drusa', 'sombria', 'chatarra']]
    + [('segadora_mut_sdf', {'SEG_VAR': v}) for v in ['sierra', 'vendaval']]
    + [('slime_sdf', {'SLIME_VAR': v}) for v in _SLIMES]
    + [('trent_mutantes_sdf', {'TRENT_VAR': 'ambarino', 'TRENT_SIN_COSTRA': c}) for c in ['', '1']]
    + [('trent_mutantes_sdf', {'TRENT_VAR': 'espantajo'})]
)

# Lo que corre dentro de cada proceso: importar el horno (sin el __main__) y decir su salida, lienzo y pies.
_LEER = r'''
import importlib, json, sys
sys.path.insert(0, sys.argv[1])
m = importlib.import_module(sys.argv[2])
md = getattr(m, "MODELO", m)   # (el Minotauro no tiene Modelo: W, H, OX, OY sueltos)
print("PIES " + json.dumps({"salida": m.SALIDA, "lienzo": [md.W, md.H], "pies": [md.OX, md.OY]}))
'''


def leer(script, env):
    e = dict(os.environ)
    for k in ('ABERRACION_MUT', 'ARANA_VAR', 'BICHO', 'HINCHA', 'CIEM_VAR', 'ESC_VAR', 'JABALI_VAR', 'JABALI_ROTOS',
              'JABALI_PELADO', 'MIC_VAR', 'POLILLA_MUT', 'POLILLA_VAR', 'RATA_VAR', 'SEG_VAR', 'SLIME_VAR', 'SLIME_SALIDA',
              'TRENT_VAR', 'TRENT_SIN_COSTRA'):
        e.pop(k, None)
    e.update(env)
    r = subprocess.run([sys.executable, '-c', _LEER, AQUI, script], cwd=RAIZ, env=e, capture_output=True, text=True)
    for linea in r.stdout.splitlines():
        if linea.startswith('PIES '):
            return json.loads(linea[5:])
    print('  !! %s %s: %s' % (script, env, (r.stderr.strip().splitlines() or ['?'])[-1]))
    return None


def main():
    hechas = {}
    for script, env in COMBOS:
        d = leer(script, env)
        if d is None:
            continue
        carpeta = os.path.normpath(os.path.join(RAIZ, d['salida']))
        meta_path = os.path.join(carpeta, 'hojas.json')
        if not os.path.exists(meta_path):
            continue
        meta = json.load(open(meta_path))
        if meta.get('lienzo') and list(meta['lienzo']) != d['lienzo']:
            print('  !! %s: el lienzo del horno %s no es el de la hoja %s (no lo toco)' % (d['salida'], d['lienzo'], meta['lienzo']))
            continue
        meta['pies'] = d['pies']
        with open(meta_path, 'w', newline='\n') as f:
            json.dump(meta, f, indent=1)   # (como lo escribe hornear)
        hechas[carpeta] = d['pies']
        print('%-48s lienzo %s pies %s' % (d['salida'], d['lienzo'], d['pies']))
    todas = [os.path.normpath(os.path.dirname(p)) for p in glob.glob(os.path.join(RAIZ, 'assets/sprites/enemigos/*/hojas.json'))]
    faltan = [c for c in todas if c not in hechas]
    print('\n%d carpetas con pies; sin saber de que horno son: %d' % (len(hechas), len(faltan)))
    for c in faltan:
        print('  falta', os.path.relpath(c, RAIZ))


if __name__ == '__main__':
    main()
