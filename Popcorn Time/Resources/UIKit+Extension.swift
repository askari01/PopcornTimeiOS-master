

import UIKit
import OBSlider
import MediaPlayer


// MARK: - UIView

@IBDesignable class GradientView: UIView {
    
    @IBInspectable var topColor: UIColor? {
        didSet {
            configureView()
        }
    }
    @IBInspectable var bottomColor: UIColor? {
        didSet {
            configureView()
        }
    }
    
    override class var layerClass : AnyClass {
        return CAGradientLayer.self
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configureView()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }
    
    override func tintColorDidChange() {
        super.tintColorDidChange()
        configureView()
    }
    
    func configureView() {
        let layer = self.layer as! CAGradientLayer
        let locations = [ 0.0, 1.0 ]
        layer.locations = locations as [NSNumber]?
        let color1: UIColor = topColor ?? self.tintColor
        let color2: UIColor = bottomColor ?? UIColor.black
        let colors = [ color1.cgColor, color2.cgColor ]
        layer.colors = colors
    }
    
}


@IBDesignable class CircularView: UIView {
    @IBInspectable var cornerRadius: CGFloat = 0 {
        didSet {
            layer.cornerRadius = cornerRadius
            layer.masksToBounds = cornerRadius > 0
        }
    }
    @IBInspectable var borderWidth: CGFloat = 0 {
        didSet {
            layer.borderWidth = borderWidth
        }
    }
    @IBInspectable var borderColor: UIColor? {
        didSet {
            layer.borderColor = borderColor?.cgColor
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

extension UIView {
    
    @nonobjc var parentViewController: UIViewController? {
        var parentResponder: UIResponder? = self
        while parentResponder != nil {
            parentResponder = parentResponder!.next
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
        }
        return nil
    }
}

// MARK: - UIButton

@IBDesignable class PCTBorderButton: UIButton {
    @IBInspectable var cornerRadius: CGFloat = 0 {
        didSet {
            layer.cornerRadius = cornerRadius
            layer.masksToBounds = cornerRadius > 0
        }
    }
    @IBInspectable var borderWidth: CGFloat = 0 {
        didSet {
            layer.borderWidth = borderWidth
        }
    }
    @IBInspectable var borderColor: UIColor? {
        didSet {
            layer.borderColor = borderColor?.cgColor
            setTitleColor(borderColor, for: .normal)
        }
    }
    override var isHighlighted: Bool {
        didSet {
            updateColor(isHighlighted, borderColor)
        }
    }
    
    override func tintColorDidChange() {
        if tintAdjustmentMode == .dimmed {
            updateColor(false)
        } else {
            updateColor(false, borderColor)
        }
    }
    
    func updateColor(_ highlighted: Bool, _ color: UIColor? = nil) {
        UIView.animate(withDuration: 0.25, animations: {
            if highlighted {
                self.backgroundColor =  color ?? self.tintColor
                self.layer.borderColor = color?.cgColor ?? self.tintColor?.cgColor
                self.setTitleColor(UIColor.white, for: .highlighted)
            } else {
                self.backgroundColor = UIColor.clear
                self.layer.borderColor = color?.cgColor ?? self.tintColor?.cgColor
                self.setTitleColor(color ?? self.tintColor, for: .normal)
            }
        }) 
    }
}

@IBDesignable class PCTBlurButton: UIButton {
    var cornerRadius: CGFloat = 0.0 {
        didSet {
            backgroundView.layer.cornerRadius = cornerRadius
            backgroundView.layer.masksToBounds = cornerRadius > 0
        }
    }
    @IBInspectable var blurTint: UIColor = UIColor.clear {
        didSet {
            backgroundView.contentView.backgroundColor = blurTint
        }
    }
    var blurStyle: UIBlurEffectStyle = .light {
        didSet {
            backgroundView.effect = UIBlurEffect(style: blurStyle)
        }
    }
    
    var imageTransform: CGAffineTransform = CGAffineTransform(scaleX: 0.5, y: 0.5) {
        didSet {
            updatedImageView.transform = imageTransform
        }
    }
    
    var backgroundView: UIVisualEffectView
    fileprivate var updatedImageView = UIImageView()
    
    override init(frame: CGRect) {
        backgroundView = UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
        super.init(frame: frame)
        setUpButton()
    }
    
    required init?(coder aDecoder: NSCoder) {
        backgroundView = UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
        super.init(coder: aDecoder)
        setUpButton()
    }
    
    func setUpButton() {
        backgroundView.frame = bounds
        backgroundView.isUserInteractionEnabled = false
        insertSubview(backgroundView, at: 0)
        updatedImageView = UIImageView(image: self.imageView!.image)
        updatedImageView.frame = self.imageView!.bounds
        updatedImageView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        updatedImageView.isUserInteractionEnabled = false
        self.imageView?.removeFromSuperview()
        addSubview(updatedImageView)
        updatedImageView.transform = imageTransform
        cornerRadius = frame.width/2
    }
    
    override var isHighlighted: Bool {
        didSet {
            updateColor(isHighlighted)
        }
    }
    
    func updateColor(_ tint: Bool) {
        UIView.animate(withDuration: 0.25, delay: 0.0, options: UIViewAnimationOptions(), animations: { 
            self.backgroundView.contentView.backgroundColor = tint ? UIColor.white : self.blurTint
            }, completion: nil)
    }
}

@IBDesignable class PCTHighlightedImageButton: UIButton {
    @IBInspectable var highlightedImageTintColor: UIColor = UIColor.white
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setImage(self.imageView?.image?.withColor(highlightedImageTintColor), for: .highlighted)
    }
    
    override func setImage(_ image: UIImage?, for state: UIControlState) {
        super.setImage(image, for: state)
        super.setImage(image?.withColor(highlightedImageTintColor), for: .highlighted)
    }
}
// MARK: - String

extension String {
    
    func sliceFrom(_ start: String, to: String) -> String? {
        return (range(of: start)?.upperBound).flatMap { sInd in
            let eInd = range(of: to, range: sInd..<endIndex)
            if eInd != nil {
                return (eInd?.lowerBound).map { eInd in
                    return substring(with: sInd..<eInd)
                }
            }
            return substring(with: sInd..<endIndex)
        }
    }
    
    func contains(_ aString: String) -> Bool {
        return range(of: aString, options: NSString.CompareOptions.caseInsensitive) != nil
    }
    /// Produce a string of which all spaces are removed.
    @nonobjc var whiteSpacelessed: String {
        return replacingOccurrences(of: " ", with: "")
    }
    /// Produce a string of which all spaces are removed and all letters capitalised except for the first.
    @nonobjc var lowerCamelCased: String {
        guard characters.count < 1 else {
            var camelString = capitalized.whiteSpacelessed
            camelString.replaceSubrange(startIndex..<characters.index(startIndex, offsetBy: 1), with: String(capitalized.characters.first!).lowercased())
            return camelString
        }
        return self
    }
}

// MARK: - Dictionary

extension Dictionary
{
    public init(keys: [Key], values: [Value])
    {
        precondition(keys.count == values.count)
        self.init()
        for (index, key) in keys.enumerated()
        {
            self[key] = values[index]
        }
    }
}

extension Dictionary where Value : Equatable {
    func allKeysForValue(_ val : Value) -> [Key] {
        return self.filter { $1 == val }.map { $0.0 }
    }
}

func += <K, V> (left: inout [K:V], right: [K:V]) {
    for (k, v) in right {
        left.updateValue(v, forKey: k)
    }
}

// MARK: - NSLocale


extension Locale {
    
    @nonobjc static var langs: [String: String] {
        get {
            return [
                "af": "Afrikaans",
                "sq": "Albanian",
                "ar": "Arabic",
                "hy": "Armenian",
                "at": "Asturian",
                "az": "Azerbaijani",
                "eu": "Basque",
                "be": "Belarusian",
                "bn": "Bengali",
                "bs": "Bosnian",
                "br": "Breton",
                "bg": "Bulgarian",
                "my": "Burmese",
                "ca": "Catalan",
                "zh": "Chinese (simplified)",
                "zt": "Chinese (traditional)",
                "ze": "Chinese bilingual",
                "hr": "Croatian",
                "cs": "Czech",
                "da": "Danish",
                "nl": "Dutch",
                "en": "English",
                "eo": "Esperanto",
                "et": "Estonian",
                "ex": "Extremaduran",
                "fi": "Finnish",
                "fr": "French",
                "ka": "Georgian",
                "gl": "Galician",
                "de": "German",
                "el": "Greek",
                "he": "Hebrew",
                "hi": "Hindi",
                "hu": "Hungarian",
                "it": "Italian",
                "is": "Icelandic",
                "id": "Indonesian",
                "ja": "Japanese",
                "kk": "Kazakh",
                "km": "Khmer",
                "ko": "Korean",
                "lv": "Latvian",
                "lt": "Lithuanian",
                "lb": "Luxembourgish",
                "ml": "Malayalam",
                "ms": "Malay",
                "ma": "Manipuri",
                "mk": "Macedonian",
                "me": "Montenegrin",
                "mn": "Mongolian",
                "no": "Norwegian",
                "oc": "Occitan",
                "fa": "Persian",
                "pl": "Polish",
                "pt": "Portuguese",
                "pb": "Portuguese (BR)",
                "pm": "Portuguese (MZ)",
                "ru": "Russian",
                "ro": "Romanian",
                "sr": "Serbian",
                "si": "Sinhalese",
                "sk": "Slovak",
                "sl": "Slovenian",
                "es": "Spanish",
                "sw": "Swahili",
                "sv": "Swedish",
                "sy": "Syriac",
                "ta": "Tamil",
                "te": "Telugu",
                "tl": "Tagalog",
                "th": "Thai",
                "tr": "Turkish",
                "uk": "Ukrainian",
                "ur": "Urdu",
                "vi": "Vietnamese",
            ]
        }
    }
    
    static func commonISOLanguageCodes() -> [String] {
        return Array(langs.keys)
    }
    
    static func commonLanguages() -> [String] {
        return Array(langs.values)
    }
}

// MARK: - UITableViewCell

extension UITableViewCell {
    func relatedTableView() -> UITableView {
        guard let superview = self.superview as? UITableView ?? self.superview?.superview as? UITableView else {
            fatalError("UITableView shall always be found.")
        }
        return superview
    }
}


// MARK: - UIStoryboardSegue

class DismissSegue: UIStoryboardSegue {
    override func perform() {
        source.dismiss(animated: true, completion: nil)
    }
}

// MARK: - UIImage

extension UIImage {

    func crop(_ rect: CGRect) -> UIImage {
        var rect = rect
        if self.scale > 1.0 {
            rect = CGRect(x: rect.origin.x * self.scale,
                              y: rect.origin.y * self.scale,
                              width: rect.size.width * self.scale,
                              height: rect.size.height * self.scale)
        }
        
        let imageRef = self.cgImage?.cropping(to: rect)
        return UIImage(cgImage: imageRef!, scale: self.scale, orientation: self.imageOrientation)
    }
    
    func withColor(_ color: UIColor?) -> UIImage {
        var color: UIColor! = color
        color = color ?? UIColor.app
        UIGraphicsBeginImageContextWithOptions(self.size, false, UIScreen.main.scale)
        let context = UIGraphicsGetCurrentContext()
        color.setFill()
        context?.translateBy(x: 0, y: self.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        context?.setBlendMode(CGBlendMode.colorBurn)
        let rect = CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height)
        context?.draw(self.cgImage!, in: rect)
        context?.setBlendMode(CGBlendMode.sourceIn)
        context?.addRect(rect)
        context?.drawPath(using: CGPathDrawingMode.fill)
        let coloredImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return coloredImage!
    }
    
    class func fromColor(_ color: UIColor?, inRect rect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)) -> UIImage {
        var color: UIColor! = color
        color = color ?? UIColor.app
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(color.cgColor)
        context?.fill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }

}

// MARK: - NSFileManager

extension FileManager {
    func fileSizeAtPath(_ path: String) -> Int64 {
        do {
            return try (attributesOfItem(atPath: path)[FileAttributeKey.size]! as AnyObject).int64Value
        } catch {
            print("Error reading filesize: \(error)")
            return 0
        }
    }
    
