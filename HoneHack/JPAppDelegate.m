//
//  JPAppDelegate.m
//  HoneHack
//
//  Created by Jamie Pinkham on 3/30/13.
//  Copyright (c) 2013 Jamie Pinkham. All rights reserved.
//

#import "JPAppDelegate.h"
#import <IOBluetooth/IOBluetooth.h>

#define HONE_SERVICE_UUID					@"8DBC5C8B-5165-4B43-8DA7-DF39C5FF8FE3"
#define HONE_BONDING_CONNECTION_STATUS_UDID	@"577FE739-2AE6-46A7-8493-C0B5198E25F9"
#define HONE_BONDING_COUNT_UDID				@"C3601366-B701-4F70-9BA5-B05F5103A2FB"
#define HONE_DEVICE_RESET_UUID				@"DAB15407-51E9-465D-AA06-DBBFFD0D50DD"
#define HONE_DEVICE_DISCONNECT_UUID			@"EE5A026A-BF3A-4BA4-B070-D315F7D3ABC2"
#define HONE_BONDING_DOORBELL_UDID			@"C5AF9583-2553-4802-9B5C-4347BB025F39"

#define IMMEDIATE_ALERT_SERVICE				@"1802"

typedef NS_ENUM(uint8_t, AlertLevel)
{
	AlertLevelNone = 0x0,
	AlertLevelMild = 0x1,
	AlertLevelHigh = 0x2,
};

@interface JPAppDelegate () <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBPeripheral *connectedPeripheral;
@property (nonatomic, strong) CBCharacteristic *findCharacteristic;
@property (nonatomic, strong) CBCharacteristic *resetCharacteristic;
@property (nonatomic, assign) BOOL finding;

@property (nonatomic, weak) IBOutlet NSArrayController *arrayController;

@property (nonatomic, weak) IBOutlet NSButton* connectButton;
@property (nonatomic, weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (nonatomic, weak) IBOutlet NSWindow *scanSheet;

@property (nonatomic, weak) IBOutlet NSButton *findButton;
@property (nonatomic, weak) IBOutlet NSButton *resetButon;


- (IBAction) closeScanSheet:(id)sender;
- (IBAction) cancelScanSheet:(id)sender;
- (IBAction) connectButtonPressed:(id)sender;
- (IBAction) findButtonPressed:(id)sender;
- (IBAction) resetButtonPressed:(id)sender;
@end

@implementation JPAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()];
	self.foundPeripherals = [NSMutableArray new];
}


- (void) stopScan
{
    [self.centralManager stopScan];
}

- (void) startScan
{
    [self.centralManager scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey : @NO}];
	NSLog(@"scanning started");
}

- (BOOL) isLECapableHardware
{
    NSString * state = nil;
    
    switch ([self.centralManager state])
    {
        case CBCentralManagerStateUnsupported:
            state = @"The platform/hardware doesn't support Bluetooth Low Energy.";
            break;
        case CBCentralManagerStateUnauthorized:
            state = @"The app is not authorized to use Bluetooth Low Energy.";
            break;
        case CBCentralManagerStatePoweredOff:
            state = @"Bluetooth is currently powered off.";
            break;
        case CBCentralManagerStatePoweredOn:
            return YES;
        case CBCentralManagerStateUnknown:
        default:
            return NO;
            
    }
    
    NSLog(@"Central manager state: %@", state);
	
	[self cancelScanSheet:nil];
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:state];
    [alert addButtonWithTitle:@"OK"];
    [alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
    return FALSE;
}

#pragma mark - Scan sheet methods

/*
 Open scan sheet to discover motion peripherals if it is LE capable hardware
 */
