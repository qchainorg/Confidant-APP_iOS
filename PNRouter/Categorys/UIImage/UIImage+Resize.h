// UIImage+Resize.h
// Created by Trevor Harmon on 8/5/09.
// Free for personal or commercial use, with or without modification.
// No warranty is expressed or implied.

// Extends the UIImage class to support resizing/cropping
#import <UIKit/UIKit.h>

#define kImageMaxSize   CGSizeMake(200, 200)

@interface UIImage (Resize)
- (UIImage *)croppedImage:(CGRect)bounds;
- (UIImage *)thumbnailImage:(NSInteger)thumbnailSize
          transparentBorder:(NSUInteger)borderSize
               cornerRadius:(NSUInteger)cornerRadius
       interpolationQuality:(CGInterpolationQuality)quality;
- (UIImage *)resizedImage:(CGSize)newSize
     interpolationQuality:(CGInterpolationQuality)quality;
- (UIImage *)resizedImageWithContentMode:(UIViewContentMode)contentMode
                                  bounds:(CGSize)bounds
                    interpolationQuality:(CGInterpolationQuality)quality;

- (NSData *)compressJPGImage:(UIImage *)image toMaxFileSize:(NSInteger)maxFileSize;
- (NSData *)compressPNGImage:(UIImage *)image toMaxFileSize:(NSInteger)maxFileSize;

- (UIImage *)resizeImage:(UIImage *)image;

-(NSData *)compressWithMaxLength:(NSUInteger)maxLength;
@end
