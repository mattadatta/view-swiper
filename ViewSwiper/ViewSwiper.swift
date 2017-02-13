//
// This file is subject to the terms and conditions defined in
// file 'LICENSE', which is part of this source code package.
//

import UIKit

/// A `ViewSwiper` manages a `ViewSwipeable` instance and provides the functionality for dragging and
/// revealing hidden views beneath the draggable object. The most common use-case for this class
/// would be attaching an instance to a `UITableViewCell` or `UICollectionViewCell` to provide advanced
/// functionality for swiping left or right on the cell to reveal additional options.
public final class ViewSwiper: NSObject {

    /// The `ViewSwipeable` instance that this `ViewSwiper` manages
    public private(set) weak var swipeable: ViewSwipeable?

    /// The delegate of this `ViewSwiper`
    public weak var delegate: ViewSwiperDelegate?

    /// The gesture recognizer this `ViewSwiper` uses for tracking user touches
    fileprivate private(set) var panGestureRecognizer: UIPanGestureRecognizer!

    /// Construct a `ViewSwiper` instance that manages the given `ViewSwipeable` and optional delegate.

    /// - Parameters:
    ///   - swipeable: The `ViewSwipeable` instance to manage
    ///   - delegate: The delegate of the instance
    public init(swipeable: ViewSwipeable, delegate: ViewSwiperDelegate? = nil) {
        self.swipeable = swipeable
        self.delegate = delegate
        super.init()

        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
        self.panGestureRecognizer = panGestureRecognizer
        panGestureRecognizer.delegate = self
    }

    /// Whether or not this `ViewSwiper` is enabled
    public var isEnabled: Bool = false {
        didSet {
            guard self.isEnabled != oldValue else { return }
            if self.isEnabled {
                self.enable()
            } else {
                self.disable()
            }
        }
    }

    /// Enables the `ViewSwiper`. This will add the gesture recognizer to the trackable view.
    /// - seealso: `ViewSwipeable.swipeableTrackingView`
    private func enable() {
        guard let trackingView = self.swipeable?.swipeableTrackingView else {
            self.isEnabled = false
            return
        }
        trackingView.addGestureRecognizer(self.panGestureRecognizer)
    }

    /// Disables the `ViewSwiper`. This will remove the gesture recognizer to the trackable view.
    /// - seealso: `ViewSwipeable.swipeableTrackingView`
    private func disable() {
        guard let trackingView = self.swipeable?.swipeableTrackingView else {
            self.isEnabled = true
            return
        }
        trackingView.removeGestureRecognizer(self.panGestureRecognizer)
    }


    // MARK: State management

    /// A revealable side
    ///
    /// - left: The left side, reavealed when the user drags to the right
    /// - right: The right side, reavealed when the user drags to the left
    public enum Side {

        case left
        case right

        /// The unit multiplier for normalizing translation math
        fileprivate var unit: CGFloat {
            switch self {
            case .left: return 1
            case .right: return -1
            }
        }
    }

    /// A `RevealedViewInstance` keeps track of the currently revealed view (as the result of a drag) and
    /// what `Side` it's on.
    public struct RevealedViewInstance {

        /// The side the instance is on
        public var side: Side

        /// The revealable view
        public weak var view: UIView?
    }

    /// A `DragInstance` keeps track of the frame-by-frame state of the user currently dragging and
    /// and revealing a view.
    public struct DragInstance {

        /// The `RevealedViewInstance` of this drag
        public var viewInstance: RevealedViewInstance

        /// The translation vector as a result of the pan (offseted properly for the translation of the view)
        public var translationVector: CGVector

        /// The current velocity vector
        public var velocityVector: CGVector
    }

    /// A `ReleaseAction` represents the result of the user lifting their finger after a drag, i.e., which
    /// action should occur as a result of the release
    ///
    /// - complete: Indicates that the release should fully reveal the underlying view and fully swipe across the draggable view
    /// - open: Indicates the the release should open to the width defined by `ViewSwipeable.revealedViewWidth(for:)`. If no width
    ///         is defined here, this action is the same as returing `complete`.
    /// - close: Indicates that the release should close and hide the revealed view
    public enum ReleaseAction {

        case complete
        case open
        case close
    }

