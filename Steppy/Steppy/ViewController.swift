import UIKit

class ViewController: UIViewController {
    init(title: String) {
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = .white
        self.title = title
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
