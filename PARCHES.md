# Notas de parche — Dungeon Oratoria

---

# v0.11.1 — «Cada golpe el suyo»

Los enemigos hacían todos sus ataques con la misma animación: la de su golpe estrella. Ahora
cada habilidad se mueve como lo que es. Y el equipo de metal por fin reluce.

---

## ⚔️ Cada habilidad, su gesto

Antes, cuando un bicho usaba una técnica, repetía su ataque de siempre. Salían cosas como
éstas, y ninguna era a propósito:

- La **gárgola** despegaba, se elevaba y se dejaba caer encima… **para mirarte fijamente**.
- El **coloso** estampaba su Pisotón sísmico… **para ponerse un escudo**.
- El **gólem** alzaba los dos puños y machacaba el suelo… **para endurecerse**.
- El **Rey Slime** hacía un placaje entero… **para invocar**.

Las **veintiocho** habilidades que lo necesitaban tienen ahora su propia animación.

**El escarabajo rueda de verdad.** Su Embestida rodante era un dibujo de una bola girando
pintado encima del bicho, que seguía andando debajo. Ahora se hace una bola y rueda.

**El minotauro** deja de hacer la cornada para todo: tiene puñetazo, cornada, pisotón y
bramido, y en el bramido echa la cabeza atrás hasta que el morro apunta al techo.

**El ciempiés se enrosca**, en vez de alzarse y picar.

## 🦴 Y se mueven como bichos

**Brazos y piernas dejan de ser un bloque.** El minotauro, el gólem y el coloso tienen ahora
codo y rodilla de verdad: antes el brazo no doblaba, se combaba entero.

**El gólem ya no se aplana al morir.** Se deshacía como un slime; ahora se parte en terrones y
se viene abajo, que es lo que le pasa a algo hecho de barro cocido.

## ✨ El metal reluce

**Las piezas de metal sueltan un destello que las cruza**, cada diez o veinte segundos. El
brillo sube según lo mejorada que esté la pieza — y el cuero y la madera se quedan mates, que
un peto de cuero reluciente parece de plástico.

**El acero cambia de color.** Antes acababa casi negro, igual que el hierro; ahora va al revés
y termina en **acero espejo**, casi blanco. Así se distinguen de un vistazo: el hierro es el
metal oscuro y el acero el claro.

## 🐛 Arreglos

- El **brillo metálico del equipo no se veía nunca**. Estaba puesto desde hacía versiones, pero
  se encendía solo en piezas ya muy claras y mejorar una pieza la oscurece: justo cuando el
  brillo estaba a tope no quedaba nada que pudiera brillar.
- **Mejorar una armadura la apagaba.** El acabado metálico hundía los tonos oscuros en vez de
  darle rango, así que un peto muy mejorado se veía más apagado que uno recién forjado.
- El **pisotón y el bramido** del minotauro solo se veían según hacia dónde mirase; el resto de
  las veces hacía su embestida.

---

# v0.11.0 — «Se oye»

Hasta ahora solo hacían ruido los enemigos. Ahora suena el juego entero: tus armas, tus
hechizos, la mazmorra y la música.

---

## ⚔️ Tus golpes suenan

**Cada arma tiene su sonido y cada habilidad el suyo.** Las diez armas, sus habilidades, las
magias y la varita. Un mandoble no suena como una daga, y el Grito de guerra no suena como el
Molinete.

**Y no suenan siempre igual.** Donde hay varias grabaciones se sortea una en cada golpe, así
que lanzar tres veces el mismo grito en una pelea no se oye como un disco rayado.

**El arma imbuida chisporrotea.** Fuego, agua y rayo se montan encima del golpe: el mismo tajo
suena distinto según con qué lo hayas cargado.

**También fuera del combate.** Tu espadazo se oye aunque no le des a nada, y el bicho que te
embiste se oye antes de que se abra la pelea.

## 🎵 Música

**Nueve momentos, con varias piezas cada uno**: menú, pueblo, mazmorra, combate, jefe, victoria,
derrota y el golpe de bajar un piso.

**La mazmorra vuelve por donde iba.** Al salir de una pelea no empieza de cero: retoma la pieza
justo donde se quedó, así que se llegan a oír enteras.

**La victoria suena mientras lees el resultado**, no al darle a Continuar.

## 🌒 La mazmorra suena a mazmorra

**Un fondo constante** y, cada tanto, algo suelto: una gota, un hueso, un crujido, algo que
respira muy hondo. Lo que se oye depende del piso.

**El agua se oye al acercarte** al charco, y tu farolillo chisporrotea mientras alumbra.

