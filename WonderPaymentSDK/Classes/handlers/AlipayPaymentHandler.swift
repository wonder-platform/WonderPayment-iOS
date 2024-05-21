//
//  AlipayPaymentHandler.swift
//  PaymentSDK
//
//  Created by X on 2024/3/12.
//

import Foundation



class AlipayPaymentHandler : PaymentHander {
    
    func pay(intent: PaymentIntent, delegate: PaymentDelegate) {
        delegate.onProcessing()
        
        var payment_inst = "ALIPAYCN"
        if intent.paymentMethod?.type == .alipayHK {
            payment_inst = "ALIPAYHK"
        }
        
        intent.paymentMethod?.arguments = [
            "alipay": [
                "amount": "\(intent.amount)",
                "in_app": [
                    "app_env": "ios",
                    "payment_inst": payment_inst,
                ]
            ]
        ]
        
        PaymentService.payOrder(intent: intent) {
            result, error in
            if let transaction = result?.transaction
            {
                let json = DynamicJson.from(transaction.acquirerResponseBody)
                guard let paymentString = json["alipay"]["in_app"]["payinfo"].string else {
                    delegate.onFinished(intent: intent, result: result, error: .dataFormatError)
                    return
                }
          
                delegate.onInterrupt(intent: intent)
                
                AlipaySDK.defaultService().payOrder(paymentString, fromScheme: WonderPayment.paymentConfig.fromScheme) { 
                    data in
                    //WebView 回调
                    let resultStatus = data?["resultStatus"]
                    let memo = data?["memo"]
                    let callbackData: [String: Any?] = ["resultStatus": resultStatus, "memo": memo]
                    WonderPayment.alipayCallback?(callbackData)
                }
                
                WonderPayment.alipayCallback = { data in
                    let resultStatus = data["resultStatus"] as? String
                    let memo = data["memo"] as? String
                    if resultStatus == "9000" {
                        let orderNum = intent.orderNumber
                        delegate.onProcessing()
                        PaymentService.loopForResult(uuid: transaction.uuid, orderNum: orderNum) {
                            result, error in
                            delegate.onFinished(intent: intent, result: result, error: error)
                        }
                    } else {
                        if resultStatus == "6001" {
                            delegate.onCanceled()
                        } else {
                            let error = ErrorMessage(code: "\(resultStatus ?? "")", message: memo ?? "")
                            delegate.onFinished(intent: intent, result: nil, error: error)
                        }
                    }
                }
                
            } else {
                delegate.onFinished(intent: intent, result: result, error: error)
            }
        }
    }
    
}
