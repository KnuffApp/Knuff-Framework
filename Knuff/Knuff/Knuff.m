//
//  Knuff.m
//  Knuff
//
//  Created by Simon Blommegård on 2012-10-31.
//  Copyright (c) 2012 Simon Blommegård. All rights reserved.
//

#import <objc/runtime.h>
#import <MultipeerConnectivity/MultipeerConnectivity.h>

void sb_swizzle(Class class, SEL orig, SEL new) {
  Method origMethod = class_getInstanceMethod(class, orig);
  Method newMethod = class_getInstanceMethod(class, new);
  if(class_addMethod(class, orig, method_getImplementation(newMethod), method_getTypeEncoding(newMethod)))
    class_replaceMethod(class, new, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
  else
    method_exchangeImplementations(origMethod, newMethod);
}

@interface MBBKnuff : NSObject
@end

@interface MBBKnuff () <MCNearbyServiceAdvertiserDelegate>
@property (nonatomic, strong) MCNearbyServiceAdvertiser *advertiser;
@property (nonatomic, strong) NSString *token;
@property (nonatomic, strong) dispatch_queue_t queue;
@end

@implementation MBBKnuff

+ (void)load {
  [[NSNotificationCenter defaultCenter] addObserver:[MBBKnuff _knuff]
                                           selector:@selector(_applicationDidFinishLaunchingNotification:)
                                               name:UIApplicationDidFinishLaunchingNotification
                                             object:nil];
}

+ (MBBKnuff *)_knuff {
  static dispatch_once_t onceToken;
  static MBBKnuff *knuff;
  
  dispatch_once(&onceToken, ^{
    knuff = [MBBKnuff new];
  });
  
  return knuff;
}

- (void)_republish {
  if (self.advertiser) {
    [self.advertiser stopAdvertisingPeer];
    self.advertiser = nil;
  }
  
  if (self.token) {
    MCPeerID *peerID = [[MCPeerID alloc] initWithDisplayName:[UIDevice currentDevice].name];
    NSDictionary *discoveryInfo = @{@"token": self.token};
    self.advertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:peerID
                                                        discoveryInfo:discoveryInfo
                                                          serviceType:@"knuff"];
    self.advertiser.delegate = self;
    [self.advertiser startAdvertisingPeer];
  }
}

- (void)_applicationDidFinishLaunchingNotification:(NSNotification *)notification {
  id<UIApplicationDelegate> appDelegate = [[UIApplication sharedApplication] delegate];
  
  // application:didRegisterForRemoteNotificationsWithDeviceToken:
  SEL newSEL = NSSelectorFromString(@"sb_application:didRegisterForRemoteNotificationsWithDeviceToken:");
  IMP newIMP = imp_implementationWithBlock(^(id _self, UIApplication *application, NSData *deviceToken) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [_self performSelector:newSEL withObject:application withObject:deviceToken];
#pragma clang diagnostic pop
    
    dispatch_async([MBBKnuff _knuff].queue, ^{
      const unsigned *tokenBytes = [deviceToken bytes];
      NSString *hexToken = [NSString stringWithFormat:@"%08x%08x%08x%08x%08x%08x%08x%08x", ntohl(tokenBytes[0]), ntohl(tokenBytes[1]), ntohl(tokenBytes[2]), ntohl(tokenBytes[3]), ntohl(tokenBytes[4]), ntohl(tokenBytes[5]), ntohl(tokenBytes[6]), ntohl(tokenBytes[7])];
      
      [[MBBKnuff _knuff] setToken:hexToken];
      [[MBBKnuff _knuff] _republish];
    });
  });
  
  SEL origSEL = @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:);
  Method origMethod = class_getInstanceMethod([appDelegate class], origSEL);
  
  class_addMethod([appDelegate class], newSEL, newIMP, method_getTypeEncoding(origMethod));
  sb_swizzle([appDelegate class], origSEL, newSEL);
  
  [[NSNotificationCenter defaultCenter] addObserver:[MBBKnuff _knuff]
                                           selector:@selector(_applicationDidBecomeActiveNotification:)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];
}

- (void)_applicationDidBecomeActiveNotification:(NSNotification *)notification {
  dispatch_async([MBBKnuff _knuff].queue, ^{
    if ([MBBKnuff _knuff].token)
      [[MBBKnuff _knuff] _republish];
  });
}

#pragma mark - Properties

- (dispatch_queue_t)queue {
  if (!_queue) {
    _queue = dispatch_queue_create("com.madebybowtie.SBAPNSPusherQueue", NULL);
    dispatch_set_target_queue(_queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
  }
  return _queue;
}

#pragma mark - MCNearbyServiceAdvertiserDelegate

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void(^)(BOOL accept, MCSession *session))invitationHandler {
  // Do not connect
  invitationHandler(NO, nil);
}

@end