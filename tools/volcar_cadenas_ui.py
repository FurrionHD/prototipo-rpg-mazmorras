"""Vuelca las cadenas que parecen VISIBLES de los .gd (pase de textos de menus y avisos).

Uso: python -I tools/volcar_cadenas_ui.py [archivo_o_carpeta ...] [--salida ruta.txt]
Sin argumentos mira scripts/ui. Saca "archivo:linea  cadena", saltando comentarios, rutas,
identificadores (snake_case), prints y depuracion. Es una criba: puede colar alguna clave interna
y dejarse alguna frase hecha a trozos; sirve para leerlo todo de una vez, no para cambiar a ciegas.
"""
import os
import re
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Llamadas cuyas cadenas no ve el jugador.
NO_VISIBLE = re.compile(
    r"\b(print|prints|printerr|print_debug|push_warning|push_error|assert|get_node|get_node_or_null|"
    r"has_node|find_child|preload|load|has_method|emit_signal|connect|disconnect|call|call_deferred|"
    r"set_meta|get_meta|has_meta|remove_meta|is_in_group|add_to_group|get_nodes_in_group|"
    r"add_theme_[a-z_]+|get_theme_[a-z_]+|has_theme_[a-z_]+|Input\.is_action[a-z_]*|is_action[a-z_]*|"
    r"set_shader_parameter|tween_property|tween_method|Log\.d|_dbg|_log_dbg|DebugLog\.[a-z_]+|"
    r"ResourceLoader\.[a-z_]+|FileAccess\.[a-z_]+|DirAccess\.[a-z_]+|ClassDB\.[a-z_]+|"
    r"rpc[a-z_]*|Steam\.[a-z_]+|OS\.[a-z_]+)\s*\("
)
CADENA = re.compile(r'(?<![&^])"((?:[^"\\]|\\.)*)"')
IDENT = re.compile(r"^[a-z0-9_./:%-]*$")
ACENTO = re.compile(r"[áéíóúñÁÉÍÓÚÑ¿¡]")


def quitar_comentario(linea: str) -> str:
    """Corta el # que no este dentro de una cadena."""
    dentro = False
    i = 0
    while i < len(linea):
        c = linea[i]
        if c == "\\" and dentro:
            i += 2
            continue
        if c == '"':
            dentro = not dentro
        elif c == "#" and not dentro:
            return linea[:i]
        i += 1
    return linea


def parece_visible(s: str) -> bool:
    t = s.strip()
    if len(t) < 2 or not re.search(r"[A-Za-záéíóúñÁÉÍÓÚÑ]", t):
        return False
    if t.startswith(("res://", "user://", "uid://", "http", "%s" * 0 + "/root")):
        return False
    if IDENT.match(t) and not ACENTO.search(t):
        return False  # clave interna: "espada_larga", "ui_accept"
    if re.match(r"^[A-Z0-9_]+$", t):
        return False  # CONSTANTE
    if re.match(r"^[A-Za-z]+(/[A-Za-z0-9_]+)+$", t):
        return False  # ruta de nodo
    if re.match(r"^#?[0-9a-fA-F]{6,8}$", t):
        return False  # color
    return True


def cadenas_del_texto(texto: str):
    """(linea_de_inicio, contenido) de cada cadena "..." del archivo, aunque ocupe varias lineas.
    Salta comentarios (#) y las cadenas &"..." / ^"..." (StringName y NodePath)."""
    i, n, linea = 0, len(texto), 1
    while i < n:
        c = texto[i]
        if c == "\n":
            linea += 1
        elif c == "#":
            while i < n and texto[i] != "\n":
                i += 1
            continue
        elif c == '"':
            triple = texto.startswith('"""', i)
            previo = texto[i - 1] if i > 0 else ""
            fin_tok = '"""' if triple else '"'
            j = i + len(fin_tok)
            ini = linea
            while j < n and not texto.startswith(fin_tok, j):
                if texto[j] == "\\":
                    j += 1
                elif texto[j] == "\n":
                    linea += 1
                j += 1
            contenido = texto[i + len(fin_tok):j]
            if not triple and previo not in "&^":
                yield ini, contenido
            i = j + len(fin_tok)
            continue
        i += 1


# --revisar: los fallos que se repiten en el pase de textos (07/11, "cometes el mismo error una y otra vez").
# Reglas de docs/guia_textos.md y de lo acordado con el jefe. Lo que no se puede mirar a maquina (¿de que es este
# numero?, ¿"tu" en algo que lleva un enemigo?) se marca igual como RECORDATORIO para leerlo a mano.
TILDES = (r"sesion|codigo|menu|conexion|companer[oa]s?|acompanantes?|ultim[oa]s?|version|aqui|asi|tambien|despues|"
          r"todavia|facil|rapid[oa]|pagina|numero|minimo|maximo|energia|musica|encontro|perdio|cerro|recoleccion|"
          r"formacion|extraccion|direccion|contrasena|opcion|accion|dano|ningun|algun|tenia|habia|podia|dia|"
          r"mia|alli|ahi|ademas|segun|traves|baul|cafe|pocion|curacion|mision|anadir|anade")
GLOSARIO = (r"encaj\w*|\bpeg(a|an|as|ue|ó)\b|\bdosis\b|\bentradas?\b|\bCD\b|\bproc\b|\bstacks?\b|\bbuffs?\b|"
            r"\bdebuffs?\b|\bDoT\b|\bprob\.|\bresist\.|\bregen\b|\bcrít\.|\bpx\b|\bmv\b|motion value|\bhp\b|"
            r"farm\w*|craft\w*|\b(sub-?)?stats?\b|\bloot\b|\bspawn\w*|\bdrop\w*|\bnerf\w*|\bcooldown\b")
