import UIKit

class OnboardingViewController: UIViewController {
    let username = UITextField(frame: CGRect.init(x: 10, y: 10, width: 200, height: 50))
    let password = UITextField(frame: CGRect.init(x: 10, y: 60, width: 200, height: 50))
    let send = UIButton.init(type: .system)
    
    let keychain: SteppyKeychain
    
    init(title: String, keychain: SteppyKeychain) {
        self.keychain = keychain
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = .white
        view.addSubview(username)
        view.addSubview(password)
        view.addSubview(send)
        
        send.addTarget(self, action: #selector(tap), for: .touchUpInside)

        password.isSecureTextEntry = true
        send.frame = CGRect.init(x: 10, y: 120, width: 200, height: 50)
        send.backgroundColor = .blue
        send.titleLabel?.text = "Sign In"
    }

    @objc func tap() {
        keychain.setToken("token-here-to-test")
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
