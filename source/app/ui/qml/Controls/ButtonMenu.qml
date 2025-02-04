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

import QtQuick 2.7
import QtQuick.Controls 1.5
import QtQml 2.8

import app.graphia 1.0

Item
{
    id: root
    width: button.width
    height: button.height
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    property string text: ""
    property string selectedValue: ""
    property color hoverColor
    property color textColor

    property color _contrastingColor:
    {
        if(mouseArea.containsMouse)
            return QmlUtils.contrastingColor(hoverColor);

        return textColor;
    }

    property bool propogatePresses: false

    property alias model: instantiator.model

    property bool _modelIsUnset: instantiator.model === 1 // wtf?

    property bool menuDropped: false
    Menu
    {
        id: menu

        onAboutToShow: root.menuDropped = true;
        onAboutToHide: root.menuDropped = false;

        Instantiator
        {
            id: instantiator
            delegate: MenuItem
            {
                text: index >= 0 && !_modelIsUnset ? instantiator.model[index] : ""

                onTriggered: { root.selectedValue = text; }
            }

            onObjectAdded: menu.insertItem(index, object)
            onObjectRemoved: menu.removeItem(object)
        }
    }

    Rectangle
    {
        id: button

        width: label.width + 2 * 4/*padding*/
        height: label.height + 2 * 4/*padding*/
        implicitWidth: width
        implicitHeight: height
        radius: 2
        color: (mouseArea.containsMouse || root.menuDropped) ? root.hoverColor : "transparent"

        Label
        {
            id: label
            anchors
            {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.verticalCenter
            }

            text: root.selectedValue !== "" ? root.selectedValue : root.text
            color: root._contrastingColor
            font.bold: true
        }
    }

    MouseArea
    {
        id: mouseArea

        hoverEnabled: true
        anchors.fill: parent
        onClicked:
        {
            if(mouse.button === Qt.LeftButton && menu && !_modelIsUnset)
                menu.__popup(parent.mapToItem(null, 0, parent.height + 4/*padding*/, 0, 0), 0);

            root.clicked(mouse);
        }

        onPressed: { mouse.accepted = !propogatePresses; }
    }

    signal clicked(var mouse)
}
