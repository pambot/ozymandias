from tornado.wsgi import WSGIContainer
from tornado.ioloop import IOLoop
from tornado.web import FallbackHandler, RequestHandler, Application
from app import app

class MainHandler(RequestHandler):
    def get(self):
        self.write("This message comes from Tornado ^_^")

tr = WSGIContainer(app)

tornado_app = Application([
    ('/ozymandias', MainHandler),
    ('/', FallbackHandler, dict(fallback=tr))])

if __name__ == "__main__":
    tornado_app.listen(80)
    IOLoop.instance().start()

