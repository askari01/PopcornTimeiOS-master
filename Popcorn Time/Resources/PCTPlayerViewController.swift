

import UIKit
import MediaPlayer
import PopcornTorrent
import PopcornKit

protocol PCTPlayerViewControllerDelegate: class {
    func playNext(_ episode: Episode)
    func presentCastPlayer(_ media: Media, videoFilePath: URL, startPosition: TimeInterval)
}

class PCTPlayerViewController: UIViewController, UIGestureRecognizerDelegate, UIActionSheetDelegate, VLCMediaPlayerDelegate, SubtitlesTableViewControllerDelegate, UIPopoverPresentationControllerDelegate, UpNextViewDelegate {
    
    // MARK: - IBOutlets
    @IBOutlet var movieView: UIView!
    @IBOutlet var positionSlider: PCTBarSlider!
    @IBOutlet var bufferProgressView: UIProgressView? {
        didSet {
            bufferProgressView?.layer.borderWidth = 0.6
            bufferProgressView?.layer.cornerRadius = 1.0
            bufferProgressView?.clipsToBounds = true
            bufferProgressView?.layer.borderColor = UIColor.darkText.cgColor
        }
    }
    @IBOutlet var volumeSlider: PCTBarSlider! {
        didSet {
            volumeSlider.setValue(AVAudioSession.sharedInstance().outputVolume, animated: false)
        }
    }
    @IBOutlet var loadingView: UIView!
    @IBOutlet var playPauseButton: UIButton!
    @IBOutlet var subtitleSwitcherButton: UIButton!
    @IBOutlet var tapOnVideoRecognizer: UITapGestureRecognizer!
    @IBOutlet var doubleTapToZoomOnVideoRecognizer: UITapGestureRecognizer!
    @IBOutlet var regularConstraints: [NSLayoutConstraint]!
    @IBOutlet var compactConstraints: [NSLayoutConstraint]!
    @IBOutlet var duringScrubbingConstraints: NSLayoutConstraint!
    @IBOutlet var finishedScrubbingConstraints: NSLayoutConstraint!
    @IBOutlet var subtitleSwitcherButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet var scrubbingSpeedLabel: UILabel!
    @IBOutlet var elapsedTimeLabel: UILabel!
    @IBOutlet var remainingTimeLabel: UILabel!
    @IBOutlet var navigationView: UIVisualEffectView!
    @IBOutlet var toolBarView: UIVisualEffectView!
    @IBOutlet var upNextView: UpNextView!
    @IBOutlet var videoDimensionsButton: UIButton!
    
    // MARK: - Slider actions
    
    @IBAction func sliderDidDrag() {
        resetIdleTimer()
    }
    @IBAction func positionSliderDidDrag() {
        resetIdleTimer()
        let streamDuration = (fabsf(mediaplayer.remainingTime.value.floatValue) + mediaplayer.time.value.floatValue)
        elapsedTimeLabel.text = VLCTime(number: NSNumber(value: (positionSlider.value * streamDuration) as Float)).stringValue
        remainingTimeLabel.text = VLCTime(number: NSNumber(value: ((positionSlider.value * streamDuration) - streamDuration) as Float)).stringValue
        var text = ""
        switch positionSlider.scrubbingSpeed {
        case 1.0:
            text = "Hi-Speed"
        case 0.5:
            text = "Half-Speed"
        case 0.25:
            text = "Quarter-Speed"
        case 0.1:
            text = "Fine"
        default:
            break
        }
        text += " Scrubbing"
        scrubbingSpeedLabel.text = text
    }
    @IBAction func positionSliderTouchedDown() {
        stateBeforeScrubbing = mediaplayer.state
        if mediaplayer.isPlaying {
            mediaplayer.pause()
        }
        UIView.animate(withDuration: animationLength, animations: {
            self.finishedScrubbingConstraints.isActive = false
            self.duringScrubbingConstraints.isActive = true
            self.view.layoutIfNeeded()
        })
    }
    @IBAction func volumeSliderAction() {
        resetIdleTimer()
        for subview in volumeView.subviews {
            if let slider = subview as? UISlider {
                slider.setValue(volumeSlider.value, animated: true)
            }
        }
    }
    @IBAction func positionSliderAction() {
        if stateBeforeScrubbing != .paused {
            mediaplayer.play()
            playPauseButton.setImage(UIImage(named: "Pause"), for: .normal)
        }
        mediaplayer.position = positionSlider.value
        view.layoutIfNeeded()
        UIView.animate(withDuration: animationLength, animations: {
            self.duringScrubbingConstraints.isActive = false
            self.finishedScrubbingConstraints.isActive = true
            self.view.layoutIfNeeded()
        })
    }
    
