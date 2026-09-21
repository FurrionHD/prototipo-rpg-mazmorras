# La nube de los mundos compartidos

Un Worker de Cloudflare con un **Durable Object por mundo** (`src/index.js`). Guarda la contraseña (con
huella), el **cerrojo** (quién tiene el mundo abierto, con arrendamiento de 120 s y token de vallado) y
el **save**, en trozos de 1 MB dentro del propio objeto. Es la misma lógica que
`scripts/net/cloud_store_local.gd`: si cambias una regla aquí, cámbiala allí.

- Dirección: `https://dungeon-oratoria-nube.dungeon-oratoria.workers.dev` (es `Nube.URL_NUBE` en
  `scripts/net/cloud.gd`).
- Cuenta: la de Cloudflare de dasui (plan gratuito). Los Durable Objects son del tipo SQLite, que es
  el que entra en el plan gratuito, y no hace falta R2 (pediría tarjeta).

## Probar en local, sin tocar la nube de verdad

```
cd servidor/nube
npx wrangler dev --port 8787 --ip 127.0.0.1
```

Y el juego contra ese servidor: lanzarlo con `-- nube_url=http://127.0.0.1:8787`. Con `-- nube_local`
usa la carpeta de pruebas (`user://nube_test`), como antes de la nube. **Las pruebas que abran mundos
tienen que llevar una de las dos**; si no, escriben en la nube de verdad.

## Publicar un cambio

```
cd servidor/nube
npx wrangler login     # solo la primera vez en un PC
npx wrangler deploy
```

Ojo con el protocolo: un juego ya repartido habla con el servidor publicado. Si cambias lo que una
operación pide o contesta, que el servidor siga entendiendo al juego viejo, o publica los dos a la vez.
