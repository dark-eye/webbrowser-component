/*
 * Copyright 2013-2014 Canonical Ltd.
 *
 * This file is part of webbrowser-app.
 *
 * webbrowser-app is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * webbrowser-app is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.0
import Ubuntu.Components 0.1
import webbrowserapp.private 0.1
import "../actions" as Actions
import ".."

BrowserView {
    id: browser

    property alias currentIndex: tabsModel.currentIndex
    currentWebview: tabsModel.currentWebview

    property QtObject searchEngine

    actions: [
        Actions.GoTo {
            onTriggered: currentWebview.url = value
        },
        Actions.Back {
            enabled: currentWebview ? currentWebview.canGoBack : false
            onTriggered: currentWebview.goBack()
        },
        Actions.Forward {
            enabled: currentWebview ? currentWebview.canGoForward : false
            onTriggered: currentWebview.goForward()
        },
        Actions.Reload {
            enabled: currentWebview
            onTriggered: currentWebview.reload()
        },
        Actions.Bookmark {
            enabled: currentWebview
            onTriggered: _bookmarksModel.add(currentWebview.url, currentWebview.title, currentWebview.icon)
        },
        Actions.NewTab {
            onTriggered: openUrlInNewTab("", true)
        },
        Actions.ClearHistory {
            onTriggered: _historyModel.clearAll()
        }
    ]

    Item {
        id: previewsContainer

        width: webviewContainer.width
        height: webviewContainer.height
        y: webviewContainer.y

        Component {
            id: previewComponent

            ShaderEffectSource {
                id: preview

                width: parent.width
                height: parent.height

                onSourceItemChanged: {
                    if (!sourceItem) {
                        this.destroy()
                    }
                }

                live: mainView.visible && (browser.currentWebview === sourceItem)
            }
        }
    }

    Item {
        id: mainView

        anchors.fill: parent
        visible: !historyViewContainer.visible && !tabsViewContainer.visible

        Item {
            id: webviewContainer
            anchors {
                left: parent.left
                right: parent.right
                top: chrome.bottom
            }
            height: parent.height - chrome.visibleHeight - osk.height
        }

        ErrorSheet {
            anchors.fill: webviewContainer
            visible: currentWebview ? currentWebview.lastLoadFailed : false
            url: currentWebview ? currentWebview.url : ""
            onRefreshClicked: currentWebview.reload()
        }

        Chrome {
            id: chrome

            webview: browser.currentWebview
            searchUrl: browser.searchEngine ? browser.searchEngine.template : ""

            function isCurrentUrlBookmarked() {
                return (webview ? _bookmarksModel.contains(webview.url) : false)
            }
            bookmarked: isCurrentUrlBookmarked()
            onBookmarkedChanged: {
                if (bookmarked && !isCurrentUrlBookmarked()) {
                    _bookmarksModel.add(webview.url, webview.title, webview.icon)
                } else if (!bookmarked && isCurrentUrlBookmarked()) {
                    _bookmarksModel.remove(webview.url)
                }
            }
            onWebviewChanged: bookmarked = isCurrentUrlBookmarked()
            Connections {
                target: chrome.webview
                onUrlChanged: chrome.bookmarked = chrome.isCurrentUrlBookmarked()
            }
            Connections {
                target: _bookmarksModel
                onAdded: if (!chrome.bookmarked && (url === chrome.webview.url)) chrome.bookmarked = true
                onRemoved: if (chrome.bookmarked && (url === chrome.webview.url)) chrome.bookmarked = false
            }

            anchors {
                left: parent.left
                right: parent.right
            }
            height: units.gu(6)

            drawerActions: [
                Action {
                    objectName: "share"
                    text: i18n.tr("Share")
                    enabled: formFactor == "mobile"
                    onTriggered: {
                        var component = Qt.createComponent("../Share.qml")
                        if (component.status == Component.Ready) {
                            var share = component.createObject(browser)
                            share.onDone.connect(share.destroy)
                            share.shareLink(browser.currentWebview.url, browser.currentWebview.title)
                        }
                    }
                },
                Action {
                    objectName: "history"
                    text: i18n.tr("History")
                    iconName: "history"
                    onTriggered: historyViewComponent.createObject(historyViewContainer)
                },
                Action {
                    objectName: "tabs"
                    text: i18n.tr("Open tabs")
                    iconName: "browser-tabs"
                    onTriggered: tabsViewComponent.createObject(tabsViewContainer)
                },
                Action {
                    objectName: "newtab"
                    text: i18n.tr("New tab")
                    iconName: "tab-new"
                    onTriggered: browser.openUrlInNewTab("", true)
                }
            ]

            Connections {
                target: browser.currentWebview
                onLoadingChanged: {
                    if (browser.currentWebview.loading) {
                        chrome.state = "shown"
                    } else if (browser.currentWebview.fullscreen) {
                        chrome.state = "hidden"
                    }
                }
                onFullscreenChanged: {
                    if (browser.currentWebview.fullscreen) {
                        chrome.state = "hidden"
                    } else {
                        chrome.state = "shown"
                    }
                }
            }
        }

        ScrollTracker {
            webview: browser.currentWebview
            header: chrome

            active: !browser.currentWebview.fullscreen
            onScrolledUp: chrome.state = "shown"
            onScrolledDown: {
                if (nearBottom) {
                    chrome.state = "shown"
                } else if (!nearTop) {
                    chrome.state = "hidden"
                }
            }
        }

        Suggestions {
            opacity: ((chrome.state == "shown") && chrome.activeFocus && (count > 0) && !chrome.drawerOpen) ? 1.0 : 0.0
            Behavior on opacity {
                UbuntuNumberAnimation {}
            }
            enabled: opacity > 0
            anchors {
                top: chrome.bottom
                horizontalCenter: parent.horizontalCenter
            }
            width: chrome.width - units.gu(5)
            height: enabled ? Math.min(contentHeight, webviewContainer.height - units.gu(2)) : 0
            model: historyMatches
            onSelected: {
                browser.currentWebview.url = url
                browser.currentWebview.forceActiveFocus()
            }
        }
    }

    Item {
        id: tabsViewContainer

        visible: children.length > 0
        anchors.fill: parent

        Component {
            id: tabsViewComponent

            TabsView {
                anchors.fill: parent
                model: tabsModel
                onNewTabRequested: browser.openUrlInNewTab("", true)
                onDone: this.destroy()
            }
        }
    }

    Item {
        id: historyViewContainer

        visible: children.length > 0
        anchors.fill: parent

        function done() {
            for (var i in children) {
                children[i].destroy()
            }
        }

        Component {
            id: historyViewComponent

            HistoryView {
                anchors.fill: parent

                historyModel: _historyModel

                onHistoryEntryClicked: {
                    currentWebview.url = url
                    historyViewContainer.done()
                }
                onSeeMoreEntriesClicked: {
                    expandedHistoryViewComponent.createObject(historyViewContainer, {model: model, domain: expandedDomain})
                }
                onDone: historyViewContainer.done()
            }
        }

        Component {
            id: expandedHistoryViewComponent

            ExpandedHistoryView {
                anchors.fill: parent

                onHistoryEntryClicked: {
                    currentWebview.url = url
                    historyViewContainer.done()
                }
                onDone: this.destroy()
            }
        }
    }

    HistoryModel {
        id: _historyModel
        databasePath: dataLocation + "/history.sqlite"
    }

    HistoryMatchesModel {
        id: historyMatches
        sourceModel: _historyModel
        query: chrome.text
    }

    TabsModel {
        id: tabsModel
    }

    BookmarksModel {
        id: _bookmarksModel
        databasePath: dataLocation + "/bookmarks.sqlite"
    }

    Component {
        id: webviewComponent

        WebViewImpl {
            currentWebview: browser.currentWebview

            property var preview

            anchors.fill: parent

            readonly property bool current: currentWebview === this
            enabled: current
            visible: current

            //experimental.preferences.developerExtrasEnabled: developerExtrasEnabled
            preferences.localStorageEnabled: true
            preferences.appCacheEnabled: true

            contextualActions: ActionList {
                Actions.OpenLinkInNewTab {
                    enabled: contextualData.href.toString()
                    onTriggered: openUrlInNewTab(contextualData.href, true)
                }
                Actions.BookmarkLink {
                    enabled: contextualData.href.toString()
                    onTriggered: _bookmarksModel.add(contextualData.href, contextualData.title, "")
                }
                Actions.CopyLink {
                    enabled: contextualData.href.toString()
                    onTriggered: Clipboard.push([contextualData.href])
                }
                Actions.OpenImageInNewTab {
                    enabled: contextualData.img.toString()
                    onTriggered: openUrlInNewTab(contextualData.img, true)
                }
                Actions.CopyImage {
                    enabled: contextualData.img.toString()
                    onTriggered: Clipboard.push([contextualData.img])
                }
                Actions.SaveImage {
                    enabled: contextualData.img.toString() && downloadLoader.status == Loader.Ready
                    onTriggered: downloadLoader.item.downloadPicture(contextualData.img)
                }
            }

            onNewViewRequested: {
                var webview = webviewComponent.createObject(webviewContainer, {"request": request})
                internal.addTab(webview, true, false)
            }

            onLoadingChanged: {
                if (lastLoadSucceeded) {
                    _historyModel.add(url, title, icon)
                }
            }

            Loader {
                id: newTabViewLoader
                anchors.fill: parent

                sourceComponent: !parent.url.toString() ? newTabViewComponent : undefined

                Component {
                    id: newTabViewComponent

                    NewTabView {
                        anchors.fill: parent

                        historyModel: _historyModel
                        bookmarksModel: _bookmarksModel
                        onBookmarkClicked: {
                            currentWebview.url = url
                            currentWebview.forceActiveFocus()
                        }
                        onHistoryEntryClicked: {
                            currentWebview.url = url
                            currentWebview.forceActiveFocus()
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: downloadLoader
        source: formFactor == "desktop" ? "" : "../Downloader.qml"
    }

    QtObject {
        id: internal

        function addTab(webview, setCurrent, focusAddressBar) {
            var index = tabsModel.add(webview)
            if (setCurrent) {
                tabsModel.currentIndex = index
                if (focusAddressBar) {
                    chrome.forceActiveFocus()
                    Qt.inputMethod.show() // work around http://pad.lv/1316057
                }
            }
            webview.preview = previewComponent.createObject(previewsContainer, {sourceItem: webview})
        }
    }

    function openUrlInNewTab(url, setCurrent) {
        var webview = webviewComponent.createObject(webviewContainer, {"url": url})
        internal.addTab(webview, setCurrent, !url.toString())
    }
}
