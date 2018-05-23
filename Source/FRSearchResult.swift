//
//  FRSearchResult.swift
//  FolioReaderKit
//
//  Created by Alexander on 5/23/18.
//  Copyright © 2018 FolioReader. All rights reserved.
//

import Foundation

struct FRSearchResult {
    
    var searchString: String
    var resource: FRResource
    var range: NSRange
    
    
    var resultString: NSAttributedString? {
        guard let htmlString = try? String(contentsOfFile: resource.fullHref, encoding: .utf8).stripHtml() else { return nil }
        
        let lower = htmlString.index(htmlString.startIndex, offsetBy: range.lowerBound)
        let upper = htmlString.index(htmlString.startIndex, offsetBy: range.upperBound)
        
        let offsetUpper = htmlString.index(upper, offsetBy: 30, limitedBy: htmlString.endIndex) ?? upper
        
        // TODO: - Refactor remove force
        let originalString = String(htmlString[lower..<upper])!
        let offsetString = String(htmlString[lower..<offsetUpper])!
        
        guard let originalRangeInOffsetString = offsetString.range(of: originalString) else { return nil }
        
        let resultString = NSMutableAttributedString(string: offsetString, attributes: [NSForegroundColorAttributeName: UIColor.gray, NSFontAttributeName: UIFont.systemFont(ofSize: 16)])
        resultString.addAttributes([NSForegroundColorAttributeName: UIColor.black, NSFontAttributeName: UIFont.boldSystemFont(ofSize: 17)], range: originalString.nsRange(from: originalRangeInOffsetString))
        
        return resultString
    }
    
}
