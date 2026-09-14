"""Saca tramos de un script de PANTALLA (p. ej. scripts/ui/combat.gd) a un TEMA: un RefCounted que lleva
la pantalla en `_pantalla` y se crea con ella (`var <tema> = Clase.new(self)`).

uso:
  python tools/trocear_pantalla.py <host.gd> <tema> <ClaseConst> "<cabecera>" "<inicio1>" "<fin1>" [...]

  - Las marcas son PREFIJOS de linea: el tramo va de la linea que empieza por <inicio> hasta la anterior a
    la que empieza por <fin> (buscada despues del inicio).
  - EXCLUIR=f1,f2   funciones del tramo que se QUEDAN en el host.
  - MUDAR=v1,v2     variables de arriba que se mudan aunque el host tambien las use.
  - SECO=1          solo informa.

Lo que hace:
  1. Mueve el tramo (y las variables que solo usa el) a <dir del host>/<prefijo>_<tema>.gd.
  2. En el tema, todo lo que era del host (funciones, variables, enums, señales) y lo que es de Control
     (tools/miembros_control.txt) pasa a `_pantalla.x`.
  3. En el host, lo movido pasa a `<tema>.x`.
  4. Las funciones que se usan DESDE FUERA (otro script las llama por nombre) dejan un PUENTE de una linea
     en el host con la misma firma: nada de fuera cambia.
"""
import os, re, sys, glob

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
host_rel, tema, clase, cabecera = sys.argv[1:5]
marcas = sys.argv[5:]
seco = os.environ.get("SECO") == "1"
HOST = os.path.join(RAIZ, host_rel)
prefijo_archivo = os.path.splitext(os.path.basename(HOST))[0]
MOD = os.path.join(os.path.dirname(HOST), "%s_%s.gd" % (prefijo_archivo, tema))
mod_res = "res://" + os.path.relpath(MOD, RAIZ).replace("\\", "/")

L = open(HOST, encoding="utf-8").read().split("\n")
CONTROL = set(open(os.path.join(RAIZ, "tools", "miembros_control.txt"), encoding="utf-8").read().split())


def idx_linea(prefijo, desde=0):
    for i in range(desde, len(L)):
        if L[i].startswith(prefijo):
            return i
    raise SystemExit("no encuentro la marca: %r" % prefijo)


def partir(linea):
    q = None
    for i, c in enumerate(linea):
        if q:
            if c == q:
                q = None
        elif c in "\"'":
            q = c
        elif c == "#":
            return linea[:i], linea[i:]
    return linea, ""


DEF = re.compile(r"^(?:static\s+)?(?:@onready\s+|@export\s+)?(func|var|const|signal|enum)\s+(\w+)")

# --- tramos ---
tramos = []
for k in range(0, len(marcas), 2):
    a = idx_linea(marcas[k])
    if a > 0 and L[a - 1].startswith("# ====="):
        a -= 1
    b = idx_linea(marcas[k + 1], a + 1)
    if L[b - 1].startswith("# =====") and not L[b].startswith("# ====="):
        b -= 1
    tramos.append((a, b))
tramos.sort()
en_tramo = set()
for a, b in tramos:
    en_tramo.update(range(a, b))


def rango_funcion(i):
    """(inicio con comentarios y anotaciones, fin exclusivo) de la func de la linea i."""
    a = i
    while a - 1 >= 0 and (L[a - 1].startswith("#") or L[a - 1].startswith("@")) \
            and not L[a - 1].startswith("# ---") and not L[a - 1].startswith("# ==="):
        a -= 1
    b = i + 1
    while b < len(L) and (L[b].strip() == "" or L[b].startswith("\t") or L[b].startswith(" ")):
        b += 1
    while L[b - 1].strip() == "":
        b -= 1
    return a, b


for nombre in [n for n in os.environ.get("EXCLUIR", "").split(",") if n]:
    i = next((k for k in sorted(en_tramo) if re.match(r"^(?:static\s+)?func\s+" + nombre + r"\(", L[k])), None)
    if i is None:
        raise SystemExit("EXCLUIR: no encuentro func %s en el tramo" % nombre)
    a, b = rango_funcion(i)
    for k in range(a, b):
        en_tramo.discard(k)


def definiciones(idx):
    out = {}
    for i in idx:
        m = DEF.match(L[i])
        if m:
            out[m.group(2)] = (m.group(1), i)
    return out


