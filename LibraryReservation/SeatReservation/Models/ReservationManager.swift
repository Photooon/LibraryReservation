//
//  ReservationManager.swift
//  LibraryReservation
//
//  Created by Weston Wu on 2018/05/17.
//  Copyright © 2018 Weston Wu. All rights reserved.
//

struct ReservationArchive: Codable {
    let reservation: SeatReservation?
    let historys: [SeatReservation]
}

class ReservationManager: NSObject {
    var account = AccountManager.shared.currentAccount
    var reservation: SeatReservation? {
        didSet {
            NotificationManager.shared.schedule(reservation: reservation)
            WatchAppDelegate.shared.transfer(reservation: reservation)
        }
    }
    var historys: [SeatReservation] = []
    var manager = SeatHistoryManager()
    static let shared = ReservationManager()
    
    private override init() {
        super.init()
        load()
        NotificationCenter.default.addObserver(self, selector: #selector(accountLogin(notification:)), name: .AccountLogin, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(accountLogout(notification:)), name: .AccountLogout, object: nil)
    }
    
    @objc func accountLogout(notification: Notification) {
        guard let account = notification.userInfo?["OldAccount"] as? UserAccount else {
            return
        }
        delete(account: account)
    }
    
    @objc func accountLogin(notification: Notification) {
        guard let account = notification.userInfo?["NewAccount"] as? UserAccount else {
            return
        }
        self.account = account
        reservation = nil
        historys = []
        load()
    }
    
    func load() {
        load(account: account)
    }
    
    func load(account: UserAccount?) {
        guard let account = account else {
            reservation = nil
            historys = []
            return
        }
        let path = GroupURL.appendingPathComponent("SeatReservation-\(account.username).archive")
        let decoder = JSONDecoder()
        guard let data = try? Data(contentsOf: path),
            let archive = try? decoder.decode(ReservationArchive.self, from: data) else {
                reservation = nil
                historys = []
                return
        }
        reservation = archive.reservation
        historys = archive.historys
    }
    
    func save() {
        save(account: account)
    }
    
    func save(account: UserAccount?) {
        guard let account = account else {
            return
        }
        guard let reservation = reservation else {
            delete()
            return
        }
        let encoder = JSONEncoder()
        let filePath = GroupURL.appendingPathComponent("SeatReservation-\(account.username).archive")
        let data = try! encoder.encode(reservation)
        do {
            try data.write(to: filePath)
        }catch{
            print(error.localizedDescription)
        }
    }
    
    func delete() {
        delete(account: account)
    }
    
    func delete(account: UserAccount?) {
        guard let account = account else {
            return
        }
        let fileManager = FileManager.default
        let filePath = GroupURL.appendingPathComponent("SeatReservation-\(account.username).archive")
        try? fileManager.removeItem(atPath: filePath.absoluteString)
    }
    
    func refresh(callback: SeatHandler<SeatReservation?>?) {
        manager.fetchHistory(page: 1) { (response) in
            switch response {
            case .error(let error):
                callback?(.error(error))
            case .failed(let failedResponse):
                callback?(.failed(failedResponse))
            case .requireLogin:
                callback?(.requireLogin)
            case .success(let reservations):
                self.reservation = nil
                self.historys = reservations
                for reservation in reservations {
                    if !reservation.isHistory {
                        self.reservation = reservation
                        break
                    }
                }
                self.save()
                callback?(.success(self.reservation))
            }
        }
    }
    
    func cancel(callback: SeatHandler<Void>?) {
        guard let reservation = reservation else {
            callback?(.success(()))
            return
        }
        manager.cancel(reservation: reservation) { (response) in
            switch response {
            case .error(let error):
                callback?(.error(error))
            case .failed(let failedResponse):
                callback?(.failed(failedResponse))
            case .requireLogin:
                callback?(.requireLogin)
            case .success(_):
                self.reservation = nil
                self.delete()
                callback?(.success(()))
            }
        }
    }
    
    func fetch(page: Int, callback: SeatHandler<[SeatReservation]>?) {
        manager.fetchHistory(page: page) { (response) in
            callback?(response)
            if page == 0,
                case .success(let reservations) = response {
                self.historys = reservations
                for reservation in reservations {
                    if !reservation.isHistory {
                        self.reservation = reservation
                        break
                    }
                }
            }
        }
    }
}

