#!/usr/bin/env python
# -*- coding: utf-8 -*-

import logging

from waveapi import events
from waveapi import document
from waveapi import model
from waveapi import robot

#from google.appengine.api import users
#from google.appengine.ext import webapp
#from google.appengine.ext.webapp.util import run_wsgi_app
from google.appengine.ext import db

import pickle
import xmlrpclib


class Wave(db.Model):
	id = db.StringProperty()

	endpoint = db.StringProperty()
	user_id = db.StringProperty()
	user_pass = db.StringProperty()

	blog_id = db.IntegerProperty()
	publishing_unit = db.StringProperty()

	wave_id = db.IntegerProperty()

	blips = db.BlobProperty()
	blog_ids = db.StringListProperty()

	def GetBlips(self):
		if self.blips:
			return pickle.loads(self.blips)
		else:
			return {}

	def SetBlips(self, blips):
		self.blips = pickle.dumps(blips)

	def AddBlips(self, blips):
		tmp = self.GetBlips()
		for blip in blips:
			data = {}
			for k in blip.raw_data:
				data[k] = blip.raw_data[k]
			tmp[blip.GetId()] = data
		self.SetBlips(tmp)

	def ClearBlips(self):
		tmp = self.GetBlips()
		self.blips = None
		return tmp

	def HasBlipsToPublish(self):
		if self.blips == None:
			return 0
		else:
			return 1


def OnSelfAdded(properties, context):
	root_wavelet = context.GetRootWavelet()
	blip = root_wavelet.CreateBlip()
	doc = blip.GetDocument()

	w = Wave.gql('WHERE id = :id', id=root_wavelet.GetWaveId()).get()
	if not w:
		w = Wave()
		w.id = root_wavelet.GetWaveId()
	w.AddBlips(context.GetBlips())
	w.put()


	doc.AppendText('\n')

	elm = document.FormElement(document.ELEMENT_TYPE.LABEL, 'endpoint', 'Endpoint:')
	doc.AppendElement(elm)
	elm = document.FormElement(document.ELEMENT_TYPE.INPUT, 'endpoint')
	doc.AppendElement(elm)

	elm = document.FormElement(document.ELEMENT_TYPE.LABEL, 'user_id', 'Username:')
	doc.AppendElement(elm)
	elm = document.FormElement(document.ELEMENT_TYPE.INPUT, 'user_id')
	doc.AppendElement(elm)

	elm = document.FormElement(document.ELEMENT_TYPE.LABEL, 'user_pass', 'Password:')
	doc.AppendElement(elm)
#	elm = document.FormElement(document.ELEMENT_TYPE.PASSWORD, 'user_pass')
	elm = document.FormElement(document.ELEMENT_TYPE.INPUT, 'user_pass')
	doc.AppendElement(elm)

	elm = document.FormElement(document.ELEMENT_TYPE.BUTTON, 'create', 'Next')
	doc.AppendElement(elm)


def OnSelfRemoved(properties, context):
	root_wavelet = context.GetRootWavelet()
	w = Wave.gql('WHERE id = :id', id=root_wavelet.GetWaveId()).get()
	w.delete()
	logging.info('Removed')

def IntToStr(a_set):
	for k in a_set:
		if a_set[k].__class__ == int:
			a_set[k] = str(a_set[k])
		elif a_set[k].__class__ == dict:
			IntToStr(a_set[k])
	return a_set

def MakeContent(wave, context):
	root_wavelet = context.GetRootWavelet()
	blips = wave.ClearBlips()

	return {
		'id': wave.id,
		'publishing_unit': wave.publishing_unit,
		'participants': list(root_wavelet.participants),
		'title': root_wavelet.GetTitle(),
		'root_wavelet': IntToStr(root_wavelet.raw_data),
		'blips': IntToStr(blips),
	}


def OnUpdated(properties, context):
	root_wavelet = context.GetRootWavelet()

	w = Wave.gql('WHERE id = :id', id=root_wavelet.GetWaveId()).get()
	if not w:
		return

	w.AddBlips(context.GetBlips())

	if not w.blog_id or not w.publishing_unit or not w.wave_id:
		w.put()
		return


	content = MakeContent(w, context)
	w.put()

	server = xmlrpclib.ServerProxy(w.endpoint)
	wave_id = server.mt.editWave(
		w.wave_id, w.user_id, w.user_pass, content, 1
	)


