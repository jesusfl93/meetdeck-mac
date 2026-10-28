-- Handlers compartidos para las acciones de Google Meet.
-- build.sh concatena este archivo con cada MeetX.applescript antes de compilar.

-- La PWA "Meet" corre como proceso app_mode_loader; se identifica por bundle id.
property MEET_PWA_ID : "com.google.Chrome.app.jkcmcgbhkjkbfmhffmabblckhkdibjkj"
property CHROME_ID : "com.google.Chrome"
property MEET_URL_PATTERN : "meet.google.com/"

on frontAppId()
	try
		tell application "System Events" to set bid to bundle identifier of first application process whose frontmost is true
		if bid is missing value then return ""
		return bid
	on error
		return ""
	end try
end frontAppId

on restoreApp(bid)
	if bid is "" or bid is MEET_PWA_ID then return
	try
		tell application id bid to activate
	end try
end restoreApp

on waitFrontmost(bid)
	repeat 20 times
		if frontAppId() is bid then return true
		delay 0.05
	end repeat
	return false
end waitFrontmost

-- Devuelve el bundle id de la app enfocada, o "" si no hay reunión.
on focusMeet()
	-- 1) PWA instalada (si no está instalada, `is running` falla y se sigue al fallback)
	try
		if application id MEET_PWA_ID is running then
			tell application id MEET_PWA_ID to activate
			if waitFrontmost(MEET_PWA_ID) then return MEET_PWA_ID
		end if
	end try
	-- 2) Fallback: pestaña de Chrome, aunque no sea la activa
	if application id CHROME_ID is running then
		tell application "Google Chrome"
			repeat with w in windows
				set i to 0
				repeat with t in tabs of w
					set i to i + 1
					if URL of t contains MEET_URL_PATTERN then
						set active tab index of w to i
						set index of w to 1
						activate
						if my waitFrontmost(CHROME_ID) then return CHROME_ID
						return ""
					end if
				end repeat
			end repeat
		end tell
	end if
	display notification "No hay una reunión de Meet abierta" with title "Stream Deck"
	return ""
end focusMeet

on meetShortcut(k, mods, returnToPrevious)
	set prev to frontAppId()
	set target to focusMeet()
	if target is "" then return
	delay 0.05
	-- Última verificación: nunca enviar la tecla a otra app (⌘D en Chrome = marcador).
	if frontAppId() is not target then return
	try
		tell application "System Events" to keystroke k using mods
	on error
		display notification "Dale permiso de Accesibilidad a " & (name of current application) & " en Ajustes del Sistema" with title "Stream Deck: falta permiso"
	end try
	if returnToPrevious and prev is not target then
		delay 0.1
		restoreApp(prev)
	end if
end meetShortcut

