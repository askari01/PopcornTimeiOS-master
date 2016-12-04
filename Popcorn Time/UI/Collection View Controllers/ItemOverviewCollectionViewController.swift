

import UIKit
import Reachability

protocol ItemOverviewDelegate: class {
    func search(_ text: String?)
    func didDismissSearchController(_ searchController: UISearchController)
    func loadNextPage(_ page: Int, searchTerm: String?, removeCurrentData: Bool)
    func shouldRefreshCollectionView() -> Bool
}

class ItemOverviewCollectionViewController: UICollectionViewController, UISearchControllerDelegate, UISearchBarDelegate, UISearchResultsUpdating, UICollectionViewDelegateFlowLayout {
    
    weak var delegate: ItemOverviewDelegate?
    
    let searchBlockDelay: TimeInterval = 0.25
    var searchBlock: DispatchCancelableBlock?
    
    var isLoading: Bool = false
    var hasNextPage: Bool = false
    var currentPage: Int = 1
    
    let cache = NSCache<AnyObject, UINavigationController>()
    fileprivate var classContext = 0
    
    var error: NSError?
    
    var filterHeader: FilterCollectionReusableView?
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
        collectionView?.removeObserver(self, forKeyPath: "frame")
        searchController.searchBar.isHidden = true
        searchController.searchBar.resignFirstResponder()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        collectionView?.addObserver(self, forKeyPath: "frame", options: .new, context: &classContext)
        searchController.searchBar.isHidden = false
        searchController.searchBar.becomeFirstResponder()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshCollectionView(_:)), for: .valueChanged)
        collectionView?.addSubview(refreshControl)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        collectionView?.performBatchUpdates(nil, completion: nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let keyPath = keyPath , keyPath == "frame" && context == &classContext {
            collectionView?.performBatchUpdates(nil, completion: nil)
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    func reachabilityChanged(_ notification: Notification) {
        let reachability = notification.object! as! Reachability
        if reachability.isReachableViaWiFi() || reachability.isReachableViaWWAN() {
            if let delegate = delegate , delegate.shouldRefreshCollectionView() {
                delegate.loadNextPage(currentPage, searchTerm: searchController.searchBar.text, removeCurrentData: true)
            }
        }
    }
    
    func refreshCollectionView(_ sender: UIRefreshControl) {
        delegate?.loadNextPage(currentPage, searchTerm: searchController.searchBar.text, removeCurrentData: true)
        sender.endRefreshing()
    }
    
    lazy var searchController: UISearchController = {
        let svc = UISearchController(searchResultsController: nil)
        svc.searchResultsUpdater = self
        svc.delegate = self
        svc.searchBar.delegate = self
        svc.searchBar.barStyle = .black
        svc.searchBar.isTranslucent = false
        svc.hidesNavigationBarDuringPresentation = false
        svc.dimsBackgroundDuringPresentation = false
        svc.searchBar.keyboardAppearance = .dark
        return svc
    }()
    
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == collectionView {
            let y = scrollView.contentOffset.y + scrollView.bounds.size.height - scrollView.contentInset.bottom
            let height = scrollView.contentSize.height
            let reloadDistance: CGFloat = 10
            if(y > height + reloadDistance && isLoading == false && hasNextPage == true) {
                collectionView?.contentInset.bottom = 80
                let background = UIView(frame: collectionView!.frame)
                let indicator = UIActivityIndicatorView(activityIndicatorStyle: .white)
                indicator.startAnimating()
                indicator.translatesAutoresizingMaskIntoConstraints = false
                background.addSubview(indicator)
                background.addConstraint(NSLayoutConstraint(item: indicator, attribute: .centerX, relatedBy: .equal, toItem: background, attribute: .centerX, multiplier: 1, constant: 0))
                background.addConstraint(NSLayoutConstraint(item: indicator, attribute: .bottom, relatedBy: .equal, toItem: background, attribute: .bottom, multiplier: 1, constant: -55))
                collectionView?.backgroundView = background
                currentPage += 1
                delegate?.loadNextPage(currentPage, searchTerm: nil, removeCurrentData: false)
            }
        }
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        searchBlock = DispatchQueue.main.asyncAfter(delay: searchBlockDelay) {
            self.delegate?.search(searchController.searchBar.text)
        }
        searchBlock?(true)
    }
    
    func collectionView(_ collectionView: UICollectionView,layout collectionViewLayout: UICollectionViewLayout,sizeForItemAt indexPath: IndexPath) -> CGSize {
        var width = (collectionView.bounds.width/CGFloat(2))-8
        if traitCollection.horizontalSizeClass == .regular
        {
            var items = 1
            while (collectionView.bounds.width/CGFloat(items))-8 > 195 {
                items += 1
            }
            width = (collectionView.bounds.width/CGFloat(items))-8
        }
        let ratio = width/195.0
        let height = 280.0 * ratio
        return CGSize(width: width, height: height)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return filterHeader?.isHidden == true ? CGSize(width: CGFloat.leastNormalMagnitude, height: CGFloat.leastNormalMagnitude): CGSize(width: view.frame.size.width, height: 50)
    }

}

extension UISearchController {
    open override var preferredStatusBarStyle : UIStatusBarStyle {
        // Fixes status bar color changing from black to white upon presentation.
        return .lightContent
    }
}
