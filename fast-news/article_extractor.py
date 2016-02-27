import readability
from soup_tools import iterate_tree, clone_node
import bs4
import os
import json
import re

def extract(html, url):
    in_soup = create_soup_with_ids(html)
    html = unicode(in_soup)
    
    out_soup = bs4.BeautifulSoup('<div></div>', 'lxml')
    stack = [out_soup.find('div')]
    
    blacklist, whitelist = id_blacklist_and_whitelist_for_soup(in_soup, url)
    readability_ids = ids_preserved_by_readability(html)
    
    NONE = 1
    WHITELISTED = 2
    READABILITY = 3
    BLACKLISTED = 4
    
    # print 'IN SOUP', in_soup.prettify().encode('utf-8')
    # print readability_ids
    
    state_stack = [NONE]
    for kind, data in iterate_tree(in_soup):
        if kind == 'enter':
            id = data.get('data-subscribed-id')
            parent_state = state_stack[-1]
            
            if parent_state in (WHITELISTED, BLACKLISTED):
                state = parent_state
            else:
                if id in readability_ids:
                    state = READABILITY
                else:
                    state = NONE
            
            if id in whitelist:
                state = WHITELISTED
            elif id in blacklist:
                state = BLACKLISTED
            
            if id: del data['data-subscribed-id']
            
            state_stack.append(state)
            clone = clone_node(data)
            stack[-1].append(clone)
            stack.append(clone)
        elif kind == 'text':
            # if '342 days' in data:
            #     print state_stack, state_stack[-1] in (WHITELISTED, READABILITY)
            if state_stack[-1] in (WHITELISTED, READABILITY):
                stack[-1].append(data)
        elif kind == 'exit':
            node = stack[-1]
            node_contains_content = (len(list(node)) > 0) 
            node_is_content = node.name in ('img', 'video', 'object', 'hr', 'br') and state_stack[-1] in (WHITELISTED, READABILITY) 
            if  not node_contains_content and not node_is_content:
                node.extract()
            stack.pop()
            state_stack.pop()
    return out_soup.prettify()

def create_soup_with_ids(html):
    i = 1
    soup = bs4.BeautifulSoup(html, 'lxml')
    for kind, data in iterate_tree(soup):
        if kind == 'enter':
            data['data-subscribed-id'] = str(i)
            i += 1
    return soup

def ids_preserved_by_readability(html):
    ids = set()
    extracted_html = readability.Document(html).summary(html_partial=True)
    # print 'READABILITY SOUP', bs4.BeautifulSoup(extracted_html, 'lxml').prettify().encode('utf-8')
    
    for kind, data in iterate_tree(bs4.BeautifulSoup(extracted_html, 'lxml')):
        if kind == 'enter':
            id = data.get('data-subscribed-id')
            if id:
                ids.add(id)
            else:
                pass
                # print 'No ID for', data
    return ids

def strip_url_prefix(url): 
    return re.sub(r"^https?:\/\/(www\.)?", "", url)

def normalize_url(url):
    url = strip_url_prefix(url).split('/')[0]
    url = "".join([c for c in url if c.isalpha() or c.isdigit() or c in (' ', '.', '-', '_')]).rstrip()
    return url

def id_blacklist_and_whitelist_for_soup(soup, url):
    whitelist = set()
    blacklist = set()
    
    data_path = os.path.join(os.path.dirname(__file__), 'article_extractor_info', normalize_url(url) + '.json')
    if os.path.exists(data_path):
        j = json.load(open(data_path))
        for (id_set, name) in [(whitelist, 'whitelist'), (blacklist, 'blacklist')]:
            for selector in j.get(name, []):
                for node in soup.select(selector):
                    id = node.get('data-subscribed-id')
                    if id:
                        id_set.add(id)
    return blacklist, whitelist

if __name__ == '__main__':
    markup = open('samples/nytimes.html').read()
    # print create_soup_with_ids(markup).prettify()
    ex = extract(markup, 'http://www.nytimes.com/2016/02/15/us/politics/antonin-scalias-death-cuts-fierce-battle-lines-in-washington.html?hp&action=click&pgtype=Homepage&clickSource=story-heading&module=a-lede-package-region&region=top-news&WT.nav=top-news&_r=0')
    print ex

