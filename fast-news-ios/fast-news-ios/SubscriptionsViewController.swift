//
//  SubscriptionsViewController.swift
//  fast-news-ios
//
//  Created by Nate Parrott on 2/6/16.
//  Copyright © 2016 Nate Parrott. All rights reserved.
//

import UIKit

class SubscriptionsViewController: UITableViewController, UITextFieldDelegate {
    let subs = SubscriptionsList.objectsForIDs(["main"]).first! as! SubscriptionsList
    var _subsSub: Subscription?
    var _sourcesBeingAddedSub: Subscription?
    var _sourcesBeingDeletedSub: Subscription?
    var _sourcesJustAddedSub: Subscription?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "_foreground:", name: UIApplicationWillEnterForegroundNotification, object: nil)
        
        _subsSub = subs.onUpdate.subscribe({ [weak self] (_) -> () in
            self?._update()
        })
        _sourcesBeingAddedSub = AddSubscriptionTransaction.InProgress().subscribe({ [weak self] (_) -> () in
            self?._update()
        })
        _sourcesBeingDeletedSub = DeleteSubscriptionTransaction.InProgress().subscribe({ [weak self] (_) -> () in
            self?._update()
        })
        
        tableView.tableHeaderView = addSourceTextField
    }
    
    let _preferredRecency: CFAbsoluteTime = 5 * 60
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        subs.ensureRecency(_preferredRecency)
    }
    
    func _foreground(notif: NSNotification) {
        subs.ensureRecency(_preferredRecency)
    }
    
    func _update() {
        var title = navigationItem.title
        if _addsInProgress > 0 {
            title = NSLocalizedString("Adding…", comment: "")
        } else {
            switch subs.loadingState {
            case .Error(_): title = NSLocalizedString("Offline", comment: "")
            case .Loading(_): title = NSLocalizedString("Refreshing…", comment: "")
            default: title = NSLocalizedString("News Subscriptions", comment: "")
            }
        }
        navigationItem.title = title
        
        var models = subs.subscriptions ?? []
        for t in AddSubscriptionTransaction.InProgress().val as! [AddSubscriptionTransaction] {
            models.insert(t.optimisticSub, atIndex: 0)
        }
        let removedUrls = Set((DeleteSubscriptionTransaction.InProgress().val as! [DeleteSubscriptionTransaction]).map({ $0.url }))
        models = models.filter({ !removedUrls.contains($0.source?.url ?? "") })
        _subscriptionModels = models
    }
    
    // MARK: Adding sources
    
    @IBOutlet var addSourceTextField: UITextField!
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        if let url = (textField.text ?? "").asURLString() {
            _addsInProgress += 1
            AddSubscriptionTransaction(url: url).start({ (success) -> () in
                self._addsInProgress -= 1
                if !success {
                    self.showError(NSLocalizedString("Couldn't add that news source.", comment: ""))
                }
            })
        }
        textField.text = ""
        textField.resignFirstResponder()
        return false
    }
    
    func textFieldShouldClear(textField: UITextField) -> Bool {
        delay(0.01) { () -> () in
            textField.resignFirstResponder()
        }
        return true
    }
    var _addsInProgress = 0 {
        didSet {
            _update()
        }
    }
    
    // MARK: TableView
    var _subscriptionModels = [SourceSubscription]() {
        didSet {
            tableView.reloadData()
        }
    }
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return _subscriptionModels.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)
        let sub = _subscriptionModels[indexPath.row]
        cell.textLabel!.text = sub.source!.title
        cell.detailTextLabel!.text = sub.source!.url
        return cell
    }
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        switch editingStyle {
        case .Delete:
            let sub = _subscriptionModels[indexPath.row]
            DeleteSubscriptionTransaction(url: sub.source!.url!).start({ (success) -> () in
                if !success {
                    self.showError(NSLocalizedString("Couldn't unsubscribe.", comment: ""))
                }
            })
        default: ()
        }
    }
    
    override func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        addSourceTextField.resignFirstResponder()
    }
    
    override func tableView(tableView: UITableView, performAction action: Selector, forRowAtIndexPath indexPath: NSIndexPath, withSender sender: AnyObject?) {
        if action == "delete:" {
            let sub = subs.subscriptions![indexPath.row]
            DeleteSubscriptionTransaction(url: sub.source!.url!).start({ (success) -> () in
                if !success {
                    self.showError(NSLocalizedString("Couldn't unsubscribe.", comment: ""))
                }
            })
        }
    }
}
