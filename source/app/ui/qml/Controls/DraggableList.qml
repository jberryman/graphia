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
import QtQml.Models 2.2

import "../../../../shared/ui/qml/Constants.js" as Constants

Column
{
    id: root

    property Component component
    property var model
    property color heldColor
    property Item parentWhenDragging
    property int alignment
    property int count: repeater.count

    signal itemMoved(int from, int to)

    Component
    {
        id: dragDelegate

        MouseArea
        {
            id: dragArea

            anchors.left: alignment === Qt.AlignLeft ? parent.left : undefined
            anchors.right: alignment === Qt.AlignRight ? parent.right : undefined

            acceptedButtons: Qt.AllButtons

            drag.target: held ? content : undefined
            drag.axis: Drag.YAxis
            drag.minimumY: root.parent.y
            drag.maximumY:
            {
                let position = 0;

                if(repeater.count > 0)
                {
                    let item = repeater.itemAt(repeater.count - 1);

                    if(item !== null)
                        position = item.y;
                }

                return drag.minimumY + position;
            }

            property int _dragStartIndex: -1

            property bool held
            onPressAndHold: held = true;
            onReleased: held = false;

            property int _clickX
            property int _clickY

            // If the mouse is significantly moved after a click, initiate a drag
            onPositionChanged:
            {
                let manhattan = Math.abs(_clickX - mouse.x) + Math.abs(_clickY - mouse.y);

                if(manhattan > 3)
                    held = true;
            }

            onClicked:
            {
                _clickX = mouse.x;
                _clickY = mouse.y;

                // Pass click events on to the child item(s)
                forwardEventToItem(mouse, "clicked");
            }

            onDoubleClicked: { forwardEventToItem(mouse, "doubleClicked"); }

            function forwardEventToItem(event, eventType)
            {
                let receivers = [];

                function recurse(item)
                {
                    if(typeof(item[eventType]) === "function")
                        receivers.push(item);

                    for(let i = 0; i < item.children.length; i++)
                    {
                        let child = item.children[i];

                        if(!child.visible || !child.enabled)
                            continue;

                        let p = mapToItem(child, event.x, event.y);

                        if(child.contains(p))
                            recurse(child);
                    }
                }

                recurse(loader.item);

                while(receivers.length > 0)
                {
                    let item = receivers[receivers.length - 1];

                    item[eventType](event);
                    if(event.accepted)
                        break;

                    receivers.pop();
                }
            }

            width: content.width
            height: content.height

            Rectangle
            {
                id: content

                anchors
                {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                }

                width: loader.item.width + Constants.margin * 2
                height: loader.item.height + Constants.margin

                color: Qt.rgba(root.heldColor.r, root.heldColor.g, root.heldColor.b, dragArea.held ? 1.0 : 0.0)
                Behavior on color { ColorAnimation { duration: 100 } }

                radius: 2

                Drag.source: dragArea
                Drag.hotSpot.x: width / 2
                Drag.hotSpot.y: height / 2

                // http://stackoverflow.com/a/24729837/2721809
                Drag.dragType: Drag.Automatic
                property bool dragActive: dragArea.drag.active
                onDragActiveChanged:
                {
                    if(dragActive)
                    {
                        Drag.start();
                        dragStarted();
                    }
                    else
                    {
                        Drag.drop();
                        dragFinished();
                    }
                }

                signal dragStarted()
                signal dragFinished()
                //

                onDragStarted: { dragArea._dragStartIndex = index; }
                onDragFinished: { dragArea._dragStartIndex = -1; }

                states: State
                {
                    when: dragArea.held

                    ParentChange { target: content; parent: parentWhenDragging }
                    AnchorChanges
                    {
                        target: content
                        anchors { horizontalCenter: undefined; verticalCenter: undefined }
                    }
                }

                Loader
                {
                    id: loader
                    sourceComponent: root.component

                    anchors
                    {
                        horizontalCenter: parent.horizontalCenter
                        verticalCenter: parent.verticalCenter
                    }

                    onLoaded:
                    {
                        if(item.index !== undefined)
                            item.index = index;

                        if(item.value !== undefined)
                        {
                            item.value = modelData;
                            item.valueChanged.connect(function() { modelData = item.value; });
                        }
                    }
                }
            }

            DropArea
            {
                id: dropArea
                anchors
                {
                    top: parent.top
                    bottom: parent.bottom
                    left: alignment === Qt.AlignLeft ? parent.left : undefined
                    right: alignment === Qt.AlignRight ? parent.right : undefined
                }
                width: root.width

                onEntered:
                {
                    let sourcePinned = repeater.itemAt(drag.source.DelegateModel.itemsIndex).pinned;
                    let targetPinned = repeater.itemAt(dragArea.DelegateModel.itemsIndex).pinned;

                    // Must both be pinned or neither pinned
                    if(sourcePinned === targetPinned)
                    {
                        // Do the move in the DelegateModel, so there is a visual change, but leave
                        // the underlying model alone for now
                        delegateModel.items.move(
                                drag.source.DelegateModel.itemsIndex,
                                dragArea.DelegateModel.itemsIndex, 1);
                    }
                }

                onDropped:
                {
                    if(dragArea._dragStartIndex !== dragArea.DelegateModel.itemsIndex)
                    {
                        // Request that the underlying model performs a move
                        root.itemMoved(dragArea._dragStartIndex,
                                       dragArea.DelegateModel.itemsIndex);
                    }
                }
            }

            property bool pinned: loader.item.pinned !== undefined ? loader.item.pinned : false
        }
    }

    // @disable-check M300
    DelegateModel
    {
        id: delegateModel
        model: root.model
        delegate: dragDelegate
    }

    Repeater
    {
        id: repeater
        model: delegateModel
    }
}
