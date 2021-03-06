//
// RSKImageCropViewController.m
//
// Copyright (c) 2014-present Ruslan Skorb, http://ruslanskorb.com/
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "RSKImageCropViewController.h"
#import "RSKTouchView.h"
#import "RSKImageScrollView.h"
#import "RSKInternalUtility.h"
#import "UIImage+RSKImageCropper.h"
#import "CGGeometry+RSKImageCropper.h"
#import "UIApplication+RSKImageCropper.h"
#import "UISelfPanGestureRecognizer.h"

static const CGFloat kPortraitCircleMaskRectInnerEdgeInset = 15.0f;
static const CGFloat kPortraitSquareMaskRectInnerEdgeInset = 20.0f;
static const CGFloat kPortraitMoveAndScaleLabelVerticalMargin = 64.0f;
static const CGFloat kPortraitCancelAndChooseButtonsHorizontalMargin = 13.0f;
static const CGFloat kPortraitCancelAndChooseButtonsVerticalMargin = 21.0f;

static const CGFloat kLandscapeCircleMaskRectInnerEdgeInset = 45.0f;
static const CGFloat kLandscapeSquareMaskRectInnerEdgeInset = 45.0f;
static const CGFloat kLandscapeMoveAndScaleLabelVerticalMargin = 12.0f;
static const CGFloat kLandscapeCancelAndChooseButtonsVerticalMargin = 12.0f;

static const CGFloat kResetAnimationDuration = 0.4;
static const CGFloat kLayoutImageScrollViewAnimationDuration = 0.25;

// K is a constant such that the accumulated error of our floating-point computations is definitely bounded by K units in the last place.
#ifdef CGFLOAT_IS_DOUBLE
    static const CGFloat kK = 9;
#else
    static const CGFloat kK = 0;
#endif

#define MyPointRect self.TheRect


@interface RSKImageCropViewController () <UIGestureRecognizerDelegate>

@property (assign, nonatomic) BOOL originalNavigationControllerNavigationBarHidden;
@property (strong, nonatomic) UIImage *originalNavigationControllerNavigationBarShadowImage;
@property (copy, nonatomic) UIColor *originalNavigationControllerViewBackgroundColor;
@property (assign, nonatomic) BOOL originalStatusBarHidden;

@property (strong, nonatomic) RSKImageScrollView *imageScrollView;
@property (strong, nonatomic) RSKTouchView *overlayView;
@property (strong, nonatomic) CAShapeLayer *maskLayer;

@property (assign, nonatomic) CGRect maskRect;
@property (copy, nonatomic) UIBezierPath *maskPath;

@property (readonly, nonatomic) CGRect rectForMaskPath;
@property (readonly, nonatomic) CGRect rectForClipPath;

@property (strong, nonatomic) UILabel *moveAndScaleLabel;
@property (strong, nonatomic) UIButton *cancelButton;
@property (strong, nonatomic) UIButton *chooseButton;

@property (strong, nonatomic) UITapGestureRecognizer *doubleTapGestureRecognizer;
@property (strong, nonatomic) UIRotationGestureRecognizer *rotationGestureRecognizer;

@property (assign, nonatomic) BOOL didSetupConstraints;
@property (strong, nonatomic) NSLayoutConstraint *moveAndScaleLabelTopConstraint;
@property (strong, nonatomic) NSLayoutConstraint *cancelButtonBottomConstraint;
@property (strong, nonatomic) NSLayoutConstraint *chooseButtonBottomConstraint;


#pragma mark - 新添加功能 -- 自定义调整裁剪框
@property (strong, nonatomic) UIView *lineTop;
@property (strong, nonatomic) UIView *lineRight;
@property (strong, nonatomic) UIView *lineBottom;
@property (strong, nonatomic) UIView *lineLeft;

@property (strong, nonatomic) UIView *leftTop;
@property (strong, nonatomic) UIView *rightTop;
@property (strong, nonatomic) UIView *rightBottom;
@property (strong, nonatomic) UIView *leftBottom;

@property (assign, nonatomic) CGFloat scrollDefaultx;
@property (assign, nonatomic) CGFloat scrollDefaulty;

@property (assign, nonatomic) CGFloat minPicWidth;
@property (assign, nonatomic) CGFloat minPicHight;

@property (assign, nonatomic) CGFloat minEdgeWidth;
@property (assign, nonatomic) CGFloat minEdgeHight;

@property (assign, nonatomic) CGFloat cornerLineK;
@property (assign, nonatomic) CGFloat cornerLineB;
@property (assign, nonatomic) CGFloat cornerLineB2;

@property (assign, nonatomic) CGFloat defaultx;
@property (assign, nonatomic) CGFloat defaulty;

@property (assign, nonatomic) BOOL firstMark;

#pragma mark -


@end

@implementation RSKImageCropViewController

#pragma mark - Lifecycle

- (instancetype)init
{
    self = [super init];
    if (self) {
        _avoidEmptySpaceAroundImage = NO;
        _applyMaskToCroppedImage = NO;
        _maskLayerLineWidth = 1.0;
        _rotationEnabled = NO;
        _cropMode = RSKImageCropModeCircle;
        _minEdgeWidth = 15;
        _minEdgeHight = 100;
        _minPicWidth = 100;
        _minPicHight = 100;
        _defaultx = 20;
        _defaulty = 89;
        _firstMark = YES;
    }
    return self;
}

- (instancetype)initWithImage:(UIImage *)originalImage
{
    self = [self init];
    if (self) {
        _originalImage = originalImage;
    }
    return self;
}

- (instancetype)initWithImage:(UIImage *)originalImage cropMode:(RSKImageCropMode)cropMode
{
    self = [self initWithImage:originalImage];
    if (self) {
        _cropMode = cropMode;
    }
    return self;
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.automaticallyAdjustsScrollViewInsets = NO;
    }
    
    self.view.backgroundColor = [UIColor colorWithWhite:0.35 alpha:0.3];
    self.view.clipsToBounds = YES;
    
    [self.view addSubview:self.imageScrollView];
    [self.view addSubview:self.overlayView];
    [self.view addSubview:self.moveAndScaleLabel];
    [self.view addSubview:self.cancelButton];
    [self.view addSubview:self.chooseButton];
    
    [self.view addGestureRecognizer:self.doubleTapGestureRecognizer];
    [self.view addGestureRecognizer:self.rotationGestureRecognizer];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    UIApplication *application = [UIApplication rsk_sharedApplication];
    if (application) {
        self.originalStatusBarHidden = application.statusBarHidden;
        [application setStatusBarHidden:YES];
    }
    
    self.originalNavigationControllerNavigationBarHidden = self.navigationController.navigationBarHidden;
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    
    self.originalNavigationControllerNavigationBarShadowImage = self.navigationController.navigationBar.shadowImage;
    self.navigationController.navigationBar.shadowImage = nil;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    self.originalNavigationControllerViewBackgroundColor = self.navigationController.view.backgroundColor;
    self.navigationController.view.backgroundColor = [UIColor blackColor];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    UIApplication *application = [UIApplication rsk_sharedApplication];
    if (application) {
        [application setStatusBarHidden:self.originalStatusBarHidden];
    }
    
    [self.navigationController setNavigationBarHidden:self.originalNavigationControllerNavigationBarHidden animated:animated];
    self.navigationController.navigationBar.shadowImage = self.originalNavigationControllerNavigationBarShadowImage;
    self.navigationController.view.backgroundColor = self.originalNavigationControllerViewBackgroundColor;
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    [self updateMaskRect];
    [self layoutImageScrollView];
    [self layoutOverlayView];
    [self updateMaskPath];
    
    //新添加裁剪框
    if (_firstMark) {
        [self setDragable];
        _firstMark = NO;
    }
    else {
        [self resetMaskView];
    }
    
    [self.view setNeedsUpdateConstraints];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    if (!self.imageScrollView.zoomView) {
        [self displayImage];
    }
}

