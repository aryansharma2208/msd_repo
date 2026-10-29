import json
import threading
import unittest
import urllib.error
import urllib.request

import app


class AppTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = app.make_server(0, host="127.0.0.1")  # port 0 = any free port
        cls.base = "http://127.0.0.1:%d" % cls.server.server_address[1]
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()

    def get(self, path):
        return urllib.request.urlopen(self.base + path, timeout=5)

    def test_root_returns_message(self):
        resp = self.get("/")
        self.assertEqual(resp.status, 200)
        self.assertIn("Hello", resp.read().decode())

    def test_health_returns_ok_json(self):
        resp = self.get("/health")
        self.assertEqual(resp.status, 200)
        self.assertEqual(resp.headers["Content-Type"], "application/json")
        self.assertEqual(json.loads(resp.read())["status"], "ok")

    def test_health_ignores_query_string(self):
        self.assertEqual(self.get("/health?probe=1").status, 200)

    def test_unknown_path_is_404(self):
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            self.get("/does-not-exist")
        self.assertEqual(ctx.exception.code, 404)


if __name__ == "__main__":
    unittest.main()
