

#import "ABC.h"
#import "Wallet.h"
#import "Transaction.h"
#import "ABC.h"
#import "User.h"
#import "Util.h"

#import "CoreBridge.h"

@interface CoreBridge ()
{
}

@property (nonatomic, strong) NSMutableArray *arrayWallets;
@property (nonatomic, strong) NSMutableArray *arrayArchivedWallets;

+ (void)loadTransactions:(Wallet *) wallet;
+ (void)setTransaction:(Wallet *) wallet transaction:(Transaction *) transaction coreTx:(tABC_TxInfo *) pTrans;
+ (NSDate *)dateFromTimestamp:(int64_t) intDate;

@end

@implementation CoreBridge

+ (void)loadWallets:(NSMutableArray *)arrayWallets
{
    tABC_Error Error;
    tABC_WalletInfo **aWalletInfo = NULL;
    unsigned int nCount;

    tABC_CC result = ABC_GetWallets([[User Singleton].name UTF8String],
                                    [[User Singleton].password UTF8String],
                                    &aWalletInfo, &nCount, &Error);
    if (ABC_CC_Ok == result)
    {
        unsigned int i;
        for (i = 0; i < nCount; ++i)
        {
            Wallet *wallet;
            tABC_WalletInfo *pWalletInfo = aWalletInfo[i];

            wallet = [[Wallet alloc] init];
            wallet.strUUID = [NSString stringWithUTF8String: pWalletInfo->szUUID];
            wallet.strName = [NSString stringWithUTF8String: pWalletInfo->szName];
            wallet.attributes = pWalletInfo->attributes;
            wallet.balance = pWalletInfo->balanceSatoshi;
            wallet.currencyNum = pWalletInfo->currencyNum;
            [arrayWallets addObject:wallet];
            [self loadTransactions: wallet];
        }
    }
    else
    {
        NSLog(@("Error: CoreBridge.loadWallets:  %s\n"), Error.szDescription);
        [Util printABC_Error:&Error];
    }
    ABC_FreeWalletInfoArray(aWalletInfo, nCount);
}

+ (void)loadWallets:(NSMutableArray *)arrayWallets archived:(NSMutableArray *) arrayArchivedWallets
{
    [CoreBridge loadWallets:arrayWallets];

    // go through all the wallets and seperate out the archived ones
    for (int i = (int) [arrayWallets count] - 1; i >= 0; i--)
    {
        Wallet *wallet = [arrayWallets objectAtIndex:i];

        // if this is an archived wallet
        if ((wallet.attributes & WALLET_ATTRIBUTE_ARCHIVE_BIT) == 1)
        {
            // add it to the archive wallet
            if (arrayArchivedWallets != nil)
            {
                [arrayArchivedWallets insertObject:wallet atIndex:0];
            }

            // remove it from the standard wallets
            [arrayWallets removeObjectAtIndex:i];
        }
    }
}

+ (void)reloadWallet: (Wallet *) wallet;
{
    tABC_Error Error;
    tABC_WalletInfo *pWalletInfo = NULL;
    tABC_CC result = ABC_GetWalletInfo([[User Singleton].name UTF8String],
                                       [[User Singleton].password UTF8String],
                                       [wallet.strUUID UTF8String],
                                       &pWalletInfo, &Error);
    if (ABC_CC_Ok == result)
    {
        wallet.strName = [NSString stringWithUTF8String: pWalletInfo->szName];
        wallet.strUUID = [NSString stringWithUTF8String: pWalletInfo->szUUID];
        wallet.attributes = 0;
        wallet.balance = pWalletInfo->balanceSatoshi;
        wallet.currencyNum = pWalletInfo->currencyNum;
        [self loadTransactions: wallet];
    }
    else
    {
        NSLog(@("Error: CoreBridge.reloadWallets:  %s\n"), Error.szDescription);
        [Util printABC_Error:&Error];
    }
    ABC_FreeWalletInfo(pWalletInfo);
}

+ (void) loadTransactions: (Wallet *) wallet
{
    tABC_Error Error;
    unsigned int tCount = 0;
    Transaction *transaction;
    tABC_TxInfo **aTransactions = NULL;
    tABC_CC result = ABC_GetTransactions([[User Singleton].name UTF8String],
                                         [[User Singleton].password UTF8String],
                                         [wallet.strUUID UTF8String], &aTransactions,
                                         &tCount, &Error);
    if (ABC_CC_Ok == result)
    {
        NSMutableArray *arrayTransactions = [[NSMutableArray alloc] init];

        for (int j = tCount - 1; j >= 0; --j)
        {
            tABC_TxInfo *pTrans = aTransactions[j];
            transaction = [[Transaction alloc] init];
            [CoreBridge setTransaction:wallet transaction:transaction coreTx:pTrans];
            [arrayTransactions addObject:transaction];
        }
        SInt64 bal = 0;
        for (int j = (int) arrayTransactions.count - 1; j >= 0; --j)
        {
            Transaction *t = arrayTransactions[j];
            bal += t.amountSatoshi;
            t.balance = bal;
        }
        wallet.arrayTransactions = arrayTransactions;
    }
    else
    {
        NSLog(@("Error: CoreBridge.loadTransactions:  %s\n"), Error.szDescription);
        [Util printABC_Error:&Error];
    }
    ABC_FreeTransactions(aTransactions, tCount);
}

