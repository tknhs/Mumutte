import CoreAudio
import Foundation

struct AudioInputDevice: Identifiable, Equatable {
    let uid: String
    let name: String
    let volumeScalar: Float?
    let isVolumeSettable: Bool
    let objectID: AudioObjectID

    var id: String { uid }
    var isControllable: Bool { volumeScalar != nil && isVolumeSettable }
}

@MainActor
final class CoreAudioDeviceStore {
    func inputDevices() -> [AudioInputDevice] {
        deviceIDs().compactMap { objectID in
            guard hasInputStream(on: objectID),
                  let uid = stringProperty(kAudioDevicePropertyDeviceUID, on: objectID),
                  let name = stringProperty(kAudioObjectPropertyName, on: objectID) else {
                return nil
            }

            let address = inputVolumeAddress()
            let volume = readVolume(on: objectID, address: address)
            let settable = isPropertySettable(on: objectID, address: address)

            return AudioInputDevice(
                uid: uid,
                name: name,
                volumeScalar: volume,
                isVolumeSettable: settable,
                objectID: objectID
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func setInputVolume(_ value: Float32, on objectID: AudioObjectID) -> OSStatus {
        var address = inputVolumeAddress()
        var volume = value
        return AudioObjectSetPropertyData(
            objectID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<Float32>.size),
            &volume
        )
    }

    private func deviceIDs() -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize) == noErr else {
            return []
        }

        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.stride
        guard count > 0 else { return [] }

        var ids = [AudioObjectID](repeating: kAudioObjectUnknown, count: count)
        let status = ids.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return kAudioHardwareBadObjectError }
            return AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0,
                nil,
                &dataSize,
                baseAddress
            )
        }
        return status == noErr ? ids : []
    }

    private func hasInputStream(on objectID: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        return AudioObjectGetPropertyDataSize(objectID, &address, 0, nil, &dataSize) == noErr && dataSize > 0
    }

    private func stringProperty(_ selector: AudioObjectPropertySelector, on objectID: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, &value)
        guard status == noErr, let value else { return nil }
        return value.takeUnretainedValue() as String
    }

    private func readVolume(on objectID: AudioObjectID, address: AudioObjectPropertyAddress) -> Float? {
        var address = address
        var value: Float32 = 0
        var dataSize = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, &value)
        return status == noErr ? value : nil
    }

    private func isPropertySettable(on objectID: AudioObjectID, address: AudioObjectPropertyAddress) -> Bool {
        var address = address
        var settable = DarwinBoolean(false)
        let status = AudioObjectIsPropertySettable(objectID, &address, &settable)
        return status == noErr && settable.boolValue
    }

    private func inputVolumeAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
    }
}