REVISAR = [
    (re.compile(r"(\d|%[ds]|%\.\d+f)%%?(?![ds.\d])"), "% sin espacio delante (va «20 %»)"),
    (re.compile(r"%\.[1-9]f"), "decimal con punto (%.Nf): usar StatusEffects.num / MenuScaffold.valor_es"),
    (re.compile(r"%%|\d ?%(?![sd.])"), "RECORDATORIO: ¿la frase dice DE QUÉ es este %? (ley)"),
    (re.compile(r"\bNo se pudo\b"), "«No se pudo» -> «No se ha podido»"),
    (re.compile(r"\bbuild\b|\bhost\b|\bhostear\b", re.I), "jerga: build/host"),
    (re.compile(GLOSARIO, re.I), "palabra del glosario prohibido (guia_textos.md, sección 3)"),
    (re.compile(r"\bech(a|as|an|ar|arle|arte|ártelo|árselo|es)\b|\bechó\b|\bintentó echar", re.I),
     "magias: «lanzar», no «echar»"),
    (re.compile(r"(?<![%\w])x%d|(?<![\w])x\d|(%d|\d) x (%s|\w)"), "«x3» / «3 x algo»: el signo es «×»"),
    (re.compile(r"%ds\b"), "«%ds»: con espacio, «%d s»"),
    (re.compile(r"\b(" + TILDES + r")\b", re.I), "¿tilde comida?"),
]
# Mayusculas de grito: palabra en MAYUSCULAS despues de texto en minusculas del mismo trozo, fuera de «».
SIGLAS = {"PC", "IP", "ID", "LAN", "UDP", "HTTP", "PNG", "JPG", "FPS", "DPS", "HSR", "OK", "NO", "MP", "VS", "UI", "IA"}
GRITO = re.compile(r"\b[A-ZÁÉÍÓÚÑ]{3,}\b")
_EMOJIS = None


def _emojis_pixel() -> set:
    global _EMOJIS
    if _EMOJIS is None:
        ruta = os.path.join(RAIZ, "scripts", "ui", "fuente_iconos_tabla.gd")
        with open(ruta, encoding="utf-8") as f:
            _EMOJIS = set(re.findall(r'^\s*"([^"]+)":', f.read(), re.M))
    return _EMOJIS


def _fuera_de_la_fuente(texto: str) -> list:
    """Simbolos raros que no estan en la fuente de iconos pixel (regla TODO EN PIXEL)."""
    malos = []
    for c in texto:
        o = ord(c)
        if o < 0x2000 or c in "–—…‘’“”«»·•×÷−→←↓" or c == "\ufe0f" or c == "⏎":
            continue
        if c not in _emojis_pixel() and (c + "\ufe0f") not in _emojis_pixel():
            malos.append(c)
    return malos


def revisar(salida: list) -> list:
    marcas = []
    for linea in salida:
        _ref, _tab, texto = linea.partition("\t")
        motivos = [m for rx, m in REVISAR if rx.search(texto)]
        for trozo in texto.split("  |  "):
            limpio = re.sub(r"«[^»]*»", "", trozo)
            for m in GRITO.finditer(limpio):
                if m.group(0) not in SIGLAS and re.search(r"[a-záéíóúñ]", limpio[:m.start()]):
                    motivos.append("MAYÚSCULAS de grito a mitad de frase (%s)" % m.group(0))
                    break
        raros = _fuera_de_la_fuente(texto)
        if raros:
            motivos.append("símbolo fuera de la fuente pixel: %s (TODO EN PIXEL)" % " ".join(sorted(set(raros))))
        if motivos:
            marcas.append(linea + "".join("\n    -> " + m for m in motivos))
    return marcas


def volcar(ruta: str, salida: list) -> None:
    rel = os.path.relpath(ruta, RAIZ).replace("\\", "/")
    with open(ruta, encoding="utf-8") as f:
        texto = f.read()
    lineas = texto.split("\n")
    por_linea: dict = {}
    for n, s in cadenas_del_texto(texto):
        cod = quitar_comentario(lineas[n - 1])
        if NO_VISIBLE.search(cod):
            continue
        if re.match(r"^\s*(signal|class_name|extends|@export|const\s+[A-Z_]+\s*:=\s*preload)", cod):
            continue
        if parece_visible(s):
            por_linea.setdefault(n, []).append(s.replace("\n", "⏎"))
    for n in sorted(por_linea):
        salida.append(f"{rel}:{n}\t" + "  |  ".join(por_linea[n]))


def main() -> None:
    args = sys.argv[1:]
    destino = None
    args = [a for a in args if a != "--revisar"]
    if "--salida" in args:
        i = args.index("--salida")
        destino = args[i + 1]
        del args[i:i + 2]
    if not args:
        args = [os.path.join(RAIZ, "scripts", "ui")]
    salida: list = []
    for a in args:
        a = a if os.path.isabs(a) else os.path.join(RAIZ, a)
        if os.path.isdir(a):
            for base, _dirs, archivos in os.walk(a):
                for nombre in sorted(archivos):
                    if nombre.endswith(".gd") and nombre != "debug_panel.gd":
                        volcar(os.path.join(base, nombre), salida)
        else:
            volcar(a, salida)
    if "--revisar" in sys.argv:
        salida = revisar(salida)
    texto = "\n".join(salida) + "\n"
    if destino:
        with open(destino, "w", encoding="utf-8") as f:
            f.write(texto)
        print(f"{len(salida)} lineas -> {destino}")
    else:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stdout.write(texto)


if __name__ == "__main__":
    main()
