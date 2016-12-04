

import UIKit
import AlamofireImage
import ColorArt
import PopcornKit
import PopcornTorrent

class TVShowDetailViewController: DetailItemOverviewViewController, UITableViewDataSource, UITableViewDelegate, UIViewControllerTransitioningDelegate {
    
    @IBOutlet var segmentedControl: UISegmentedControl!
    @IBOutlet var tableHeaderView: UIView!
    
    override var minimumHeight: CGFloat {
        get {
            return super.minimumHeight + 46.0
        }
    }
    
    let interactor = PCTEpisodeDetailPercentDrivenInteractiveTransition()

    var currentType: Trakt.MediaType = .shows
    var currentItem: Show!
    var episodesLeftInShow: [Episode]!
    
    /* Because UISplitViewControllers are not meant to be pushed to the navigation heirarchy, we are tricking it into thinking it is a root view controller when in fact it is just a childViewController of TVShowContainerViewController. Because of the fact that child view controllers should not be aware of their container view controllers, this variable had to be created to access the navigationController and the tabBarController of the viewController. In order to further trick the view controller, navigationController, navigationItem and tabBarController properties have been overridden to point to their corrisponding parent properties.
     */
    var parentTabBarController: UITabBarController?
    var parentNavigationController: UINavigationController?
    var parentNavigationItem: UINavigationItem?
    
    override var navigationItem: UINavigationItem {
        return parentNavigationItem ?? super.navigationItem
    }
    
    override var navigationController: UINavigationController? {
        return parentNavigationController
    }
    
    override var tabBarController: UITabBarController? {
        return parentTabBarController
    }
    
