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
import QtQuick.Layouts 1.3
import app.graphia 1.0

import ".."
import "../../../../shared/ui/qml/Constants.js" as Constants
import "../../../../shared/ui/qml/Utils.js" as Utils
import "../AttributeUtils.js" as AttributeUtils
import "VisualisationUtils.js" as VisualisationUtils

import "../Controls"

Item
{
    id: root

    width: row.width
    height: row.height

    property color enabledTextColor
    property color disabledTextColor
    property color hoverColor
    property color textColor: enabledMenuItem.checked ? enabledTextColor : disabledTextColor

    property var gradientSelector
    Connections
    {
        target: gradientSelector

        function onAccepted()
        {
            if(gradientSelector.visualisationIndex !== index)
                return;

            if(gradientSelector.applied)
                return;

            parameters["gradient"] = "\"" + Utils.escapeQuotes(gradientSelector.configuration) + "\"";
            root.updateExpression();
        }

        function onRejected()
        {
            if(gradientSelector.visualisationIndex !== index)
                return;

            if(gradientSelector.applied)
                document.rollback();
        }

        function onApplyClicked(alreadyApplied)
        {
            if(gradientSelector.visualisationIndex !== index)
                return;

            parameters["gradient"] = "\"" + Utils.escapeQuotes(gradientSelector.configuration) + "\"";
            root.updateExpression(alreadyApplied);
        }
    }

    property var paletteSelector
    Connections
    {
        target: paletteSelector

        function onAccepted()
        {
            if(paletteSelector.visualisationIndex !== index)
                return;

            if(paletteSelector.applied)
                return;

            parameters["palette"] = "\"" + Utils.escapeQuotes(paletteSelector.configuration) + "\"";
            root.updateExpression();
        }

        function onRejected()
        {
            if(paletteSelector.visualisationIndex !== index)
                return;

            if(paletteSelector.applied)
                document.rollback();
        }

        function onApplyClicked(alreadyApplied)
        {
            if(paletteSelector.visualisationIndex !== index)
                return;

            parameters["palette"] = "\"" + Utils.escapeQuotes(paletteSelector.configuration) + "\"";
            root.updateExpression(alreadyApplied);
        }
    }

    property var mappingSelector
    Connections
    {
        target: mappingSelector

        function onAccepted()
        {
            if(mappingSelector.visualisationIndex !== index)
                return;

            if(mappingSelector.applied)
                return;

            parameters["mapping"] = "\"" + Utils.escapeQuotes(mappingSelector.configuration) + "\"";
            root.updateExpression();
        }

        function onRejected()
        {
            if(mappingSelector.visualisationIndex !== index)
                return;

            if(mappingSelector.applied)
                document.rollback();
            else
                optionsMenu.setupMappingMenuItems();
        }

        function onApplyClicked(alreadyApplied)
        {
            if(mappingSelector.visualisationIndex !== index)
                return;

            parameters["mapping"] = "\"" + Utils.escapeQuotes(mappingSelector.configuration) + "\"";
            root.updateExpression(alreadyApplied);
        }
    }

    MouseArea
    {
        anchors.fill: row

        onClicked:
        {
            if(mouse.button === Qt.RightButton)
                hamburger.menu.popup();
        }

        onDoubleClicked: { root.toggle(); }

        // Pass presses on to parent (DraggableList)
        onPressed: { mouse.accepted = false; }
    }

    RowLayout
    {
        id: row

        AlertIcon
        {
            id: alertIcon
            visible: false
        }

        TreeComboBox
        {
            id: attributeList

            implicitWidth: 180
            model: root.similarAttributes
            enabled: enabledMenuItem.checked

            onSelectedValueChanged: { root.updateExpression(); }

            prettifyFunction: AttributeUtils.prettify

            Preferences
            {
                section: "misc"
                property alias visualisationAttributeSortOrder: attributeList.ascendingSortOrder
                property alias visualisationAttributeSortBy: attributeList.sortRoleName
            }
        }

        NamedIcon
        {
            visible: iconName.length > 0
            enabled: enabledMenuItem.checked
            iconName:
            {
                if(channel.length === 0)
                    return "";

                if(channel === "Text")
                    return "format-text-bold";

                if(channel === "Size")
                {
                    if(attributeElementType === ElementType.Node)
                        return "node-size";
                    else if(attributeElementType === ElementType.Edge)
                        return "edge-size";
                }

                return "";
            }
        }

        GradientKey
        {
            id: gradientKey
            visible: false
            enabled: enabledMenuItem.checked

            keyWidth: 100

            textColor: root.textColor
            hoverColor: root.hoverColor

            invert: isFlagSet("invert");

            minimum: root._visualisationInfo.minimumNumericValue !== undefined ?
                root._visualisationInfo.minimumNumericValue : 0.0
            maximum: root._visualisationInfo.maximumNumericValue !== undefined ?
                root._visualisationInfo.maximumNumericValue : 0.0

            mappedMinimum: root._visualisationInfo.mappedMinimumNumericValue !== undefined ?
                root._visualisationInfo.mappedMinimumNumericValue : 0.0
            mappedMaximum: root._visualisationInfo.mappedMaximumNumericValue !== undefined ?
                root._visualisationInfo.mappedMaximumNumericValue : 0.0

            showLabels:
            {
                return !root.isFlagSet("disabled") && !root._error &&
                    (root._visualisationInfo.hasNumericRange !== undefined &&
                    root._visualisationInfo.hasNumericRange) &&
                    // If the visualisation has been applied to multiple components,
                    // then there are multiple ranges; don't show any labels
                    (root._visualisationInfo.numApplications !== undefined &&
                    root._visualisationInfo.numApplications === 1);
            }

            onClicked:
            {
                if(mouse.button === Qt.LeftButton)
                {
                    gradientSelector.visualisationIndex = index;
                    gradientSelector.open(gradientKey.configuration);
                }
                else
                    mouse.accepted = false;
            }
        }

        PaletteKey
        {
            id: paletteKey
            visible: false
            enabled: enabledMenuItem.checked

            textColor: root.textColor
            hoverColor: root.hoverColor

            stringValues: root._visualisationInfo.stringValues !== undefined ?
                root._visualisationInfo.stringValues : []

            onClicked:
            {
                if(mouse.button === Qt.LeftButton)
                {
                    paletteSelector.visualisationIndex = index;
                    paletteSelector.open(paletteKey.configuration,
                        root._visualisationInfo.stringValues);
                }
                else
                    mouse.accepted = false;
            }
        }

        Hamburger
        {
            id: hamburger

            width: 20
            height: 15
            color: disabledTextColor
            hoverColor: enabledTextColor
            propogatePresses: true

            menu: Menu
            {
                id: optionsMenu

                MenuItem
                {
                    id: enabledMenuItem

                    text: qsTr("Enabled")
                    checkable: true
                    enabled: alertIcon.type !== "error"

                    onCheckedChanged:
                    {
                        setFlag("disabled", !checked);
                        root.updateExpression();
                    }
                }

                property bool _showMappingOptions:
                {
                    return document.visualisationChannelAllowsMapping(root.channel) &&
                        root.attributeValueType === ValueType.Numerical;
                }

                MenuSeparator { visible: optionsMenu._showMappingOptions }

                MenuItem
                {
                    id: invertMenuItem

                    text: qsTr("Invert")
                    checkable: true
                    enabled: alertIcon.type !== "error"

                    visible: optionsMenu._showMappingOptions

                    onCheckedChanged:
                    {
                        setFlag("invert", checked);
                        root.updateExpression();
                    }
                }

                ExclusiveGroup { id: mappingExclusiveGroup }

                function setupMappingMenuItems()
                {
                    if(parameters.mapping === undefined)
                    {
                        minmaxMenuItem.checked = true;
                        return;
                    }

                    let mappingString = Utils.unescapeQuotes(parameters["mapping"]);
                    let mapping = JSON.parse(mappingString);

                    if(mapping.exponent !== undefined && mapping.exponent !== 1.0)
                        customMappingMenuItem.checked = true;
                    else if(mapping.type !== undefined)
                    {
                        if(mapping.type === "minmax")
                            minmaxMenuItem.checked = true;
                        else if(mapping.type === "stddev")
                            stddevMenuItem.checked = true;
                    }
                    else
                        customMappingMenuItem.checked = true;
                }

                MenuItem
                {
                    id: minmaxMenuItem
                    text: qsTr("Min/Max")

                    // This is the default when there is no mapping
                    checked: parameters.mapping === undefined

                    checkable: true
                    exclusiveGroup: mappingExclusiveGroup

                    visible: optionsMenu._showMappingOptions

                    onTriggered:
                    {
                        parameters["mapping"] = "\"{\\\"type\\\":\\\"minmax\\\",\\\"exponent\\\":1}\"";
                        root.updateExpression();
                    }
                }

                MenuItem
                {
                    id: stddevMenuItem
                    text: qsTr("Standard Deviation")

                    checkable: true
                    exclusiveGroup: mappingExclusiveGroup

                    visible: optionsMenu._showMappingOptions

                    onTriggered:
                    {
                        parameters["mapping"] = "\"{\\\"type\\\":\\\"stddev\\\",\\\"exponent\\\":1}\"";
                        root.updateExpression();
                    }
                }

                MenuItem
                {
                    id: customMappingMenuItem

                    text: qsTr("Custom Mapping…")

                    checkable: true
                    exclusiveGroup: mappingExclusiveGroup

                    enabled: alertIcon.type !== "error"
                    visible: optionsMenu._showMappingOptions

                    onTriggered:
                    {
                        mappingSelector.visualisationIndex = index;
                        mappingSelector.values = root._visualisationInfo.numericValues;
                        mappingSelector.invert = isFlagSet("invert");

                        if(parameters.mapping !== undefined)
                            mappingSelector.initialise(Utils.unescapeQuotes(parameters["mapping"]));
                        else
                            mappingSelector.reset();

                        mappingSelector.show();
                    }
                }

                MenuSeparator { visible: optionsMenu._showMappingOptions }

                MenuItem
                {
                    id: perComponentMenuItem

                    text: qsTr("Apply Per Component")
                    checkable: true
                    enabled: alertIcon.type !== "error"

                    visible: optionsMenu._showMappingOptions

                    onCheckedChanged:
                    {
                        setFlag("component", checked);
                        root.updateExpression();
                    }
                }

                property bool _showAssignByOptions:
                {
                    if(!paletteKey.visible)
                        return false;

                    return root.attributeValueType === ValueType.String;
                }

                ExclusiveGroup { id: sortByExclusiveGroup }

                MenuSeparator { visible: optionsMenu._showAssignByOptions }

                MenuItem
                {
                    id: sortByValueMenuItem

                    enabled: alertIcon.type !== "error"
                    visible: optionsMenu._showAssignByOptions

                    text: qsTr("By Value")
                    checkable: true
                    exclusiveGroup: sortByExclusiveGroup
                }

                MenuItem
                {
                    id: sortBySharedValuesMenuItem

                    enabled: alertIcon.type !== "error"
                    visible: optionsMenu._showAssignByOptions

                    text: qsTr("By Quantity")
                    checkable: true
                    exclusiveGroup: sortByExclusiveGroup

                    onCheckedChanged:
                    {
                        setFlag("assignByQuantity", checked);
                        root.updateExpression();
                    }
                }

                MenuSeparator { visible: optionsMenu._showAssignByOptions }

                MenuItem
                {
                    text: qsTr("Delete")
                    iconName: "edit-delete"

                    onTriggered:
                    {
                        document.removeVisualisation(index);
                        document.update();
                    }
                }
            }
        }
    }

    property bool ready: false

    function toggle()
    {
        if(!enabledMenuItem.enabled)
            return;

        setFlag("disabled", !isFlagSet("disabled"));
        root.updateExpression();
    }

    property var flags: []
    function setFlag(flag, value)
    {
        if(!ready)
            return;

        if(value)
        {
            flags.push(flag);
            flags = flags.filter(function(e, i)
            {
                return flags.lastIndexOf(e) === i;
            });
        }
        else
        {
            flags = flags.filter(function(e)
            {
                return e !== flag;
            });
        }
    }

    function isFlagSet(flag)
    {
        return flags.indexOf(flag) >= 0;
    }

    property string attributeName
    readonly property var similarAttributes:
        document.attributesSimilarTo(attributeName)

    property var attributeValueType:
    {
        let valueType = document.attribute(attributeName).valueType;
        if(valueType === ValueType.Float || valueType === ValueType.Int)
            return ValueType.Numerical;

        return valueType;
    }

    property var attributeElementType:
    {
        return document.attribute(attributeName).elementType;
    }

    property string channel
    property var parameters

    function updateExpression(replaceLastCommand = false)
    {
        if(!ready)
            return;

        let flagsString = "";
        if(flags.length > 0)
            flagsString = "[" + flags.toString() + "] ";

        let newExpression = flagsString + attributeList.selectedValue + " \"" + channel + "\"";

        if(Object.keys(parameters).length !== 0)
            newExpression += " with";

        for(let key in parameters)
            newExpression += " " + key + " = " + parameters[key];

        value = newExpression;
        document.setVisualisation(index, value);
        document.update([], [], replaceLastCommand);
    }

    property var _visualisationInfo: ({})

    function setVisualisationInfo(visualisationInfo)
    {
        switch(visualisationInfo.alertType)
        {
        case AlertType.Error:
            alertIcon.type = "error";
            alertIcon.text = visualisationInfo.alertText;
            alertIcon.visible = true;
            break;

        case AlertType.Warning:
            alertIcon.type = "warning";
            alertIcon.text = visualisationInfo.alertText;
            alertIcon.visible = true;
            break;

        default:
        case AlertType.None:
            alertIcon.visible = false;
        }
    }

    function parseParameters()
    {
        gradientKey.visible = false;
        paletteKey.visible = false;

        for(let key in parameters)
        {
            let value = parameters[key];
            let unescaped = Utils.unescapeQuotes(value);

            switch(key)
            {
            case "gradient":
                gradientKey.configuration = unescaped;
                gradientKey.visible = true;
                break;

            case "palette":
                paletteKey.configuration = unescaped;
                paletteKey.visible = true;
                break;

            case "mapping":
                optionsMenu.setupMappingMenuItems();
                break;
            }
        }
    }

    property bool _error: false
    property int index: -1
    property string value
    onValueChanged:
    {
        if(!ready)
        {
            let visualisationConfig = document.parseVisualisation(value);

            flags = visualisationConfig.flags;
            attributeName = visualisationConfig.attribute;
            channel = visualisationConfig.channel;
            parameters = visualisationConfig.parameters;

            _error = false;
            if(document.hasVisualisationInfo() && index >= 0)
            {
                root._visualisationInfo = document.visualisationInfoAtIndex(index);
                setVisualisationInfo(root._visualisationInfo);

                _error = root._visualisationInfo.alertType === AlertType.Error;
            }

            parseParameters();

            enabledMenuItem.checked = !isFlagSet("disabled") && !_error;
            invertMenuItem.checked = isFlagSet("invert");
            perComponentMenuItem.checked = isFlagSet("component");
            sortByValueMenuItem.checked = !isFlagSet("assignByQuantity");
            sortBySharedValuesMenuItem.checked = isFlagSet("assignByQuantity");

            if(attributeList.model !== null)
                attributeList.select(attributeList.model.find(attributeName));
            else
                attributeList.placeholderText = attributeName;

            ready = true;
        }
    }
}
