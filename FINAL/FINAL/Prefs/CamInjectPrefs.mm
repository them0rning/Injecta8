/*
 * CamInjectPrefs.mm
 * Preference bundle — shows up in Settings automatically via PreferenceLoader
 * Writes to /var/mobile/Library/CameraInject/ (always writable by mobile user)
 */

#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>

static NSString *const kLibDir     = @"/var/mobile/Library/CameraInject";
static NSString *const kImagePath  = @"/var/mobile/Library/CameraInject/inject.png";
static NSString *const kConfigPath = @"/var/mobile/Library/CameraInject/config.plist";

#define RGB(r,g,b)    [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:1.0]
#define RGBA(r,g,b,a) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:(a)]

static UIButton *MakePill(NSString *title, UIColor *bg) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    b.backgroundColor = bg;
    b.layer.cornerRadius = 10;
    b.layer.masksToBounds = YES;
    b.translatesAutoresizingMaskIntoConstraints = NO;
    return b;
}

@interface CamInjectListController : PSListController
    <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, strong) UIScrollView *scroll;
@property (nonatomic, strong) UIView       *content;
@property (nonatomic, strong) UIImageView  *previewView;
@property (nonatomic, strong) UILabel      *placeholderLabel;
@property (nonatomic, strong) UISwitch     *enableSwitch;
@property (nonatomic, strong) UILabel      *statusLabel;
@property (nonatomic, strong) UIButton     *flipHBtn;
@property (nonatomic, strong) UIButton     *flipVBtn;

@property (nonatomic, strong) UIImage  *baseImage;
@property (nonatomic, assign) CGFloat   rotateDeg;
@property (nonatomic, assign) BOOL      isFlipH;
@property (nonatomic, assign) BOOL      isFlipV;
@property (nonatomic, assign) BOOL      cropEnabled;
@property (nonatomic, assign) BOOL      injectionEnabled;
@end

@implementation CamInjectListController

- (NSArray *)specifiers { return @[]; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"CamInject";
    self.view.backgroundColor = RGB(12,12,20);
    [self loadConfig];
    [self buildUI];
    [self loadSavedImage];
    [self refreshPreview];
}

#pragma mark - Config

- (void)loadConfig {
    [[NSFileManager defaultManager] createDirectoryAtPath:kLibDir
        withIntermediateDirectories:YES attributes:nil error:nil];
    NSDictionary *cfg = [NSDictionary dictionaryWithContentsOfFile:kConfigPath];
    self.injectionEnabled = cfg[@"enabled"] ? [cfg[@"enabled"] boolValue] : YES;
}

- (void)saveConfig {
    [@{ @"enabled": @(self.injectionEnabled), @"imagePath": kImagePath }
        writeToFile:kConfigPath atomically:YES];
}

- (void)loadSavedImage {
    UIImage *img = [UIImage imageWithContentsOfFile:kImagePath];
    if (img) { self.baseImage = img; }
}

#pragma mark - Build UI

- (UIView *)makeCard {
    UIView *v = [[UIView alloc] init];
    v.translatesAutoresizingMaskIntoConstraints = NO;
    v.backgroundColor = RGB(22,22,38);
    v.layer.cornerRadius = 14;
    v.layer.masksToBounds = YES;
    v.layer.borderWidth = 0.5;
    v.layer.borderColor = RGBA(255,255,255,0.08).CGColor;
    return v;
}

- (UILabel *)sectionLabel:(NSString *)text {
    UILabel *l = [[UILabel alloc] init];
    l.translatesAutoresizingMaskIntoConstraints = NO;
    l.attributedText = [[NSMutableAttributedString alloc]
        initWithString:text.uppercaseString
            attributes:@{
                NSKernAttributeName: @(1.3),
                NSForegroundColorAttributeName: RGBA(140,140,160,1),
                NSFontAttributeName: [UIFont systemFontOfSize:11 weight:UIFontWeightBold]
            }];
    return l;
}

