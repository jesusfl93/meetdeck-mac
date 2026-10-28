# MeetDeck 🎛️

Controla **Google Meet** y el **audio de tu Mac** desde un Stream Deck: silencia el mic, apaga la cámara y cambia entre audífonos y bocinas con un botón. Los iconos muestran el estado real de la reunión.

> ⚠️ **Solo macOS.** Usa AppleScript, CoreAudio y Google Chrome. No funciona en Windows.

```
Carpeta MEET en un Stream Deck Mini
┌──────────┬────────┬─────────┐
│ ← atrás  │  🎙 MIC │ 🎧 HEAD │
├──────────┼────────┼─────────┤
│ IR A MEET│ 📷 CAM  │ 🔊 MAC  │
└──────────┴────────┴─────────┘
```

## Capacidades

| Botón | Qué hace | Estado en el icono |
| --- | --- | --- |
| **Mic** (plugin) | Activa o silencia el micrófono en Meet | 🔵 abierto · 🔴 línea roja = silenciado · ⚪ sin reunión |
| **Cámara** (plugin) | Enciende o apaga la cámara en Meet | 🔵 encendida · 🔴 línea roja = apagada · ⚪ sin reunión |
| **Headset** | Cambia la salida y el micrófono del sistema al headset | — |
| **Bocinas** | Cambia la salida y el micrófono del sistema a los de la Mac | — |
| **Ir a Meet** | Trae la reunión al frente, aunque esté en otro escritorio | — |
| **Mano** | Levanta o baja la mano (Ctrl+⌘H) | — |
| **Chat** | Abre o cierra el chat (Ctrl+⌘C) | — |

- Mic y Cámara **no cambian el foco**: hacen clic en el botón de Meet sin sacarte de la app donde estás.
- Funcionan con Meet en una **pestaña de Chrome** (aunque no sea la activa) o como **app instalada de Chrome (PWA)**.
- Si no hay reunión abierta, no hacen nada: muestran un aviso y nunca envían teclas a otra ventana.
- Si un dispositivo de audio no está conectado, no se cambia nada y aparece una notificación.
- Sin dependencias externas: solo lo que trae macOS, las Command Line Tools de Xcode y la app Stream Deck.

## Requisitos

| Requisito | Cómo verificarlo |
| --- | --- |
| macOS 12 o superior (probado en macOS 26, Apple Silicon) | ` → Acerca de esta Mac` |
| Un Stream Deck (cualquier modelo) y la app **Stream Deck 6.5+** de Elgato | Menú del Stream Deck → *About* |
| **Command Line Tools de Xcode** (`swift` y `swiftc`) | `swiftc --version`; si falla: `xcode-select --install` |
| **Google Chrome** con Meet en una pestaña o instalado como app | — |
| Meet en **español o inglés** (los botones se detectan por su nombre) | Configuración de la cuenta de Google |

## Instalación paso a paso

### 1. Clonar el repo

```bash
git clone https://github.com/jesusfl93/meetdeck-mac.git
cd meetdeck-mac
```

### 2. Configurar tus dispositivos de audio

Compila la herramienta de audio y lista tus dispositivos:

```bash
mkdir -p build && swiftc -O -o build/audioswitch tools/audioswitch.swift
build/audioswitch list
```

```
G535 Wireless Gaming Headset   OUT* in      ← * = el que está activo
MacBook Air Microphone         IN*
MacBook Air Speakers           out
```

Edita los nombres en estos dos archivos. Basta con una parte del nombre, por ejemplo `"G535"`:

- `src/AudioHeadset.applescript` → `switchAudio("🎧 Headset G535", "<salida>", "<micrófono>")`
- `src/AudioSpeakers.applescript` → `switchAudio("🔊 Bocinas de la Mac", "<salida>", "<micrófono>")`

Si no quieres que el botón cambie el micrófono, usa `""` como tercer valor.

### 3. Compilar e instalar las mini-apps

```bash
./build.sh
```

Genera los iconos, compila cada botón como una app y las instala en `~/Applications/StreamDeckMeet/`. Se puede correr varias veces sin problema.

### 4. Instalar el plugin de Stream Deck

```bash
./install_plugin.sh
```