+ (void)setTransaction:(Wallet *) wallet transaction:(Transaction *) transaction coreTx:(tABC_TxInfo *) pTrans
{
    transaction.strID = [NSString stringWithUTF8String: pTrans->szID];
    transaction.strName = [NSString stringWithUTF8String: pTrans->pDetails->szName];
    transaction.strNotes = [NSString stringWithUTF8String: pTrans->pDetails->szNotes];
    transaction.strCategory = [NSString stringWithUTF8String: pTrans->pDetails->szCategory];
    transaction.date = [self dateFromTimestamp: pTrans->timeCreation];
    transaction.amountSatoshi = pTrans->pDetails->amountSatoshi;
    transaction.amountFiat = pTrans->pDetails->amountFeesAirbitzSatoshi;
    transaction.minerFees = pTrans->pDetails->amountFeesMinersSatoshi;
    transaction.strWalletName = wallet.strName;
    transaction.strWalletUUID = wallet.strUUID;
#warning TODO: Hardcoded confirmations...Need to add the info to our structs or cut-it-out
    transaction.confirmations = 3;
    transaction.bConfirmed = NO;
    if (transaction.strName) {
        transaction.strAddress = transaction.strName;
    } else {
        transaction.strAddress = @"1zf76dh4TG";
    }
    NSMutableArray *addresses = [[NSMutableArray alloc] init];
    for (int i = 0; i < pTrans->countAddresses; ++i)
    {
        [addresses addObject:[NSString stringWithUTF8String: pTrans->aAddresses[i]]];
    }
    transaction.addresses = addresses;
}

+ (NSMutableArray *)searchTransactionsIn: (Wallet *) wallet query:(NSString *)term addTo:(NSMutableArray *) arrayTransactions 
{
    tABC_Error Error;
    unsigned int tCount = 0;
    Transaction *transaction;
    tABC_TxInfo **aTransactions = NULL;
    tABC_CC result = ABC_SearchTransactions([[User Singleton].name UTF8String],
                                            [[User Singleton].password UTF8String],
                                            [wallet.strUUID UTF8String], [term UTF8String],
                                            &aTransactions, &tCount, &Error);
    if (ABC_CC_Ok == result)
    {
        for (int j = tCount - 1; j >= 0; --j) {
            tABC_TxInfo *pTrans = aTransactions[j];
            transaction = [[Transaction alloc] init];
            [CoreBridge setTransaction:wallet transaction:transaction coreTx:pTrans];
            [arrayTransactions addObject:transaction];
        }
    }
    else 
    {
        NSLog(@("Error: CoreBridge.searchTransactionsIn:  %s\n"), Error.szDescription);
        [Util printABC_Error:&Error];
    }
    ABC_FreeTransactions(aTransactions, tCount);
    return arrayTransactions;
}

+ (void)setWalletOrder: (NSMutableArray *) arrayWallets archived:(NSMutableArray *) arrayArchivedWallets
{
    tABC_Error Error;
    int i = 0;
    unsigned int walletCount = (unsigned int) [arrayWallets count] + (unsigned int)[arrayArchivedWallets count];
    const char **paUUIDS = malloc(sizeof(char *) * walletCount);
    for (Wallet *w in arrayWallets)
    {
        paUUIDS[i] = [w.strUUID UTF8String];
        i++;
    }
    for (Wallet *w in arrayArchivedWallets)
    {
        paUUIDS[i] = [w.strUUID UTF8String];
        i++;
    }
    if (ABC_SetWalletOrder([[User Singleton].name UTF8String],
                           [[User Singleton].password UTF8String],
                           (char **)paUUIDS,
                           walletCount,
                           &Error) != ABC_CC_Ok)
    {
        NSLog(@("Error: CoreBridge.setWalletOrder:  %s\n"), Error.szDescription);
        [Util printABC_Error:&Error];
    }
    free(paUUIDS);
}

+ (bool)setWalletAttributes: (Wallet *) wallet
{
    tABC_Error Error;
    tABC_CC result = ABC_SetWalletAttributes([[User Singleton].name UTF8String],
                                             [[User Singleton].password UTF8String],
                                             [wallet.strUUID UTF8String],
                                             wallet.attributes, &Error);
    if (ABC_CC_Ok == result)
    {
        return true;
    }
    else
    {
        NSLog(@("Error: CoreBridge.setWalletAttributes:  %s\n"), Error.szDescription);
        [Util printABC_Error:&Error];
        return false;
    }
}

