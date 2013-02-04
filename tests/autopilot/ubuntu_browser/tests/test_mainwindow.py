# -*- Mode: Python; coding: utf-8; indent-tabs-mode: nil; tab-width: 4 -*-
# Copyright 2013 Canonical
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 3, as published
# by the Free Software Foundation.

"""Tests for the Browser"""

from __future__ import absolute_import

from testtools.matchers import Equals
from autopilot.matchers import Eventually

from ubuntu_browser.tests import BrowserTestCase, ChromelessBrowserTestCase

import unittest
import time
import os
from os import path
import tempfile


class TestMainWindowMixin(object):

    def setUp(self):
        super(TestMainWindowMixin, self).setUp()
        # This is needed to wait for the application to start.
        # In the testfarm, the application may take some time to show up.
        self.assertThat(self.main_window.get_qml_view().visible, Eventually(Equals(True)))

    def tearDown(self):
        super(TestMainWindowMixin, self).tearDown()


class TestMainWindow(BrowserTestCase, TestMainWindowMixin):

    """Tests the main browser features."""

    def test_open_website(self):
        address_bar = self.main_window.get_address_bar()
        self.pointing_device.move_to_object(address_bar)
        self.pointing_device.click()
        address_bar_clear_button = self.main_window.get_address_bar_clear_button()
        self.pointing_device.move_to_object(address_bar_clear_button)
        self.pointing_device.click()
        self.pointing_device.move_to_object(address_bar)
        self.pointing_device.click()

        self.keyboard.type("http://www.canonical.com")
        self.keyboard.press("Enter")

        web_view = self.main_window.get_web_view()
        self.assertThat(web_view.url, Eventually(Equals("http://www.canonical.com/")))

    def test_title(self):
        fd, path = tempfile.mkstemp(suffix=".html", text=True)
        os.write(fd, "<html><title>Alice in Wonderland</title><body><p>Lorem ipsum dolor sit amet.</p></body></html>")
        os.close(fd)

        address_bar = self.main_window.get_address_bar()
        self.pointing_device.move_to_object(address_bar)
        self.pointing_device.click()
        address_bar_clear_button = self.main_window.get_address_bar_clear_button()
        self.pointing_device.move_to_object(address_bar_clear_button)
        self.pointing_device.click()
        self.pointing_device.move_to_object(address_bar)
        self.pointing_device.click()
        self.keyboard.type("file://" + path)
        self.keyboard.press("Enter")

        window = self.main_window.get_qml_view()
        self.assertThat(window.title, Eventually(Equals("Alice in Wonderland - Ubuntu Web Browser")))

        os.remove(path)


class TestMainWindowChromeless(ChromelessBrowserTestCase, TestMainWindowMixin):

    """Tests the main browser features when run in chromeless mode."""

    def test_chrome_is_not_loaded(self):
        self.assertThat(self.main_window.get_chrome(), Equals(None))
