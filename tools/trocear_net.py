"""Saca uno o varios tramos de scripts/net/net.gd a un modulo hijo de Net.

uso: python trocear_net.py <modulo> <NodoNombre> <ClaseConst> "<cabecera>" <inicio1> <fin1> [<inicio2> <fin2> ...]
  <modulo>     nombre del var en Net y del archivo net_<modulo>.gd
  inicioN/finN prefijos de linea: el tramo va desde la linea que EMPIEZA por inicioN hasta la anterior a
               la que empieza por finN (el fin se busca despues del inicio).
Opciones por entorno: SECO=1 -> no escribe, solo informa.
"""
import os, re, sys, glob

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NET = os.path.join(RAIZ, "scripts", "net", "net.gd")

mod, nodo, clase, cabecera = sys.argv[1:5]
marcas = sys.argv[5:]
seco = os.environ.get("SECO") == "1"

L = open(NET, encoding="utf-8").read().split("\n")


def idx_linea(prefijo, desde=0):
    for i in range(desde, len(L)):
        if L[i].startswith(prefijo):
            return i
    raise SystemExit("no encuentro la marca: %r" % prefijo)


# --- tramos (se amplian hacia arriba para coger la cabecera "# ===" pegada) ---
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

# EXCLUIR=f1,f2: funciones que estan dentro del tramo pero se QUEDAN en net.gd (con su comentario y @rpc)
for nombre in [n for n in os.environ.get("EXCLUIR", "").split(",") if n]:
    i = next((k for k in sorted(en_tramo) if re.match(r"^(?:static\s+)?func\s+" + nombre + r"\(", L[k])), None)
    if i is None:
        raise SystemExit("EXCLUIR: no encuentro func %s en el tramo" % nombre)
    a = i
    while a - 1 in en_tramo and (L[a - 1].startswith("#") or L[a - 1].startswith("@")) \
            and not L[a - 1].startswith("# ---") and not L[a - 1].startswith("# ==="):
        a -= 1
    b = i + 1
    while b < len(L) and (L[b].strip() == "" or L[b].startswith("\t") or L[b].startswith(" ")):
        b += 1
    while L[b - 1].strip() == "":
        b -= 1
    for k in range(a, b):
        en_tramo.discard(k)
    print("se queda en net.gd:", nombre, "(lineas %d-%d)" % (a + 1, b))


def partir(linea):
    """(codigo, comentario) respetando comillas."""
    q = None
    for i, c in enumerate(linea):
        if q:
            if c == "\\":
                continue
            if c == q:
                q = None
        elif c in "\"'":
            q = c
        elif c == "#":
            return linea[:i], linea[i:]
    return linea, ""


DEF = re.compile(r"^(?:static\s+)?(func|var|const|signal)\s+(\w+)")

def definiciones(lineas_idx):
    out = {}
    for i in lineas_idx:
        m = DEF.match(L[i])
        if m:
            out[m.group(2)] = (m.group(1), i)
    return out

todas = definiciones(range(len(L)))
propias = definiciones(sorted(en_tramo))

# --- variables/constantes de ARRIBA que solo usa el tramo: se mudan con su comentario ---
def usos(nombre, lineas_idx):
    pat = re.compile(r"(?<![\w.])" + re.escape(nombre) + r"\b")
    n = 0
    for i in lineas_idx:
        codigo, _ = partir(L[i])
        if DEF.match(L[i]) and DEF.match(L[i]).group(2) == nombre:
            continue
        n += len(pat.findall(codigo))
    return n

fuera_tramo = [i for i in range(len(L)) if i not in en_tramo]
forzadas = [n for n in os.environ.get("MUDAR", "").split(",") if n]
mudadas = []
for nombre, (tipo, i) in todas.items():
    if nombre in propias or tipo not in ("var", "const"):
        continue
    if i in en_tramo:
        continue
    if nombre in forzadas or (usos(nombre, sorted(en_tramo)) > 0 and usos(nombre, fuera_tramo) == 0):
        # comentario pegado encima
        c = i
        while c > 0 and L[c - 1].startswith("#") and not L[c - 1].startswith("# ---") \
                and not L[c - 1].startswith("# ===") and (c - 1) not in en_tramo:
            c -= 1
        mudadas.append((c, i, nombre))

# las externas (otros scripts) tambien cuentan: una var de arriba leida desde fuera no se muda
scripts = [f for f in glob.glob(os.path.join(RAIZ, "scripts", "**", "*.gd"), recursive=True)
           if os.path.abspath(f) != os.path.abspath(NET)]
raiz_dev = glob.glob(os.path.join(RAIZ, "tools", "prueba_*.gd"))
externos_txt = {f: open(f, encoding="utf-8").read() for f in scripts + raiz_dev}
mudadas_ok = []
for c, i, nombre in mudadas:
    if nombre not in forzadas and any(re.search(r"\bNet\." + re.escape(nombre) + r"\b", t)
                                      for t in externos_txt.values()):
        continue
    mudadas_ok.append((c, i, nombre))
mudadas = mudadas_ok
lineas_mudadas = set()
for c, i, _ in mudadas:
    lineas_mudadas.update(range(c, i + 1))

loc_net_previo = set(re.findall(r"^\s+var\s+(\w+)", chr(10).join(L), re.M))
nombres_mod = set(propias) | {n for _, _, n in mudadas}
nombres_net = set(todas) - nombres_mod
if mod in loc_net_previo:
    print("AVISO: hay locales llamadas %r en net.gd que taparian al modulo" % mod)
if mod in todas:
    raise SystemExit("ya hay algo llamado %r en net.gd" % mod)