+ (bool)storeTransaction: (Transaction *) transaction
{
    tABC_Error Error;
    tABC_TxDetails *pDetails;
    tABC_CC result = ABC_GetTransactionDetails([[User Singleton].name UTF8String],
                                               [[User Singleton].password UTF8String],
                                               [transaction.strWalletUUID UTF8String],
                                               [transaction.strID UTF8String],
                                               &pDetails, &Error);
    if (ABC_CC_Ok != result)
    {
        NSLog(@("Error: CoreBridge.storeTransaction:  %s\n"), Error.szDescription);
        [Util printABC_Error:&Error];
        return false;
    }

    pDetails->szName = (char *) [transaction.strName UTF8String];
    pDetails->szCategory = (char *) [transaction.strCategory UTF8String];
    pDetails->szNotes = (char *) [transaction.strNotes UTF8String];
    pDetails->amountCurrency = transaction.amountFiat;

    result = ABC_SetTransactionDetails([[User Singleton].name UTF8String],
                                       [[User Singleton].password UTF8String],
                                       [transaction.strWalletUUID UTF8String],
                                       [transaction.strID UTF8String],
                                       pDetails, &Error);
    
    if (ABC_CC_Ok != result)
    {
        NSLog(@("Error: CoreBridge.storeTransaction:  %s\n"), Error.szDescription);
        [Util printABC_Error:&Error];
        return false;
    }

    return true;
}

+ (NSDate *)dateFromTimestamp:(int64_t) intDate
{
    return [NSDate dateWithTimeIntervalSince1970: intDate];
}

+ (NSString *)formatCurrency: (double) currency
{
    return [CoreBridge formatCurrency:currency withSymbol:true];
}

+ (NSString *)formatCurrency: (double) currency withSymbol:(bool) symbol
{
    NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
    [f setNumberStyle: NSNumberFormatterCurrencyStyle];
    if (symbol)
        [f setCurrencySymbol:@"$ "];
    else
        [f setCurrencySymbol:@""];
    return [f stringFromNumber:[NSNumber numberWithFloat:currency]];
}

+ (NSString *)formatSatoshi: (int64_t) amount
{
    return [CoreBridge formatSatoshi:amount withSymbol:true];
}

+ (int) denominationDecimals
{
    int decimalPlaces = 8;
    if ([[[User Singleton] denominationLabel] isEqualToString:@"µBTC"])
        decimalPlaces = 2;
    else if ([[[User Singleton] denominationLabel] isEqualToString:@"mBTC"])
        decimalPlaces = 5;
    return decimalPlaces;
}

+ (NSString *)formatSatoshi: (int64_t) amount withSymbol:(bool) symbol
{
    tABC_Error error;
    char *pFormatted = NULL;
    int decimalPlaces = [self denominationDecimals];
    bool negative = amount < 0;
    amount = llabs(amount);
    if (ABC_FormatAmount(amount, &pFormatted, decimalPlaces, &error) != ABC_CC_Ok)
    {
        return nil;
    }
    else
    {
        NSMutableString *formatted = [[NSMutableString alloc] init];
        if (negative)
            [formatted appendString: @"("];
        if (symbol)
        {
            [formatted appendString: [User Singleton].denominationLabelShort];
            [formatted appendString: @" "];
        }
        const char *p = pFormatted;
        const char *decimal = strstr(pFormatted, ".");
        int offset = (decimal - pFormatted) % 3;
        for (int i = 0; i < strlen(pFormatted); ++i, ++p)
        {
            if (p != pFormatted 
                    && p < decimal 
                    && (i - offset) % 3 == 0)
                [formatted appendString:@","];
            [formatted appendFormat: @"%c", *p];
        }
        if (negative)
            [formatted appendString: @")"];
        NSLog(@("%ld - %s - %@\n"), amount, pFormatted, formatted);
        free(pFormatted);
        return formatted;
    }
}

+ (int64_t) denominationToSatoshi: (NSString *) amount
{
    int64_t parsedAmount;
    int decimalPlaces = [self denominationDecimals];
    if (ABC_ParseAmount([amount UTF8String], &parsedAmount, decimalPlaces) != ABC_CC_Ok)
    {
#warning TODO handle error
    }
    return parsedAmount;
}

+ (NSString *)conversionString: (int) currencyNumber
{
    double currency;
    tABC_Error error;

    double denomination = [User Singleton].denomination;
    NSString *denominationLabel = [User Singleton].denominationLabel;
    NSString *currencyLabel = @"USD";
    tABC_CC result = ABC_SatoshiToCurrency(denomination, &currency, currencyNumber, &error);
    [Util printABC_Error:&error];
    if (result == ABC_CC_Ok)
        return [NSString stringWithFormat:@"1.00 %@ = $%.2f %@", denominationLabel, currency, currencyLabel];
    else
        return @"";
}

@end
