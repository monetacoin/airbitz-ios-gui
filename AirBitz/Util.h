//
//  Util.h
//  AirBitz
//
//  Created by Adam Harris on 5/19/14.
//  Copyright (c) 2014 AirBitz. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AddressBookUI/AddressBookUI.h>
#import "ABC.h"

#define UIColorFromRGB(rgbValue) \
        [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 \
                        green:((float)((rgbValue & 0x00FF00) >>  8))/255.0 \
                         blue:((float)((rgbValue & 0x0000FF) >>  0))/255.0 \
                        alpha:1.0]

#define UIColorFromARGB(rgbValue) \
        [UIColor colorWithRed:((float)((rgbValue & 0x00FF0000) >> 16))/255.0 \
                        green:((float)((rgbValue & 0x0000FF00) >>  8))/255.0 \
                         blue:((float)((rgbValue & 0x000000FF) >>  0))/255.0 \
                        alpha:((float)((rgbValue & 0xFF000000) >> 24))/255.0]


@interface Util : NSObject

+ (NSString *)errorMap:(const tABC_Error *)pError;
+ (void)printABC_Error:(const tABC_Error *)pError;
+ (void)resizeView:(UIView *)theView withDisplayView:(UIView *)theDisplayView;
+ (void)freeStringArray:(char **)aszStrings count:(unsigned int)count;
+ (NSString *)getNameFromAddressRecord:(ABRecordRef)person;
+ (void)callTelephoneNumber:(NSString *)telNum;
+ (void)stylizeTextField:(UITextField *)textField;
+ (void)stylizeTextView:(UITextView *)textField;


+ (UIViewController *)animateIn:(NSString *)identifier parentController:(UIViewController *)parent;
+ (void)animateOut:(UIViewController *)controller parentController:(UIViewController *)parent complete:(void(^)(void))cb;

+ (UIImage *)dataToImage:(const unsigned char *)data withWidth:(int)width andHeight:(int)height;

@end
