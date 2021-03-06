//
//  ArticleCollectionViewController.swift
//  fast-news-ios
//
//  Created by Nate Parrott on 2/10/16.
//  Copyright © 2016 Nate Parrott. All rights reserved.
//

import UIKit

class ArticleCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {
    var model: APIObject! {
        get {
            return nil
        }
    }
    var collectionModels: [APIObject] {
        get {
            return []
        }
    }
    func applyModelToCell(cell: UICollectionViewCell, model: APIObject) {
        
    }
    var modelTitle: String {
        return ""
    }
    var cellClass: UICollectionViewCell.Type {
        return UICollectionViewCell.self
    }
    
    func getPreloadObjectForModel(model: APIObject) -> AnyObject? {
        return nil
    }
    
    // MARK: Loading
    var _modelSub: Subscription?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // collectionView?.backgroundColor = UIColor.whiteColor()
        collectionView!.decelerationRate = (UIScrollViewDecelerationRateFast + UIScrollViewDecelerationRateNormal) / 2
        automaticallyAdjustsScrollViewInsets = false
        _modelSub = model.onUpdate.subscribe { [weak self] (state) -> () in
            self?.update()
        }
        collectionView!.registerClass(cellClass, forCellWithReuseIdentifier: "Cell")
        _sizingCell = cellClass.init()
        update()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ArticleCollectionViewController._foreground(_:)), name: UIApplicationWillEnterForegroundNotification, object: nil)
        // navigationController?.navigationBar.titleTextAttributes = [NSFontAttributeName: UIFont(name: "AbrilFatface-Regular", size: 20)!]
        // let layout = collectionView!.collectionViewLayout as! UICollectionViewFlowLayout
    }
    
    let _preferredRecency: CFAbsoluteTime = 5 * 60
    
    var visible = false
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        visible = true
        update()
        model.ensureRecency(_preferredRecency)
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        visible = false
    }
    
    func _foreground(notif: NSNotification) {
        model.ensureRecency(_preferredRecency)
    }
    
    func update() {
        collectionView?.reloadData()
        
        var title = ""
        switch model.loadingState {
        case .Error(_):
            title = NSLocalizedString("Offline", comment: "")
        case .Loading(_):
            title = NSLocalizedString("Refreshing…", comment: "")
        default:
            title = modelTitle
        }
        displayTitle = title
        
        if !visible {
            return
        }
    }
        
    var displayTitle: String? {
        get {
            return navigationItem.title
        }
        set (val) {
            navigationItem.title = val
        }
    }
    
    // MARK: Collection
    var _sizingCell: UICollectionViewCell!
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return collectionModels.count
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("Cell", forIndexPath: indexPath)
        applyModelToCell(cell, model: collectionModels[indexPath.item])
        return cell
    }
    
    override func collectionView(collectionView: UICollectionView, willDisplayCell cell: UICollectionViewCell, forItemAtIndexPath indexPath: NSIndexPath) {
        preloadImagesForVisibleRange(currentVisibleRange())
    }
    
    func currentVisibleRange() -> NSRange {
        let visibleIndices = collectionView!.indexPathsForVisibleItems().map({ $0.item })
        if visibleIndices.count == 0 {
            return NSMakeRange(0, 0)
        } else {
            let minIdx = visibleIndices.minElement()!
            return NSMakeRange(minIdx, visibleIndices.maxElement()! - minIdx)
        }
    }
    
    // MARK: Layout
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        let model = collectionModels[indexPath.item]
        applyModelToCell(_sizingCell, model: model)
        return _sizingCell.sizeThatFits(CGSizeMake(collectionView.bounds.size.width, 1000))
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if let flow = collectionView!.collectionViewLayout as? UICollectionViewFlowLayout {
            flow.estimatedItemSize = CGSizeMake(view.bounds.size.width * 0.7, 200)
        }
    }
    
    // MARK: Image preloading
    let preloadCountInEachDirection = 4
    var preloadObjectsForIndices = [Int: AnyObject]()
    func preloadImagesForVisibleRange(range: NSRange) {
        let indicesToRemove = preloadObjectsForIndices.keys.filter({ range.distanceFromValue($0) > self.preloadCountInEachDirection })
        for idx in indicesToRemove {
            preloadObjectsForIndices.removeValueForKey(idx)
            // print("removing \(idx)")
        }
        var indices = [Int]()
        let models = collectionModels
        for i in 1..<(preloadCountInEachDirection+1) {
            indices.append(range.location - i)
            indices.append(range.location + range.length + i)
        }
        for i in indices {
            if i >= 0 && i < models.count {
                if preloadObjectsForIndices[i] == nil {
                    if let obj = getPreloadObjectForModel(models[i]) {
                        preloadObjectsForIndices[i] = obj
                        // print("adding \(i)")
                    } else {
                        // print("nothing for \(i)")
                    }
                }
            }
        }
    }
}

extension NSRange {
    func distanceFromValue(val: Int) -> Int {
        if val < location {
            return location - val
        } else if val > location + length {
            return val - (location + length)
        } else {
            return 0
        }
    }
}
