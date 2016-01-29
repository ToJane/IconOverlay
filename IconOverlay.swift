//
//  IconOverlay.swift
//
//  Created by Julián Romero on 16/11/15.
//  Copyright © 2015 Julián Romero. All rights reserved.
//
import Foundation
import Cocoa
import Darwin

enum ExitCode : Int32 {
    case OK = 0
    case WrongNumberOfArguments
    case SourceImageNotValid
    case CouldNotWriteImage
    case InvalidBackgroundColor
}

extension NSColor {
    /// - returns: A color from its #RRGGBBAA string. Leadin # is optional.
    class func fromHexColor(hexColor: String) -> NSColor? {
        guard hexColor.characters.count >= 8 else {
            return nil
        }
        let skip = hexColor[hexColor.startIndex] == "#" ? 1 : 0
        guard let hexString: String = hexColor.substringFromIndex(hexColor.startIndex.advancedBy(skip)),
            var value: UInt32 = 0
            where hexString.characters.count == 8 && NSScanner(string: hexString).scanHexInt(&value) else {
                return nil
        }
        
        let red   = CGFloat((value & 0xFF000000) >> 24) / 255.0
        let green = CGFloat((value & 0x00FF0000) >> 16) / 255.0
        let blue  = CGFloat((value & 0x0000FF00) >>  8) / 255.0
        let alpha = CGFloat((value & 0x000000FF)      ) / 255.0
        return NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }
}

extension NSImage
{
    func unscaledBitmapImageRep() -> NSBitmapImageRep {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: NSDeviceRGBColorSpace,
            bytesPerRow: 0,
            bitsPerPixel: 0
            ) else {
                preconditionFailure()
        }
        
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.setCurrentContext(NSGraphicsContext(bitmapImageRep: rep))
        self.drawAtPoint(NSZeroPoint, fromRect: NSZeroRect, operation: .CompositeSourceOver, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()
        
        return rep
    }
    
    func asPNG() -> NSData? {
        let bitmap = unscaledBitmapImageRep()
        guard let pngData = bitmap.representationUsingType(.NSPNGFileType, properties: [String:AnyObject]()) else {
            return nil
        }
        return pngData
    }
}

func fontWithSize(size:CGFloat) -> NSFont {
    return NSFont(name:"Helvetica", size: size)!
}

// calculate a font size that fits the label in the image
func labelWidth(label : String, let withAttributes attributes: [String:AnyObject], toFit width:CGFloat) -> (fontSize:CGFloat, width:CGFloat) {
    var textAttributes = attributes
    var fontSize : CGFloat = (attributes[NSFontAttributeName]!.pointSize)!
    var textWidth = width
    while(textWidth >= (width - 0) && fontSize > 6.0) {
        textAttributes[NSFontAttributeName] = fontWithSize(fontSize)
        textWidth = NSAttributedString(string: label, attributes: textAttributes).size().width
        fontSize -= 1.0
    }
    return (fontSize, textWidth)
}

/** main **/

// Usage: ImageOverlay </path/to/image> </path/to/output> <label> [<rrggbbaa-color>]

guard Process.argc >= 4 else {
    exit(ExitCode.WrongNumberOfArguments.rawValue)
}

let imageFile = Process.arguments[1]
let outputImageFile = Process.arguments[2]
let label = Process.arguments[3]

var hexColor = "000ABC77" // blueish
if Process.argc >= 5 {
    hexColor = Process.arguments[4]
}

guard let source = NSImage(contentsOfFile: imageFile) else {
    exit(ExitCode.SourceImageNotValid.rawValue)
}

let imageSize = source.size
var textAttributes =  [
    NSFontAttributeName:fontWithSize(imageSize.width * 0.15),
    NSForegroundColorAttributeName:NSColor.whiteColor()
    ] as [String : AnyObject]
let (fontSize, textWidth) = labelWidth(label, withAttributes: textAttributes, toFit: imageSize.width)

let result = NSImage(size: imageSize)

result.lockFocus()

// draw the image
source.drawInRect(NSRect(origin: NSZeroPoint, size: imageSize), fromRect: NSZeroRect, operation: .CompositeSourceOver, fraction: 1.0)

// draw overlay background unless the hex color is not valid
if let overlayColor = NSColor.fromHexColor(hexColor) {
    let path = NSBezierPath(rect: NSRect(origin: NSZeroPoint, size:CGSize(width: imageSize.width, height: fontSize * 3)))
    overlayColor.setFill()
    path.fill()
}
else {
    exit(ExitCode.InvalidBackgroundColor.rawValue)
}

// draw centered label
textAttributes[NSFontAttributeName] = fontWithSize(fontSize)
NSString(string: label).drawAtPoint(NSPoint(x: imageSize.width / 2 - textWidth / 2, y: fontSize * 1.0), withAttributes: textAttributes)

result.unlockFocus()

// write result to disk
if let png = result.asPNG()
    where png.writeToFile(outputImageFile, atomically: true) == true {
        exit(ExitCode.OK.rawValue)
}

exit(ExitCode.CouldNotWriteImage.rawValue)
