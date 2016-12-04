

import UIKit

public protocol HeaderScrollViewDelegate {
    func headerDidScroll(_ headerView: UIView, progressiveness: Float)
}

private enum ScrollDirection {
    case down
    case up
}

@IBDesignable open class HeaderScrollView: UIScrollView {
    @IBInspectable var headerView: UIView = UIView() {
        didSet {
            if let heightConstraint = headerView.constraints.filter({$0.firstAttribute == .height}).first {
                headerHeightConstraint = heightConstraint
            } else {
                headerHeightConstraint = NSLayoutConstraint(item: headerView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: maximumHeaderHeight)
            }
        }
    }
    
    @IBInspectable var maximumHeaderHeight: CGFloat = 230
    
    @IBInspectable var minimumHeaderHeight: CGFloat = 22
    
    @IBOutlet fileprivate var headerHeightConstraint: NSLayoutConstraint! {
        didSet {
            guard !headerView.constraints.contains(headerHeightConstraint) else {return}
            headerView.addConstraint(headerHeightConstraint)
        }
    }
    
    open var programaticScrollEnabled = false
    
    fileprivate var scrollViewScrollingProgress: CGFloat {
        return (contentOffset.y + contentInset.top) / (contentSize.height + contentInset.top + contentInset.bottom - bounds.size.height)
    }
    fileprivate var overallScrollingProgress: CGFloat {
        return headerScrollingProgress * scrollViewScrollingProgress
    }
    fileprivate var headerScrollingProgress: CGFloat {
        get {
            return 1.0 - (headerHeightConstraint.constant - minimumHeaderHeight)/(maximumHeaderHeight - minimumHeaderHeight)
        }
    }
    
    fileprivate var lastTranslation: CGFloat = 0.0
//    private var scrollingIndicator: UIView
//    
//    public required init?(coder aDecoder: NSCoder) {
//        scrollingIndicator = UIView()
//        super.init(coder: aDecoder)
//        addSubview(scrollingIndicator)
//    }
    
    
    override open var contentOffset: CGPoint {
        didSet {
            if !programaticScrollEnabled {
                super.contentOffset = CGPoint.zero
            }
        }
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        if programaticScrollEnabled == true && headerHeightConstraint.constant != minimumHeaderHeight {
            headerHeightConstraint.constant = minimumHeaderHeight
        } else if isOverScrollingTop {
            headerHeightConstraint.constant = maximumHeaderHeight
        } else if isOverScrollingBottom {
            scrollToEnd(true)
        }
    }
    
    @IBAction func handleGesture(_ sender: UIPanGestureRecognizer) {
        var translation = sender.translation(in: sender.view!.superview!)
        isOverScrolling ? translation.y /= isOverScrollingBottom ? overScrollingBottomFraction : overScrollingTopFraction : ()
        let offset = translation.y - lastTranslation
        let scrollDirection: ScrollDirection = offset > 0 ? .up : .down
        
        if sender.state == .changed || sender.state == .began {
            if (headerHeightConstraint.constant + offset) >= minimumHeaderHeight && programaticScrollEnabled == false {
                if ((headerHeightConstraint.constant + offset) - minimumHeaderHeight) <= 8.0 // Stops scrolling from sticking just before we transition to scroll view input.
                {
                    headerHeightConstraint.constant = minimumHeaderHeight
                    updateScrolling(true)
                } else {
                    headerHeightConstraint.constant += offset
                    updateScrolling(false)
                }
            }
            if headerHeightConstraint.constant == minimumHeaderHeight && isAtTop
            {
                if scrollDirection == .up {
                    programaticScrollEnabled = false
                } else // If header is fully collapsed and we are not at the end of scroll view, hand scrolling to scroll view
                {
                    programaticScrollEnabled = true
                }
            }
            lastTranslation = translation.y
        } else if sender.state == .ended {
            if isOverScrollingTop {
                headerHeightConstraint.constant = maximumHeaderHeight
                updateScrolling(true)
            } else if isOverScrollingBottom {
                scrollToEnd(true)
            }
            lastTranslation = 0.0
        }
    }
    
    func updateScrolling(_ animated: Bool) {
        guard animated else {return}
        UIView.animate(withDuration: 0.45, delay: 0.0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.3, options: [.allowUserInteraction, .curveEaseOut], animations: {
            self.superview?.layoutIfNeeded()
            }, completion: nil)
    }
    
    func scrollToEnd(_ animated: Bool) {
        headerHeightConstraint.constant -= verticalOffsetForBottom
        
        if headerHeightConstraint.constant > maximumHeaderHeight { headerHeightConstraint.constant = maximumHeaderHeight }
        
        if headerHeightConstraint.constant >= minimumHeaderHeight // User does not go over the "bridge area" so programmatic scrolling has to be explicitly disabled
        {
            programaticScrollEnabled = false
        }
        updateScrolling(animated)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return gestureRecognizers!.contains(gestureRecognizer) && gestureRecognizers!.contains(otherGestureRecognizer)
    }

}

// MARK: - Scroll View Helper Variables

extension HeaderScrollView {
    @nonobjc var isOverScrollingBottom: Bool {
        return bounds.height > contentSize.height + contentInset.bottom
    }
    
    @nonobjc var isOverScrollingTop: Bool {
        return headerHeightConstraint.constant > maximumHeaderHeight
    }
    
    @nonobjc var isOverScrolling: Bool {
        return isOverScrollingTop || isOverScrollingBottom
    }
    
    @nonobjc var overScrollingBottomFraction: CGFloat {
        return (contentInset.bottom + contentSize.height)/bounds.height
    }
    
    @nonobjc var overScrollingTopFraction: CGFloat {
        return maximumHeaderHeight/headerHeightConstraint.constant
    }
}
