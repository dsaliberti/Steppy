import HealthKit

protocol HealthKit {
    var store: HKHealthStore { get }
    //permission
    //read
    //write
}

struct HKViewModel: HealthKit {
    let store = HKHealthStore()
}
