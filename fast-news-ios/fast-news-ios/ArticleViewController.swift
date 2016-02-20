//
//  ArticleViewController.swift
//  fast-news-ios
//
//  Created by Nate Parrott on 2/10/16.
//  Copyright © 2016 Nate Parrott. All rights reserved.
//

import UIKit

class ArticleViewController: SwipeAwayViewController, UITableViewDelegate, UITableViewDataSource {
    // MARK: Data
    var article: Article!
    var _articleSub: Subscription?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.alpha = 0
        errorView.alpha = 0
        
        tableView.separatorColor = UIColor.clearColor()
        
        tableView.registerClass(ImageSegmentTableViewCell.self, forCellReuseIdentifier: "Image")
        tableView.registerClass(TextSegmentTableViewCell.self, forCellReuseIdentifier: "Text")
        
        _articleSub = article.onUpdate.subscribe({ [weak self] (_) -> () in
            self?._update()
        })
        _update()
        article.ensureRecency(3 * 60 * 60)
    }
    func _update() {
        title = article.title
        if let content = article.content {
            rowModels = _createRowModelsFromSegments(content.segments)
            _viewState = .ShowContent
        } else if article.fetchFailed ?? false {
            _viewState = .ShowError
        } else {
            _viewState = .ShowNothing
        }
    }
    // MARK: Layout
    static let Margin: CGFloat = 20
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    enum _ViewState {
        case ShowNothing
        case ShowContent
        case ShowError
        var id: Int {
            get {
                switch self {
                case .ShowNothing: return 1
                case .ShowContent: return 2
                case .ShowError: return 3
                }
            }
        }
    }
    var _viewState = _ViewState.ShowNothing {
        willSet(newVal) {
            if newVal.id != _viewState.id {
                UIView.transitionWithView(self.view, duration: 0.15, options: [.TransitionCrossDissolve], animations: { () -> Void in
                    var tableAlpha: CGFloat = 0
                    var errorAlpha: CGFloat = 0
                    switch newVal {
                    case .ShowContent: tableAlpha = 1
                    case .ShowError: errorAlpha = 1
                    default: ()
                    }
                    self.tableView.alpha = tableAlpha
                    self.errorView.alpha = errorAlpha
                    }, completion: nil)
            }
        }
    }
    
    @IBOutlet var errorView: UIView!
    
    // MARK: Table
    
    @IBOutlet var tableView: UITableView!
    enum RowModel {
        case Text(NSAttributedString)
        case Image(ArticleContent.ImageSegment)
    }
    
    func _createRowModelsFromSegments(segments: [ArticleContent.Segment]) -> [RowModel] {
        var models = [RowModel]()
        for seg in segments {
            if let image = seg as? ArticleContent.ImageSegment {
                models.append(RowModel.Image(image))
            } else if let text = seg as? ArticleContent.TextSegment {
                let attributedString = NSMutableAttributedString()
                text.span.appendToAttributedString(attributedString)
                let maxCharLen = 5000
                while attributedString.length > 0 {
                    let take = min(attributedString.length, maxCharLen)
                    let substring = attributedString.attributedSubstringFromRange(NSMakeRange(0, take))
                    attributedString.deleteCharactersInRange(NSMakeRange(0, take))
                    models.append(RowModel.Text(substring))
                }
            }
        }
        return models
    }
    
    var rowModels: [RowModel]? {
        didSet {
            tableView.reloadData()
        }
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rowModels?.count ?? 0
    }
    
    func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 100
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let model = rowModels![indexPath.row]
        switch model {
        case .Image(let segment): return ceil(ImageSegmentTableViewCell.heightForSegment(segment, width: tableView.bounds.size.width, maxHeight: tableView.bounds.size.height))
        case .Text(let text): return ceil(TextSegmentTableViewCell.heightForString(text, width: tableView.bounds.size.width))
        }
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let model = rowModels![indexPath.row]
        switch model {
        case .Image(let segment):
            let cell = tableView.dequeueReusableCellWithIdentifier("Image") as! ImageSegmentTableViewCell
            cell.segment = segment
            return cell
        case .Text(let string):
            let cell = tableView.dequeueReusableCellWithIdentifier("Text") as! TextSegmentTableViewCell
            cell.string = string
            return cell
        }
    }
    
    func tableView(tableView: UITableView, shouldHighlightRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return false
    }
    
    // MARK: Actions
    @IBAction func share(sender: AnyObject) {
        presentViewController(UIActivityViewController(activityItems: [NSURL(string: article.url!)!], applicationActivities: nil), animated: true, completion: nil)
    }
}
