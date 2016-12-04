

import UIKit
import PopcornKit
import SafariServices

class SettingsTableViewController: UITableViewController, PCTTablePickerViewDelegate, PCTPickerViewDelegate, TraktManagerDelegate {

    @IBOutlet var streamOnCellularSwitch: UISwitch!
    @IBOutlet var removeCacheOnPlayerExitSwitch: UISwitch!
    @IBOutlet var qualitySegmentedControl: UISegmentedControl!
    @IBOutlet var traktSignInButton: UIButton!
    @IBOutlet var openSubsSignInButton: UIButton!
	
	var tablePickerView: PCTTablePickerView!
    var pickerView: PCTPickerView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tablePickerView = PCTTablePickerView(superView: view, sourceArray: Locale.commonLanguages(), self)
        tabBarController?.view.addSubview(tablePickerView)
        pickerView = PCTPickerView(superView: view, componentDataSources: [[String : AnyObject]](), delegate: self, selectedItems: [String]())
        tabBarController?.view.addSubview(pickerView)
        updateSignedInStatus(traktSignInButton, isSignedIn: TraktManager.shared.isSignedIn())
        updateSignedInStatus(openSubsSignInButton, isSignedIn: UserDefaults.standard.bool(forKey: "AuthorizedOpenSubs"))
        streamOnCellularSwitch.isOn = UserDefaults.standard.bool(forKey: "StreamOnCellular")
        removeCacheOnPlayerExitSwitch.isOn = UserDefaults.standard.bool(forKey: "removeCacheOnPlayerExit")
        for index in 0..<qualitySegmentedControl.numberOfSegments {
            if qualitySegmentedControl.titleForSegment(at: index) == UserDefaults.standard.string(forKey: "PreferredQuality") {
                qualitySegmentedControl.selectedSegmentIndex = index
            }
        }
        TraktManager.shared.delegate = self
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        pickerView?.setNeedsLayout()
        pickerView?.layoutIfNeeded()
        tablePickerView?.setNeedsLayout()
        tablePickerView?.layoutIfNeeded()
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)!
        switch indexPath.section {
        case 0 where indexPath.row == 2:
            tablePickerView?.toggle()
        case 2:
            let selectedItem = UserDefaults.standard.string(forKey: "PreferredSubtitle\(cell.textLabel!.text!.capitalized.whiteSpacelessed)")
            var dict = [String: AnyObject]()
            if indexPath.row == 0 || indexPath.row == 2 {
                for (index, color) in UIColor.systemColors().enumerated() {
                    dict[UIColor.systemColorStrings()[index]] = color
                }
                if indexPath.row == 2 {
                    dict["None"] = UIColor.clear
                }
                pickerView.componentDataSources = [dict]
                pickerView.selectedItems = [selectedItem ?? cell.detailTextLabel!.text!]
                pickerView.attributesForComponents = [NSForegroundColorAttributeName]
            } else if indexPath.row == 1 {
                for size in 16...40 {
                    dict["\(size) pt"] = UIFont.systemFont(ofSize: CGFloat(size))
                }
                pickerView.componentDataSources = [dict]
                pickerView.selectedItems = [selectedItem ?? cell.detailTextLabel!.text! + " pt"]
                pickerView.attributesForComponents = [NSFontAttributeName]
            } else if indexPath.row == 3 {
                for familyName in UIFont.familyNames {
                    for fontName in UIFont.fontNames(forFamilyName: familyName) {
                        let font = UIFont(name: fontName, size: 16)!; let traits = font.fontDescriptor.symbolicTraits
                        if !traits.contains(.traitCondensed) && !traits.contains(.traitBold) && !traits.contains(.traitItalic) && !fontName.contains("Thin") && !fontName.contains("Light") && !fontName.contains("Medium") && !fontName.contains("Black") {
                            dict[fontName] = UIFont(name: fontName, size: 16)
                        }
                    }
                }
                dict["Default"] = UIFont.systemFont(ofSize: 16)
                pickerView.componentDataSources = [dict]
                pickerView.selectedItems = [selectedItem ?? cell.detailTextLabel!.text!]
                pickerView.attributesForComponents = [NSFontAttributeName]
            } else if indexPath.row == 4 {
                dict = ["Normal": UIFont.systemFont(ofSize: 16), "Bold": UIFont.boldSystemFont(ofSize: 16), "Italic": UIFont.italicSystemFont(ofSize: 16), "Bold-Italic": UIFont.systemFont(ofSize: 16).boldItalic()]
                pickerView.componentDataSources = [dict]
                pickerView.selectedItems = [selectedItem ?? cell.detailTextLabel!.text!]
                pickerView.attributesForComponents = [NSFontAttributeName]
            }
            pickerView.toggle()
        case 3 where indexPath.row == 1:
            let controller = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
            controller.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            do {
                let size = FileManager.default.folderSizeAtPath(NSTemporaryDirectory())
                for path in try FileManager.default.contentsOfDirectory(atPath: NSTemporaryDirectory()) {
                   try FileManager.default.removeItem(atPath: NSTemporaryDirectory() + "/\(path)")
                }
                controller.title = "Success"
                if size == 0 {
                    controller.message = "Cache was already empty, no disk space was reclamed."
                } else {
                    controller.message = "Cleaned \(size) bytes."
                }
            } catch {
                controller.title = "Failed"
                controller.message = "Error cleaning cache."
                print("Error: \(error)")
            }
            present(controller, animated: true, completion: nil)
            tableView.deselectRow(at: indexPath, animated: true)
        case 4:
            if indexPath.row == 1 {
                let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
                let loadingView: UIViewController = {
                    let viewController = UIViewController()
                    viewController.view.translatesAutoresizingMaskIntoConstraints = false
                    let label = UILabel(frame: CGRect(origin: CGPoint.zero, size: CGSize(width: 200, height: 20)))
                    label.translatesAutoresizingMaskIntoConstraints = false
                    label.text = "Checking for updates..."
                    label.font = UIFont.systemFont(ofSize: 16, weight: UIFontWeightBold)
                    label.sizeToFit()
                    let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
                    activityIndicator.translatesAutoresizingMaskIntoConstraints = false
                    activityIndicator.startAnimating()
                    viewController.view.addSubview(activityIndicator)
                    viewController.view.addSubview(label)
                    viewController.view.centerXAnchor.constraint(equalTo: label.centerXAnchor, constant: -10).isActive = true
                    viewController.view.centerYAnchor.constraint(equalTo: label.centerYAnchor).isActive = true
                    label.leadingAnchor.constraint(equalTo: activityIndicator.trailingAnchor, constant: 7.0).isActive = true
                    viewController.view.centerYAnchor.constraint(equalTo: activityIndicator.centerYAnchor).isActive = true
                    return viewController
                }()
                alert.setValue(loadingView, forKey: "contentViewController")
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                present(alert, animated: true, completion: nil)
                tableView.deselectRow(at: indexPath, animated: true)
                UpdateManager.shared.checkVersion(.immediately) { [weak self] success in
                    alert.dismiss(animated: true, completion: nil)
                    self?.tableView.reloadData()
                    if !success {
                        let alert = UIAlertController(title: "No Updates Available", message: "There are no updates available for Popcorn Time at this time.", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                        self?.present(alert, animated: true, completion: nil)
                    }
                }
            } else if indexPath.row == 2 {
                openUrl("https://github.com/PopcornTimeTV/PopcornTimeiOS/blob/master/NOTICE.md")
            }
        default:
           break
        }
    }
    
    // MARK: - UITableViewDataSource
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        switch indexPath.section {
        case 0 where indexPath.row == 2:
            cell.detailTextLabel?.text = "None"
            tablePickerView.selectedItems.removeAll()
            if let preferredSubtitleLanguage = UserDefaults.standard.string(forKey: "PreferredSubtitleLanguage") , preferredSubtitleLanguage != "None" {
                self.tablePickerView.selectedItems = [preferredSubtitleLanguage]
                cell.detailTextLabel?.text = preferredSubtitleLanguage
            }
        case 2:
            if let string = UserDefaults.standard.string(forKey: "PreferredSubtitle\(cell.textLabel!.text!.capitalized.whiteSpacelessed)") {
                cell.detailTextLabel?.text = string
            }
        case 4:
            if indexPath.row == 0 {
              cell.detailTextLabel?.text = "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")!).\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")!)"
            } else if indexPath.row == 1 {
                var date = "Never."
                if let lastChecked = UserDefaults.standard.object(forKey: "lastVersionCheckPerformedOnDate") as? Date {
                    date = DateFormatter.localizedString(from: lastChecked, dateStyle: .short, timeStyle: .short)
                }
                cell.detailTextLabel?.text = "Last checked: \(date)"
            }
        default:
            break
        }
        return cell
    }
    
    func updateSignedInStatus(_ sender: UIButton, isSignedIn: Bool) {
        sender.setTitle(isSignedIn ? "Sign Out": "Authorize", for: .normal)
        sender.setTitleColor(isSignedIn ? UIColor(red: 230.0/255.0, green: 46.0/255.0, blue: 37.0/255.0, alpha: 1.0) : view.window?.tintColor!, for: .normal)
    }
    
    // MARK: - PCTTablePickerViewDelegate
    
    func tablePickerView(_ tablePickerView: PCTTablePickerView, didClose items: [String]) {
        UserDefaults.standard.set(items.first ?? "None", forKey: "PreferredSubtitleLanguage")
        tableView.reloadData()
    }
    
    func tablePickerView(_ tablePickerView: PCTTablePickerView, willClose items: [String]) {
        if let indexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    // MARK: - PCTPickerViewDelegate
    
    func pickerView(_ pickerView: PCTPickerView, didClose items: [String : AnyObject]) {
        if let index = tableView.indexPathForSelectedRow, let text = tableView.cellForRow(at: index)?.textLabel?.text {
            UserDefaults.standard.set(items.keys.first, forKey: "PreferredSubtitle\(text.capitalized.whiteSpacelessed)")
        }
        tableView.reloadData()
    }

    func pickerView(_ pickerView: PCTPickerView, willClose items: [String : AnyObject]) {
        if let index = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: index, animated: true)
        }
    }
    
    @IBAction func streamOnCellular(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: "StreamOnCellular")
    }
    
    @IBAction func removeCacheOnPlayerExit(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: "removeCacheOnPlayerExit")
    }
    
    @IBAction func preferredQuality(_ control: UISegmentedControl) {
        UserDefaults.standard.set(control.titleForSegment(at: control.selectedSegmentIndex), forKey: "PreferredQuality")
    }
    
    // MARK: - Authorization
    
    @IBAction func authorizeTraktTV(_ sender: UIButton) {
        if TraktManager.shared.isSignedIn() {
            let alert = UIAlertController(title: "Sign Out", message: "Are you sure you want to Sign Out?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: { action in
                do { try TraktManager.shared.logout() } catch {}
                self.updateSignedInStatus(sender, isSignedIn: false)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        } else {
            present(TraktManager.shared.loginViewController(), animated: true, completion: nil)
        }
    }
    
    @IBAction func authorizeOpenSubs(_ sender: UIButton) {
        if UserDefaults.standard.bool(forKey: "AuthorizedOpenSubs") {
            let alert = UIAlertController(title: "Sign Out", message: "Are you sure you want to Sign Out?", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: { action in
            
                let credential = URLCredentialStorage.shared.credentials(for: SubtitlesManager.shared.protectionSpace)!.values.first!
                URLCredentialStorage.shared.remove(credential, for: SubtitlesManager.shared.protectionSpace)
                UserDefaults.standard.set(false, forKey: "AuthorizedOpenSubs")
                self.updateSignedInStatus(sender, isSignedIn: false)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        } else {
            var alert = UIAlertController(title: "Sign In", message: "VIP account required.", preferredStyle: .alert)
            alert.addTextField(configurationHandler: { (textField) in
                textField.placeholder = "Username"
            })
            alert.addTextField(configurationHandler: { (textField) in
                textField.placeholder = "Password"
                textField.isSecureTextEntry = true
            })
            alert.addAction(UIAlertAction(title: "Sign In", style: .default, handler: { (action) in
                let credential = URLCredential(user: alert.textFields![0].text!, password: alert.textFields![1].text!, persistence: .permanent)
                URLCredentialStorage.shared.set(credential, for: SubtitlesManager.shared.protectionSpace)
                SubtitlesManager.shared.login() { error in
                    if let error = error {
                        URLCredentialStorage.shared.remove(credential, for: SubtitlesManager.shared.protectionSpace)
                        alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                    } else {
                        UserDefaults.standard.set(true, forKey: "AuthorizedOpenSubs")
                        self.updateSignedInStatus(sender, isSignedIn: true)
                    }
                }
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        }
    }
    
    func openUrl(_ url: String) {
        present(SFSafariViewController(url: URL(string: url)!), animated: true, completion: nil)
    }
    
    // MARK: - TraktManagerDelegate
    
    func authenticationDidSucceed() {
        dismiss(animated: true, completion: nil)
        updateSignedInStatus(traktSignInButton, isSignedIn: true)
    }
    
    func authenticationDidFail(withError error: NSError) {
        dismiss(animated: true, completion: nil)
        let alert = UIAlertController(title: "Error authenticating.", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}