    // MARK: - Button actions
    
    @IBAction func playandPause(_ sender: UIButton) {
        if mediaplayer.isPlaying {
            mediaplayer.pause()
        } else {
            mediaplayer.play()
        }
    }
    @IBAction func fastForward() {
        mediaplayer.longJumpForward()
    }
    @IBAction func rewind() {
        mediaplayer.longJumpBackward()
    }
    @IBAction func fastForwardHeld(_ sender: UILongPressGestureRecognizer) {
        resetIdleTimer()
        switch sender.state {
        case .began:
            fallthrough
        case .changed:
            mediaplayer.mediumJumpForward()
        default:
            break
        }
        
    }
    @IBAction func rewindHeld(_ sender: UILongPressGestureRecognizer) {
        resetIdleTimer()
        switch sender.state {
        case .began:
            fallthrough
        case .changed:
            mediaplayer.mediumJumpBackward()
        default:
            break
        }
    }
    
    @IBAction func switchVideoDimensions() {
        resetIdleTimer()
        if mediaplayer.videoCropGeometry == nil // Change to aspect to scale to fill
        {
            if movieView.bounds.width.truncatingRemainder(dividingBy: 4) == 0 && movieView.bounds.height.truncatingRemainder(dividingBy: 3) == 0 {
                mediaplayer.videoCropGeometry = UnsafeMutablePointer<Int8>(mutating: ("4:3" as NSString).utf8String)
            } else if movieView.bounds.width.truncatingRemainder(dividingBy: 3) == 0 && movieView.bounds.height.truncatingRemainder(dividingBy: 4) == 0 {
                mediaplayer.videoCropGeometry = UnsafeMutablePointer<Int8>(mutating: ("3:4" as NSString).utf8String)
            } else if movieView.bounds.width.truncatingRemainder(dividingBy: 16) == 0 && movieView.bounds.height.truncatingRemainder(dividingBy: 9) == 0 {
                mediaplayer.videoCropGeometry = UnsafeMutablePointer<Int8>(mutating: ("16:9" as NSString).utf8String)
            } else if movieView.bounds.width.truncatingRemainder(dividingBy: 9) == 0 && movieView.bounds.height.truncatingRemainder(dividingBy: 16) == 0 {
                mediaplayer.videoCropGeometry = UnsafeMutablePointer<Int8>(mutating: ("9:16" as NSString).utf8String)
            }
            videoDimensionsButton.setImage(UIImage(named: "Scale To Fit"), for: .normal)
        } else // Change aspect ratio to scale to fit
        {
            videoDimensionsButton.setImage(UIImage(named: "Scale To Fill"), for: .normal)
            mediaplayer.videoAspectRatio = nil
            mediaplayer.videoCropGeometry = nil
        }
    }
    @IBAction func didFinishPlaying() {
        self.dismiss(animated: true, completion: nil)
        mediaplayer.stop()
        PTTorrentStreamer.shared().cancelStreamingAndDeleteData(UserDefaults.standard.bool(forKey: "removeCacheOnPlayerExit"))
    }
    
    // MARK: - Public vars
    
    weak var delegate: PCTPlayerViewControllerDelegate?
    var subtitles = [Subtitle]()
    var currentSubtitle: Subtitle? {
        didSet {
            if let subtitle = currentSubtitle {
                mediaplayer.numberOfChapters(forTitle: Int32(subtitles.index(of: subtitle)!)) != NSNotFound ? mediaplayer.currentChapterIndex = Int32(subtitles.index(of: subtitle)!) : openSubtitles(URL(string: subtitle.link)!)
            } else {
                mediaplayer.currentChapterIndex = NSNotFound // Remove all subtitles
            }
        }
    }
    
    // MARK: - Private vars
    
