//
//  CameraViewController.swift
//  snapchat
//
//  Created by Boqin Hu on 27/08/2016.
//  Copyright © 2016 Boqin Hu. All rights reserved.
//

import UIKit
import AVFoundation
import Firebase

class CameraViewController : UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var usingSimulator: Bool = true
    var captureSession : AVCaptureSession!
    var backCamera : AVCaptureDevice!
    var frontCamera : AVCaptureDevice!
    var currentDevice : AVCaptureDevice!
    var captureDeviceInputBack:AVCaptureDeviceInput!
    var captureDeviceInputFront:AVCaptureDeviceInput!
    var stillImageOutput:AVCaptureStillImageOutput!
    var cameraFacingback: Bool = true
    var ImageCaptured: UIImage!
    var cameraState:Bool = true
    var flashOn:Bool = false
    
    var faceDetector:CIDetector!
    var capturePreviewLayer: AVCaptureVideoPreviewLayer?
    var square: UIImage!
    var smile: UIImage!
    var videoDataOutputQueue: DispatchQueue!
    var lasttime:TimeInterval = 0
    
    /**
     The outlet of UIView of the CameraView.
     */
    @IBOutlet var previewView: UIView!
    
    /**
     The outlet of the take picture button.
     */
    @IBOutlet weak var TakePicButton: UIButton!
    
    /**
     The outlet of the configure flash button.
     */
    @IBOutlet weak var Flash: UIButton!
    
    /**
     The outlet of the flip camera button.
     */
    @IBOutlet weak var FlipCamera: UIButton!
    
    /**
     The action button to scroll to the chat view.
     */
    @IBAction func Jump_to_chat(_ sender: UIButton) {
        let scrollView = self.view.superview?.superview?.superview as? UIScrollView
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .curveEaseOut, animations: {
            scrollView!.contentOffset.x = 0.0
            }, completion: nil)
    }
    
    /**
     The action button to scroll to the story view.
     */
    @IBAction func Jump_to_story(_ sender: UIButton) {
        let scrollView = self.view.superview?.superview?.superview as? UIScrollView
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .curveEaseOut, animations: {
            scrollView!.contentOffset.x += self.view.frame.width
            
            }, completion: nil)
    }
    
    /**
     The action button to scroll to the my information view.
     */
    @IBAction func toAddfriend(_ sender: UIButton) {
        let scrollView = self.view.superview as? UIScrollView
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .curveEaseOut, animations: {
            scrollView!.contentOffset.y = 0.0
            }, completion: nil)


    }
    
    private func DegreesToRadians(degrees: CGFloat) -> CGFloat {return degrees * .pi / 180}
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.isNavigationBarHidden = true
        
        square = UIImage(named: "squarePNG")
        smile = UIImage(named: "smilePNG")
        
        let detectorOptions = [CIDetectorAccuracy: CIDetectorAccuracyHigh, CIDetectorTracking: true] as [String : Any]
        faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: detectorOptions)
        
        loadCamera()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        checkIfUserIsLoggedIn()
    }
    
    /**
     Method to check whether user is logged in.
     */
    func checkIfUserIsLoggedIn() {
        
        if Auth.auth().currentUser?.uid != nil {
            // User is logged in
            // Do nothing currently
        } else {
            // User is not logged in
            let loginRegisterController = LoginRegisterController()
            present(loginRegisterController, animated: true, completion: nil)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    /**
     The method to load camera.
     */
    func loadCamera() {
        captureSession = AVCaptureSession()
        captureSession.startRunning()
        
        if captureSession.canSetSessionPreset(AVCaptureSession.Preset.high){
            captureSession.sessionPreset = AVCaptureSession.Preset.photo
        }
        let devices = AVCaptureDevice.devices()
        
        for device in devices {
            if (device as AnyObject).hasMediaType(AVMediaType.video){
                if (device as AnyObject).position == AVCaptureDevice.Position.back {
                    backCamera = device 
                }
                else if (device as AnyObject).position == AVCaptureDevice.Position.front{
                    frontCamera = device 
                }
            }
        }
        if backCamera == nil {
            print("The device doesn't have camera")
        }
        
        currentDevice = backCamera
        configureFlash()
        //var error:NSError?
        
        //create a capture device input object from the back and front camera
        do {
            captureDeviceInputBack = try AVCaptureDeviceInput(device: backCamera)
        }
        catch
        {
            
        }
        do {
            captureDeviceInputFront = try AVCaptureDeviceInput(device: frontCamera)
        }catch{
            
        }
        
        if captureSession.canAddInput(captureDeviceInputBack){
            captureSession.addInput(captureDeviceInputBack)
        } else {
            print("can't add input")
        }
        stillImageOutput = AVCaptureStillImageOutput()
        stillImageOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
        captureSession.addOutput(stillImageOutput)
        
        // Make a video data output
        let videoDataOutput = AVCaptureVideoDataOutput()
        // we want BGRA, both CoreGraphics and OpenGL work well with 'BGRA'
        let rgbOutputSettings = [kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCMPixelFormat_32BGRA)]
        
        videoDataOutput.videoSettings = rgbOutputSettings
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        
        videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue")
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        captureSession.addOutput(videoDataOutput)
        videoDataOutput.connection(with: AVMediaType.video)!.isEnabled = true
        
        capturePreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        capturePreviewLayer!.videoGravity = AVLayerVideoGravity.resizeAspectFill
        capturePreviewLayer!.frame = self.view.frame
        capturePreviewLayer!.bounds = self.view.bounds
        
        previewView.layer.addSublayer(capturePreviewLayer!)
        
    }
    
    /**
     The method to realize the shutter function.
     */
    @IBAction func Takepicture(_ sender: UIButton) {
        TakePicButton.isEnabled = true;
        cameraState = false
        if !captureSession.isRunning {
            return
        }
        if let videoConnection = stillImageOutput!.connection(with: AVMediaType.video){
            stillImageOutput?.captureStillImageAsynchronously(from: videoConnection, completionHandler: {(sampleBuffer,error) -> Void in
                if sampleBuffer != nil {
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer!)
                let dataProvider = CGDataProvider(data: imageData as! CFData)
                let cgImageRef = CGImage(jpegDataProviderSource: dataProvider!, decode: nil, shouldInterpolate: true, intent: CGColorRenderingIntent.defaultIntent)
                self.ImageCaptured = UIImage(cgImage:cgImageRef!, scale: 1.0, orientation: UIImageOrientation.right)
                    //self.captureSession.stopRunning()
                self.performSegue(withIdentifier: "test", sender: self)}
            })
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if Date().timeIntervalSince1970 - lasttime < 0.1 {
            return
        }
        lasttime = Date().timeIntervalSince1970;
        // got an image
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate) as NSDictionary? as! [String: Any]?
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer, options: attachments)
        let curDeviceOrientation = UIDevice.current.orientation
        var exifOrientation: Int = 0
        
        /* kCGImagePropertyOrientation values
         The intended display orientation of the image. If present, this key is a CFNumber value with the same value as defined
         by the TIFF and EXIF specifications -- see enumeration of integer constants.
         The value specified where the origin (0,0) of the image is located. If not present, a value of 1 is assumed.
         
         used when calling featuresInImage: options: The value for this key is an integer NSNumber from 1..8 as found in kCGImagePropertyOrientation.
         If present, the detection will be done based on that orientation but the coordinates in the returned features will still be based on those of the image. */
        
        
        let PHOTOS_EXIF_0ROW_TOP_0COL_LEFT            = 1 //   1  =  0th row is at the top, and 0th column is on the left (THE DEFAULT).
        //let PHOTOS_EXIF_0ROW_TOP_0COL_RIGHT            = 2 //   2  =  0th row is at the top, and 0th column is on the right.
        let PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT      = 3 //   3  =  0th row is at the bottom, and 0th column is on the right.
        //let PHOTOS_EXIF_0ROW_BOTTOM_0COL_LEFT       = 4 //   4  =  0th row is at the bottom, and 0th column is on the left.
        //let PHOTOS_EXIF_0ROW_LEFT_0COL_TOP          = 5 //   5  =  0th row is on the left, and 0th column is the top.
        let PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP         = 6 //   6  =  0th row is on the right, and 0th column is the top.
        //let PHOTOS_EXIF_0ROW_RIGHT_0COL_BOTTOM      = 7 //   7  =  0th row is on the right, and 0th column is the bottom.
        let PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM       = 8  //   8  =  0th row is on the left, and 0th column is the bottom.
        
        switch curDeviceOrientation {
        case .portraitUpsideDown:  // Device oriented vertically, home button on the top
            exifOrientation = PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM
        case .landscapeLeft:       // Device oriented horizontally, home button on the right
            if !cameraFacingback {
                exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT
            } else {
                exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT
            }
        case .landscapeRight:      // Device oriented horizontally, home button on the left
            if !cameraFacingback {
                exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT
            } else {
                exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT
            }
        case .portrait:            // Device oriented vertically, home button on the bottom
            fallthrough
        default:
            exifOrientation = PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP
        }
        
        let imageOptions = [CIDetectorImageOrientation: exifOrientation, CIDetectorSmile: true] as [String : Any]
        let features = faceDetector.features(in: ciImage, options: imageOptions)
        
        // get the clean aperture
        // the clean aperture is a rectangle that defines the portion of the encoded pixel dimensions
        // that represents image data valid for display.
        let fdesc = CMSampleBufferGetFormatDescription(sampleBuffer)!
        let clap = CMVideoFormatDescriptionGetCleanAperture(fdesc, false /*originIsTopLeft == false*/)
        
        videoDataOutputQueue.async() {
            self.drawFaceBoxesForFeatures(features: features, forVideoBox: clap, orientation: curDeviceOrientation)
        }
    }
    
    func postImageData(completion: () -> ()) {
        let requestUrl = URL(string: "https://westus.api.cognitive.microsoft.com/emotion/v1.0/recognize")
        let key = "b2ecededcbe3486fae0a8976b794e4f2"
        
        var request = URLRequest(url: requestUrl!)
        request.setValue(key, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        
        let image = UIImage(named: "sad.jpg")
        let imageData = UIImagePNGRepresentation(image!)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData
        
        request.httpMethod = "POST"
        
        let task = URLSession.shared.dataTask(with: request){ data, response, error in
            if error != nil{
                print("Error -> \(String(describing: error))")
                return
            }else{
                //print(data)
                let results = try! JSONSerialization.jsonObject(with: data!)
                print(results)
            }
            
        }
        task.resume()
        
    }
    
    func videoPreviewBoxForGravity(gravity: AVLayerVideoGravity, frameSize: CGSize, apertureSize: CGSize) -> CGRect {
//        print(apertureSize)
        let apertureRatio = apertureSize.height / apertureSize.width
        let viewRatio = frameSize.width / frameSize.height
        
        var size = CGSize.zero
        switch gravity {
        case .resizeAspectFill:
            if viewRatio > apertureRatio {
                size.width = frameSize.width
                size.height = apertureSize.width * (frameSize.width / apertureSize.height)
            } else {
                size.width = apertureSize.height * (frameSize.height / apertureSize.width)
                size.height = frameSize.height
            }
        case .resizeAspect:
            if viewRatio > apertureRatio {
                size.width = apertureSize.height * (frameSize.height / apertureSize.width)
                size.height = frameSize.height;
            } else {
                size.width = frameSize.width;
                size.height = apertureSize.width * (frameSize.width / apertureSize.height);
            }
        case .resize:
            size.width = frameSize.width
            size.height = frameSize.height
        default:
            break
        }
//        print(size, frameSize)
        var videoBox: CGRect = CGRect()
        size = frameSize;
        videoBox.size = frameSize;
        if size.width < frameSize.width {
            videoBox.origin.x = (frameSize.width - size.width) / 2
        } else {
            videoBox.origin.x = (size.width - frameSize.width) / 2
        }
        
        if size.height < frameSize.height {
            videoBox.origin.y = (frameSize.height - size.height) / 2
        } else {
            videoBox.origin.y = (size.height - frameSize.height) / 2
        }
        
        return videoBox;
    }
    
    // called asynchronously as the capture output is capturing sample buffers, this method asks the face detector (if on)
    // to detect features and for each draw the red square in a layer and set appropriate orientation
    private func drawFaceBoxesForFeatures(features: [CIFeature], forVideoBox clap: CGRect, orientation: UIDeviceOrientation) {
        let sublayers = capturePreviewLayer?.sublayers ?? []
        let sublayersCount = sublayers.count
        var currentSublayer = 0
        var featuresCount = features.count, currentFeature = 0
        
        CATransaction.begin()
        CATransaction.setValue(true, forKey: kCATransactionDisableActions)
        
        // hide all the face layers
        for layer in sublayers {
            if layer.name == "FaceLayer" {
                layer.isHidden = true
            }
        }
        
//        print(featuresCount, sublayersCount)
        
        if featuresCount == 0 {
            CATransaction.commit()
            return // early bail.
        }
        
        let parentFrameSize = previewView.frame.size;
        let gravity = capturePreviewLayer?.videoGravity
        let isMirrored = capturePreviewLayer?.connection?.isVideoMirrored ?? false
        let previewBox = videoPreviewBoxForGravity(gravity: gravity!,
                                                   frameSize: parentFrameSize,
                                                   apertureSize: clap.size)
        
        for ff in features as! [CIFaceFeature] {
            var x : CGFloat = 0.0, y : CGFloat = 0.0
            if ff.hasLeftEyePosition {
                x = ff.leftEyePosition.x
                y = ff.leftEyePosition.y
//                print(ff.leftEyeClosed ? "(\(x) \(y))" : "(\(x) \(y))" + "👀")
            }
            
            if ff.hasRightEyePosition {
                x = ff.rightEyePosition.x
                y = ff.rightEyePosition.y
//                print(ff.rightEyeClosed ? "(\(x) \(y))" : "(\(x) \(y))" + "👀")
            }
            
            if ff.hasMouthPosition {
                x = ff.mouthPosition.x
                y = ff.mouthPosition.y
//                print(ff.hasSmile ? "\(x) \(y)" + "😊" : "(\(x) \(y))")
            }
        }
        
        
        for ff in features as! [CIFaceFeature] {
            // find the correct position for the square layer within the previewLayer
            // the feature box originates in the bottom left of the video frame.
            // (Bottom right if mirroring is turned on)
            var faceRect = ff.bounds
            
            // flip preview width and height
            var temp = faceRect.size.width
            faceRect.size.width = faceRect.size.height
            faceRect.size.height = temp
            temp = faceRect.origin.x
            faceRect.origin.x = faceRect.origin.y
            faceRect.origin.y = temp
            // scale coordinates so they fit in the preview box, which may be scaled
            let widthScaleBy = previewBox.size.width / clap.size.height
            let heightScaleBy = previewBox.size.height / clap.size.width
            faceRect.size.width *= widthScaleBy
            faceRect.size.height *= heightScaleBy
            faceRect.origin.x *= widthScaleBy
            faceRect.origin.y *= heightScaleBy
            
            if isMirrored {
                faceRect = faceRect.offsetBy(dx: previewBox.origin.x + previewBox.size.width - faceRect.size.width - (faceRect.origin.x * 2), dy: previewBox.origin.y)
            } else {
                faceRect = faceRect.offsetBy(dx: previewBox.origin.x, dy: previewBox.origin.y)
            }
            
//            print(faceRect, previewBox, ff.bounds)
            
            var featureLayer: CALayer? = nil
            
            // re-use an existing layer if possible
            while featureLayer == nil && (currentSublayer < sublayersCount) {
                let currentLayer = sublayers[currentSublayer];currentSublayer += 1
                if currentLayer.name == "FaceLayer" {
                    featureLayer = currentLayer
                    currentLayer.isHidden = false
                }
            }
            
            // create a new one if necessary
            if featureLayer == nil {
                featureLayer = CALayer()
                featureLayer!.name = "FaceLayer"
                capturePreviewLayer?.addSublayer(featureLayer!)
            }
            if ff.hasSmile {
                featureLayer!.contents = smile.cgImage
                print("smile")
            } else {
                featureLayer!.contents = square.cgImage
            }
            featureLayer!.frame = faceRect
            
            switch orientation {
            case .portrait:
                featureLayer!.setAffineTransform(CGAffineTransform(rotationAngle: DegreesToRadians(degrees: 0.0)))
            case .portraitUpsideDown:
                featureLayer!.setAffineTransform(CGAffineTransform(rotationAngle: DegreesToRadians(degrees: 180.0)))
            case .landscapeLeft:
                featureLayer!.setAffineTransform(CGAffineTransform(rotationAngle: DegreesToRadians(degrees: 90.0)))
            case .landscapeRight:
                featureLayer!.setAffineTransform(CGAffineTransform(rotationAngle: DegreesToRadians(degrees: -90.0)))
            case .faceUp, .faceDown:
                break
            default:
                
                break // leave the layer in its last known orientation//        }
            }
            currentFeature += 1
        }
        
        CATransaction.commit()
    }
    
    /**
     The method to realise opening and closing camera flash.
     */
    @IBAction func ChangeFlash(_ sender: UIButton){
        flashOn = !flashOn
        if flashOn {
            self.Flash.setImage(UIImage(named: "Flash_on"), for: UIControlState.normal)
        }
        else {
            self.Flash.setImage(UIImage(named: "Flash_off"), for: UIControlState.normal)
        }
            self.configureFlash()
    }
    
    /**
     The method to realize changing the camera direction.
     */
    @IBAction func Flip_Camera(_ sender: UIButton){
        
        cameraFacingback = !cameraFacingback
        if cameraFacingback {
            displayBackCamera()
            self.FlipCamera.setImage(UIImage(named:"Camera flip"), for: UIControlState.normal)
            
        } else {
            
            self.FlipCamera.setImage(UIImage(named:"Camera_flip_self"), for: UIControlState.normal)
            displayFrontCamera()
        }
    }
    
    /**
     The method to load back camera.
     */
    func displayBackCamera(){
        if captureSession.canAddInput(captureDeviceInputBack) {
            captureSession.addInput(captureDeviceInputBack)
        } else {
            captureSession.removeInput(captureDeviceInputFront)
            if captureSession.canAddInput(captureDeviceInputBack) {
                captureSession.addInput(captureDeviceInputBack)
            }
        }
        
    }
    
    /**
     The method to load front camera.
     */
    func displayFrontCamera(){
        if captureSession.canAddInput(captureDeviceInputFront) {
            captureSession.addInput(captureDeviceInputFront)
        } else {
            captureSession.removeInput(captureDeviceInputBack)
            if captureSession.canAddInput(captureDeviceInputFront) {
                captureSession.addInput(captureDeviceInputFront)
            }
        }
    }
    
    /**
     The method to configure flash light.
     */
    func configureFlash(){
        do {
            try backCamera.lockForConfiguration()
        } catch {
            
        }
        if backCamera.hasFlash {
            if flashOn {
                if backCamera.isFlashModeSupported(AVCaptureDevice.FlashMode.on){
                backCamera.flashMode = AVCaptureDevice.FlashMode.on
                }
            }else {
                if backCamera.isFlashModeSupported(AVCaptureDevice.FlashMode.off){
                    backCamera.flashMode = AVCaptureDevice.FlashMode.off
                    //flashOn = false
                }
                
            }
        }
        backCamera.unlockForConfiguration()
    }
    
    /**
     The method to realise camera focusing.
     */
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touchpoint = touches.first
//        var screenSize = previewView.bounds.size
//        let location = touchpoint?.location(in: self.view)
        let x = (touchpoint?.location(in: self.view).x)! / self.view.bounds.width
        let y = (touchpoint?.location(in: self.view).y)! / self.view.bounds.height
        
//        var locationX = location?.x
//        var locationY = location?.y
        
        focusOnPoint(x: x, y: y)
    }
    
    /**
     The algorithm to reasise autofocus .
     */
    func focusOnPoint(x: CGFloat, y:CGFloat){
        let focusPoint = CGPoint(x: x, y: y)
        if cameraFacingback {
            currentDevice = backCamera
        }
        else {
            currentDevice = frontCamera
        }
        do {
            try currentDevice.lockForConfiguration()
        }catch {
            
        }
        
        if currentDevice.isFocusPointOfInterestSupported{
            
            currentDevice.focusPointOfInterest = focusPoint
        }
        if currentDevice.isFocusModeSupported(AVCaptureDevice.FocusMode.autoFocus)
        {
            currentDevice.focusMode = AVCaptureDevice.FocusMode.autoFocus
        }
        if currentDevice.isExposurePointOfInterestSupported
        {
            currentDevice.exposurePointOfInterest = focusPoint
        }
        if currentDevice.isExposureModeSupported(AVCaptureDevice.ExposureMode.autoExpose) {
            currentDevice.exposureMode = AVCaptureDevice.ExposureMode.autoExpose
        }
        currentDevice.unlockForConfiguration()

    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "test"{
            let previewController = segue.destination as! PreviewController
            previewController.capturedPhoto = self.ImageCaptured            
        }
}
}
    
