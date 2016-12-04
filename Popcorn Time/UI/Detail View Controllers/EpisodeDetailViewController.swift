

import UIKit
import AlamofireImage
import PopcornKit

protocol EpisodeDetailViewControllerDelegate: class {
    func didDismissViewController(_ vc: EpisodeDetailViewController)
    func loadMovieTorrent(_ media: Episode, animated: Bool, onChromecast: Bool)
}

class EpisodeDetailViewController: UIViewController, PCTTablePickerViewDelegate, UIGestureRecognizerDelegate {
    
    @IBOutlet var backgroundImageView: UIImageView?
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var episodeAndSeasonLabel: UILabel!
    @IBOutlet var summaryView: UITextView!
    @IBOutlet var infoLabel: UILabel!
    @IBOutlet var qualityBtn: UIButton?
    @IBOutlet var playNowBtn: PCTBorderButton?
    @IBOutlet var subtitlesButton: UIButton!
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var torrentHealth: CircularView!
    @IBOutlet var heightConstraint: NSLayoutConstraint!
    
    var currentItem: Episode?
    var subtitlesTablePickerView: PCTTablePickerView!
    
    weak var delegate: EpisodeDetailViewControllerDelegate?
    var interactor: PCTEpisodeDetailPercentDrivenInteractiveTransition?
    
    override var navigationController: UINavigationController? {
        return splitViewController?.viewControllers.first?.navigationController
    }
    