    private (set) var mediaplayer = VLCMediaPlayer()
    private var stateBeforeScrubbing: VLCMediaPlayerState!
    private (set) var url: URL!
    private (set) var directory: URL!
    private (set) var media: Media!
    internal var nextMedia: Episode?
    private var startPosition: Float = 0.0
    private var idleTimer: Timer!
    private var shouldHideStatusBar = true
    private let NSNotFound: Int32 = -1
    private var volumeView: MPVolumeView = {
       let view = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 100, height: 100))
        view.sizeToFit()
        return view
    }()
    
    // MARK: - Player functions
    
    func play(_ media: Media, fromURL url: URL, progress fromPosition: Float, nextEpisode: Episode? = nil, directory: URL) {
        self.url = url
        self.media = media
        self.startPosition = fromPosition
        self.nextMedia = nextEpisode
        self.directory = directory
        if let subtitles = media.subtitles {
            self.subtitles = subtitles
            currentSubtitle = media.currentSubtitle
        }
    }
    
    private func openSubtitles(_ filePath: URL) {
        if filePath.isFileURL {
            mediaplayer.addPlaybackSlave(URL(fileURLWithPath: filePath.relativeString), type: .subtitle, enforce: true)
        } else {
            PopcornKit.downloadSubtitleFile(filePath.relativeString, downloadDirectory: directory, completion: { (subtitlePath, error) in
                guard let subtitlePath = subtitlePath else {return}
                self.mediaplayer.addPlaybackSlave(subtitlePath, type: .subtitle, enforce: true)
            })
        }
    }
    
    private func screenshotAtTime(_ time: NSNumber, completion: @escaping (_ image: UIImage) -> Void) {
        let imageGen = AVAssetImageGenerator(asset: AVAsset(url: url))
        imageGen.appliesPreferredTrackTransform = true
        imageGen.requestedTimeToleranceAfter = kCMTimeZero
        imageGen.requestedTimeToleranceBefore = kCMTimeZero
        imageGen.cancelAllCGImageGeneration()
        imageGen.generateCGImagesAsynchronously(forTimes: [NSValue(time: CMTimeMakeWithSeconds(time.doubleValue,1000000000))]) { (_, image, _, _, error) in
            if let image = image , error == nil {
                completion(UIImage(cgImage: image))
                
            }
        }
    }
    
    // MARK: - View Methods
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(mediaPlayerStateChanged), name: NSNotification.Name(rawValue: VLCMediaPlayerStateChanged), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(mediaPlayerTimeChanged), name: NSNotification.Name(rawValue: VLCMediaPlayerTimeChanged), object: nil)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if startPosition > 0.0 {
            let continueWatchingAlert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            continueWatchingAlert.addAction(UIAlertAction(title: "Continue Watching", style: .default, handler:{ action in
                self.mediaplayer.play()
                self.mediaplayer.position = self.startPosition
                self.positionSlider.value = self.startPosition
            }))
            continueWatchingAlert.addAction(UIAlertAction(title: "Start from beginning", style: .default, handler: { action in
                self.mediaplayer.play()
            }))
            self.present(continueWatchingAlert, animated: true, completion: nil)
            
        } else {
            mediaplayer.play()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let font = UserDefaults.standard.string(forKey: "PreferredSubtitleFont"),
            let name = UIFont(name: font, size: 0)?.familyName {
            (mediaplayer as VLCFontAppearance).setTextRendererFont!(name as NSString)
        }
        if let style = UserDefaults.standard.string(forKey: "PreferredSubtitleFontStyle") {
            (mediaplayer as VLCFontAppearance).setTextRendererFontForceBold!(NSNumber(value: (style == "Bold") as Bool))
        }
        if let size = UserDefaults.standard.string(forKey: "PreferredSubtitleSize") {
            (mediaplayer as VLCFontAppearance).setTextRendererFontSize!(NSNumber(value: Float(size.replacingOccurrences(of: " pt", with: ""))! as Float))
        }
        if let subtitleColor = UserDefaults.standard.string(forKey: "PreferredSubtitleColor")?.lowerCamelCased,
            let color = UIColor.perform(Selector(subtitleColor + "Color")).takeRetainedValue() as? UIColor {
            (mediaplayer as VLCFontAppearance).setTextRendererFontColor!(NSNumber(value: color.hexInt() as UInt32))
        }
        subtitleSwitcherButton.isHidden = subtitles.count == 0
        subtitleSwitcherButtonWidthConstraint.constant = subtitleSwitcherButton.isHidden == true ? 0 : 24
        mediaplayer.delegate = self
        mediaplayer.drawable = movieView
        mediaplayer.media = VLCMedia(url: url)
        if let nextMedia = nextMedia {
            upNextView.delegate = self
            upNextView.nextEpisodeInfoLabel.text = "Season \(nextMedia.season) Episode \(nextMedia.episode)"
            upNextView.nextEpisodeTitleLabel.text = nextMedia.title
            upNextView.nextShowTitleLabel.text = nextMedia.show!.title
            TraktManager.shared.getEpisodeMetadata(nextMedia.show.id, episodeNumber: nextMedia.episode, seasonNumber: nextMedia.season, completion: { (_, imdb, error) in
                guard let imdb = imdb else { return }
                SubtitlesManager.shared.search(imdbId: imdb, completion: { (subtitles, error) in
                    guard error == nil else { return }
                    self.nextMedia?.subtitles = subtitles
                })
            })
            TMDBManager.shared.getEpisodeScreenshots(forShowWithImdbId: nextMedia.show.id, orTMDBId: nextMedia.show.tmdbId, season: nextMedia.season, episode: nextMedia.episode, completion: { (tmdb, image, error) in
                if let tmdb = tmdb { self.nextMedia?.show.tmdbId = tmdb }
                if let image = image {
                    self.nextMedia?.largeBackgroundImage = image
                    self.upNextView.nextEpisodeThumbImageView.af_setImage(withURL: URL(string: image)!)
                } else {
                    self.upNextView.nextEpisodeThumbImageView.image = UIImage(named: "Placeholder")
                }
            })
        }
        resetIdleTimer()
        view.addSubview(volumeView)
        for subview in volumeView.subviews {
            if let slider = subview as? UISlider {
                slider.addTarget(self, action: #selector(volumeChanged), for: .valueChanged)
            }
        }
        tapOnVideoRecognizer.require(toFail: doubleTapToZoomOnVideoRecognizer)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        mediaplayer.pause()
        NotificationCenter.default.removeObserver(self)
        if idleTimer != nil {
            idleTimer.invalidate()
            idleTimer = nil
        }
    }
    
    // MARK: - Player changes notifications
    
    func mediaPlayerStateChanged() {
        resetIdleTimer()
        let type: Trakt.MediaType = media is Movie ? .movies : .episodes
        switch mediaplayer.state {
        case .error:
            fallthrough
        case .ended:
            fallthrough
        case .stopped:
            TraktManager.shared.scrobble(media.id, progress: positionSlider.value, type: type, status: .finished)
            didFinishPlaying()
        case .paused:
            playPauseButton.setImage(UIImage(named: "Play"), for: .normal)
            TraktManager.shared.scrobble(media.id, progress: positionSlider.value, type: type, status: .paused)
        case .playing:
            playPauseButton.setImage(UIImage(named: "Pause"), for: .normal)
            TraktManager.shared.scrobble(media.id, progress: positionSlider.value, type: type, status: .watching)
        default:
            break
        }
    }
    
    func mediaPlayerTimeChanged() {
        if loadingView.isHidden == false {
            positionSlider.isHidden = false
            bufferProgressView!.isHidden = false
            loadingView.isHidden = true
            elapsedTimeLabel.isHidden = false
            remainingTimeLabel.isHidden = false
            videoDimensionsButton.isHidden = false
        }
        positionSlider.value = mediaplayer.position
        remainingTimeLabel.text = mediaplayer.remainingTime.stringValue
        elapsedTimeLabel.text = mediaplayer.time.stringValue
        if nextMedia != nil && (mediaplayer.remainingTime.intValue/1000) == -30 {
            upNextView.show()
        } else if (mediaplayer.remainingTime.intValue/1000) < -30 && !upNextView.isHidden {
            upNextView.hide()
        }
    }
    
    func volumeChanged() {
        if toolBarView.isHidden {
            toggleControlsVisible()
            resetIdleTimer()
        }
        for subview in volumeView.subviews {
            if let slider = subview as? UISlider {
                volumeSlider.setValue(slider.value, animated: true)
            }
        }
    }
    
    // MARK: - View changes
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        switchVideoDimensions()
        for constraint in compactConstraints {
            constraint.priority = traitCollection.horizontalSizeClass == .compact ? 999 : 240
        }
        for constraint in regularConstraints {
            constraint.priority = traitCollection.horizontalSizeClass == .compact ? 240 : 999
        }
        UIView.animate(withDuration: animationLength, animations: {
            self.view.layoutIfNeeded()
        })
    }
    
    @IBAction func toggleControlsVisible() {
        shouldHideStatusBar = navigationView.isHidden
        UIView.animate(withDuration: 0.25, animations: {
            if self.toolBarView.isHidden {
                self.toolBarView.alpha = 1.0
                self.navigationView.alpha = 1.0
                self.toolBarView.isHidden = false
                self.navigationView.isHidden = false
            } else {
                self.toolBarView.alpha = 0.0
                self.navigationView.alpha = 0.0
            }
            self.setNeedsStatusBarAppearanceUpdate()
            }, completion: { finished in
                if self.toolBarView.alpha == 0.0 {
                    self.toolBarView.isHidden = true
                    self.navigationView.isHidden = true
                }
        }) 
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        segue.destination.popoverPresentationController?.delegate = self
        if segue.identifier == "showSubtitles" {
            let vc = (segue.destination as! UINavigationController).viewControllers.first! as! SubtitlesTableViewController
            vc.dataSourceArray = subtitles
            vc.selectedSubtitle = currentSubtitle
            vc.delegate = self
        } else if segue.identifier == "showDevices" {
            let vc = (segue.destination as! UINavigationController).viewControllers.first! as! StreamToDevicesTableViewController
            vc.castMetadata = (title: media.title, image: media.smallCoverImage != nil ? URL(string: media.smallCoverImage!) : nil, contentType: media is Movie ? "video/mp4" : "video/x-matroska", subtitles: media.subtitles, url: url.relativeString, mediaAssetsPath: directory)
        }
    }
    
    func presentationController(_ controller: UIPresentationController, viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle) -> UIViewController? {
        (controller.presentedViewController as! UINavigationController).topViewController?.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelButtonPressed))
        return controller.presentedViewController
        
    }
    
    
    func cancelButtonPressed() {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Timers
    
    func resetIdleTimer() {
        if idleTimer == nil {
            idleTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(idleTimerExceeded), userInfo: nil, repeats: false)
            if !mediaplayer.isPlaying || loadingView.isHidden == false // If paused or loading, cancel timer so UI doesn't disappear
            {
                idleTimer.invalidate()
                idleTimer = nil
            }
        } else {
            idleTimer.invalidate()
            idleTimer = nil
            resetIdleTimer()
        }
    }
    
    func idleTimerExceeded() {
        idleTimer = nil
        if !toolBarView.isHidden {
            toggleControlsVisible()
        }
    }
    
    // MARK: - Status Bar
    
    override var prefersStatusBarHidden : Bool {
        return !shouldHideStatusBar
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return .default
    }
    
}
/**
 Protocol wrapper for private subtitle appearance API in MobileVLCKit. Can be toll free bridged from VLCMediaPlayer. Example for changing font:
 
        let mediaPlayer = VLCMediaPlayer()
        (mediaPlayer as VLCFontAppearance).setTextRendererFont!("HelveticaNueve")
 */