    /// The state the `ViewSwiper` is currently in.
    ///
    /// - start: The default and primary state, where no user interaction has yet occurred
    /// - holding: The state entered when the user is touching/dragging but no revealed view is available
    /// - dragging: The state when the user is dragging and revealing an underlying view
    /// - open: The state entered when the `ViewSwiper` is told, as the result of releasing a drag, to snap to the edge of the revealed view
    /// - settling: The state entered when the `ViewSwiper` is told, as the result of releasing a drag, to close and cover the reavealed view
    /// - complete: The state entered when the `ViewSwiper` is told, as the result of releasing a drag, to fully animate across
    public enum State {

        case start
        case holding
        case dragging(DragInstance)
        case open(DragInstance, CGFloat)
        case settling(DragInstance, (() -> Void)?)
        case completing(DragInstance, (() -> Void)?)
    }

    /// The current `State` the `ViewSwiper` is in. Altering this propery will trigger
    /// the state transition function.
    public fileprivate(set) var state: State = .start {
        didSet {
            self.transition(from: oldValue, to: self.state)
        }
    }

    /// Close the slider, if it is open, optionally suppressing the animations when doing so. Supressing
    /// the animations would typically be desired when attaching `ViewSwiper`s to `UITableViewCell`s or
    /// `UICollectionViewCell`s when the cell prepares for reuse
    ///
    /// - Parameter suppressAnimations: `true` to supress the animations, `false` otherwise
    public func close(suppressAnimations: Bool = false, callback: (() -> Void)? = nil) {
        guard case let .open(dragInstance, _) = self.state else { return }
        self.suppressAnimations = suppressAnimations
        self.state = .settling(dragInstance, callback)
        self.suppressAnimations = false
    }

    /// Complete the slider, if it is open. You would call this function, for example, if you wanted to perform the
    /// animation as if the user dragged all the way across, but as a result of tapping one of the available options.
    public func complete(callback: (() -> Void)? = nil) {
        guard case let .open(dragInstance, _) = self.state else { return }
        self.state = .completing(dragInstance, callback)
    }

    /// Boolean to keep track of whether or not the current state change should perform animations
    private var suppressAnimations: Bool = false

