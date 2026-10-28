-- Handlers compartidos para las acciones de audio.
-- build.sh concatena este archivo con cada AudioX.applescript y copia el binario
-- audioswitch (tools/audioswitch.swift) a Contents/Resources de la app.

on switchAudio(label, outputName, inputName)
	set bin to quoted form of (POSIX path of (path to me) & "Contents/Resources/audioswitch")
	set cmd to bin & " set --output " & quoted form of outputName
	if inputName is not "" then set cmd to cmd & " --input " & quoted form of inputName
	try
		do shell script cmd
		display notification label with title "Audio"
	on error errMsg
		-- Si algún dispositivo no está conectado, audioswitch no cambia nada.
		display notification errMsg with title "Audio sin cambios"
	end try
end switchAudio

