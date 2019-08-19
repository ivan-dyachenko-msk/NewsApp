//
//  NetworkManager.swift
//  testNews
//
//  Created by Ivan Dyachenko on 15/08/2019.
//  Copyright © 2019 Ivan Dyachenko. All rights reserved.
//

import Foundation
import SystemConfiguration
import SDWebImage
import CoreData

protocol NetworkManagerProtocol: class {
    func getNews(page: Int)
}

class NetworkManager {
    
    weak var view: ViewController!
    var coreData = CoreDataManager()
    var newsArray = [News]()
    
    func getNews(page: Int) {
        
        let category = "business"
        let country = "ru"
        let api = "https://newsapi.org/v2/top-headlines?country=\(country)&category=\(category)&page=\(page)&apiKey=\(Constants.apiKey)"
        
        let urlString = URL(string: api)!
        
        if self.isConnectedToNetwork() == true {
            self.view.canLoad = true
            if page == 1 {
                self.coreData.deleteEntities(entity: "News")
            }
            let dataTask = URLSession.shared.dataTask(with: urlString, completionHandler: {(data, response, error) in
                if let error = error {
                    print(" Eroor in dataTask: \(error.localizedDescription)")
                }
                if let data = data {
                    do {
                        let d = try JSONSerialization.jsonObject(with: data, options: .mutableContainers)
                        DispatchQueue.main.async {
                            self.view.activityLoading.stopAnimating()
                            self.view.noData(hidden: false)
                            if self.view.refreshControl.isRefreshing == true {
                                self.view.refreshControl.endRefreshing()
                            }
                        }
                        self.parseNews(d: d as! [String : Any])
                    } catch let error {
                        print("error: \(error)")
                    }
                }
            })
            dataTask.resume()
        } else {
            self.view.canLoad = false
            DispatchQueue.main.async {
                self.view.activityLoading.stopAnimating()
                let context = self.coreData.persistentContainer.viewContext
                do {
                    let result = try context.fetch(News.fetchRequest())
                    if result.count == 0 {
                        self.view.noData(hidden: true)
                    }
                    for i in result as! [News] {
                        self.view.insertRow(row: i)
                    }
                } catch let error {
                    print("Failed to insert rows to table view: \(error)")
                }
                self.view.presentAlertNoConnection()
            }
        }
    }
    
    func parseNews(d: [String: Any]) {
        
        if let totalResults = d["totalResults"] as? Int {
            self.view.total = totalResults
        }
        
        if let articles = d["articles"] as? [[String: Any]] {
            self.view.inLoading += articles.count
            var title = ""
            var date = ""
            var description = ""
            let dateFormatterGet = DateFormatter()
            dateFormatterGet.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
            dateFormatterGet.timeZone = TimeZone(abbreviation: "UTC")
            let dateFormatterSet = DateFormatter()
            dateFormatterSet.timeZone = TimeZone(abbreviation: "UTC")
            
            for article in articles {

                if let tit = article["title"] as? String {
                    title = tit
                }
                if let datePub = article["publishedAt"] as? String {
                    let dateGet = dateFormatterGet.date(from: datePub)
                    dateFormatterSet.dateFormat = "dd"
                    let day = dateFormatterSet.string(from: dateGet ?? Date())
                    dateFormatterSet.dateFormat = "MM"
                    let month = dateFormatterSet.string(from: dateGet ?? Date())
                    dateFormatterSet.dateFormat = "yyyy"
                    let year = dateFormatterSet.string(from: dateGet ?? Date())
                    dateFormatterSet.dateFormat = "HH:ss"
                    let time = dateFormatterSet.string(from: dateGet ?? Date())
                    date = "\(day)-\(month)-\(year)\n\(time)"
                }
                if let desc = article["description"] as? String {
                    description = desc
                }
                if let url = article["urlToImage"] as? String {
                    self.save(title: title, desc: description, date: date, imageData: url)
                } else {
                    self.save(title: title, desc: description, date: date, imageData: "")
                    print("NO URL")
                }
            }
        }
    }
    
    func save(title: String, desc: String, date: String, imageData: String) {
        
        if self.coreData.someEntityExists(title: title) {
            let news = News(entity: News.entity(), insertInto: nil)
            news.title = title
            news.desc = desc
            news.date = date
            news.imageURL = imageData
            self.view.insertRow(row: self.coreData.loadImageFromDB(title: title) ?? news)
            print("ALREADY EXISTS")
        } else {
            let mainContext = self.coreData.persistentContainer.viewContext
            let backgroundContext = self.coreData.getBackgroundContext()
            let news = News(context: mainContext)
            news.title = title
            news.desc = desc
            news.date = date
            news.imageURL = imageData
            do {
                self.saveImage(imageUrl: imageData, closure: { data in
                    news.image = data
                    do {
                        self.setRows(row: news)
                        try backgroundContext.save()
                        try backgroundContext.parent?.save()
                        print("IMAGE SAVED")
                    } catch let error {
                        print("Error in DATA IMAGE: \(error.localizedDescription)")
                    }
                })
            } catch {
                print("Error in newsData: \(error.localizedDescription)")
            }
            self.coreData.saveContext()
        }
    }
    
    func setRows(row: News) {
        self.view.insertRow(row: row)
    }
    
    func saveImage(imageUrl: String, closure: @escaping (Data?) -> Void) {
        SDWebImageManager.shared.loadImage(with: URL(string: imageUrl), options: .fromLoaderOnly, progress: nil) { (image, data, error, cache, finished, url) in
            if finished {
                if image != nil {
                    closure(image?.sd_imageData())
                } else {
                    closure(nil)
                }
            }
        }
    }
    
    func isConnectedToNetwork() -> Bool {
        
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }
        
        var flags = SCNetworkReachabilityFlags()
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) {
            return false
        }
        let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
        let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
        return (isReachable && !needsConnection)
    }
}
