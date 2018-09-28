//
//  ViewController.swift
//  RekogGate
//
//  Created by Gyuri Trum on 2018. 09. 28..
//  Copyright © 2018. onceapps. All rights reserved.
//
import UIKit
import AVFoundation
import Vision
import PromiseKit

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
  let label: UILabel = {
    let label = UILabel()
    label.textColor = .white
    label.translatesAutoresizingMaskIntoConstraints = false
    label.text = "Nem látok senkit 😞"
    label.font = label.font.withSize(30)
    return label
  }()
  
  let drawingView: UIView = {
    let view = UIView()
    view.backgroundColor = UIColor.white.withAlphaComponent(0.1)
    return view
  }()
  
  var scaledWidth: CGFloat = 0
  var checkerIsOn = true
  
  var lastFaceRekognitionRectangle: UIView? = nil
  var open = true
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    setupCaptureSession()
    drawingView.frame = CGRect.init(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.height)

    view.addSubview(label)
    view.addSubview(drawingView)
    setupLabel()
  }
  
  func setupCaptureSession() {
    // creates a new capture session
    let captureSession = AVCaptureSession()
    
    // search for available capture devices
    let availableDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .front).devices
    
    // get capture device, add device input to capture session
    do {
      if let captureDevice = availableDevices.first {
        captureSession.addInput(try AVCaptureDeviceInput(device: captureDevice))
      }
    } catch {
      print(error.localizedDescription)
    }
    
    // setup output, add output to capture session
    let captureOutput = AVCaptureVideoDataOutput()
    captureSession.addOutput(captureOutput)
    
    captureOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
    
    let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    previewLayer.frame = view.frame
    view.layer.addSublayer(previewLayer)
    
    captureSession.startRunning()
  }
  
  func convertCIImageToCGImage(inputImage: CIImage) -> CGImage? {
    let context = CIContext(options: nil)
    return context.createCGImage(inputImage, from: inputImage.extent) ?? nil
  }
  
  // called everytime a frame is captured
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    let imageBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
    let inputImage : CIImage = CIImage(cvPixelBuffer: imageBuffer)
    
    if (scaledWidth == 0) {
      DispatchQueue.main.async { [weak self] in
        let image = UIImage.init(ciImage: inputImage)
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        
        self?.scaledWidth = (self?.view.frame.width)! / image.size.height * image.size.width
        let newHeight = (self?.view.frame.width)! / image.size.height * image.size.width
        let newWidth = (self?.view.frame.height)! / image.size.width * image.size.height
        
//        self?.drawingView.frame = CGRect.init(x: ((self?.view.frame.size.width)! - newWidth)/2, y: ((self?.view.frame.size.height)! - newHeight)/2, width: newWidth, height: newHeight)
      }
      return
    }
    
    // Detect any faces in the image
    let detector = CIDetector(ofType: CIDetectorTypeFace,
                              context: nil,
                              options: nil)

    let features = detector?.features(in: inputImage)
    if checkerIsOn {
      let request = VNDetectFaceRectanglesRequest { (req, err) in
        
        if let err = err {
          print("Failed to detect faces:", err)
          return
        }
        
        var enoughBig = false
        var biggestFaceObservationObject: VNFaceObservation? = nil
        var faceHeight = CGFloat(0)
        
        req.results?.forEach({ (res) in
          if let faceObservation = res as? VNFaceObservation{
            if faceObservation.boundingBox.height > faceHeight {
              faceHeight = faceObservation.boundingBox.height
              biggestFaceObservationObject = faceObservation
            }
            
            if (faceObservation.boundingBox.width > 0.3 && faceObservation.boundingBox.height > 0.3) {
              enoughBig = true
            }
          }
          
          DispatchQueue.main.async { [weak self] in
            guard let faceObservation = res as? VNFaceObservation else { return }
            //self?.drawingView.addSubview(self?.generateBlueRectangleView(faceObservation: faceObservation) ?? UIView())
          }
        })
        
        if let count = req.results?.count, count > 0 {
          if let faceObject = biggestFaceObservationObject {
            let newBlueRectangle = self.generateBlueRectangleView(faceObservation: faceObject)
            
            if enoughBig {
              DispatchQueue.main.async { [weak self] in
                self?.label.text = "Arc felismerve 😎 Nyitas!"
                
                if self?.lastFaceRekognitionRectangle != nil {
                  self?.animateBlueRectangleView(nextBlueRectangle: self?.generateBlueRectangleView(faceObservation: faceObject) ?? UIView())
                } else {
                  self?.lastFaceRekognitionRectangle = self?.generateBlueRectangleView(faceObservation: faceObject)
                  self?.animateInRectangle()
                }
                
                let image = UIImage.init(ciImage: inputImage)
                var imageData = image.pngData()
                if self?.open ?? false {
                  firstly {
                    NetworkManager.sharedManager.getImageSchools(data: imageData)
                    }.done { success  in
                      print("done")
                    }.ensure { [weak self] in
                      self?.checkerIsOn = false
                      DispatchQueue.main.async {
                        //self?.drawingView.backgroundColor = UIColor.white.withAlphaComponent(1)
                      }
                      
                      _ = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false, block: { [weak self] _ in
                        self?.checkerIsOn = true
                      })
                      
                      self?.open = false
                      _ = Timer.scheduledTimer(withTimeInterval: 5, repeats: false, block: { [weak self] _ in
                        self?.open = true
                        DispatchQueue.main.async {
                          //self?.drawingView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
                        }
                      })
                      print("always")
                    }.catch { [weak self] error in
                      print(error.localizedDescription)
                  }
                }

              }
            } else {
              DispatchQueue.main.async{ [weak self] in
                if self?.lastFaceRekognitionRectangle != nil {
                  self?.animateBlueRectangleView(nextBlueRectangle: self?.generateBlueRectangleView(faceObservation: faceObject) ?? UIView())
                } else {
                  self?.lastFaceRekognitionRectangle = self?.generateBlueRectangleView(faceObservation: faceObject)
                  self?.animateInRectangle()
                }
                
                self?.label.text = "Gyere közelebb 🔑"
                self?.checkerIsOn = false
                _ = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false, block: { [weak self] _ in
                  self?.checkerIsOn = true
                })
              }
            }
          }
            
        } else {
          DispatchQueue.main.async{ [weak self] in
            self?.label.text = "Nem látok senkit 😞"
            self?.lastFaceRekognitionRectangle = nil
            DispatchQueue.main.async { [weak self] in
              self?.drawingView.subviews.map({$0.removeFromSuperview()})
            }
          }
        }
      }
      
      if let cgImage = convertCIImageToCGImage(inputImage: inputImage) {
        DispatchQueue.global(qos: .userInteractive).async {
          let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
          do {
            try handler.perform([request])
          } catch let reqErr {
            print("Failed to perform request:", reqErr)
          }
        }
      }
    }
  }
  
  
  func animateBlueRectangleView(nextBlueRectangle: UIView) {
    UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseIn], animations: {
      //Frame Option 1:
      self.lastFaceRekognitionRectangle?.frame = CGRect(x: nextBlueRectangle.frame.origin.x, y: nextBlueRectangle.frame.origin.y, width: nextBlueRectangle.frame.width, height: nextBlueRectangle.frame.height)
      }) { (done) in
      
      }
  }
  
  func generateBlueRectangleView(faceObservation: VNFaceObservation) -> UIView {
    let x = view.frame.width * (1 - faceObservation.boundingBox.origin.y)
    let width = view.frame.height * faceObservation.boundingBox.width
    let y = view.frame.height *  faceObservation.boundingBox.origin.x
    let height = view.frame.width * faceObservation.boundingBox.height
    let blueView = UIView()
    blueView.layer.borderColor = UIColor.blue.cgColor
    blueView.layer.borderWidth = 3
    blueView.alpha = 0.4
    blueView.frame = CGRect(x: x - width, y: y , width: width, height: height * 0.7)
    return blueView
  }
  
  func animateInRectangle() {
    self.drawingView.addSubview(self.lastFaceRekognitionRectangle ?? UIView())
    self.lastFaceRekognitionRectangle?.transform = CGAffineTransform(scaleX: 0.2, y: 0.2)
    UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseIn], animations: {
      //Frame Option 1:
      self.lastFaceRekognitionRectangle?.transform = CGAffineTransform.identity
    }) { (done) in
      
    }
  }
  
  func animateOutRectangle() {
    self.drawingView.addSubview(self.lastFaceRekognitionRectangle ?? UIView())
    UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseIn], animations: {
      //Frame Option 1:
      self.lastFaceRekognitionRectangle?.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
    }) { (done) in
      
    }
  }
  
  func setupLabel() {
    label.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
    label.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50).isActive = true
    
    drawingView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
    drawingView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
    drawingView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
    drawingView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

  }
}

