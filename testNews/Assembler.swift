//
//  Assembler.swift
//  testNews
//
//  Created by Ivan Dyachenko on 15/08/2019.
//  Copyright © 2019 Ivan Dyachenko. All rights reserved.
//

import Foundation

class Assembler {
    static let shared = Assembler()
    
    func assembly(vc: ViewController) {
        let networkManager = NetworkManager()
        vc.networkManager = networkManager
        networkManager.view = vc
    }
}