    func folderSizeAtPath(_ path: String) -> Int64 {
        var size : Int64 = 0
        do {
            let files = try subpathsOfDirectory(atPath: path)
            for i in 0 ..< files.count {
                size += fileSizeAtPath((path as NSString).appendingPathComponent(files[i]) as String)
            }
        } catch {
            print("Error reading directory.")
        }
        return size
    }
}

// MARK: - UISlider

class PCTBarSlider: OBSlider {
    
    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        var customBounds = super.trackRect(forBounds: bounds)
        customBounds.size.height = 3
        customBounds.origin.y -= 1
        return customBounds
    }
    
    override func awakeFromNib() {
        self.setThumbImage(UIImage(named: "Scrubber Image"), for: .normal)
        super.awakeFromNib()
    }
}

class PCTProgressSlider: UISlider {
    
    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        var customBounds = super.trackRect(forBounds: bounds)
        customBounds.size.height = 3
        customBounds.origin.y -= 1
        return customBounds
    }
    
    override func awakeFromNib() {
        setThumbImage(UIImage(named: "Progress Indicator")?.withColor(minimumTrackTintColor), for: .normal)
        setMinimumTrackImage(UIImage.fromColor(minimumTrackTintColor), for: .normal)
        setMaximumTrackImage(UIImage.fromColor(maximumTrackTintColor), for: .normal)
        super.awakeFromNib()
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        var bounds = self.bounds
        bounds = bounds.insetBy(dx: 0, dy: -5)
        return bounds.contains(point)
    }
    
    override func thumbRect(forBounds bounds: CGRect, trackRect rect: CGRect, value: Float) -> CGRect {
        var rect = rect
        rect.size.width -= 4
        var frame = super.thumbRect(forBounds: bounds, trackRect: rect, value: value)
        frame.origin.y += rect.origin.y
        frame.origin.x += 2
        return frame
    }
    
}