todas = definiciones(range(len(L)))
propias = definiciones(sorted(en_tramo))


def usos(nombre, idx):
    pat = re.compile(r"(?<![\w.])" + re.escape(nombre) + r"\b")
    n = 0
    for i in idx:
        m = DEF.match(L[i])
        if m and m.group(2) == nombre:
            continue
        n += len(pat.findall(partir(L[i])[0]))
    return n


fuera = [i for i in range(len(L)) if i not in en_tramo]
forzadas = [n for n in os.environ.get("MUDAR", "").split(",") if n]
mudadas = []
for nombre, (tipo, i) in todas.items():
    if nombre in propias or tipo not in ("var", "const") or i in en_tramo:
        continue
    if L[i].startswith("@onready"):
        continue
    # Una PROPIEDAD con get/set debajo (la declaracion acaba en ':') no se muda: solo se moveria la
    # primera linea y su bloque se quedaria colgando.
    if partir(L[i])[0].rstrip().endswith(":"):
        continue
    if nombre in forzadas or (usos(nombre, sorted(en_tramo)) > 0 and usos(nombre, fuera) == 0):
        c = i
        while c > 0 and L[c - 1].startswith("#") and not L[c - 1].startswith("# ---") \
                and not L[c - 1].startswith("# ===") and (c - 1) not in en_tramo:
            c -= 1
        mudadas.append((c, i, nombre))
def fin_declaracion(i):
    """Ultima linea de una declaracion que puede ocupar varias (una lista o un dict entre corchetes)."""
    prof = 0
    k = i
    while True:
        codigo = re.sub(r'"(?:[^"\\]|\\.)*"', '""', partir(L[k])[0])
        prof += codigo.count("[") + codigo.count("{") + codigo.count("(")
        prof -= codigo.count("]") + codigo.count("}") + codigo.count(")")
        if prof <= 0 or k + 1 >= len(L):
            return k
        k += 1


lineas_mudadas = set()
for c, i, _ in mudadas:
    lineas_mudadas.update(range(c, fin_declaracion(i) + 1))

nombres_mod = set(propias) | {n for _, _, n in mudadas}
nombres_host = set(todas) - nombres_mod

# --- quien usa lo movido DESDE FUERA (otros scripts o escenas): se le deja un puente ---
# Los TEMAS HERMANOS (otros <prefijo>_*.gd ya partidos) no cuentan como "de fuera": a esos se les
# reescribe la llamada (_pantalla.x -> _pantalla.<tema>.x) en vez de dejar un puente.
hermanos = [os.path.abspath(f) for f in glob.glob(os.path.join(os.path.dirname(HOST), prefijo_archivo + "_*.gd"))
            if os.path.abspath(f) != os.path.abspath(MOD)]
otros = [f for f in glob.glob(os.path.join(RAIZ, "scripts", "**", "*.gd"), recursive=True)
         if os.path.abspath(f) != os.path.abspath(HOST) and os.path.abspath(f) not in hermanos] + \
        glob.glob(os.path.join(RAIZ, "scenes", "**", "*.tscn"), recursive=True) + \
        glob.glob(os.path.join(RAIZ, "tools", "*.gd"))
# Sin comentarios: un "ver combat._pintar_test" en un comentario no es alguien que lo llame.
txt_otros = {f: "\n".join(partir(l)[0] for l in open(f, encoding="utf-8").read().split("\n"))
             if f.endswith(".gd") else open(f, encoding="utf-8").read() for f in otros}
puentes = []
avisos_cadena = []
for nombre, (tipo, i) in propias.items():
    if tipo != "func":
        continue
    usado_fuera = any(re.search(r"\." + re.escape(nombre) + r"\b", t) or
                      re.search(r"[\"']" + re.escape(nombre) + r"[\"']", t) for t in txt_otros.values())
    if usado_fuera:
        puentes.append(nombre)
for nombre in nombres_mod:
    for k, l in enumerate(L):
        if k in en_tramo:
            continue
        if re.search(r"[\"']" + re.escape(nombre) + r"[\"']", partir(l)[0]):
            avisos_cadena.append("%s (linea %d del host)" % (nombre, k + 1))

LOCAL = re.compile(r"\b(?:var|const)\s+(\w+)|\bfor\s+(\w+)\s+in\b")


