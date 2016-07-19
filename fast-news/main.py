#!/usr/bin/env python
#
# Copyright 2007 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
import webapp2
import api
from model import Source, Article, Subscription
from google.appengine.ext import ndb
import json
from pprint import pprint
from mirror import MirrorHandler
import dump
import util
import file_storage

def send_json(handler, content):
    handler.response.headers.add_header('Content-Type', 'application/json')
    handler.response.write(json.dumps(content))

class MainHandler(webapp2.RequestHandler):
    def get(self):
        self.response.write('Hello world!')

class SubscribeHandler(webapp2.RequestHandler):
    def post(self):
        url = self.request.get('url')
        uid = self.request.get('uid')
        send_json(self, api.subscribe(uid, url))

class SourceHandler(webapp2.RequestHandler):
    def get(self):
        id = self.request.get('id')
        send_json(self, ndb.Key('Source', id).get().json(include_articles=True))

class ArticleHandler(webapp2.RequestHandler):
    def get(self):
        id = self.request.get('id')
        url = self.request.get('url')
        
        if id:
            article = ndb.Key('Article', id).get()
            article.fetch_if_needed(ignore_previous_failure=True)
        else:
            article = api.ensure_article_at_url(url)
        
        send_json(self, article.json(include_article_json=True))

class FeedHandler(webapp2.RequestHandler):
    def get(self):
        uid = self.request.get('uid')
        article_limit = int(self.request.get('article_limit', '10'))
        source_limit = int(self.request.get('source_limit', '100'))
        send_json(self, api.feed(uid, article_limit, source_limit))

class SubscriptionsHandler(webapp2.RequestHandler):
    def get(self):
        uid = self.request.get('uid')
        send_json(self, api.subscriptions(uid))

class UnsubscribeHandler(webapp2.RequestHandler):
    def post(self):
        self.delete()
    
    def delete(self):
        uid = self.request.get('uid')
        url = self.request.get('url')
        api.unsubscribe(uid, url)
        send_json(self, {"success": True})

class BookmarksHandler(webapp2.RequestHandler):
    def get(self):
        uid = self.request.get('uid')
        send_json(self, api.bookmarks(uid))
    
    def post(self):
        uid = self.request.get('uid')
        article_id = self.request.get('article_id')
        article_url = self.request.get('article_url')
        reading_pos = self.request.get('reading_position')
        if reading_pos: reading_pos = json.loads(reading_pos)
        bookmark = api.add_or_update_bookmark(uid, reading_pos, article_id, article_url)
        send_json(self, {"bookmark": bookmark.json() if bookmark else None})
    
    def delete(self):
        uid = self.request.get('uid')
        article_id = self.request.get('article_id')
        api.delete_bookmark(uid, article_id)
        send_json(self, {"success": True})
    
class ArticleTestFetchHandler(webapp2.RequestHandler):
    def post(self):
        url = self.request.get('url')
        article = api.ensure_article_at_url(url, force_fetch=True)
        type = self.request.get('type')
        if type == 'html':
            self.response.write(article.content.get().html)
        elif type == 'article_json':
            self.response.headers.add_header('Content-Type', 'application/json')
            self.response.write(json.dumps({
                "article": article.content.get().article_json
            }))
        else:
            self.response.headers.add_header('Content-Type', 'application/json')
            self.response.write(json.dumps({
                "article": article.json(include_article_json=True)
            }))

