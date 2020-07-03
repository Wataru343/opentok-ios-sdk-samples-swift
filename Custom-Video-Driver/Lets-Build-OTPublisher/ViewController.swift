//
//  ViewController.swift
//  Lets-Build-OTPublisher
//
//  Created by Roberto Perez Cubero on 11/08/16.
//  Copyright © 2016 tokbox. All rights reserved.
//

import UIKit
import Accelerate
import OpenTok
import ImageDetect

let kWidgetRatio: CGFloat = 1.333

// *** Fill the following variables using your own Project info  ***
// ***            https://tokbox.com/account/#/                  ***
// Replace with your OpenTok API key
let kApiKey = ""
// Replace with your generated session ID
let kSessionId = ""
// Replace with your generated token
let kToken = ""

var count: Int = 0
var skipFrames: Int = 30

class ViewController: UIViewController {
    lazy var session: OTSession = {
        return OTSession(apiKey: kApiKey, sessionId: kSessionId, delegate: self)!
    }()
    
    var publisher: OTPublisher?
    
    var subscriber: OTSubscriber?
    
    let captureSession = AVCaptureSession()
    
    let captureQueue = DispatchQueue(label: "com.tokbox.VideoCapture", attributes: [])

    var infoYpCbCrToARGB = vImage_YpCbCrToARGB()

    var imageView: UIImageView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        doConnect()


        //configuring
        var pixelRange = vImage_YpCbCrPixelRange(Yp_bias: 0, CbCr_bias: 128, YpRangeMax: 255, CbCrRangeMax: 255, YpMax: 255, YpMin: 1, CbCrMax: 255, CbCrMin: 0)
        let error = vImageConvert_YpCbCrToARGB_GenerateConversion(kvImage_YpCbCrToARGBMatrix_ITU_R_601_4!, &pixelRange, &infoYpCbCrToARGB, kvImage420Yp8_Cb8_Cr8, kvImageARGB8888, vImage_Flags(kvImagePrintDiagnosticsToConsole))
        print(error)

        imageView = UIImageView()
        imageView?.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        view.addSubview(imageView!)
    }
    
    /**
     * Asynchronously begins the session connect process. Some time later, we will
     * expect a delegate method to call us back with the results of this action.
     */
    fileprivate func doConnect() {
        var error: OTError?
        defer {
            processError(error)
        }
        session.connect(withToken: kToken, error: &error)
    }
    
    /**
     * Sets up an instance of OTPublisher to use with this session. OTPubilsher
     * binds to the device camera and microphone, and will provide A/V streams
     * to the OpenTok session.
     */
    fileprivate func doPublish() {
        var error: OTError? = nil
        defer {
            processError(error)
        }
        let settings = OTPublisherSettings()
        settings.name = UIDevice.current.name
        
        publisher = OTPublisher(delegate: self, settings: settings)
        if let pub = publisher {
            //let videoRender = ExampleVideoRender()
            //pub.videoCapture = ExampleVideoCapture()
            //pub.videoRender = videoRender
            session.publish(pub, error: &error)
            
            pub.view!.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.width / kWidgetRatio)
            view.addSubview(pub.view!)
        }
    }
    
    /**
     * Instantiates a subscriber for the given stream and asynchronously begins the
     * process to begin receiving A/V content for this stream. Unlike doPublish,
     * this method does not add the subscriber to the view hierarchy. Instead, we
     * add the subscriber only after it has connected and begins receiving data.
     */
    fileprivate func doSubscribe(_ stream: OTStream) {
        var error: OTError?
        defer {
            processError(error)
        }
        subscriber = OTSubscriber(stream: stream, delegate: self)
        session.subscribe(subscriber!, error: &error)
    }
    
    fileprivate func cleanupSubscriber() {
        subscriber?.view?.removeFromSuperview()
        subscriber = nil
    }
    
    fileprivate func processError(_ error: OTError?) {
        if let err = error {
            showAlert(errorStr: err.localizedDescription)
        }
    }
    
    fileprivate func showAlert(errorStr err: String) {
        DispatchQueue.main.async {
            let controller = UIAlertController(title: "Error", message: err, preferredStyle: .alert)
            controller.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            self.present(controller, animated: true, completion: nil)
        }
    }
    
    
    @IBAction func toggleCamera(_ sender: Any) {
        if let capturer = publisher?.videoCapture as? ExampleVideoCapture, let renderer = publisher?.videoRender as? ExampleVideoRender {
            let _ = capturer.toggleCameraPosition()
            renderer.mirroring = (capturer.cameraPosition == AVCaptureDevice.Position.front) ? true : false
        }
    }
}

