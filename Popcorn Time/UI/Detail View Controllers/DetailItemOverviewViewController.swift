

import UIKit
import GoogleCast
import PopcornKit

class DetailItemOverviewViewController: UIViewController, UIGestureRecognizerDelegate, UIScrollViewDelegate, UIPopoverPresentationControllerDelegate, PCTPlayerViewControllerDelegate {
    
    var progressiveness: CGFloat = 0.0
    var lastTranslation: CGFloat = 0.0
    var lastHeaderHeight: CGFloat = 0.0
    var minimumHeight: CGFloat {
        if let navigationBar = navigationController?.navigationBar , navigationBar.isHidden == false { return navigationBar.bounds.size.height + statusBarHeight() }
        return statusBarHeight()
    }
    var maximumHeight: CGFloat {
        return view.bounds.height/1.6
    }
    
    @IBOutlet var headerHeightConstraint: NSLayoutConstraint!
    @IBOutlet var scrollView: PCTScrollView!
    @IBOutlet var tableView: PCTTableView!
    @IBOutlet var blurView: UIVisualEffectView!
    @IBOutlet var gradientViews: [GradientView]!
    @IBOutlet var backgroundImageView: UIImageView!
    @IBOutlet var castButton: CastIconBarButtonItem!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var ratingView: FloatRatingView!
    @IBOutlet var summaryView: PCTTextView!
    @IBOutlet var infoLabel: UILabel!

    enum ScrollDirection {
        case down
        case up
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(updateCastStatus), name: NSNotification.Name.gckCastStateDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(layoutNavigationBar), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
        updateCastStatus()
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for:.default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationController?.navigationBar.backgroundColor = UIColor.clear
        self.navigationController?.navigationBar.tintColor = UIColor.white
        self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.white.withAlphaComponent(self.progressiveness)]
        if transitionCoordinator?.viewController(forKey: UITransitionContextViewControllerKey.from) is PCTPlayerViewController || transitionCoordinator?.viewController(forKey: UITransitionContextViewControllerKey.from) is CastPlayerViewController {
            self.navigationController?.setNavigationBarHidden(false, animated: false)
            self.headerHeightConstraint.constant = self.lastHeaderHeight
            self.updateScrolling(false)
            for view in self.gradientViews {
                view.alpha = 1.0
            }
            if let showDetail = self as? TVShowDetailViewController {
                showDetail.segmentedControl.alpha = 1.0
            }
            if let frame = self.tabBarController?.tabBar.frame , frame.origin.y > self.view.bounds.height - frame.height {
                let offsetY = -frame.size.height
                self.tabBarController?.tabBar.frame = frame.offsetBy(dx: 0, dy: offsetY)
            }
        }
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        if transitionCoordinator?.viewController(forKey: UITransitionContextViewControllerKey.to) == self.navigationController?.topViewController {
            self.navigationController?.navigationBar.setBackgroundImage(nil, for:.default)
            self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.white]
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        layoutNavigationBar()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        headerHeightConstraint.constant = maximumHeight
        (castButton.customView as! CastIconButton).addTarget(self, action: #selector(castButtonTapped), for: .touchUpInside)
    }
    
    /// On iPhones, status bar hides when view traits become compact so we need to force an update for the header size.
    func layoutNavigationBar() {
        let scrollingView: UIScrollView! = tableView ?? scrollView
        if headerHeightConstraint.constant < minimumHeight || (scrollingView.value(forKey: "programaticScrollEnabled")! as AnyObject).boolValue
        {
            headerHeightConstraint.constant = minimumHeight
        }
        if headerHeightConstraint.constant > maximumHeight {
            headerHeightConstraint.constant = maximumHeight
        }
        if scrollingView.frame.size.height > scrollingView.contentSize.height + scrollingView.contentInset.bottom {
            resetToEnd(scrollingView)
        }
        updateScrolling(true)
    }
    
