from model import Source, Article, Subscription
from util import get_or_insert
from canonical_url import canonical_url
from google.appengine.ext import ndb

def subscribe(uid, url):
    source = ensure_source(url)
    url = source.url
    
    id = Subscription.id_for_subscription(url, uid)
    sub, inserted = get_or_insert(Subscription, id)
    if inserted:
        sub.url = url
        sub.uid = uid
        sub.put()
    
    return source.json(include_articles=True)

def ensure_source(url):
    url = canonical_url(url)
    source_id = Source.id_for_source(url)
    source, inserted = get_or_insert(Source, source_id)
    if inserted:
        source.url = url
        source.put()
        source.fetch_now()
        source.enqueue_fetch()
    return source

def feed(uid):
    print 'UID', uid
    subscriptions = Subscription.query(Subscription.uid == uid).fetch(100)
    source_json = []
    if len(subscriptions) > 0:
        
        subscription_urls = set([s.url for s in subscriptions])
        sources = Source.query(Source.url.IN(list(subscription_urls))).order(-Source.most_recent_article_added_date).fetch(len(subscription_urls))
        source_promises = [src.json(include_articles=True, article_limit=10, return_promise=True) for src in sources]
        source_json = [p() for p in source_promises]
    return {
        "sources": source_json
    }
