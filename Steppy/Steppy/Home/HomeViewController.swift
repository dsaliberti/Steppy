import UIKit
import HealthKit
import Bento

class HomeViewController: UIViewController {
    let tableView: UITableView = UITableView(frame: CGRect.zero)
    let stepsLabel: UILabel = UILabel(frame: CGRect.zero)
    let keychain: SteppyKeychain
    let homeViewModel: HomeViewModel
    init(
        title: String,
        keychain: SteppyKeychain,
        homeViewModel: HomeViewModel
    ) {
        self.keychain = keychain
        self.homeViewModel = homeViewModel
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = .white
        self.title = title
    }

    private func setupTableView() {
        tableView.add(to: view).pinEdges(to: view.safeAreaLayoutGuide)
        tableView.estimatedSectionFooterHeight = 18
        tableView.estimatedSectionHeaderHeight = 18
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.sectionFooterHeight = UITableView.automaticDimension
        tableView.rowHeight = 100
        tableView.estimatedRowHeight = 100
        tableView.separatorColor = .clear
    }

    private func setupView() {
        view.backgroundColor = .white
    }

    override func viewDidLoad() {
        super.viewDidLoad()
//        setupUI()
        
        setupView()
        setupTableView()
        render()
    }

    func render(steps: String = "0") {
        let box = Box<SectionId, RowId>.empty
            |-+ renderFirstSection(steps: steps)
        
        tableView.render(box)
    }

    enum SectionId: Hashable {
        case first
    }
    
    enum RowId: Hashable {
        case space
        case steps
        case healthKit
        case generateSteps
        case logoutButton
    }

    private func renderFirstSection(steps: String = "0") -> Section<SectionId, RowId> {
        let space =  Component.EmptySpace(height: 20)
        
        let steps = Node(
            id: RowId.steps,
            component: Component.ImageOrLabel(
                imageOrLabel: ImageOrLabelView.Content.text("\(steps) \nsteps"),
                styleSheet: Component.ImageOrLabel.StyleSheet(
                    imageOrLabel: ImageOrLabelView.StyleSheet(
                        fixedSize: CGSize.init(width: 100, height: 50),
                        backgroundColor: .lightGray,
                        cornerRadius: 10.0,
                        label: LabelStyleSheet(
                            backgroundColor: .red,
                            font: UIFont.systemFont(ofSize: 20, weight: .bold),
                            textColor: .white,
                            textAlignment: .center,
                            numberOfLines: 2,
                            lineBreakMode: .byClipping
                        )
                    )
                )
            )
        )
        
        func logout() {
            keychain.clearToken()
        }
        
        let healthButton = Node(
            id: RowId.healthKit,
            component: Component.Button(
                title: "Sync with Apple Health®",
                isEnabled: true,
                didTap: { [weak self] in
                    print("tap..")
                    self?.requestAndPresent()
                },
                styleSheet: Component.Button.StyleSheet(button: ButtonStyleSheet())
            )
        )

        let generateSteps = Node(
            id: RowId.generateSteps,
            component: Component.Button(
                title: "Generate steps randomly",
                isEnabled: true,
                didTap: { [weak self] in
                    print("tap..")
                    self?.writeSteps()
                },
                styleSheet: Component.Button.StyleSheet(button: ButtonStyleSheet())
            )
        )

        let logoutButton = Node(
            id: RowId.logoutButton,
            component: Component.Button(
                title: "Logout",
                isEnabled: true,
                didTap: {
                    print("tapped ")
                    logout()
                },
                styleSheet: Component.Button.StyleSheet(button: ButtonStyleSheet())
            )
        )
        
        return Section(
            id: .first,
            header: space,
            footer: space,
            items: [steps, healthButton, generateSteps, logoutButton]
        )
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension HomeViewController {
    private func setupUI() {
        let health = UIBarButtonItem(
            title: "Health",
            style: UIBarButtonItem.Style.plain,
            target: self,
            action: #selector(requestAndPresent)
        )
        self.navigationItem.rightBarButtonItem = health

        stepsLabel.textColor = .black
        stepsLabel.text = ".. steps 👣"
        stepsLabel.sizeToFit()

        view.addSubview(stepsLabel)

        let gesture = UITapGestureRecognizer(target: self, action: #selector(writeSteps))
        view.addGestureRecognizer(gesture)

        let logout = UIButton(frame: CGRect.init(x: 30, y: 70, width: 200, height: 60))
        logout.titleLabel?.text = ".. Logout"
        logout.backgroundColor = .red
        logout.addTarget(self, action: #selector(HomeViewController.logout), for: .touchUpInside)
        view.addSubview(logout)
    }

    @objc func logout() {
        keychain.clearToken()
    }

    @objc func requestAndPresent() {
        print("request..")
        requestAuthorization { (isGranted, error) in
            print("Health data ❤️: isGranted", isGranted, "error", error.debugDescription)
            
            self.getSteps(
                for: Date(),
                completion: { steps in
                    DispatchQueue.main.sync {
                        self.render(steps: "\(Int(steps))")
                        self.stepsLabel.text = "steps 👣 \(steps.debugDescription)"
                        self.stepsLabel.sizeToFit()
                    }
                }
            )
        }
    }
}

/// MARK - TODO: Extract HealthKit
extension HomeViewController {
    
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
                        self.render(steps: "\(Int(steps))")
                        self.stepsLabel.text = "👣 \(steps)"
                    }
                })
            } else {
                print("failed to save steps on HK 💔 \(error.debugDescription)")
            }
        }
    }
}
