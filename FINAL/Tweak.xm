/*
 * Tweak.xm — CameraInject (rootless, iOS 15.x)
 * Hooks AVFoundation to inject a static image into all camera feeds.
 * Config path: /var/mobile/Library/CameraInject/config.plist
 * Image path:  /var/mobile/Library/CameraInject/inject.png
 */

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <os/lock.h>
#import <CoreFoundation/CoreFoundation.h>
#import "SampleBufferFactory.h"

static NSString *const kConfigPath     = @"/var/mobile/Library/CameraInject/config.plist";
static NSString *const kDefaultImgPath = @"/var/mobile/Library/CameraInject/inject.png";

static UIImage       *gInjectImage = nil;
static BOOL           gEnabled     = YES;
static NSString      *gImagePath   = nil;
static os_unfair_lock gImageLock   = OS_UNFAIR_LOCK_INIT;

// ── Config loading ─────────────────────────────────────────────────────────

static void CILoadConfig(CFNotificationCenterRef c, void *o, CFStringRef n,
                         const void *obj, CFDictionaryRef u) {
    NSDictionary *cfg = [NSDictionary dictionaryWithContentsOfFile:kConfigPath];
    os_unfair_lock_lock(&gImageLock);
    gEnabled     = cfg[@"enabled"]   ? [cfg[@"enabled"] boolValue] : YES;
    gImagePath   = cfg[@"imagePath"] ?: kDefaultImgPath;
    gInjectImage = gEnabled ? [UIImage imageWithContentsOfFile:gImagePath] : nil;
    if (gEnabled && !gInjectImage) {
        // Fallback placeholder
        CGSize sz = CGSizeMake(640, 480);
        UIGraphicsBeginImageContextWithOptions(sz, YES, 1.0);
        [[UIColor colorWithRed:0.1 green:0.6 blue:0.9 alpha:1.0] setFill];
        UIRectFill(CGRectMake(0, 0, sz.width, sz.height));
        NSDictionary *attrs = @{
            NSFontAttributeName: [UIFont boldSystemFontOfSize:36],
            NSForegroundColorAttributeName: UIColor.whiteColor
        };
        [@"CamInject" drawAtPoint:CGPointMake(180, 210) withAttributes:attrs];
        gInjectImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    os_unfair_lock_unlock(&gImageLock);
}

static void CILoadConfigInitial(void) {
    CILoadConfig(NULL, NULL, NULL, NULL, NULL);
}

static UIImage *CIGetInjectImage(void) {
    os_unfair_lock_lock(&gImageLock);
    UIImage *img = gInjectImage;
    os_unfair_lock_unlock(&gImageLock);
    return img;
}

// ── Proxy delegate ─────────────────────────────────────────────────────────

@interface CIProxyDelegate : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, weak)   id<AVCaptureVideoDataOutputSampleBufferDelegate> realDelegate;
@property (nonatomic, strong) dispatch_queue_t realQueue;
@end

@implementation CIProxyDelegate

- (void)captureOutput:(AVCaptureOutput *)output
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    if (!gEnabled) {
        [self.realDelegate captureOutput:output didOutputSampleBuffer:sampleBuffer fromConnection:connection];
        return;
    }
    UIImage *img = CIGetInjectImage();
    if (!img) {
        [self.realDelegate captureOutput:output didOutputSampleBuffer:sampleBuffer fromConnection:connection];
        return;
    }
    CMSampleBufferRef fakeBuf = CICreateSampleBufferFromImage(img, sampleBuffer);
    if (fakeBuf) {
        [self.realDelegate captureOutput:output didOutputSampleBuffer:fakeBuf fromConnection:connection];
        CFRelease(fakeBuf);
    } else {
        [self.realDelegate captureOutput:output didOutputSampleBuffer:sampleBuffer fromConnection:connection];
    }
}

- (void)captureOutput:(AVCaptureOutput *)output
  didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    if ([self.realDelegate respondsToSelector:@selector(captureOutput:didDropSampleBuffer:fromConnection:)]) {
        [self.realDelegate captureOutput:output didDropSampleBuffer:sampleBuffer fromConnection:connection];
    }
}

- (BOOL)respondsToSelector:(SEL)sel {
    return [super respondsToSelector:sel] || [self.realDelegate respondsToSelector:sel];
}
- (id)forwardingTargetForSelector:(SEL)sel {
    return self.realDelegate;
}
@end

// ── Hooks ──────────────────────────────────────────────────────────────────

static const void *kProxyKey = &kProxyKey;

%hook AVCaptureVideoDataOutput

- (void)setSampleBufferDelegate:(id<AVCaptureVideoDataOutputSampleBufferDelegate>)delegate
                          queue:(dispatch_queue_t)queue {
    if (!delegate || !gEnabled) { %orig; return; }
    CIProxyDelegate *proxy = objc_getAssociatedObject(self, kProxyKey);
    if (!proxy || proxy.realDelegate != delegate) {
        proxy = [[CIProxyDelegate alloc] init];
        proxy.realDelegate = delegate;
        proxy.realQueue    = queue;
        objc_setAssociatedObject(self, kProxyKey, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    %orig(proxy, queue);
}

- (id)sampleBufferDelegate {
    CIProxyDelegate *proxy = objc_getAssociatedObject(self, kProxyKey);
    return proxy ? proxy.realDelegate : %orig;
}

%end

%hook AVCaptureSession
- (void)startRunning { CILoadConfigInitial(); %orig; }
- (void)stopRunning  { %orig; }
%end

// ── Constructor ────────────────────────────────────────────────────────────

%ctor {
    CILoadConfigInitial();
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        CILoadConfig,
        CFSTR("com.yourname.camerainject.reload"),
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately
    );
}
