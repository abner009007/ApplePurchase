//
//  ViewController.swift
//  ApplePurchase
//
//  Created by 云中科技 on 2018/3/19.
//  Copyright © 2018年 云中科技. All rights reserved.
//

import UIKit
import StoreKit

class ViewController: UIViewController {
    
    var products: [SKProduct] = [SKProduct]() {//数据源  
        didSet {  
            //刷新表 
        }  
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        SApplePurchase.shared.requestProducts(self)
    }

   

}
extension ViewController: applePurchaseDelegate {  
    func getProductsFromApple(_ response: SKProductsResponse) {
        
        guard response.products.count > 0 else {
            return
        }
        guard (response.products.first?.localizedTitle.count)! > 0 else {
            return
        }
        products = response.products
        //根据钻石个数排序
        products.sort{ (product1, product2) -> Bool in
            let price_product1 = product1.price
            let price_product2 = product2.price
            return Int(price_product1) < Int(price_product2)
        }
    }
}