    var currentSeason: Int! {
        didSet {
            self.tableView.reloadData()
        }
    }
    var currentSeasonArray = [Episode]()
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.frame.size.width = splitViewController?.primaryColumnWidth ?? view.bounds.width
        WatchedlistManager.episode.syncTraktProgress()
        WatchedlistManager.show.getWatched() {
            self.tableView.reloadData()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.frame.size.width = UIScreen.main.bounds.width
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        navigationController?.navigationBar.frame.size.width = splitViewController?.primaryColumnWidth ?? view.bounds.width
        splitViewController?.minimumPrimaryColumnWidth = UIScreen.main.bounds.width/1.7
        splitViewController?.maximumPrimaryColumnWidth = UIScreen.main.bounds.width/1.7
        self.tableView.sizeHeaderToFit()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        splitViewController?.delegate = self
        splitViewController?.preferredDisplayMode = .allVisible
        let adjustForTabbarInsets = UIEdgeInsetsMake(0, 0, tabBarController!.tabBar.frame.height, 0)
        tableView.contentInset = adjustForTabbarInsets
        tableView.scrollIndicatorInsets = adjustForTabbarInsets
        tableView.rowHeight = UITableViewAutomaticDimension
        titleLabel.text = currentItem.title
        navigationItem.title = currentItem.title
        infoLabel.text = currentItem.year
        ratingView.rating = currentItem.rating
        let completion: (Show?, NSError?) -> Void = { (show, error) in
            guard let show = show else { return }
            self.currentItem = show
            self.summaryView.text = self.currentItem.summary
            self.infoLabel.text = "\(self.currentItem.year) ● \(self.currentItem.status!.capitalized) ● \(self.currentItem.genres.first!.capitalized)"
            self.setUpSegmenedControl()
            self.tableView.reloadData()
        }
        if currentType == .animes {
            PopcornKit.getAnimeInfo(currentItem.id, completion: completion)
        } else {
            PopcornKit.getShowInfo(currentItem.id, completion: completion)
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if let coverImageAsString = currentItem.mediumCoverImage,
            let backgroundImageAsString = currentItem.largeBackgroundImage {
            backgroundImageView.af_setImage(withURLRequest: URLRequest(url: URL(string: splitViewController?.traitCollection.horizontalSizeClass == .compact ? coverImageAsString : backgroundImageAsString)!), placeholderImage: UIImage(named: "Placeholder"), imageTransition: .crossDissolve(animationLength))
        }
    }
    
    // MARK: - UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if segmentedControl.selectedSegmentIndex == 0 {
            tableView.tableHeaderView = tableHeaderView
            return 0
        }
        tableView.tableHeaderView = nil
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if !currentItem.episodes.isEmpty {
            currentSeasonArray.removeAll()
            currentSeasonArray = getGroupedEpisodesBySeason(currentSeason)
            return currentSeasonArray.count
        }
        return 0
    }
    
    func getGroupedEpisodesBySeason(_ season: Int) -> [Episode] {
        var array = [Episode]()
        for index in currentItem.seasonNumbers {
            if season == index {
                array += currentItem.episodes.filter({$0.season == index})
            }
        }
        return array
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TVShowDetailTableViewCell
        cell.titleLabel.text = currentSeasonArray[indexPath.row].title
        cell.seasonLabel.text = "E" + String(currentSeasonArray[indexPath.row].episode)
        cell.tvdbId = currentSeasonArray[indexPath.row].id
        return cell
    }
    
    
    // MARK: - SegmentedControl
    
    func setUpSegmenedControl() {
        segmentedControl.removeAllSegments()
        segmentedControl.insertSegment(withTitle: "ABOUT", at: 0, animated: true)
        for index in currentItem.seasonNumbers {
            segmentedControl.insertSegment(withTitle: "SEASON \(index)", at: index, animated: true)
        }
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.setTitleTextAttributes([NSFontAttributeName: UIFont.systemFont(ofSize: 11, weight: UIFontWeightMedium)],for: .normal)
        segmentedControlDidChangeSegment(segmentedControl)
    }
    
    @IBAction func segmentedControlDidChangeSegment(_ segmentedControl: UISegmentedControl) {
        currentSeason = segmentedControl.selectedSegmentIndex == 0 ? Int.max: currentItem.seasonNumbers[segmentedControl.selectedSegmentIndex - 1]
        if tableView.frame.height > tableView.contentSize.height + tableView.contentInset.bottom {
            resetToEnd(tableView)
        }
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if segue.identifier == "showDetail" {
            let indexPath = tableView.indexPath(for: sender as! TVShowDetailTableViewCell)
            let destinationController = segue.destination as! EpisodeDetailViewController
            destinationController.currentItem = currentSeasonArray[indexPath!.row]
            var allEpisodes = [Episode]()
            for index in segmentedControl.selectedSegmentIndex..<segmentedControl.numberOfSegments {
                let season = currentItem.seasonNumbers[index - 1]
                allEpisodes += getGroupedEpisodesBySeason(season)
                if season == currentSeason // Remove episodes up to the next episode eg. If row 2 is selected, row 0-2 will be deleted.
                {
                    allEpisodes.removeFirst(indexPath!.row + 1)
                }
            }
            episodesLeftInShow = allEpisodes
            destinationController.delegate = self
            destinationController.transitioningDelegate = self
            destinationController.modalPresentationStyle = .custom
            destinationController.interactor = interactor
        }
    }
    
    func loadMovieTorrent(_ media: Episode, animated: Bool, onChromecast: Bool = GCKCastContext.sharedInstance().castState == .connected) {
        let loadingViewController = storyboard!.instantiateViewController(withIdentifier: "LoadingViewController") as! LoadingViewController
        loadingViewController.transitioningDelegate = self
        loadingViewController.backgroundImage = backgroundImageView.image
        present(loadingViewController, animated: animated, completion: nil)
        PopcornKit.downloadTorrentFile(media.currentTorrent!.url) { [unowned self] (url, error) in
            if let url = url {
                let moviePlayer = self.storyboard!.instantiateViewController(withIdentifier: "PCTPlayerViewController") as! PCTPlayerViewController
                moviePlayer.delegate = self
                let currentProgress = WatchedlistManager.episode.currentProgress(media.id)
                let castDevice = GCKCastContext.sharedInstance().sessionManager.currentSession?.device
                PTTorrentStreamer.shared().startStreaming(fromFileOrMagnetLink: url, progress: { status in
                    loadingViewController.progress = status.bufferingProgress
                    loadingViewController.speed = Int(status.downloadSpeed)
                    loadingViewController.seeds = Int(status.seeds)
                    moviePlayer.bufferProgressView?.progress = status.totalProgreess
                    }, readyToPlay: {(videoFileURL, videoFilePath) in
                        loadingViewController.dismiss(animated: false, completion: nil)
                        var nextEpisode: Episode? = nil
                        if self.episodesLeftInShow.count > 0 {
                            nextEpisode = self.episodesLeftInShow.first
                            self.episodesLeftInShow.removeFirst()
                        }
                        if onChromecast {
                            if GCKCastContext.sharedInstance().sessionManager.currentSession == nil {
                                GCKCastContext.sharedInstance().sessionManager.startSession(with: castDevice!)
                            }
                            let castPlayerViewController = self.storyboard?.instantiateViewController(withIdentifier: "CastPlayerViewController") as! CastPlayerViewController
                            let castMetadata: CastMetaData = (title: media.title, image: media.show!.smallCoverImage != nil ? URL(string: media.show!.smallCoverImage!) : nil, contentType: "video/x-matroska", subtitles: media.subtitles, url: videoFileURL.relativeString, mediaAssetsPath: videoFilePath.deletingLastPathComponent())
                            GoogleCastManager(castMetadata: castMetadata).sessionManager(GCKCastContext.sharedInstance().sessionManager, didStart: GCKCastContext.sharedInstance().sessionManager.currentSession!)
                            castPlayerViewController.backgroundImage = self.backgroundImageView.image
                            castPlayerViewController.title = media.title
                            castPlayerViewController.media = media
                            castPlayerViewController.startPosition = TimeInterval(currentProgress)
                            castPlayerViewController.directory = videoFilePath.deletingLastPathComponent()
                            self.present(castPlayerViewController, animated: true, completion: nil)
                        } else {
                            moviePlayer.play(media, fromURL: videoFileURL, progress: currentProgress, nextEpisode: nextEpisode, directory: videoFilePath.deletingLastPathComponent())
                            self.present(moviePlayer, animated: true, completion: nil)
                        }
                }) { error in
                    loadingViewController.cancelButtonPressed()
                    let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                    print("Error is \(error)")
                }
            } else if let error = error {
                loadingViewController.dismiss(animated: true, completion: { [unowned self] in
                    let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                })
            }
        }
    }
    
    override func playNext(_ episode: Episode) {
        var episode = episode; episode.currentTorrent = episode.currentTorrent ?? episode.torrents.first!
        loadMovieTorrent(episode, animated: false)
    }
    
    // MARK: - Presentation
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if presented is LoadingViewController {
            return PCTLoadingViewAnimatedTransitioning(isPresenting: true, sourceController: source)
        } else if presented is EpisodeDetailViewController {
            return PCTEpisodeDetailAnimatedTransitioning(isPresenting: true)
        }
        return nil
        
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if dismissed is LoadingViewController {
            return PCTLoadingViewAnimatedTransitioning(isPresenting: false, sourceController: self)
        } else if dismissed is EpisodeDetailViewController {
            return PCTEpisodeDetailAnimatedTransitioning(isPresenting: false)
        }
        return nil
    }
    
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return presented is EpisodeDetailViewController ? PCTEpisodeDetailPresentationController(presentedViewController: presented, presenting: presenting) : nil
    }
    
    func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        if animator is PCTEpisodeDetailAnimatedTransitioning && interactor.hasStarted && splitViewController!.isCollapsed  {
            return interactor
        }
        return nil
    }
}

extension TVShowDetailViewController: UISplitViewControllerDelegate {
    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        guard let secondaryViewController = secondaryViewController as? EpisodeDetailViewController , secondaryViewController.currentItem != nil else { return false }
        primaryViewController.present(secondaryViewController, animated: true, completion: nil)
        return true
    }
    
    func splitViewController(_ splitViewController: UISplitViewController, separateSecondaryFrom primaryViewController: UIViewController) -> UIViewController? {
        if primaryViewController.presentedViewController is EpisodeDetailViewController {
            return primaryViewController.presentedViewController
        }
        return nil
    }
}
