//
//  ViewController.m
//  Vanessa
//
//  Created by Aron Steg on 12/6/13.
//  Copyright (c) 2013 Electric Imp. All rights reserved.
//

#import "ViewController.h"
#import "UIImage+Resize.h"

#define AGENT_ID @"7s_PSI9NXZ7c"
//#define HEIGHT 240
//#define WIDTH  400
//#define HEIGHT 96
//#define WIDTH  96
#define HEIGHT 176
#define WIDTH  264

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIButton *Default;
@property (weak, nonatomic) IBOutlet UIButton *Load;
@property (weak, nonatomic) IBOutlet UIButton *Shoot;
@property (weak, nonatomic) IBOutlet UIButton *Send;
@property (weak, nonatomic) IBOutlet UIButton *Dither;
@property (weak, nonatomic) IBOutlet UIImageView* imageView;
@end


@implementation ViewController

@synthesize Default;
@synthesize Load;
@synthesize Shoot;
@synthesize Send;
@synthesize Dither;
@synthesize imageView;


- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)DefaultButtonClick:(id)sender
{
    imageView.image = [UIImage imageNamed:@"lena"];
}

- (IBAction)ShootButtonClick:(id)sender
{
    UIImagePickerController *pickerLibrary = [[UIImagePickerController alloc] init];
    if (sender == Load) {
        pickerLibrary.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    } else {
        pickerLibrary.sourceType = UIImagePickerControllerSourceTypeCamera;
    }
    pickerLibrary.delegate = self;
    [self presentViewController:pickerLibrary animated:YES completion:nil];
}

- (void) imagePickerController:(UIImagePickerController *)picker
         didFinishPickingImage:(UIImage *)image
                   editingInfo:(NSDictionary *)editingInfo
{
    imageView.image = image;
    [self dismissModalViewControllerAnimated:YES];
}

