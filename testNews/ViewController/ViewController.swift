//
//  ViewController.swift
//  testNews
//
//  Created by Ivan Dyachenko on 15/08/2019.
//  Copyright © 2019 Ivan Dyachenko. All rights reserved.
//

import UIKit
import SDWebImage

protocol ViewControllerProtocol: class {
    func presentAlertNoConnection()
    func insertRow(row: News)
    func noData(hidden: Bool)
    var page: Float { get set }
    var total: Float { get set }
    var refreshControl: UIRefreshControl { get set }
    var inLoading: Float { get set }
    var activityLoading: UIActivityIndicatorView { get set }
    var canLoad: Bool { get set }
}

class ViewController: UIViewController {

    @IBOutlet weak var newsTableView: UITableView!
    
    var networkManager: NetworkManager!
    var coredata = CoreDataManager()
    
    var newsCDArray = [News]()
    var total = 0
    var page = 1
    var inLoading = 0
    var refreshControl = UIRefreshControl()
    var activity = UIActivityIndicatorView()
    var activityLoading = UIActivityIndicatorView()
    var canLoad = true
    let noDataLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Assembler.shared.assembly(vc: self)
        
        self.setupTableView()
        self.setupActivityLoading()
        self.networkManager.getNews(page: 1)
        self.refreshControl.addTarget(self, action: #selector(self.refresh(sender:)), for: .valueChanged)
        self.newsTableView.addSubview(refreshControl)
        self.newsTableView.separatorStyle = .none
        self.activity.hidesWhenStopped = true
        self.activity.style = .gray
        self.noDataLabel.frame.size = CGSize(width: self.view.frame.width, height: 50)
        self.noDataLabel.frame = CGRect(x: 0, y: self.view.center.y - 25, width: self.view.frame.width, height: 50)
        self.noDataLabel.textAlignment = .center
        self.noDataLabel.text = "Нет ранее сохраненных новостей"
    }
    
    func setupActivityLoading() {
        self.activityLoading.style = .whiteLarge
        self.activityLoading.color = .lightGray
        self.activityLoading.hidesWhenStopped = true
        self.activityLoading.frame.size = CGSize(width: 40, height: 40)
        self.activityLoading.center = self.view.center
        self.view.addSubview(activityLoading)
        self.activityLoading.startAnimating()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
//        self.coredata.deleteEntities(entity: "News")
    }
    
    func noData(hidden: Bool) {
        if hidden == true {
            self.view.addSubview(noDataLabel)
        } else {
            self.noDataLabel.removeFromSuperview()
        }
    }
    
    @objc func refresh(sender: AnyObject) {
        DispatchQueue.main.async {
            self.newsCDArray.removeAll()
            self.newsTableView.reloadData()
            self.page = 1
            self.inLoading = 0
            self.networkManager.getNews(page: self.page)
        }
    }
    
    func insertRow(row: News) {
        DispatchQueue.main.async {
            self.activity.stopAnimating()
            if self.newsCDArray.contains(row) == false {
                self.newsCDArray.append(row)
                self.newsTableView.beginUpdates()
                let indexPaths = IndexPath(row: self.newsCDArray.count - 1, section: 0)
                self.newsTableView.insertRows(at: [indexPaths], with: .fade)
                self.newsTableView.endUpdates()
            }
        }
    }
    
    func presentAlertNoConnection() {
        let alert = UIAlertController(title: "Ошибка", message: "Нет соединения, попробуйте снова", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default, handler: {_ in
            alert.dismiss(animated: true, completion: nil)
        })
        alert.addAction(action)
        if self.refreshControl.isRefreshing {
            self.newsTableView.setContentOffset(.zero, animated: true)
            self.refreshControl.endRefreshing()
        }
        self.activity.stopAnimating()
        self.present(alert, animated: true, completion: nil)
    }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    
    func setupTableView() {
        self.newsTableView.register(UINib(nibName: "NewsTableViewCell", bundle: nil), forCellReuseIdentifier: "cell")
        self.newsTableView.delegate = self
        self.newsTableView.dataSource = self
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.newsCDArray.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! NewsTableViewCell
        cell.titleLabel.text = self.newsCDArray[indexPath.row].title
        cell.descriptionLabel.text = self.newsCDArray[indexPath.row].desc
        cell.dateLabel.text = self.newsCDArray[indexPath.row].date
        cell.newsImageView.layer.cornerRadius = 7
        if let data = self.newsCDArray[indexPath.row].image {
            cell.newsImageView.image = UIImage(data: data)
        } else {
            cell.newsImageView.image = UIImage(imageLiteralResourceName: "no_image")
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 200
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 200
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let lastRowIndex = tableView.numberOfRows(inSection: 0) - 1
        print("INDEX PATH: \(indexPath.row), lastIndex: \(lastRowIndex), total: \(self.total), canLoad: \(self.canLoad), ARRAY COUNT: \(self.newsCDArray.count)")
        if indexPath.row == lastRowIndex && self.total > self.newsCDArray.count && self.canLoad == true && indexPath.row == self.inLoading - 1 {
            self.activity.startAnimating()
            self.activity.frame = CGRect(x: CGFloat(0), y: CGFloat(0), width: tableView.bounds.width, height: CGFloat(44))
            self.newsTableView.tableFooterView = self.activity
            self.newsTableView.tableFooterView?.isHidden = false
            self.page += 1
            self.networkManager.getNews(page: self.page)
        }
    }
}

