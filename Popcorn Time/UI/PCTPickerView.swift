

import UIKit

/**
 Listen for PCTPickerView delegate calls.
 */
@objc public protocol PCTPickerViewDelegate: class {
    /**
     Called when the pickerView has been closed.
     
     - Parameter pickerView:    The pickerView.
     - Parameter items:         The current selected item(s) in the pickerView. These may not have changed from the 
                                original selected items passed in.
     */
    @objc optional func pickerView(_ pickerView: PCTPickerView, didClose items: [String: AnyObject])
    /**
     Called when the pickerView is about to be closed.
     
     - Parameter pickerView:    The pickerView.
     - Parameter items:         The current selected item(s) in the pickerView. These may not have changed from the 
                                original selected items passed in.
     */
    @objc optional func pickerView(_ pickerView: PCTPickerView, willClose items: [String: AnyObject])
}
/**
 A class based on UIPickerView that handles hiding and dismissing itself from the view its added to.
 */
open class PCTPickerView: UIView, UIPickerViewDataSource, UIPickerViewDelegate {
    
    @IBOutlet fileprivate var view: UIView!
    @IBOutlet open weak var pickerView: UIPickerView!
    @IBOutlet open weak var toolbar: UIToolbar!
    @IBOutlet open weak var cancelButton: UIBarButtonItem!
    @IBOutlet open weak var doneButton: UIBarButtonItem!
    @IBOutlet open weak var backgroundView: UIView!
    
