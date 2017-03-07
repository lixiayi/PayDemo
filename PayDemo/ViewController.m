//
//  ViewController.m
//  PayDemo
//
//  Created by xiaoyi li on 16/9/14.
//  Copyright © 2016年 xiaoyi li. All rights reserved.
//

#import "ViewController.h"
#import <PassKit/PassKit.h>                                 //用户绑定的银行卡信息
#import <PassKit/PKPaymentAuthorizationViewController.h>    //Apple pay的展示控件
#import <AddressBook/AddressBook.h>                         //用户联系信息相关
#import "GTMBase64.h"

@interface ViewController ()<PKPaymentAuthorizationViewControllerDelegate>
@property (nonatomic, strong) NSMutableArray *summaryItems;
@property (weak, nonatomic) IBOutlet UIButton *button;

@end

@implementation ViewController
- (IBAction)butClick:(id)sender {
    
    
    if (![PKPaymentAuthorizationViewController class]) {
        //PKPaymentAuthorizationViewController需iOS8.0以上支持
        NSLog(@"操作系统不支持ApplePay，请升级至9.0以上版本，且iPhone6以上设备才支持");
        return;
    }
    
    //检查当前设备是否可以支付
    if (![PKPaymentAuthorizationViewController canMakePayments]) {
        //支付需iOS9.0以上支持
        NSLog(@"设备不支持ApplePay，请升级至9.0以上版本，且iPhone6以上设备才支持");
        return;
    }
    
    //检查用户是否可进行某种卡的支付，是否支持Amex、MasterCard、Visa与银联四种卡，根据自己项目的需要进行检测
    NSArray *supportedNetworks = @[PKPaymentNetworkAmex, PKPaymentNetworkMasterCard,PKPaymentNetworkVisa,PKPaymentNetworkChinaUnionPay];
    if (![PKPaymentAuthorizationViewController canMakePaymentsUsingNetworks:supportedNetworks]) {
        NSLog(@"wallet没有绑定支付卡");
        
        // 创建一个设置按钮;当用户点击的时候跳转到添加银行卡的界面;
        PKPaymentButton *button = [PKPaymentButton buttonWithType:PKPaymentButtonTypeSetUp style:PKPaymentButtonStyleWhiteOutline];
        button.frame = CGRectMake(200, 200, 100, 44);
        [button addTarget:self action:@selector(jump) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:button];
        return;
    }
    
    
    // 设置币种、国家码及merchant标识符等基本信息
    PKPaymentRequest *payRequest = [[PKPaymentRequest alloc]init];
    payRequest.countryCode = @"CN";     //国家代码
    payRequest.currencyCode = @"CNY";       //RMB的币种代码
    payRequest.merchantIdentifier = @"merchant.com.pcidata";  //申请的merchantID
    payRequest.supportedNetworks = supportedNetworks;   //用户可进行支付的银行卡
    payRequest.merchantCapabilities = PKMerchantCapability3DS|PKMerchantCapabilityEMV;      //设置支持的交易处理协议，3DS必须支持，EMV为可选，目前国内的话还是使用两者吧
    
    //    payRequest.requiredBillingAddressFields = PKAddressFieldEmail;
    //如果需要邮寄账单可以选择进行设置，默认PKAddressFieldNone(不邮寄账单)
    //楼主感觉账单邮寄地址可以事先让用户选择是否需要，否则会增加客户的输入麻烦度，体验不好，
    payRequest.requiredShippingAddressFields = PKAddressFieldPostalAddress|PKAddressFieldPhone|PKAddressFieldName;
    //送货地址信息，这里设置需要地址和联系方式和姓名，如果需要进行设置，默认PKAddressFieldNone(没有送货地址)
    
    //设置两种配送方式
    PKShippingMethod *freeShipping = [PKShippingMethod summaryItemWithLabel:@"包邮" amount:[NSDecimalNumber zero]];
    freeShipping.identifier = @"freeshipping";
    freeShipping.detail = @"6-8 天 送达";
    
    PKShippingMethod *expressShipping = [PKShippingMethod summaryItemWithLabel:@"极速送达" amount:[NSDecimalNumber decimalNumberWithString:@"10.00"]];
    expressShipping.identifier = @"expressshipping";
    expressShipping.detail = @"2-3 小时 送达";
    
    payRequest.shippingMethods = @[freeShipping, expressShipping];
    
    
    
    NSDecimalNumber *subtotalAmount = [NSDecimalNumber decimalNumberWithMantissa:1275 exponent:-2 isNegative:NO];   //12.75
    PKPaymentSummaryItem *subtotal = [PKPaymentSummaryItem summaryItemWithLabel:@"商品价格" amount:subtotalAmount];
    
    NSDecimalNumber *discountAmount = [NSDecimalNumber decimalNumberWithString:@"-12.74"];      //-12.74
    PKPaymentSummaryItem *discount = [PKPaymentSummaryItem summaryItemWithLabel:@"优惠折扣" amount:discountAmount];
    
    NSDecimalNumber *methodsAmount = [NSDecimalNumber zero];
    PKPaymentSummaryItem *methods = [PKPaymentSummaryItem summaryItemWithLabel:@"包邮" amount:methodsAmount];
    
    NSDecimalNumber *totalAmount = [NSDecimalNumber zero];
    totalAmount = [totalAmount decimalNumberByAdding:subtotalAmount];
    totalAmount = [totalAmount decimalNumberByAdding:discountAmount];
    totalAmount = [totalAmount decimalNumberByAdding:methodsAmount];
    PKPaymentSummaryItem *total = [PKPaymentSummaryItem summaryItemWithLabel:@"pcidata" amount:totalAmount];  //最后这个是支付给谁。哈哈，快支付给我
    
    _summaryItems = [NSMutableArray arrayWithArray:@[subtotal, discount, methods, total]];
    //summaryItems为账单列表，类型是 NSMutableArray，这里设置成成员变量，在后续的代理回调中可以进行支付金额的调整。
    payRequest.paymentSummaryItems = _summaryItems;
    
    PKPaymentAuthorizationViewController *view = [[PKPaymentAuthorizationViewController alloc]initWithPaymentRequest:payRequest];
    view.delegate = self;
    [self presentViewController:view animated:YES completion:nil];
    
}

