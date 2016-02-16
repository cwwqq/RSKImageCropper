//
//  UISelfPanGestureRecognizer.m
//  RSKImageCropperExample
//
//  Created by cwwqq on 16/2/14.
//  Copyright © 2016年 Ruslan Skorb. All rights reserved.
//

#import "UISelfPanGestureRecognizer.h"

@implementation UISelfPanGestureRecognizer {
    CGPoint originPoint;
    CGPoint targetPoint;
    CGPoint transPoint;
    UIView* transview;
}

-(void)setTransview:(UIView*)view{
    transview = view;
}

-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    if (touches.count != 1) {
        self.state = UIGestureRecognizerStateFailed;
    }

    UITouch *touch=[touches anyObject];
    originPoint = [touch locationInView:transview];
    
    self.state = UIGestureRecognizerStateBegan;
}

-(void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    self.state = UIGestureRecognizerStateEnded;
}

-(void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
    
    if (self.state == UIGestureRecognizerStateFailed) {
        return;
    }
    
    UITouch *touch=[touches anyObject];
    targetPoint = [touch locationInView:transview];
    
    transPoint = CGPointMake(targetPoint.x - originPoint.x, targetPoint.y - originPoint.y);
    originPoint = targetPoint;
    
    self.state = UIGestureRecognizerStateChanged;
}

-(CGPoint)translationPoint {
    return transPoint;
}

@end
