

import UIKit

@objc public protocol PCTTablePickerViewDelegate: class {
	@objc optional func tablePickerView(_ tablePickerView: PCTTablePickerView, didSelect item: String)
	@objc optional func tablePickerView(_ tablePickerView: PCTTablePickerView, didDeselect item: String)
	@objc optional func tablePickerView(_ tablePickerView: PCTTablePickerView, didClose items: [String])
	@objc optional func tablePickerView(_ tablePickerView: PCTTablePickerView, willClose items: [String])
}

open class PCTTablePickerView: UIView, UITableViewDataSource, UITableViewDelegate {
	
	@IBOutlet fileprivate var view: UIView!
	@IBOutlet open weak var tableView: UITableView!
	@IBOutlet open weak var toolbar: UIToolbar!
	@IBOutlet open weak var button: UIBarButtonItem!
	
	open weak var delegate: PCTTablePickerViewDelegate?
    fileprivate var visible: Bool {
        return !isHidden
    }
    fileprivate let dimmingView: UIView
	fileprivate var superView: UIView
	fileprivate var dataSourceKeys = [String]()
	fileprivate var dataSourceValues = [String]()
    open var selectedItems = [String]() {
        didSet {
            tableView?.reloadData()
        }
    }
    fileprivate var cellBackgroundColor: UIColor = UIColor.clear {
        didSet {
            tableView?.reloadData()
        }
    }
    fileprivate var cellBackgroundColorSelected: UIColor = UIColor(red: 217.0/255.0, green: 217.0/255.0, blue: 217.0/255.0, alpha: 1.0) {
        didSet {
            tableView?.reloadData()
        }
    }
    fileprivate var cellTextColor: UIColor = UIColor.lightGray {
        didSet {
            tableView?.reloadData()
        }
    }
	fileprivate var multipleSelect: Bool = false
	fileprivate var nullAllowed: Bool = true
	fileprivate var speed: Double = 0.2
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        layoutView()
    }
    
    /**
     Designated Initialiser. Creates a UITableView with toolbar on top to handle dismissal of the view. Also handles hiding and showing animations.
     
     Parameter superView:                   View that the pickerView is a subview of.
     Parameter sourceDict:                  Data source dictionary for the tableView. Values will be used as table view cell 
                                            text and keys are used to keep track of selected items.
     Parameter delegate:                    Register for `PCTTablePickerViewDelegate` notifications.
     */
    public init(superView: UIView, sourceDict: [String : String]?, _ delegate: PCTTablePickerViewDelegate?) {
        self.superView = superView
        self.dimmingView = {
            let view = UIView(frame: superView.bounds)
            view.backgroundColor = UIColor.black
            return view
        }()
		super.init(frame: CGRect.zero)
		self.superView = superView
		if let sourceDict = sourceDict {
			self.setSourceDictionay(sourceDict)
		}
		self.delegate = delegate
        prepareView()
	}
    /**
     Designated Initialiser. Creates a UITableView with toolbar on top to handle dismissal of the view. Also handles hiding and showing animations.
     
     Parameter superView:                   View that the pickerView is a subview of.
     Parameter sourceArray:                 Data source array for the tableView.
     Parameter delegate:                    Register for `PCTTablePickerViewDelegate` notifications.
     */
	public init(superView: UIView, sourceArray: [String]?, _ delegate: PCTTablePickerViewDelegate?) {
        self.superView = superView
        self.dimmingView = {
            let view = UIView(frame: superView.bounds)
            view.backgroundColor = UIColor.black
            return view
        }()
		super.init(frame: CGRect.zero)
		self.superView = superView
		if var sourceArray = sourceArray {
            sourceArray.sort(by: {$0 < $1})
			self.setSourceArray(sourceArray)
		}
		self.delegate = delegate
		prepareView()
	}
    /**
     This method of initialisation is not supported.
     */
    @available(iOS, deprecated : 9.0, message: "Use initWithSuperView:sourceArray:delegate: or initWithSuperView:sourceDict:delegate: instead.") required public init?(coder aDecoder: NSCoder) {
        fatalError("This method of initialisation is not supported. Use initWithSuperView:sourceArray:delegate: or initWithSuperView:sourceDict:delegate: instead.")
    }
    /**
     Set data source dictionary for the tableView.
     
     - Parameter source: The dictionary.
     */
	open func setSourceDictionay(_ source: [String : String]) {
		let sortedKeysAndValues = source.sorted(by: { $0.1 < $1.1 })
		for (key, value) in sortedKeysAndValues {
			self.dataSourceKeys.append(key)
			self.dataSourceValues.append(value)
		}
		tableView?.reloadData()
	}
    /**
     Set data source array for the tableView.
     
     - Parameter source: The array.
     */
	open func setSourceArray(_ source: [String]) {
		self.dataSourceKeys = source
		self.dataSourceValues = source
		tableView?.reloadData()
	}
    /**
     Deselect the tableView row.
     
     - Parameter item: The title of the row that will be deselected. If the title is not in the tableView, nothing will be deselected.
     */
	open func deselect(_ item: String) {
		if let index = selectedItems.index(of: item) {
			selectedItems.remove(at: index)
			tableView?.reloadData()
			delegate?.tablePickerView?(self, didDeselect: item)
		}
	}
    /**
     Deselect every tableView apart from the passed in row.
     
     - Parameter item: The title of the row that will not be deselected. If the title is not in the tableView, nothing will be deselected. If mulitple selection is not enabled or if nothing is selected the passed in row will be selected.
     */
	open func deselectButThis(_ item: String) {
		for _item in selectedItems {
			if _item != item {
				delegate?.tablePickerView?(self, didDeselect: item)
			}
		}
		selectedItems = [item]
		tableView?.reloadData()
	}
    /**
     Show tablePickerView in superView with animation.
     */
	open func show() {
        if let selectedItem = selectedItems.first , dataSourceKeys.contains(selectedItem) {
            tableView.scrollToRow(at: IndexPath(row: dataSourceKeys.index(of: selectedItem)!, section: 0) , at: .top, animated: true)
        } else {
            tableView.scrollToRow(at: IndexPath(row: 0, section: 0) , at: .top, animated: false)
        }
        dimmingView.isHidden = false
        view.frame.origin.y = superView.bounds.height
        isHidden = false
        UIView.animate(withDuration: speed, delay: 0, options: UIViewAnimationOptions(), animations: {
            self.dimmingView.alpha = 0.6
            self.view.frame.origin.y = self.superView.bounds.height - (self.superView.bounds.height / 2.7)
            }, completion: nil)
	}
    /**
     Hide tablePickerView in superView with animation.
     */
	open func hide() {
		if visible {
            UIView.animate(withDuration: speed, delay: 0, options: UIViewAnimationOptions(), animations: { [unowned self] in
                self.dimmingView.alpha = 0
                self.view.frame.origin.y = self.superView.bounds.height
                self.delegate?.tablePickerView?(self, willClose: self.selectedItems)
                }, completion: { [unowned self] _ in
                    self.dimmingView.isHidden = true
                    self.isHidden = true
                    self.delegate?.tablePickerView?(self, didClose: self.selectedItems)
                })
		}
	}
    /**
     Toggle hiding/showing of tablePickerView in superView with animation.
     */
    open func toggle() {
        visible ? hide() : show()
    }
	
    // MARK: - UITableViewDataSource
	
	open func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}
	
	open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return dataSourceKeys.count
	}
	
	open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = UITableViewCell()
		cell.textLabel?.text = dataSourceValues[indexPath.row]
        cell.backgroundColor = cellBackgroundColor
        let bg = UIView()
        bg.backgroundColor = cellBackgroundColorSelected
        cell.selectedBackgroundView = bg
        cell.textLabel?.textColor = cellTextColor
        cell.tintColor = cellTextColor
        cell.accessoryType = selectedItems.contains(dataSourceKeys[indexPath.row]) ? .checkmark : .none
		return cell
	}
	
	open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let cell = tableView.cellForRow(at: indexPath)!
		let selectedItem = dataSourceKeys[indexPath.row]
		if selectedItems.contains(selectedItem) && (nullAllowed || selectedItems.count > 1) {
			selectedItems.remove(at: selectedItems.index(of: selectedItem)!)
			delegate?.tablePickerView?(self, didDeselect: selectedItem)
			cell.accessoryType = .none
		} else {
			if !multipleSelect && selectedItems.count > 0 {
				let oldSelected = selectedItems[0]
				selectedItems.removeAll()
				if let index = dataSourceKeys.index(of: oldSelected) {
					let oldCell = tableView.cellForRow(at: IndexPath(item: index, section: 0))
					oldCell?.accessoryType = .none
				}
			}
			
			selectedItems.append(selectedItem)
			cell.accessoryType = .checkmark
			delegate?.tablePickerView?(self, didSelect: selectedItem)
		}
		
		tableView.deselectRow(at: indexPath, animated: true)
	}

	
	// MARK: Private methods
	
	fileprivate func prepareView() {
        loadNib()
        isHidden = true
        let borderTop = CALayer()
        borderTop.frame = CGRect(x: 0.0, y: toolbar.frame.height - 1, width: toolbar.frame.width, height: 0.5);
        borderTop.backgroundColor = UIColor(red:0.17, green:0.17, blue:0.17, alpha:1.0).cgColor
        toolbar.layer.addSublayer(borderTop)
        tableView.separatorColor = UIColor.darkGray
        tableView.backgroundColor = UIColor.clear
        let blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        tableView.backgroundView = blurEffectView
        tableView.tableFooterView = UIView(frame: CGRect.zero)
        layoutView()
        insertSubview(dimmingView, belowSubview: view)
        dimmingView.alpha = 0
        dimmingView.isHidden = true
        dimmingView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(done)))
        view.frame.origin.y = superView.bounds.height
	}
    
    fileprivate func layoutView() {
        frame = CGRect(x: 0, y: 0, width: superView.frame.width, height: superView.bounds.height)
        dimmingView.frame = superView.bounds
        view.frame = CGRect(origin: CGPoint(x: 0, y: superView.bounds.height - (superView.bounds.height / 2.7)), size: CGSize(width: superView.bounds.width, height: superView.bounds.height / 2.7))
    }
	
	fileprivate func loadNib() {
		UINib(nibName: "PCTTablePickerView", bundle: nil).instantiate(withOwner: self, options: nil)[0] as? UIView
		addSubview(view)
	}
	
	@IBAction func done(_ sender: AnyObject) {
		hide()
	}
}