def OnButtonClicked(properties, context):
	root_wavelet = context.GetRootWavelet()

	w = Wave.gql('WHERE id = :id', id=root_wavelet.GetWaveId()).get()
	if not w:
		return

	blip = context.GetBlipById(properties['blipId'])
	for elm in blip.GetElements().values():
		if elm.__class__ == document.FormElement:
			if elm.type == document.ELEMENT_TYPE.LABEL:
				continue
			for k in ['endpoint', 'user_id', 'user_pass', 'blog_id']:
				if elm.name == k:
					w.__setattr__(k, elm.value)
			if w.blog_ids:
				for i in w.blog_ids:
					k = 'blog_id_' + i
					if elm.name == k and elm.value == 'true':
						w.blog_id = int(i)
			if elm.name == 'publishing_unit_blip':
				if elm.value == 'true':
					w.publishing_unit = 'blip'
				else:
					w.publishing_unit = 'wave'

	server = xmlrpclib.ServerProxy(w.endpoint)
	if properties['button'] == 'select':
		# if not w.blog_id:
		# 	error

		doc = blip.GetDocument()
		doc.Clear()
		doc.AppendText('\n')
		doc.AppendText('\nOptions:\n')

		elm = document.FormElement(document.ELEMENT_TYPE.LABEL, 'publishing_unit_blip', 'Publishing each blip as entry:')
		doc.AppendElement(elm)
		elm = document.FormElement(document.ELEMENT_TYPE.CHECK, 'publishing_unit_blip')
		doc.AppendElement(elm)

		elm = document.FormElement(document.ELEMENT_TYPE.BUTTON, 'start', 'Start')
		doc.AppendText('\n')
		doc.AppendElement(elm)

	elif properties['button'] == 'start':
		publish = w.HasBlipsToPublish()
		content = MakeContent(w, context)

		try:
			wave_id = server.mt.newWave(
				w.blog_id, w.user_id, w.user_pass, content, publish
			)
		except xmlrpclib.Fault, e:
			doc = blip.GetDocument()
			doc.AppendText('\n')
			doc.AppendText(e.faultString)
		else:
			w.wave_id = int(wave_id)
			blip.Delete()

	else:
		try:
			blogs = server.blogger.getUsersBlogs('appkey', w.user_id, w.user_pass)
		except xmlrpclib.Fault, e:
			doc = blip.GetDocument()
			doc.AppendText('\n')
			doc.AppendText(e.faultString)
		else:
			doc = blip.GetDocument()
			doc.Clear()
			doc.AppendText('\n')
			doc.AppendText('\n')

			ids = []
			for b in blogs:
				elm = document.FormElement(
					document.ELEMENT_TYPE.CHECK, 'blog_id_' + b['blogid']
				)
				doc.AppendElement(elm)
				elm = document.FormElement(
					document.ELEMENT_TYPE.LABEL, 'blog_id_' + b['blogid'], ':' + b['blogName']
				)
				doc.AppendElement(elm)
				doc.AppendText('\n')

				ids.append(b['blogid'])

			w.blog_ids = ids

			elm = document.FormElement(
				document.ELEMENT_TYPE.BUTTON, 'select', 'Next'
			)
			doc.AppendElement(elm)

	w.put()



if __name__ == '__main__':
	bot = robot.Robot(
		'Google Wave for Movable Type', version='0.05',
		image_url='http://wave-for-mt.appspot.com/img/wave-for-mt_icon.png',
		profile_url='http://wave-for-mt.appspot.com/'
	)

	bot.RegisterHandler(events.WAVELET_SELF_ADDED, OnSelfAdded)
	bot.RegisterHandler(events.WAVELET_SELF_REMOVED, OnSelfRemoved)
	bot.RegisterHandler(events.FORM_BUTTON_CLICKED, OnButtonClicked)
	#bot.RegisterHandler(events.DOCUMENT_CHANGED, OnDocumentChanged)
	bot.RegisterHandler(events.BLIP_SUBMITTED, OnUpdated)
	bot.RegisterHandler(events.BLIP_DELETED, OnUpdated)

	bot.Run()