# locales/parametros del modulo (no prefijar) y de net.gd restante (no prefijar con mod.)
LOCAL = re.compile(r"\b(?:var|const)\s+(\w+)|\bfor\s+(\w+)\s+in\b")
def locales(lineas):
    s = set()
    for l in lineas:
        codigo, _ = partir(l)
        for m in LOCAL.finditer(codigo):
            if not DEF.match(l):
                s.add(m.group(1) or m.group(2))
        m = re.match(r"^(?:static\s+)?func\s+\w+\((.*)\)", l)
        if m:
            for p in m.group(1).split(","):
                p = p.strip().split(":")[0].split("=")[0].strip()
                if p:
                    s.add(p)
    return s

txt_mod = [L[i] for i in sorted(lineas_mudadas)] + [L[i] for i in sorted(en_tramo)]
loc_mod = locales(txt_mod)
choques_mod = (nombres_net & loc_mod)
txt_net = [L[i] for i in range(len(L)) if i not in en_tramo and i not in lineas_mudadas]
loc_net = locales(txt_net)
choques_net = (nombres_mod & loc_net)

def reescribir(linea, nombres, prefijo, evitar):
    if linea.lstrip().startswith("#"):
        return linea
    codigo, com = partir(linea)
    usar = sorted(nombres - evitar, key=len, reverse=True)
    if not usar:
        return linea
    pat = re.compile(r"(?<![\w.$\"])(" + "|".join(map(re.escape, usar)) + r")\b(?!\s*:\s*(?:int|float|String|bool|Array|Dictionary|Vector2|Node|Color))")
    # no tocar la propia definicion ni parametros con nombre igual
    return pat.sub(prefijo + r"\1", codigo) + com

# --- construir el modulo ---
cuerpo = []
for i in sorted(lineas_mudadas):
    cuerpo.append(L[i])
if mudadas:
    cuerpo.append("")
    cuerpo.append("")
bloques = []
for a, b in tramos:
    t = L[a:b]
    while t and t[-1].strip() == "":
        t.pop()
    bloques.append("\n".join(t))
cuerpo.extend("\n\n\n".join(bloques).split("\n"))
def reescribir_mod(l):
    m = DEF.match(l)
    if not m:
        return reescribir(l, nombres_net, "Net.", loc_mod)
    if m.group(1) in ("var", "const") and "=" in partir(l)[0]:
        izq, der = l.split("=", 1)
        return izq + "=" + reescribir(der, nombres_net, "Net.", loc_mod)
    return l
cuerpo = [reescribir_mod(l) for l in cuerpo]

modulo_txt = cabecera.replace("\\n", "\n").rstrip("\n") + "\nextends Node\n\n" + "\n".join(cuerpo).rstrip("\n") + "\n"

# --- net.gd restante ---
resto = []
for i, l in enumerate(L):
    if i in en_tramo or i in lineas_mudadas:
        continue
    if DEF.match(l):
        resto.append(l)
    else:
        resto.append(reescribir(l, nombres_mod, mod + ".", loc_net))
# quitar tripletes de lineas vacias
limpio = []
for l in resto:
    if l.strip() == "" and len(limpio) >= 2 and limpio[-1].strip() == "" and limpio[-2].strip() == "":
        continue
    limpio.append(l)
# declarar e instanciar
ancla_const = "const NetPesca = preload(\"res://scripts/net/net_pesca.gd\")"
ancla_new = "\tadd_child(pesca)"
j = limpio.index(ancla_const)
limpio.insert(j + 1, "const %s = preload(\"res://scripts/net/net_%s.gd\")" % (clase, mod))
j = limpio.index("var pesca: NetPesca = null")
limpio.insert(j + 1, "var %s: %s = null" % (mod, clase))
j = limpio.index(ancla_new)
limpio[j + 1:j + 1] = ["\t%s = %s.new()" % (mod, clase), "\t%s.name = \"%s\"" % (mod, nodo), "\tadd_child(%s)" % mod]

# --- externos: Net.X -> Net.mod.X ---
cambios_ext = {}
publicos = nombres_mod
patext = re.compile(r"\bNet\.(" + "|".join(map(re.escape, sorted(publicos, key=len, reverse=True))) + r")\b")
for f, t in externos_txt.items():
    n = len(patext.findall(t))
    if n:
        cambios_ext[f] = (patext.sub(r"Net." + mod + r".\1", t), n)

print("tramos:", [(a + 1, b) for a, b in tramos], "lineas:", len(en_tramo))
print("mudadas de arriba:", [n for _, _, n in mudadas])
print("nombres del modulo:", len(nombres_mod))
print("AVISO locales del modulo que chocan con Net (no prefijados):", sorted(choques_mod))
print("AVISO locales de net.gd que chocan con el modulo (no prefijados):", sorted(choques_net))
print("externos:", {os.path.relpath(f, RAIZ): n for f, (_, n) in cambios_ext.items()})
# usos dinamicos por cadena
for nombre in nombres_mod:
    for f, t in list(externos_txt.items()) + [(NET, "\n".join(L))]:
        if re.search(r"[\"']" + re.escape(nombre) + r"[\"']", t):
            print("AVISO nombre en cadena:", nombre, "en", os.path.relpath(f, RAIZ))

if not seco:
    open(os.path.join(RAIZ, "scripts", "net", "net_%s.gd" % mod), "w", encoding="utf-8", newline="").write(modulo_txt)
    open(NET, "w", encoding="utf-8", newline="").write("\n".join(limpio))
    for f, (t, _) in cambios_ext.items():
        open(f, "w", encoding="utf-8", newline="").write(t)
    print("escrito")
