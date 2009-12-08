#!/usr/bin/env python
# -*- coding: utf-8 -*-

import xmlrpclib

wl = {
	'endpoint': 'http://wh207/~taku/mt50/mt-wave.cgi',
	'user_id': 'taku',
	'user_pass': 'd4b29n09'
}

def getUsersBlogs():
	server = xmlrpclib.ServerProxy(wl['endpoint'])
	blogs = server.blogger.getUsersBlogs('appkey', wl['user_id'], wl['user_pass'])
	print blogs

if __name__ == '__main__':
	getUsersBlogs()