def locales(lineas):
    s = set()
    for l in lineas:
        codigo = partir(l)[0]
        if not DEF.match(l):
            for m in LOCAL.finditer(codigo):
                s.add(m.group(1) or m.group(2))
        m = re.match(r"^(?:static\s+)?func\s+\w+\((.*)", l)
        if m:
            for p in m.group(1).split(","):
                p = p.strip().split(":")[0].split("=")[0].strip().rstrip(")")
                if p:
                    s.add(p)
        # lambdas: func(a, b)
        for m in re.finditer(r"\bfunc\s*\(([^)]*)\)", codigo):
            for p in m.group(1).split(","):
                p = p.strip().split(":")[0].split("=")[0].strip()
                if p:
                    s.add(p)
    return s


txt_mod = [L[i] for i in sorted(lineas_mudadas)] + [L[i] for i in sorted(en_tramo)]
loc_mod = locales(txt_mod)
txt_host = [L[i] for i in range(len(L)) if i not in en_tramo and i not in lineas_mudadas]
loc_host = locales(txt_host)

# lo que en el tema hay que pedirle a la pantalla: lo del host + lo de Control que se use suelto
a_pantalla = (nombres_host | CONTROL) - loc_mod - nombres_mod


def reescribir(linea, nombres, prefijo):
    if linea.lstrip().startswith("#") or not nombres:
        return linea
    codigo, com = partir(linea)
    usar = sorted(nombres, key=len, reverse=True)
    pat = re.compile(r"(?<![\w.$\"'@])(" + "|".join(map(re.escape, usar)) + r")\b(?!\s*:=)(?!\s*:\s*\w)")
    trozos = re.split(r'("(?:[^"\\]|\\.)*")', codigo)   # no tocar dentro de cadenas
    for j in range(0, len(trozos), 2):
        trozos[j] = pat.sub(prefijo + r"\1", trozos[j])
        # En un TEMA, el 'self' del codigo movido era la PANTALLA (lo escribio ella), y el atajo $Ruta
        # buscaba el nodo en la escena de la pantalla: en un RefCounted no existe ninguno de los dos.
        if prefijo == "_pantalla.":
            trozos[j] = re.sub(r"(?<![\w.])self\b", "_pantalla", trozos[j])
            trozos[j] = re.sub(r"\$([A-Za-z_][\w/]*)", r'_pantalla.get_node("\1")', trozos[j])
    return "".join(trozos) + com


def reescribir_mod(l):
    m = DEF.match(l)
    if not m:
        return reescribir(l, a_pantalla, "_pantalla.")
    if m.group(1) in ("var", "const") and "=" in partir(l)[0]:
        izq, der = l.split("=", 1)
        return izq + "=" + reescribir(der, a_pantalla, "_pantalla.")
    if m.group(1) == "func":
        # valores por defecto de los parametros
        cab, _, resto = l.partition("(")
        return cab + "(" + reescribir(resto, a_pantalla - loc_mod, "_pantalla.")
    return l


cuerpo = [L[i] for i in sorted(lineas_mudadas)]
if mudadas:
    cuerpo += ["", ""]
bloques = []
for a, b in tramos:
    t = [L[i] for i in range(a, b) if i in en_tramo]
    while t and t[-1].strip() == "":
        t.pop()
    bloques.append("\n".join(t))
cuerpo += "\n\n\n".join(bloques).split("\n")
cuerpo = [reescribir_mod(l) for l in cuerpo]
# tres lineas vacias seguidas (tras EXCLUIR) -> dos
limpio_mod = []
for l in cuerpo:
    if l.strip() == "" and len(limpio_mod) >= 2 and limpio_mod[-1].strip() == "" and limpio_mod[-2].strip() == "":
        continue
    limpio_mod.append(l)

modulo_txt = cabecera.replace("\\n", "\n").rstrip("\n") + '''
extends RefCounted

# La pantalla de la que es este tema: todo lo que no es del tema se le pide a ella. Tipada con su
# script para que Godot deduzca los tipos (los := sobre ella); los NOMBRES no los comprueba al compilar:
# de eso se encarga tools/verificar_pantalla.py.
const Pantalla = preload("%s")
var _pantalla: Pantalla = null


func _init(pantalla: Pantalla) -> void:
	_pantalla = pantalla


''' % ("res://" + host_rel.replace("\\", "/")) + "\n".join(limpio_mod).rstrip("\n") + "\n"

