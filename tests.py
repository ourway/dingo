import unittest
from unittest.mock import patch
from falcon import testing
from dingolib.rest.app import application


class FalconTestCase(testing.TestCase):
    def setUp(self):
        super(FalconTestCase, self).setUp()
        self.app = application


class TestApp(FalconTestCase):
    """ Tests for app.py wsgi app """

    def test_ping(self):
        doc = {u'ping': u'pong'}
        result = self.simulate_get('/api/ping')
        self.assertEqual(result.json, doc)


if __name__ == '__main__':
    unittest.main()