// MARK: - OTSession delegate callbacks
extension ViewController: OTSessionDelegate {
    func sessionDidConnect(_ session: OTSession) {
        print("Session connected")
        doPublish()
    }
    
    func sessionDidDisconnect(_ session: OTSession) {
        print("Session disconnected")
    }
    
    func session(_ session: OTSession, streamCreated stream: OTStream) {
        print("Session streamCreated: \(stream.streamId)")
        if subscriber == nil {
            doSubscribe(stream)
        }
    }
    
    func session(_ session: OTSession, streamDestroyed stream: OTStream) {
        print("Session streamDestroyed: \(stream.streamId)")
        if let subStream = subscriber?.stream, subStream.streamId == stream.streamId {
            cleanupSubscriber()
        }
    }
    
    func session(_ session: OTSession, didFailWithError error: OTError) {
        print("session Failed to connect: \(error.localizedDescription)")
    }
    
}

// MARK: - OTPublisher delegate callbacks
extension ViewController: OTPublisherDelegate {
    func publisher(_ publisher: OTPublisherKit, streamCreated stream: OTStream) {
        print("Publishing")
    }
    
    func publisher(_ publisher: OTPublisherKit, streamDestroyed stream: OTStream) {
        if let subStream = subscriber?.stream, subStream.streamId == stream.streamId {
            cleanupSubscriber()
        }
    }
    
    func publisher(_ publisher: OTPublisherKit, didFailWithError error: OTError) {
        print("Publisher failed: \(error.localizedDescription)")
    }
    
}

// MARK: - OTSubscriber delegate callbacks
extension ViewController: OTSubscriberDelegate {
    func subscriberDidConnect(toStream subscriberKit: OTSubscriberKit) {
        let videoRender = ExampleVideoRender()
        subscriber?.videoRender = videoRender

        videoRender.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height)
        //if let subsView = subscriber?.view {
            view.addSubview(videoRender)
        //}

        videoRender.delegate = self
    }
    
    func subscriber(_ subscriber: OTSubscriberKit, didFailWithError error: OTError) {
        print("Subscriber failed: \(error.localizedDescription)")
    }
    
    func subscriberVideoDataReceived(_ subscriber: OTSubscriber) {
    }
}

extension ViewController: ExampleVideoRenderDelegate {
    func renderer(_ renderer: ExampleVideoRender, didReceiveFrame videoFrame: OTVideoFrame) {
        //face detection
        if count % skipFrames == 0 {
            let image = toUIImage(videoFrame)

            image.detector.crop(type: .face) { [weak self] result in
                switch result {
                case .success(let croppedImages):
                    // When the `Vision` successfully find type of object you set and successfuly crops it.
                    DispatchQueue.main.async {
                        guard let self = self else {
                            return
                        }

                        self.imageView?.image = croppedImages[0]
                        self.imageView?.superview?.bringSubviewToFront(self.imageView!)
                    }
                    print("Found")
                case .notFound:
                    // When the image doesn't contain any type of object you did set, `result` will be `.notFound`.
                    print("Not Found")
                case .failure(let error):
                    // When the any error occured, `result` will be `failure`.
                    print(error.localizedDescription)
                }
            }


            /*let ciimage:CIImage! = CIImage(image: image)
            let detector: CIDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options:[CIDetectorAccuracy: CIDetectorAccuracyLow])!
            let features: [CIFeature] = detector.features(in: ciimage)

            if features.count > 0 {
                //found
                for feature in features {
                    let f = feature as? CIFaceFeature
                }
            }*/
        }
        count += 1
    }

