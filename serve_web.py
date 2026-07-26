# ============================================================
# SmartAttend — Flutter Web SPA Local Server (Windows 11)
# Serves build/web on port 8080 with index.html fallback
# for Flutter Web page refresh routing support.
# ============================================================

import http.server
import socketserver
import os
import sys

PORT = 8080
WEB_DIR = os.path.join(os.path.dirname(__file__), "build", "web")

if not os.path.exists(WEB_DIR):
    print(f"❌ Error: {WEB_DIR} does not exist.")
    print("👉 Please run 'flutter build web --release' first!")
    sys.exit(1)

class SPARequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def do_GET(self):
        # Resolve request path
        path = self.translate_path(self.path)
        # If file/directory does not exist, fallback to index.html for SPA routing
        if not os.path.exists(path) and not '.' in os.path.basename(self.path):
            self.path = '/index.html'
        return super().do_GET()

if __name__ == "__main__":
    print(f"🚀 Serving Flutter Web SPA at http://localhost:{PORT}")
    print(f"📁 Web directory: {WEB_DIR}")
    print("Press Ctrl+C to stop.")
    with socketserver.TCPServer(("0.0.0.0", PORT), SPARequestHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n👋 Server stopped.")