# --- host restante ---
resto = []
for i, l in enumerate(L):
    if i in en_tramo or i in lineas_mudadas:
        continue
    if DEF.match(l) and not DEF.match(l).group(1) == "var":
        resto.append(l)
    elif DEF.match(l):
        if "=" in partir(l)[0]:
            izq, der = l.split("=", 1)
            resto.append(izq + "=" + reescribir(der, nombres_mod - loc_host, tema + "."))
        else:
            resto.append(l)
    else:
        resto.append(reescribir(l, nombres_mod - loc_host, tema + "."))
limpio = []
for l in resto:
    if l.strip() == "" and len(limpio) >= 2 and limpio[-1].strip() == "" and limpio[-2].strip() == "":
        continue
    limpio.append(l)

# declarar el tema: tras 'extends'
j = next(k for k, l in enumerate(limpio) if l.startswith("extends "))
bloque_temas = "# --- LOS TEMAS de esta pantalla, cada uno en su archivo (ver su cabecera) ---"
if bloque_temas not in limpio:
    limpio[j + 1:j + 1] = ["", bloque_temas]
k = limpio.index(bloque_temas)
fin_bloque = k + 1
while fin_bloque < len(limpio) and (limpio[fin_bloque].startswith("const Combat") or limpio[fin_bloque].startswith("var ") and "= Combat" in limpio[fin_bloque] or limpio[fin_bloque].startswith("const " + clase)):
    fin_bloque += 1
limpio[fin_bloque:fin_bloque] = ['const %s = preload("%s")' % (clase, mod_res),
                                 "var %s = %s.new(self)" % (tema, clase)]

# puentes
def firma(nombre):
    i = propias[nombre][1]
    lineas = [L[i]]
    k = i
    while not partir(lineas[-1])[0].rstrip().endswith(":"):
        k += 1
        lineas.append(L[k])
    sig = " ".join(x.strip() for x in lineas)
    m = re.match(r"^(static\s+)?func\s+(\w+)\((.*)\)\s*(->\s*([\w\[\]]+))?\s*:$", sig)
    params = []
    depth = 0
    cur = ""
    for ch in m.group(3):
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            params.append(cur)
            cur = ""
        else:
            cur += ch
    if cur.strip():
        params.append(cur)
    nombres_p = [p.strip().split(":")[0].split("=")[0].strip() for p in params]
    ret = m.group(5)
    return sig, nombres_p, ret


if puentes:
    limpio += ["", "", "# --- PUENTES a %s: lo llaman desde fuera por su nombre (ver %s) ---" % (tema, os.path.basename(MOD))]
    for nombre in sorted(puentes):
        sig, ps, ret = firma(nombre)
        llamada = "%s.%s(%s)" % (tema, nombre, ", ".join(ps))
        limpio += [sig, "\t" + ("return " if ret and ret != "void" else "") + llamada, ""]

print("tramos:", [(a + 1, b) for a, b in tramos], "lineas:", len(en_tramo))
print("mudadas de arriba:", [n for _, _, n in mudadas])
print("nombres del tema:", len(nombres_mod), " puentes:", sorted(puentes))
if tema in loc_host:
    print("AVISO: hay locales llamadas %r en el host" % tema)
if avisos_cadena:
    print("AVISO nombres en cadena en el host:", avisos_cadena)
if any(re.search(r"\bself\b", partir(l)[0]) for l in txt_mod):
    print("AVISO: el tramo usa 'self': revisalo (en el tema 'self' es el tema, no la pantalla)")
cambios_hermanos = {}
for f in hermanos:
    t = open(f, encoding="utf-8").read()
    contador = [0]

    def sub(m):
        if m.group(1) in nombres_mod:
            contador[0] += 1
            return "_pantalla.%s.%s" % (tema, m.group(1))
        return m.group(0)

    t2 = re.sub(r"\b_pantalla\.(\w+)\b", sub, t)
    if contador[0]:
        cambios_hermanos[f] = t2
        print("tema hermano %s: %d llamadas pasan a _pantalla.%s" % (os.path.basename(f), contador[0], tema))
if not seco:
    for f, t2 in cambios_hermanos.items():
        open(f, "w", encoding="utf-8", newline="").write(t2)
    open(MOD, "w", encoding="utf-8", newline="").write(modulo_txt)
    open(HOST, "w", encoding="utf-8", newline="").write("\n".join(limpio))
    print("escrito", os.path.relpath(MOD, RAIZ))