**En combate se calla**, que ahí ya estás en otro sitio.

## 🔊 Y se oyen todos igual

**Los volúmenes están igualados** uno por uno: ya no hay un golpe que reviente y otro que no se
entere. Los mazazos y los pisotones pesan más que lo demás, a propósito.

**Los golpes de suelo se oyen de verdad.** El Pisotón atronador del minotauro era retumbe puro
y en un altavoz normal no sonaba nada; ahora tiene cuerpo.

**El volumen se puede tocar en mitad de una pelea**, con ESC, sin salir de ella.

## 🐛 Arreglos

- El **Velo umbrío** no se pintaba: la tela salía mal formada y el efecto desaparecía.

---

# v0.10.1 — «Te ves entero»

El personaje era la mitad de grande de lo que pedía su propio dibujo. Ahora mide el doble.

---

## 🧍 El personaje, al doble

**Se ve el doble de grande.** Y no es un zoom: se dibuja con el doble de píxeles, así que lo
que hay es más detalle, no más borroso.

**Con eso, los enemigos vuelven a su sitio.** Una rata medía casi lo mismo que tú y dejaba de
leerse como una alimaña: parecía otro humanoide. Ahora te llega por el tobillo, el slime por
la rodilla y el Rey Slime te saca de ancho.

**Los dos brazos ya son iguales.** Uno salía más gordo que el otro, y al girar parecía cambiar
de brazo. También se ha acabado el de atrás que unas veces era corto y otras largo: quedaba
enterrado dentro del pecho y asomaba un trozo distinto en cada paso.

**El cuerpo va en color carne**, no del color que elegiste. Ese color no se pierde: pasará a
ser el de la ropa cuando la haya. Elegir el tono de piel llegará más adelante.

**Y vuelves a tener tu cara.** Tu imagen se pegó a la cabeza — se te ve de frente y de perfil,
y desaparece cuando andas de espaldas. Desde que el personaje dejó de ser un cuadrado, tu
retrato había dejado de verse en el mapa.

---

## 🚶 Lo que ocupas al andar

Ahora son **dos cosas distintas**, que es como debía haber sido siempre:

- **Contra las paredes chocas con los pies**, no con el cuerpo entero. Por eso la cabeza y los
  hombros pueden pasar por delante de lo que hay detrás, que es lo que hace que el mapa se lea
  con profundidad. Lo que ocupas en el suelo es prácticamente lo de antes: los pasillos se
  cruzan igual.
- **Los golpes te alcanzan en todo el cuerpo.** Eres más alto que ancho, y eso ya cuenta.

> Los compañeros del séquito **se separan más** para no metérsete dentro.

---

# v0.10.0 — «Se apaga la luz»

*74 commits desde la v0.9.6.* La versión más grande hasta ahora: la mazmorra se queda a
oscuras, y de paso deja de estar hecha de cuadrados de colores.

---

## 🔦 La mazmorra está a oscuras

**Ya no ves el piso entero.** Solo ves lo que alguien está iluminando **y** a lo que tienes
línea recta desde donde estás. Son dos condiciones y hacen falta las dos:

- Un compañero al otro lado de un muro **no se ve**, aunque lleve su propio farolillo.
- Un compañero con línea despejada **sí se ve**, aunque tu luz no llegue hasta él — y le ves
  también su corro de luz.

Los enemigos, las vetas y los nombres de los otros jugadores **se apagan** cuando no les
llega luz: no se quedan oscurecidos, desaparecen. Si no, verías flotar los nombres y los
`[F]` a través de la roca y sabrías dónde está todo sin verlo.

**Siempre ves tu corro.** Hay un suelo duro de 3 casillas que no se baja pase lo que pase:
sin farolillo, apagado, sin carbón o con el requisito del piso por las nubes. La oscuridad
puede dejarte casi ciego; ciego del todo, nunca.

> **Los enemigos te siguen detectando igual.** Su oído y su cono de visión no han cambiado:
> ellos te encuentran aunque tú no los veas. Es deliberado — es lo que hace que la oscuridad
> dé miedo.

---

## 🪔 El farolillo

Una **quinta herramienta**, con su ranura propia y su pestaña en el inventario. Como las
otras: no pesa, no ocupa mano y no entra en combate.

**El mismo farolillo alumbra menos cuanto más bajas.** El requisito de luz sube con la
profundidad, así que para recuperar el corro hay que subir de sub-tier, de tier, sacar mejor
tirada en la forja o meterle mejoras.