- (void)updateViewConstraints
{
    [super updateViewConstraints];
    
    if (!self.didSetupConstraints) {
        // ---------------------------
        // The label "Move and Scale".
        // ---------------------------
        
        NSLayoutConstraint *constraint = [NSLayoutConstraint constraintWithItem:self.moveAndScaleLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual
                                                                         toItem:self.view attribute:NSLayoutAttributeCenterX multiplier:1.0f
                                                                       constant:0.0f];
        [self.view addConstraint:constraint];
        
        CGFloat constant = kPortraitMoveAndScaleLabelVerticalMargin;
        self.moveAndScaleLabelTopConstraint = [NSLayoutConstraint constraintWithItem:self.moveAndScaleLabel attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual
                                                                              toItem:self.view attribute:NSLayoutAttributeTop multiplier:1.0f
                                                                            constant:constant];
        [self.view addConstraint:self.moveAndScaleLabelTopConstraint];
        
        // --------------------
        // The button "Cancel".
        // --------------------
        
        constant = kPortraitCancelAndChooseButtonsHorizontalMargin;
        constraint = [NSLayoutConstraint constraintWithItem:self.cancelButton attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual
                                                     toItem:self.view attribute:NSLayoutAttributeLeft multiplier:1.0f
                                                   constant:constant];
        [self.view addConstraint:constraint];
        
        constant = -kPortraitCancelAndChooseButtonsVerticalMargin;
        self.cancelButtonBottomConstraint = [NSLayoutConstraint constraintWithItem:self.cancelButton attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual
                                                                            toItem:self.view attribute:NSLayoutAttributeBottom multiplier:1.0f
                                                                          constant:constant];
        [self.view addConstraint:self.cancelButtonBottomConstraint];
        
        // --------------------
        // The button "Choose".
        // --------------------
        
        constant = -kPortraitCancelAndChooseButtonsHorizontalMargin;
        constraint = [NSLayoutConstraint constraintWithItem:self.chooseButton attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual
                                                     toItem:self.view attribute:NSLayoutAttributeRight multiplier:1.0f
                                                   constant:constant];
        [self.view addConstraint:constraint];
        
        constant = -kPortraitCancelAndChooseButtonsVerticalMargin;
        self.chooseButtonBottomConstraint = [NSLayoutConstraint constraintWithItem:self.chooseButton attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual
                                                                            toItem:self.view attribute:NSLayoutAttributeBottom multiplier:1.0f
                                                                          constant:constant];
        [self.view addConstraint:self.chooseButtonBottomConstraint];
        
        self.didSetupConstraints = YES;
    } else {
        if ([self isPortraitInterfaceOrientation]) {
            self.moveAndScaleLabelTopConstraint.constant = kPortraitMoveAndScaleLabelVerticalMargin;
            self.cancelButtonBottomConstraint.constant = -kPortraitCancelAndChooseButtonsVerticalMargin;
            self.chooseButtonBottomConstraint.constant = -kPortraitCancelAndChooseButtonsVerticalMargin;
        } else {
            self.moveAndScaleLabelTopConstraint.constant = kLandscapeMoveAndScaleLabelVerticalMargin;
            self.cancelButtonBottomConstraint.constant = -kLandscapeCancelAndChooseButtonsVerticalMargin;
            self.chooseButtonBottomConstraint.constant = -kLandscapeCancelAndChooseButtonsVerticalMargin;
        }
    }
}

#pragma mark - Custom Accessors

- (RSKImageScrollView *)imageScrollView
{
    if (!_imageScrollView) {
        _imageScrollView = [[RSKImageScrollView alloc] init];
        _imageScrollView.clipsToBounds = NO;
        //_imageScrollView.aspectFill = self.avoidEmptySpaceAroundImage;
        _imageScrollView.aspectFill = NO;
    }
    return _imageScrollView;
}

- (RSKTouchView *)overlayView
{
    if (!_overlayView) {
        _overlayView = [[RSKTouchView alloc] init];
        _overlayView.receiver = self.imageScrollView;
        [_overlayView.layer addSublayer:self.maskLayer];
    }
    return _overlayView;
}

- (CAShapeLayer *)maskLayer
{
    if (!_maskLayer) {
        _maskLayer = [CAShapeLayer layer];
        _maskLayer.fillRule = kCAFillRuleEvenOdd;
        _maskLayer.fillColor = self.maskLayerColor.CGColor;
        _maskLayer.lineWidth = self.maskLayerLineWidth;
        _maskLayer.strokeColor = self.maskLayerStrokeColor.CGColor;
    }
    return _maskLayer;
}

- (UIColor *)maskLayerColor
{
    if (!_maskLayerColor) {
        _maskLayerColor = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.7f];
    }
    return _maskLayerColor;
}

- (UILabel *)moveAndScaleLabel
{
    if (!_moveAndScaleLabel) {
        _moveAndScaleLabel = [[UILabel alloc] init];
        _moveAndScaleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _moveAndScaleLabel.backgroundColor = [UIColor clearColor];
        _moveAndScaleLabel.text = RSKLocalizedString(@"Move and Scale", @"Move and Scale label");
        _moveAndScaleLabel.textColor = [UIColor whiteColor];
        _moveAndScaleLabel.opaque = NO;
    }
    return _moveAndScaleLabel;
}

