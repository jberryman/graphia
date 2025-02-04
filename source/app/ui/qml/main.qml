/* Copyright © 2013-2020 Graphia Technologies Ltd.
 *
 * This file is part of Graphia.
 *
 * Graphia is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Graphia is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Graphia.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQml 2.8
import QtQuick 2.12
import QtQuick.Controls 1.5
import QtQuick.Controls.Styles 1.4
import QtQuick.Layouts 1.3
import QtQuick.Dialogs 1.2
import QtQuick.Window 2.2

import Qt.labs.platform 1.0 as Labs

import app.graphia 1.0
import "../../../shared/ui/qml/Utils.js" as Utils
import "../../../shared/ui/qml/Constants.js" as Constants

import "Loading"
import "Options"
import "Controls"
import "Enrichment"

ApplicationWindow
{
    id: mainWindow
    visible: false
    property var recentFiles
    property bool debugMenuUnhidden: false
    width: 1024
    height: 768
    minimumWidth: mainToolBar.visible ? mainToolBar.implicitWidth : 640
    minimumHeight: 480
    property bool maximised: mainWindow.visibility === Window.Maximized

    property TabUI currentTab: tabView.currentIndex < tabView.count ?
        tabView.getTab(tabView.currentIndex).item : null
    property var currentDocument: currentTab !== null ? currentTab.document : null

    property bool _anyTabsBusy:
    {
        for(let index = 0; index < tabView.count; index++)
        {
            let tab = tabView.getTab(index).item;
            if(tab !== null && tab.document.busy)
                return true;
        }

        return false;
    }

    title:
    {
        let text = "";
        if(currentTab !== null && currentTab.title.length > 0)
            text += currentTab.title + qsTr(" - ");

        text += application.name;

        return text;
    }

    Application { id: application }

    MessageDialog
    {
        id: noUpdatesMessageDialog
        icon: StandardIcon.Information
        title: qsTr("No Updates")
        text: qsTr("There are no updates available at this time.")
    }

    // Use Connections to avoid an M16 JS lint error
    Connections
    {
        target: application

        function onNoNewUpdateAvailable(existing)
        {
            if(checkForUpdatesAction.active)
            {
                if(existing)
                {
                    // While there is no /new/ update, there is an existing update
                    // available that the user has previously dismissed
                    newUpdate.visible = true;
                }
                else
                    noUpdatesMessageDialog.open();
            }

            checkForUpdatesAction.active = false;
        }

        function onNewUpdateAvailable()
        {
            checkForUpdatesAction.active = false;
            newUpdate.visible = true;
        }

        function onChangeLogStored()
        {
            changeLog.refresh();
        }
    }

    Tracking
    {
        id: tracking

        anchors.fill: parent

        visible: !validValues

        onTrackingDataEntered: { submit(); }

        function submit()
        {
            if(!validValues)
                return;

            application.submitTrackingData();

            // Deal with any arguments now that
            // we've collected a tracking identity
            processOnePendingArgument();
        }
    }

    function currentState()
    {
        let s = tabView.count + " tabs";

        for(let index = 0; index < tabView.count; index++)
        {
            if(s.length !== 0)
                s += "\n\n";

            s += "Tab " + index + ": ";
            let tab = tabView.getTab(index).item;
            if(tab === null)
            {
                s += "null";
                continue;
            }

            s += tab.title;
            s += "\n\n" + tab.document.graphSizeSummary();
            s += "\n\nParse Log:\n" + tab.document.log;

            let stack = tab.document.commandStackSummary();
            if(stack.length > 0)
                s += "\n\nCommand Stack:\n" + stack;

            let listToString = function(list, title)
            {
                if(list.length > 0)
                {
                    s += "\n\n" + title;
                    for(let row = 0; row < list.length; row++)
                        s += "\n  " + list[row];
                }
            };

            listToString(tab.document.transforms, "Transforms:");
            listToString(tab.document.visualisations, "Visualisations:");
        }

        s += "\n\nEnvironment:\n" + mainWindow.environment;

        return s;
    }

    property var _pendingArguments: []

    // This is called with the arguments of a second instance of the app,
    // when it starts then immediately exits
    function processArguments(arguments)
    {
        _pendingArguments = arguments.slice(1);
        processOnePendingArgument();
    }

    function processOnePendingArgument()
    {
        if(_pendingArguments.length === 0)
            return;

        let argument = "";
        do
        {
            // Pop
            argument = _pendingArguments[0];
            _pendingArguments.shift();
        }
        while(argument[0] === "-" && _pendingArguments.length > 0);

        // Ignore option style arguments
        if(argument.length === 0 || argument[0] === "-")
            return;

        let url = QmlUtils.urlForUserInput(argument);
        Qt.callLater(function()
        {
            // Queue this up to do later in the event loop, in case there
            // is any other plugin initialisation to do be done beforehand
            openFile(url, true);
        });
    }

    Component.onCompleted:
    {
        if(misc.recentFiles.length > 0)
            mainWindow.recentFiles = JSON.parse(misc.recentFiles);
        else
            mainWindow.recentFiles = [];

        if(windowPreferences.width !== undefined &&
           windowPreferences.height !== undefined &&
           windowPreferences.x !== undefined &&
           windowPreferences.y !== undefined)
        {
            mainWindow.width = windowPreferences.width;
            mainWindow.height = windowPreferences.height;
            mainWindow.x = windowPreferences.x;
            mainWindow.y = windowPreferences.y;

            // Make sure that the window doesn't appear off screen
            // This is basically a workaround for QTBUG-58419
            let rightEdge = mainWindow.x + mainWindow.width;
            let bottomEdge = mainWindow.y + mainWindow.height;

            if(mainWindow.x < 0)
                mainWindow.x = 0;
            else if(rightEdge > Screen.desktopAvailableWidth)
                mainWindow.x -= (rightEdge - Screen.desktopAvailableWidth);

            if(mainWindow.y < 0)
                mainWindow.y = 0;
            else if(bottomEdge > Screen.desktopAvailableHeight)
                mainWindow.y -= (bottomEdge - Screen.desktopAvailableHeight);
        }

        if(windowPreferences.maximised !== undefined)
        {
            mainWindow.visibility = Utils.castToBool(windowPreferences.maximised) ?
                Window.Maximized : Window.Windowed;
        }

        // Arguments minus the executable
        _pendingArguments = Qt.application.arguments.slice(1);

        mainWindow.visible = true;

        if(!misc.hasSeenTutorial)
        {
            let exampleFile = application.resourceFile("examples/Tutorial.graphia");

            if(QmlUtils.fileExists(exampleFile))
            {
                // Add it to the pending arguments, because it's highly
                // likely we're currently showing the tracking UI
                _pendingArguments.push(exampleFile);
            }
        }

        tracking.submit();
    }

    property bool _restartOnExit: false

    function restart()
    {
        _restartOnExit = true;
        mainWindow.close();
    }

    onClosing:
    {
        if(tabView.count > 0)
        {
            // Capture _restartOnExit so that we can restore its value after a non-cancel exit
            let closeTabFunction = function(restartOnExit)
            {
                return function()
                {
                    tabView.removeTab(0);
                    _restartOnExit = restartOnExit;
                    mainWindow.close();
                };
            }(_restartOnExit);

            // Reset the value of _restartOnExit so that if the user cancels an exit, any
            // subsequent future exit doesn't then also restart
            _restartOnExit = false;

            // If any tabs are open, close the first one and cancel the window close, followed
            // by (recursive) calls to clostTabFunction, assuming the user doesn't cancel
            tabView.closeTab(0, closeTabFunction);

            close.accepted = false;
            return;
        }

        windowPreferences.maximised = mainWindow.maximised;

        if(!mainWindow.maximised)
        {
            windowPreferences.width = mainWindow.width;
            windowPreferences.height = mainWindow.height;
            windowPreferences.x = mainWindow.x;
            windowPreferences.y = mainWindow.y;
        }

        Qt.exit(!_restartOnExit ?
            ExitType.NormalExit :
            ExitType.Restart);
    }

    MessageDialog
    {
        id: errorOpeningFileMessageDialog
        icon: StandardIcon.Critical
        title: qsTr("Error Opening File")

        onAccepted:
        {
            // Even if a file failed to load, there may be more to process
            processOnePendingArgument();
        }
    }

    OptionsDialog
    {
        id: optionsDialog

        enabled: !mainWindow._anyTabsBusy
    }

    AboutDialog
    {
        id: aboutDialog
        application: application

        onHiddenSwitchActivated:
        {
            console.log("Debug menu enabled");
            mainWindow.debugMenuUnhidden = true;
        }
    }

    AboutPluginsDialog
    {
        id: aboutpluginsDialog
        pluginDetails: application.pluginDetails
    }

    ChangeLog { id: changeLog }
    LatestChangesDialog
    {
        id: latestChangesDialog

        text: changeLog.text
        version: application.version
    }

    readonly property string environment:
    {
        let s = "";
        let environment = application.environment;

        for(let i = 0; i < environment.length; i++)
        {
            if(s.length !== 0)
                s += "\n";

            s += environment[i];
        }

        return s;
    }

    TextDialog
    {
        id: environmentDialog
        text: mainWindow.environment
    }

    TextDialog
    {
        id: provenanceLogDialog
        title: qsTr("Provenance Log")
        text: currentDocument !== null ? currentDocument.log : ""
    }

    Preferences
    {
        id: windowPreferences
        section: "window"
        property var width
        property var height
        property var maximised
        property var x
        property var y
    }

    Preferences
    {
        id: misc
        section: "misc"
        property alias showGraphMetrics: toggleGraphMetricsAction.checked

        property var fileOpenInitialFolder
        property string recentFiles
        property bool hasSeenTutorial
        property string update
    }

    Preferences
    {
        id: visuals
        section: "visuals"
        property int edgeVisualType:
        {
            return toggleEdgeDirectionAction.checked ? EdgeVisualType.Arrow
                                                     : EdgeVisualType.Cylinder;
        }
        property int showNodeText:
        {
            switch(nodeTextDisplay.current)
            {
            default:
            case hideNodeTextAction:         return TextState.Off;
            case showFocusedNodeTextAction:  return TextState.Focused;
            case showSelectedNodeTextAction: return TextState.Selected;
            case showAllNodeTextAction:      return TextState.All;
            }
        }
        property int showEdgeText:
        {
            switch(edgeTextDisplay.current)
            {
            default:
            case hideEdgeTextAction:         return TextState.Off;
            case showSelectedEdgeTextAction: return TextState.Selected;
            case showAllEdgeTextAction:      return TextState.All;
            }
        }
        property alias showMultiElementIndicators: toggleMultiElementIndicatorsAction.checked
    }

    Preferences
    {
        section: "debug"
        property alias showFpsMeter: toggleFpsMeterAction.checked
        property alias saveGlyphMaps: toggleGlyphmapSaveAction.checked
    }

    function addToRecentFiles(fileUrl)
    {
        let fileUrlString = fileUrl.toString();

        if(mainWindow.recentFiles === undefined)
            mainWindow.recentFiles = [];

        let localRecentFiles = mainWindow.recentFiles;

        // Remove any duplicates
        for(let i = 0; i < localRecentFiles.length; i++)
        {
            if(localRecentFiles[i] === fileUrlString)
            {
                localRecentFiles.splice(i, 1);
                break;
            }
        }

        // Add to the top
        localRecentFiles.unshift(fileUrlString);

        let MAX_RECENT_FILES = 10;
        while(localRecentFiles.length > MAX_RECENT_FILES)
            localRecentFiles.pop();

        mainWindow.recentFiles = localRecentFiles;
        misc.recentFiles = JSON.stringify(localRecentFiles);
    }

    function openFile(fileUrl, inNewTab)
    {
        fileUrl = fileUrl.toString().trim();

        // If the file name is empty, avoid doing anything with it
        if(fileUrl.length === 0)
            return;

        if(!QmlUtils.fileUrlExists(fileUrl))
        {
            errorOpeningFileMessageDialog.title = qsTr("File Not Found");
            errorOpeningFileMessageDialog.text = QmlUtils.baseFileNameForUrl(fileUrl) +
                    qsTr(" does not exist.");
            errorOpeningFileMessageDialog.open();
            return;
        }

        let fileTypes = application.urlTypesOf(fileUrl);

        if(fileTypes.length === 0)
        {
            errorOpeningFileMessageDialog.text = "";

            let failureReasons = application.failureReasons(fileUrl);
            if(failureReasons.length === 0)
            {
                errorOpeningFileMessageDialog.title = qsTr("Unknown File Type");
                errorOpeningFileMessageDialog.text = QmlUtils.baseFileNameForUrl(fileUrl) +
                    qsTr(" cannot be loaded as its file type is unknown.");
            }
            else
            {
                errorOpeningFileMessageDialog.title = qsTr("Failed To Load");
                if(failureReasons.length > 0)
                    errorOpeningFileMessageDialog.text += failureReasons[0];
            }

            errorOpeningFileMessageDialog.open();
            return;
        }

        if(!application.canOpenAnyOf(fileTypes))
        {
            errorOpeningFileMessageDialog.title = qsTr("Can't Open File");
            errorOpeningFileMessageDialog.text = QmlUtils.baseFileNameForUrl(fileUrl) +
                    qsTr(" cannot be loaded."); //FIXME more elaborate error message
            errorOpeningFileMessageDialog.open();
            return;
        }

        if(fileTypes.length > 1)
        {
            fileTypeChooserDialog.fileUrl = fileUrl
            fileTypeChooserDialog.fileTypes = fileTypes;
            fileTypeChooserDialog.inNewTab = inNewTab;
            fileTypeChooserDialog.open();
        }
        else
            openFileOfType(fileUrl, fileTypes[0], inNewTab);
    }

    FileTypeChooserDialog
    {
        id: fileTypeChooserDialog
        application: application
        model: application.urlTypeDetails
        onAccepted: openFileOfType(fileUrl, fileType, inNewTab)
    }

    function openFileOfType(fileUrl, fileType, inNewTab)
    {
        let onSaveConfirmed = function()
        {
            let pluginNames = application.pluginNames(fileType);

            if(pluginNames.length > 1)
            {
                pluginChooserDialog.fileUrl = fileUrl
                pluginChooserDialog.fileType = fileType;
                pluginChooserDialog.pluginNames = pluginNames;
                pluginChooserDialog.inNewTab = inNewTab;
                pluginChooserDialog.open();
            }
            else
                openFileOfTypeWithPlugin(fileUrl, fileType, pluginNames[0], inNewTab);
        };

        if(currentTab !== null && !inNewTab)
            currentTab.confirmSave(onSaveConfirmed);
        else
            onSaveConfirmed();
    }

    PluginChooserDialog
    {
        id: pluginChooserDialog
        application: application
        model: application.pluginDetails
        onAccepted: openFileOfTypeWithPlugin(fileUrl, fileType, pluginName, inNewTab)
    }

    function openFileOfTypeWithPlugin(fileUrl, fileType, pluginName, inNewTab)
    {
        let parametersQmlPath = application.parametersQmlPathForPlugin(pluginName, fileType);

        if(parametersQmlPath.length > 0)
        {
            let component = Qt.createComponent(parametersQmlPath);
            if(component.status !== Component.Ready)
            {
                console.log("Error loading parameters QML: " + component.errorString());
                return;
            }

            let contentObject = component.createObject(this);
            if(contentObject === null)
            {
                console.log(parametersQmlPath + ": failed to create instance");
                return;
            }

            if(!isValidParameterDialog(contentObject))
            {
                console.log("Failed to load Parameters dialog for " + pluginName);
                console.log("Parameters QML must use BaseParameterDialog as root object");
                return;
            }

            contentObject.fileUrl = fileUrl
            contentObject.fileType = fileType;
            contentObject.pluginName = pluginName;
            contentObject.inNewTab = inNewTab;

            contentObject.accepted.connect(function()
            {
                openFileOfTypeWithPluginAndParameters(contentObject.fileUrl,
                    contentObject.fileType, contentObject.pluginName,
                    contentObject.parameters, contentObject.inNewTab);
            });

            // Offset parameters position from top left of main window
            contentObject.x = x + (width * 0.3);
            contentObject.y = y + (height * 0.3);

            contentObject.show();
        }
        else
            openFileOfTypeWithPluginAndParameters(fileUrl, fileType, pluginName, {}, inNewTab);
    }

    function isValidParameterDialog(element)
    {
        if (element['parameters'] === undefined ||
            element['fileUrl'] === undefined ||
            element['fileType'] === undefined ||
            element['pluginName'] === undefined ||
            element['inNewTab'] === undefined ||
            element['show'] === undefined ||
            element['accepted'] === undefined)
        {
            return false;
        }

        return true;
    }

    function openFileOfTypeWithPluginAndParameters(fileUrl, fileType, pluginName, parameters, inNewTab)
    {
        let openInCurrentTab = function()
        {
            tabView.openInCurrentTab(fileUrl, fileType, pluginName, parameters);
        };

        if(currentTab !== null && !inNewTab)
            tabView.replaceTab(openInCurrentTab);
        else
            tabView.createTab(openInCurrentTab);
    }

    Labs.FileDialog
    {
        id: fileOpenDialog
        nameFilters: application.nameFilters
        onAccepted:
        {
            misc.fileOpenInitialFolder = folder.toString();
            openFile(file, inTab);
        }

        property bool inTab: false
    }

    Action
    {
        id: fileOpenAction
        iconName: "document-open"
        text: qsTr("&Open…")
        shortcut: "Ctrl+O"
        onTriggered:
        {
            fileOpenDialog.title = qsTr("Open File…");
            fileOpenDialog.inTab = false;

            if(misc.fileOpenInitialFolder !== undefined)
                fileOpenDialog.folder = misc.fileOpenInitialFolder;

            fileOpenDialog.open();
        }
    }

    Action
    {
        id: fileOpenInTabAction
        iconName: "tab-new"
        text: qsTr("Open In New &Tab…")
        shortcut: "Ctrl+T"
        onTriggered:
        {
            fileOpenDialog.title = qsTr("Open File In New Tab…");
            fileOpenDialog.inTab = true;

            if(misc.fileOpenInitialFolder !== undefined)
                fileOpenDialog.folder = misc.fileOpenInitialFolder;

            fileOpenDialog.open();
        }
    }

    Action
    {
        id: fileSaveAction
        iconName: "document-save"
        text: qsTr("&Save")
        shortcut: "Ctrl+S"
        enabled: currentTab && currentDocument && !currentDocument.busy
        onTriggered:
        {
            if(currentTab === null)
                return;

            currentTab.saveFile();
        }
    }

    Action
    {
        id: fileSaveAsAction
        iconName: "document-save-as"
        text: qsTr("&Save As…")
        enabled: currentTab && currentDocument && !currentDocument.busy
        onTriggered:
        {
            if(currentTab === null)
                return;

            currentTab.saveAsFile();
        }
    }

    Action
    {
        id: closeTabAction
        iconName: "window-close"
        text: qsTr("&Close Tab")
        shortcut: "Ctrl+W"
        enabled: currentTab !== null
        onTriggered:
        {
            // If we're currently busy, cancel and wait before closing
            if(currentDocument.significantCommandInProgress)
            {
                // If a load is cancelled the tab is closed automatically,
                // and there is no command involved anyway, so in that case we
                // don't need to wait for the command to complete
                if(currentDocument.loadComplete)
                {
                    // Capture the document by value so we can use it to work out
                    // which tab to close once the command is complete
                    let closeTabFunction = function(tab)
                    {
                        return function()
                        {
                            tab.commandComplete.disconnect(closeTabFunction);
                            tabView.closeTab(tabView.findTabIndex(tab));
                        };
                    }(currentTab);

                    currentTab.commandComplete.connect(closeTabFunction);
                }

                if(currentDocument.commandIsCancellable)
                    currentDocument.cancelCommand();
            }
            else
                tabView.closeTab(tabView.currentIndex);
        }
    }

    Action
    {
        id: closeAllTabsAction
        iconName: "window-close"
        text: qsTr("Close &All Tabs")
        shortcut: "Ctrl+Shift+W"
        enabled: currentTab !== null
        onTriggered:
        {
            if(tabView.count > 0)
            {
                // If any tabs are open, close the first one...
                tabView.closeTab(0, function()
                {
                    // ...then (recursively) resume closing if the user doesn't cancel
                    tabView.removeTab(0);
                    closeAllTabsAction.trigger();
                });
            }
        }
    }

    Action
    {
        id: quitAction
        iconName: "application-exit"
        text: qsTr("&Quit")
        shortcut: "Ctrl+Q"
        onTriggered: { mainWindow.close(); }
    }

    Action
    {
        id: undoAction
        iconName: "edit-undo"
        text: currentDocument ? currentDocument.nextUndoAction : qsTr("&Undo")
        shortcut: "Ctrl+Z"
        enabled: currentDocument ? currentDocument.canUndo : false
        onTriggered:
        {
            if(currentDocument)
                currentDocument.undo();
        }
    }

    Action
    {
        id: redoAction
        iconName: "edit-redo"
        text: currentDocument ? currentDocument.nextRedoAction : qsTr("&Redo")
        shortcut: "Ctrl+Shift+Z"
        enabled: currentDocument ? currentDocument.canRedo : false
        onTriggered:
        {
            if(currentDocument)
                currentDocument.redo();
        }
    }

    Action
    {
        id: deleteAction
        iconName: "edit-delete"
        text: qsTr("&Delete Selection")
        shortcut: "Del"
        property bool visible: currentDocument ?
            currentDocument.canDeleteSelection : false
        enabled: currentDocument ? !currentDocument.busy && visible : false
        onTriggered: { currentDocument.deleteSelectedNodes(); }
    }

    Action
    {
        id: selectAllAction
        iconName: "edit-select-all"
        text: qsTr("Select &All")
        shortcut: "Ctrl+Shift+A"
        enabled: currentDocument ? !currentDocument.busy : false
        onTriggered:
        {
            if(currentDocument)
                currentDocument.selectAll();
        }
    }

    Action
    {
        id: selectAllVisibleAction
        iconName: "edit-select-all"
        text: qsTr("Select All &Visible")
        shortcut: "Ctrl+A"
        enabled: currentDocument ? !currentDocument.busy : false
        onTriggered:
        {
            if(currentDocument)
                currentDocument.selectAllVisible();
        }
    }

    Action
    {
        id: selectNoneAction
        text: qsTr("Select &None")
        shortcut: "Ctrl+N"
        enabled: currentDocument ? !currentDocument.busy : false
        onTriggered:
        {
            if(currentDocument)
                currentDocument.selectNone();
        }
    }

    Action
    {
        id: selectSourcesAction
        text: qsTr("Select Sources of Selection")
        property bool visible: currentDocument ?
            currentDocument.directed && !currentDocument.nodeSelectionEmpty : false
        enabled: currentDocument ? !currentDocument.busy && visible : false
        onTriggered:
        {
            if(currentTab)
                currentTab.selectSources();
        }
    }

    Action
    {
        id: selectTargetsAction
        text: qsTr("Select Targets of Selection")
        property bool visible: currentDocument ?
            currentDocument.directed && !currentDocument.nodeSelectionEmpty : false
        enabled: currentDocument ? !currentDocument.busy && visible : false
        onTriggered:
        {
            if(currentTab)
                currentTab.selectTargets();
        }
    }

    Action
    {
        id: selectNeighboursAction
        text: qsTr("Select Neigh&bours of Selection")
        shortcut: "Ctrl+B"
        property bool visible: currentDocument ?
            !currentDocument.nodeSelectionEmpty : false
        enabled: currentDocument ? !currentDocument.busy && visible : false
        onTriggered:
        {
            if(currentTab)
                currentTab.selectNeighbours();
        }
    }

    Action
    {
        id: repeatLastSelectionAction
        text: currentTab ? currentTab.repeatLastSelectionMenuText :
            qsTr("Repeat Last Selection")

        shortcut: "Ctrl+R"
        enabled: currentTab && currentTab.canRepeatLastSelection
        onTriggered:
        {
            if(currentTab)
                currentTab.repeatLastSelection();
        }
    }

    Action
    {
        id: invertSelectionAction
        text: qsTr("&Invert Selection")
        shortcut: "Ctrl+I"
        enabled: currentDocument ? !currentDocument.busy : false
        onTriggered:
        {
            if(currentDocument)
                currentDocument.invertSelection();
        }
    }

    Action
    {
        id: findAction
        iconName: "edit-find"
        text: qsTr("&Find")
        shortcut: "Ctrl+F"
        enabled: currentDocument ? !currentDocument.busy : false
        onTriggered:
        {
            if(currentTab)
                currentTab.showFind(Find.Simple);
        }
    }

    Action
    {
        id: advancedFindAction
        iconName: "edit-find"
        text: qsTr("Advanced Find")
        shortcut: "Ctrl+Shift+F"
        enabled: currentDocument ? !currentDocument.busy : false
        onTriggered:
        {
            if(currentTab)
                currentTab.showFind(Find.Advanced);
        }
    }

    Action
    {
        id: findByAttributeAction
        iconName: "edit-find-replace"
        text: qsTr("Find By Attribute Value")
        shortcut: "Ctrl+H"
        enabled:
        {
            if(currentDocument)
                return !currentDocument.busy && currentTab.numAttributesWithSharedValues > 0;

            return false;
        }

        onTriggered:
        {
            if(currentTab)
                currentTab.showFind(Find.ByAttribute);
        }
    }

    Action
    {
        id: prevComponentAction
        text: qsTr("Goto &Previous Component")
        shortcut: "PgUp"
        enabled: currentDocument ? currentDocument.canChangeComponent : false
        onTriggered:
        {
            if(currentDocument)
                currentDocument.gotoPrevComponent();
        }
    }

    Action
    {
        id: nextComponentAction
        text: qsTr("Goto &Next Component")
        shortcut: "PgDown"
        enabled: currentDocument ? currentDocument.canChangeComponent : false
        onTriggered:
        {
            if(currentDocument)
                currentDocument.gotoNextComponent();
        }
    }

    Action
    {
        id: optionsAction
        enabled: !mainWindow._anyDocumentsBusy
        iconName: "applications-system"
        text: qsTr("&Options…")
        onTriggered:
        {
            optionsDialog.raise();
            optionsDialog.show();
        }
    }

    Action
    {
        id: enrichmentAction
        text: qsTr("Enrichment…")
        enabled: currentDocument !== null && !currentDocument.busy
        onTriggered:
        {
            if(currentDocument !== null)
            {
                if(enrichmentResults.models.length > 0)
                    enrichmentResults.show();
                else
                    enrichmentWizard.show();
            }
        }
    }

    TextMetrics
    {
        id: elidedNodeName

        elide: Text.ElideMiddle
        elideWidth: 200
        text: searchWebAction.enabled ?
            currentDocument.nodeName(searchWebAction._selectedNodeId) : ""
    }

    Action
    {
        id: searchWebAction
        text: enabled ? qsTr("Search Web for '") + elidedNodeName.elidedText + qsTr("'…") :
            qsTr("Search Web for Selected Node…")

        property var _selectedNodeId:
        {
            if(currentDocument === null || currentDocument.numHeadNodesSelected !== 1)
                return null;

            return currentDocument.selectedHeadNodeIds[0];
        }

        enabled: currentTab !== null && _selectedNodeId !== null
        onTriggered:
        {
            currentTab.searchWebForNode(_selectedNodeId);
        }
    }

    ImportAttributesDialog
    {
        id: importAttributesDialog
        document: currentDocument
    }

    Labs.FileDialog
    {
        id: importAttributesFileOpenDialog
        nameFilters:
        [
            "All Files (*.csv *.tsv *.ssv *.xlsx)",
            "CSV Files (*.csv)",
            "TSV Files (*.tsv)",
            "SSV Files (*.ssv)",
            "Excel Files (*.xlsx)"
        ]

        onAccepted:
        {
            misc.fileOpenInitialFolder = folder.toString();
            importAttributesDialog.open(file);
        }
    }

    Action
    {
        id: importAttributesAction
        text: qsTr("Import Attributes From Table…")
        enabled: currentDocument !== null && !currentDocument.busy
        onTriggered:
        {
            if(misc.fileOpenInitialFolder !== undefined)
                importAttributesFileOpenDialog.folder = misc.fileOpenInitialFolder;

            importAttributesFileOpenDialog.open();
        }
    }

    Action
    {
        id: pauseLayoutAction
        iconName:
        {
            let layoutPauseState = currentDocument ? currentDocument.layoutPauseState : -1;

            switch(layoutPauseState)
            {
            case LayoutPauseState.Paused:          return "media-playback-start";
            case LayoutPauseState.RunningFinished: return "media-playback-stop";
            default:
            case LayoutPauseState.Running:         return "media-playback-pause";
            }
        }

        text: currentDocument && currentDocument.layoutPauseState === LayoutPauseState.Paused ?
                  qsTr("&Resume Layout") : qsTr("&Pause Layout")
        shortcut: "Pause"
        enabled: currentDocument ? !currentDocument.busy : false
        onTriggered:
        {
            if(currentDocument)
                currentDocument.toggleLayout();
        }
    }

    Action
    {
        id: toggleLayoutSettingsAction
        iconName: "applications-system"
        text: Qt.platform.os === "osx" ? qsTr("Layout Settings…") : qsTr("Settings…")
        shortcut: "Ctrl+L"
        enabled: currentTab && currentDocument && !currentDocument.busy

        onTriggered:
        {
            if(currentTab)
                currentTab.showLayoutSettings();
        }
    }

    Action
    {
        id: exportNodePositionsAction
        text: qsTr("Export To File…")
        enabled: currentTab && currentDocument && !currentDocument.busy

        onTriggered:
        {
            if(currentTab)
                currentTab.exportNodePositions();
        }
    }

    Action
    {
        id: overviewModeAction
        iconName: "view-fullscreen"
        text: qsTr("&Overview Mode")
        enabled: currentDocument ? currentDocument.canEnterOverviewMode : false
        onTriggered:
        {
            if(currentDocument)
                currentDocument.switchToOverviewMode();
        }
    }

    Action
    {
        id: resetViewAction
        iconName: "view-refresh"
        text: qsTr("&Reset View")
        enabled: currentDocument ? currentDocument.canResetView : false
        onTriggered:
        {
            if(currentDocument)
                currentDocument.resetView();
        }
    }

    Action
    {
        id: toggleGraphMetricsAction
        text: qsTr("Show Graph Metrics")
        checkable: true
    }

    Action
    {
        id: toggleEdgeDirectionAction
        text: qsTr("Show Edge Direction")
        checkable: true

        Component.onCompleted:
        {
            toggleEdgeDirectionAction.checked = !(visuals.edgeVisualType === EdgeVisualType.Cylinder);
        }
    }

    Action
    {
        id: addBookmarkAction
        iconName: "list-add"
        text: qsTr("Add Bookmark…")
        shortcut: "Ctrl+D"
        enabled: currentDocument ? !currentDocument.busy && currentDocument.numNodesSelected > 0 : false
        onTriggered:
        {
            if(currentTab !== null)
                currentTab.showAddBookmark();
        }
    }

    ManageBookmarks
    {
        id: manageBookmarks
        document: currentDocument
    }

    Action
    {
        id: manageBookmarksAction
        text: qsTr("Manage Bookmarks…")
        enabled: currentDocument ? !currentDocument.busy && currentDocument.bookmarks.length > 0 : false
        onTriggered:
        {
            manageBookmarks.raise();
            manageBookmarks.show();
        }
    }

    Action
    {
        id: activateAllBookmarksAction
        text: qsTr("Activate All Bookmarks")
        enabled: currentDocument ? !currentDocument.busy && currentDocument.bookmarks.length > 1 : false
        onTriggered:
        {
            if(currentTab !== null)
                currentTab.gotoAllBookmarks();
        }
    }

    ExclusiveGroup
    {
        id: nodeTextDisplay

        Action { id: hideNodeTextAction; text: qsTr("None"); checkable: true; }
        Action { id: showFocusedNodeTextAction; text: qsTr("Focused"); checkable: true; }
        Action { id: showSelectedNodeTextAction; text: qsTr("Selected"); checkable: true; }
        Action { id: showAllNodeTextAction; text: qsTr("All"); checkable: true; }

        Component.onCompleted:
        {
            switch(visuals.showNodeText)
            {
            default:
            case TextState.Off:      nodeTextDisplay.current = hideNodeTextAction; break;
            case TextState.Focused:  nodeTextDisplay.current = showFocusedNodeTextAction; break;
            case TextState.Selected: nodeTextDisplay.current = showSelectedNodeTextAction; break;
            case TextState.All:      nodeTextDisplay.current = showAllNodeTextAction; break;
            }
        }
    }

    ExclusiveGroup
    {
        id: edgeTextDisplay

        Action { id: hideEdgeTextAction; text: qsTr("None"); checkable: true; }
        Action { id: showSelectedEdgeTextAction; text: qsTr("Selected"); checkable: true; }
        Action { id: showAllEdgeTextAction; text: qsTr("All"); checkable: true; }

        Component.onCompleted:
        {
            switch(visuals.showEdgeText)
            {
            default:
            case TextState.Off:      edgeTextDisplay.current = hideEdgeTextAction; break;
            case TextState.Selected: edgeTextDisplay.current = showSelectedEdgeTextAction; break;
            case TextState.All:      edgeTextDisplay.current = showAllEdgeTextAction; break;
            }
        }
    }

    ExclusiveGroup
    {
        id: projection

        Action
        {
            id: perspecitveProjectionAction
            enabled: currentDocument ? !currentDocument.busy : false
            text: qsTr("Perspective")
            checkable: true
            onCheckedChanged:
            {
                if(currentDocument !== null && checked)
                {
                    currentDocument.setProjection(Projection.Perspective);
                    updateShadingMode(currentDocument);
                }
            }
        }

        Action
        {
            id: orthographicProjectionAction
            enabled: currentDocument ? !currentDocument.busy : false
            text: qsTr("Orthographic")
            checkable: true
            onCheckedChanged:
            {
                if(currentDocument !== null && checked)
                {
                    currentDocument.setProjection(Projection.Orthographic);
                    updateShadingMode(currentDocument);
                }
            }
        }

        Action
        {
            id: twoDeeProjectionAction
            enabled: currentDocument ? !currentDocument.busy : false
            text: qsTr("2D")
            checkable: true
            onCheckedChanged:
            {
                if(currentDocument !== null && checked)
                {
                    currentDocument.setProjection(Projection.TwoDee);
                    updateShadingMode(currentDocument);
                }
            }
        }
    }

    ExclusiveGroup
    {
        id: shading

        Action
        {
            id: smoothShadingAction
            enabled: currentDocument ? !currentDocument.busy : false
            text: qsTr("Smooth Shading")
            checkable: true
            onCheckedChanged:
            {
                if(currentDocument !== null && checked)
                    currentDocument.setShading(Shading.Smooth);
            }
        }

        Action
        {
            id: flatShadingAction
            enabled: currentDocument ? !currentDocument.busy : false
            text: qsTr("Flat Shading")
            checkable: true
            onCheckedChanged:
            {
                if(currentDocument !== null && checked)
                    currentDocument.setShading(Shading.Flat);
            }
        }
    }

    Action
    {
        id: toggleMultiElementIndicatorsAction
        text: qsTr("Show Multi-Element Indicators")
        checkable: true
    }

    Action
    {
        id: dumpGraphAction
        text: qsTr("Dump graph to qDebug")
        enabled: application.debugEnabled
        onTriggered: currentDocument && currentDocument.dumpGraph()
    }

    Action
    {
        id: dumpCommandStackAction
        text: qsTr("Dump command stack to qDebug")
        enabled: application.debugEnabled
        onTriggered:
        {
            if(currentDocument)
                console.log(currentDocument.commandStackSummary());
        }
    }

    Action
    {
        id: reportScopeTimersAction
        text: qsTr("Report Scope Timers")
        onTriggered: { application.reportScopeTimers(); }
    }

    Action
    {
        id: restartAction
        text: qsTr("Restart")
        onTriggered: { mainWindow.restart(); }
    }

    MessageDialog
    {
        id: commandLineArgumentsMessageDialog
        icon: StandardIcon.Information
        title: qsTr("Command Line Arguments")

        text:
        {
            let text = "Arguments:\n\n";
            return text + JSON.stringify(application.arguments, null, 4);
        }
    }

    Action
    {
        id: showCommandLineArgumentsAction
        text: qsTr("Show Command Line Arguments")
        onTriggered: { commandLineArgumentsMessageDialog.open(); }
    }

    Action
    {
        id: showEnvironmentAction
        text: qsTr("Show Environment")
        onTriggered: { environmentDialog.show(); }
    }

    Action
    {
        id: saveImageAction
        iconName: "camera-photo"
        text: qsTr("Save As Image…")
        enabled: currentTab && currentDocument && !currentDocument.busy
        onTriggered:
        {
            if(currentTab)
                currentTab.screenshot();
        }
    }

    Action
    {
        id: toggleFpsMeterAction
        text: qsTr("Show FPS Meter")
        checkable: true
    }

    Action
    {
        id: toggleGlyphmapSaveAction
        text: qsTr("Save Glyphmaps on Regeneration")
        checkable: true
    }

    Action
    {
        id: togglePluginMinimiseAction
        shortcut: "Ctrl+M"
        iconName: currentTab && currentTab.pluginMinimised ? "go-top" : "go-bottom"
        text: currentTab ? (currentTab.pluginMinimised ? qsTr("Restore ") : qsTr("Minimise ")) +
            currentDocument.pluginName : ""
        enabled: currentDocument && currentDocument.hasPluginUI && !currentTab.pluginPoppedOut

        onTriggered:
        {
            if(currentTab)
                currentTab.toggleMinimise();
        }
    }

    Shortcut
    {
        enabled: currentTab && !currentTab.panelVisible
        sequence: "Esc"
        onActivated:
        {
            if(currentDocument.canEnterOverviewMode)
                overviewModeAction.trigger();
            else if(currentDocument.canResetView)
                resetViewAction.trigger();
            else if(currentDocument.hasPluginUI && !currentTab.pluginPoppedOut)
                togglePluginMinimiseAction.trigger();
       }
    }

    Action
    {
        id: togglePluginWindowAction
        iconName: "preferences-system-windows"
        text: currentDocument ? qsTr("Display ") + currentDocument.pluginName + qsTr(" In Separate &Window") : ""
        checkable: true
        checked: currentTab && currentTab.pluginPoppedOut
        enabled: currentDocument && currentDocument.hasPluginUI && !mainWindow._anyDocumentsBusy
        onTriggered:
        {
            if(currentTab)
                currentTab.togglePop();
        }
    }

    Action
    {
        id: showProvenanceLogAction
        text: qsTr("Show Provenance Log…")
        enabled: currentDocument !== null && !currentDocument.busy
        onTriggered:
        {
            provenanceLogDialog.raise();
            provenanceLogDialog.show();
        }
    }

    Action
    {
        id: aboutPluginsAction
        // Don't ask...
        text: Qt.platform.os === "osx" ? qsTr("Plugins…") : qsTr("About Plugins…")
        onTriggered:
        {
            aboutpluginsDialog.raise();
            aboutpluginsDialog.show();
        }
    }

    Action
    {
        id: aboutAction
        text: qsTr("About " + application.name + "…")
        onTriggered:
        {
            aboutDialog.raise();
            aboutDialog.show();
        }
    }

    Action
    {
        id: aboutQtAction
        text: Qt.platform.os === "osx" ? qsTr("Qt…") : qsTr("About Qt…")
        onTriggered: { application.aboutQt(); }
    }

    Action
    {
        id: checkForUpdatesAction
        enabled: !newUpdate.visible

        text: qsTr("Check For Updates")

        property bool active: false

        onTriggered:
        {
            active = true;
            application.checkForUpdates();
            newUpdate.visible = false;
        }
    }

    Action
    {
        id: showLatestChangesAction
        enabled: changeLog.available

        text: qsTr("Latest Changes…")

        onTriggered:
        {
            latestChangesDialog.raise();
            latestChangesDialog.show();
        }
    }

    Action
    {
        id: copyImageToClipboardAction
        text: qsTr("Copy Viewport To Clipboard")
        shortcut: "Ctrl+C"
        enabled: currentTab
        onTriggered:
        {
            if(currentTab)
                currentTab.copyImageToClipboard();
        }
    }

    Action
    {
        id: onlineHelpAction
        text: qsTr("Online Help")
        shortcut: "F1"
        onTriggered: { Qt.openUrlExternally(QmlUtils.redirectUrl("help")); }
    }

    Action
    {
        // A do nothing action that we use when there
        // is no other valid action available
        id: nullAction
    }

    menuBar: MenuBar
    {
        id: mainMenuBar

        property bool visible: !tracking.visible

        onVisibleChanged: _updateVisibility();
        Component.onCompleted: _updateVisibility();

        function _updateVisibility()
        {
            if(!visible)
            {
                mainWindow.menuBar = null;
                __contentItem.parent = null;
            }
            else
                mainWindow.menuBar = mainMenuBar;
        }

        Menu
        {
            title: qsTr("&File")
            MenuItem { action: fileOpenAction }
            MenuItem { action: fileOpenInTabAction }
            Menu
            {
                id: recentFileMenu
                title: qsTr("&Recent Files")

                Instantiator
                {
                    model: mainWindow.recentFiles
                    delegate: Component
                    {
                        MenuItem
                        {
                            // FIXME: This fires with a -1 index onOpenFile
                            // BUG: Text overflows MenuItems on Windows
                            // https://bugreports.qt.io/browse/QTBUG-50849
                            text: index > -1 ? QmlUtils.fileNameForUrl(mainWindow.recentFiles[index]) : "";
                            onTriggered:
                            {
                                openFile(QmlUtils.urlForFileName(text), true);
                            }
                        }
                    }
                    onObjectAdded: recentFileMenu.insertItem(index, object)
                    onObjectRemoved: recentFileMenu.removeItem(object)
                }
            }
            MenuSeparator {}
            MenuItem { action: fileSaveAction }
            MenuItem { action: fileSaveAsAction }
            MenuItem { action: saveImageAction }
            MenuSeparator {}
            MenuItem { action: closeTabAction }
            MenuItem { action: closeAllTabsAction }
            MenuSeparator {}
            MenuItem { action: quitAction }
        }
        Menu
        {
            title: qsTr("&Edit")
            MenuItem { action: undoAction }
            MenuItem { action: redoAction }
            MenuSeparator {}
            MenuItem { action: deleteAction }
            MenuSeparator {}
            MenuItem { action: selectAllAction }
            MenuItem { action: selectAllVisibleAction }
            MenuItem { action: selectNoneAction }
            MenuItem { action: invertSelectionAction }
            MenuItem { visible: selectSourcesAction.enabled; action: selectSourcesAction }
            MenuItem { visible: selectTargetsAction.enabled; action: selectTargetsAction }
            MenuItem { action: selectNeighboursAction }
            Menu
            {
                id: sharedValuesMenu
                title: qsTr("Select Shared Values of Selection")
                enabled: currentDocument !== null && !currentDocument.nodeSelectionEmpty &&
                    currentTab.numAttributesWithSharedValues > 0

                Instantiator
                {
                    model: currentTab !== null ? currentTab.sharedValuesAttributeNames : []
                    MenuItem
                    {
                        text: modelData
                        onTriggered: { currentTab.selectBySharedAttributeValue(text); }
                    }
                    onObjectAdded: sharedValuesMenu.insertItem(index, object)
                    onObjectRemoved: sharedValuesMenu.removeItem(object)
                }
            }
            MenuItem { action: repeatLastSelectionAction }
            MenuSeparator {}
            MenuItem { action: findAction }
            MenuItem { action: advancedFindAction }
            MenuItem { action: findByAttributeAction }
            MenuItem
            {
                action: currentTab ? currentTab.previousAction : nullAction
                visible: currentTab
            }
            MenuItem
            {
                action: currentTab ? currentTab.nextAction : nullAction
                visible: currentTab
            }
            MenuSeparator {}
            MenuItem { action: prevComponentAction }
            MenuItem { action: nextComponentAction }
            MenuSeparator {}
            MenuItem { action: optionsAction }
        }
        Menu
        {
            title: qsTr("&View")
            MenuItem { action: overviewModeAction }
            MenuItem { action: resetViewAction }
            MenuItem
            {
                action: togglePluginWindowAction
                visible: currentDocument && currentDocument.hasPluginUI
            }
            MenuItem
            {
                action: togglePluginMinimiseAction
                visible: currentDocument && currentDocument.hasPluginUI
            }
            MenuSeparator {}
            MenuItem { action: toggleGraphMetricsAction }
            Menu
            {
                title: qsTr("Show Node Text")
                MenuItem { action: hideNodeTextAction }
                MenuItem { action: showFocusedNodeTextAction }
                MenuItem { action: showSelectedNodeTextAction }
                MenuItem { action: showAllNodeTextAction }
            }
            Menu
            {
                title: qsTr("Show Edge Text")

                MenuItem
                {
                    id: edgeTextWarning

                    enabled: false
                    visible: currentDocument && !currentDocument.hasValidEdgeTextVisualisation &&
                        visuals.showEdgeText !== TextState.Off
                    text: qsTr("⚠ Visualisation Required For Edge Text")
                }

                MenuSeparator { visible: edgeTextWarning.visible }

                MenuItem { action: hideEdgeTextAction }
                MenuItem { action: showSelectedEdgeTextAction }
                MenuItem { action: showAllEdgeTextAction }
            }
            MenuItem
            {
                action: toggleEdgeDirectionAction
                visible: currentTab && currentDocument.directed
            }
            MenuItem { action: toggleMultiElementIndicatorsAction }
            MenuSeparator {}
            MenuItem { action: perspecitveProjectionAction }
            MenuItem { action: orthographicProjectionAction }
            MenuItem { action: twoDeeProjectionAction }
            MenuSeparator {}
            MenuItem { action: smoothShadingAction }
            MenuItem { action: flatShadingAction }
            MenuSeparator {}
            MenuItem { action: copyImageToClipboardAction }
        }
        Menu
        {
            title: qsTr("&Layout")
            MenuItem { action: pauseLayoutAction }
            MenuItem { action: toggleLayoutSettingsAction }
            MenuItem { action: exportNodePositionsAction }
        }
        Menu
        {
            title: qsTr("T&ools")
            MenuItem { action: enrichmentAction }
            MenuItem { action: searchWebAction }
            MenuItem { action: importAttributesAction }
            MenuSeparator {}
            MenuItem { action: showProvenanceLogAction }
        }
        Menu
        {
            id: bookmarksMenu

            title: qsTr("&Bookmarks")
            MenuItem { action: addBookmarkAction }
            MenuItem { action: manageBookmarksAction }
            MenuSeparator { visible: currentDocument ? currentDocument.bookmarks.length > 0 : false }

            MenuItem
            {
                action: activateAllBookmarksAction
                visible: currentDocument ? currentDocument.bookmarks.length > 1 : false
            }

            Instantiator
            {
                model: currentDocument ? currentDocument.bookmarks : []
                delegate: Component
                {
                    MenuItem
                    {
                        text: index > -1 ? currentDocument.bookmarks[index] : "";
                        shortcut:
                        {
                            if(index >= 0 && index < 10)
                                return "Ctrl+" + (index + 1);
                            else if(index == 10)
                                return "Ctrl+0";

                            return "";
                        }

                        enabled: currentTab ? !currentDocument.busy : false
                        onTriggered:
                        {
                            currentTab.gotoBookmark(text);
                        }
                    }
                }
                onObjectAdded: bookmarksMenu.insertItem(index, object)
                onObjectRemoved: bookmarksMenu.removeItem(object)
            }
        }
        Menu { id: pluginMenu0; visible: false; enabled: currentDocument && !currentDocument.busy }
        Menu { id: pluginMenu1; visible: false; enabled: currentDocument && !currentDocument.busy }
        Menu { id: pluginMenu2; visible: false; enabled: currentDocument && !currentDocument.busy }
        Menu { id: pluginMenu3; visible: false; enabled: currentDocument && !currentDocument.busy }
        Menu { id: pluginMenu4; visible: false; enabled: currentDocument && !currentDocument.busy }
        Menu
        {
            title: qsTr("&Debug")
            visible: application.debugEnabled || mainWindow.debugMenuUnhidden
            Menu
            {
                title: qsTr("&Crash")
                MenuItem
                {
                    text: qsTr("Null Pointer Deference");
                    onTriggered: { application.crash(CrashType.NullPtrDereference); }
                }
                MenuItem
                {
                    text: qsTr("C++ Exception");
                    onTriggered: { application.crash(CrashType.CppException); }
                }
                MenuItem
                {
                    text: qsTr("Fatal Error");
                    onTriggered: { application.crash(CrashType.FatalError); }
                }
                MenuItem
                {
                    text: qsTr("Infinite Loop");
                    onTriggered: { application.crash(CrashType.InfiniteLoop); }
                }
                MenuItem
                {
                    text: qsTr("Deadlock");
                    onTriggered: { application.crash(CrashType.Deadlock); }
                }
                MenuItem
                {
                    text: qsTr("Hitch");
                    onTriggered: { application.crash(CrashType.Hitch); }
                }
                MenuItem
                {
                    visible: Qt.platform.os === "windows"
                    text: qsTr("Windows Exception");
                    onTriggered: { application.crash(CrashType.Win32Exception); }
                }
                MenuItem
                {
                    visible: Qt.platform.os === "windows"
                    text: qsTr("Windows Exception Non-Continuable");
                    onTriggered: { application.crash(CrashType.Win32ExceptionNonContinuable); }
                }
                MenuItem
                {
                    text: qsTr("Silent Submit");
                    onTriggered: { application.crash(CrashType.SilentSubmit); }
                }
            }
            MenuItem { action: dumpGraphAction }
            MenuItem { action: dumpCommandStackAction }
            MenuItem { action: toggleFpsMeterAction }
            MenuItem { action: toggleGlyphmapSaveAction }
            MenuItem { action: reportScopeTimersAction }
            MenuItem { action: showCommandLineArgumentsAction }
            MenuItem { action: showEnvironmentAction }
            MenuItem { action: restartAction }
        }
        Menu
        {
            title: qsTr("&Help")

            MenuItem { action: onlineHelpAction }

            MenuItem
            {
                text: qsTr("Show Tutorial…")
                onTriggered:
                {
                    let exampleFileUrl = QmlUtils.urlForFileName(application.resourceFile(
                        "examples/Tutorial.graphia"));

                    if(QmlUtils.fileUrlExists(exampleFileUrl))
                    {
                        let tutorialAlreadyOpen = tabView.findAndActivateTab(exampleFileUrl);
                        openFile(exampleFileUrl, !tutorialAlreadyOpen);
                    }
                }
            }

            MenuSeparator {}
            MenuItem { action: aboutAction }
            MenuItem { action: aboutPluginsAction }
            MenuItem { action: aboutQtAction }

            MenuSeparator {}
            MenuItem { action: checkForUpdatesAction }
            MenuItem { action: showLatestChangesAction }
        }
    }

    function clearMenu(menu)
    {
        menu.visible = false;
        while(menu.items.length > 0)
            menu.removeItem(menu.items[0]);
    }

    function clearMenus()
    {
        if(currentTab !== null)
        {
            clearMenu(currentTab.pluginMenu0);
            clearMenu(currentTab.pluginMenu1);
            clearMenu(currentTab.pluginMenu2);
            clearMenu(currentTab.pluginMenu3);
            clearMenu(currentTab.pluginMenu4);
        }

        clearMenu(pluginMenu0);
        clearMenu(pluginMenu1);
        clearMenu(pluginMenu2);
        clearMenu(pluginMenu3);
        clearMenu(pluginMenu4);
    }

    function updatePluginMenu(index, menu)
    {
        clearMenu(menu);

        if(currentTab !== null)
        {
            if(currentTab.createPluginMenu(index, menu))
                menu.visible = true;
        }
    }

    function updatePluginMenus()
    {
        clearMenus();

        if(currentTab !== null && currentTab.pluginPoppedOut)
        {
            updatePluginMenu(0, currentTab.pluginMenu0);
            updatePluginMenu(1, currentTab.pluginMenu1);
            updatePluginMenu(2, currentTab.pluginMenu2);
            updatePluginMenu(3, currentTab.pluginMenu3);
            updatePluginMenu(4, currentTab.pluginMenu4);
        }
        else
        {
            updatePluginMenu(0, pluginMenu0);
            updatePluginMenu(1, pluginMenu1);
            updatePluginMenu(2, pluginMenu2);
            updatePluginMenu(3, pluginMenu3);
            updatePluginMenu(4, pluginMenu4);
        }
    }

    function updateShadingMode(document)
    {
        switch(document.shading())
        {
        default:
        case Shading.Smooth:    shading.current = smoothShadingAction; break;
        case Shading.Flat:      shading.current = flatShadingAction; break;
        }
    }

    function onDocumentShown(document)
    {
        enrichmentResults.models = document.enrichmentTableModels;

        switch(document.projection())
        {
        default:
        case Projection.Perspective:    projection.current = perspecitveProjectionAction; break;
        case Projection.Orthographic:   projection.current = orthographicProjectionAction; break;
        case Projection.TwoDee:         projection.current = twoDeeProjectionAction; break;
        }

        updateShadingMode(document);
    }

    onCurrentTabChanged:
    {
        updatePluginMenus();

        if(currentDocument !== null)
            onDocumentShown(currentDocument);
    }

    EnrichmentResults
    {
        id: enrichmentResults
        wizard: enrichmentWizard
        models: currentDocument ? currentDocument.enrichmentTableModels : []

        onRemoveResults:
        {
            currentDocument.removeEnrichmentResults(index);
        }
    }

    EnrichmentWizard
    {
        id: enrichmentWizard
        document: currentDocument
        onAccepted:
        {
            if(currentDocument !== null)
                currentDocument.performEnrichment(selectedAttributeGroupA, selectedAttributeGroupB);

            enrichmentWizard.reset();
        }
    }

    Connections
    {
        target: currentTab

        function onPluginLoadComplete() { updatePluginMenus(); }
        function onPluginPoppedOutChanged() { updatePluginMenus(); }
    }

    Connections
    {
        target: currentDocument

        function onEnrichmentTableModelsChanged()
        {
            enrichmentResults.models = currentDocument.enrichmentTableModels;
        }

        function onEnrichmentAnalysisComplete() { enrichmentResults.visible = true; }

        // Plugin menus may reference attributes, so regenerate menus when these change
        function onAttributesChanged() { updatePluginMenus(); }
    }

    toolBar: ToolBar
    {
        id: mainToolBar

        visible: !tracking.visible

        RowLayout
        {
            anchors.fill: parent

            ToolButton { action: fileOpenAction }
            ToolButton { action: fileOpenInTabAction }
            ToolButton { action: fileSaveAction }
            ToolBarSeparator {}
            ToolButton
            {
                id: pauseLayoutButton
                action: pauseLayoutAction
                tooltip: ""
            }
            ToolBarSeparator {}
            ToolButton { action: deleteAction }
            ToolButton { action: findAction }
            ToolButton { action: findByAttributeAction }
            ToolButton { action: undoAction }
            ToolButton { action: redoAction }
            ToolBarSeparator {}
            ToolButton { action: resetViewAction }
            ToolButton { action: optionsAction }

            Item { Layout.fillWidth: true }

            // This is only displayed if the user is checking for updates manually
            RowLayout
            {
                id: updateProgressIndicator
                visible: checkForUpdatesAction.active

                Text
                {
                    text: application.updateDownloadProgress >= 0 ?
                        qsTr("Downloading Update:") : qsTr("Checking For Update:")
                }

                ProgressBar
                {
                    visible: parent.visible
                    indeterminate: application.updateDownloadProgress < 0
                    value: !indeterminate ? application.updateDownloadProgress / 100.0 : 0.0
                }
            }

            NewUpdate
            {
                id: newUpdate
                visible: false

                onRestartClicked: { mainWindow.restart(); }
            }
        }
    }

    DropArea
    {
        anchors.fill: parent
        onDropped:
        {
            if(drop.text.length > 0)
                openFile(drop.text, true)
        }

        TabView
        {
            id: tabView

            visible: !tracking.visible

            anchors.fill: parent
            tabsVisible: count > 1
            frameVisible: count > 1

            onCountChanged:
            {
                if(count === 0)
                    lastTabClosed();
            }

            function insertTabAtIndex(index)
            {
                let tab = insertTab(index, "", tabComponent);
                tab.active = true;
                tabView.currentIndex = index;

                // Make the tab title match the document title
                tab.title = Qt.binding(function() { return tab.item.title });

                return tab;
            }

            function createTab(onCreateFunction)
            {
                let tab = insertTabAtIndex(tabView.count);

                if(typeof(onCreateFunction) !== "undefined")
                    onCreateFunction();

                return tab;
            }

            function replaceTab(onReplaceFunction)
            {
                let oldIndex = tabView.currentIndex;

                removeTab(oldIndex);
                insertTabAtIndex(oldIndex);

                if(onReplaceFunction !== "undefined")
                    onReplaceFunction();
            }

            // This is called if the file can't be opened immediately, or
            // if the load has been attempted but it failed later
            function onLoadFailure(index, fileUrl)
            {
                let tab = getTab(index).item;
                let loadWasCancelled = tab.document.commandIsCancelling;

                // Remove the tab that was created but won't be used
                removeTab(index);

                if(!loadWasCancelled)
                {
                    if(tab.document.failureReason.length > 0)
                    {
                        errorOpeningFileMessageDialog.text = QmlUtils.baseFileNameForUrl(fileUrl) +
                            qsTr(" could not be opened:\n\n") + tab.document.failureReason;
                    }
                    else
                    {
                        errorOpeningFileMessageDialog.text = QmlUtils.baseFileNameForUrl(fileUrl) +
                            qsTr(" could not be opened due to an unspecified error.");
                    }

                    errorOpeningFileMessageDialog.open();
                }
            }

            function openInCurrentTab(fileUrl, fileType, pluginName, parameters)
            {
                let tab = currentTab;
                tab.application = application;
                if(!tab.openFile(fileUrl, fileType, pluginName, parameters))
                    onLoadFailure(findTabIndex(tab), fileUrl);
            }

            function closeTab(index, onCloseFunction)
            {
                if(index < 0 || index >= count)
                {
                    console.log("closeTab called with out of range index: " + index);
                    return false;
                }

                if(typeof(onCloseFunction) === "undefined")
                {
                    onCloseFunction = function()
                    {
                        removeTab(index);
                    }
                }

                tabView.currentIndex = index;
                let tab = getTab(index).item;
                tab.confirmSave(onCloseFunction);
            }

            function findTabIndex(tab)
            {
                for(let index = 0; index < count; index++)
                {
                    if(getTab(index).item === tab)
                        return index;
                }

                return -1;
            }

            function findAndActivateTab(fileUrl)
            {
                for(let index = 0; index < count; index++)
                {
                    let tab = getTab(index);
                    if(tab.item.fileUrl === fileUrl)
                    {
                        currentIndex = index;
                        return true;
                    }
                }

                return false;
            }

            Component
            {
                id: tabComponent

                TabUI
                {
                    id: tab

                    onLoadComplete:
                    {
                        if(success)
                        {
                            processOnePendingArgument();

                            if(application.isResourceFileUrl(fileUrl) &&
                                QmlUtils.baseFileNameForUrlNoExtension(fileUrl) === "Tutorial")
                            {
                                // Mild hack: if it looks like the tutorial file,
                                // it probably is, so start the tutorial
                                startTutorial();
                                misc.hasSeenTutorial = true;
                            }
                            else
                                addToRecentFiles(fileUrl);

                            if(currentDocument !== null)
                                onDocumentShown(currentDocument);
                        }
                        else
                            tabView.onLoadFailure(tabView.findTabIndex(tab), fileUrl);
                    }
                }
            }
        }
    }

    signal lastTabClosed()

    statusBar: StatusBar
    {
        visible: !tracking.visible

        RowLayout
        {
            id: rowLayout
            width: parent.width

            // Status
            Label
            {
                Layout.fillWidth: true
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                textFormat: Text.PlainText
                text: currentDocument ? currentDocument.status : ""
            }

            // Progress
            Label
            {
                text: currentDocument && currentDocument.significantCommandInProgress ? currentDocument.commandVerb : ""
            }

            ProgressBar
            {
                id: progressBar
                value: currentDocument && currentDocument.commandProgress >= 0.0 ? currentDocument.commandProgress / 100.0 : 0.0
                visible: currentDocument ? currentDocument.significantCommandInProgress : false
                indeterminate: currentDocument ? currentDocument.commandProgress < 0.0 ||
                    currentDocument.commandProgress === 100.0 : false
            }

            Label
            {
                property string currentCommandVerb
                visible:
                {
                    if(!currentDocument)
                        return false;

                    if(!currentDocument.significantCommandInProgress)
                        return false;

                    // Show the time remaining when it's above a threshold value
                    if(currentDocument.commandSecondsRemaining > 10)
                    {
                        currentCommandVerb = currentDocument.commandVerb;
                        return true;
                    }

                    // We've dropped below the time threshold, but we're still doing the
                    // same thing, so keep showing the timer
                    if(currentCommandVerb.length > 0 && currentCommandVerb === currentDocument.commandVerb)
                        return true;

                    currentCommandVerb = "";
                    return false;
                }

                text:
                {
                    if(!currentDocument)
                        return "";

                    let minutes = Math.floor(currentDocument.commandSecondsRemaining / 60);
                    let seconds = String(currentDocument.commandSecondsRemaining % 60);
                    if(seconds.length < 2)
                        seconds = "0" + seconds;

                    return minutes + ":" + seconds;
                }
            }

            ToolButton
            {
                id: cancelButton

                implicitHeight: progressBar.implicitHeight * 0.8
                implicitWidth: implicitHeight

                iconName: "process-stop"
                tooltip: qsTr("Cancel")

                visible: currentDocument ? currentDocument.commandInProgress &&
                    currentDocument.commandIsCancellable &&
                    !currentDocument.commandIsCancelling : false

                onClicked:
                {
                    currentDocument.cancelCommand();
                }
            }

            BusyIndicator
            {
                implicitWidth: cancelButton.implicitWidth
                implicitHeight: cancelButton.implicitHeight

                id: cancelledIndicator
                visible: currentDocument ? currentDocument.commandIsCancelling : false
            }

            // Hack to force the RowLayout height to be the maximum of its children
            Rectangle { height: rowLayout.childrenRect.height }
        }
    }

    Hubble
    {
        title: qsTr("Resume/Pause Layout")
        alignment: Qt.AlignBottom | Qt.AlignLeft
        edges: Qt.LeftEdge | Qt.TopEdge
        target: pauseLayoutButton
        tooltipMode: true
        RowLayout
        {
            spacing: Constants.spacing
            Column
            {
                ToolButton { iconName: "media-playback-start" }
                ToolButton { iconName: "media-playback-stop" }
                ToolButton { iconName: "media-playback-pause" }
            }
            Text
            {
                Layout.preferredWidth: 500
                wrapMode: Text.WordWrap
                textFormat: Text.StyledText
                text: qsTr("The graph layout system can be resumed or paused from here.<br>" +
                      "The layout system uses a <b>force-directed</b> model to position nodes. " +
                      "This improves the graph's visual navigability.<br><br>" +
                      "The process will automatically stop when it converges on a stable layout.");
            }
        }
    }

    function alertWhenCommandComplete()
    {
        alert(0);
    }

    onActiveChanged:
    {
        if(!currentTab)
            return;

        // Notify the user that a command is complete when the window isn't active
        if(active)
            currentTab.commandComplete.disconnect(alertWhenCommandComplete);
        else if(currentDocument.significantCommandInProgress)
            currentTab.commandComplete.connect(alertWhenCommandComplete);
    }
}
