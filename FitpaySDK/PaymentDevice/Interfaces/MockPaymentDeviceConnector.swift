//
//  MockPaymentDeviceConnector.swift
//  FitpaySDK
//
//  Created by Tim Shanahan on 5/6/16.
//  Copyright © 2016 Fitpay. All rights reserved.
//

public enum TestingType: UInt64 {
    case partialSimulationMode = 0xBADC0FFEE000
    case fullSimulationMode    = 0xDEADBEEF0000
}

open class MockPaymentDeviceConnector : NSObject, IPaymentDeviceConnector {
    weak var paymentDevice : PaymentDevice!
    var responseData : ApduResultMessage!
    var connected = false
    var _nfcState = SecurityNFCState.disabled
    var sendingAPDU : Bool = false
    let maxPacketSize : Int = 20
    let apduSecsTimeout : Double = 5
    var sequenceId: UInt16 = 0
    var testingType: TestingType
    var connectDelayTime: Double = 4 
    var disconnectDelayTime: Double = 4
    var apduExecuteDelayTime: Double = 0.5

    var timeoutTimer : Timer?
    
    required public init(paymentDevice device:PaymentDevice, testingType: TestingType = .fullSimulationMode) {
        self.paymentDevice = device
        self.testingType = testingType
    }
    
    open func connect() {
        log.verbose("connecting")
        DispatchQueue.main.asyncAfter(deadline: .now() + connectDelayTime, execute: {
            self.connected = true
            self._nfcState = SecurityNFCState.enabled
            let deviceInfo = self.deviceInfo()
            log.verbose("triggering device data")
            self.paymentDevice?.callCompletionForEvent(PaymentDeviceEventTypes.onDeviceConnected, params: ["deviceInfo": deviceInfo!])
            self.paymentDevice?.connectionState = ConnectionState.connected
        })
    }
    
    open func disconnect() {
        DispatchQueue.main.asyncAfter(deadline: .now() + disconnectDelayTime, execute: {
            self.connected = false
            self.paymentDevice?.callCompletionForEvent(PaymentDeviceEventTypes.onDeviceDisconnected)
            self.paymentDevice?.connectionState = ConnectionState.disconnected
        })
    }
    
    open func isConnected() -> Bool {
        log.verbose("checking is connected")
        return connected
    }
    
    open func validateConnection(completion: @escaping (Bool, NSError?) -> Void) {
        completion(isConnected(), nil)
    }
    
    
    open func executeAPDUCommand(_ apduCommand: APDUCommand) {
        guard let commandData = apduCommand.command?.hexToData() else {
            if let completion = self.paymentDevice.apduResponseHandler {
                completion(nil, nil, NSError.error(code: PaymentDevice.ErrorCode.apduDataNotFull, domain: IPaymentDeviceConnector.self))
            }
            return
        }
        
        sendAPDUData(commandData as Data, sequenceNumber: UInt16(apduCommand.sequence))
    }
    
    open func sendAPDUData(_ data: Data, sequenceNumber: UInt16) {
        let response = "9000"
        let packet = ApduResultMessage(hexResult: response)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + apduExecuteDelayTime) {
            if let apduResponseHandler = self.paymentDevice.apduResponseHandler {
                self.paymentDevice.apduResponseHandler = nil
                apduResponseHandler(packet, nil, nil)
            }
        }
    }
    
    
    open func deviceInfo() -> DeviceInfo? {
        let deviceInfo = DeviceInfo()
        
        deviceInfo.deviceType = "WATCH"
        deviceInfo.manufacturerName = "Fitpay"
        deviceInfo.deviceName = "PSPS"
        deviceInfo.serialNumber = "074DCC022E14"
        deviceInfo.modelNumber = "FB404"
        deviceInfo.hardwareRevision = "1.0.0.0"
        deviceInfo.firmwareRevision = "1030.6408.1309.0001"
        deviceInfo.softwareRevision = "2.0.242009.6"
        deviceInfo.systemId = "0x123456FFFE9ABCDE"
        deviceInfo.osName = "IOS"
        deviceInfo.licenseKey = "6b413f37-90a9-47ed-962d-80e6a3528036"
        deviceInfo.bdAddress = "977214bf-d038-4077-bdf8-226b17d5958d"
        deviceInfo.secureElementId = self.generateRandomSeId()
        deviceInfo.casd = "7F218201097F218201049310201608231634158F370493B60000000342038949325F200C434552542E434153442E43549501825F2504201607015F240420210701450CA000000151535043415344005314C0AC3B49223485BE2FCFECBC19CFE14CE01CD9795F378180C0F41E9813FDC0C4522AA72CA6DDFFCFEE5432A01D7FDCF37246C23B138C2C7E5F91431E7E445932A812E0473A713919E594002E257311E67A324F130CA56EDF13FE36616C6EDE85437F30450ADA2549122C0C879B1BF55D1C83FEC7F8AB5CC45DE3A36110226F1A7DC35D86B39445EBBC9325C2F7FDF79FA0410DF55074ABE25F3822905ACD4030B40F9B8BAF35678C439EB7F6862D198BE58CFB053F6BE4A3ECAE148D05"

        return deviceInfo;
    }

    open func resetToDefaultState() {
        
    }

    func generateRandomSeId() -> String {
        return  testingType.rawValue.hex(preferableLength: 12) +
                "528704504258" +
                UInt64(Date().timeIntervalSince1970).hex(preferableLength: 12) +
                "FFFF427208236250082462502041FFFF082562502041FFFF"
    }
    
}

