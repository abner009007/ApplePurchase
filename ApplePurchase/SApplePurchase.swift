//
//  SApplePurchase.swift
//  DATING
//
//  Created by 云中科技 on 2018/1/18.
//  Copyright © 2018年 深圳指掌人科技有限公司. All rights reserved.
//

import UIKit
import StoreKit


@objc public protocol applePurchaseDelegate: NSObjectProtocol{
    func getProductsFromApple(_ response: SKProductsResponse)
}

class SApplePurchase: NSObject {
    
    fileprivate weak var appleDelegate:applePurchaseDelegate?
    fileprivate var productDict:NSMutableDictionary?
    fileprivate let VERIFY_RECEIPT_URL = "https://buy.itunes.apple.com/verifyReceipt"
    fileprivate let ITMS_SANDBOX_VERIFY_RECEIPT_URL = "https://sandbox.itunes.apple.com/verifyReceipt"

    // 单例 
    static let shared = SApplePurchase.init()
    private override init(){}
    
    
    //最好是在AppDelegate里面添加监听,一旦下次近来的时候回自动检测到未完成的内购
    func addTransactionObserver() {
        SKPaymentQueue.default().add(self)
    }
    func removeTransactionObserver() {
        SKPaymentQueue.default().remove(self)
    }
    // 点击购买产品后触发的
    func startPaymentWithProductId(productId: String){
        //先判断是否支持内购
        if(SKPaymentQueue.canMakePayments())
        {
            let payment = SKPayment(product: productDict![productId] as! SKProduct)  
            SKPaymentQueue.default().add(payment)//添加到支付队列
        }
        else
        {
            
        }
    }
    //询问苹果的服务器能够销售哪些商品
    func requestProducts(_ delegate: applePurchaseDelegate){
        DataTools.getGoodsList { (ids: Set<String>) -> () in//从我们自己的服务器上获取需要销售的额商品  
            let request: SKProductsRequest = SKProductsRequest(productIdentifiers: ids)//上面的商品还要到苹果服务器进行验证, 看下哪些商品是可以真正被销售的（创建一个商品请求并设置请求的代理，由代理告知结果）  
            request.delegate = self//设置代理, 接收可以被销售的商品列表数据  
            request.start()
            appleDelegate = delegate
        }
    }
    
    func clearPurchasedFromApple(dictionary:NSDictionary,completion:@escaping() -> Void) {
        
        let dic = dictionary as! Dictionary<String, Any>
        let in_app_array = dic["in_app"] as! [Dictionary<String, Any>]
        let firstDic = in_app_array.first!
        let price = DataTools.getPrice(id: firstDic["product_id"] as! String)
        
        //取出数据以后开始和自己的后台进行验证
        
        
        
        
        
    }
}
extension SApplePurchase : SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {  
        for transaction in transactions {// 当交易队列里面添加的每一笔交易状态发生变化的时候调用  
            switch transaction.transactionState { 
            case .purchased:        //支付成功
                SApplePurchase.shared.verifyPruchase { (resultDictionary, error) in
                    if error == nil
                    {
                        //print("==================",resultDictionary!)
                        self.clearPurchasedFromApple(dictionary: resultDictionary!, completion: {
                            
                            //自己后台也验证成功以后吧这个内购清除掉,否者一直保留当前内购,每次开启app就会提醒这个内购
                            queue.finishTransaction(transaction)
                            
                        })
                    }
                }
            case .failed:           //支付失败
                queue.finishTransaction(transaction)
            case .purchasing:       //正在支付
                break
            case .deferred:         //延迟处理
                queue.finishTransaction(transaction)
                break
            case .restored:         //恢复购买
                queue.finishTransaction(transaction)  
            }  
        }  
    }
    // 比对字典中以下信息基本上可以保证数据安全
    // bundle_id&application_version&product_id&transaction_id
    // 验证成功
    func verifyPruchase(completion:@escaping(NSDictionary?, NSError?) -> Void) {
        // 验证凭据，获取到苹果返回的交易凭据
        let receiptURL = Bundle.main.appStoreReceiptURL
        // 从沙盒中获取到购买凭据
        let receiptData = NSData(contentsOf: receiptURL!)
        #if DEBUG
            let url = NSURL(string: ITMS_SANDBOX_VERIFY_RECEIPT_URL)
        #else
            let url = NSURL(string: VERIFY_RECEIPT_URL)
        #endif
        let request = NSMutableURLRequest(url: url! as URL, cachePolicy: NSURLRequest.CachePolicy.useProtocolCachePolicy, timeoutInterval: 10.0)
        request.httpMethod = "POST"
        let encodeStr = receiptData?.base64EncodedString(options: NSData.Base64EncodingOptions.endLineWithLineFeed)
        let payload = NSString(string: "{\"receipt-data\" : \"" + encodeStr! + "\"}")
        let payloadData = payload.data(using: String.Encoding.utf8.rawValue)
        request.httpBody = payloadData;
        
        let dataTask = URLSession.shared.dataTask(with: request as URLRequest) { (data, response, error) in
            if error != nil
            {
                completion(nil,error as NSError?)
            }
            else
            {
                if (data==nil) 
                {
                    completion(nil,error as NSError?)
                }
                do
                {
                    let jsonResult: NSDictionary = try JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers) as! NSDictionary
                    
                    if (jsonResult.count != 0) 
                    {
                        // 比对字典中以下信息基本上可以保证数据安全
                        // bundle_id&application_version&product_id&transaction_id
                        // 验证成功
                        print(jsonResult)
                        let receipt = jsonResult["receipt"] as! NSDictionary
                        completion(receipt,nil)
                    }
                    
                }
                catch
                {
                    completion(nil,nil)
                }
            }
        }
        dataTask.resume()
    }
}
extension SApplePurchase : SKProductsRequestDelegate {
    
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        // 当请求完毕之后, 从苹果服务器获取到数据之后调用  
//        for product in response.products 
//        {
//            //debugPrint("----------------",product.localizedTitle)
//            //print("=======================",product.productIdentifier)
//        }
          
        if (productDict == nil) 
        {
            productDict = NSMutableDictionary(capacity: response.products.count)
        }
        for product in response.products  
        {
            productDict!.setObject(product, forKey: product.productIdentifier as NSCopying)
        }
        appleDelegate?.getProductsFromApple(response)
    } 
}
//钻石需要购买以后才可以使用
class DataTools: NSObject {  
    class func getGoodsList(_ result: (Set<String>)->()) {  
        result(["com.zzr.ios.", 
                "com.zzr.ios.", 
                "com.zz", 
                "com.z",
                "com.zzr"])  
    } 
    class func getPrice(id:String) -> String {
        let dic = ["com.zzr.":"6", 
                   "com.zzr":"18", 
                   "com.zzr":"50", 
                   "com.zzr":"108",
                   "com.zzr":"518"]
        return dic[id]!
    }
}
