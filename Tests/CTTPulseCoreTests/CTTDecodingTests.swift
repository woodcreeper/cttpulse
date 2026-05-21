import Foundation
import Testing
@testable import CTTPulseCore

@Suite("CTT decoding")
struct CTTDecodingTests {
    @Test("Decodes project device summaries")
    func decodesProjectDeviceSummaries() throws {
        let data = Data("""
        {
          "data": [
            {
              "imei": "352753094012345",
              "deviceType": "flicker_gps_gen2",
              "alias": "Piping Plover A12",
              "latestConnectionAt": "2026-05-20T12:00:00Z",
              "latestLocationAt": "2026-05-20T11:59:30Z",
              "latestBatteryV": 3.91
            }
          ],
          "pagination": {
            "nextCursor": null,
            "hasMore": false
          }
        }
        """.utf8)

        let envelope = try JSONDecoder().decode(ListEnvelope<ProjectDeviceDTO>.self, from: data)

        #expect(envelope.data.count == 1)
        #expect(envelope.data[0].alias == "Piping Plover A12")
        #expect(envelope.data[0].latestBatteryV == 3.91)
        #expect(envelope.pagination.hasMore == false)
    }

    @Test("Decodes stable CTT error envelopes")
    func decodesErrorEnvelope() throws {
        let data = Data("""
        {
          "error": {
            "code": "rate_limited",
            "message": "Rate limit exceeded for the caller's token.",
            "requestId": "req_123"
          }
        }
        """.utf8)

        let envelope = try JSONDecoder().decode(ErrorEnvelope.self, from: data)

        #expect(envelope.error.code == .rateLimited)
        #expect(envelope.error.requestId == "req_123")
    }

    @Test("Decodes sensor battery voltage")
    func decodesSensorBatteryVoltage() throws {
        let data = Data("""
        {
          "data": [
            {
              "imei": "352753094012345",
              "time": "2026-05-20T12:10:00Z",
              "source": "sensor",
              "reason": null,
              "battery_v": 3.72,
              "solarMv": null,
              "solarMa": null,
              "tempC": null,
              "activity": null,
              "actCumulative": null,
              "actX": null,
              "actY": null,
              "actZ": null,
              "polarAct": null
            }
          ],
          "pagination": {
            "nextCursor": null,
            "hasMore": false
          }
        }
        """.utf8)

        let envelope = try JSONDecoder().decode(ListEnvelope<SensorRecordDTO>.self, from: data)

        #expect(envelope.data.count == 1)
        #expect(envelope.data[0].batteryV == 3.72)
    }
}