- (void)buildUI {
    const CGFloat pad = 18;

    self.scroll = [[UIScrollView alloc] init];
    self.scroll.translatesAutoresizingMaskIntoConstraints = NO;
    self.scroll.alwaysBounceVertical = YES;
    [self.view addSubview:self.scroll];

    self.content = [[UIView alloc] init];
    self.content.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scroll addSubview:self.content];

    [NSLayoutConstraint activateConstraints:@[
        [self.scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.content.topAnchor constraintEqualToAnchor:self.scroll.topAnchor],
        [self.content.leadingAnchor constraintEqualToAnchor:self.scroll.leadingAnchor],
        [self.content.trailingAnchor constraintEqualToAnchor:self.scroll.trailingAnchor],
        [self.content.bottomAnchor constraintEqualToAnchor:self.scroll.bottomAnchor],
        [self.content.widthAnchor constraintEqualToAnchor:self.scroll.widthAnchor],
    ]];

    UIView *cv = self.content;

    // Header
    UILabel *titleLbl = [[UILabel alloc] init];
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    titleLbl.text = @"CamInject";
    titleLbl.font = [UIFont systemFontOfSize:28 weight:UIFontWeightHeavy];
    titleLbl.textColor = UIColor.whiteColor;
    [cv addSubview:titleLbl];

    UILabel *subLbl = [[UILabel alloc] init];
    subLbl.translatesAutoresizingMaskIntoConstraints = NO;
    subLbl.text = @"Camera Feed Injection";
    subLbl.font = [UIFont systemFontOfSize:13];
    subLbl.textColor = RGBA(120,120,150,1);
    [cv addSubview:subLbl];

    // Toggle card
    UIView *toggleCard = [self makeCard];
    [cv addSubview:toggleCard];

    UILabel *toggleTitle = [[UILabel alloc] init];
    toggleTitle.translatesAutoresizingMaskIntoConstraints = NO;
    toggleTitle.text = @"Injection Active";
    toggleTitle.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    toggleTitle.textColor = UIColor.whiteColor;
    [toggleCard addSubview:toggleTitle];

    UILabel *toggleSub = [[UILabel alloc] init];
    toggleSub.translatesAutoresizingMaskIntoConstraints = NO;
    toggleSub.text = @"Replaces camera feed in all apps";
    toggleSub.font = [UIFont systemFontOfSize:12];
    toggleSub.textColor = RGBA(140,140,160,1);
    [toggleCard addSubview:toggleSub];

    self.enableSwitch = [[UISwitch alloc] init];
    self.enableSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.enableSwitch.onTintColor = RGB(50,200,120);
    self.enableSwitch.on = self.injectionEnabled;
    [self.enableSwitch addTarget:self action:@selector(toggleChanged:)
                forControlEvents:UIControlEventValueChanged];
    [toggleCard addSubview:self.enableSwitch];

    // Preview card
    UIView *previewCard = [self makeCard];
    [cv addSubview:previewCard];
    UILabel *previewSec = [self sectionLabel:@"Preview"];
    [previewCard addSubview:previewSec];

    self.previewView = [[UIImageView alloc] init];
    self.previewView.translatesAutoresizingMaskIntoConstraints = NO;
    self.previewView.contentMode = UIViewContentModeScaleAspectFit;
    self.previewView.backgroundColor = RGB(15,15,25);
    self.previewView.layer.cornerRadius = 8;
    self.previewView.layer.masksToBounds = YES;
    [previewCard addSubview:self.previewView];

    self.placeholderLabel = [[UILabel alloc] init];
    self.placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.placeholderLabel.text = @"No image selected";
    self.placeholderLabel.font = [UIFont systemFontOfSize:14];
    self.placeholderLabel.textColor = RGBA(100,100,130,1);
    self.placeholderLabel.textAlignment = NSTextAlignmentCenter;
    [self.previewView addSubview:self.placeholderLabel];

    // Choose button
    UIButton *chooseBtn = MakePill(@"Choose Photo", RGB(40,110,255));
    [chooseBtn addTarget:self action:@selector(chooseTapped)
        forControlEvents:UIControlEventTouchUpInside];
    [cv addSubview:chooseBtn];

    // Transform card
    UIView *transformCard = [self makeCard];
    [cv addSubview:transformCard];
    UILabel *transformSec = [self sectionLabel:@"Transform"];
    [transformCard addSubview:transformSec];

    UILabel *rotLabel = [[UILabel alloc] init];
    rotLabel.translatesAutoresizingMaskIntoConstraints = NO;
    rotLabel.text = @"Rotate";
    rotLabel.font = [UIFont systemFontOfSize:13];
    rotLabel.textColor = RGBA(180,180,200,1);
    [transformCard addSubview:rotLabel];

    UIButton *rotL = MakePill(@"90 Left",  RGB(55,55,80));
    UIButton *rotR = MakePill(@"90 Right", RGB(55,55,80));
    [rotL addTarget:self action:@selector(rotateCCW) forControlEvents:UIControlEventTouchUpInside];
    [rotR addTarget:self action:@selector(rotateCW)  forControlEvents:UIControlEventTouchUpInside];
    [transformCard addSubview:rotL];
    [transformCard addSubview:rotR];

    UILabel *flipLabel = [[UILabel alloc] init];
    flipLabel.translatesAutoresizingMaskIntoConstraints = NO;
    flipLabel.text = @"Flip";
    flipLabel.font = [UIFont systemFontOfSize:13];
    flipLabel.textColor = RGBA(180,180,200,1);
    [transformCard addSubview:flipLabel];

    self.flipHBtn = MakePill(@"Horizontal", RGB(55,55,80));
    self.flipVBtn = MakePill(@"Vertical",   RGB(55,55,80));
    [self.flipHBtn addTarget:self action:@selector(doFlipH) forControlEvents:UIControlEventTouchUpInside];
    [self.flipVBtn addTarget:self action:@selector(doFlipV) forControlEvents:UIControlEventTouchUpInside];
    [transformCard addSubview:self.flipHBtn];
    [transformCard addSubview:self.flipVBtn];

    // Crop card
    UIView *cropCard = [self makeCard];
    [cv addSubview:cropCard];
    UILabel *cropSec = [self sectionLabel:@"Crop"];
    [cropCard addSubview:cropSec];

    UILabel *cropDesc = [[UILabel alloc] init];
    cropDesc.translatesAutoresizingMaskIntoConstraints = NO;
    cropDesc.text = @"Crop to 9:16 portrait";
    cropDesc.font = [UIFont systemFontOfSize:13];
    cropDesc.textColor = RGBA(180,180,200,1);
    [cropCard addSubview:cropDesc];

    UISwitch *cropSwitch = [[UISwitch alloc] init];
    cropSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    cropSwitch.onTintColor = RGB(50,200,120);
    cropSwitch.on = NO;
    [cropSwitch addTarget:self action:@selector(cropToggled:)
        forControlEvents:UIControlEventValueChanged];
    [cropCard addSubview:cropSwitch];

    // Apply button
    UIButton *applyBtn = MakePill(@"Apply & Activate", RGB(50,200,120));
    applyBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [applyBtn addTarget:self action:@selector(applyTapped)
        forControlEvents:UIControlEventTouchUpInside];
    [cv addSubview:applyBtn];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.text = @"";
    self.statusLabel.font = [UIFont systemFontOfSize:13];
    self.statusLabel.textColor = RGB(50,200,120);
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 2;
    [cv addSubview:self.statusLabel];

    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [titleLbl.topAnchor constraintEqualToAnchor:cv.topAnchor constant:24],
        [titleLbl.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor constant:pad],

        [subLbl.topAnchor constraintEqualToAnchor:titleLbl.bottomAnchor constant:4],
        [subLbl.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor constant:pad],

        [toggleCard.topAnchor constraintEqualToAnchor:subLbl.bottomAnchor constant:20],
        [toggleCard.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor constant:pad],
        [toggleCard.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor constant:-pad],
        [toggleTitle.topAnchor constraintEqualToAnchor:toggleCard.topAnchor constant:14],
        [toggleTitle.leadingAnchor constraintEqualToAnchor:toggleCard.leadingAnchor constant:14],
        [toggleSub.topAnchor constraintEqualToAnchor:toggleTitle.bottomAnchor constant:3],
        [toggleSub.leadingAnchor constraintEqualToAnchor:toggleCard.leadingAnchor constant:14],
        [toggleSub.bottomAnchor constraintEqualToAnchor:toggleCard.bottomAnchor constant:-14],
        [self.enableSwitch.centerYAnchor constraintEqualToAnchor:toggleCard.centerYAnchor],
        [self.enableSwitch.trailingAnchor constraintEqualToAnchor:toggleCard.trailingAnchor constant:-14],

        [previewCard.topAnchor constraintEqualToAnchor:toggleCard.bottomAnchor constant:14],
        [previewCard.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor constant:pad],
        [previewCard.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor constant:-pad],
        [previewSec.topAnchor constraintEqualToAnchor:previewCard.topAnchor constant:14],
        [previewSec.leadingAnchor constraintEqualToAnchor:previewCard.leadingAnchor constant:14],
        [self.previewView.topAnchor constraintEqualToAnchor:previewSec.bottomAnchor constant:10],
        [self.previewView.leadingAnchor constraintEqualToAnchor:previewCard.leadingAnchor constant:14],
        [self.previewView.trailingAnchor constraintEqualToAnchor:previewCard.trailingAnchor constant:-14],
        [self.previewView.heightAnchor constraintEqualToConstant:200],
        [self.previewView.bottomAnchor constraintEqualToAnchor:previewCard.bottomAnchor constant:-14],
        [self.placeholderLabel.centerXAnchor constraintEqualToAnchor:self.previewView.centerXAnchor],
        [self.placeholderLabel.centerYAnchor constraintEqualToAnchor:self.previewView.centerYAnchor],

        [chooseBtn.topAnchor constraintEqualToAnchor:previewCard.bottomAnchor constant:14],
        [chooseBtn.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor constant:pad],
        [chooseBtn.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor constant:-pad],
        [chooseBtn.heightAnchor constraintEqualToConstant:48],

        [transformCard.topAnchor constraintEqualToAnchor:chooseBtn.bottomAnchor constant:14],
        [transformCard.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor constant:pad],
        [transformCard.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor constant:-pad],
        [transformSec.topAnchor constraintEqualToAnchor:transformCard.topAnchor constant:14],
        [transformSec.leadingAnchor constraintEqualToAnchor:transformCard.leadingAnchor constant:14],
        [rotLabel.topAnchor constraintEqualToAnchor:transformSec.bottomAnchor constant:12],
        [rotLabel.leadingAnchor constraintEqualToAnchor:transformCard.leadingAnchor constant:14],
        [rotL.topAnchor constraintEqualToAnchor:rotLabel.bottomAnchor constant:8],
        [rotL.leadingAnchor constraintEqualToAnchor:transformCard.leadingAnchor constant:14],
        [rotL.trailingAnchor constraintEqualToAnchor:transformCard.centerXAnchor constant:-6],
        [rotL.heightAnchor constraintEqualToConstant:40],
        [rotR.topAnchor constraintEqualToAnchor:rotLabel.bottomAnchor constant:8],
        [rotR.leadingAnchor constraintEqualToAnchor:transformCard.centerXAnchor constant:6],
        [rotR.trailingAnchor constraintEqualToAnchor:transformCard.trailingAnchor constant:-14],
        [rotR.heightAnchor constraintEqualToConstant:40],
        [flipLabel.topAnchor constraintEqualToAnchor:rotL.bottomAnchor constant:12],
        [flipLabel.leadingAnchor constraintEqualToAnchor:transformCard.leadingAnchor constant:14],
        [self.flipHBtn.topAnchor constraintEqualToAnchor:flipLabel.bottomAnchor constant:8],
        [self.flipHBtn.leadingAnchor constraintEqualToAnchor:transformCard.leadingAnchor constant:14],
        [self.flipHBtn.trailingAnchor constraintEqualToAnchor:transformCard.centerXAnchor constant:-6],
        [self.flipHBtn.heightAnchor constraintEqualToConstant:40],
        [self.flipVBtn.topAnchor constraintEqualToAnchor:flipLabel.bottomAnchor constant:8],
        [self.flipVBtn.leadingAnchor constraintEqualToAnchor:transformCard.centerXAnchor constant:6],
        [self.flipVBtn.trailingAnchor constraintEqualToAnchor:transformCard.trailingAnchor constant:-14],
        [self.flipVBtn.heightAnchor constraintEqualToConstant:40],
        [self.flipVBtn.bottomAnchor constraintEqualToAnchor:transformCard.bottomAnchor constant:-14],

        [cropCard.topAnchor constraintEqualToAnchor:transformCard.bottomAnchor constant:14],
        [cropCard.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor constant:pad],
        [cropCard.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor constant:-pad],
        [cropSec.topAnchor constraintEqualToAnchor:cropCard.topAnchor constant:14],
        [cropSec.leadingAnchor constraintEqualToAnchor:cropCard.leadingAnchor constant:14],
        [cropDesc.topAnchor constraintEqualToAnchor:cropSec.bottomAnchor constant:10],
        [cropDesc.leadingAnchor constraintEqualToAnchor:cropCard.leadingAnchor constant:14],
        [cropDesc.bottomAnchor constraintEqualToAnchor:cropCard.bottomAnchor constant:-14],
        [cropSwitch.centerYAnchor constraintEqualToAnchor:cropDesc.centerYAnchor],
        [cropSwitch.trailingAnchor constraintEqualToAnchor:cropCard.trailingAnchor constant:-14],

        [applyBtn.topAnchor constraintEqualToAnchor:cropCard.bottomAnchor constant:20],
        [applyBtn.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor constant:pad],
        [applyBtn.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor constant:-pad],
        [applyBtn.heightAnchor constraintEqualToConstant:52],

        [self.statusLabel.topAnchor constraintEqualToAnchor:applyBtn.bottomAnchor constant:10],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:cv.leadingAnchor constant:pad],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:cv.trailingAnchor constant:-pad],
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:cv.bottomAnchor constant:-36],
    ]];
}

