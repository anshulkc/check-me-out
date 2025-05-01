//
//  CGPointDictionaryTransformer.swift
//  CheckMeOut
//
//  Created for body composition analysis
//

import Foundation
import UIKit
import CoreData

// Define a class that conforms to NSSecureCoding to store CGPoint values
class CodableCGPoint: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool = true
    
    let point: CGPoint
    
    init(point: CGPoint) {
        self.point = point
        super.init()
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(Float(point.x), forKey: "x")
        coder.encode(Float(point.y), forKey: "y")
    }
    
    required init?(coder: NSCoder) {
        let x = CGFloat(coder.decodeFloat(forKey: "x"))
        let y = CGFloat(coder.decodeFloat(forKey: "y"))
        self.point = CGPoint(x: x, y: y)
        super.init()
    }
}

// Custom value transformer for [String: CGPoint] dictionaries
@objc(CGPointDictionaryTransformer)
class CGPointDictionaryTransformer: NSSecureUnarchiveFromDataTransformer {
    
    static let name = NSValueTransformerName(rawValue: String(describing: CGPointDictionaryTransformer.self))
    
    override static var allowedTopLevelClasses: [AnyClass] {
        return [NSDictionary.self, NSString.self, CodableCGPoint.self, NSValue.self]
    }
    
    public static func register() {
        let transformer = CGPointDictionaryTransformer()
        ValueTransformer.setValueTransformer(transformer, forName: name)
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        // If nil, return nil
        guard let value = value else { return nil }
        
        // If already Data, return it
        if value is Data { return value }
        
        // Handle [String: CGPoint] dictionary
        if let dictionary = value as? [String: CGPoint] {
            // Convert [String: CGPoint] to [String: CodableCGPoint]
            let transformedDict = dictionary.mapValues { CodableCGPoint(point: $0) }
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: transformedDict, requiringSecureCoding: true)
                return data
            } catch {
                print("Error archiving CGPoint dictionary: \(error)")
                return nil
            }
        }
        
        // If we get here, use the superclass implementation but with extra safety
        // Don't call super.transformedValue as it might not handle our custom types correctly
        do {
            // For any other object, try to archive it directly
            let data = try NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: true)
            return data
        } catch {
            print("Error archiving value of type \(type(of: value)): \(error)")
            return nil
        }
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        // Handle nil values
        guard let value = value else { return nil }
        
        // Make sure we have Data
        guard let data = value as? Data else {
            print("Error: expected Data but got \(type(of: value))")
            return nil
        }
        
        do {
            // First try to unarchive as a dictionary of CodableCGPoint
            if let unarchivedDict = try? NSKeyedUnarchiver.unarchivedObject(
                ofClasses: [NSDictionary.self, NSString.self, CodableCGPoint.self, NSValue.self],
                from: data
            ) as? [String: CodableCGPoint] {
                // Convert back from [String: CodableCGPoint] to [String: CGPoint]
                return unarchivedDict.mapValues { $0.point }
            }
            
            // If that fails, try to unarchive as a single CodableCGPoint
            if let codablePoint = try? NSKeyedUnarchiver.unarchivedObject(
                ofClasses: [CodableCGPoint.self],
                from: data
            ) as? CodableCGPoint {
                return codablePoint.point
            }
            
            // If all else fails, try the generic approach
            let object = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [
                NSDictionary.self, NSArray.self, NSString.self, NSNumber.self,
                NSDate.self, NSData.self, CodableCGPoint.self, NSValue.self
            ], from: data)
            return object
        } catch {
            print("Error unarchiving data: \(error)")
            return nil
        }
    }
}