    @IBAction func handleGesture(_ sender: UIPanGestureRecognizer) {
        let translation = sender.translation(in: sender.view!.superview!)
        let scrollingView: UIScrollView! = tableView ?? scrollView
        if sender.state == .changed || sender.state == .began {
            let offset = translation.y - lastTranslation
            let scrollDirection: ScrollDirection = offset > 0 ? .up : .down
            
            if (headerHeightConstraint.constant + offset) >= minimumHeight && (scrollingView.value(forKey: "programaticScrollEnabled")! as AnyObject).boolValue == false {
                if ((headerHeightConstraint.constant + offset) - minimumHeight) <= 8.0 // Stops scrolling from sticking just before we transition to scroll view input.
                {
                    headerHeightConstraint.constant = self.minimumHeight
                    updateScrolling(true)
                } else {
                    headerHeightConstraint.constant += offset
                    updateScrolling(false)
                }
            }
            if headerHeightConstraint.constant == minimumHeight && scrollingView.isAtTop
            {
                if scrollDirection == .up {
                    scrollingView.setValue(false, forKey: "programaticScrollEnabled")
                } else // If header is fully collapsed and we are not at the end of scroll view, hand scrolling to scroll view
                {
                    scrollingView.setValue(true, forKey: "programaticScrollEnabled")
                }
            }
            lastTranslation = translation.y
        } else if sender.state == .ended {
            if headerHeightConstraint.constant > maximumHeight {
                headerHeightConstraint.constant = maximumHeight
                updateScrolling(true)
            } else if scrollingView.frame.size.height > scrollingView.contentSize.height + scrollingView.contentInset.bottom {
                resetToEnd(scrollingView)
            }
            lastTranslation = 0.0
        }
    }
    
    
    func updateScrolling(_ animated: Bool) {
        self.progressiveness = 1.0 - (self.headerHeightConstraint.constant - self.minimumHeight)/(self.maximumHeight - self.minimumHeight)
        if animated {
            UIView.animate(withDuration: 0.46, delay: 0.0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.2, options: .allowUserInteraction, animations: {
                self.view.layoutIfNeeded()
                self.blurView.alpha = self.progressiveness
                self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.white.withAlphaComponent(self.progressiveness)]
                }, completion: nil)
        } else {
            self.blurView.alpha = self.progressiveness
            self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.white.withAlphaComponent(self.progressiveness)]
        }
    }
    
    func resetToEnd(_ scrollingView: UIScrollView, animated: Bool = true) {
        headerHeightConstraint.constant += scrollingView.frame.size.height - (scrollingView.contentSize.height + scrollingView.contentInset.bottom)
        if headerHeightConstraint.constant > maximumHeight {
            headerHeightConstraint.constant = maximumHeight
        }
        if headerHeightConstraint.constant >= minimumHeight // User does not go over the "bridge area" so programmatic scrolling has to be explicitly disabled
        {
            scrollingView.setValue(false, forKey: "programaticScrollEnabled")
        }
        updateScrolling(animated)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    // MARK: - PCTPlayerViewControllerDelegate
    
    func playNext(_ episode: Episode) {}
    func presentCastPlayer(_ media: Media, videoFilePath: URL, startPosition: TimeInterval) {
        self.dismiss(animated: true, completion: nil)
        let castPlayerViewController = self.storyboard?.instantiateViewController(withIdentifier: "CastPlayerViewController") as! CastPlayerViewController
        castPlayerViewController.backgroundImage = self.backgroundImageView.image
        castPlayerViewController.title = media.title
        castPlayerViewController.media = media
        castPlayerViewController.startPosition = startPosition
        castPlayerViewController.directory = videoFilePath.deletingLastPathComponent()
        present(castPlayerViewController, animated: true, completion: nil)
    }
    
    // MARK: - Presentation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showCasts", let vc = (segue.destination as? UINavigationController)?.viewControllers.first as? StreamToDevicesTableViewController {
            segue.destination.popoverPresentationController?.delegate = self
            vc.onlyShowCastDevices = true
        }
    }
    
    func castButtonTapped() {
        performSegue(withIdentifier: "showCasts", sender: castButton)
    }
    
    func updateCastStatus() {
        (castButton.customView as! CastIconButton).status = GCKCastContext.sharedInstance().castState
    }
    
    func presentationController(_ controller: UIPresentationController, viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle) -> UIViewController? {
        (controller.presentedViewController as! UINavigationController).topViewController?.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelButtonPressed))
        return controller.presentedViewController
        
    }
    
    func cancelButtonPressed() {
        self.dismiss(animated: true, completion: nil)
    }
}

class PCTScrollView: UIScrollView {
    var programaticScrollEnabled = false
    
    override var contentOffset: CGPoint {
        didSet {
            if !programaticScrollEnabled {
                super.contentOffset = CGPoint.zero
            }
        }
    }
}

class PCTTableView: UITableView {
    var programaticScrollEnabled = false
    
    override var contentOffset: CGPoint {
        didSet {
            if !programaticScrollEnabled {
                super.contentOffset = CGPoint.zero
            }
        }
    }
}