#pragma mark - Actions

- (void)toggleChanged:(UISwitch *)sw { self.injectionEnabled = sw.on; }
- (void)cropToggled:(UISwitch *)sw   { self.cropEnabled = sw.on; [self refreshPreview]; }

- (void)chooseTapped {
    if (![UIImagePickerController isSourceTypeAvailable:
            UIImagePickerControllerSourceTypePhotoLibrary]) return;
    UIImagePickerController *p = [[UIImagePickerController alloc] init];
    p.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    p.delegate   = self;
    [self presentViewController:p animated:YES completion:nil];
}

- (void)rotateCCW {
    if (!self.baseImage) return;
    self.rotateDeg = fmod(self.rotateDeg - 90 + 360, 360);
    [self refreshPreview];
}

- (void)rotateCW {
    if (!self.baseImage) return;
    self.rotateDeg = fmod(self.rotateDeg + 90, 360);
    [self refreshPreview];
}

- (void)doFlipH {
    if (!self.baseImage) return;
    self.isFlipH = !self.isFlipH;
    self.flipHBtn.backgroundColor = self.isFlipH ? RGB(40,110,255) : RGB(55,55,80);
    [self refreshPreview];
}

- (void)doFlipV {
    if (!self.baseImage) return;
    self.isFlipV = !self.isFlipV;
    self.flipVBtn.backgroundColor = self.isFlipV ? RGB(40,110,255) : RGB(55,55,80);
    [self refreshPreview];
}