- (void)openScanSheet
{
    if( [self isLECapableHardware] )
    {
        [self.arrayController removeObjects:self.foundPeripherals];
        [NSApp beginSheet:self.scanSheet modalForWindow:self.window modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
        [self startScan];
    }
}

/*
 Close scan sheet once device is selected
 */
- (IBAction)closeScanSheet:(id)sender
{
    [NSApp endSheet:self.scanSheet returnCode:NSAlertDefaultReturn];
    [self.scanSheet orderOut:self];
}

/*
 Close scan sheet without choosing any device
 */
- (IBAction)cancelScanSheet:(id)sender
{
    [NSApp endSheet:self.scanSheet returnCode:NSAlertAlternateReturn];
    [self.scanSheet orderOut:self];
}

- (IBAction)findButtonPressed:(id)sender
{
	if(self.connectedPeripheral != nil && self.findCharacteristic != nil)
	{
		uint8_t bytes[1];
		if(self.finding)
		{
			bytes[0] = AlertLevelNone;
 		}
		else
		{
			bytes[0] = AlertLevelHigh;
		}
		NSMutableData *data = [NSMutableData dataWithBytes:&bytes length:sizeof(uint8_t)];
		[self.connectedPeripheral writeValue:data forCharacteristic:self.findCharacteristic type:CBCharacteristicWriteWithoutResponse];
		self.finding = !self.finding;
		[self.findButton setTitle:(self.finding ? @"Stop" : @"Find")];
		[self.findButton sizeToFit];
	}
}

- (IBAction)resetButtonPressed:(id)sender
{
	if(self.connectedPeripheral != nil && self.resetCharacteristic != nil)
	{
		uint8_t bytes[1];
		bytes[0] = 0x01;
		NSMutableData *data = [NSMutableData dataWithBytes:&bytes length:sizeof(uint8_t)];
		[self.connectedPeripheral writeValue:data forCharacteristic:self.resetCharacteristic type:CBCharacteristicWriteWithoutResponse];
	}
}

/*
 This method is called when Scan sheet is closed. Initiate connection to selected motion peripheral
 */
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [self stopScan];
    if( returnCode == NSAlertDefaultReturn )
    {
        NSIndexSet *indexes = [self.arrayController selectionIndexes];
        if ([indexes count] != 0)
        {
            NSUInteger anIndex = [indexes firstIndex];
            self.connectedPeripheral = [[self foundPeripherals] objectAtIndex:anIndex];
            [self.progressIndicator setHidden:FALSE];
            [self.progressIndicator startAnimation:self];
            [self.connectButton setTitle:@"Cancel"];
			[self.connectButton sizeToFit];
            [self.centralManager connectPeripheral:self.connectedPeripheral options:@{CBConnectPeripheralOptionNotifyOnDisconnectionKey : @YES}];
        }
    }
}

#pragma mark - Connect Button

/*
 This method is called when connect button pressed and it takes appropriate actions depending on device connection state
 */
- (IBAction)connectButtonPressed:(id)sender
{
    if(self.connectedPeripheral && ([self.connectedPeripheral isConnected]))
    {
        /* Disconnect if it's already connected */
        [self.centralManager cancelPeripheralConnection:self.connectedPeripheral];
    }
    else if (self.connectedPeripheral)
    {
        /* Device is not connected, cancel pendig connection */
        [self.progressIndicator setHidden:YES];
        [self.progressIndicator stopAnimation:self];
        [self.connectButton setTitle:@"Connect"];
		[self.connectButton sizeToFit];
        [self.centralManager cancelPeripheralConnection:self.connectedPeripheral];
        [self openScanSheet];
    }
    else
    {   /* No outstanding connection, open scan sheet */
        [self openScanSheet];
    }
}


- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
	[self isLECapableHardware];
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
	
    NSLog(@"Discovered %@ at %@", peripheral.name, RSSI);
    NSMutableArray *peripherals = [self mutableArrayValueForKey:@"foundPeripherals"];
    if( ![self.foundPeripherals containsObject:peripheral] )
	{
        [peripherals addObject:peripheral];
	}
}

