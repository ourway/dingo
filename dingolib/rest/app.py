#!/usr/bin/env python
# -*- coding: utf-8 -*-

'''
Copyright: Farsheed Ashouri
Developed by: Farsheed Ashouri <farsheed@ashouri.org>
   ___              _                   _
  / __\_ _ _ __ ___| |__   ___  ___  __| |
 / _\/ _` | '__/ __| '_ \ / _ \/ _ \/ _` |
/ / | (_| | |  \__ \ | | |  __/  __/ (_| |
\/   \__,_|_|  |___/_| |_|\___|\___|\__,_|

'''

import falcon


class QuoteResource:
    def on_get(self, req, resp):
        """Handles GET requests"""
        quote = {'ping': 'pong'}
        resp.media = quote


application = falcon.API()
application.add_route('/api/ping', QuoteResource())
