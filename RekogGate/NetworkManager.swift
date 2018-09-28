//
//  NetworkManager.swift
//  RekogGate
//
//  Created by Gyuri Trum on 2018. 09. 28..
//  Copyright © 2018. onceapps. All rights reserved.
//

import Foundation
import PromiseKit
import Alamofire

class NetworkManager: NSObject {
  
  private var headers: HTTPHeaders = [
    "Content-Type": "application/json",
    "Cache-Control": "no-cache"
  ]
  
  static let sharedManager = NetworkManager()
  
  func getImageSchools(data: Data?) -> Promise<Bool> {
    return Promise { seal in
      Alamofire.request("http://192.168.9.49/open", headers: headers)
        .validate(contentType: ["application/json"])
        .response { data in
          //self.checkAuthorization(response: data.response)
          if let httpResponse = data.response {
            if let etag = httpResponse.allHeaderFields["Etag"] as? String {
            }
          }
        
          if data.response?.statusCode != 200 {
            seal.reject(NSError.init(domain: "", code: -1, userInfo: nil))
          } else {
            seal.fulfill(true)
          }
          
        }
    }
  }
}