    open weak var delegate: PCTPickerViewDelegate?
    fileprivate var visible: Bool {
        return !isHidden
    }
    fileprivate var superView: UIView
    fileprivate var speed: Double = 0.2
    fileprivate let dimmingView: UIView
    open fileprivate (set) var numberOfComponents: Int = 0
    open fileprivate (set) var numberOfRowsInComponets = [Int]()
    open var selectedItems: [String]
    open var componentDataSources: [[String: AnyObject]] {
        didSet {
            numberOfComponents = componentDataSources.count
            numberOfRowsInComponets.removeAll()
            for array in componentDataSources {
                numberOfRowsInComponets.append(array.count)
            }
            pickerView?.reloadAllComponents()
        }
    }
    open var attributesForComponents: [String?]! {
        didSet {
            pickerView?.reloadAllComponents()
        }
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        layoutView()
    }
    
    
    /**
     Designated Initialiser. Creates a UIPickerView with toolbar on top to handle dismissal of the view. Also handles hiding and showing animations.
     
     Parameter superview:                   View that the pickerView is a subview of.
     Parameter componentDataSources:        Data source dictionaries of the components in the picker.
     Parameter delegate:                    Register for `PCTPickerViewDelegate` notifications.
     Parameter selectedItems:               Data source keys that the pickerView will start on.
     Parameter attributesForComponenets:    Array of keys for NSAttributedString to customize component text style. Value for supplied key will be taken from the corresponding componentDataSource value.
     */
    public init(superView: UIView, componentDataSources: [[String: AnyObject]], delegate: PCTPickerViewDelegate?, selectedItems: [String], attributesForComponents: [String?]? = nil) {
        self.superView = superView
        self.componentDataSources = componentDataSources
        self.delegate = delegate
        self.selectedItems = selectedItems
        self.dimmingView = {
           let view = UIView(frame: superView.bounds)
            view.backgroundColor = UIColor.black
            return view
        }()
        super.init(frame: CGRect.zero)
        self.attributesForComponents = attributesForComponents ?? [String?](repeating: nil, count: numberOfComponents)
        loadNib()
        self.isHidden = true
        let borderTop = CALayer()
        borderTop.frame = CGRect(x: 0.0, y: toolbar.frame.height - 1, width: toolbar.frame.width, height: 0.5);
        borderTop.backgroundColor = UIColor(red:0.17, green:0.17, blue:0.17, alpha:1.0).cgColor
        toolbar.layer.addSublayer(borderTop)
        layoutView()
        insertSubview(dimmingView, belowSubview: view)
        dimmingView.alpha = 0
        dimmingView.isHidden = true
        dimmingView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cancel)))
        view.frame.origin.y = self.superView.bounds.height
    }
    /**
     This method of initialisation is not supported.
     */
    @available(iOS, deprecated : 9.0, message: "Use initWithSuperView:componentDataSources:delegate:selectedItems:attributesForComponents: instead.") required public init?(coder aDecoder: NSCoder) {
        fatalError("This method of initialisation is not supported. Use initWithSuperView:componentDataSources:delegate:selectedItems:attributesForComponents: instead.")
    }
    /**
     Show pickerView in superView with animation.
     */
    open func show() {
        for component in 0..<numberOfComponents {
            pickerView?.selectRow(Array(componentDataSources[component].keys.sorted(by: >)).index(of: selectedItems[component])!, inComponent: component, animated: false)
        }
        dimmingView.isHidden = false
        view.setNeedsLayout()
        view.layoutIfNeeded()
        self.view.frame.origin.y = self.superView.bounds.height
        isHidden = false
        UIView.animate(withDuration: speed, delay: 0, options: UIViewAnimationOptions(), animations: {
            self.dimmingView.alpha = 0.6
            self.view.frame.origin.y = self.superView.bounds.height - (self.superView.bounds.height / 2.7)
            }, completion: nil)
    }
    /**
     Hide pickerView in superView with animation.
     */
    open func hide() {
        if visible {
            var selected = [String: AnyObject]()
            for component in 0..<numberOfComponents {
                let key = Array(componentDataSources[component].keys.sorted(by: >))[pickerView.selectedRow(inComponent: component)]
                let value = componentDataSources[component][key]
                selected[key] = value
            }
            selectedItems = Array(selected.keys).reversed()
            self.delegate?.pickerView?(self, willClose: selected)
            UIView.animate(withDuration: speed, delay: 0, options: UIViewAnimationOptions(), animations: { [unowned self] in
                self.dimmingView.alpha = 0
                self.view.frame.origin.y = self.superView.bounds.height
                }, completion: { [unowned self] _ in
                    self.delegate?.pickerView?(self, didClose: selected)
                    self.dimmingView.isHidden = true
                    self.isHidden = true
            })
        }
    }
    /**
     Toggle hiding/showing of pickerView in superView with animation.
     */
    open func toggle() {
        visible ? hide() : show()
    }
    
    // MARK: - UIPickerViewDataSource
    
    open func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let key = Array(componentDataSources[component].keys).sorted(by: >)[row]
        let value = componentDataSources[component][key]
        var attributes = [String: AnyObject]()
        if let attribute = attributesForComponents[component] {
            attributes[attribute] = value
        }
        let textLabel = view as? UILabel ?? {
            let label = UILabel()
            label.textColor = UIColor.white
            label.textAlignment = .center
            return label
            }()
        textLabel.text = key
        textLabel.attributedText = NSAttributedString(string: key, attributes: attributes)
        return textLabel
    }
    
    open func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return numberOfRowsInComponets[component]
    }
    
    open func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return numberOfComponents
    }
    
    // MARK: Private methods
    
    fileprivate func layoutView() {
        frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: superView.bounds.height)
        dimmingView.frame = superView.bounds
        view.frame = CGRect(origin: CGPoint(x: 0, y: superView.bounds.height - (superView.bounds.height / 2.7)), size: CGSize(width: superView.bounds.width, height: superView.bounds.height / 2.7))
    }
    
    fileprivate func loadNib() {
        UINib(nibName: "PCTPickerView", bundle: nil).instantiate(withOwner: self, options: nil)[0] as? UIView
        addSubview(view)
    }
    
    @IBAction func done() {
        var selected = [String: AnyObject]()
        for component in 0..<numberOfComponents {
            let key = Array(componentDataSources[component].keys.sorted(by: >))[pickerView.selectedRow(inComponent: component)]
            let value = componentDataSources[component][key]
            selected[key] = value
        }
        selectedItems = Array(selected.keys).reversed()
        hide()
    }
    
    @IBAction func cancel() {
        hide()
    }
}