- (IBAction)DitherButtonClick:(id)sender
{
    NSUInteger width = WIDTH;
    NSUInteger height = HEIGHT;
    NSUInteger area = height * width;
    
    // Resize the image
    UIImage *resized = [imageView.image resizedImageWithContentMode:UIViewContentModeScaleAspectFit
                                                             bounds:CGSizeMake(width, height)
                                               interpolationQuality:kCGInterpolationHigh];
    
    // Get the image into your data buffer
    CGImageRef imageRef = [resized CGImage];
    NSUInteger iwidth = CGImageGetWidth(imageRef);
    NSUInteger iheight = CGImageGetHeight(imageRef);
    NSUInteger iwoffset = (width>iwidth) ? (width-iwidth)/2 : 0;
    NSUInteger ihoffset = (height>iheight) ? (height-iheight)/2 : 0;
    NSLog(@"area %lu,%lu = offset %lu,%lu", (unsigned long)iheight, (unsigned long)iwidth, (unsigned long)ihoffset, (unsigned long)iwoffset);
    
    // Now rawData contains the image data in the RGBA8888 pixel format
    // and greyData contains the luminance levels (signed integers to allow for negative errors)
    unsigned char *rawData = (unsigned char*) calloc(area * 4, sizeof(unsigned char));
    NSInteger *greyData = (NSInteger *) calloc(area, sizeof(NSInteger));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    CGContextRef context = CGBitmapContextCreate(rawData, width, height,
                                                 bitsPerComponent, bytesPerRow, colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextFillRect(context, CGRectMake(0, 0, width, height));
    CGContextDrawImage(context, CGRectMake(iwoffset, ihoffset, iwidth, iheight), imageRef);
    CGContextRelease(context);
    
    // Fill out the luminance levels into greyData
    for (int ii = 0, i = 0; ii < area * 4; ii += 4, i++)
    {
        CGFloat red   = rawData[ii + 0];
        CGFloat green = rawData[ii + 1];
        CGFloat blue  = rawData[ii + 2];
        greyData[i] = (red * 0.3) + (green * 0.59) + (blue * 0.11);
    }
    
    // Now we need to dither the grey pixels using Atkinson's technique
    for (int ii = 0, i = 0; ii < area * 4; ii += 4, i++)
    {
        // Threshold the pixels and forward the errors
        NSInteger newPixel = greyData[i] < 110 ? 0 : 255;
        NSInteger err      = (NSInteger) floor( (greyData[i] - newPixel) / 8 );
        
        if (i + 0*width + 0 < area) greyData[i + 0*width + 0]  = newPixel;
        if (i + 0*width + 1 < area) greyData[i + 0*width + 1] += err;
        if (i + 0*width + 2 < area) greyData[i + 0*width + 2] += err;
        
        if (i + 1*width - 1 < area) greyData[i + 1*width - 1] += err;
        if (i + 1*width + 0 < area) greyData[i + 1*width + 0] += err;
        if (i + 1*width + 1 < area) greyData[i + 1*width + 1] += err;
        
        if (i + 2*width + 0 < area) greyData[i + 2*width + 0] += err;
        
        // Also write the same data back to the original image
        rawData[ii+0] = rawData[ii+1] = rawData[ii+2] = (unsigned char) newPixel;
        
    }
    
    // All done, update the display
    imageView.image = [self imageWithBytes:rawData size:CGSizeMake(width, height)];
    
    // And free some memory allocations
    free(greyData);
    free(rawData);
}

- (IBAction)SendButtonClick:(id)sender
{

    CGSize newSize = CGSizeMake(WIDTH, HEIGHT);
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 1.0);
    [self.imageView.image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    CGDataProviderRef provider = CGImageGetDataProvider(newImage.CGImage);
    NSData* data = (id)CFBridgingRelease(CGDataProviderCopyData(provider));
    const int height = (int) newImage.size.height; // 176
    const int width = (int) newImage.size.width;   // 264
    NSLog(@"Image height = %d, width = %d, bytes = %lu", height, width, (unsigned long)data.length);

    // Prepare the bitmap file
    uint8_t wif[(height * width) / 8 + 4];
    int wif_i = 0;
    
    
    wif[wif_i++] = (height & 0xFF);
    wif[wif_i++] = ((height >> 8) & 0xFF);
    wif[wif_i++] = (width & 0xFF);
    wif[wif_i++] = ((width >> 8) & 0xFF);
    
    uint8_t byte = 0x0;
    uint8_t bit_i = 0;
    
    const uint8_t* bytes = [data bytes];
    for (int i = 0; i < [data length]; i += 4) {
        uint8_t r = bytes[i+0];
        uint8_t g = bytes[i+1];
        uint8_t b = bytes[i+2];
        // uint8_t a = bytes[i+3];
        
        bool bit = ((r + g + b) < 500);
        byte |= bit << bit_i;
        
        bit_i++;
        if (bit_i == 8) {
            wif[wif_i++] = byte;
            
            byte = 0x0;
            bit_i = 0;
        }
        
        if (wif_i == sizeof(wif)) break;
    }
    
    // Send the bitmap file to the agent
    NSLog(@"%lu, %lu, %d", (unsigned long)[data length], sizeof(wif), wif_i);
    NSData *postData = [NSData dataWithBytes:(const void *) wif length:sizeof(wif)];
    NSString *agenturl = [NSString stringWithFormat:@"https://agent.electricimp.com/%@/WIFimage", AGENT_ID];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:agenturl]];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:postData];
    
    // Fire
    NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:nil];
    if (!conn) {
        NSLog(@"Connection could not be made to %@", agenturl);
    } else {
        NSLog(@"POSTed %lu bytes to %@", (unsigned long)postData.length, agenturl);
    }
    
}


- (UIImage*)imageWithBytes:(unsigned char*)data size:(CGSize)size
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    if (colorSpace == NULL) {
        NSLog(@"Could not create color space");
        return nil;
    }
    
    CGContextRef context = CGBitmapContextCreate(data, size.width, size.height, 8, size.width * 4, colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    
    CGColorSpaceRelease(colorSpace);
    if (context == NULL) {
        NSLog(@"Could not create context");
        return nil;
    }
    
    CGImageRef ref = CGBitmapContextCreateImage(context);
    if (ref == NULL) {
        NSLog(@"Could not create image");
        return nil;
    }
    
    CGContextRelease(context);
    
    UIImage* image = [UIImage imageWithCGImage:ref];
    CFRelease(ref);
    
    return image;
}

@end