class TestHandler(webapp2.RequestHandler):
    def get(self):
        html = """
        <form method=POST action='/subscriptions/add'>
            <h1>Test subscribe</h1>
            <input name=url placeholder=url>
            <input name=uid placeholder=uid>
            <input type=submit>
        </form>
        <form method=POST>
            <h1>Test source fetch</h1>
            <input type=hidden name=test value=source>
            <input name=url>
            <input type=submit>
        </form>
        <form method=POST action='/subscriptions/delete'>
            <h1>Test unsubscribe</h1>
            <input name=url placeholder=url>
            <input name=uid placeholder=uid>
            <input type=submit>
        </form>
        <form method=POST action='test/article_fetch'>
            <h1>Test article fetch</h1>
            <input name=url placeholder=url>
            <p><input type=radio name=type value=default checked>Default json</p>
            <p><input type=radio name=type value=html>Extracted HTML</p>
            <p><input type=radio name=type value=article_json>Article JSON</p>
            <input type=submit>
        </form>
        <form method=POST action='bookmarks'>
            <h1>Bookmark</h1>
            <input name=article_url type=url placeholder=article_url>
            <input name=uid placeholder=uid>
            <input type=submit>
        </form>
        <form method=POST action='/admin/reschedule_source_fetches'>
            <h1>Reschedule source fetches</h1>
            <p>Make sure to clear the <em>sources</em> queue in the AppEngine dashboard <a href='https://console.cloud.google.com/appengine/taskqueues/sources?project=fast-news&moduleId=default'>here</a> first.</p>
            <input type=submit>
        </form>
        <form method=POST action='/admin/purge_source'>
            <h1>Purge source</h1>
            <input type=url name=url placeholder='Source URL'/>
            <input type=submit>
        </form>
        """
        self.response.write(html)
    
    def post(self):
        test = self.request.get('test')
        if test == 'source':
            from source_fetch import _source_fetch
            from api import ensure_source
            url = self.request.get('url')
            source = ensure_source(url, suppress_immediate_fetch=True)
            self.response.headers.add_header('Content-Type', 'text/plain')
            pprint(_source_fetch(source), self.response.out)

class StatsHandler(webapp2.RequestHandler):
    def get(self):
        send_json(dump.stats())

class ArticleDumpHandler(webapp2.RequestHandler):
    def get(self):
        send_json(dump.dump_items(cursor=self.request.get('cursor')))

class SimpleExtractHandler(webapp2.RequestHandler):
    def get(self):
        from bs4 import BeautifulSoup as bs
        from article_extractor import extract
        url = self.request.get('url')
        markup = util.url_fetch(url)
        soup = bs(markup, 'lxml')
        text = u""
        if soup.title:
            title = soup.title.string
            h1 = soup.new_tag('h1')
            h1.string = title
            text += unicode(h1)
        # print create_soup_with_ids(markup).prettify()
        text += extract(markup, url)
        self.response.headers['Access-Control-Allow-Origin'] = '*'
        self.response.write(text)

class FeaturedSourcesHandler(webapp2.RequestHandler):
    def get(self):
        send_json(self, api.featured_sources_by_category(category=self.request.get('category')))

app = webapp2.WSGIApplication([
    ('/', MainHandler),
    ('/article', ArticleHandler),
    ('/source', SourceHandler),
    ('/feed', FeedHandler),
    ('/subscriptions', SubscriptionsHandler),
    ('/subscriptions/add', SubscribeHandler),
    ('/subscriptions/delete', UnsubscribeHandler),
    ('/bookmarks', BookmarksHandler),
    ('/sources/featured', FeaturedSourcesHandler),
    ('/test', TestHandler),
    ('/test/article_fetch', ArticleTestFetchHandler),
    ('/mirror', MirrorHandler),
    ('/stats', StatsHandler),
    ('/dump/articles', ArticleDumpHandler),
    ('/extract', SimpleExtractHandler),
    ('/_dbFile', file_storage._DBFileHandler)
], debug=True)

if True:
    def cprofile_wsgi_middleware(app):
        """
        Call this middleware hook to enable cProfile on each request.  Statistics are dumped to
        the log at the end of the request.
        :param app: WSGI app object
        :return: WSGI middleware wrapper
        """
        def _cprofile_wsgi_wrapper(environ, start_response):
            import cProfile, cStringIO, pstats, logging
            profile = cProfile.Profile()
            try:
                return profile.runcall(app, environ, start_response)
            finally:
                stream = cStringIO.StringIO()
                stats = pstats.Stats(profile, stream=stream)
                stats.strip_dirs().sort_stats('cumulative', 'time', 'calls').print_stats(50)
                logging.info('cProfile data:\n%s', stream.getvalue())
        return _cprofile_wsgi_wrapper

    def webapp_add_wsgi_middleware(app):
        return cprofile_wsgi_middleware(app)

    app = webapp_add_wsgi_middleware(app)