- (UIButton *)cancelButton
{
    if (!_cancelButton) {
        _cancelButton = [[UIButton alloc] init];
        _cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
        [_cancelButton setTitle:RSKLocalizedString(@"Cancel", @"Cancel button") forState:UIControlStateNormal];
        [_cancelButton addTarget:self action:@selector(onCancelButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
        _cancelButton.opaque = NO;
    }
    return _cancelButton;
}

- (UIButton *)chooseButton
{
    if (!_chooseButton) {
        _chooseButton = [[UIButton alloc] init];
        _chooseButton.translatesAutoresizingMaskIntoConstraints = NO;
        [_chooseButton setTitle:RSKLocalizedString(@"Choose", @"Choose button") forState:UIControlStateNormal];
        [_chooseButton addTarget:self action:@selector(onChooseButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
        _chooseButton.opaque = NO;
    }
    return _chooseButton;
}

- (UITapGestureRecognizer *)doubleTapGestureRecognizer
{
    if (!_doubleTapGestureRecognizer) {
        _doubleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
        _doubleTapGestureRecognizer.delaysTouchesEnded = NO;
        _doubleTapGestureRecognizer.numberOfTapsRequired = 2;
        _doubleTapGestureRecognizer.delegate = self;
    }
    return _doubleTapGestureRecognizer;
}

- (UIRotationGestureRecognizer *)rotationGestureRecognizer
{
    if (!_rotationGestureRecognizer) {
        _rotationGestureRecognizer = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(handleRotation:)];
        _rotationGestureRecognizer.delaysTouchesEnded = NO;
        _rotationGestureRecognizer.delegate = self;
        _rotationGestureRecognizer.enabled = self.isRotationEnabled;
    }
    return _rotationGestureRecognizer;
}


//- (CGRect)cropRect
//{
//    CGRect cropRect = CGRectZero;
//    float zoomScale = 1.0 / self.imageScrollView.zoomScale;
//
//    cropRect.origin.x = round(self.imageScrollView.contentOffset.x * zoomScale);
//    cropRect.origin.y = round(self.imageScrollView.contentOffset.y * zoomScale);
//    cropRect.size.width = CGRectGetWidth(self.imageScrollView.bounds) * zoomScale;
//    cropRect.size.height = CGRectGetHeight(self.imageScrollView.bounds) * zoomScale;
//
//    CGFloat width = CGRectGetWidth(cropRect);
//    CGFloat height = CGRectGetHeight(cropRect);
//    CGFloat ceilWidth = ceil(width);
//    CGFloat ceilHeight = ceil(height);
//
//    if (fabs(ceilWidth - width) < pow(10, kK) * RSK_EPSILON * fabs(ceilWidth + width) || fabs(ceilWidth - width) < RSK_MIN ||
//        fabs(ceilHeight - height) < pow(10, kK) * RSK_EPSILON * fabs(ceilHeight + height) || fabs(ceilHeight - height) < RSK_MIN) {
//
//        cropRect.size.width = ceilWidth;
//        cropRect.size.height = ceilHeight;
//    } else {
//        cropRect.size.width = floor(width);
//        cropRect.size.height = floor(height);
//    }
//
//    return cropRect;
//}

/*把剪切时候的Rect改成自定义Rect*/
- (CGRect)cropRect
{
    CGRect cropRect = CGRectZero;
    float zoomScale = 1.0 / self.imageScrollView.zoomScale;

    NSLog(@"%f\n,%f\n,%f\n",self.imageScrollView.contentOffset.x,MyPointRect.origin.x,_defaultx);
    NSLog(@"%f\n,%f\n,%f\n",self.imageScrollView.contentOffset.y,MyPointRect.origin.y,_defaulty);
    
    CGSize boundsSize = self.imageScrollView.bounds.size;
    CGRect frameToCenter = self.imageScrollView.zoomView.frame;
    
    if (self.imageScrollView.contentOffset.x == 0) {
        CGFloat offsetx = (CGRectGetWidth(frameToCenter) - boundsSize.width) * 0.5f;
        printf("offsetx = %f\n",offsetx);
        cropRect.origin.x = round((self.imageScrollView.contentOffset.x + offsetx + (MyPointRect.origin.x - _defaultx)) * zoomScale);
    }
    else
    {
        cropRect.origin.x = round((self.imageScrollView.contentOffset.x + (MyPointRect.origin.x - _defaultx)) * zoomScale);
    }
    
    if (self.imageScrollView.contentOffset.y == 0) {
        CGFloat offsety = (CGRectGetHeight(frameToCenter) - boundsSize.height) * 0.5f;
        printf("offsety = %f\n",offsety);
        cropRect.origin.y = round((self.imageScrollView.contentOffset.y + offsety + (MyPointRect.origin.y - _defaulty)) * zoomScale);
    }
    else {
        cropRect.origin.y = round((self.imageScrollView.contentOffset.y + (MyPointRect.origin.y - _defaulty)) * zoomScale);
    }
    cropRect.size.width = (MyPointRect.size.width) * zoomScale;
    cropRect.size.height = (MyPointRect.size.height) * zoomScale;
    
    CGFloat width = CGRectGetWidth(cropRect);
    CGFloat height = CGRectGetHeight(cropRect);
    CGFloat ceilWidth = ceil(width);
    CGFloat ceilHeight = ceil(height);
    
    if (fabs(ceilWidth - width) < pow(10, kK) * RSK_EPSILON * fabs(ceilWidth + width) || fabs(ceilWidth - width) < RSK_MIN ||
        fabs(ceilHeight - height) < pow(10, kK) * RSK_EPSILON * fabs(ceilHeight + height) || fabs(ceilHeight - height) < RSK_MIN) {
        
        cropRect.size.width = ceilWidth;
        cropRect.size.height = ceilHeight;
    } else {
        cropRect.size.width = floor(width);
        cropRect.size.height = floor(height);
    }
    
    NSLog(@"%f\n,%f\n,%f\n,%f\n",cropRect.origin.x,cropRect.origin.y,cropRect.size.width,cropRect.size.height);
    return cropRect;
}

- (CGRect)rectForClipPath
{
    if (!self.maskLayerStrokeColor) {
        return self.overlayView.frame;
    } else {
        CGFloat maskLayerLineHalfWidth = self.maskLayerLineWidth / 2.0;
        return CGRectInset(self.overlayView.frame, -maskLayerLineHalfWidth, -maskLayerLineHalfWidth);
    }
}

- (CGRect)rectForMaskPath
{
    if (!self.maskLayerStrokeColor) {
        return self.maskRect;
    } else {
        CGFloat maskLayerLineHalfWidth = self.maskLayerLineWidth / 2.0;
        return CGRectInset(self.maskRect, maskLayerLineHalfWidth, maskLayerLineHalfWidth);
    }
}

- (CGFloat)rotationAngle
{
    CGAffineTransform transform = self.imageScrollView.transform;
    CGFloat rotationAngle = atan2(transform.b, transform.a);
    return rotationAngle;
}

- (CGFloat)zoomScale
{
    return self.imageScrollView.zoomScale;
}

- (void)setAvoidEmptySpaceAroundImage:(BOOL)avoidEmptySpaceAroundImage
{
    if (_avoidEmptySpaceAroundImage != avoidEmptySpaceAroundImage) {
        _avoidEmptySpaceAroundImage = avoidEmptySpaceAroundImage;
        
        //self.imageScrollView.aspectFill = avoidEmptySpaceAroundImage;
        self.imageScrollView.aspectFill = NO;
    }
}

- (void)setCropMode:(RSKImageCropMode)cropMode
{
    if (_cropMode != cropMode) {
        _cropMode = cropMode;
        
        if (self.imageScrollView.zoomView) {
            [self reset:NO];
        }
    }
}

- (void)setOriginalImage:(UIImage *)originalImage
{
    if (![_originalImage isEqual:originalImage]) {
        _originalImage = originalImage;
        if (self.isViewLoaded && self.view.window) {
            [self displayImage];
        }
    }
}

- (void)setMaskPath:(UIBezierPath *)maskPath
{
    if (![_maskPath isEqual:maskPath]) {
        _maskPath = maskPath;
        
        UIBezierPath *clipPath = [UIBezierPath bezierPathWithRect:self.rectForClipPath];
        [clipPath appendPath:maskPath];
        clipPath.usesEvenOddFillRule = YES;
        
//        CABasicAnimation *pathAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
//        pathAnimation.duration = [CATransaction animationDuration];
//        pathAnimation.timingFunction = [CATransaction animationTimingFunction];
//        [self.maskLayer addAnimation:pathAnimation forKey:@"path"];
        
        self.maskLayer.path = [clipPath CGPath];
    }
}

- (void)setRotationAngle:(CGFloat)rotationAngle
{
    if (self.rotationAngle != rotationAngle) {
        CGFloat rotation = (rotationAngle - self.rotationAngle);
        CGAffineTransform transform = CGAffineTransformRotate(self.imageScrollView.transform, rotation);
        self.imageScrollView.transform = transform;
    }
}

- (void)setRotationEnabled:(BOOL)rotationEnabled
{
    if (_rotationEnabled != rotationEnabled) {
        _rotationEnabled = rotationEnabled;
        
        self.rotationGestureRecognizer.enabled = rotationEnabled;
    }
}

#pragma mark - Action handling

- (void)onCancelButtonTouch:(UIBarButtonItem *)sender
{
    [self cancelCrop];
}

- (void)onChooseButtonTouch:(UIBarButtonItem *)sender
{
    [self cropImage];
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)gestureRecognizer
{
    [self reset:YES];
}

- (void)handleRotation:(UIRotationGestureRecognizer *)gestureRecognizer
{
    [self setRotationAngle:(self.rotationAngle + gestureRecognizer.rotation)];
    gestureRecognizer.rotation = 0;
    
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        [UIView animateWithDuration:kLayoutImageScrollViewAnimationDuration
                              delay:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             [self layoutImageScrollView];
                         }
                         completion:nil];
    }
}

#pragma mark - Public

- (BOOL)isPortraitInterfaceOrientation
{
    return CGRectGetHeight(self.view.bounds) > CGRectGetWidth(self.view.bounds);
}

#pragma mark - Private

- (void)reset:(BOOL)animated
{
    if (animated) {
        [UIView beginAnimations:@"rsk_reset" context:NULL];
        [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
        [UIView setAnimationDuration:kResetAnimationDuration];
        [UIView setAnimationBeginsFromCurrentState:YES];
    }
    
    [self resetRotation];
    [self resetFrame];
    [self resetZoomScale];
    [self resetContentOffset];
    
    if (animated) {
        [UIView commitAnimations];
    }
}

- (void)resetContentOffset
{
    CGSize boundsSize = self.imageScrollView.bounds.size;
    CGRect frameToCenter = self.imageScrollView.zoomView.frame;
    
    CGPoint contentOffset;
    if (CGRectGetWidth(frameToCenter) > boundsSize.width) {
        contentOffset.x = (CGRectGetWidth(frameToCenter) - boundsSize.width) * 0.5f;
    } else {
        contentOffset.x = 0;
    }
    if (CGRectGetHeight(frameToCenter) > boundsSize.height) {
        contentOffset.y = (CGRectGetHeight(frameToCenter) - boundsSize.height) * 0.5f;
    } else {
        contentOffset.y = 0;
    }
    
    self.imageScrollView.contentOffset = contentOffset;
}

- (void)resetFrame
{
    [self layoutImageScrollView];
}

- (void)resetRotation
{
    [self setRotationAngle:0.0];
}

- (void)resetZoomScale
{
    CGFloat zoomScale;
    if (CGRectGetWidth(self.view.bounds) > CGRectGetHeight(self.view.bounds)) {
        zoomScale = CGRectGetHeight(self.view.bounds) / self.originalImage.size.height;
    } else {
        zoomScale = CGRectGetWidth(self.view.bounds) / self.originalImage.size.width;
    }
    self.imageScrollView.zoomScale = zoomScale;
}

- (NSArray *)intersectionPointsOfLineSegment:(RSKLineSegment)lineSegment withRect:(CGRect)rect
{
    RSKLineSegment top = RSKLineSegmentMake(CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect)),
                                            CGPointMake(CGRectGetMaxX(rect), CGRectGetMinY(rect)));
    
    RSKLineSegment right = RSKLineSegmentMake(CGPointMake(CGRectGetMaxX(rect), CGRectGetMinY(rect)),
                                              CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect)));
    
    RSKLineSegment bottom = RSKLineSegmentMake(CGPointMake(CGRectGetMinX(rect), CGRectGetMaxY(rect)),
                                               CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect)));
    
    RSKLineSegment left = RSKLineSegmentMake(CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect)),
                                             CGPointMake(CGRectGetMinX(rect), CGRectGetMaxY(rect)));
    
    CGPoint p0 = RSKLineSegmentIntersection(top, lineSegment);
    CGPoint p1 = RSKLineSegmentIntersection(right, lineSegment);
    CGPoint p2 = RSKLineSegmentIntersection(bottom, lineSegment);
    CGPoint p3 = RSKLineSegmentIntersection(left, lineSegment);
    
    NSMutableArray *intersectionPoints = [@[] mutableCopy];
    if (!RSKPointIsNull(p0)) {
        [intersectionPoints addObject:[NSValue valueWithCGPoint:p0]];
    }
    if (!RSKPointIsNull(p1)) {
        [intersectionPoints addObject:[NSValue valueWithCGPoint:p1]];
    }
    if (!RSKPointIsNull(p2)) {
        [intersectionPoints addObject:[NSValue valueWithCGPoint:p2]];
    }
    if (!RSKPointIsNull(p3)) {
        [intersectionPoints addObject:[NSValue valueWithCGPoint:p3]];
    }
    
    return [intersectionPoints copy];
}