    /// Callback invoked when the `ViewSwiper` transitions from one state to another.
    ///
    /// - Parameters:
    ///   - fromState: The previous state of the `ViewSwiper`
    ///   - toState: The current state of the `ViewSwiper`
    private func transition(from fromState: State, to toState: State) {
        guard
            let trackingView = self.swipeable?.swipeableTrackingView,
            let draggableView = self.swipeable?.swipeableDragView else { return }

        switch (fromState, toState) {
        case (_, .start):
            self.dragOffsetVector = .zero
            trackingView.isUserInteractionEnabled = true
            draggableView.transform = .identity

        case (_, .holding):
            draggableView.transform = .identity

        case (_, .dragging(let instance)):
            let vector = instance.translationVector
            let unit: CGFloat = vector.dx >= 0 ? 1 : -1
            let absoluteTranslation = abs(vector.dx)

            let xTranslate: CGFloat
            let percentage: CGFloat?

            if let swipeable = self.swipeable, let revealableWidth = swipeable.revealedViewWidth(for: instance.viewInstance.side) {
                let percentageRevealed = absoluteTranslation / revealableWidth
                if percentageRevealed > 1.0 && !swipeable.dragInstanceCanPassEdge(instance) {
                    // Dampen pull after 100% if we can't continue pulling
                    xTranslate = (revealableWidth * unit) + ((absoluteTranslation - revealableWidth) * unit * 0.3)
                } else {
                    xTranslate = absoluteTranslation * unit
                }
                percentage = abs(xTranslate / revealableWidth)
            } else {
                xTranslate = absoluteTranslation * unit
                percentage = nil
            }

            draggableView.transform = CGAffineTransform.identity.translatedBy(x: xTranslate, y: 0)
            self.swipeable?.didDrag(instance.viewInstance, translation: xTranslate, percentage: percentage)

        case (_, .open(let dragInstance, let width)):
            trackingView.isUserInteractionEnabled = false

            let xTranslate = width * dragInstance.viewInstance.side.unit
            self.dragOffsetVector = CGVector(dx: xTranslate, dy: 0)

            let animBlock = {
                draggableView.transform = CGAffineTransform.identity.translatedBy(x: xTranslate, y: 0)
                self.swipeable?.didDrag(dragInstance.viewInstance, translation: xTranslate, percentage: 1.0)
            }

            let completion: (Bool) -> Void = { _ in
                trackingView.isUserInteractionEnabled = true
            }

            if !self.suppressAnimations {
                UIView.animate(
                    withDuration: 0.3,
                    delay: 0,
                    options: [.curveEaseOut],
                    animations: animBlock,
                    completion: completion)
            } else {
                animBlock()
                completion(true)
            }

        case (_, .settling(let dragInstance, let callback)):
            trackingView.isUserInteractionEnabled = false // Will be set back to true when it's in the `start` state again

            let animBlock = {
                draggableView.transform = .identity
                self.swipeable?.didDrag(dragInstance.viewInstance, translation: 0.0, percentage: 0.0)
            }

            let completion: (Bool) -> Void = { [weak self] _ in
                DispatchQueue.main.async {
                    dragInstance.viewInstance.view?.removeFromSuperview()
                    self?.state = .start
                    callback?()
                }
            }

            if !self.suppressAnimations {
                UIView.animate(
                    withDuration: 0.3,
                    delay: 0,
                    options: [.curveEaseOut],
                    animations: animBlock,
                    completion: completion)
            } else {
                animBlock()
                completion(true)
            }

        case (_, .completing(let dragInstance, let callback)):
            trackingView.isUserInteractionEnabled = false // Will be set back to true when it's in the `start` state again

            let xTranslate = (dragInstance.viewInstance.view?.frame.width ?? 0) * dragInstance.viewInstance.side.unit

            let animBlock = {
                draggableView.transform = CGAffineTransform.identity.translatedBy(x: xTranslate, y: 0)
                self.swipeable?.didDrag(dragInstance.viewInstance, translation: xTranslate, percentage: nil)
            }

            let completion: (Bool) -> Void = { [weak self] _ in
                self?.swipeable?.finishCompletion(for: dragInstance) {
                    DispatchQueue.main.async {
                        dragInstance.viewInstance.view?.removeFromSuperview()
                        self?.state = .start
                        callback?()
                    }
                }
            }

            if !self.suppressAnimations {
                UIView.animate(
                    withDuration: 0.3,
                    delay: 0,
                    options: [.curveEaseOut],
                    animations: animBlock,
                    completion: completion)
            } else {
                animBlock()
                completion(true)
            }
        }

        self.swipeable?.swiperDidTransition(from: fromState, to: toState)
    }


    // MARK: UI touch tracking

    /// The offset vector (used when the user starts dragging if the `ViewSwiper` is already open
    /// and offsetted
    private var dragOffsetVector: CGVector = .zero

    /// The callback to invoked as a result of the pan gesture changing state
    ///
    /// - Parameter gestureRecognizer: The pan gesture recognizer
    private dynamic func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let trackingView = self.swipeable?.swipeableTrackingView else { return }

        switch gestureRecognizer.state {

        case .changed:
            let translationVector = gestureRecognizer.translation(in: trackingView).vector + self.dragOffsetVector
            let velocityVector = gestureRecognizer.translation(in: trackingView).vector
            let newSide: Side = translationVector.dx > 0 ? .left : .right

            let createNewViewInstance: (RevealedViewInstance?) -> RevealedViewInstance? = { existingInstance in
                existingInstance?.view?.removeFromSuperview()

                guard self.delegate?.viewSwiper(self, shouldBeginRevealing: newSide) ?? true else { return nil }
                guard let swipeable = self.swipeable else { return nil }
                guard let view = swipeable.revealedView(for: newSide) else { return nil }
                let viewInstance = RevealedViewInstance(side: newSide, view: view)
                let containerView = swipeable.swipeableRevealedContainerView
                containerView.addAndConstrain(view)
                containerView.layoutIfNeeded()
                return viewInstance
            }

            let viewInstance: RevealedViewInstance?

            switch self.state {
            case .start: fallthrough
            case .holding:
                viewInstance = createNewViewInstance(nil)

            case .open(let instance, _):
                viewInstance = instance.viewInstance.side != newSide ? createNewViewInstance(instance.viewInstance) : instance.viewInstance

            case .dragging(let instance):
                viewInstance = instance.viewInstance.side != newSide ? createNewViewInstance(instance.viewInstance) : instance.viewInstance

            default:
                viewInstance = nil
            }

            if let viewInstance = viewInstance {
                let dragInstance = DragInstance(viewInstance: viewInstance, translationVector: translationVector, velocityVector: velocityVector)
                self.state = .dragging(dragInstance)
            } else {
                self.state = .holding
            }

        case .ended:
            switch self.state {
            case .dragging(let dragInstance):

                let releaseAction = self.swipeable?.releaseAction(for: dragInstance) ?? .close

                switch releaseAction {
                case .complete:
                    self.state = .completing(dragInstance, nil)

                case .open:
                    if let viewWidth = self.swipeable?.revealedViewWidth(for: dragInstance.viewInstance.side) {
                        self.state = .open(dragInstance, viewWidth)
                    } else {
                        self.state = .completing(dragInstance, nil)
                    }

                case .close:
                    self.state = .settling(dragInstance, nil)
                }

            default:
                self.state = .start
            }

        default:
            break
        }
    }
}