@objc protocol VLCFontAppearance {
    /**
     Change color of subtitle font.
     
     [All colors available here]: http://www.nameacolor.com/Color%20numbers.htm
     
     - Parameter fontColor: An `NSNumber` wrapped hexInt(`UInt32`) indicating the color. Eg. Black: 0, White: 16777215, etc.
     
     - SeeAlso: [All colors available here]
     */
    @objc optional func setTextRendererFontColor(_ fontColor: NSNumber)
    /**
     Toggle bold on subtitle font.
     
     - Parameter fontForceBold: `NSNumber` wrapped `Bool`.
     */
    @objc optional func setTextRendererFontForceBold(_ fontForceBold: NSNumber)
    /**
     Change the subtitle font.
     
     - Parameter fontname: `NSString` representation of font name. Eg `UIFonts` familyName property.
     */
    @objc optional func setTextRendererFont(_ fontname: NSString)
    /**
     Change the subtitle font size.
     
     - Parameter fontname: `NSNumber` wrapped `Int` of the fonts size.
     
     - Important: Provide the font in reverse size as `libvlc` sets the text matrix to the identity matrix which reverses the font size. Ie. 5pt is really big and 100pt is really small.
     */
    @objc optional func setTextRendererFontSize(_ fontSize: NSNumber)
}

extension VLCMediaPlayer: VLCFontAppearance {}
