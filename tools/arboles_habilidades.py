# ============================================================
#  arboles_habilidades.py
#  ESCRIBE LOS ARBOLES DE MEJORAS de las habilidades en sus fichas (.tres), a partir de la tabla de abajo (24/11, los
#  arboles que se cierran con el jefe arma a arma; memoria empezar-habilidades-24-11).
#
#      python tools/arboles_habilidades.py            # todas las de la tabla
#      python tools/arboles_habilidades.py rafaga     # solo esa
#
#  Cada nodo: id, nivel, padres, excluye, nombre, sabor y cambios. Los numeros NO van en el sabor: la ficha del nodo los
#  saca de los datos (antes -> despues). El dinero del presupuesto va con ("presupuesto", parte): parte = lo que se lleva
#  ese nodo del +40 % de su nivel (0,75 = 30 de 40). Ver Mejoras.presupuesto.
#
#  Lo que pide cada nodo sale de su NIVEL: dominio 300 por nivel por encima del 1 (tramos de 25 por piso) y el oro de
#  ORO_POR_NIVEL (PROVISIONAL: calibrarlo con el oro que se lleva en cada piso).
#
#  Escribe con saltos de linea LF (memoria python-escribe-crlf) y deja el resto de la ficha como estaba: solo quita los
#  sub-recursos NM_* viejos y la linea 'arbol = [...]' (con su comentario de encima) y pone los nuevos.
# ============================================================
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
DOMINIO_POR_NIVEL = 300
ORO_POR_NIVEL = {2: 2000, 3: 8000, 4: 25000, 5: 70000}

P = "presupuesto"
SANGRADO = 1

