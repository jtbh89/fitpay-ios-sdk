//
//  testHelpers.swift
//  FitpaySDK
//
//  Copyright © 2016 Fitpay. All rights reserved.
//

import XCTest
@testable import FitpaySDK

class TestHelpers {

    let clientId: String!
    let redirectUri: String!
    var session: RestSession!
    var client: RestClient!

    init(clientId:String, redirectUri:String, session:RestSession, client:RestClient) {
        self.clientId = clientId
        self.redirectUri = redirectUri
        self.session = session
        self.client = client
    }

    func userValid(user:User) {
        XCTAssertNotNil(user.info)
        XCTAssertNotNil(user.created)
        XCTAssertNotNil(user.links)
        XCTAssertNotNil(user.createdEpoch)
        XCTAssertNotNil(user.encryptedData)
        XCTAssertNotNil(user.info?.email)
        
    }
    
    func createAndLoginUser(expectation:XCTestExpectation, completion:(User?)->Void) {
        let email = self.randomEmail()
        let pin = "1234" //needs to be a parameter eventually.

        let currentTime = NSDate().timeIntervalSince1970 //double or NSTimeInterval
        
        self.client.createUser(
            email, password: pin, firstName:nil, lastName:nil, birthDate:nil, termsVersion:nil,
            termsAccepted:nil, origin:nil, originAccountCreated:nil, completion:
        {
            [unowned self](user, error) -> Void in

            XCTAssertNil(error)

            if error != nil {
                expectation.fulfill()
                return
            }

            XCTAssertNotNil(user, "user is nil")
            debugPrint("created user: \(user?.info?.email)")
            if (user != nil) { self.userValid(user!) }

            //additional sanity checks that we created a meaningful user
            //PLAT-1388 has a bug on the number of links returned when creating a user. When that gets fixed, reenable this.
            //XCTAssertEqual(user!.links!.count, 4, "Expect the number of links to be at least user, cards, devices") //could change. I'm violating HATEAOS
        
            //because there is such a thing as system clock variance (and I demonstrated it to Jakub), we check +/- 5 minutes.
            let comparisonTime = currentTime - (150) //2.5 minutes.
            let actualTime = user!.createdEpoch! //PGR-551 bug. Drop the /1000.0 when the bug is fixed.
            debugPrint("actualTime created: \(actualTime), expected Time: \(currentTime)")
            XCTAssertGreaterThan(actualTime, comparisonTime, "Want it to be created after the last 2.5 minutes")
            XCTAssertLessThan(actualTime, comparisonTime+300, "Want it to be created no more than the last 2.5 min")
            XCTAssertEqual(user?.email, email, "Want the emails to match up")
            
            self.session.login(username: email, password: pin, completion: {
                (loginError) -> Void in
                XCTAssertNil(loginError)
                debugPrint("user isAuthorized: \(self.session.isAuthorized)")
                XCTAssertTrue(self.session.isAuthorized, "user should be authorized")

                if loginError != nil {
                    expectation.fulfill()
                    return
                }

                self.client.user(id: self.session.userId!) {
                    (user, userError) in

                    XCTAssertNotNil(user)
                    if (user !=  nil) { self.userValid(user!) }
                    XCTAssertEqual(user?.email, email, "Want emails to match up after logging in")
                    
                    XCTAssertNil(userError)
                    if userError != nil {
                        expectation.fulfill()
                        return
                    }

                    completion(user)
                }

            })
        })
    }

    func deleteUser(user:User?, expectation:XCTestExpectation) {
        user?.deleteUser {
                (error) in
                XCTAssertNil(error)
                expectation.fulfill()
        }
    }

    func createDevice(expectation:XCTestExpectation, user:User?, completion:(user:User?, device:DeviceInfo?) -> Void) {
        let deviceType = "WATCH"
        let manufacturerName = "Fitpay"
        let deviceName = "PSPS"
        let serialNumber = "074DCC022E14"
        let modelNumber = "FB404"
        let hardwareRevision = "1.0.0.0"
        let firmwareRevision = "1030.6408.1309.0001"
        let softwareRevision = "2.0.242009.6"
        let systemId = "0x123456FFFE9ABCDE"
        let osName = "ANDROID"
        let licenseKey = "6b413f37-90a9-47ed-962d-80e6a3528036"
        let bdAddress = "977214bf-d038-4077-bdf8-226b17d5958d"
        let secureElementId = "8615b2c7-74c5-43e5-b224-38882060161b"
        let pairing = "2016-02-29T21:42:21.469Z"

        user?.createNewDevice(
            deviceType, manufacturerName: manufacturerName, deviceName: deviceName, serialNumber: serialNumber,
            modelNumber: modelNumber, hardwareRevision: hardwareRevision, firmwareRevision: firmwareRevision,
            softwareRevision: softwareRevision, systemId: systemId, osName: osName, licenseKey: licenseKey,
            bdAddress: bdAddress, secureElementId: secureElementId, pairing: pairing, completion:
        {
            (device, error) -> Void in
            XCTAssertNotNil(user)
            XCTAssertNil(error)
            if error != nil {
                expectation.fulfill()
                return
            }
            completion(user:user, device: device)
        })
    }