| farolillo | piso 1 | piso 3 | piso 6 | piso 9 | piso 12 |
|---|---|---|---|---|---|
| sin farolillo | 3.0 | 3.0 | 3.0 | 3.0 | 3.0 |
| T1 común (el del pack) | 7.0 | 6.0 | 5.1 | 4.4 | 3.9 |
| T1 legendario, cobre profundo, +8 | 14.0 | 12.0 | 9.1 | 7.1 | 5.8 |
| T2 común, hierro | 10.9 | 9.1 | 7.1 | 5.8 | 4.9 |

*(en casillas de alcance)*

**Se forja** en el herrero → *Herramientas*, con **metal + hebillas** (no lleva mango: lleva
armazón y un asa).

**Se mejora**, y es la primera herramienta del juego que se puede mejorar. La mejora es *a
secas*: no eliges categoría, cada punto sube la luz. Cuesta **un núcleo de cada rama** — uno
de arma y uno de armadura de su banda (slime+rata, venenoso+rey rata, fuego+jabalí…) — más 2
de metal, y **no escala**: el nivel no encarece nada. Cuántas mejoras admite lo decide su
rareza. Es la única pieza del juego que cruza las dos escaleras de núcleos, y por fin les da
un destino común a los repetidos.

---

## ⚫ El carbón

El farolillo **quema carbón**, y solo dentro de la mazmorra (en el pueblo no consume, y
tampoco mientras tienes un menú abierto).

**Dos formas de conseguirlo:**

- **Picándolo**: vetas negras en la mazmorra, 1-2 por piso, con respawn lento.
- **Quemándolo**: pestaña **Carbonera** nueva en el carpintero. 2 maderas = 1 carbón (frente
  a las 3 del tablón: el carbón es el destino barato de la madera).

Cada madera da su propio carbón, y la escalera tiene **techo a propósito**: el mejor carbón
que puedes *fabricar* se queda por debajo del peor que hay que *bajar a picar*. Si lo
alcanzara, la veta de carbón sobraría y no habría razón para arriesgarse abajo.

| carbón | llama |
|---|---|
| vegetal (madera común) | 2:00 |
| de veta · anillado | 2:30 · 3:00 |
| duro · férreo · petrificado | 3:20 · 3:40 · 4:00 |
| negro (madera negra) — *techo de lo fabricable* | 4:30 |
| **mineral** (se pica abajo) | **5:00** |
| antracita (T2) | ~12:00 |

*(la calidad del trozo lo estira hasta un +50%)*

**El carbón no pesa y no vive en la bolsa.** Tiene su propio sitio, con el farolillo. En la
bolsa se colaba en «guardar materiales en el hogar» y acababa mezclado en el almacén con el
material de forja, y el carbón no es material de oficio: es el consumible de *ver*.

**El pack inicial** ahora trae farolillo y 3 carbones además del arma y las pociones.

---

## 🧱 El mapa deja de ser cuadrados de colores

- **Suelo y paredes con sprites de verdad**, dibujados por código y horneados a PNG.
- **Sin juntas visibles.** La textura es un tapiz continuo de 4×4 baldosas que se trocea, así
  que las uniones son las que ya tenía el dibujo por dentro: ninguna.
- **Musgo por zonas**: hay salas más húmedas que otras, el musgo va a manchas y trepa por la
  roca. La mazmorra se lee como cueva y no como plano.
- **Riachuelos**, con el agua corriendo de verdad. Y una regla: **el agua nunca termina en
  seco** — nace en una pared y acaba en el lago, se mete en otra pared o se cuela por un
  sumidero.
- **Vetas, árboles, matas, sal y huerto**: 4 modelos distintos cada uno, para que tres vetas
  en una sala no se lean como tres copias. El material tiñe solo su parte, no la roca de
  alrededor.
- **Escaleras**: un hueco con peldaños. Subir y bajar se distinguen por hacia dónde va la luz.
- **Puerta al pueblo**: un arco de sillares con la luz colándose por las rendijas. Con la
  mazmorra a oscuras es el único sitio con luz de día, así que se lee como un faro.

---

## 👹 Los enemigos dejan de ser cuadrados

- **Slime, rata, rey rata, jabalí y trent** dibujados: los pisos 1-6 completos.
- Todos vistos desde el **mismo sitio** (cámara a 45°) y con el **mismo tamaño de píxel**,
  que es lo que mantiene coherente el pixel-art.
- La **colisión sale del cuerpo real**, no de una caja de 32×32.
- **Rendimiento**: los sprites se hornean a PNG en disco. Cargarlos son **108 ms** contra los
  **2943** de dibujarlos en cada partida. Y la VRAM baja de **387 MB a 86** recortando el aire
  transparente de cada frame (entre el 62% y el 86% de cada uno era aire).
