---
name: publicar-sitio
description: Publica en Netlify los cambios acumulados del sitio de Tierra Métrica (tierrametrica.com) — valida, confirma en local, hace push y verifica que el sitio en vivo realmente se actualizó. Úsalo siempre que el usuario diga que quiere subir, publicar, desplegar o cargar los cambios al servidor, al hosting o a Netlify, o que pida "actualizar el sitio en línea", aunque no nombre Netlify ni Git. Úsalo también cuando el usuario dé por terminada una tanda de cambios en la web y pregunte qué falta para que se vean publicados.
---

# Publicar el sitio de Tierra Métrica

Este sitio se despliega por **push a `main`**: GitHub `HugoTierraMetrica/tierrametrica-web`
está enlazado a Netlify con despliegue continuo. No hay CLI de Netlify ni `gh`
en este entorno — el push *es* el despliegue. Node y Python sí están
disponibles (desde 2026-08-18), pero no intervienen aquí: el sitio no tiene
build y Netlify se dispara solo con el push.

Invocar este skill cuenta como la autorización para publicar. No hace falta
volver a preguntar si se sube o no. Lo que sí se detiene sin excepción es un
push con validaciones en rojo: publicar markup roto cuesta otro despliegue para
arreglarlo, y el objetivo de todo este flujo es que cada despliegue valga la
pena.

## Por qué existe este flujo

Netlify avisó al usuario de su consumo de créditos. La causa fue clara en el
historial: quince commits en veinticuatro horas, cada uno empujado, y **cada
push a `main` dispara una construcción**. La mayoría eran ajustes de una línea
de texto.

De ahí la regla que gobierna todo: **se trabaja con commits locales y se agrupa
todo en un solo despliegue**. Este skill es ese momento de agrupar.

## Los cuatro pasos

### 1. Validar

```powershell
powershell -ExecutionPolicy Bypass -File .claude\skills\publicar-sitio\scripts\validar.ps1
```

Revisa lo que se ha roto antes en este proyecto: JSON-LD mal formado (que se
ignora en silencio, el modo de fallo más caro), enlaces internos rotos,
referencias `@id` huérfanas, páginas sin title/canonical/description, más de un
`h1`, desajustes entre el sitemap y las canónicas, y documentos de cliente
colados en un repositorio que es **público**.

Si sale con código 1, **para ahí**: arregla lo señalado, o dile al usuario qué
encontraste si la decisión es suya. Los avisos no bloquean, pero conviene
mencionarlos.

Cuando el cambio toque el diseño y no solo el texto, vale la pena además abrir
la página y medir el DOM. El panel del navegador de este entorno es inestable
—se queda cargando otra pestaña, deja de componer imagen, reporta el viewport en
cero—; si las mediciones salen absurdas, dilo en vez de dar por buena una
verificación que no ocurrió.

### 2. Confirmar en local lo que falte

```powershell
git status --porcelain
```

Si hay cambios sin confirmar, revisa `git diff` antes de agregarlos: ha servido
para atrapar ediciones accidentales. Agrúpalos en commits por tema, no uno por
archivo.

**Los mensajes de commit no pueden llevar comillas dobles.** PowerShell 5.1
parte el argumento al pasárselo a `git` y el commit falla con un `pathspec`
extrañísimo. Usa comillas angulares o ninguna. El formato que funciona:

```powershell
git commit -m @'
Titulo en imperativo, sin punto final

Que cambio y por que. El por que importa mas que el que:
el diff ya dice que cambio.
'@
```

### 3. Empujar

```powershell
git log --oneline origin/main..HEAD
git push origin main
```

Enseña primero los commits que van a salir — el usuario debe poder ver qué
compró con este despliegue.

Si en algún momento hace falta subir al remoto **sin** desplegar (por respaldo,
por ejemplo), `[skip ci]` en el mensaje del commit hace que Netlify omita la
construcción.

### 4. Verificar en vivo

Este paso no es opcional, y es la lección más cara de este proyecto: **que el
push llegue a GitHub no prueba que Netlify haya construido**. Una vez los ocho
commits llegaron al remoto y el sitio siguió sirviendo la versión anterior
durante horas, porque los créditos estaban agotados. Se reportó como publicado
sin serlo.

Verifica con `Invoke-WebRequest`, no con WebFetch: WebFetch cachea quince
minutos por URL y puede devolverte la versión vieja justo después de desplegar.

```powershell
$html = (Invoke-WebRequest -Uri "https://tierrametrica.com/" -UseBasicParsing -TimeoutSec 25).Content
$html -match 'algo que solo exista en la version nueva'
```

Elige como sonda **una cadena de texto que solo aparezca en lo que acabas de
publicar**. Si no la encuentras, Netlify no ha terminado o no construyó: espera
y reintenta antes de dar nada por bueno.

Comprueba también que respondan 200 los archivos nuevos y las imágenes que hayas
tocado:

```powershell
foreach ($u in @('robots.txt','sitemap.xml')) {
  $r = Invoke-WebRequest -Uri "https://tierrametrica.com/$u" -Method Head -UseBasicParsing
  "{0}  {1}  {2}" -f $u, $r.StatusCode, $r.Headers['Content-Type']
}
```

Si la construcción no arranca, se relanza desde el panel de Netlify en
**Deploys → Trigger deploy**, sin gastar un commit vacío. Eso lo hace el
usuario; no hay forma de dispararlo desde aquí.

## Qué reportar al final

Di qué quedó publicado y **qué comprobaste de verdad**, separando lo verificado
de lo que no. Si el panel del navegador no compuso imagen, o no pudiste ver una
página renderizada, dilo: es información que el usuario necesita para saber qué
le toca revisar a él.

Cuando el despliegue toque el formulario de suscripción, recuérdaselo: Netlify
reprocesa los formularios en cada construcción, y la prueba de treinta segundos
—suscribirse con un correo propio— descarta sorpresas.

## Cosas del proyecto que conviene no olvidar

- **El repositorio es público**, por decisión explícita del usuario. Nunca deben
  entrar ahí avalúos, contratos ni documentos de clientes: quedarían en el
  historial de forma permanente, y borrarlos después no los quita del historial.
- Las fotografías originales de campo viven en `assets/fotos/` pero están
  excluidas en `.gitignore`; solo se versionan las copias recortadas y
  optimizadas que el sitio sirve.
- `styles.css` y `site.js` no llevan hash en el nombre, así que `netlify.toml`
  les deja a propósito la caché corta. No cambiar eso sin renombrarlos.
- El usuario trabaja en español. Los mensajes de commit y los reportes van en
  español.
