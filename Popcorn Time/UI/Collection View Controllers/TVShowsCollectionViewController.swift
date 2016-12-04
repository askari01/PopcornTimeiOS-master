

import UIKit
import AlamofireImage
import PopcornKit

class TVShowsCollectionViewController: ItemOverviewCollectionViewController, UIPopoverPresentationControllerDelegate, GenresDelegate, ItemOverviewDelegate {
    
    var shows = [Show]()
    
    var currentGenre = ShowManager.Genres.all {
        didSet {
            shows.removeAll()
            collectionView?.reloadData()
            currentPage = 1
            loadNextPage(currentPage)
        }
    }
    var currentFilter = ShowManager.Filters.trending {
        didSet {
            shows.removeAll()
            collectionView?.reloadData()
            currentPage = 1
            loadNextPage(currentPage)
        }
    }
    
    @IBAction func searchBtnPressed(_ sender: UIBarButtonItem) {
        present(searchController, animated: true, completion: nil)
    }
    
    @IBAction func filter(_ sender: AnyObject) {
        self.collectionView?.performBatchUpdates({
            self.filterHeader!.isHidden = !self.filterHeader!.isHidden
            }, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        loadNextPage(currentPage)
    }
    
    func segmentedControlDidChangeSegment(_ segmentedControl: UISegmentedControl) {
        currentFilter = ShowManager.Filters.array[segmentedControl.selectedSegmentIndex]
    }
    
    // MARK: - ItemOverviewDelegate
    
    func loadNextPage(_ pageNumber: Int, searchTerm: String? = nil, removeCurrentData: Bool = false) {
        guard !isLoading else { return }
        isLoading = true
        hasNextPage = false
        PopcornKit.loadShows(currentPage, filterBy: currentFilter, genre: currentGenre, searchTerm: searchTerm, completion: { (shows, error) in
            self.isLoading = false
            guard let shows = shows else { self.error = error; self.collectionView?.reloadData(); return }
            if removeCurrentData {
                self.shows.removeAll()
            }
            self.shows += shows
            if shows.isEmpty // If the array passed in is empty, there are no more results so the content inset of the collection view is reset.
            {
                self.collectionView?.contentInset.bottom = 0.0
            } else {
                self.hasNextPage = true
            }
            self.collectionView?.reloadData()
        })
    }
    
    func didDismissSearchController(_ searchController: UISearchController) {
        self.shows.removeAll()
        collectionView?.reloadData()
        self.currentPage = 1
        loadNextPage(self.currentPage)
    }
    
    func search(_ text: String?) {
        self.shows.removeAll()
        collectionView?.reloadData()
        self.currentPage = 1
        self.loadNextPage(self.currentPage, searchTerm: text)
    }
    
    func shouldRefreshCollectionView() -> Bool {
        return shows.isEmpty
    }
    
    // MARK: - Navigation
    
    @IBAction func genresButtonTapped(_ sender: UIBarButtonItem) {
        let controller = cache.object(forKey: Trakt.MediaType.shows.rawValue as AnyObject) ?? (storyboard?.instantiateViewController(withIdentifier: "GenresNavigationController"))! as! UINavigationController
        cache.setObject(controller, forKey: Trakt.MediaType.shows.rawValue as AnyObject)
        controller.modalPresentationStyle = .popover
        controller.popoverPresentationController?.barButtonItem = sender
        controller.popoverPresentationController?.backgroundColor = UIColor(red: 30.0/255.0, green: 30.0/255.0, blue: 30.0/255.0, alpha: 1.0)
        (controller.viewControllers.first as! GenresTableViewController).delegate = self
        present(controller, animated: true, completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            (segue.destination as! TVShowContainerViewController).currentItem = shows[(collectionView?.indexPath(for: sender as! CoverCollectionViewCell)?.row)!]
        }
    }
    
    // MARK: - Collection view data source
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        collectionView.backgroundView = nil
        if shows.count == 0 {
            if error != nil {
                let background = Bundle.main.loadNibNamed("TableViewBackground", owner: self, options: nil)?.first as! TableViewBackground
                background.setUpView(error: error!)
                collectionView.backgroundView = background
            } else if isLoading {
                let indicator = UIActivityIndicatorView(activityIndicatorStyle: .white)
                indicator.center = collectionView.center
                collectionView.backgroundView = indicator
                indicator.sizeToFit()
                indicator.startAnimating()
            } else {
                let background = Bundle.main.loadNibNamed("TableViewBackground", owner: self, options: nil)?.first as! TableViewBackground
                background.setUpView(image: UIImage(named: "Search")!, title: "No results found.", description: "No search results found for \(searchController.searchBar.text!). Please check the spelling and try again.")
                collectionView.backgroundView = background
            }
        }
        return 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return shows.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! CoverCollectionViewCell
        cell.titleLabel.text = shows[indexPath.row].title
        cell.yearLabel.text = shows[indexPath.row].year
        if let image = shows[indexPath.row].mediumCoverImage,
            let url = URL(string: image) {
            cell.coverImage.af_setImage(withURL: url, placeholderImage: UIImage(named: "Placeholder"), imageTransition: .crossDissolve(animationLength))
        }
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        filterHeader = filterHeader ?? {
            let reuseableView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "filter", for: indexPath) as! FilterCollectionReusableView
            reuseableView.segmentedControl?.removeAllSegments()
            for (index, filterValue) in ShowManager.Filters.array.enumerated() {
                reuseableView.segmentedControl?.insertSegment(withTitle: filterValue.string, at: index, animated: false)
            }
            reuseableView.isHidden = true
            reuseableView.segmentedControl?.addTarget(self, action: #selector(segmentedControlDidChangeSegment(_:)), for: .valueChanged)
            reuseableView.segmentedControl?.selectedSegmentIndex = 0
            return reuseableView
            }()
        return filterHeader!
    }
    
    // MARK: - GenresDelegate
    
    func finished(_ genreArrayIndex: Int) {
        navigationItem.title = ShowManager.Genres.array[genreArrayIndex].rawValue
        if ShowManager.Genres.array[genreArrayIndex] == .all {
            navigationItem.title = "Shows"
        }
        currentGenre = ShowManager.Genres.array[genreArrayIndex]
    }
    
    func populateDataSourceArray(_ array: inout [String]) {
        array = ShowManager.Genres.array.map({$0.rawValue})
    }
}

class TVShowContainerViewController: UIViewController {
    
    var currentItem: Show!
    var currentType: Trakt.MediaType = .shows
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            let vc = (segue.destination as! UISplitViewController).viewControllers.first as! TVShowDetailViewController
            vc.currentItem = currentItem
            vc.currentType = currentType
            vc.parentTabBarController = tabBarController
            vc.parentNavigationController = navigationController
            navigationItem.rightBarButtonItems = vc.navigationItem.rightBarButtonItems
            vc.parentNavigationItem = navigationItem
        }
    }
}
