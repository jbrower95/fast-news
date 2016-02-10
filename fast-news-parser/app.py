from flask import Flask, request, jsonify
app = Flask(__name__)
import newspaper
import sys

@app.route("/")
def hello():
    return "Hello World!"

@app.route('/parse')
def parse():
    url = request.args['url']
    article = newspaper.Article(url, keep_article_html=True, request_timeout=4, fetch_images=False)
    print('article')
    article.download()
    print('download')
    article.parse()
    print('parse')
    d = {
        "title": article.title,
        "top_image": article.top_image,
        "authors": article.authors,
        "html": article.html,
        "article_html": article.article_html,
        "article_text": article.text,
        "images": list(article.images)
    }
    print('d')
    return jsonify(**d)

if __name__ == "__main__":
    # app.run(debug = 'debug' in sys.argv)
    app.run(debug=True)