// MARK: - UITableView

extension UITableView {
    func sizeHeaderToFit() {
        if let headerView = tableHeaderView {
            let height = headerView.systemLayoutSizeFitting(UILayoutFittingCompressedSize).height
            var headerFrame = headerView.frame
            if height != headerFrame.size.height {
                headerFrame.size.height = height
                headerView.frame = headerFrame
                tableHeaderView = headerView
            }
        }
    }
    
    @nonobjc var indexPathsForAllCells: [IndexPath] {
        var allIndexPaths = [IndexPath]()
        for section in 0..<numberOfSections {
            for row in 0..<numberOfRows(inSection: section) {
                allIndexPaths.append(IndexPath(row: row, section: section))
            }
        }
        return allIndexPaths
    }
}

// MARK: - CGSize

extension CGSize {
    @nonobjc static let max = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
}

// MARK: - UIViewController

extension UIViewController {
    
    func statusBarHeight() -> CGFloat {
        let statusBarSize = UIApplication.shared.statusBarFrame.size
        return Swift.min(statusBarSize.width, statusBarSize.height)
    }
    
    func dismissUntilAnimated<T: UIViewController>(_ animated: Bool, viewController: T.Type, completion: ((_ viewController: T) -> Void)?) {
        var vc = presentingViewController!
        while let new = vc.presentingViewController, !(new is T) {
            vc = new
        }
        vc.dismiss(animated: animated, completion: {
            completion?(vc as! T)
        })
    }
}