// MARK: - ViewSwiper UIGestureRecognizerDelegate conformance

extension ViewSwiper: UIGestureRecognizerDelegate {

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return !(otherGestureRecognizer is UIPanGestureRecognizer)
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return otherGestureRecognizer is UIPanGestureRecognizer
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let panGestureRecognizer = self.panGestureRecognizer!
        guard panGestureRecognizer == gestureRecognizer else { return true }
        guard self.delegate?.viewSwiperShouldBegin(self) ?? true else { return false }
        guard let trackingView = self.swipeable?.swipeableTrackingView else { return false }
        let translationVector = panGestureRecognizer.translation(in: trackingView).vector
        return abs(translationVector.dx) >= abs(translationVector.dy)
    }
}


// MARK: - ViewSwipeable

/// A `ViewSwipeable` provides configuration and view information for its managing
/// `ViewSwiper` instance. It defines the tracking, dragging, and container views
/// for view hierarchy management, and also provides the callbacks for all state-related
/// swiping events.
public protocol ViewSwipeable: class {

    /// The tracking view to use for gesture recognition
    var swipeableTrackingView: UIView { get }

    /// The view to drag that will reveal the underlying views
    var swipeableDragView: UIView { get }

    /// The container view to add the revealed views to
    var swipeableRevealedContainerView: UIView { get }

    /// Callback invoked when the `ViewSwiper` would like to attach a view to the left or right
    /// as the result of a drag.
    ///
    /// - Parameter side: Which side the `ViewSwiper` is querying for
    /// - Returns: The `UIView` to reveal and display on the given side, or `nil` if you don't want to support that side
    func revealedView(for side: ViewSwiper.Side) -> UIView?

    /// Callback invoked when the `ViewSwiper` is dragging the view to reveal a side. Use this function to translate any
    /// additional components in your view. This callback will also be invoked in animation blocks for settling
    /// or expanding animations.
    ///
    /// - Parameters:
    ///   - instance: The `ViewSwiper.RevealedViewInstance` the user is currently revealing
    ///   - translation: The translation amount of the drag
    ///   - percentage: The percentage to the edge width of the revealed view, or `nil` if the view doesn't define a width
    /// - seealso: `ViewSwipeable.edgeWith(for:)`
    func didDrag(_ instance: ViewSwiper.RevealedViewInstance, translation: CGFloat, percentage: CGFloat?)

    /// Callback invoked when the `ViewSwiper` would like to know what the width of the revealed view is on the given side.
    /// If you define a width, the swiper instance can move into the `open` state. If you don't define a width, then
    /// the `ViewSwiper` can only enter the `completing` and `settling` states
    ///
    /// - Parameter side: The side in question
    /// - Returns: An optional width, which defines the edge of the possible drag
    func revealedViewWidth(for side: ViewSwiper.Side) -> CGFloat?

    /// Callback invoked when the `ViewSwiper` would like to know if scrolling past the width of the revealed view causes
    /// the scroll to dampen or not. If you did not return a width from `revealedViewWidth(for:)`, this function will not
    /// get called.
    ///
    /// - Parameter dragInsance: The `DragInstance` in question
    /// - Returns: `true` if no damping should be applied, `false` otherwise
    func dragInstanceCanPassEdge(_ dragInsance: ViewSwiper.DragInstance) -> Bool

