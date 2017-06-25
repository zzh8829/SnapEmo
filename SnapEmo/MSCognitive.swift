//
//  MSCognitive.swift
//  SnapEmo
//
//  Created by Monster on 2017-06-24.
//  Copyright © 2017 University of Melbourne. All rights reserved.
//

import UIKit

enum Emotion: String {
    case anger = "anger"
    case contempt = "contempt"
    case disgust = "disgust"
    case fear = "fear"
    case happiness = "happiness"
    case neutral = "neutral"
    case sadness = "sadness"
    case surprise = "surprise"
}


class MSCognitive {
    
    func convert(cImage: CIImage) -> UIImage {
        let context: CIContext = CIContext.init(options: nil)
        let cgImage: CGImage = context.createCGImage(cImage, from: cImage.extent)!
        let image: UIImage = UIImage.init(cgImage: cgImage)
        return image
    }
    
    func postImageData(cImage: CIImage, completion: @escaping (CGRect?, Emotion, Double) -> ()) {
        let requestUrl = URL(string: "https://westus.api.cognitive.microsoft.com/emotion/v1.0/recognize")
        let key = "b2ecededcbe3486fae0a8976b794e4f2"
        
        var request = URLRequest(url: requestUrl!)
        request.setValue(key, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        
        let image = convert(cImage: cImage)
        let imageData = UIImagePNGRepresentation(image)
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
                self.analyzeResult(array: results as! [Any], completion: { rect, emotion, score in
                    
                    guard let resultRect = rect else {
                        completion(nil, emotion, 0)
                        return
                    }
                    
                    print(resultRect)
                    print(emotion)
                    print(score)
                    
                    completion(resultRect, emotion, score)
                })
            }
            
        }
        task.resume()
        
    }
    
    func analyzeResult(array: [Any], completion: @escaping (CGRect?, Emotion, Double) -> ()) {
        if array.count == 0 {
            completion(nil, Emotion.anger, 0)
            return
        }
        guard let dict = array[0] as? [String : Any] else {
            completion(nil, Emotion.anger, 0)
            return
        }
        guard let faceRect = dict["faceRectangle"] as? [String : Int] else {
            completion(nil, Emotion.anger, 0)
            return
        }
        
        let height = faceRect["height"]
        let width = faceRect["width"]
        let top = faceRect["top"]
        let left = faceRect["left"]
        
        let rect = CGRect(x: left!, y: top!, width: width!, height: height!)
        
        guard let emotionScores = dict["scores"] as? [String : Double] else {
            completion(nil, Emotion.anger, 0)
            return
        }
        
        let max = emotionScores.values.max()
        
        for (key, value) in emotionScores {
            if value == max {
                for emotion in iterateEnum(Emotion.self) {
                    // do something with suit
                    if emotion.rawValue == key {
                        completion(rect, emotion, max!)
                    }
                }
                
            }
        }
    }
    
    func iterateEnum<T: Hashable>(_: T.Type) -> AnyIterator<T> {
        var i = 0
        return AnyIterator {
            let next = withUnsafeBytes(of: &i) { $0.load(as: T.self) }
            if next.hashValue != i { return nil }
            i += 1
            return next
        }
    }
}