// MARK: UIScrollView

extension UIScrollView {
    @nonobjc var isAtTop: Bool {
        return contentOffset.y <= verticalOffsetForTop
    }
    
    @nonobjc var isAtBottom: Bool {
        return contentOffset.y >= verticalOffsetForBottom
    }
    
    @nonobjc var verticalOffsetForTop: CGFloat {
        let topInset = contentInset.top
        return -topInset
    }
    
    @nonobjc var verticalOffsetForBottom: CGFloat {
        let scrollViewHeight = bounds.height
        let scrollContentSizeHeight = contentSize.height
        let bottomInset = contentInset.bottom
        let scrollViewBottomOffset = scrollContentSizeHeight + bottomInset - scrollViewHeight
        return scrollViewBottomOffset
    }
}

// MARK: - NSUserDefaults

extension UserDefaults {
    func reset() {
        for key in dictionaryRepresentation().keys {
            removeObject(forKey: key)
        }
    }
}

// MARK: - UIColor 

extension UIColor {
    @nonobjc static var app = UIColor(red:0.37, green:0.41, blue:0.91, alpha:1.0)
    
    class func systemColors() -> [UIColor] {
        return [UIColor.black, UIColor.darkGray, UIColor.lightGray, UIColor.white, UIColor.gray, UIColor.red, UIColor.green, UIColor.blue, UIColor.cyan, UIColor.yellow, UIColor.magenta, UIColor.orange, UIColor.purple, UIColor.brown]
    }
    
