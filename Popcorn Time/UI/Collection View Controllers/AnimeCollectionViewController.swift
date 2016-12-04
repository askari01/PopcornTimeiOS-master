

import UIKit
import AlamofireImage
import PopcornKit

class AnimeCollectionViewController: ItemOverviewCollectionViewController, UIPopoverPresentationControllerDelegate, GenresDelegate, ItemOverviewDelegate {
    
    var anime = [Show]()
    
    var currentGenre = AnimeManager.Genres.all {
        didSet {
            anime.removeAll()
            collectionView?.reloadData()
            currentPage = 1
            loadNextPage(currentPage)
        }
    }
    var currentFilter = AnimeManager.Filters.popularity {
        didSet {
            anime.removeAll()
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
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let collectionView = object as? UICollectionView , collectionView == self.collectionView! && keyPath! == "frame" {
            collectionView.performBatchUpdates(nil, completion: nil)
        }
    }
    
    func segmentedControlDidChangeSegment(_ segmentedControl: UISegmentedControl) {
        currentFilter = AnimeManager.Filters.array[segmentedControl.selectedSegmentIndex]
    }
    
    // MARK: - ItemOverviewDelegate
    
    func loadNextPage(_ pageNumber: Int, searchTerm: String? = nil, removeCurrentData: Bool = false) {
        guard !isLoading else { return }
        isLoading = true
        hasNextPage = false
        PopcornKit.loadAnime(currentPage, filterBy: currentFilter, genre: currentGenre, searchTerm: searchTerm, completion: { (anime, error) in
            self.isLoading = false
            guard let anime = anime else { self.error = error; self.collectionView?.reloadData(); return }
            if removeCurrentData {
                self.anime.removeAll()
            }
            self.anime += anime
            if anime.isEmpty // If the array passed in is empty, there are no more results so the content inset of the collection view is reset.
            {
                self.collectionView?.contentInset.bottom = 0.0
            } else {
                self.hasNextPage = true
            }
            self.collectionView?.reloadData()
        })
    }
    
    func didDismissSearchController(_ searchController: UISearchController) {
        self.anime.removeAll()
        collectionView?.reloadData()
        self.currentPage = 1
        loadNextPage(self.currentPage)
    }
    
    func search(_ text: String?) {
        self.anime.removeAll()
        collectionView?.reloadData()
        self.currentPage = 1
        self.loadNextPage(self.currentPage, searchTerm: text)
    }
    
    func shouldRefreshCollectionView() -> Bool {
        return anime.isEmpty
    }
    
    // MARK: - Navigation
    
    @IBAction func genresButtonTapped(_ sender: UIBarButtonItem) {
        let controller = cache.object(forKey: Trakt.MediaType.animes.rawValue as AnyObject) ?? (storyboard?.instantiateViewController(withIdentifier: "GenresNavigationController"))! as! UINavigationController
        cache.setObject(controller, forKey: Trakt.MediaType.animes.rawValue as AnyObject)
        controller.modalPresentationStyle = .popover
        controller.popoverPresentationController?.barButtonItem = sender
        controller.popoverPresentationController?.backgroundColor = UIColor(red: 30.0/255.0, green: 30.0/255.0, blue: 30.0/255.0, alpha: 1.0)
        (controller.viewControllers.first as! GenresTableViewController).delegate = self
        present(controller, animated: true, completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            let vc = segue.destination as! TVShowContainerViewController
            vc.currentItem = anime[collectionView!.indexPath(for: sender as! CoverCollectionViewCell)!.row]
            vc.currentType = .animes
        }
    }
    
    // MARK: - Collection view data source
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        collectionView.backgroundView = nil
        if anime.count == 0 {
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
        return anime.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! CoverCollectionViewCell
        cell.titleLabel.text = anime[indexPath.row].title
        cell.yearLabel.text = anime[indexPath.row].year
        if let image = anime[indexPath.row].smallCoverImage,
            let url = URL(string: image) {
            cell.coverImage.af_setImage(withURL: url, placeholderImage: UIImage(named: "Placeholder"), imageTransition: .crossDissolve(animationLength))
        }
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        filterHeader = filterHeader ?? {
            let reuseableView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "filter", for: indexPath) as! FilterCollectionReusableView
            reuseableView.segmentedControl?.removeAllSegments()
            for (index, filterValue) in AnimeManager.Filters.array.enumerated() {
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
        navigationItem.title = AnimeManager.Genres.array[genreArrayIndex].rawValue
        if AnimeManager.Genres.array[genreArrayIndex] == .all {
            navigationItem.title = "Anime"
        }
        currentGenre = AnimeManager.Genres.array[genreArrayIndex]
    }
    
    func populateDataSourceArray(_ array: inout [String]) {
        array = AnimeManager.Genres.array.map({$0.rawValue})
    }
}