- (void)applyTapped {
    if (!self.baseImage) {
        [self showAlert:@"No Image" message:@"Please choose a photo first."];
        return;
    }

    UIImage *final = [self buildTransformedImage];
    NSData *png = UIImagePNGRepresentation(final);
    if (!png) {
        [self showAlert:@"Error" message:@"Failed to process image."];
        return;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *err = nil;

    if (![fm fileExistsAtPath:kLibDir]) {
        [fm createDirectoryAtPath:kLibDir withIntermediateDirectories:YES
                       attributes:nil error:&err];
        if (err) {
            [self showAlert:@"Save Failed" message:err.localizedDescription];
            return;
        }
    }

    BOOL ok = [png writeToFile:kImagePath options:NSDataWritingAtomic error:&err];
    if (!ok) {
        [self showAlert:@"Save Failed" message:err.localizedDescription ?: @"Unknown error."];
        return;
    }

    self.injectionEnabled = self.enableSwitch.on;
    [self saveConfig];

    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.yourname.camerainject.reload"),
        NULL, NULL, YES);

    [self showStatus:@"Applied! Open any camera app to test."];
    UINotificationFeedbackGenerator *g = [[UINotificationFeedbackGenerator alloc] init];
    [g notificationOccurred:UINotificationFeedbackTypeSuccess];
}