- (void)displayImage
{
    if (self.originalImage) {
        [self.imageScrollView displayImage:self.originalImage];
        [self reset:NO];
    }
}

- (void)layoutImageScrollView
{
    CGRect frame = CGRectZero;
    
    // The bounds of the image scroll view should always fill the mask area.
    switch (self.cropMode) {
        case RSKImageCropModeSquare: {
            if (self.rotationAngle == 0.0) {
                frame = self.maskRect;
            } else {
                // Step 1: Rotate the left edge of the initial rect of the image scroll view clockwise around the center by `rotationAngle`.
                CGRect initialRect = self.maskRect;
                CGFloat rotationAngle = self.rotationAngle;
                
                CGPoint leftTopPoint = CGPointMake(initialRect.origin.x, initialRect.origin.y);
                CGPoint leftBottomPoint = CGPointMake(initialRect.origin.x, initialRect.origin.y + initialRect.size.height);
                RSKLineSegment leftLineSegment = RSKLineSegmentMake(leftTopPoint, leftBottomPoint);
                
                CGPoint pivot = RSKRectCenterPoint(initialRect);
                
                CGFloat alpha = fabs(rotationAngle);
                RSKLineSegment rotatedLeftLineSegment = RSKLineSegmentRotateAroundPoint(leftLineSegment, pivot, alpha);
                
                // Step 2: Find the points of intersection of the rotated edge with the initial rect.
                NSArray *points = [self intersectionPointsOfLineSegment:rotatedLeftLineSegment withRect:initialRect];
                
                // Step 3: If the number of intersection points more than one
                // then the bounds of the rotated image scroll view does not completely fill the mask area.
                // Therefore, we need to update the frame of the image scroll view.
                // Otherwise, we can use the initial rect.
                if (points.count > 1) {
                    // We have a right triangle.
                    
                    // Step 4: Calculate the altitude of the right triangle.
                    if ((alpha > M_PI_2) && (alpha < M_PI)) {
                        alpha = alpha - M_PI_2;
                    } else if ((alpha > (M_PI + M_PI_2)) && (alpha < (M_PI + M_PI))) {
                        alpha = alpha - (M_PI + M_PI_2);
                    }
                    CGFloat sinAlpha = sin(alpha);
                    CGFloat cosAlpha = cos(alpha);
                    CGFloat hypotenuse = RSKPointDistance([points[0] CGPointValue], [points[1] CGPointValue]);
                    CGFloat altitude = hypotenuse * sinAlpha * cosAlpha;
                    
                    // Step 5: Calculate the target width.
                    CGFloat initialWidth = CGRectGetWidth(initialRect);
                    CGFloat targetWidth = initialWidth + altitude * 2;
                    
                    // Step 6: Calculate the target frame.
                    CGFloat scale = targetWidth / initialWidth;
                    CGPoint center = RSKRectCenterPoint(initialRect);
                    frame = RSKRectScaleAroundPoint(initialRect, center, scale, scale);
                    
                    // Step 7: Avoid floats.
                    frame.origin.x = round(CGRectGetMinX(frame));
                    frame.origin.y = round(CGRectGetMinY(frame));
                    frame = CGRectIntegral(frame);
                } else {
                    // Step 4: Use the initial rect.
                    frame = initialRect;
                }
            }
            break;
        }
        case RSKImageCropModeCircle: {
            frame = self.maskRect;
            break;
        }
        case RSKImageCropModeCustom: {
            if ([self.dataSource respondsToSelector:@selector(imageCropViewControllerCustomMovementRect:)]) {
                frame = [self.dataSource imageCropViewControllerCustomMovementRect:self];
            } else {
                // Will be changed to `CGRectNull` in version `2.0.0`.
                frame = self.maskRect;
            }
            break;
        }
    }
    
    CGAffineTransform transform = self.imageScrollView.transform;
    self.imageScrollView.transform = CGAffineTransformIdentity;
    self.imageScrollView.frame = frame;
    self.imageScrollView.transform = transform;
}

