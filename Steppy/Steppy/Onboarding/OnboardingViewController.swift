import UIKit
import Bento

class OnboardingViewController: UIViewController {
    let tableView: UITableView = UITableView(frame: CGRect.zero)
    let keychain: SteppyKeychain
    init(title: String, keychain: SteppyKeychain) {
        self.keychain = keychain
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupTableView()
        render()
    }

    private func setupTableView() {
        tableView.add(to: view).pinEdges(to: view.safeAreaLayoutGuide)
        tableView.estimatedSectionFooterHeight = 18
        tableView.estimatedSectionHeaderHeight = 18
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.sectionFooterHeight = UITableView.automaticDimension
    }

    enum SectionId: Hashable {
        case first
    }
    
    enum RowId: Hashable {
        case space
        case username
        case password
        case sendButton
    }

    func render() {
        let box = Box<SectionId, RowId>.empty
            |-+ renderFirstSection()

        tableView.render(box)
    }
    
    private func renderFirstSection() -> Section<SectionId, RowId> {
        //let headerSpace = Component.EmptySpace(height: 20)
        //let footerSpace = Component.EmptySpace(height: 20)
        let space =  Component.EmptySpace(height: 20)

        let username = Node(
            id: RowId.username,
            component: Component.TextInput(
                title: "e-mail: ",
                placeholder: "type your e-mail or username here",
                keyboardType: .emailAddress,
                isEnabled: true,
                textWillChange: nil,
                textDidChange: { text in
                
                },
                styleSheet: Component.TextInput.StyleSheet()
            )
        )
        
        let password = Node(
            id: RowId.password,
            component: Component.TextInput(
                title: "password: ",
                placeholder: "type your password here",
                keyboardType: .alphabet,
                isEnabled: true,
                textWillChange: nil,
                textDidChange: { text in
                    
            },
                styleSheet: Component.TextInput.StyleSheet()
            )
        )

        let sendButton = Node(
            id: RowId.sendButton,
            component: Component.Button(
                title: "Sign Up",
                isEnabled: true,
                didTap: {
                    print("tapped ")
                },
                styleSheet: Component.Button.StyleSheet(button: ButtonStyleSheet())
            )
        )
        
        return Section(
            id: .first,
            header: space,
            footer: space,
            items: [username, password, sendButton]
        )
    }

    private func setupView() {
        view.backgroundColor = .white
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