    override var tabBarController: UITabBarController? {
        return splitViewController?.viewControllers.first?.tabBarController
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if transitionCoordinator?.viewController(forKey: UITransitionContextViewControllerKey.to) == self.presentingViewController {
            delegate?.didDismissViewController(self)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let adjustForTabbarInsets = tabBarController?.tabBar.frame.height ?? 0
        scrollView.contentInset.bottom = adjustForTabbarInsets
        scrollView.scrollIndicatorInsets.bottom = adjustForTabbarInsets
        subtitlesTablePickerView?.tableView.contentInset.bottom = adjustForTabbarInsets
        heightConstraint.constant = UIScreen.main.bounds.height * 0.35
        subtitlesTablePickerView?.setNeedsLayout()
        subtitlesTablePickerView?.layoutIfNeeded()
        preferredContentSize = scrollView.contentSize
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        heightConstraint.constant = UIScreen.main.bounds.height * 0.35
        if var currentItem = currentItem {
            TraktManager.shared.getEpisodeMetadata(currentItem.show.id, episodeNumber: currentItem.episode, seasonNumber: currentItem.season, completion: { ( _, imdb, error) in
                guard let imdb = imdb else { return }
                SubtitlesManager.shared.search(imdbId: imdb, completion: { (subtitles, error) in
                    guard error == nil else { self.subtitlesButton.setTitle("Error loading subtitles.", for: .normal); return }
                    currentItem.subtitles = subtitles
                    if subtitles.isEmpty {
                        self.subtitlesButton.setTitle("No Subtitles Available", for: .normal)
                    } else {
                        self.subtitlesButton.setTitle("None ▾", for: .normal)
                        self.subtitlesButton.isUserInteractionEnabled = true
                        if let preferredSubtitle = UserDefaults.standard.object(forKey: "PreferredSubtitleLanguage") as? String , preferredSubtitle != "None" {
                            let languages = subtitles.map({$0.language})
                            let index = languages.index{$0 == languages.filter({$0 == preferredSubtitle}).first!}
                            let subtitle = currentItem.subtitles![index!]
                            currentItem.currentSubtitle = subtitle
                            self.subtitlesButton.setTitle(subtitle.language + " ▾", for: .normal)
                        }
                    }
                    self.subtitlesTablePickerView = PCTTablePickerView(superView: self.view, sourceDict: Dictionary(keys: subtitles.map({$0.link}), values: subtitles.map({$0.language})), self)
                    if let link = currentItem.currentSubtitle?.link {
                        self.subtitlesTablePickerView.selectedItems = [link]
                    }
                    self.view.addSubview(self.subtitlesTablePickerView)
                })
            })
            TMDBManager.shared.getEpisodeScreenshots(forShowWithImdbId: currentItem.show.id, orTMDBId: currentItem.show.tmdbId, season: currentItem.season, episode: currentItem.episode, completion: { (tmdb, image, error) in
                if let tmdb = tmdb { currentItem.show.tmdbId = tmdb }
                if let image = image,
                    let url = URL(string: image) {
                    currentItem.largeBackgroundImage = image
                    self.backgroundImageView!.af_setImage(withURL: url, placeholderImage: UIImage(named: "Placeholder"), imageTransition: .crossDissolve(animationLength))
                }
            })
            titleLabel.text = currentItem.title
            var season = String(currentItem.season)
            season = season.characters.count == 1 ? "0" + season : season
            var episode = String(currentItem.episode)
            episode = episode.characters.count == 1 ? "0" + episode : episode
            episodeAndSeasonLabel.text = "S\(season)E\(episode)"
            summaryView.text = currentItem.summary
            if let date = currentItem.firstAirDate {
                infoLabel.text = "Aired: " + DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
            }
            qualityBtn?.isUserInteractionEnabled = currentItem.torrents.count > 1
            currentItem.currentTorrent = currentItem.torrents.filter({$0.quality == UserDefaults.standard.string(forKey: "PreferredQuality")}).first ?? currentItem.torrents.first
            if let torrent = currentItem.currentTorrent {
                qualityBtn?.setTitle("\(torrent.quality! + (currentItem.torrents.count > 1 ? " ▾" : ""))", for: .normal)
            } else {
                qualityBtn?.setTitle("Error loading torrents.", for: .normal)
            }
            playNowBtn?.isEnabled = currentItem.currentTorrent?.url != nil
            torrentHealth.backgroundColor = currentItem.currentTorrent?.health.color
        } else {
            let background = Bundle.main.loadNibNamed("TableViewBackground", owner: self, options: nil)?.first as! TableViewBackground
            background.frame = view.bounds
            background.autoresizingMask = [.flexibleHeight, .flexibleWidth]
            background.backgroundColor = UIColor(red: 30.0/255.0, green: 30.0/255.0, blue: 30.0/255.0, alpha: 1.0)
            view.insertSubview(background, aboveSubview: view)
            background.setUpView(image: UIImage(named: "AirTV")!.withRenderingMode(.alwaysTemplate), description: "No episode selected")
            background.imageView.tintColor = UIColor.darkGray
        }
        scrollView.setNeedsLayout()
        scrollView.layoutIfNeeded()
        preferredContentSize = scrollView.contentSize
    }
    
    @IBAction func changeQualityTapped(_ sender: UIButton) {
        let quality = UIAlertController(title:"Select Quality", message:nil, preferredStyle:UIAlertControllerStyle.actionSheet)
        for torrent in currentItem!.torrents {
            quality.addAction(UIAlertAction(title: "\(torrent.quality!) \(torrent.size ?? "")", style: .default, handler: { action in
                self.currentItem?.currentTorrent = torrent
                self.playNowBtn?.isEnabled = self.currentItem?.currentTorrent?.url != nil
                self.qualityBtn?.setTitle("\(torrent.quality!) ▾", for: .normal)
                self.torrentHealth.backgroundColor = torrent.health.color
            }))
        }
        quality.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        quality.popoverPresentationController?.sourceView = sender
        present(quality, animated: true, completion: nil)
    }
    
    @IBAction func changeSubtitlesTapped(_ sender: UIButton) {
        subtitlesTablePickerView?.toggle()
    }
    
    @IBAction func watchNowTapped(_ sender: UIButton) {
        let onWifi: Bool = (UIApplication.shared.delegate! as! AppDelegate).reachability!.isReachableViaWiFi()
        let wifiOnly: Bool = !UserDefaults.standard.bool(forKey: "StreamOnCellular")
        if !wifiOnly || onWifi {
            splitViewController?.collapseSecondaryViewController(self, for: splitViewController!)
//            dismissViewControllerAnimated(false, completion: { [unowned self] in
//                self.delegate?.loadMovieTorrent(self.currentItem!, animated: true, onChromecast: GCKCastContext.sharedInstance().castState == .Connected)
//            })
        } else {
            let errorAlert = UIAlertController(title: "Cellular Data is Turned Off for streaming", message: "To enable it please go to settings.", preferredStyle: UIAlertControllerStyle.alert)
            errorAlert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { (action: UIAlertAction!) in }))
            errorAlert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { (action: UIAlertAction!) in
                let settings = self.storyboard!.instantiateViewController(withIdentifier: "SettingsTableViewController") as! SettingsTableViewController
                self.navigationController?.pushViewController(settings, animated: true)
            }))
            self.present(errorAlert, animated: true, completion: nil)
        }
    }
    
    func tablePickerView(_ tablePickerView: PCTTablePickerView, didClose items: [String]) {
        if items.count == 0 {
            currentItem?.currentSubtitle = nil
            subtitlesButton.setTitle("None ▾", for: .normal)
        } else if var currentItem = currentItem {
            let links = currentItem.subtitles?.map({$0.link})
            let index = links?.index{$0 == links?.filter({$0 == items.first!}).first!}
            let subtitle = currentItem.subtitles?[index!]
            currentItem.currentSubtitle = subtitle
            subtitlesButton.setTitle(subtitle!.language + " ▾", for: .normal)
        }
    }
    
    @IBAction func handleGesture(_ sender: UIPanGestureRecognizer) {
        let percentThreshold: CGFloat = 0.12
        let superview = sender.view!.superview!
        let translation = sender.translation(in: superview)
        let progress = translation.y/superview.bounds.height/3.0
        
        guard let interactor = interactor else { return }
        
        switch sender.state {
        case .began:
            interactor.hasStarted = true
            dismiss(animated: true, completion: nil)
            scrollView.bounces = false
        case .changed:
            interactor.shouldFinish = progress > percentThreshold
            interactor.update(progress)
        case .cancelled:
            interactor.hasStarted = false
            interactor.cancel()
             scrollView.bounces = true
        case .ended:
            interactor.hasStarted = false
            interactor.shouldFinish ? interactor.finish() : interactor.cancel()
            scrollView.bounces = true
        default:
            break
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return scrollView.contentOffset.y == 0 ? true : false
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return .lightContent
    }
}

extension TVShowDetailViewController: EpisodeDetailViewControllerDelegate {
    func didDismissViewController(_ vc: EpisodeDetailViewController) {
        if let indexPath = self.tableView!.indexPathForSelectedRow , splitViewController!.isCollapsed {
            self.tableView!.deselectRow(at: indexPath, animated: false)
        }
    }
}
