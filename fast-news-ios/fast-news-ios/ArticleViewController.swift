//
//  ArticleViewController.swift
//  fast-news-ios
//
//  Created by Nate Parrott on 2/10/16.
//  Copyright © 2016 Nate Parrott. All rights reserved.
//

import UIKit
import SafariServices

class ArticleViewController: SwipeAwayViewController {
    // MARK: Data
    var article: Article!
    var _articleSub: Subscription?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        pager.alpha = 0
        loadingContainer.alpha = 0
        
        pager.updateLayout = {
            [weak self] (_) in
            self?._updatePages()
        }
        pager.createPageForModel = {
            [weak self] (i) in
            return self!._pageViewForIndex(i)
        }
        
        view.insertSubview(pager, atIndex: 0)
        
        _articleSub = article.onUpdate.subscribe({ [weak self] (_) -> () in
            self?._update()
        })
        _update()
        article.ensureRecency(3 * 60 * 60)
        
        if let bgColor = article.source?.backgroundColor, let textColor = article.source?.textColor {
            let bgVisibility = max(bgColor.hsva.1, 1 - bgColor.hsva.2)
            let textVisibility = max(textColor.hsva.1, 1 - textColor.hsva.2)
            actionsBar.tintColor = bgVisibility > textVisibility ? bgColor : textColor
        }
        
