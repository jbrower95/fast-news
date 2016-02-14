//
//  ArticleView.swift
//  fast-news-ios
//
//  Created by Nate Parrott on 2/12/16.
//  Copyright © 2016 Nate Parrott. All rights reserved.
//

import UIKit


class ArticleView: UIView {
    var article: Article? {
        didSet {
            _setup()
            if let a = article {
                headline.attributedText = getPreviewText()
                if let url = a.imageURL {
                    imageView.url = ArticleView.resizedURLForImageAtURL(url)
                    // imageView.url = NSURL(string: url)
                } else {
                    imageView.url = nil
                }
            }
        }
    }
    class func resizedURLForImageAtURL(url: String) -> NSURL {
        let scale = UIScreen.mainScreen().scale * 2
        return NetImageView.mirroredURLForImage(url, size: CGSizeMake(ArticleView.ImageSize * scale, (ArticleView.MaxLabelHeight + ArticleView.Padding * 2) * scale))
    }
    func getPreviewText() -> NSAttributedString {
        let headlineAttributes = [NSFontAttributeName: UIFont.boldSystemFontOfSize(17), NSForegroundColorAttributeName: UIColor(white: 0, alpha: 1)]
        let secondLineFont = UIFont.systemFontOfSize(12)
        let descriptionAttributes = [NSFontAttributeName: secondLineFont, NSForegroundColorAttributeName: UIColor(white: 0, alpha: 0.5)]
        let hostAttributes = [NSFontAttributeName: UIFont.systemFontOfSize(12), NSForegroundColorAttributeName: Theme.darkBlue]
        
        let headline = NSAttributedString(string: (article?.title ?? ""), attributes: headlineAttributes)
        
        var secondLine = [NSAttributedString]()
        if let diff = article?.differentWebsiteFromSource,
            let url = article?.url,
            let host = Utils.HostFromURLString(url) where diff {
                secondLine.append(NSAttributedString(string: host, attributes: hostAttributes))
        }
        if let desc = article?.articleDescription {
            secondLine.append(NSAttributedString(string: desc, attributes: descriptionAttributes))
        }
        let secondLineJoiner = NSAttributedString(string: " ", attributes: [NSFontAttributeName: secondLineFont])
        
        let lines = [
            headline,
            Utils.JoinAttributedStrings(secondLine, joint: secondLineJoiner)
        ]
        let lineJoiner = NSAttributedString(string: "\n\n", attributes: [NSFontAttributeName: UIFont.systemFontOfSize(1)])
        return Utils.JoinAttributedStrings(lines, joint: lineJoiner)
        
    }
    let imageView = NetImageView()
    let headline = UILabel()
    var _setupYet = false
    func _setup() {
        if !_setupYet {
            _setupYet = true
            for v in [imageView, headline] {
                addSubview(v)
            }
            headline.numberOfLines = 0
            headline.font = UIFont.boldSystemFontOfSize(17)
            backgroundColor = UIColor.whiteColor()
            imageView.contentMode = .ScaleAspectFill
            imageView.clipsToBounds = true
        }
    }
    
    static let ImageSize: CGFloat = 120
    static let Padding: CGFloat = 4
    static let MaxLabelHeight: CGFloat = 124
    
    func _layout(width: CGFloat) -> CGFloat {
        let maxLabelHeight: CGFloat = ArticleView.MaxLabelHeight
        let minLabelHeight: CGFloat = 56
        let padding: CGFloat = ArticleView.Padding
        let hasImage = imageView.url != nil
        let headlineWidth = hasImage ? width - ArticleView.ImageSize - padding * 2 : width - padding * 2
        let headlineHeight = min(maxLabelHeight, headline.sizeThatFits(CGSizeMake(headlineWidth, maxLabelHeight)).height)
        let height = max(headlineHeight + padding * 2, hasImage ? ArticleView.ImageSize : 0, minLabelHeight)
        imageView.hidden = !hasImage
        imageView.frame = CGRectMake(width - ArticleView.ImageSize, 0, ArticleView.ImageSize, height)
        headline.frame = CGRectMake(padding, padding, headlineWidth, height - padding * 2)
        return height
    }
    
    override func sizeThatFits(size: CGSize) -> CGSize {
        return CGSizeMake(size.width, _layout(size.width))
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        _layout(bounds.size.width)
    }
}

