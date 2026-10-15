from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

prototype = Path(__file__).resolve().parent / 'V2.html'
class Preview(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.split('?', 1)[0] not in ('/', '/V2.html'):
            self.send_error(404)
            return
        body = prototype.read_bytes()
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *args):
        pass

print('Preview ready at http://127.0.0.1:8766/V2.html', flush=True)
HTTPServer(('127.0.0.1', 8766), Preview).serve_forever()