La primera vez, **cierra y vuelve a abrir la app Stream Deck** (icono de la barra de menús → *Quit*). En la lista de acciones aparecerá la categoría **Meet**, con *Mic de Meet* y *Cámara de Meet*.

### 5. Permitir JavaScript en Chrome

El plugin lee y controla Meet ejecutando JavaScript en la pestaña de la reunión.

1. Abre una ventana normal de Chrome con el **perfil donde usas Meet**.
2. En la **barra de menús de macOS** (no en el menú ⋮): **View → Developer → Allow JavaScript from Apple Events** (en español: *Ver → Opciones para desarrolladores → Permitir JavaScript desde Apple Events*).

> 🔐 Con esto, cualquier app a la que des permiso de *Automatización* sobre Chrome puede ejecutar JavaScript en tus pestañas. Concede ese permiso solo a apps de confianza.

### 6. Dar permisos de macOS

| Permiso | Para qué | Dónde |
| --- | --- | --- |
| **Accesibilidad** | Que MeetHand, MeetChat y el respaldo de Mic/Cámara puedan enviar atajos de teclado | Ajustes del Sistema → Privacidad y seguridad → Accesibilidad → **+** → presiona **⌘⇧G**, pega `~/Applications/StreamDeckMeet` y agrega `MeetMic`, `MeetCam`, `MeetHand` y `MeetChat` |
| **Automatización** | Que el plugin y las apps controlen Chrome y System Events | macOS lo pregunta la primera vez que presionas cada botón. Responde **Permitir** |
| **Notificaciones** | Ver avisos como "No hay reunión" o "Audio sin cambios" | Se pide la primera vez; también en Ajustes → Notificaciones |

> El buscador del diálogo de Accesibilidad no encuentra las apps porque Spotlight no indexa `~/Applications`. Usa **⌘⇧G**.

### 7. Configurar los botones en el Stream Deck

Sugerencia: crea una carpeta **MEET** en tu perfil.

1. Arrastra **Navigation → Create Folder** a un botón, ponle el icono `icons/MeetFolder.png` y ábrelo.
2. Arrastra a sus botones:
   - **Meet → Mic de Meet** y **Meet → Cámara de Meet**. El icono es automático; no cambies la imagen.
   - **System → Open Application** para cada una de estas apps de `~/Applications/StreamDeckMeet/`: `AudioHeadset.app`, `AudioSpeakers.app`, `MeetFocus.app`, y si quieres `MeetHand.app` y `MeetChat.app`.
3. A cada *Open Application*, asígnale su icono de `icons/` (clic en la imagen del botón → *Set from File*).

### 8. Probar

