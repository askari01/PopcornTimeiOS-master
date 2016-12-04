

import UIKit
import XCDYouTubeKit
import AlamofireImage
import ColorArt
import PopcornTorrent
import PopcornKit

class MovieDetailViewController: DetailItemOverviewViewController, PCTTablePickerViewDelegate, UIViewControllerTransitioningDelegate {
    
    @IBOutlet var torrentHealth: CircularView!
    @IBOutlet var qualityBtn: UIButton!
    @IBOutlet var subtitlesButton: UIButton!
    @IBOutlet var playButton: PCTBorderButton!
    @IBOutlet var watchedBtn: UIBarButtonItem!
    @IBOutlet var trailerBtn: UIButton!
    @IBOutlet var collectionView: UICollectionView!
    @IBOutlet var regularConstraints: [NSLayoutConstraint]!
    @IBOutlet var compactConstraints: [NSLayoutConstraint]!
    
    var currentItem: Movie!
    var relatedItems = [Movie]()
    var subtitlesTablePickerView: PCTTablePickerView!
    fileprivate var classContext = 0
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        WatchedlistManager.movie.syncTraktProgress()
        view.addObserver(self, forKeyPath: "frame", options: .new, context: &classContext)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.removeObserver(self, forKeyPath: "frame")
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        subtitlesTablePickerView?.setNeedsLayout()
        subtitlesTablePickerView?.layoutIfNeeded()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = currentItem.title
        watchedBtn.image = getWatchedButtonImage()
        scrollView.contentInset.bottom = tabBarController?.tabBar.frame.height ?? 0.0
        scrollView.scrollIndicatorInsets.bottom = tabBarController?.tabBar.frame.height ?? 0.0
        titleLabel.text = currentItem.title
        summaryView.text = currentItem.summary
        ratingView.rating = Float(currentItem.rating)
        infoLabel.text = "\(currentItem.year) ● \(currentItem.runtime) min ● \(currentItem.genres.first!.capitalized)"
        playButton.borderColor = SLColorArt(image: backgroundImageView.image).secondaryColor
        trailerBtn.isEnabled = currentItem.trailer != nil
        if currentItem.torrents.isEmpty {
//            PopcornKit.getMovieInfo(currentItem.id, currentItem.tmdbId) { (movie, error) in
//                guard let movie = movie else { self.qualityBtn?.setTitle("Error loading torrents.", for: .normal); return}
//                self.currentItem = movie
                self.updateTorrents()
//            }
        } else {
            updateTorrents()
        }
        SubtitlesManager.shared.search(imdbId: self.currentItem.id, completion: { (subtitles, error) in
            guard error == nil else { self.subtitlesButton.setTitle("Error loading subtitles", for: .normal); return }
            self.currentItem.subtitles = subtitles
            if subtitles.count == 0 {
                self.subtitlesButton.setTitle("No Subtitles Available", for: .normal)
            } else {
                self.subtitlesButton.setTitle("None ▾", for: .normal)
                self.subtitlesButton.isUserInteractionEnabled = true
                if let preferredSubtitle = UserDefaults.standard.object(forKey: "PreferredSubtitleLanguage") as? String , preferredSubtitle != "None" {
                    let languages = subtitles.map({$0.language})
                    let index = languages.index{$0 == languages.filter({$0 == preferredSubtitle}).first!}
                    let subtitle = self.currentItem.subtitles![index!]
                    self.currentItem.currentSubtitle = subtitle
                    self.subtitlesButton.setTitle(subtitle.language + " ▾", for: .normal)
                }
            }
            self.subtitlesTablePickerView = PCTTablePickerView(superView: self.view, sourceDict: Dictionary(keys: subtitles.map({$0.link}), values: subtitles.map({$0.language})), self)
            if let link = self.currentItem.currentSubtitle?.link {
                self.subtitlesTablePickerView.selectedItems = [link]
            }
            self.tabBarController?.view.addSubview(self.subtitlesTablePickerView)
        })
        TraktManager.shared.getRelated(currentItem) { (movies, _) in
            self.relatedItems = movies
            self.collectionView.reloadData()
        }
        TraktManager.shared.getPeople(forMediaOfType: .movies, id: currentItem.id) { (actors, crew, _) in
            self.currentItem.crew = crew
            self.currentItem.actors = actors
            self.collectionView.reloadData()
        }
    }
    
    func getWatchedButtonImage() -> UIImage {
        return WatchedlistManager.movie.isAdded(currentItem.id) ? UIImage(named: "WatchedOn")! : UIImage(named: "WatchedOff")!
    }
    
    func updateTorrents() {
        self.qualityBtn?.isUserInteractionEnabled = self.currentItem.torrents.count > 1
        self.currentItem.currentTorrent = self.currentItem.torrents.filter({$0.quality == UserDefaults.standard.string(forKey: "PreferredQuality")}).first ?? self.currentItem.torrents.first
        if let torrent = self.currentItem.currentTorrent {
            self.qualityBtn?.setTitle("\(torrent.quality! + (self.currentItem.torrents.count > 1 ? " ▾" : ""))", for: .normal)
        } else {
            self.qualityBtn?.setTitle("No torrents available.", for: .normal)
        }
        self.torrentHealth.backgroundColor = self.currentItem.currentTorrent?.health.color
        self.playButton.isEnabled = self.currentItem.currentTorrent?.url != nil
    }
    
    @IBAction func toggleWatched() {
        WatchedlistManager.movie.toggle(currentItem.id)
        watchedBtn.image = getWatchedButtonImage()
    }
    
    @IBAction func changeQualityTapped(_ sender: UIButton) {
        let quality = UIAlertController(title:"Select Quality", message:nil, preferredStyle:UIAlertControllerStyle.actionSheet)
        for torrent in currentItem.torrents {
            quality.addAction(UIAlertAction(title: "\(torrent.quality!) \(torrent.size!)", style: .default, handler: { action in
                self.currentItem.currentTorrent = torrent
                self.playButton.isEnabled = self.currentItem.currentTorrent?.url != nil
                self.qualityBtn.setTitle("\(torrent.quality!) ▾", for: .normal)
                self.torrentHealth.backgroundColor = torrent.health.color
            }))
        }
        quality.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        quality.popoverPresentationController?.sourceView = sender
        present(quality, animated: true, completion: nil)
    }
    
    @IBAction func changeSubtitlesTapped(_ sender: UIButton) {
        subtitlesTablePickerView.toggle()
    }
    
    @IBAction func watchNowTapped() {
        if UserDefaults.standard.bool(forKey: "StreamOnCellular") || (UIApplication.shared.delegate! as! AppDelegate).reachability!.isReachableViaWiFi() {
            guard let url = currentItem.currentTorrent?.url else { return }
            
            let currentProgress = WatchedlistManager.movie.currentProgress(currentItem.id)
            
            let loadingViewController = storyboard?.instantiateViewController(withIdentifier: "LoadingViewController") as! LoadingViewController
            loadingViewController.transitioningDelegate = self
            loadingViewController.backgroundImage = backgroundImageView.image
            present(loadingViewController, animated: true, completion: nil)
            
            let error: (String) -> Void = { [weak self] (errorMessage) in
                let alertVc = UIAlertController(title: "Error", message: errorMessage, preferredStyle: .alert)
                alertVc.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                self?.present(alertVc, animated: true, completion: nil)
            }
            
            let finishedLoading: (LoadingViewController, UIViewController) -> Void = { [weak self] (loadingVc, playerVc) in
                loadingVc.dismiss(animated: false, completion: nil)
                self?.present(playerVc, animated: true, completion: nil)
            }
            
            if GCKCastContext.sharedInstance().castState == .connected {
                let playViewController = self.storyboard?.instantiateViewController(withIdentifier: "CastPlayerViewController") as! CastPlayerViewController
                currentItem.playOnChromecast(fromFileOrMagnetLink: url, loadingViewController: loadingViewController, playViewController: playViewController, progress: currentProgress, errorBlock: error, finishedLoadingBlock: finishedLoading)
            } else {
                let playViewController = self.storyboard?.instantiateViewController(withIdentifier: "PCTPlayerViewController") as! PCTPlayerViewController
                playViewController.delegate = self
                currentItem.play(fromFileOrMagnetLink: url, loadingViewController: loadingViewController, playViewController: playViewController, progress: currentProgress, errorBlock: error, finishedLoadingBlock: finishedLoading)
            }
        } else {
            let errorAlert = UIAlertController(title: "Cellular Data is turned off for streaming", message: nil, preferredStyle: .alert)
            errorAlert.addAction(UIAlertAction(title: "Turn On", style: .default, handler: { [weak self] _ in
                UserDefaults.standard.set(true, forKey: "StreamOnCellular")
                self?.watchNowTapped()
            }))
            errorAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            self.present(errorAlert, animated: true, completion: nil)
        }
    }
    
	@IBAction func watchTrailerTapped() {
        let vc = XCDYouTubeVideoPlayerViewController(videoIdentifier: currentItem.trailerCode)
        present(vc, animated: true, completion: nil)
	}
    
    func tablePickerView(_ tablePickerView: PCTTablePickerView, didClose items: [String]) {
        if items.count == 0 {
            currentItem.currentSubtitle = nil
            subtitlesButton.setTitle("None ▾", for: .normal)
        } else {
            let links = currentItem.subtitles?.map({$0.link})
            let index = links?.index{$0 == links?.filter({$0 == items.first!}).first!}
            let subtitle = currentItem.subtitles![index!]
            currentItem.currentSubtitle = subtitle
            subtitlesButton.setTitle(subtitle.language + " ▾", for: .normal)
        }
    }
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return presented is LoadingViewController ? PCTLoadingViewAnimatedTransitioning(isPresenting: true, sourceController: source) : nil
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return dismissed is LoadingViewController ? PCTLoadingViewAnimatedTransitioning(isPresenting: false, sourceController: self) : nil
    }
}