    class func systemColorStrings() -> [String] {
       return ["Black", "Dark Gray", "Light Gray", "White", "Gray", "Red", "Green", "Blue", "Cyan", "Yellow", "Magenta", "Orange", "Purple", "Brown"]
    }
    
    func hexString() -> String {
        let colorSpace = self.cgColor.colorSpace?.model
        let components = self.cgColor.components
        
        var r, g, b: CGFloat!
        
        if (colorSpace == .monochrome) {
            r = components?[0]
            g = components?[0]
            b = components?[0]
        } else if (colorSpace == .rgb) {
            r = components?[0]
            g = components?[1]
            b = components?[2]
        }
        
        return NSString(format: "#%02lX%02lX%02lX", lroundf(Float(r) * 255), lroundf(Float(g) * 255), lroundf(Float(b) * 255)) as String
    }
    
    func hexInt() -> UInt32 {
        let hex = hexString()
        var rgb: UInt32 = 0
        let s = Scanner(string: hex)
        s.scanLocation = 1
        s.scanHexInt32(&rgb)
        return rgb
    }
}

// MARK: - UIFont

extension UIFont {
    
    func withTraits(_ traits:UIFontDescriptorSymbolicTraits...) -> UIFont {
        let descriptor = self.fontDescriptor
            .withSymbolicTraits(UIFontDescriptorSymbolicTraits(traits))
        return UIFont(descriptor: descriptor!, size: 0)
    }
    
    func boldItalic() -> UIFont {
        return withTraits(.traitBold, .traitItalic)
    }
    
    func bold() -> UIFont {
        return withTraits(.traitBold)
    }
    
    func italic() -> UIFont {
        return withTraits(.traitItalic)
    }
}

extension GCKMediaTextTrackStyle {
    
    class func pct_createDefault() -> Self {
        let ud = UserDefaults.standard
        let windowType = GCKMediaTextTrackStyleWindowType.none
        let windowColor = GCKColor(uiColor: UIColor.clear)
        var fontFamily: String?
        var edgeColor: GCKColor?
        let edgeType: GCKMediaTextTrackStyleEdgeType
        let fontScale: CGFloat
        var foregroundColor: GCKColor?
        if let font = ud.string(forKey: "PreferredSubtitleFont") {
            fontFamily = UIFont(name: font, size: 0)?.familyName
        }
        var fontStyle = GCKMediaTextTrackStyleFontStyle.normal
        if let style = ud.string(forKey: "PreferredSubtitleFontStyle") {
            switch style {
            case "Bold":
                fontStyle = .bold
            case "Italic":
                fontStyle = .italic
            case "Bold-Italic":
                fontStyle = .boldItalic
            default:
                break
            }
        }
        if let color = ud.string(forKey: "PreferredSubtitleOutlineColor")?.lowerCamelCased {
            edgeColor = GCKColor(uiColor: UIColor.perform(Selector(color + "Color")).takeRetainedValue() as! UIColor)
        }
        edgeType = edgeColor != nil ? .outline : .dropShadow
        var scale: CGFloat = 25
        if let size = ud.string(forKey: "PreferredSubtitleSize") {
            scale = CGFloat(Float(size.replacingOccurrences(of: " pt", with: ""))!)
        }
        fontScale = scale
        var textColor = UIColor.white
        if let color = ud.string(forKey: "PreferredSubtitleColor")?.lowerCamelCased {
            textColor = UIColor.perform(Selector(color + "Color")).takeRetainedValue() as! UIColor
        }
        foregroundColor = GCKColor(uiColor: textColor)
        let swizzledSelf = self.init()
        swizzledSelf.windowType = windowType
        swizzledSelf.windowColor = windowColor
        swizzledSelf.fontFamily = fontFamily
        swizzledSelf.edgeColor = edgeColor
        swizzledSelf.edgeType = edgeType
        swizzledSelf.fontScale = fontScale
        swizzledSelf.foregroundColor = foregroundColor
        swizzledSelf.fontStyle = fontStyle
        return swizzledSelf
    }
    