    /// Callback invoked when the `ViewSwiper` would like to know what action should occur as a result of releasing a drag.
    /// Note: If yo did not return a width in `revealedViewWidth(for:)`, returning `.open` acts as if you returned `.complete`.
    ///
    /// - Parameter dragInstance: The `DragInstance` in question
    /// - Returns: The action to perform
    func releaseAction(for dragInstance: ViewSwiper.DragInstance) -> ViewSwiper.ReleaseAction

    /// Callback invoked when the `ViewSwiper` has completed a full-swipe-across. Most commonly this is some form of a delete operation,
    /// and the swiper expects the dragging view to be removed. Take this opportunity to perform any relevant animations that collapse/remove
    /// the view(s) in question and invoke the provided callback when you are done. This method will not get called if the swiper never expects
    /// to enter the `.completing` state.
    ///
    /// - Parameters:
    ///   - dragInstance: The `DragInstance` in question
    ///   - callback: The callback to invoke when any animations to clean up the view are complete
    func finishCompletion(for dragInstance: ViewSwiper.DragInstance, callback: @escaping () -> Void)

    /// Callback invoked when the `ViewSwiper` has changed states internally as the result of any user interaction, function invocation,
    /// or animation completion. Use this function to perform any extra UI tweaks that wouldn't be covered by `ViewSwipeable.didDrag(_:translation:
    ///
    /// - Parameters:
    ///   - fromState: The previous state of the swiper
    ///   - toState: The current state of the swiper
    func swiperDidTransition(from fromState: ViewSwiper.State, to toState: ViewSwiper.State)
}


// MARK: - ViewSwiperDelegate

/// The `ViewSwiperDelegate` provides callbacks related globally to multiple instances of `ViewSwiper`s being
/// available at once (for instance, a table view can prevent any swipe actions from occurring by setting its
/// cell's swiper's delegates to itself.
public protocol ViewSwiperDelegate: class {

    /// Callback invoked to determine if the `ViewSwiper` should start or not.
    ///
    /// - Parameter viewSwiper: The `ViewSwiper` in question
    /// - Returns: `true` if the swiper should being an operation, `false` otherwise
    func viewSwiperShouldBegin(_ viewSwiper: ViewSwiper) -> Bool

    /// Callback invoked to determine if the `ViewSwiper` should start revealing the given side or not
    ///
    /// - Parameters:
    ///   - viewSwiper: The `ViewSwiper` in question
    ///   - side: The side in question
    /// - Returns: `true` if the swiper should being an operation, `false` otherwise
    func viewSwiper(_ viewSwiper: ViewSwiper, shouldBeginRevealing side: ViewSwiper.Side) -> Bool
}


// MARK: - ViewSwiper associated objects

private extension ViewSwiper {

    struct Keys {

        static var viewSwiperKey = "ViewSwiper"
    }
}

/// `ViewSwipeable`'s that are `UIView`s get a swiper for free!
public extension ViewSwipeable where Self: UIView {

    private var _viewSwiper: ViewSwiper? {
        get { return objc_getAssociatedObject(self, &ViewSwiper.Keys.viewSwiperKey) as! ViewSwiper? }
        set { objc_setAssociatedObject(self, &ViewSwiper.Keys.viewSwiperKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// This swipeable's embedded swiper instance to use
    public var viewSwiper: ViewSwiper {
        guard let viewSwiper = self._viewSwiper else {
            let viewSwiper = ViewSwiper(swipeable: self)
            self._viewSwiper = viewSwiper
            return viewSwiper
        }
        return viewSwiper
    }
}


// MARK: - ViewSwiper utils

private extension UIView {

    func addAndConstrain(_ view: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(view)
        self.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        self.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        self.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        self.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
}

private extension CGPoint {

    var vector: CGVector {
        return CGVector(dx: self.x, dy: self.y)
    }
}

private extension CGVector {

    static let zero = CGVector(dx: 0, dy: 0)
}

private func + (lhs: CGVector, rhs: CGVector) -> CGVector {
    return CGVector(dx: lhs.dx + rhs.dx, dy: lhs.dy + rhs.dy)
}