- (void)layoutOverlayView
{
    CGRect frame = CGRectMake(0, 0, CGRectGetWidth(self.view.bounds) * 2, CGRectGetHeight(self.view.bounds) * 2);
    self.overlayView.frame = frame;
}

- (void)updateMaskRect
{
    switch (self.cropMode) {
        case RSKImageCropModeCircle: {
            CGFloat viewWidth = CGRectGetWidth(self.view.bounds);
            CGFloat viewHeight = CGRectGetHeight(self.view.bounds);
            
            CGFloat diameter;
            if ([self isPortraitInterfaceOrientation]) {
                diameter = MIN(viewWidth, viewHeight) - kPortraitCircleMaskRectInnerEdgeInset * 2;
            } else {
                diameter = MIN(viewWidth, viewHeight) - kLandscapeCircleMaskRectInnerEdgeInset * 2;
            }
            
            CGSize maskSize = CGSizeMake(diameter, diameter);
            
            self.maskRect = CGRectMake((viewWidth - maskSize.width) * 0.5f,
                                       (viewHeight - maskSize.height) * 0.5f,
                                       maskSize.width,
                                       maskSize.height);
            break;
        }
        case RSKImageCropModeSquare: {
            CGFloat viewWidth = CGRectGetWidth(self.view.bounds);
            CGFloat viewHeight = CGRectGetHeight(self.view.bounds);
            
            CGFloat length;
            if ([self isPortraitInterfaceOrientation]) {
                length = MIN(viewWidth, viewHeight) - kPortraitSquareMaskRectInnerEdgeInset * 2;
            } else {
                length = MIN(viewWidth, viewHeight) - kLandscapeSquareMaskRectInnerEdgeInset * 2;
            }
            
            CGSize maskSize = CGSizeMake(length, length);
            
            self.maskRect = CGRectMake((viewWidth - maskSize.width) * 0.5f,
                                       (viewHeight - maskSize.height) * 0.5f,
                                       maskSize.width,
                                       maskSize.height);
            
            _defaultx = self.maskRect.origin.x;
            _defaulty = self.maskRect.origin.y;
            
            break;
        }
        case RSKImageCropModeCustom: {
            self.maskRect = [self.dataSource imageCropViewControllerCustomMaskRect:self];
            break;
        }
    }
}

- (void)updateMaskPath
{
    switch (self.cropMode) {
        case RSKImageCropModeCircle: {
            self.maskPath = [UIBezierPath bezierPathWithOvalInRect:self.rectForMaskPath];
            break;
        }
        case RSKImageCropModeSquare: {
            self.maskPath = [UIBezierPath bezierPathWithRect:self.rectForMaskPath];
            break;
        }
        case RSKImageCropModeCustom: {
            self.maskPath = [self.dataSource imageCropViewControllerCustomMaskPath:self];
            break;
        }
    }
}

- (UIImage *)croppedImage:(UIImage *)image cropMode:(RSKImageCropMode)cropMode cropRect:(CGRect)cropRect rotationAngle:(CGFloat)rotationAngle zoomScale:(CGFloat)zoomScale maskPath:(UIBezierPath *)maskPath applyMaskToCroppedImage:(BOOL)applyMaskToCroppedImage
{
    // Step 1: check and correct the crop rect.
    CGSize imageSize = image.size;
    CGFloat x = CGRectGetMinX(cropRect);
    CGFloat y = CGRectGetMinY(cropRect);
    CGFloat width = CGRectGetWidth(cropRect);
    CGFloat height = CGRectGetHeight(cropRect);
    
    UIImageOrientation imageOrientation = image.imageOrientation;
    if (imageOrientation == UIImageOrientationRight || imageOrientation == UIImageOrientationRightMirrored) {
        cropRect.origin.x = y;
        cropRect.origin.y = round(imageSize.width - CGRectGetWidth(cropRect) - x);
        cropRect.size.width = height;
        cropRect.size.height = width;
    } else if (imageOrientation == UIImageOrientationLeft || imageOrientation == UIImageOrientationLeftMirrored) {
        cropRect.origin.x = round(imageSize.height - CGRectGetHeight(cropRect) - y);
        cropRect.origin.y = x;
        cropRect.size.width = height;
        cropRect.size.height = width;
    } else if (imageOrientation == UIImageOrientationDown || imageOrientation == UIImageOrientationDownMirrored) {
        cropRect.origin.x = round(imageSize.width - CGRectGetWidth(cropRect) - x);
        cropRect.origin.y = round(imageSize.height - CGRectGetHeight(cropRect) - y);
    }
    
    CGFloat imageScale = image.scale;
    cropRect = CGRectApplyAffineTransform(cropRect, CGAffineTransformMakeScale(imageScale, imageScale));
    
    // Step 2: create an image using the data contained within the specified rect.
    CGImageRef croppedCGImage = CGImageCreateWithImageInRect(image.CGImage, cropRect);
    UIImage *croppedImage = [UIImage imageWithCGImage:croppedCGImage scale:imageScale orientation:imageOrientation];
    CGImageRelease(croppedCGImage);
    
    // Step 3: fix orientation of the cropped image.
    croppedImage = [croppedImage fixOrientation];
    imageOrientation = croppedImage.imageOrientation;
    
    // Step 4: If current mode is `RSKImageCropModeSquare` and the image is not rotated
    // or mask should not be applied to the image after cropping and the image is not rotated,
    // we can return the cropped image immediately.
    // Otherwise, we must further process the image.
    if ((cropMode == RSKImageCropModeSquare || !applyMaskToCroppedImage) && rotationAngle == 0.0) {
        // Step 5: return the cropped image immediately.
        return croppedImage;
    } else {
        // Step 5: create a new context.
        CGSize maskSize = CGRectIntegral(maskPath.bounds).size;
        CGSize contextSize = CGSizeMake(ceil(maskSize.width / zoomScale),
                                        ceil(maskSize.height / zoomScale));
        UIGraphicsBeginImageContextWithOptions(contextSize, NO, imageScale);
        
        // Step 6: apply the mask if needed.
        if (applyMaskToCroppedImage) {
            // 6a: scale the mask to the size of the crop rect.
            UIBezierPath *maskPathCopy = [maskPath copy];
            CGFloat scale = 1 / zoomScale;
            [maskPathCopy applyTransform:CGAffineTransformMakeScale(scale, scale)];
            
            // 6b: move the mask to the top-left.
            CGPoint translation = CGPointMake(-CGRectGetMinX(maskPathCopy.bounds),
                                              -CGRectGetMinY(maskPathCopy.bounds));
            [maskPathCopy applyTransform:CGAffineTransformMakeTranslation(translation.x, translation.y)];
            
            // 6c: apply the mask.
            [maskPathCopy addClip];
        }
        
        // Step 7: rotate the cropped image if needed.
        if (rotationAngle != 0) {
            croppedImage = [croppedImage rotateByAngle:rotationAngle];
        }
        
        // Step 8: draw the cropped image.
        CGPoint point = CGPointMake(round((contextSize.width - croppedImage.size.width) * 0.5f),
                                    round((contextSize.height - croppedImage.size.height) * 0.5f));
        [croppedImage drawAtPoint:point];
        
        // Step 9: get the cropped image affter processing from the context.
        croppedImage = UIGraphicsGetImageFromCurrentImageContext();
        
        // Step 10: remove the context.
        UIGraphicsEndImageContext();
        
        croppedImage = [UIImage imageWithCGImage:croppedImage.CGImage scale:imageScale orientation:imageOrientation];
        
        // Step 11: return the cropped image affter processing.
        return croppedImage;
    }
}

