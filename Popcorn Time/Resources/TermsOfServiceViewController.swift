

import UIKit

class TermsOfServiceViewController: UIViewController {
    
    @IBAction func accepted(_ sender: UIButton) {
        UserDefaults.standard.set(true, forKey: "TOSAccepted")
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func canceled(_ sender: UIButton) {
        exit(0)
    }

}
