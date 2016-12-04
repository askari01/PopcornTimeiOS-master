

import UIKit

class PCTLoadingViewAnimatedTransitioning: NSObject, UIViewControllerAnimatedTransitioning {
    let isPresenting: Bool
    let sourceController: UIViewController
    
    init(isPresenting: Bool, sourceController source: UIViewController) {
        self.sourceController = source
        self.isPresenting = isPresenting
        super.init()
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.6
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning)  {
        if isPresenting {
            animatePresentationWithTransitionContext(transitionContext)
        }
        else {
            animateDismissalWithTransitionContext(transitionContext)
        }
    }
    
    
    func animatePresentationWithTransitionContext(_ transitionContext: UIViewControllerContextTransitioning) {
        guard
            let presentedControllerView = transitionContext.view(forKey: UITransitionContextViewKey.to)
            else {
                return
        }
        
        transitionContext.containerView.addSubview(presentedControllerView)
        presentedControllerView.isHidden = true
        
        let view = UIView(frame: sourceController.view.bounds)
        view.backgroundColor = UIColor.black
        view.alpha = 0.0
        sourceController.view.addSubview(view)
        UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: .allowUserInteraction, animations: {
            if let sourceController = self.sourceController as? DetailItemOverviewViewController {
                sourceController.lastHeaderHeight = sourceController.headerHeightConstraint.constant
                let frame = sourceController.tabBarController?.tabBar.frame
                let nframe = sourceController.navigationController?.navigationBar.frame
                let offsetY = frame!.size.height
                let noffsetY = -(nframe!.size.height + sourceController.statusBarHeight())
                sourceController.tabBarController?.tabBar.frame = frame!.offsetBy(dx: 0, dy: offsetY)
                sourceController.navigationController?.navigationBar.frame = nframe!.offsetBy(dx: 0, dy: noffsetY)
                sourceController.progressiveness = 0.0
                sourceController.blurView.alpha = 0.0
                for view in sourceController.gradientViews {
                   view.alpha = 0.0
                }
                if let showDetail = self.sourceController as? TVShowDetailViewController {
                    showDetail.segmentedControl.alpha = 0.0
                }
                sourceController.headerHeightConstraint.constant = UIScreen.main.bounds.height
                sourceController.view.layoutIfNeeded()
                view.alpha = 0.4
            }
            }, completion: { completed in
                view.removeFromSuperview()
                self.sourceController.navigationController?.setNavigationBarHidden(true, animated: false)
                presentedControllerView.isHidden = false
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        })
    }
    
    func animateDismissalWithTransitionContext(_ transitionContext: UIViewControllerContextTransitioning) {
        guard
            let presentedControllerView = transitionContext.view(forKey: UITransitionContextViewKey.from),
            let presentingControllerView = transitionContext.view(forKey: UITransitionContextViewKey.to)
            else {
                return
        }
        transitionContext.containerView.addSubview(presentingControllerView)
        presentedControllerView.isHidden = true
        sourceController.navigationController?.setNavigationBarHidden(false, animated: true)
        UIView.animate(withDuration: transitionDuration(using: transitionContext), delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: .allowUserInteraction, animations: {
            if let sourceController = self.sourceController as? DetailItemOverviewViewController {
                sourceController.headerHeightConstraint.constant = sourceController.lastHeaderHeight
                sourceController.updateScrolling(true)
                if let showDetail = self.sourceController as? TVShowDetailViewController {
                    showDetail.segmentedControl.alpha = 1.0
                }
                for view in sourceController.gradientViews {
                    view.alpha = 1.0
                }
                let frame = sourceController.tabBarController?.tabBar.frame
                let offsetY = -frame!.size.height
                sourceController.tabBarController?.tabBar.frame = frame!.offsetBy(dx: 0, dy: offsetY)
            }
            }, completion: { _ in
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        })
    }
}