ARBOLES = {
    "rafaga": [
        # Nv2: muchos enemigos o uno solo. Los tajos de mas por enemigo van +-25 % en DAÑO por enemigo de mas (no en
        # tajos: el de hoja fina vale el doble), asi que van x(1,25/0,75) y x(0,75/1,5); mas tajos sube el tope a 12.
        # HOJA FINA DESTACA A UNO (el jefe, "cada una con su identidad"): su tajo vale x1,8 (x1,5 de la forma y +20 % que
        # paga perdiendo area) y su nivel 2 se lleva lo mismo que mas tajos: a un enemigo +20 % en todos los niveles.
        # CON DOS DAGAS (el jefe: "y en dual?"): la 2a mano pega lo que le queda tras los de la principal; para guardar la
        # misma relacion que con una, mas tajos 7 golpes con la 2a al 53 % y hoja fina 4 con la 2a al 40 %.
        ("mas_tajos", 2, [], ["hoja_fina"], "Más tajos",
         "El brazo no para: caen más tajos, aunque ninguno entra hondo.",
         {"golpes_min": ("add", 1), "golpes_max": ("add", 1), "golpes_dual_min": ("add", 2), "golpes_dual_max": ("add", 2),
          "dual_golpe_mult": ("set", 1.6 / 3.0), "golpes_extra_por_enemigo": ("mult", 1.25 / 0.75),
          "golpes_extra_por_enemigo_dual": ("set", 3.0), "golpes_extra_max": ("set", 12),
          "dano_mult": ("mult", 0.75), "potencia": (P, 0.75), "potencia_coste": (P, 1.0)}),
        ("hoja_fina", 2, [], ["mas_tajos"], "Hoja fina",
         "Menos tajos, pero cada uno entra hasta el hueso.",
         {"golpes_min": ("add", -1), "golpes_max": ("add", -1), "golpes_dual_min": ("add", -1), "golpes_dual_max": ("add", -1),
          "dual_golpe_mult": ("set", 0.4), "golpes_extra_por_enemigo": ("set", 0.5),
          "golpes_extra_por_enemigo_dual": ("set", 1.0),
          "dano_mult": ("mult", 1.8), "potencia": (P, 0.75), "potencia_coste": (P, 1.0)}),
        # Nv3, lado de los muchos tajos
        ("remolino", 3, ["mas_tajos"], ["brazo_largo"], "Remolino",
         "Giras sobre ti mismo y la hoja pasa por todo lo que te rodea.",
         {"forma_apertura": ("set", 360.0), "potencia": (P, 0.5), "potencia_coste": (P, 1.0)}),
        ("brazo_largo", 3, ["mas_tajos"], ["remolino"], "Brazo largo",
         "Estiras el brazo y alcanzas a los que se creían a salvo detrás.",
         {"forma_radio": ("add", 20.0), "potencia": (P, 0.75), "potencia_coste": (P, 1.0)}),
        # Nv3, lado de la hoja fina
        ("mil_cortes", 3, ["hoja_fina"], ["entrar_bailando"], "Mil cortes",
         "Cortes que no matan, pero que no dejan de sangrar.",
         {"efectos_prob_mult": ("set", 0.38 / 0.22), "potencia": (P, 0.625), "potencia_coste": (P, 1.0)}),
        ("entrar_bailando", 3, ["hoja_fina"], ["mil_cortes"], "Entrar bailando",
         "No esperas a que se acerquen: entras tú.",
         {"acercarse": ("add", 60.0), "potencia": (P, 0.75), "potencia_coste": (P, 1.0)}),
        # Nv4, cada uno en su lado
        ("persiguen", 4, ["remolino", "brazo_largo"], [], "Tajos que persiguen",
         "Cuando uno cae, la hoja ya va hacia el siguiente, y con más ganas.",
         {"bonus_por_baja": ("set", 0.15), "potencia": (P, 0.75), "potencia_coste": (P, 1.0)}),
        ("remate", 4, ["mil_cortes", "entrar_bailando"], [], "Remate",
         "El último tajo busca la herida que abrieron los primeros.",
         {"remate_estado": ("set", SANGRADO), "remate_mult": ("set", 2.0), "potencia": (P, 0.625), "potencia_coste": (P, 1.0)}),
        # Nv5: se llega desde cualquiera de los dos lados
        ("frenesi", 5, ["persiguen", "remate"], ["ligera"], "Frenesí",
         "Acabas una ráfaga y el brazo ya pide la siguiente.",
         {"cooldown": ("add", -1), "potencia": (P, 0.375), "potencia_coste": (P, 1.0)}),
        ("ligera", 5, ["persiguen", "remate"], ["frenesi"], "Ráfaga ligera",
         "Menos fuerza en cada tajo y menos aliento en cada ráfaga.",
         {"potencia": (P, 0.625), "potencia_coste": (P, 0.375)}),
    ],
    # PUÑALADA CERTERA (24/11): base 240 %, un tajo (dos con dos dagas), sangrado 55 % y 2a herida si critea 30 %.
    "punalada": [
        # Nv2: critico o sangre
        ("punto_debil", 2, [], ["herida_abierta"], "Punto débil",
         "Sabes dónde mirar antes de clavar.",
         {"crit_extra": ("add", 0.2), "potencia": (P, 0.5), "potencia_coste": (P, 1.0)}),
        ("herida_abierta", 2, [], ["punto_debil"], "Herida abierta",
         "La hoja no sale limpia: sale arrastrando.",
         {"efectos_prob_mult": ("set", 1.651), "potencia": (P, 0.5), "potencia_coste": (P, 1.0)}),
        # Nv3, lado del critico
        ("hasta_el_mango", 3, ["punto_debil"], ["por_la_espalda"], "Hasta el mango",
         "Cuando entra bien, no te paras a medias.",
         {"crit_dano_mult": ("set", 1.3), "potencia": (P, 0.625), "potencia_coste": (P, 1.0)}),
        ("por_la_espalda", 3, ["punto_debil"], ["hasta_el_mango"], "Por la espalda",
         "Donde no mira, no se defiende.",
         {"extra_espalda": ("add", 0.3), "potencia": (P, 0.625), "potencia_coste": (P, 1.0)}),
        # Nv3, lado de la sangre (Arteria -> Desangrar, el combo del jefe)
        ("arteria", 3, ["herida_abierta"], ["mano_segura"], "Arteria",
         "Buscas la vena gorda, la que no para.",
         {"efectos_cargas_extra": ("set", 1), "potencia": (P, 0.625), "potencia_coste": (P, 1.0)}),
        ("mano_segura", 3, ["herida_abierta"], ["arteria"], "Mano segura",
         "Ni rápida ni bonita: segura.",
         {"infalible": ("set", True), "potencia": (P, 0.25), "potencia_coste": (P, 1.0)}),
        # Nv4: desde cualquiera de los cuatro del nivel 3
        ("asesinato", 4, ["hasta_el_mango", "por_la_espalda", "arteria", "mano_segura"], ["desangrar"], "Asesinato",
         "A los que ya se tambalean no les das tiempo a levantarse.",
         {"bonus_vida_baja": ("set", 0.4), "potencia": (P, 0.75), "potencia_coste": (P, 1.0)}),
        ("desangrar", 4, ["hasta_el_mango", "por_la_espalda", "arteria", "mano_segura"], ["asesinato"], "Desangrar",
         "Abres lo que ya estaba abierto, y sale todo de una vez.",
         {"detona_estado": ("set", SANGRADO), "potencia": (P, 0.5), "potencia_coste": (P, 1.0)}),
        # Nv5: desde cualquiera de los dos del nivel 4
        ("ejecucion", 5, ["asesinato", "desangrar"], ["golpe_y_fuera"], "Ejecución",
         "Uno menos, y la mano ya está lista para el siguiente.",
         {"recarga_al_matar": ("set", True), "potencia": (P, 0.5), "potencia_coste": (P, 1.0)}),
        ("golpe_y_fuera", 5, ["asesinato", "desangrar"], ["ejecucion"], "Golpe y fuera",
         "Clavas, sueltas y ya no estás.",
         {"se_aparta": ("add", 40.0), "potencia": (P, 0.875), "potencia_coste": (P, 1.0)}),
    ],
}