    func assetCreditCard(card:CreditCard?) {
        XCTAssertNotNil(card?.links)
        XCTAssertNotNil(card?.creditCardId)
        XCTAssertNotNil(card?.userId)
        XCTAssertNotNil(card?.isDefault)
        XCTAssertNotNil(card?.created)
        XCTAssertNotNil(card?.createdEpoch)
        XCTAssertNotNil(card?.state)
        XCTAssertNotNil(card?.cardType)
        XCTAssertNotNil(card?.cardMetaData)
        XCTAssertNotNil(card?.deviceRelationships)
        XCTAssertNotEqual(card?.deviceRelationships?.count, 0)
        XCTAssertNotNil(card?.encryptedData)
        XCTAssertNotNil(card?.info)
        XCTAssertNotNil(card?.info?.address)
        XCTAssertNotNil(card?.info?.cvv)
        XCTAssertNotNil(card?.info?.expMonth)
        XCTAssertNotNil(card?.info?.expYear)
        XCTAssertNotNil(card?.info?.pan)
    }

    func createEricCard(expectation:XCTestExpectation, pan: String, expMonth: Int, expYear: Int, user: User?, completion:(user:User?, creditCard:CreditCard?) -> Void) {
        user?.createCreditCard(
            pan: pan, expMonth: expMonth, expYear: expYear, cvv: "1234", name: "Eric Peers", street1: "4883 Dakota Blvd.",
            street2: "Ste. #209-A", street3: "underneath a bird's nest", city: "Boulder", state: "CO", postalCode: "80304-1111", country: "USA"
        ) {
            [unowned self](card, error) -> Void in
            debugPrint("creating credit card with \(pan)")
            self.assetCreditCard(card)
            XCTAssertNil(error)
            
            if error != nil {
                expectation.fulfill()
                return
            }
            
            debugPrint("card created")
            completion(user: user, creditCard: card)
        }
    }
    func createCreditCard(expectation:XCTestExpectation, user:User?, completion:(user:User?, creditCard:CreditCard?) -> Void) {
        user?.createCreditCard(
            pan: "9999411111111116", expMonth: 12, expYear: 2016, cvv: "434", name: "Jon Doe", street1: "Street 1",
            street2: "Street 2", street3: "Street 3", city: "Kansas City", state: "MO", postalCode: "66002", country: "USA"
        ) {
            [unowned self](card, error) -> Void in

            self.assetCreditCard(card)
            XCTAssertNil(error)

            if error != nil {
                expectation.fulfill()
                return
            }

            completion(user: user, creditCard: card)
        }
    }

    func listCreditCards(expectation:XCTestExpectation, user:User?, completion:(user:User?, result:ResultCollection<CreditCard>?) -> Void) {
        user?.listCreditCards(excludeState:[], limit: 10, offset: 0) {
            [unowned self](result, error) -> Void in

            XCTAssertNil(error)

            if error != nil {
                expectation.fulfill()
                return
            }

            XCTAssertNotNil(result)
            XCTAssertNotNil(result?.limit)
            XCTAssertNotNil(result?.offset)
            XCTAssertNotNil(result?.totalResults)
            XCTAssertNotNil(result?.results)
            XCTAssertNotEqual(result?.results?.count, 0)
            XCTAssertNotNil(result?.links)

            if let results = result?.results {
                for card in results {
                    self.assetCreditCard(card)
                }
            }

            completion(user: user, result: result)
        }
    }

    func createDefaultDevice(userId: String, completion:RestClient.CreateNewDeviceHandler) {
        let deviceType = "WATCH"
        let manufacturerName = "Fitpay"
        let deviceName = "PSPS"
        let serialNumber = "074DCC022E14"
        let modelNumber = "FB404"
        let hardwareRevision = "1.0.0.0"
        let firmwareRevision = "1030.6408.1309.0001"
        let softwareRevision = "2.0.242009.6"
        let systemId = "0x123456FFFE9ABCDE"
        let osName = "ANDROID"
        let licenseKey = "6b413f37-90a9-47ed-962d-80e6a3528036"
        let bdAddress = "977214bf-d038-4077-bdf8-226b17d5958d"
        let secureElementId = "8615b2c7-74c5-43e5-b224-38882060161b"
        let pairing = "2016-02-29T21:42:21.469Z"

        self.client.user(id:userId, completion: {
            (user, error) -> Void in

            if (error != nil) {
                completion(device: nil, error: error)
                return
            }

            user?.createNewDevice(
                deviceType, manufacturerName: manufacturerName, deviceName: deviceName, serialNumber: serialNumber,
                modelNumber: modelNumber, hardwareRevision: hardwareRevision, firmwareRevision: firmwareRevision,
                softwareRevision: softwareRevision, systemId: systemId, osName: osName, licenseKey: licenseKey,
                bdAddress: bdAddress, secureElementId: secureElementId, pairing: pairing, completion:
            {
                (device, error) -> Void in
                completion(device: device, error: error)
            })
        })
    }

