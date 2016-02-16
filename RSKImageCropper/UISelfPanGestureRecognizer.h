//
//  UISelfPanGestureRecognizer.h
//  RSKImageCropperExample
//
//  Created by cwwqq on 16/2/14.
//  Copyright © 2016年 Ruslan Skorb. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <UIKit/UIGestureRecognizerSubclass.h>
@interface UISelfPanGestureRecognizer : UIGestureRecognizer
-(void)setTransview:(UIView*)view;
-(CGPoint)translationPoint;
@end
