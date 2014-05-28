//
//  ExportWalletOptionsOptionsViewController.h
//  AirBitz
//
//  Created by Adam Harris on 5/26/14.
//  Copyright (c) 2014 AirBitz. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Wallet.h"

typedef enum eWalletExportType
{
    WalletExportType_CSV = 0,
    WalletExportType_Quicken,
    WalletExportType_Quickbooks,
    WalletExportType_PDF,
    WalletExportType_PrivateSeed
} tWalletExportType;

@protocol ExportWalletOptionsViewControllerDelegate;

@interface ExportWalletOptionsViewController : UIViewController

@property (assign)            id<ExportWalletOptionsViewControllerDelegate> delegate;
@property (assign)            tWalletExportType                             type;
@property (nonatomic, strong) Wallet                                        *wallet;

@end

@protocol ExportWalletOptionsViewControllerDelegate <NSObject>

@required

- (void)exportWalletOptionsViewControllerDidFinish:(ExportWalletOptionsViewController *)controller;

@end