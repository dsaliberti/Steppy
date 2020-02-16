import HealthKit
import ReactiveSwift

protocol HealthKit {
    func checkAuthorizationStatus() -> HKStepsAuthorizationStatus
    
    func requestAuthorization(completion: @escaping (HKStepsAuthorizationStatus, Error?) -> Void)
    func requestAuthorization() -> SignalProducer<HKStepsAuthorizationStatus, Error>

    func readSteps(for date: Date,_ completion: @escaping (Double) -> Void)
    func writeAndRead(steps: Int, date: Date,_ completion: @escaping (Double) -> Void)

    func readSteps(for date: Date) -> SignalProducer<Double, Error>
    func writeAndRead(steps: Int, date: Date) -> SignalProducer<Double, Error>
}

enum HKStepsAuthorizationStatus {
    case unknown
    case sharingAuthorized
    case cancelled
    case denied
    case unavailable
    case notDetermined
}

struct HKViewModel: HealthKit {
    internal let store = HKHealthStore()

    func checkAuthorizationStatus() -> HKStepsAuthorizationStatus {
        guard HKHealthStore.isHealthDataAvailable() else {
            return .unavailable
        }
        
        guard let objectTypeQuantityStepCount = HKObjectType.quantityType(forIdentifier: .stepCount) else {
                return .notDetermined
        }

        let status = self.store.authorizationStatus(for: objectTypeQuantityStepCount)

        switch status {
        case .notDetermined:
            return  .notDetermined
        case .sharingAuthorized:
            return .sharingAuthorized
        case .sharingDenied:
            return .denied
        @unknown default:
            return .notDetermined
        }
    }

    func requestAuthorization(completion: @escaping (HKStepsAuthorizationStatus, Error?) -> Void) {
        guard let objectTypeQuantityStepCount = HKObjectType.quantityType(forIdentifier: .stepCount),
            let sampleTypeQuantityStepCount = HKSampleType.quantityType(forIdentifier: .stepCount) else {
                return
        }

        let objectTypesToRead = Set([objectTypeQuantityStepCount])
        let sampleTypesToWrite = Set([sampleTypeQuantityStepCount])

        store.requestAuthorization(
            toShare: sampleTypesToWrite,
            read: objectTypesToRead
        ) { (success, error) in
            guard success else {
                return completion(.cancelled, error)
            }

            completion(self.checkAuthorizationStatus(), error)
        }
    }

    var stepsCountQuantityType: HKQuantityType {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            fatalError("HKQuantityType: Could not create a step count quantity type")
            //TODO: - Log error
        }

        return type
    }
    
    func readSteps(for date: Date,_ completion: @escaping (Double) -> Void) {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: startOfDay)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        let query = HKStatisticsQuery(
            quantityType: stepsCountQuantityType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            guard let result = result,
                let sum = result.sumQuantity() else {
                    //TODO: - Log error
                    completion(0.0)
                    return
            }

            completion(sum.doubleValue(for: .count()))
        }
        store.execute(query)
    }
    
    func writeAndRead(steps: Int, date: Date,_ completion: @escaping (Double) -> Void) {
        let quantity = HKQuantity(unit: .count(), doubleValue: Double(steps))
        let startOfDay = Calendar.current.startOfDay(for: date)
        
        let sample = HKQuantitySample(
            type: stepsCountQuantityType,
            quantity: quantity,
            start: startOfDay,
            end: date.endOfDay
        )
        
        store.save(sample) { (bool, error) in
            if bool {
                self.readSteps(for: date, completion)
            } else {
                print("Failed to save steps on HK 💔 \(error.debugDescription)")
            }
        }
    }
}

extension HKViewModel {
    //MARK: -ReactiveSwift versions
    func readSteps(for date: Date) -> SignalProducer<Double, Error> {
        return SignalProducer { (observer, _) in
            self.readSteps(for: date, { steps in
                observer.send(value: steps)
                observer.sendCompleted()
            })
        }
    }
    
    func writeAndRead(steps: Int, date: Date) -> SignalProducer<Double, Error> {
        return SignalProducer { (observer, _) in
            self.writeAndRead(steps: steps, date: date, { newSteps in
                observer.send(value: newSteps)
                observer.sendCompleted()
            })
        }
    }
    
    func requestAuthorization() -> SignalProducer<HKStepsAuthorizationStatus, Error> {
        return SignalProducer { (observer, lifetime) in
            self.requestAuthorization(completion: { (status, error) in
                if let error = error {
                    observer.send(error: error)
                }
                
                observer.send(value: status)
                observer.sendCompleted()
            })
        }
    }
}

private extension Date {
    var endOfDay: Date {
        guard let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: self) else {
            fatalError("Date couldn't be created")
            //TODO: - Log error
        }

        return endOfDay
    }
}
