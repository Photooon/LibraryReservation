//
//  SeatNetworkBaseManager.swift
//  LibraryReservation
//
//  Created by Weston Wu on 2018/04/17.
//  Copyright © 2018 Weston Wu. All rights reserved.
//

import WatchKit

public enum SeatAPIError: Int, Error {
    
    case dataCorrupt
    case dataMissing
    case unknown
    
}

public protocol SeatBaseDelegate: class {
    func requireLogin()
    func updateFailed(error: Error)
    func updateFailed(failedResponse: SeatFailedResponse)
}

public class SeatBaseNetworkManager: NSObject {
    
    let taskQueue: DispatchQueue
    public static let `default` = SeatBaseNetworkManager(queue: DispatchQueue(label: "com.westonwu.ios.libraryReservation.seat.base.default"))
    let session = URLSession.shared
    
    private override init() {
        fatalError("invalid seat network manager init")
    }
    
    public init(queue: DispatchQueue?) {
        taskQueue = queue ?? SeatBaseNetworkManager.default.taskQueue
        super.init()
    }
    
    public func login(username: String, password: String, callback: ((Error?, SeatLoginResponse?, SeatFailedResponse?)->Void)?) {
        guard let username = username.urlQueryEncoded,
            let password = password.urlQueryEncoded else {
                return
        }
        let loginQuery = "username=\(username)&password=\(password)"
        let loginURL = URL(string: "auth?\(loginQuery)", relativeTo: SeatAPIURL)!
        var loginRequest = URLRequest(url: loginURL)
        loginRequest.allHTTPHeaderFields = CommonHeader
        loginRequest.httpMethod = "GET"
        loginRequest.timeoutInterval = 10
        let loginTask = session.dataTask(with: loginRequest) { data, response, error in
            if let error = error {
                print(error.localizedDescription)
                DispatchQueue.main.async {
                    callback?(error, nil, nil)
                }
                return
            }
            
            guard let data = data else {
                print("Failed to retrive data")
                DispatchQueue.main.async {
                    callback?(SeatAPIError.dataMissing, nil, nil)
                }
                return
            }
            
            let decoder = JSONDecoder()
            do {
                let loginResponse = try decoder.decode(SeatLoginResponse.self, from: data)
                DispatchQueue.main.async {
                    callback?(nil, loginResponse, nil)
                }
            } catch DecodingError.valueNotFound {
                do {
                    let failedResponse = try decoder.decode(SeatFailedResponse.self, from: data)
                    DispatchQueue.main.async {
                        callback?(nil, nil, failedResponse)
                    }
                } catch {
                    DispatchQueue.main.async {
                        callback?(error, nil, nil)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    callback?(error, nil, nil)
                }
            }
        }
        loginTask.resume()
    }
    
    func delete(filePath kFilePath: String) {
            let fileManager = FileManager.default
            let path = GroupURL.appendingPathComponent(kFilePath)
            try? fileManager.removeItem(atPath: path.absoluteString)
    }
    
    func load(filePath kFilePath: String) -> Data? {
        let path = GroupURL.appendingPathComponent(kFilePath)
        return try? Data(contentsOf: path)
    }
    
    func save(data: Data, filePath kFilePath: String) {
        let path = GroupURL.appendingPathComponent(kFilePath)
        do {
            try data.write(to: path)
        } catch {
            print(error.localizedDescription)
            return
        }
    }
    
}