- (void)cropImage
{
    if ([self.delegate respondsToSelector:@selector(imageCropViewController:willCropImage:)]) {
        [self.delegate imageCropViewController:self willCropImage:self.originalImage];
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        CGRect cropRect = self.cropRect;
        CGFloat rotationAngle = self.rotationAngle;
        
        UIImage *croppedImage = [self croppedImage:self.originalImage cropMode:self.cropMode cropRect:cropRect rotationAngle:rotationAngle zoomScale:self.imageScrollView.zoomScale maskPath:self.maskPath applyMaskToCroppedImage:self.applyMaskToCroppedImage];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(imageCropViewController:didCropImage:usingCropRect:rotationAngle:)]) {
                [self.delegate imageCropViewController:self didCropImage:croppedImage usingCropRect:cropRect rotationAngle:rotationAngle];
            } else if ([self.delegate respondsToSelector:@selector(imageCropViewController:didCropImage:usingCropRect:)]) {
                [self.delegate imageCropViewController:self didCropImage:croppedImage usingCropRect:cropRect];
            }
        });
    });
}

- (void)cancelCrop
{
    if ([self.delegate respondsToSelector:@selector(imageCropViewControllerDidCancelCrop:)]) {
        [self.delegate imageCropViewControllerDidCancelCrop:self];
    }
}

-(void)setDragable {
    [self.view addSubview:self.leftTop];
    [self.view addSubview:self.rightTop];
    [self.view addSubview:self.leftBottom];
    [self.view addSubview:self.rightBottom];
    [self.view addSubview:self.lineLeft];
    [self.view addSubview:self.lineTop];
    [self.view addSubview:self.lineRight];
    [self.view addSubview:self.lineBottom];
    [self resetLineBounds:nil];
}

-(CGRect)TheRect {
    return self.maskRect;
}

-(UIView*)lineLeft{
    if (!_lineLeft) {
        _lineLeft = [[UIView alloc]init];
        _lineLeft.bounds = CGRectMake(0, 0, 25, 25);
        _lineLeft.center = CGPointMake(_leftTop.center.x, _leftTop.center.y + (_leftBottom.center.y - _leftTop.center.y)/2);
//        _lineLeft.backgroundColor = [UIColor greenColor];
        _lineLeft.tag = 1;//左右线为1 用于不改变移动时的Y
        
        UISelfPanGestureRecognizer *lineGesture = [[UISelfPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleLinePan:)];
        [_lineLeft setUserInteractionEnabled:YES];
        [lineGesture setTransview:self.view];
        [_lineLeft addGestureRecognizer:lineGesture];
        
    }
    return _lineLeft;
}

-(UIView*)lineTop{
    if (!_lineTop) {
        _lineTop = [[UIView alloc]init];
        _lineTop.bounds = CGRectMake(0, 0, 25, 25);
        _lineTop.center = CGPointMake(_leftTop.center.x + (_rightTop.center.x - _leftTop.center.x)/2,_leftTop.center.y);
//        _lineTop.backgroundColor = [UIColor blueColor];
        _lineTop.tag = 2;//上下线为2 用于不改变移动时的x
        UISelfPanGestureRecognizer *lineGesture = [[UISelfPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleLinePan:)];
        [_lineTop setUserInteractionEnabled:YES];
        [lineGesture setTransview:self.view];
        [_lineTop addGestureRecognizer:lineGesture];
    }
    return _lineTop;
}

-(UIView*)lineRight{
    if (!_lineRight) {
        _lineRight = [[UIView alloc]init];
        _lineRight.bounds = CGRectMake(0, 0, 25, 25);
        _lineRight.center = CGPointMake(_rightTop.center.x, _rightTop.center.y + (_rightBottom.center.y - _rightTop.center.y)/2);
//        _lineRight.backgroundColor = [UIColor blackColor];
        _lineRight.tag = 1;
        UISelfPanGestureRecognizer *lineGesture = [[UISelfPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleLinePan:)];
        [_lineRight setUserInteractionEnabled:YES];
        [lineGesture setTransview:self.view];
        [_lineRight addGestureRecognizer:lineGesture];
    }
    return _lineRight;
}

-(UIView*)lineBottom{
    if (!_lineBottom) {
        _lineBottom = [[UIView alloc]init];
        _lineBottom.bounds = CGRectMake(0, 0, 25, 25);
        _lineBottom.center = CGPointMake(_leftBottom.center.x + (_rightBottom.center.x - _leftBottom.center.x)/2, _leftBottom.center.y);
//        _lineBottom.backgroundColor = [UIColor whiteColor];
        _lineBottom.tag = 2;
        UISelfPanGestureRecognizer *lineGesture = [[UISelfPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleLinePan:)];
        [_lineBottom setUserInteractionEnabled:YES];
        [lineGesture setTransview:self.view];
        [_lineBottom addGestureRecognizer:lineGesture];
    }
    return _lineBottom;
}

