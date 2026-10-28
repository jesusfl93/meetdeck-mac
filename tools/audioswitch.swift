// audioswitch: cambia los dispositivos de audio por defecto de macOS con CoreAudio.
//
//   audioswitch list
//   audioswitch current
//   audioswitch set --output "G535" [--input "G535"]
//
// Los nombres se comparan primero exactos y luego por subcadena (sin mayúsculas).
// Códigos de salida: 0 ok, 1 uso incorrecto, 2 dispositivo no encontrado, 3 error de CoreAudio.

import CoreAudio
import Foundation

let system = AudioObjectID(kAudioObjectSystemObject)

func address(_ selector: AudioObjectPropertySelector,
             _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
}

func allDevices() -> [AudioDeviceID] {
    var addr = address(kAudioHardwarePropertyDevices)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr else { return [] }
    var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
    guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }
    return ids
}

func deviceName(_ id: AudioDeviceID) -> String {
    var addr = address(kAudioObjectPropertyName)
    var name: CFString = "" as CFString
    var size = UInt32(MemoryLayout<CFString>.size)
    let status = withUnsafeMutablePointer(to: &name) {
        AudioObjectGetPropertyData(id, &addr, 0, nil, &size, $0)
    }
    return status == noErr ? name as String : ""
}

func channelCount(_ id: AudioDeviceID, _ scope: AudioObjectPropertyScope) -> Int {
    var addr = address(kAudioDevicePropertyStreamConfiguration, scope)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr, size > 0 else { return 0 }
    let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
    defer { raw.deallocate() }
    guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, raw) == noErr else { return 0 }
    let buffers = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
    return buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
}

func defaultDevice(_ selector: AudioObjectPropertySelector) -> AudioDeviceID {
    var addr = address(selector)
    var id = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &id)
    return id
}

func setDefaultDevice(_ selector: AudioObjectPropertySelector, _ id: AudioDeviceID) -> Bool {
    var addr = address(selector)
    var device = id
    return AudioObjectSetPropertyData(system, &addr, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &device) == noErr
}

func findDevice(_ query: String, _ scope: AudioObjectPropertyScope) -> AudioDeviceID? {
    let candidates = allDevices().filter { channelCount($0, scope) > 0 }.map { ($0, deviceName($0)) }
    if let exact = candidates.first(where: { $0.1 == query }) { return exact.0 }
    return candidates.first(where: { $0.1.range(of: query, options: .caseInsensitive) != nil })?.0
}

func fail(_ message: String, _ code: Int32) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(code)
}

let args = Array(CommandLine.arguments.dropFirst())

switch args.first {
case "list":
    let output = defaultDevice(kAudioHardwarePropertyDefaultOutputDevice)
    let input = defaultDevice(kAudioHardwarePropertyDefaultInputDevice)
    for id in allDevices() {
        let outs = channelCount(id, kAudioObjectPropertyScopeOutput)
        let ins = channelCount(id, kAudioObjectPropertyScopeInput)
        var marks: [String] = []
        if outs > 0 { marks.append(id == output ? "OUT*" : "out") }
        if ins > 0 { marks.append(id == input ? "IN*" : "in") }
        print("\(deviceName(id))\t\(marks.joined(separator: " "))")
    }

case "current":
    print("output\t\(deviceName(defaultDevice(kAudioHardwarePropertyDefaultOutputDevice)))")
    print("input\t\(deviceName(defaultDevice(kAudioHardwarePropertyDefaultInputDevice)))")

case "set":
    var outputQuery: String?
    var inputQuery: String?
    var i = 1
    while i < args.count {
        guard i + 1 < args.count else { fail("Falta el valor de \(args[i])", 1) }
        switch args[i] {
        case "--output": outputQuery = args[i + 1]
        case "--input": inputQuery = args[i + 1]
        default: fail("Opción desconocida: \(args[i])", 1)
        }
        i += 2
    }
    guard outputQuery != nil || inputQuery != nil else { fail("Uso: audioswitch set --output NOMBRE [--input NOMBRE]", 1) }

    // Resolver todo antes de cambiar nada: si falta un dispositivo, no se toca ninguno.
    func resolve(_ query: String?, _ scope: AudioObjectPropertyScope, _ label: String) -> AudioDeviceID? {
        guard let query else { return nil }
        guard let id = findDevice(query, scope) else { fail("No se encontró la \(label): \(query)", 2) }
        return id
    }
    let output = resolve(outputQuery, kAudioObjectPropertyScopeOutput, "salida")
    let input = resolve(inputQuery, kAudioObjectPropertyScopeInput, "entrada")

    if let output {
        guard setDefaultDevice(kAudioHardwarePropertyDefaultOutputDevice, output),
              setDefaultDevice(kAudioHardwarePropertyDefaultSystemOutputDevice, output)
        else { fail("CoreAudio rechazó la salida \(deviceName(output))", 3) }
        print("output\t\(deviceName(output))")
    }
    if let input {
        guard setDefaultDevice(kAudioHardwarePropertyDefaultInputDevice, input)
        else { fail("CoreAudio rechazó la entrada \(deviceName(input))", 3) }
        print("input\t\(deviceName(input))")
    }

default:
    fail("Uso: audioswitch list | current | set --output NOMBRE [--input NOMBRE]", 1)
}
