import HealthKit

protocol HealthKit {
    var store: HKHealthStore { get }
    //permission
    //read
    //write
}

struct HKViewModel: HealthKit {
    internal let store = HKHealthStore()
    
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        let objectTypesToRead: Set<HKObjectType> = [HKObjectType.quantityType(forIdentifier: .stepCount)!]
        let sampleTypesToWrite: Set<HKSampleType> = [HKSampleType.quantityType(forIdentifier: .stepCount)!]
        
        store.requestAuthorization(
            toShare: sampleTypesToWrite,
            read: objectTypesToRead
        ) { (success, error) in
            completion(success, error)
        }
    }
    
    func getSteps(for date: Date, completion: @escaping (Double) -> Void) {
        let stepsQuantityType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: startOfDay)
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepsQuantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                print("there's a query error: \(error.debugDescription)")
                completion(0.0)
                return
            }
            completion(sum.doubleValue(for: .count()))
        }
        store.execute(query)
    }
    
    func write(steps: Int, completion: @escaping (Double) -> Void) {
        let quantity = HKQuantity(unit: .count(), doubleValue: Double(steps))
        let type = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: startOfDay)!
        let sample = HKQuantitySample(
            type: type,
            quantity: quantity,
            start: startOfDay,
            end: endOfDay
        )
        
        store.save(sample) { (bool, error) in
            if bool {
                self.getSteps(for: Date(), completion: { (steps) in
                    DispatchQueue.main.async {
                        //self.render(steps: "\(Int(steps))")
                        //self.stepsLabel.text = "👣 \(steps)"
                    }
                })
            } else {
                print("failed to save steps on HK 💔 \(error.debugDescription)")
            }
        }
    }
}
