import urllib2, urllib
import datetime
import json
from util import url_fetch
import readability
from bs4 import BeautifulSoup
# also look at https://github.com/seomoz/dragnet/blob/master/README.md

def find_meta_value(soup, prop):
    tag = soup.find('meta', attrs={'property': prop})
    if tag:
        return tag['content']

def first_present(items):
    for item in items:
        if item:
            return item

def article_fetch(article):
    markup = url_fetch(article.url)
    # print 'markup', markup
    if markup:
        markup_soup = BeautifulSoup(markup, 'lxml')
        doc = readability.Document(markup)
        
        if title and not article.title:
            article.title = title
        article_html = doc.summary()
        article_soup = BeautifulSoup(article_html, 'lxml')
        
        soup = BeautifulSoup(article_html, 'lxml')
        
        og_title = find_meta_value(markup_soup, 'og:title')
        og_image = find_meta_value(markup_soup, 'og:image')
        og_description = find_meta_value(markup_soup, 'og:description')
        
        article_text = unicode(article_soup.get_text()).strip()
        
        article.title = first_present([article.title, doc.short_title(), og_title])
        
        article.parsed = {
            "article_text": article_text,
            "article_html": article_html,
            "description": og_description,
            "top_image": first_present([og_image])
        }
        article.fetch_failed = False
    else:
        article.fetch_failed = True
    article.fetch_date = datetime.datetime.now()
    article.put()

def article_fetch_old(article):
    content = ""
    title = ""
    try:
        print 'URL:', 'https://fast-news-parser.herokuapp.com/parse?' + urllib.urlencode({"url": article.url})
        data = json.load(urllib2.urlopen('https://fast-news-parser.herokuapp.com/parse?' + urllib.urlencode({"url": article.url})))
        if data['title']: article.title = data['title']
        article.parsed = data
    except ValueError as e:
        print "JSON parse error fetching {0}: {1}".format(article.url, e)
        article.fetch_failed = True
    except urllib2.URLError as e:
        print "URL error fetching {0}: {1}".format(article.url, e)
        article.fetch_failed = True
    article.fetch_date = datetime.datetime.now()
    article.put()