// 绑卡
- (void)jump{
    PKPassLibrary *library = [[PKPassLibrary alloc] init];
    [library openPaymentSetup];
}


//-(void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
//                 didSelectShippingContact:(PKContact *)contact
//                               completion:(void (^)(PKPaymentAuthorizationStatus, NSArray<PKShippingMethod *> * _Nonnull, NSArray<PKPaymentSummaryItem *> * _Nonnull))completion{
//    //contact送货地址信息，PKContact类型
//    //送货信息选择回调，如果需要根据送货地址调整送货方式，比如普通地区包邮+极速配送，偏远地区只有付费普通配送，进行支付金额重新计算，可以实现该代理，返回给系统：shippingMethods配送方式，summaryItems账单列表，如果不支持该送货信息返回想要的PKPaymentAuthorizationStatus
//    completion(PKPaymentAuthorizationStatusSuccess, shippingMethods, _summaryItems);
//}

-(void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                  didSelectShippingMethod:(PKShippingMethod *)shippingMethod
                               completion:(void (^)(PKPaymentAuthorizationStatus, NSArray<PKPaymentSummaryItem *> * _Nonnull))completion{
    //配送方式回调，如果需要根据不同的送货方式进行支付金额的调整，比如包邮和付费加速配送，可以实现该代理
    PKShippingMethod *oldShippingMethod = [_summaryItems objectAtIndex:2];
    PKPaymentSummaryItem *total = [_summaryItems lastObject];
    total.amount = [total.amount decimalNumberBySubtracting:oldShippingMethod.amount];
    total.amount = [total.amount decimalNumberByAdding:shippingMethod.amount];
    
    [_summaryItems replaceObjectAtIndex:2 withObject:shippingMethod];
    [_summaryItems replaceObjectAtIndex:3 withObject:total];
    
    completion(PKPaymentAuthorizationStatusSuccess, _summaryItems);
}


-(void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller didSelectPaymentMethod:(PKPaymentMethod *)paymentMethod completion:(void (^)(NSArray<PKPaymentSummaryItem *> * _Nonnull))completion{
    //支付银行卡回调，如果需要根据不同的银行调整付费金额，可以实现该代理
    completion(_summaryItems);
}

-(void)paymentAuthorizationViewController:(PKPaymentAuthorizationViewController *)controller
                      didAuthorizePayment:(PKPayment *)payment
                               completion:(void (^)(PKPaymentAuthorizationStatus status))completion {
    PKPaymentToken *payToken = payment.token;
    //支付凭据，发给服务端进行验证支付是否真实有效
    PKContact *billingContact = payment.billingContact;     //账单信息
    PKContact *shippingContact = payment.shippingContact;   //送货信息
    PKContact *shippingMethod = payment.shippingMethod;     //送货方式
    NSString *paymentDataStr = [[NSString alloc] initWithData:payToken.paymentData encoding:NSUTF8StringEncoding];
    //等待服务器返回结果后再进行系统block调用
    NSString *hexStr = [self hexStringFromData:payToken.paymentData];
    
    // header
    NSDictionary *retDic = [NSJSONSerialization JSONObjectWithData:payToken.paymentData options:NSJSONReadingMutableLeaves error:nil];
    
    NSDictionary *header = retDic[@"header"];
    
    // wrappedKey
    NSString *wrappedKeyStr = [header objectForKey:@"wrappedKey"];
    NSData *wrappedKeyData =  [GTMBase64 decodeString:wrappedKeyStr];
    wrappedKeyStr = [[NSString alloc] initWithData:wrappedKeyData encoding:NSUTF8StringEncoding];
    
    // publicKeyHash
    NSString *publicKeyHashStr = [header objectForKey:@"publicKeyHash"];
    NSData *publicKeyHashData =  [GTMBase64 decodeString:publicKeyHashStr];
    publicKeyHashStr = [[NSString alloc] initWithData:publicKeyHashData encoding:NSUTF8StringEncoding];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        //模拟服务器通信
        completion(PKPaymentAuthorizationStatusSuccess);
    });
}

-(void)paymentAuthorizationViewControllerDidFinish:(PKPaymentAuthorizationViewController *)controller{
    [controller dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -
#pragma mark - NSData转十六进制
- (NSString *)hexStringFromData:(NSData *)data {
    Byte *byte = (Byte *)[data bytes];
    NSString *hexStr = @"";
    for (int i=0; i<data.length; i++) {
        NSString *newHexString = [NSString stringWithFormat:@"%x",byte[i] & 0xff];
        if (newHexString.length == 1) {
            hexStr = [NSString stringWithFormat:@"%@0%@",hexStr,newHexString];
        } else{
            hexStr = [NSString stringWithFormat:@"%@%@",hexStr,newHexString];
        }
    }
    return [hexStr uppercaseString];
}

@end