        pager.backgroundColor = UIColor.whiteColor()
    }
    
    func _update() {
        title = article.title
        if let content = article.content {
            if content.lowQuality ?? false {
                _viewState = .ShowWeb
            } else {
                rowModels = _createRowModelsFromSegments(content.segments)
                _viewState = .ShowContent
            }
        } else if article.fetchFailed ?? false {
            _viewState = .ShowWeb
        } else {
            _viewState = .ShowLoading
        }
    }
    // MARK: Layout
    static let Margin: CGFloat = 18
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    enum _ViewState {
        case ShowNothing
        case ShowContent
        case ShowWeb
        case ShowLoading
        var id: Int {
            get {
                switch self {
                case .ShowNothing: return 1
                case .ShowContent: return 2
                case .ShowLoading: return 4
                case .ShowWeb: return 5
                }
            }
        }
    }
    var _viewState = _ViewState.ShowNothing {
        willSet(newVal) {
            
            if newVal.id != _viewState.id {
                var contentAlpha: CGFloat = 0
                var loaderAlpha: CGFloat = 0
                webView = nil
                
                loadingSpinner.stopAnimating()
                
                switch newVal {
                case .ShowContent: contentAlpha = 1
                case .ShowLoading:
                    loaderAlpha = 1
                    loadingSpinner.startAnimating()
                    loadingSpinner.alpha = 0
                    delay(1.2, closure: { () -> () in
                        UIView.animateWithDuration(0.7, delay: 0, options: .AllowUserInteraction, animations: { () -> Void in
                            self.loadingSpinner.alpha = 1
                            }, completion: nil)
                    })
                case .ShowWeb:
                    webView = InlineWebView()
                    webView?.article = article
                    webView?.onClickedLink = {
                        [weak self] (url) in
                        self?.openLink(url)
                    }
                default: ()
                }
                
                UIView.animateWithDuration(0.2, delay: 0, options: .AllowUserInteraction, animations: { () -> Void in
                    self.pager.alpha = contentAlpha
                    self.loadingContainer.alpha = loaderAlpha
                    }, completion: nil)
            }
        }
    }
    
    @IBOutlet var loadingContainer: UIView!
    @IBOutlet var loadingSpinner: UIActivityIndicatorView!
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        pager.frame = CGRectMake(0, 0, view.bounds.size.width, view.bounds.size.height - layoutInfo.minBottomBarHeight)
        webView?.frame = view.bounds
        webView?.inset = UIEdgeInsetsMake(0, 0, layoutInfo.minBottomBarHeight, 0)
    }
    
    // MARK: Pages
    
    let pager = SwipePager<Int>(frame: CGRectZero)
    
    enum RowModel {
        case Text(string: NSAttributedString, margins: (CGFloat, CGFloat), seg: ArticleContent.TextSegment)
        case Image(ArticleContent.ImageSegment)
    }
    
    struct PageModel {
        init() {}
        var rowModels = [(RowModel, CGFloat)]() // (rowModel, offset)
        var height: CGFloat = 0
        var marginTop: CGFloat = 0
    }
    
    func _updatePages() {
        _layoutInfo = nil
        pager.pageModels = Array(0..<(layoutInfo.pages.count))
    }
    
    func _createRowModelsFromSegments(segments: [ArticleContent.Segment]) -> [RowModel] {
        var models = [RowModel]()
        var trailingMargin = false
        for seg in segments {
            if let image = seg as? ArticleContent.ImageSegment {
                models.append(RowModel.Image(image))
                trailingMargin = false
            } else if let text = seg as? ArticleContent.TextSegment {
                let attributedString = NSMutableAttributedString()
                text.span.appendToAttributedString(attributedString)
                let maxCharLen = 5000
                while attributedString.length > 0 {
                    let take = min(attributedString.length, maxCharLen)
                    let substring = attributedString.attributedSubstringFromRange(NSMakeRange(0, take)).mutableCopy() as! NSMutableAttributedString
                    attributedString.deleteCharactersInRange(NSMakeRange(0, take))
                    let marginTop = (trailingMargin ? 0 : ArticleViewController.Margin) + text.extraTopPadding
                    let marginBottom = ArticleViewController.Margin + text.extraBottomPadding
                    substring.stripWhitespace()
                    models.append(RowModel.Text(string: substring, margins: (marginTop, marginBottom), seg: text))
                    trailingMargin = true
                }
            }
        }
        return models
    }
    
    var rowModels: [RowModel]? {
        didSet {
            _updatePages()
        }
    }
    
    func cellForModel(model: RowModel) -> ArticleSegmentCell {
        switch model {
        case .Image(let segment):
            let cell = ImageSegmentTableViewCell()
            cell.segment = segment
            return cell
        case .Text(let string, let margins, let seg):
            let cell = TextSegmentTableViewCell()
            cell.string = string
            cell.segment = seg
            cell.margin = UIEdgeInsetsMake(margins.0, ArticleViewController.Margin, margins.1, ArticleViewController.Margin)
            cell.onClickedLink = {
                [weak self]
                (let url) in
                self?.openLink(url)
            }
            return cell
        }
    }
    
    func _pageViewForIndex(i: Int) -> UIView {
        let v = ArticlePageView(frame: CGRectMake(0,0,100,100))
        let model = layoutInfo.pages[i]
        var views = [(ArticleSegmentCell, CGFloat, CGFloat)]() // cell, y-offset, height
        for (row, offset) in model.rowModels {
            if views.count > 0 {
                views[views.count - 1].2 = offset - views[views.count - 1].1
            }
            views.append((cellForModel(row), offset, 0))
        }
        views[views.count - 1].2 = model.height - views[views.count - 1].1
        v.views = views
        v.marginTop = model.marginTop
        v.backgroundColor = UIColor.whiteColor()
        return v
    }
    
    // MARK: LayoutInfo
    var _layoutInfo: _LayoutInfo?
    var layoutInfo: _LayoutInfo {
        get {
            if _layoutInfo == nil {
                _layoutInfo = _LayoutInfo()
                viewDidLayoutSubviews()
                _layoutInfo!.size = pager.bounds.size
                if let models = rowModels {
                    _layoutInfo!.computeWithModels(models)
                }
            }
            return _layoutInfo!
        }
    }
    
    class _LayoutInfo {
        var size = CGSizeZero
        var pages = [PageModel]()
        
        func computeWithModels(models: [RowModel]) {
            let maxPageHeight = size.height
            
            pages = [PageModel()]
            for model in models {
                var addedYet = false
                var localPoints = pageBreakPointsForModel(model)
                localPoints[localPoints.count-1] = ceil(localPoints.last!)
                
                var prevLocalPoint: CGFloat = 0
                for point in localPoints.filter({ $0 != 0 }).map({ round($0) }) {
                    if point - prevLocalPoint + pages.last!.height > maxPageHeight {
                        // create a new page:
                        pages.append(PageModel())
                        pages[pages.count - 1].rowModels.append((model, -prevLocalPoint))
                        // if this is a text field w/ no margin, or mid-text, append a margin:
                        switch model {
                        case .Text(string: _, margins: (let topMargin, _), seg: _):
                            if topMargin == 0 || addedYet {
                                pages[pages.count - 1].height += ArticleViewController.Margin
                                pages[pages.count - 1].marginTop = ArticleViewController.Margin
                            }
                        default: ()
                        }
                    } else if !addedYet {
                        pages[pages.count - 1].rowModels.append((model, pages.last!.height))
                    }
                    pages[pages.count - 1].height += point - prevLocalPoint
                    prevLocalPoint = point
                    addedYet = true
                }
            }
        }
        
        var minBottomBarHeight: CGFloat = 44
        
        func heightForModel(model: RowModel) -> CGFloat {
            switch model {
            case .Image(let segment):
                return ceil(ImageSegmentTableViewCell.heightForSegment(segment, width: size.width, maxHeight: size.height))
            case .Text(let text, let margins, seg: _):
                let margin = UIEdgeInsetsMake(margins.0, ArticleViewController.Margin, margins.1, ArticleViewController.Margin)
                return ceil(TextSegmentTableViewCell.heightForString(text, width: size.width, margin: margin))
            }
        }
        
        func pageBreakPointsForModel(model: RowModel) -> [CGFloat] {
            switch model {
            case .Text(string: let str, margins: (let topMargin, let bottomMargin), seg: _):
                return TextSegmentTableViewCell.pageBreakPointsForSegment(str, width: size.width, margin: UIEdgeInsetsMake(topMargin, ArticleViewController.Margin, bottomMargin, ArticleViewController.Margin))
            default:
                return [0, heightForModel(model)]
            }
        }
    }
    
    // MARK: Actions
    func openLink(url: NSURL) {
        let vc = SFSafariViewController(URL: url)
        presentViewController(vc, animated: true, completion: nil)
    }
    
    @IBAction func share(sender: AnyObject) {
        let safariVCActivity = SafariVCActivity(parentViewController: self)
        let activityVC = UIActivityViewController(activityItems: [NSURL(string: article.url!)!], applicationActivities: [safariVCActivity])
        // activityVC.excludedActivityTypes = []
        presentViewController(activityVC, animated: true, completion: nil)
    }
    
    @IBAction func toggleBookmarked(sender: AnyObject) {
        
    }
    
    @IBOutlet var actionsBar: UIView!
    
    @IBOutlet var bookmarkButton: UIButton!
    var _usesBookmarkSavedIcon = false {
        didSet {
            // TODO
        }
    }
    @IBAction func dismiss() {
        if let cb = onBack {
            cb()
        } else {
            dismissViewControllerAnimated(true, completion: nil)
        }
    }
    
    var onBack: (() -> ())?
    
    // MARK: WebView
    var webView: InlineWebView? {
        willSet(newVal) {
            webView?.removeFromSuperview()
            if let new = newVal {
                view.insertSubview(new, aboveSubview: pager)
            }
        }
    }
}

