import UIKit

class AppRootViewController: UIViewController {
    let appViewModel: AppRootViewModel
    init(appViewModel: AppRootViewModel) {
        self.appViewModel = appViewModel
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = .white
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