    //Convert YUV to ARGB
    public func toUIImage(_ frame: OTVideoFrame) -> UIImage {
        var result: UIImage? = nil
        let width = frame.format?.imageWidth ?? 0
        let height = frame.format?.imageHeight ?? 0
        var pixelBuffer: CVPixelBuffer? = nil
        _ = CVPixelBufferCreate(kCFAllocatorDefault, Int(width), Int(height), kCVPixelFormatType_32BGRA, nil, &pixelBuffer)



        let start  = CFAbsoluteTimeGetCurrent()
        if pixelBuffer == nil {
            assert(false)
        }

        let subsampledWidth = frame.format!.imageWidth/2
        let subsampledHeight = frame.format!.imageHeight/2

        let planeSize = calculatePlaneSize(forFrame: frame)

        print("ysize : \(planeSize.ySize) \(planeSize.uSize) \(planeSize.vSize)")
        let yPlane = UnsafeMutablePointer<GLubyte>.allocate(capacity: planeSize.ySize)
        let uPlane = UnsafeMutablePointer<GLubyte>.allocate(capacity: planeSize.uSize)
        let vPlane = UnsafeMutablePointer<GLubyte>.allocate(capacity: planeSize.vSize)

        memcpy(yPlane, frame.planes?.pointer(at: 0), planeSize.ySize)
        memcpy(uPlane, frame.planes?.pointer(at: 1), planeSize.uSize)
        memcpy(vPlane, frame.planes?.pointer(at: 2), planeSize.vSize)

        let yStride = frame.format!.bytesPerRow.object(at: 0) as! Int
        let uStride = frame.format!.bytesPerRow.object(at: 1) as! Int
        let vStride = frame.format!.bytesPerRow.object(at: 2) as! Int

        var yPlaneBuffer = vImage_Buffer(data: yPlane, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: yStride)

        var uPlaneBuffer = vImage_Buffer(data: uPlane, height: vImagePixelCount(subsampledHeight), width: vImagePixelCount(subsampledWidth), rowBytes: uStride)


        var vPlaneBuffer = vImage_Buffer(data: vPlane, height: vImagePixelCount(subsampledHeight), width: vImagePixelCount(subsampledWidth), rowBytes: vStride)
        CVPixelBufferLockBaseAddress(pixelBuffer!, .readOnly)
        let pixelBufferData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        let rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer!)
        var destinationImageBuffer = vImage_Buffer()
        destinationImageBuffer.data = pixelBufferData
        destinationImageBuffer.height = vImagePixelCount(height)
        destinationImageBuffer.width = vImagePixelCount(width)
        destinationImageBuffer.rowBytes = rowBytes

        var permuteMap: [UInt8] = [3, 2, 1, 0] //BGRA
        let convertError = vImageConvert_420Yp8_Cb8_Cr8ToARGB8888(&yPlaneBuffer, &uPlaneBuffer, &vPlaneBuffer, &destinationImageBuffer, &infoYpCbCrToARGB, &permuteMap, 255, vImage_Flags(kvImagePrintDiagnosticsToConsole))

        print(convertError, kvImageInvalidParameter)

        CVPixelBufferUnlockBaseAddress(pixelBuffer!, [])


        yPlane.deallocate()
        uPlane.deallocate()
        vPlane.deallocate()


        var ciImage: CIImage? = nil
        if let pixelBuffer = pixelBuffer {
            ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        }

        let temporaryContext = CIContext(options: nil)
        var uiImage: CGImage? = nil
        if let ciImage = ciImage {
            uiImage = temporaryContext.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(pixelBuffer!), height: CVPixelBufferGetHeight(pixelBuffer!)))
        }

        if let uiImage = uiImage {
            result = UIImage(cgImage: uiImage)
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, [])
        return result!

    }

    fileprivate func calculatePlaneSize(forFrame frame: OTVideoFrame)
        -> (ySize: Int, uSize: Int, vSize: Int)
    {
        guard let frameFormat = frame.format
            else {
                return (0, 0 ,0)
        }
        let baseSize = Int(frameFormat.imageWidth * frameFormat.imageHeight) * MemoryLayout<GLubyte>.size
        return (baseSize, baseSize / 4, baseSize / 4)
    }
}