    open override class func initialize() {
        
        // make sure this isn't a subclass
        if self !== GCKMediaTextTrackStyle.self {
            return
        }
        
        DispatchQueue.once { 
            let originalSelector = #selector(createDefault)
            let swizzledSelector = #selector(pct_createDefault)
            let originalMethod = class_getClassMethod(self, originalSelector)
            let swizzledMethod = class_getClassMethod(self, swizzledSelector)
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
}

// MARK: - UITextView

@IBDesignable class PCTTextView: UITextView {
    
    @IBInspectable var moreButtonText: String = "...more" {
        didSet {
            moreButton.setTitle(moreButtonText, for: .normal)
        }
    }
    
    @IBInspectable var maxHeight: CGFloat = 57 {
        didSet {
            heightConstraint.constant = maxHeight
        }
    }
    
    @IBInspectable var moreButtonBackgroundColor: UIColor? {
        didSet {
            moreButton.backgroundColor = moreButtonBackgroundColor
        }
    }
    
    private var heightConstraint: NSLayoutConstraint!
    
    let moreButton = UIButton(type: .system)
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        moreButtonBackgroundColor = backgroundColor
        heightConstraint = NSLayoutConstraint(item: self, attribute: .height, relatedBy: .lessThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: maxHeight)
        loadButton()
    }
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        moreButtonBackgroundColor = backgroundColor
        heightConstraint = NSLayoutConstraint(item: self, attribute: .height, relatedBy: .lessThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: maxHeight)
        loadButton()
    }
    
    private func loadButton() {
        textContainer.maximumNumberOfLines = 0
        textContainer.lineBreakMode = .byWordWrapping
        moreButton.frame = CGRect(origin: CGPoint.zero, size: CGSize.max)
        moreButton.setTitle(moreButtonText, for: .normal)
        moreButton.sizeToFit()
        insertSubview(moreButton, aboveSubview: self)
        moreButton.addTarget(self, action: #selector(expandView), for: .touchUpInside)
        moreButton.isHidden = true
        addConstraint(heightConstraint)
    }
    
    func expandView() {
        heightConstraint.isActive = false
        self.superview?.setNeedsLayout()
        UIView.animate(withDuration: animationLength, animations: {
            self.superview?.layoutIfNeeded()
        }, completion: { _ in
            self.superview?.parentViewController?.viewDidLayoutSubviews()
        }) 
    }
    
    
    var totalNumberOfLines: Int {
        let maxSize = CGSize(width: frame.size.width, height: CGFloat.greatestFiniteMagnitude)
        let attributedText = NSAttributedString(string: text, attributes: [NSFontAttributeName: font ?? UIFont.systemFont(ofSize: 17)])
        return Int(round((attributedText.boundingRect(with: maxSize, options: .usesLineFragmentOrigin, context: nil).size.height - textContainerInset.top - textContainerInset.bottom) / (font ?? UIFont.systemFont(ofSize: 17)).lineHeight))
    }
    
    var visibleNumberOfLines: Int {
       return Int(round(contentSize.height - textContainerInset.top - textContainerInset.bottom) / (font ?? UIFont.systemFont(ofSize: 17)).lineHeight)
    }
    
    
    override func layoutSubviews() {
        super.layoutSubviews()
        moreButton.frame.origin.x = bounds.width - moreButton.frame.width - 5
        moreButton.frame.origin.y = bounds.height - moreButton.frame.height - 2.5
        moreButton.isHidden = totalNumberOfLines <= visibleNumberOfLines
    }
}

extension UITextView {
    /// When you disable selectable option on UITextView instance, text font property is reset. This bug has been in Xcode since 2013 and has yet to be fixed by apple.
    @nonobjc var text: String! {
        get {
            return perform(Selector("text")).takeUnretainedValue() as? String ?? ""
        } set {
            let originalSelectableValue = isSelectable
            isSelectable = true
            perform(Selector("setText:"), with: newValue)
            isSelectable = originalSelectableValue
        }
    }
    
}

extension Array {
    mutating func enumerate(_ block: (_ element: Element) -> Void) {
        for element in self {
            block(element)
        }
    }
}

// MARK: - UIAlertController

extension UIAlertController {
    func show() {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIViewController()
        window.windowLevel = UIWindowLevelAlert + 1
        window.makeKeyAndVisible()
        if let presentedViewController = window.rootViewController?.presentedViewController , presentedViewController is UIAlertController {return}
        window.rootViewController!.present(self, animated: true, completion: nil)
    }
}