extension MovieDetailViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 ? relatedItems.count : currentItem.actors.count
    }
    
    func collectionView(_ collectionView: UICollectionView,layout collectionViewLayout: UICollectionViewLayout,sizeForItemAt indexPath: IndexPath) -> CGSize {
        var items = 1
        while (collectionView.bounds.width/CGFloat(items))-8 > 195 {
            items += 1
        }
        let width = (collectionView.bounds.width/CGFloat(items))-8
        let ratio = width/195.0
        let height = 280.0 * ratio
        return CGSize(width: width, height: height)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if &classContext == context && keyPath == "frame" {
            collectionView.collectionViewLayout.invalidateLayout()
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: UICollectionViewCell
        if indexPath.section == 0 {
            cell = {
               let coverCell = collectionView.dequeueReusableCell(withReuseIdentifier: "relatedCell", for: indexPath) as! CoverCollectionViewCell
                coverCell.titleLabel.text = relatedItems[indexPath.row].title
                coverCell.yearLabel.text = relatedItems[indexPath.row].year
                if let image = relatedItems[indexPath.row].smallCoverImage,
                    let url = URL(string: image) {
                    coverCell.coverImage.af_setImage(withURL: url, placeholderImage: UIImage(named: "Placeholder"))
                }
                coverCell.watched = WatchedlistManager.movie.isAdded(relatedItems[indexPath.row].id)
                return coverCell
            }()
        } else {
            cell = collectionView.dequeueReusableCell(withReuseIdentifier: "castCell", for: indexPath)
            let imageView = cell.viewWithTag(1) as! UIImageView
            if let image = currentItem.actors[indexPath.row].smallImage,
                let url = URL(string: image) {
                imageView.af_setImage(withURL: url, placeholderImage: UIImage(named: "Placeholder"))
            } else {
                imageView.image = UIImage(named: "Placeholder")
            }
            imageView.layer.cornerRadius = self.collectionView(collectionView, layout: collectionView.collectionViewLayout, sizeForItemAt: indexPath).width/2
            (cell.viewWithTag(2) as! UILabel).text = currentItem.actors[indexPath.row].name
            (cell.viewWithTag(3) as! UILabel).text = currentItem.actors[indexPath.row].characterName
        }
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            let movieDetail = storyboard?.instantiateViewController(withIdentifier: "MovieDetailViewController") as! MovieDetailViewController
            movieDetail.currentItem = relatedItems[indexPath.row]
            navigationController?.pushViewController(movieDetail, animated: true)
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if let coverImageAsString = currentItem.mediumCoverImage,
            let backgroundImageAsString = currentItem.largeBackgroundImage {
            backgroundImageView.af_setImage(withURLRequest: URLRequest(url: URL(string: traitCollection.horizontalSizeClass == .compact ? coverImageAsString : backgroundImageAsString)!), placeholderImage: UIImage(named: "Placeholder"), imageTransition: .crossDissolve(animationLength), completion: {
                if let value = $0.result.value {
                    self.playButton.borderColor = SLColorArt(image: value).secondaryColor
                }
            })
        }
        
        for constraint in compactConstraints {
            constraint.priority = traitCollection.horizontalSizeClass == .compact ? 999 : 240
        }
        for constraint in regularConstraints {
            constraint.priority = traitCollection.horizontalSizeClass == .compact ? 240 : 999
        }
        UIView.animate(withDuration: animationLength, animations: {
            self.view.layoutIfNeeded()
            self.collectionView.collectionViewLayout.invalidateLayout()
        })
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionElementKindSectionHeader {
            return {
               let element = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header", for: indexPath)
                let label = (element.viewWithTag(1) as! UILabel)
                label.text = ""
                if indexPath.section == 0 && !relatedItems.isEmpty {
                    label.text = "RELATED"
                } else if indexPath.section == 1 && !currentItem.actors.isEmpty {
                    label.text = "CAST"
                }
                return element
            }()
        }
        return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "footer", for: indexPath)
    }
    
    override func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return collectionView.gestureRecognizers?.filter({$0 == gestureRecognizer || $0 == otherGestureRecognizer}).first == nil
    }
}