1. Entra a una reunión de prueba ([meet.new](https://meet.new)).
2. Abre la carpeta MEET. Los iconos de Mic y Cámara deben pasar de gris a azul o rojo.
3. Silénciate desde Meet: el icono del Stream Deck debe cambiar en 1 o 2 segundos.
4. Presiona **Mic** y **Cámara** desde otra app: deben cambiar en Meet sin que cambie la ventana activa.
5. Presiona **Headset** y **Bocinas**: debe aparecer una notificación y el audio debe cambiar.

> En Meet → Configuración → Audio, deja **"Predeterminado del sistema"**. Si eliges un dispositivo fijo ahí, los botones de audio no afectan la reunión.

## Solución de problemas

| Síntoma | Causa y solución |
| --- | --- |
| Mic/Cámara siempre en gris | Chrome no permite JavaScript (paso 5) o no aceptaste "Stream Deck quiere controlar Google Chrome". Revisa el log del plugin (abajo). |
| "MeetMic is not allowed to send keystrokes" | Falta el permiso de Accesibilidad (paso 6). |
| La cámara abre otra cosa (por ejemplo, el panel de una extensión) | Solo pasa con el respaldo por atajo (⌘E): alguna extensión usa ese atajo. Activa el paso 5 para que el plugin haga clic directo, o cambia el atajo en `chrome://extensions/shortcuts`. |
| "Audio sin cambios" | El dispositivo no está conectado o el nombre no coincide. Revisa con `build/audioswitch list` y el paso 2. |
| No aparece la categoría Meet en el Stream Deck | Reinicia la app Stream Deck después de `./install_plugin.sh`. |
| Los botones dejaron de funcionar después de recompilar | macOS invalida el permiso de Accesibilidad. Mira [Actualizar](#actualizar-o-recompilar). |
| Meet como app (PWA) no se detecta | Revisa su bundle id con `osascript -e 'id of app "Meet"'` y ajusta `MEET_PWA_ID` en `src/lib/meet_common.applescript`. |

**Log del plugin:** `~/Library/Application Support/com.elgato.StreamDeck/Plugins/com.fluentdata.meet.sdPlugin/plugin.log`

## Actualizar o recompilar

```bash
git pull
./build.sh            # o solo una: ./build.sh AudioHeadset
./install_plugin.sh   # reinicia el plugin solo
```

La firma ad hoc cambia en cada build, así que macOS **invalida el permiso de Accesibilidad** de las apps recompiladas. Para cada una:

```bash
tccutil reset Accessibility com.fluentdata.streamdeck.MeetMic   # siempre con bundle id
```

Después, agrégala de nuevo en Accesibilidad. ⚠️ **Nunca** ejecutes `tccutil reset Accessibility` sin bundle id: borra el permiso de **todas** las apps.

Variables opcionales de `build.sh`: `DEST` (carpeta de instalación) y `BUNDLE_PREFIX` (prefijo de los bundle id).

## Desinstalar

```bash
rm -rf ~/Applications/StreamDeckMeet
rm -rf ~/Library/Application\ Support/com.elgato.StreamDeck/Plugins/com.fluentdata.meet.sdPlugin
for n in MeetMic MeetCam MeetHand MeetChat MeetFocus AudioHeadset AudioSpeakers; do
  tccutil reset All com.fluentdata.streamdeck.$n
done
```

Luego reinicia la app Stream Deck y borra los botones.

## Cómo funciona

```
Stream Deck ──► Plugin "Meet Status" (Node del Stream Deck)
                  ├─ cada 1,5 s: osascript → Chrome → JS en la pestaña de Meet → lee data-is-muted
                  └─ al presionar: JS hace clic en el botón de Meet (sin cambiar el foco)
                       └─ si Chrome no permite JS: abre MeetMic.app / MeetCam.app (atajo de teclado)

Stream Deck ──► Open Application ──► MeetX.app (AppleScript)
                  └─ enfoca Meet (PWA o pestaña) → verifica que esté al frente → envía el atajo → regresa a tu app

Stream Deck ──► Open Application ──► AudioX.app (AppleScript)
                  └─ audioswitch (Swift + CoreAudio, dentro de la app) → cambia la salida y el mic del sistema
```

- **Seguridad del atajo:** las apps solo envían teclas si confirman que Meet está al frente, para evitar, por ejemplo, que ⌘D cree un marcador en otra ventana.
- **El plugin no usa npm:** usa el Node 20 que trae la app Stream Deck y un cliente WebSocket mínimo.
- **Iconos:** se generan en tu Mac con SF Symbols (`tools/make_icons.swift`). No se incluyen en el repo porque la licencia de SF Symbols no permite redistribuirlos.

## Estructura

```
├── build.sh                 # compila e instala las mini-apps
├── install_plugin.sh        # instala o actualiza el plugin
├── src/
│   ├── lib/meet_common.applescript    # enfocar Meet + enviar atajos de forma segura
│   ├── lib/audio_common.applescript   # cambiar audio con audioswitch
│   ├── Meet{Mic,Cam,Hand,Chat,Focus}.applescript
│   └── Audio{Headset,Speakers}.applescript      # ← aquí van tus dispositivos
├── plugin/com.fluentdata.meet.sdPlugin/         # plugin con estado (manifest + plugin.js)
└── tools/
    ├── audioswitch.swift    # CLI de CoreAudio: list | current | set --output X --input Y
    └── make_icons.swift     # genera los iconos 144x144
```

## Limitaciones

- Solo macOS y Google Chrome. Safari, Arc y otros navegadores no están probados.
- Meet en español o inglés. Para otro idioma, ajusta las expresiones de `FIND_JS` en `plugin.js`.
- Si Google cambia la interfaz de Meet, la detección de los botones (`data-is-muted` y el `aria-label`) puede dejar de funcionar.
- No hay botón de reacciones: Meet no tiene atajo oficial para eso.

## Licencia

[MIT](LICENSE). Proyecto personal; no está afiliado a Google ni a Elgato.
