

import UIKit
import AlamofireImage
import PopcornKit

class MoviesCollectionViewController: ItemOverviewCollectionViewController, UIPopoverPresentationControllerDelegate, GenresDelegate, ItemOverviewDelegate {
    
    var movies = [Movie]()
    
    var currentGenre = MovieManager.Genres.all {
        didSet {
            movies.removeAll()
            collectionView?.reloadData()
            currentPage = 1
            loadNextPage(currentPage)
        }
    }
    var currentFilter = MovieManager.Filters.trending {
        didSet {
            movies.removeAll()
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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        WatchedlistManager.movie.getWatched() {
            self.collectionView?.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        loadNextPage(currentPage)
    }
    
    func segmentedControlDidChangeSegment(_ segmentedControl: UISegmentedControl) {
        currentFilter = MovieManager.Filters.array[segmentedControl.selectedSegmentIndex]
    }
    
    // MARK: - ItemOverviewDelegate
    
    func loadNextPage(_ pageNumber: Int, searchTerm: String? = nil, removeCurrentData: Bool = false) {
        guard !isLoading else { return }
        isLoading = true
        hasNextPage = false
        PopcornKit.loadMovies(currentPage, filterBy: currentFilter, genre: currentGenre, searchTerm: searchTerm) { (movies, error) in
            self.isLoading = false
            guard let movies = movies else { self.error = error; self.collectionView?.reloadData(); return }
            if removeCurrentData {
                self.movies.removeAll()
            }
            self.movies += movies
            if movies.isEmpty // If the array passed in is empty, there are no more results so the content inset of the collection view is reset.
            {
                self.collectionView?.contentInset.bottom = 0.0
            } else {
                self.hasNextPage = true
            }
            self.collectionView?.reloadData()
        }
    }
    
    func didDismissSearchController(_ searchController: UISearchController) {
        movies.removeAll()
        collectionView?.reloadData()
        currentPage = 1
        loadNextPage(currentPage)
    }
    
    func search(_ text: String?) {
        movies.removeAll()
        collectionView?.reloadData()
        currentPage = 1
        loadNextPage(currentPage, searchTerm: text)
    }
    
    func shouldRefreshCollectionView() -> Bool {
        return movies.isEmpty
    }
    
    // MARK: - Navigation
    
    @IBAction func genresButtonTapped(_ sender: UIBarButtonItem) {
        let controller = cache.object(forKey: Trakt.MediaType.movies.rawValue as AnyObject) ?? (storyboard?.instantiateViewController(withIdentifier: "GenresNavigationController"))! as! UINavigationController
        cache.setObject(controller, forKey: Trakt.MediaType.movies.rawValue as AnyObject)
        controller.modalPresentationStyle = .popover
        controller.popoverPresentationController?.barButtonItem = sender
        controller.popoverPresentationController?.backgroundColor = UIColor(red: 30.0/255.0, green: 30.0/255.0, blue: 30.0/255.0, alpha: 1.0)
        (controller.viewControllers.first as! GenresTableViewController).delegate = self
        present(controller, animated: true, completion: nil)
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            let movieDetail = segue.destination as! MovieDetailViewController
            let cell = sender as! CoverCollectionViewCell
            movieDetail.currentItem = self.movies[(collectionView?.indexPath(for: cell)?.row)!]
        }
    }
    
    // MARK: - Collection view data source
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        collectionView.backgroundView = nil
        if movies.count == 0 {
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
        return movies.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! CoverCollectionViewCell
        if let image = movies[indexPath.row].mediumCoverImage,
            let url = URL(string: image) {
            cell.coverImage.af_setImage(withURL: url, placeholderImage: UIImage(named: "Placeholder"), imageTransition: .crossDissolve(animationLength))
        }
        cell.titleLabel.text = movies[indexPath.row].title
        cell.yearLabel.text = movies[indexPath.row].year
        cell.watched = WatchedlistManager.movie.isAdded(movies[indexPath.row].id)
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        filterHeader = filterHeader ?? {
            let reuseableView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "filter", for: indexPath) as! FilterCollectionReusableView
            reuseableView.segmentedControl?.removeAllSegments()
            for (index, filterValue) in MovieManager.Filters.array.enumerated() {
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
        navigationItem.title = MovieManager.Genres.array[genreArrayIndex].rawValue
        if MovieManager.Genres.array[genreArrayIndex] == .all {
            navigationItem.title = "Movies"
        }
        currentGenre = MovieManager.Genres.array[genreArrayIndex]
    }
    
    func populateDataSourceArray(_ array: inout [String]) {
        array = MovieManager.Genres.array.map({$0.rawValue})
    }
}
