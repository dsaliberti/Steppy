import UIKit
import Bento
import ReactiveSwift

final class HomeViewController: UIViewController {
    private let tableView: UITableView = UITableView(frame: CGRect.zero)
    private let viewModel: HomeViewModel
    init(title: String, viewModel: HomeViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupTableView()
        bindViewModel()

        viewModel.viewDidLoad()
    }

    func appBecomeActive() {
        viewModel.appBecomeActive()
    }
    
    private func setupTableView() {
        tableView.add(to: view).pinEdges(to: view.safeAreaLayoutGuide)
        tableView.estimatedSectionFooterHeight = 18
        tableView.estimatedSectionHeaderHeight = 18
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.sectionFooterHeight = UITableView.automaticDimension
        tableView.rowHeight = 80
        tableView.separatorColor = .clear
    }

    private func setupView() {
        view.backgroundColor = .white
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension HomeViewController {
    private func bindViewModel() {
        viewModel.state
            .producer
            .take(duringLifetimeOf: self)
            .startWithValues { [weak self] state in
                guard let self = self else { return }
                
                self.tableView.render(self.viewModel.render(state: state))
        }
    }
}

extension HomeViewController {
    func requestAndPresent() {
        print("request..")

    }
}
