

import UIKit

class CoverCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var coverImage: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var yearLabel: UILabel!
    @IBOutlet weak var watchedIndicator: UIView?
    var watched = false {
        didSet {
            if let watchedIndicator = watchedIndicator {
                UIView.animate(withDuration: 0.25, animations: {
                    if self.watched == true {
                        watchedIndicator.alpha = 0.5
                        watchedIndicator.isHidden = false
                    } else {
                        watchedIndicator.alpha = 0.0
                        watchedIndicator.isHidden = true
                    }
                })
            }
        }
    }
}