def _valor(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return repr(round(v, 6))
    return '"%s"' % v


def _cambios(c: dict) -> str:
    return "{" + ", ".join('"%s": ["%s", %s]' % (k, op, _valor(v)) for k, (op, v) in c.items()) + "}"


def _nombres(xs) -> str:
    return "Array[StringName]([%s])" % ", ".join('&"%s"' % x for x in xs)


def _sub(clave: str, n) -> tuple:
    nid, nivel, padres, excluye, nombre, sabor, cambios = n
    sid = "NM_%s_%s" % (clave[:3], nid)
    txt = "\n".join([
        '[sub_resource type="Resource" id="%s"]' % sid,
        'script = ExtResource("nodo_mejora")',
        'id = &"%s"' % nid,
        'nombre = "%s"' % nombre,
        'descripcion = "%s"' % sabor,
        "padres = " + _nombres(padres),
        "excluye = " + _nombres(excluye),
        "nivel_min = %d" % nivel,
        "dominio = %d" % (DOMINIO_POR_NIVEL * (nivel - 1)),
        "oro = %d" % ORO_POR_NIVEL.get(nivel, 0),
        "cambios = " + _cambios(cambios),
    ])
    return sid, txt


def escribir(clave: str) -> None:
    ruta = RAIZ / "resources" / "abilities" / (clave + ".tres")
    t = ruta.read_text(encoding="utf-8")
    # Fuera los nodos viejos (cada bloque [sub_resource ... id="NM_..."] hasta el siguiente '[').
    t = re.sub(r'\[sub_resource type="Resource" id="NM_[^"]*"\]\n(?:[^\[\n].*\n|\n)*', "", t)
    # Fuera la linea del arbol y los comentarios ';' justo encima.
    t = re.sub(r"(?m)^(?:;[^\n]*\n)*arbol = \[[^\n]*\]\n", "", t)
    if 'id="nodo_mejora"' not in t:
        t = t.replace("\n\n[sub_resource", '\n\n[ext_resource type="Script" path="res://scripts/items/nodo_mejora.gd" '
                      'id="nodo_mejora"]\n\n[sub_resource', 1)
    subs = [_sub(clave, n) for n in ARBOLES[clave]]
    bloque = "".join(s[1] + "\n\n" for s in subs)
    i = t.index("[resource]")
    t = t[:i] + bloque + t[i:]
    linea = ("; EL ARBOL (24/11, cerrado con el jefe): lo escribe tools/arboles_habilidades.py, no tocarlo a mano.\n"
             "arbol = [" + ", ".join('SubResource("%s")' % s[0] for s in subs) + "]\n")
    t = t.rstrip("\n") + "\n" + linea
    t = re.sub(r"\n{3,}", "\n\n", t)
    with open(ruta, "w", encoding="utf-8", newline="\n") as f:
        f.write(t)
    print("%s: %d nodos" % (ruta.relative_to(RAIZ), len(subs)))


if __name__ == "__main__":
    for clave in (sys.argv[1:] or list(ARBOLES)):
        escribir(clave)