-(void)handleLinePan:(UISelfPanGestureRecognizer*)pan {

    CGPoint point = [pan translationPoint];
    
    CGPoint finalpoint = CGPointMake(0, 0);
    
    if (pan.view.tag == 1) {//左右线
        finalpoint = CGPointMake(pan.view.center.x + point.x, pan.view.center.y);
    }
    else {
        finalpoint = CGPointMake(pan.view.center.x, pan.view.center.y + point.y );
    }
    
    if (pan.view == _lineLeft) {
        if ((finalpoint.x - 0) < _minEdgeWidth) {
            finalpoint = CGPointMake(0 + _minEdgeWidth, pan.view.center.y);
        }
        else if ((_lineRight.center.x - finalpoint.x) < _minPicWidth) {
            finalpoint = CGPointMake(_lineRight.center.x - _minPicWidth, pan.view.center.y);
        }
    }
    else if (pan.view == _lineRight) {
        if ((self.view.bounds.size.width - finalpoint.x) < _minEdgeWidth) {
            finalpoint = CGPointMake(self.view.bounds.size.width - _minEdgeWidth, pan.view.center.y);
        }
        else if ((finalpoint.x - _lineLeft.center.x) < _minPicWidth) {
            finalpoint = CGPointMake(_lineLeft.center.x + _minPicWidth, pan.view.center.y);
        }
    }
    else if (pan.view == _lineTop) {
        if ((finalpoint.y - 0) < _minEdgeHight) {
            finalpoint = CGPointMake(pan.view.center.x, _minEdgeHight);
        }
        else if ((_lineBottom.center.y - finalpoint.y) < _minPicWidth) {
            finalpoint = CGPointMake(pan.view.center.x , _lineBottom.center.y - _minPicWidth );
        }
    }
    else if (pan.view == _lineBottom) {
        if ((self.view.bounds.size.height - finalpoint.y) < _minEdgeHight) {
            finalpoint = CGPointMake(pan.view.center.x, self.view.bounds.size.height - _minEdgeHight);
        }
        else if ((finalpoint.y - _lineTop.center.y) < _minPicHight) {
            finalpoint = CGPointMake(pan.view.center.x , _lineTop.center.y + _minPicHight );
        }
    }
    
    pan.view.center = finalpoint;
    
    [self FollowMe:pan.view];
    [self resetLineBounds:pan.view];
    [self resetMaskView];
}

-(void)resetLineBounds:(UIView*)movingView {
    if (movingView != _lineLeft) {
        _lineLeft.bounds = CGRectMake(0, 0, 25, _leftBottom.center.y - _leftTop.center.y -25);
        _lineLeft.center = CGPointMake(_leftTop.center.x, _leftTop.center.y + (_leftBottom.center.y - _leftTop.center.y)/2);
    }
    if (movingView != _lineTop) {
        _lineTop.bounds = CGRectMake(0, 0, _rightTop.center.x - _leftTop.center.x  - 25, 25);
        _lineTop.center = CGPointMake(_leftTop.center.x + (_rightTop.center.x - _leftTop.center.x)/2,_leftTop.center.y);
    }
    
    if (movingView != _lineRight) {
        _lineRight.bounds = CGRectMake(0, 0, 25, _rightBottom.center.y - _rightTop.center.y - 25);
        _lineRight.center = CGPointMake(_rightTop.center.x, _rightTop.center.y + (_rightBottom.center.y - _rightTop.center.y)/2);
    }
    
    if (movingView != _lineBottom) {
        _lineBottom.bounds = CGRectMake(0, 0, _rightBottom.center.x - _leftBottom.center.x - 25, 25);
        _lineBottom.center = CGPointMake(_leftBottom.center.x + (_rightBottom.center.x - _leftBottom.center.x)/2, _leftBottom.center.y);
    }
    
}

-(void)setRoundMask:(UIView*)theView {
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(5, 5, 5, 5) byRoundingCorners:UIRectCornerAllCorners cornerRadii:CGSizeMake(2,2)];
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    maskLayer.frame = maskPath.bounds;
    maskLayer.path = maskPath.CGPath;
    
    theView.layer.mask = maskLayer;
}

-(UIView*)leftTop{
    if (!_leftTop) {
        _leftTop = [[UIView alloc]init];
        _leftTop.bounds = CGRectMake(0, 0, 25, 25);
        _leftTop.center = CGPointMake(MyPointRect.origin.x, MyPointRect.origin.y);
        UISelfPanGestureRecognizer *pointGesture = [[UISelfPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePointPan:)];
        [_leftTop setUserInteractionEnabled:YES];
        [pointGesture setTransview:self.view];
        [_leftTop addGestureRecognizer:pointGesture];
        _leftTop.backgroundColor = [UIColor whiteColor];
        [_leftTop setAlpha:0.6];
        [self setRoundMask:_leftTop];
    }
    return _leftTop;
}

-(UIView*)rightTop{
    if (!_rightTop) {
        _rightTop = [[UIView alloc]init];
        _rightTop.bounds = CGRectMake(0, 0, 25, 25);
        _rightTop.center = CGPointMake(MyPointRect.origin.x + MyPointRect.size.width, MyPointRect.origin.y);
        UISelfPanGestureRecognizer *pointGesture = [[UISelfPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePointPan:)];
        [_rightTop setUserInteractionEnabled:YES];
        [pointGesture setTransview:self.view];
        [_rightTop addGestureRecognizer:pointGesture];
        
        _rightTop.backgroundColor = [UIColor whiteColor];
        [_rightTop setAlpha:0.6];
        [self setRoundMask:_rightTop];

    }
    return _rightTop;
}

-(UIView*)rightBottom{
    if (!_rightBottom) {
        _rightBottom = [[UIView alloc]init];
        _rightBottom.bounds = CGRectMake(0, 0, 25, 25);
        _rightBottom.center = CGPointMake(MyPointRect.origin.x + MyPointRect.size.width, MyPointRect.origin.y + MyPointRect.size.height);
        UISelfPanGestureRecognizer *pointGesture = [[UISelfPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePointPan:)];
        [_rightBottom setUserInteractionEnabled:YES];
        [pointGesture setTransview:self.view];
        [_rightBottom addGestureRecognizer:pointGesture];
        
        _rightBottom.backgroundColor = [UIColor whiteColor];
        [_rightBottom setAlpha:0.6];
        [self setRoundMask:_rightBottom];
    }
    return _rightBottom;
}

-(UIView*)leftBottom{
    if (!_leftBottom) {
        _leftBottom = [[UIView alloc]init];
        _leftBottom.bounds = CGRectMake(0, 0, 25, 25);
        _leftBottom.center = CGPointMake(MyPointRect.origin.x, MyPointRect.origin.y + MyPointRect.size.height);
        UISelfPanGestureRecognizer *pointGesture = [[UISelfPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePointPan:)];
        [_leftBottom setUserInteractionEnabled:YES];
        [pointGesture setTransview:self.view];
        [_leftBottom addGestureRecognizer:pointGesture];
        
        _leftBottom.backgroundColor = [UIColor whiteColor];
        [_leftBottom setAlpha:0.6];
        [self setRoundMask:_leftBottom];
    }
    return _leftBottom;
}

