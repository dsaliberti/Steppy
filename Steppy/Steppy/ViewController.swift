import UIKit
import HealthKit

class ViewController: UIViewController {
    let stepsLabel: UILabel = UILabel(frame: CGRect.zero)
    init(title: String) {
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = .black
        self.title = title
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ViewController {
    private func setupUI() {
        let health = UIBarButtonItem(
            title: "Health",
            style: UIBarButtonItem.Style.plain,
            target: self,
            action: #selector(requestAndPresent)
        )
        self.navigationItem.rightBarButtonItem = health

        stepsLabel.textColor = .white
        stepsLabel.text = ".. steps 👣"
        stepsLabel.sizeToFit()

        view.addSubview(stepsLabel)

        let gesture = UITapGestureRecognizer(target: self, action: #selector(writeSteps))
        view.addGestureRecognizer(gesture)
    }

    @objc func requestAndPresent() {
        print("request..")
        requestAuthorization { (isGranted, error) in
            print("Health data ❤️: isGranted", isGranted, "error", error.debugDescription)
            
            self.getSteps(
                for: Date(),
                completion: { steps in
                    DispatchQueue.main.sync {
                        self.stepsLabel.text = "steps 👣 \(steps.debugDescription)"
                        self.stepsLabel.sizeToFit()
                    }
                }
            )
        }
    }
}

/// MARK - TODO: Extract HealthKit
extension ViewController {
    
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        let objectTypesToRead: Set<HKObjectType> = [HKObjectType.quantityType(forIdentifier: .stepCount)!]
        let sampleTypesToWrite: Set<HKSampleType> = [HKSampleType.quantityType(forIdentifier: .stepCount)!]

        HKHealthStore().requestAuthorization(toShare: sampleTypesToWrite, read: objectTypesToRead) { (success, error) in
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
            completion(sum.doubleValue(for: HKUnit.count()))
        }
        HKHealthStore().execute(query)
    }

    @objc func writeSteps() {
        let steps = Int.random(in: 0 ... 10)
        let quantity = HKQuantity(unit: HKUnit.count(), doubleValue: Double(steps))

        let type = HKQuantityType.quantityType(forIdentifier: .stepCount)!

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: startOfDay)!
        let sample = HKQuantitySample(
            type: type,
            quantity: quantity,
            start: startOfDay,
            end: endOfDay
        )
        
        HKHealthStore().save(sample) { (bool, error) in
            if bool {
                self.getSteps(for: Date(), completion: { (steps) in
                    DispatchQueue.main.async {
                        self.stepsLabel.text = "👣 \(steps)"
                    }
                })
            } else {
                print("failed to save steps on HK 💔 \(error.debugDescription)")
            }
        }
    }
}