#pragma mark - Image processing

- (UIImage *)buildTransformedImage {
    UIImage *img = self.baseImage;
    CGSize size  = img.size;
    BOOL swap    = (fmod(self.rotateDeg, 180) != 0);
    CGSize out   = swap ? CGSizeMake(size.height, size.width) : size;

    UIGraphicsBeginImageContextWithOptions(out, NO, img.scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(ctx, out.width/2, out.height/2);
    CGContextScaleCTM(ctx, self.isFlipH ? -1:1, self.isFlipV ? -1:1);
    CGContextRotateCTM(ctx, self.rotateDeg * M_PI / 180.0);
    [img drawInRect:CGRectMake(-size.width/2, -size.height/2, size.width, size.height)];
    UIImage *rotated = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (!rotated) return img;

    if (self.cropEnabled) {
        CGSize rs       = rotated.size;
        CGFloat targetW = rs.height * (9.0/16.0);
        CGFloat x       = (rs.width - targetW) / 2.0;
        CGRect cropRect = CGRectMake(x * rotated.scale, 0,
                                     targetW * rotated.scale,
                                     rs.height * rotated.scale);
        CGImageRef ci = CGImageCreateWithImageInRect(rotated.CGImage, cropRect);
        rotated = [UIImage imageWithCGImage:ci scale:rotated.scale
                               orientation:rotated.imageOrientation];
        CGImageRelease(ci);
    }
    return rotated;
}

- (void)refreshPreview {
    if (!self.baseImage) {
        self.previewView.image = nil;
        self.placeholderLabel.hidden = NO;
        return;
    }
    self.placeholderLabel.hidden = YES;
    self.previewView.image = [self buildTransformedImage];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *img = info[UIImagePickerControllerEditedImage]
                ?: info[UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (!img) return;
    self.baseImage = img;
    self.rotateDeg = 0;
    self.isFlipH = NO;
    self.isFlipV = NO;
    self.flipHBtn.backgroundColor = RGB(55,55,80);
    self.flipVBtn.backgroundColor = RGB(55,55,80);
    [self refreshPreview];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Helpers

- (void)showStatus:(NSString *)msg {
    self.statusLabel.alpha = 1;
    self.statusLabel.text  = msg;
    [UIView animateWithDuration:0.4 delay:3.0 options:0 animations:^{
        self.statusLabel.alpha = 0;
    } completion:nil];
}

- (void)showAlert:(NSString *)title message:(NSString *)msg {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title
        message:msg preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK"
        style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

@end
