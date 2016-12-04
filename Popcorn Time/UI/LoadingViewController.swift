

import UIKit
import PopcornTorrent

class LoadingViewController: UIViewController {
    
    @IBOutlet private var progressLabel: UILabel!
    @IBOutlet private var progressView: UIProgressView!
    @IBOutlet private var speedLabel: UILabel!
    @IBOutlet private var seedsLabel: UILabel!
    @IBOutlet private var loadingView: UIView!
    @IBOutlet private var backgroundImageView: UIImageView!

    
    var progress: Float = 0.0 {
        didSet {
            loadingView.isHidden = true
            progressView.isHidden = false
            progressLabel.isHidden = false
            progressView.progress = progress
            progressLabel.text = String(format: "%.0f%%", progress*100)
        }
    }
    var speed: Int = 0 {
        didSet {
            loadingView.isHidden = true
            speedLabel.isHidden = false
            speedLabel.text = ByteCountFormatter.string(fromByteCount: Int64(speed), countStyle: .binary) + "/s"
        }
    }
    var seeds: Int = 0 {
        didSet {
            loadingView.isHidden = true
            seedsLabel.isHidden = false
            seedsLabel.text = "\(seeds) seeds"
        }
    }
    var backgroundImage: UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        UIApplication.shared.isIdleTimerDisabled = true
        if let backgroundImage = backgroundImage {
            backgroundImageView.image = backgroundImage
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidLoad()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    @IBAction func cancelButtonPressed() {
        PTTorrentStreamer.shared().cancelStreamingAndDeleteData(UserDefaults.standard.bool(forKey: "removeCacheOnPlayerExit"))
        dismiss(animated: true, completion: nil)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
}