- **Visores** (`ver_enemigos_*.bat`) para revisar animaciones y ataques sin jugar.

---

## ⚔️ Las armas tienen gesto

Las **diez armas**, el **escudo** y la **varita** tienen animación propia por golpe. Ya no
hay ataques sin dibujo.

- Cada arma pega como lo que es: el hacha muerde, el mandoble atraviesa, la maza revienta, el
  martillo pega al suelo, el estoque va de punta.
- **Un trazo por golpe**, no la habilidad entera de una vez.
- Cada **elemento** se comporta distinto en vez de ser un tinte.
- La **imbuición** se comporta, no tiñe.
- El **contraataque** se ve, y se ve *después*.

---

## 🐺 Y los enemigos pegan a su manera

- **Ningún enemigo se ha quedado sin vestir**: todas sus habilidades tienen efecto propio
  (mordiscos, zarpazos, placajes, ponzoña, telaraña, enrosque, caparazón, muralla…).
- El **Trent** estrena kit propio y el estado **Enraizado** (te corta pegar pero te deja los
  hechizos: el Silencio al revés).
- El **Rey Slime** invoca séquito, y su escudo sube con cada slime vivo.
- Las **áreas** son un efecto grande, no el mismo repetido por cabeza.
- Los **muertos se van de la fila**, y el número deja de cantar la muerte.

---

## 🔊 Sonido

- Sistema de sonido nuevo: bus SFX propio y 12 voces simultáneas.
- **Sonidos de ataque** buscados por habilidad, también los de los enemigos.
- **Tres mandos de volumen** en la pausa: general, efectos y música.

---

## ⚖️ Ritmo y balance

- **Las animaciones duran un 43% más.** Iban tan rápidas que el golpe se resolvía antes de
  que te diera tiempo a leer qué había pasado. Y hay un **botón de x2** arriba a la derecha
  para cuando ya lo has visto: acelera la pelea entera, no solo los dibujos.
- **Jefes**: Rey Slime a 600 de base (≈1035 de vida real, ×11.6 un slime de su piso) y
  Guardián a 1200 (≈3553, ×8.7 un coloso del suyo).
- **Perks de combate**: dos escaleras de rango en vez de una. Los que van por *veces* suben a
  ×1.6 y los que van por *daño* se quedan en ×2.5 (esos ya se aceleran solos al crecer). Los
  umbrales de entrada suben: Reflejos y Erudito 300→1000, Encantamiento rápido 450→1500,
  Cazador 24.000→150.000. Antes se entraba sin enterarte y el rango S pedía 1.144.409 esquivas.
- La **Autorregeneración** deja de ir por daño encajado, que premiaba justo lo contrario de
  lo que se quería.

---

## 🩹 Arreglos

- El carbón de las partidas anteriores se recoge de la bolsa y del almacén al cargar. Antes
  te encontrabas el farolillo diciendo «0 trozos» con tres carbones encima.
- Los núcleos de **jefe** son comodín y eran los únicos de su banda, así que no tenían pareja
  y el último tramo de mejoras del farolillo era imposible — y lo único que se veía era el
  botón en gris. Ahora un comodín hace los dos papeles.
- Los recolectables ya no nacen dentro del riachuelo.
- El **Enraizado** convierte el básico en Pasar, en vez de dejarte sin jugada.
- El aura se cortaba a un tercio de su animación; el caparazón parecía un huevo y la carga
  salía por triplicado.
- El veneno del Filo emponzoñado se pintaba antes de existir.
- Los bancos de prueba `dev_*` salen del repo (se habían colado con un `git add -A`).
- **La versión**: `application/file_version` y `version/name` del export llevaban paradas en
  0.9.3 desde hace varias versiones. Los seis sitios están ahora sincronizados.

---

## 🛠️ Herramientas (para desarrollo)

`hornear_sprites.bat` (sprites a PNG), `ver_enemigos_animaciones.bat`, `ver_enemigos_ataques.bat`,
`ver_gestos.bat`, y en `tools/`: `ver_terreno`, `ver_lampara`, `ver_nucleos`, `probar_vision`,
`comprobar`.

---

## ⏭️ Lo que queda pendiente

- El carbón no se puede guardar en el Cofre todavía (el cofre solo maneja equipo, no pilas de
  material).
- Los tramos de textura de los pisos 7-12 y 13+ reutilizan el de roca hasta que se dibujen.
- Un enemigo visto pegado a una pared sin causa identificada.
