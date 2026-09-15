@preconcurrency import AVFoundation
import Darwin
import Foundation

var currentArchitecture: String {
  #if arch(arm64)
    "arm64"
  #elseif arch(x86_64)
    "x86_64"
  #else
    "unknown"
  #endif
}

func sysctlString(_ name: String) -> String? {
  var size = 0
  guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else {
    return nil
  }
  var value = [CChar](repeating: 0, count: size)
  guard sysctlbyname(name, &value, &size, nil, 0) == 0 else {
    return nil
  }
  if value.last == 0 {
    value.removeLast()
  }
  return value.withUnsafeBytes {
    String(decoding: $0, as: UTF8.self)
  }
}

struct MemoryMeasuredValue<Value> {
  let value: Value
  let memory: SelectionMemoryMeasurement
}

func measureSelectionMemory<Value>(
  _ operation: () async throws -> Value
) async throws -> MemoryMeasuredValue<Value> {
  let startingResidentBytes = currentResidentBytes()
  let sampler = Task {
    await sampledPeakResidentBytes(startingAt: startingResidentBytes)
  }

  do {
    let value = try await operation()
    let endingResidentBytes = currentResidentBytes()
    sampler.cancel()
    let sampledPeakResidentBytes = max(
      await sampler.value,
      endingResidentBytes
    )
    return MemoryMeasuredValue(
      value: value,
      memory: SelectionMemoryMeasurement(
        startingResidentBytes: startingResidentBytes,
        sampledPeakResidentBytes: sampledPeakResidentBytes,
        endingResidentBytes: endingResidentBytes,
        peakResidentIncreaseBytes: sampledPeakResidentBytes
          > startingResidentBytes
          ? sampledPeakResidentBytes - startingResidentBytes
          : 0
      )
    )
  } catch {
    sampler.cancel()
    _ = await sampler.value
    throw error
  }
}

func sampledPeakResidentBytes(startingAt initialValue: UInt64) async -> UInt64 {
  var peak = initialValue
  while !Task.isCancelled {
    peak = max(peak, currentResidentBytes())
    do {
      try await Task.sleep(for: .milliseconds(2))
    } catch {
      break
    }
  }
  return max(peak, currentResidentBytes())
}

func currentResidentBytes() -> UInt64 {
  var information = proc_taskinfo()
  let byteCount = proc_pidinfo(
    getpid(),
    PROC_PIDTASKINFO,
    0,
    &information,
    Int32(MemoryLayout<proc_taskinfo>.size)
  )
  guard byteCount == MemoryLayout<proc_taskinfo>.size else {
    return 0
  }
  return information.pti_resident_size
}

func milliseconds(_ duration: Duration) -> Double {
  let components = duration.components
  return Double(components.seconds) * 1_000
    + Double(components.attoseconds) / 1_000_000_000_000_000
}

func median(_ sortedValues: [Double]) -> Double {
  guard !sortedValues.isEmpty else { return 0 }
  let middle = sortedValues.count / 2
  if sortedValues.count.isMultiple(of: 2) {
    let lower = sortedValues[middle - 1]
    let upper = sortedValues[middle]
    return lower + (upper - lower) / 2
  }
  return sortedValues[middle]
}

func medianBytes(_ sortedValues: [UInt64]) -> UInt64 {
  guard !sortedValues.isEmpty else { return 0 }
  let middle = sortedValues.count / 2
  if sortedValues.count.isMultiple(of: 2) {
    let lower = sortedValues[middle - 1]
    let upper = sortedValues[middle]
    return lower + (upper - lower) / 2
  }
  return sortedValues[middle]
}

func fourCharacterCode(_ value: FourCharCode) -> String {
  let bytes: [UInt8] = [
    UInt8((value >> 24) & 0xff),
    UInt8((value >> 16) & 0xff),
    UInt8((value >> 8) & 0xff),
    UInt8(value & 0xff),
  ]
  return String(bytes: bytes, encoding: .ascii) ?? String(value)
}