    func acceptTermsForCreditCard(expectation:XCTestExpectation, card:CreditCard?, completion:(card:CreditCard?) -> Void) {
        debugPrint("acceptingTerms for card: \(card)")
        card?.acceptTerms {
            (pending, acceptedCard, error) in
            XCTAssertNil(error)

            if error != nil {
                expectation.fulfill()
                return
            }

            XCTAssertNotNil(acceptedCard)
            if ((acceptedCard?.state != .PENDING_VERIFICATION) && (acceptedCard?.state != .PENDING_ACTIVE)) {
                XCTFail("Need to have a pending verification or active after accepting terms")
            }
            debugPrint("acceptingTerms done")
            completion(card: acceptedCard)

        }
    }

    func selectVerificationType(expectation:XCTestExpectation, card:CreditCard?, completion:(verificationMethod:VerificationMethod?) -> Void) {
        let verificationMethod = card?.verificationMethods?.first

        verificationMethod?.selectVerificationType {
            (pending, verificationMethod, error) in
            XCTAssertNotNil(verificationMethod)
            XCTAssertEqual(verificationMethod?.state, .AWAITING_VERIFICATION)
            XCTAssertNil(error)

            if error != nil {
                expectation.fulfill()
                return
            }

            completion(verificationMethod: verificationMethod)
        }
    }

    func verifyCreditCard(expectation:XCTestExpectation, verificationMethod:VerificationMethod?, completion:(card:CreditCard?) -> Void) {
        verificationMethod?.verify("12345") {
            (pending, verificationMethod, error) -> Void in

            XCTAssertNil(error)

            if error != nil {
                expectation.fulfill()
                return
            }

            XCTAssertNotNil(verificationMethod)
            XCTAssertEqual(verificationMethod?.state, .VERIFIED)

            verificationMethod?.retrieveCreditCard {
                    (creditCard, error) in
                    completion(card: creditCard)
            }
        }
    }

    func makeCreditCardDefault(expectation:XCTestExpectation, card:CreditCard?, completion:(defaultCreditCard:CreditCard?) -> Void) {
        card?.makeDefault {
            (pending, defaultCreditCard, error) -> Void in
            XCTAssertNil(error)

            if error != nil {
                expectation.fulfill()
                return
            }

            XCTAssertNotNil(defaultCreditCard)
            XCTAssertTrue(defaultCreditCard!.isDefault!)
            completion(defaultCreditCard: defaultCreditCard)
        }
    }

    func createAcceptVerifyAmExCreditCard(expectation:XCTestExpectation, pan:String, user:User?, completion:(creditCard:CreditCard?) -> Void) {
        user?.createCreditCard(
            pan: pan, expMonth: 5, expYear: 2020, cvv: "434", name: "John Smith", street1: "Street 1", street2: "Street 2",
            street3: "Street 3", city: "New York", state: "NY", postalCode: "80302", country: "USA"
        ) {
            [unowned self](creditCard, error) in

            XCTAssertNil(error)

            if error != nil {
                expectation.fulfill()
                return
            }

            self.assetCreditCard(creditCard)

            self.acceptTermsForCreditCard(expectation, card: creditCard) {
                (card) in

                self.selectVerificationType(expectation, card: card) {
                    (verificationMethod) in
                    self.verifyCreditCard(expectation, verificationMethod: verificationMethod) {
                        (card) in
                        completion(creditCard: card)
                    }
                }
            }
        }
    }

    func deactivateCreditCard(expectation:XCTestExpectation, creditCard:CreditCard?, completion:(deactivatedCard:CreditCard?) -> Void) {
        debugPrint("deactivateCreditCard")
        creditCard?.deactivate(causedBy: .CARDHOLDER, reason: "lost card") {
            (pending, creditCard, error) in

            XCTAssertNil(error)

            if error != nil {
                expectation.fulfill()
                return
            }

            XCTAssertEqual(creditCard?.state, TokenizationState.DEACTIVATED)
            completion(deactivatedCard: creditCard)
        }
    }

    func randomStringWithLength (len : Int) -> String {

        let letters : NSString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

        let randomString : NSMutableString = NSMutableString(capacity: len)

        for _ in 0 ... (len-1) {
            let length = UInt32 (letters.length)
            let rand = arc4random_uniform(length)
            randomString.appendFormat("%C", letters.characterAtIndex(Int(rand)))
        }

        return randomString as String
    }

    func randomNumbers (len:Int = 16) -> String {

        let letters : NSString = "0123456789"

        let randomString : NSMutableString = NSMutableString(capacity: len)
        
        for _ in 0 ... (len-1) {
            let length = UInt32 (letters.length)
            let rand = arc4random_uniform(length)
            randomString.appendFormat("%C", letters.characterAtIndex(Int(rand)))
        }
        
        return randomString as String
    }

    func randomEmail() -> String {
        let email = randomStringWithLength(8)
            .stringByAppendingString("@")
            .stringByAppendingString(randomStringWithLength(5))
            .stringByAppendingString(".")
            .stringByAppendingString(randomStringWithLength(5))

        return email
    }
    
    func randomPan() -> String {
        return "999941111111" + randomNumbers(4)
    }

}