-(void)handlePointPan:(UISelfPanGestureRecognizer*)pan {

    CGPoint point = [pan translationPoint];

    CGPoint touchfinalpoint = CGPointMake(pan.view.center.x + point.x, pan.view.center.y + point.y);

    CGPoint point1 = CGPointMake(0, 0);
    CGPoint point2 = CGPointMake(0, 0);

    if (pan.state == UIGestureRecognizerStateBegan) {
        if ((pan.view == _leftTop) || (pan.view == _rightBottom)) {
            point1 = _leftTop.center;
            point2 = _rightBottom.center;
        }
        else if((pan.view == _leftBottom) || (pan.view == _rightTop)) {
            point1 = _leftBottom.center;
            point2 = _rightTop.center;
        }
        _cornerLineK = (point1.y - point2.y)/(point1.x - point2.x);
        _cornerLineB = ((point1.x * point2.y) - (point2.x * point1.y))/(point1.x - point2.x);
    }
    
    _cornerLineB2 = touchfinalpoint.y + _cornerLineK * touchfinalpoint.x;
    CGFloat finaly = (_cornerLineB + _cornerLineB2)/2;
    CGFloat finalx = (finaly - _cornerLineB)/_cornerLineK;
    CGPoint finalpoint = CGPointMake( (finaly - _cornerLineB)/_cornerLineK, finaly);
    
    if (pan.view == _leftTop) {
        if ((finalpoint.x - 0)<_minEdgeWidth) {
            finalx = _minEdgeWidth;
            finalpoint = CGPointMake(finalx, finalx*_cornerLineK + _cornerLineB);
        }
        else if((finalpoint.y - 0)< _minEdgeHight) {
            finaly = _minEdgeHight;
            finalpoint = CGPointMake((finaly - _cornerLineB)/_cornerLineK, finaly);
        }
        else if((_leftBottom.center.y - finaly)<_minPicHight) {
            finaly = _leftBottom.center.y - _minPicHight;
            finalpoint = CGPointMake((finaly - _cornerLineB)/_cornerLineK, finaly);
        }
        else if ((_rightTop.center.x - finalx)<_minPicWidth) {
            finalx = _rightTop.center.x - _minPicWidth;
            finalpoint = CGPointMake(finalx, finalx*_cornerLineK + _cornerLineB);
        }
    }
    else if (pan.view == _rightTop) {
        if ((finalx - _leftTop.center.x) < _minPicWidth) {
            finalx = _minPicWidth + _leftTop.center.x;
            finalpoint = CGPointMake(finalx, finalx*_cornerLineK + _cornerLineB);
        }
        else if ((finaly - 0)<_minEdgeHight) {
            finaly = _minEdgeHight;
            finalpoint = CGPointMake((finaly - _cornerLineB)/_cornerLineK, finaly);
        }
        else if ((self.view.bounds.size.width - finalx)<_minEdgeWidth) {
            finalx = self.view.bounds.size.width - _minEdgeWidth;
            finalpoint = CGPointMake(finalx, finalx*_cornerLineK + _cornerLineB);
        }
        else if ((_rightBottom.center.y - finaly)<_minPicHight) {
            finaly = _rightBottom.center.y - _minPicHight;
            finalpoint = CGPointMake((finaly - _cornerLineB)/_cornerLineK, finaly);
        }
    }
    else if (pan.view == _leftBottom) {
        if ((finalpoint.x - 0)<_minEdgeWidth) {
            finalx = _minEdgeWidth;
            finalpoint = CGPointMake(finalx, finalx*_cornerLineK + _cornerLineB);
        }
        else if ((finaly - _leftTop.center.y)<_minPicHight) {
            finaly = _minPicHight + _leftTop.center.y;
            finalpoint = CGPointMake((finaly - _cornerLineB)/_cornerLineK, finaly);
        }
        else if ((_rightBottom.center.x - finalx)<_minPicWidth) {
            finalx = _rightBottom.center.x - _minPicWidth;
            finalpoint = CGPointMake(finalx, finalx*_cornerLineK + _cornerLineB);
        }
        else if ((self.view.bounds.size.height - finaly)<_minPicHight) {
            finaly = self.view.bounds.size.height - _minPicHight;
            finalpoint = CGPointMake((finaly - _cornerLineB)/_cornerLineK, finaly);
        }
    }
    else if (pan.view == _rightBottom) {
        if ((finalx - _leftBottom.center.x)<_minPicWidth) {
            finalx = _minPicWidth + _leftBottom.center.x;
            finalpoint = CGPointMake(finalx, finalx*_cornerLineK + _cornerLineB);
        }
        else if ((finaly - _rightTop.center.y)<_minPicHight) {
            finaly = _minPicHight + _rightTop.center.y;
            finalpoint = CGPointMake((finaly - _cornerLineB)/_cornerLineK, finaly);
        }
        else if ((self.view.bounds.size.width - finalx)<_minEdgeWidth) {
            finalx = self.view.bounds.size.width - _minEdgeWidth;
            finalpoint = CGPointMake(finalx, finalx*_cornerLineK + _cornerLineB);
        }
        else if ((self.view.bounds.size.height - finaly)<_minEdgeHight) {
            finaly = self.view.bounds.size.height - _minEdgeHight;
            finalpoint = CGPointMake((finaly - _cornerLineB)/_cornerLineK, finaly);
        }
    }
    
    pan.view.center = finalpoint;
    
    [self FollowMe:pan.view];
    [self resetLineBounds:nil];
    [self resetMaskView];
}

-(void)FollowMe:(UIView*)point{
    
    if (point == _leftTop) {
        _rightTop.center = CGPointMake(_rightTop.center.x, _leftTop.center.y);
        _leftBottom.center = CGPointMake(_leftTop.center.x, _leftBottom.center.y);
    }
    else if (point == _rightTop){
        _leftTop.center = CGPointMake(_leftTop.center.x, _rightTop.center.y);
        _rightBottom.center = CGPointMake(_rightTop.center.x, _rightBottom.center.y);
    }
    else if (point == _leftBottom){
        _leftTop.center = CGPointMake(_leftBottom.center.x, _leftTop.center.y);
        _rightBottom.center = CGPointMake(_rightBottom.center.x, _leftBottom.center.y);
    }
    else if (point == _rightBottom){
        _leftBottom.center = CGPointMake(_leftBottom.center.x, _rightBottom.center.y);
        _rightTop.center = CGPointMake(_rightBottom.center.x, _rightTop.center.y);
    }
    else if (point == _lineLeft){
        _leftTop.center = CGPointMake(_lineLeft.center.x, _leftTop.center.y);
        _leftBottom.center = CGPointMake(_lineLeft.center.x, _leftBottom.center.y);
    }
    else if (point == _lineTop){
        _leftTop.center = CGPointMake(_leftTop.center.x, _lineTop.center.y);
        _rightTop.center = CGPointMake(_rightTop.center.x, _lineTop.center.y);
    }
    else if (point == _lineRight){
        _rightTop.center = CGPointMake(_lineRight.center.x, _rightTop.center.y);
        _rightBottom.center = CGPointMake(_lineRight.center.x, _rightBottom.center.y);
    }
    else if (point == _lineBottom){
        _leftBottom.center = CGPointMake(_leftBottom.center.x, _lineBottom.center.y);
        _rightBottom.center = CGPointMake(_rightBottom.center.x, _lineBottom.center.y);
    }
}

-(void)resetMaskView {
    self.maskRect = CGRectMake(_leftTop.center.x, _leftTop.center.y, _rightBottom.center.x - _leftTop.center.x, _rightBottom.center.y - _leftTop.center.y);
    
    CGRect rect = self.maskRect;
    
    CGPoint point1 = CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect));
    
    CGPoint point2 = CGPointMake(CGRectGetMaxX(rect), CGRectGetMinY(rect));
    
    CGPoint point3 = CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect));
    
    CGPoint point4 = CGPointMake(CGRectGetMinX(rect), CGRectGetMaxY(rect));
    
    
    
    UIBezierPath *rectangle = [UIBezierPath bezierPath];
    
    [rectangle moveToPoint:point1];
    
    [rectangle addLineToPoint:point2];
    
    [rectangle addLineToPoint:point3];
    
    [rectangle addLineToPoint:point4];
    
    [rectangle closePath];
    
    self.maskPath = rectangle;
}


#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

@end