- (void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)aPeripheral
{
	[aPeripheral setDelegate:self];
    [aPeripheral discoverServices:nil];
	
	//	self.connected = @"Connected";
    [self.connectButton setTitle:@"Disconnect"];
	[self.connectButton sizeToFit];
    [self.progressIndicator setHidden:YES];
    [self.progressIndicator stopAnimation:self];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)aPeripheral error:(NSError *)error
{
	NSLog(@"Did Disconnect to peripheral: %@ with error = %@", aPeripheral, [error localizedDescription]);
	//	self.connected = @"Not connected";
    [self.connectButton setTitle:@"Connect"];
	[self.connectButton sizeToFit];
    if( self.connectedPeripheral )
    {
        [self.connectedPeripheral setDelegate:nil];
        self.connectedPeripheral = nil;
    }
	self.resetCharacteristic = nil;
	self.findCharacteristic = nil;
	[self.findButton setEnabled:NO];
	[self.resetButon setEnabled:NO];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)aPeripheral error:(NSError *)error
{
	NSLog(@"Fail to connect to peripheral: %@ with error = %@", aPeripheral, [error localizedDescription]);
    [self.connectButton setTitle:@"Connect"];
	[self.connectButton sizeToFit];
    if( self.connectedPeripheral)
    {
        [self.connectedPeripheral setDelegate:nil];
        self.connectedPeripheral = nil;
    }
	self.resetCharacteristic = nil;
	self.findCharacteristic = nil;
	[self.findButton setEnabled:NO];
	[self.resetButon setEnabled:NO];
}

- (void) peripheral:(CBPeripheral *)aPeripheral didDiscoverServices:(NSError *)error
{
	for (CBService *aService in aPeripheral.services)
    {
        NSLog(@"Service found with UUID: %@", aService.UUID);
        
        if ([aService.UUID isEqual:[CBUUID UUIDWithString:HONE_SERVICE_UUID]])
        {
            [aPeripheral discoverCharacteristics:nil forService:aService];
        }
        
        /* GAP (Generic Access Profile) for Device Name */
        if ( [aService.UUID isEqual:[CBUUID UUIDWithString:CBUUIDGenericAccessProfileString]] )
        {
            [aPeripheral discoverCharacteristics:nil forService:aService];
        }
		
		if([aService.UUID isEqual:[CBUUID UUIDWithString:IMMEDIATE_ALERT_SERVICE]])
		{
			[aPeripheral discoverCharacteristics:nil forService:aService];
		}
    }
}

- (void) peripheral:(CBPeripheral *)aPeripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
	if ([service.UUID isEqual:[CBUUID UUIDWithString:HONE_SERVICE_UUID]])
    {
        for (CBCharacteristic *aChar in service.characteristics)
        {
			NSLog(@"characteristic UUID = %@ found for service UUID = %@", aChar.UUID, service.UUID);
			if([aChar.UUID isEqual:[CBUUID UUIDWithString:HONE_DEVICE_RESET_UUID]])
			{
				self.resetButon.enabled = YES;
				self.resetCharacteristic = aChar;
			}
        }
    }
    
    if ( [service.UUID isEqual:[CBUUID UUIDWithString:CBUUIDGenericAccessProfileString]] )
    {
        for (CBCharacteristic *aChar in service.characteristics)
        {
            /* Read device name */
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:CBUUIDDeviceNameString]])
            {
                [aPeripheral readValueForCharacteristic:aChar];
                NSLog(@"Found a Device Name Characteristic");
            }
			else
			{
				NSLog(@"characteristic UUID = %@ found for service UUID = %@", aChar.UUID, service.UUID);
			}
        }
    }
	
	if([service.UUID isEqual:[CBUUID UUIDWithString:IMMEDIATE_ALERT_SERVICE]])
	{
		for(CBCharacteristic *aChar in service.characteristics)
		{
			if([aChar.UUID isEqual:[CBUUID UUIDWithString:@"2A06"]])
			{
				self.findCharacteristic = aChar;
				self.findButton.enabled = YES;
			}
		}
	}
}

- (void) peripheral:(CBPeripheral *)aPeripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
	
	if([characteristic.UUID isEqual:[CBUUID UUIDWithString:CBUUIDDeviceNameString]])
	{
		NSLog(@"name value = %@", [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding]);
	}
	
}




@end
