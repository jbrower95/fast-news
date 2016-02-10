import urllib2
import bs4
from bs4 import BeautifulSoup
import datetime
from model import Article, Source
from google.appengine.ext import ndb
from model import Article
from util import get_or_insert, url_fetch
from canonical_url import canonical_url
import feedparser
from pprint import pprint
from urlparse import urljoin
import random

def source_fetch(source):
    result = _source_fetch(source)
    latest_date = None
    if result:
        if result.feed_title:
            source.title = result.feed_title
        
        for i, entry in enumerate(result.entries):
            id = Article.id_for_article(entry['url'], source.url)
            article, inserted = get_or_insert(Article, id)
            if inserted:
                article.added_date = datetime.datetime.now()
                if latest_date == None or article.added_date > latest_date:
                    latest_date = article.added_date
                article.added_order = i
                article.source = source.key
                article.url = canonical_url(entry['url'])
                article.title = entry['title']
                article.put()
                delay = random.randint(0, 60)
                article.enqueue_fetch(delay=delay)
        
    if latest_date:
        source.most_recent_article_added_date = latest_date
    source.last_fetched = datetime.datetime.now()
    source.put()

class FetchResult(object):
    def __init__(self, method, feed_title, entries):
        self.method = method
        self.feed_title = feed_title
        self.entries = entries # {"url": url, "title": title}
    
    def __repr__(self):
        return "FetchResult.{0}('{1}'): {2} ".format(self.method, self.feed_title, self.entries)

def _source_fetch(source):
    fetch_type = None
    markup = url_fetch(source.url)
    if markup:
        result = None
        for fn in [rss_fetch, fetch_linked_rss, fetch_wordpress_default_rss]:
            result = fn(source, markup, source.url)
            if result: break
        if result:
            print "Fetched {0} as {1} source".format(source.url, result.method)
        else:
            print "Couldn't fetch {0} using any method".format(source.url)
        return result
    else:
        print "URL error fetching {0}".format(source.url)
    return None

def rss_fetch(source, markup, url):    
    parsed = feedparser.parse(markup)
    # pprint(parsed)
    
    if len(parsed['entries']) == 0:
        return None
    
    feed_title = parsed['feed']['title']
    entries = []
    latest_date = None
    for entry in parsed['entries']:
        if 'link' in entry:
            link_url = urljoin(url, entry['link'].strip())
            title = entry['title']
            entries.append({"title": title, "url": link_url})
    
    return FetchResult('rss', feed_title, entries)

def fetch_linked_rss(source, markup, url):
    soup = BeautifulSoup(markup, 'lxml')
    link = soup.find('link', attrs={'rel': 'alternate', 'type': ['application/rss+xml', 'application/atom+xml']})
    if link and type(link) == bs4.element.Tag and link['href']:
        feed_url = urljoin(url, link['href'])
        print 'Found rss URL: ', feed_url
        feed_markup = url_fetch(feed_url)
        if feed_markup:
            result = rss_fetch(source, feed_markup, feed_url)
            if result:
                result.method = 'linked_rss'
                return result
            else:
                print 'failed to parse markup'
        else:
            print "Error fetching linked rss {0}".format(feed_url) 
    return None

def fetch_wordpress_default_rss(source, markup, url):
    link = url + "/?feed=rss"
    print "Trying", link
    feed_markup = url_fetch(link)
    # print "MARKUP:", feed_markup
    if feed_markup:
        res = rss_fetch(source, feed_markup, link)
        print 'res', res
        if res:
            res.method = 'wordpress_default_rss'
            return res
