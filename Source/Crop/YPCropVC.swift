//
//  YPCropVC.swift
//  YPImagePicker
//
//  Created by Sacha DSO on 12/02/2018.
//  Copyright © 2018 Yummypets. All rights reserved.
//

import UIKit

public enum YPCropType {
    case none
    case rectangle(ratio: Double)
//  TODO case circle
}

class YPCropVC: UIViewController {
    
    public var didFinishCropping: ((UIImage) -> Void)?
    
    override var prefersStatusBarHidden: Bool { return true }
    
    private let originalImage: UIImage
    private let pinchGR = UIPinchGestureRecognizer()
    private let panGR = UIPanGestureRecognizer()
    
    private let v: YPCropView
    override func loadView() { view = v }
    
    required init(image: UIImage, ratio: Double) {
        v = YPCropView(image: image, ratio: ratio)
        originalImage = image
        super.init(nibName: nil, bundle: nil)
        self.title = "Crop"
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupToolbar()
        setupGestureRecognizers()
    }
    
    func setupToolbar() {
        let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel,
                                           target: self,
                                           action: #selector(cancel))
        cancelButton.tintColor = .white
        
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        let chooseButton = UIBarButtonItem(barButtonSystemItem: .save,
                                           target: self,
                                           action: #selector(done))
        chooseButton.tintColor = .white
        v.toolbar.items = [cancelButton, flexibleSpace, chooseButton]
    }
    
    func setupGestureRecognizers() {
        // Pinch Gesture
        pinchGR.addTarget(self, action: #selector(pinch(_:)))
        pinchGR.delegate = self
        v.imageView.addGestureRecognizer(pinchGR)
        
        // Pan Gesture
        panGR.addTarget(self, action: #selector(pan(_:)))
        panGR.delegate = self
        v.imageView.addGestureRecognizer(panGR)
    }
    
    @objc
    func cancel() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc
    func done() {
        guard let image = v.imageView.image else {
            return
        }
        
        // TODO fix the crop ain't working yet
        let scaleRatio = v.imageView.frame.width / image.size.width
        var cropRect = view.convert(v.cropArea.frame, to: v.imageView)
        
        cropRect.origin.x = max(cropRect.origin.x, 0)
        cropRect.origin.y = max(cropRect.origin.y, 0)
        
        // rect to actual coordinates (scale)
        let scaledCropRect = CGRect(x: cropRect.minX * 1/scaleRatio,
                                    y: cropRect.minY * 1/scaleRatio,
                                    width: cropRect.width * 1/scaleRatio,
                                    height: cropRect.height * 1/scaleRatio)
        let imageRef = image.cgImage?.cropping(to: scaledCropRect)
        let croppedImage = UIImage(cgImage: imageRef!, scale: UIScreen.main.scale, orientation: image.imageOrientation)
        didFinishCropping?(croppedImage)
    }
}

extension YPCropVC: UIGestureRecognizerDelegate {
    
    // MARK: - Pinch Gesture
    
    @objc
    func pinch(_ sender: UIPinchGestureRecognizer) {
        // TODO: Zoom where the fingers are (more user friendly)
        switch sender.state {
        case .began, .changed:
            var transform = v.imageView.transform
            // Apply zoom level.
            transform = transform.scaledBy(x: sender.scale,
                                            y: sender.scale)
            v.imageView.transform = transform
        case .ended:
            var transform = v.imageView.transform
            let kMinZoomLevel: CGFloat = 1.0
            let kMaxZoomLevel: CGFloat = 3.0
            var wentOutOfAllowedBounds = false
            
            // Prevent zooming out too much
            if transform.a < kMinZoomLevel {
                transform = .identity
                wentOutOfAllowedBounds = true
            }
            
            // Prevent zooming in too much
            if transform.a > kMaxZoomLevel {
                transform.a = kMaxZoomLevel
                transform.d = kMaxZoomLevel
                wentOutOfAllowedBounds = true
            }
            
            // Animate coming back to the allowed bounds with a haptic feedback.
            if wentOutOfAllowedBounds {
                generateHapticFeedback()
                UIView.animate(withDuration: 0.3, animations: {
                    self.v.imageView.transform = transform
                })
            }
        case .cancelled, .failed, .possible:
            ()
        }
        // Reset the pinch scale.
        sender.scale = 1.0
    }
    
    func generateHapticFeedback() {
        if #available(iOS 10.0, *) {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }
    
    // MARK: - Pan Gesture
    
    @objc
    func pan(_ sender: UIPanGestureRecognizer) {
        let translation = sender.translation(in: view)
        let imageView = v.imageView
        
        // Apply the pan translation to the image.
        imageView.center = CGPoint(x: imageView.center.x + translation.x, y: imageView.center.y + translation.y)
        
        // Reset the pan translation.
        sender.setTranslation(CGPoint.zero, in: view)
        
        if sender.state == .ended {
            keepImageIntoCropArea()
        }
    }
    
    private func keepImageIntoCropArea() {
        let imageRect = v.imageView.frame
        let cropRect = v.cropArea.frame
        var correctedFrame = imageRect
        
        // Cap Top.
        if imageRect.minY > cropRect.minY {
            correctedFrame.origin.y = cropRect.minY
        }
        
        // Cap Bottom.
        if imageRect.maxY < cropRect.maxY {
            correctedFrame.origin.y = cropRect.maxY - imageRect.height
        }
        
        // Cap Left.
        if imageRect.minX > cropRect.minX {
            correctedFrame.origin.x = cropRect.minX
        }
        
        // Cap Right.
        if imageRect.maxX < cropRect.maxX {
            correctedFrame.origin.x = cropRect.maxX - imageRect.width
        }
        
        // Animate back to allowed bounds
        if imageRect != correctedFrame {
            UIView.animate(withDuration: 0.3, animations: {
                self.v.imageView.frame = correctedFrame
            })
        }
    }
    
    /// Allow both Pinching and Panning at the same time.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
