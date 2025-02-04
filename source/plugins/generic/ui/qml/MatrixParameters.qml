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

import QtQuick.Controls 1.5
import QtQuick 2.14
import QtQml 2.12
import QtQuick.Layouts 1.3
import QtQuick.Window 2.2
import app.graphia 1.0

import "../../../../shared/ui/qml/Constants.js" as Constants
import "../../../../shared/ui/qml/Utils.js" as Utils
import "Controls"

BaseParameterDialog
{
    id: root

    title: qsTr("Matrix Parameters")

    minimumWidth: tabularDataParser.binaryMatrix ? 480 : 640
    minimumHeight: tabularDataParser.binaryMatrix ? 240 : 520

    maximumHeight: tabularDataParser.binaryMatrix ? minimumHeight : (1 << 24) - 1

    modality: Qt.ApplicationModal

    property bool _graphEstimatePerformed: false

    AdjacencyMatrixTabularDataParser
    {
        id: tabularDataParser

        property var adjustedGraphSizeEstimate:
        {
            let estimate = graphSizeEstimate;

            if(estimate.keys === undefined)
                return estimate;

            let skip = estimate.keys.reduce((n, x) =>
                n + (x < minimumThresholdSpinBox.value), 0);

            estimate.keys.splice(0, skip);
            estimate.numNodes.splice(0, skip);
            estimate.numEdges.splice(0, skip);
            estimate.numUniqueEdges.splice(0, skip);

            return estimate;
        }

        onDataLoaded: { parameters.data = tabularDataParser.data; }
    }

    ColumnLayout
    {
        id: loadingInfo

        anchors.fill: parent
        visible: !tabularDataParser.complete || tabularDataParser.failed

        Item { Layout.fillHeight: true }

        Text
        {
            Layout.fillWidth: true

            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap

            text: tabularDataParser.failed ?
                qsTr("Failed to Load ") + QmlUtils.baseFileNameForUrl(fileUrl) + "." :
                qsTr("Loading ") + QmlUtils.baseFileNameForUrl(fileUrl) + "…"
        }

        RowLayout
        {
            Layout.alignment: Qt.AlignHCenter

            ProgressBar
            {
                visible: !tabularDataParser.failed
                value: tabularDataParser.progress >= 0.0 ? tabularDataParser.progress / 100.0 : 0.0
                indeterminate: tabularDataParser.progress < 0.0
            }

            Button
            {
                text: tabularDataParser.failed ? qsTr("Close") : qsTr("Cancel")
                onClicked:
                {
                    if(!tabularDataParser.failed)
                        tabularDataParser.cancelParse();

                    root.close();
                }
            }
        }

        Item { Layout.fillHeight: true }
    }

    ColumnLayout
    {
        anchors.fill: parent
        anchors.margins: Constants.margin

        visible: !loadingInfo.visible

        ColumnLayout
        {
            Layout.fillHeight: true

            spacing: Constants.spacing

            RowLayout
            {
                Layout.fillWidth: true

                Text
                {
                    wrapMode: Text.WordWrap
                    textFormat: Text.StyledText
                    Layout.fillWidth: true

                    text: qsTr("An adjacency matrix is a square matrix used to represent a graph. " +
                        "The elements of the matrix indicate whether pairs of nodes are adjacent or " +
                        "not in the graph, i.e. the nodes are connected via edges.")
                }

                Image
                {
                    Layout.minimumWidth: 80
                    Layout.minimumHeight: 80
                    Layout.margins: Constants.margin

                    sourceSize.width: 80
                    sourceSize.height: 80
                    source: "../matrix.svg"
                }
            }

            // Filler
            Item
            {
                Layout.fillHeight: true
                visible: tabularDataParser.binaryMatrix
            }

            RowLayout
            {
                visible: !tabularDataParser.binaryMatrix

                CheckBox
                {
                    id: filterEdgesCheckbox
                    text: qsTr("Filter Edges")
                }

                HelpTooltip
                {
                    title: qsTr("Filter Edges")
                    Text
                    {
                        wrapMode: Text.WordWrap
                        text: qsTr("This matrix is non-binary, i.e. non-zero cells indicate the " +
                            "strength of the relationship between entities. In some circumstances it may be " +
                            "advantageous to filter edges below a specified minimum absolute threshold, " +
                            "which is enabled here.")
                    }
                }
            }

            ColumnLayout
            {
                id: thresholdSelection

                visible: !tabularDataParser.binaryMatrix
                enabled: filterEdgesCheckbox.checked

                Layout.fillWidth: true
                Layout.fillHeight: true

                RowLayout
                {
                    Layout.fillWidth: true

                    Text { text: qsTr("Minimum:") }

                    SpinBox
                    {
                        id: minimumThresholdSpinBox

                        implicitWidth: 90

                        minimumValue: initialThresholdSpinBox.minimumValue
                        maximumValue: initialThresholdSpinBox.maximumValue

                        decimals: Utils.decimalPointsForRange(minimumValue, maximumValue);
                        stepSize: Utils.incrementForRange(minimumValue, maximumValue);

                        onValueChanged:
                        {
                            parameters.minimumThreshold = value;

                            // When the minimum value is increased beyond the initial
                            // value, the latter can get (visually) lost against the extreme
                            // left of the plot, so just punt it over a bit
                            let range = maximumValue - value;
                            let adjustedInitial = value + (range * 0.1);

                            if(initialThresholdSpinBox.value <= adjustedInitial)
                                initialThresholdSpinBox.value = adjustedInitial;
                        }
                    }

                    Slider
                    {
                        id: minimumSlider

                        Layout.fillWidth: true
                        Layout.minimumWidth: 50
                        Layout.maximumWidth: 175

                        minimumValue: initialThresholdSpinBox.minimumValue
                        maximumValue: initialThresholdSpinBox.maximumValue
                        value: minimumThresholdSpinBox.value
                        onValueChanged:
                        {
                            minimumThresholdSpinBox.value = value;
                        }
                    }

                    HelpTooltip
                    {
                        title: qsTr("Minimum Threshold Value")
                        Text
                        {
                            wrapMode: Text.WordWrap
                            text: qsTr("The minimum threshold value above which an edge " +
                                "will be created in the graph. Using a lower minimum value will " +
                                "increase the compute and memory requirements.")
                        }
                    }

                    Text { text: qsTr("Initial:") }

                    SpinBox
                    {
                        id: initialThresholdSpinBox

                        implicitWidth: 90

                        minimumValue:
                        {
                            if(tabularDataParser.graphSizeEstimate.keys !== undefined)
                                return tabularDataParser.graphSizeEstimate.keys[0];

                            return 0.0;
                        }

                        maximumValue:
                        {
                            if(tabularDataParser.graphSizeEstimate.keys !== undefined)
                            {
                                return tabularDataParser.graphSizeEstimate.keys[
                                    tabularDataParser.graphSizeEstimate.keys.length - 1];
                            }

                            return 0.0;
                        }

                        decimals: Utils.decimalPointsForRange(minimumValue, maximumValue);
                        stepSize: Utils.incrementForRange(minimumValue, maximumValue);

                        onValueChanged:
                        {
                            parameters.initialThreshold = value;
                            graphSizeEstimatePlot.threshold = value;
                        }
                    }

                    HelpTooltip
                    {
                        title: qsTr("Threshold")
                        Text
                        {
                            wrapMode: Text.WordWrap
                            text: qsTr("The initial threshold determines the size of the resultant graph. " +
                                "A lower value filters fewer edges, and results in a larger graph. " +
                                "This value can be changed later, after the graph has been created.")
                        }
                    }
                }

                GraphSizeEstimatePlot
                {
                    id: graphSizeEstimatePlot

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    visible: tabularDataParser.graphSizeEstimate.keys !== undefined

                    graphSizeEstimate: tabularDataParser.adjustedGraphSizeEstimate
                    uniqueEdgesOnly: ignoreDuplicateEdgesCheckbox.checked

                    onThresholdChanged: { initialThresholdSpinBox.value = threshold; }
                }
            }

            RowLayout
            {
                CheckBox
                {
                    id: ignoreDuplicateEdgesCheckbox
                    text: qsTr("Ignore Duplicate Edges")
                    onCheckedChanged: { parameters.skipDuplicates = checked; }
                }

                HelpTooltip
                {
                    title: qsTr("Ignore Duplicate Edges")
                    Text
                    {
                        wrapMode: Text.WordWrap
                        text: qsTr("Adjacency matrices are often presented in a symmetric fashion; " +
                            "that is to say that for every non-zero cell in the matrix with a value, " +
                            "there exists a partner cell reflected across the matrix's diagonal. In " +
                            "terms of representing the matrix as a graph, the net result is that every " +
                            "pair of nodes are connected by two edges. Often this is undesirable. " +
                            "Selecting this option avoids this. In the case where the pair of weights " +
                            "differ, the larger of the absolute values is used.")
                    }
                }
            }

            // Filler
            Item
            {
                Layout.fillHeight: true
                visible: tabularDataParser.binaryMatrix
            }

            Text
            {
                Layout.fillWidth: true
                textFormat: Text.RichText
                wrapMode: Text.WordWrap

                text:
                {
                    let summaryString = "";
                    let normalFont = "<font>";
                    let warningFont = "<font color=\"red\">";

                    if(tabularDataParser.adjustedGraphSizeEstimate.keys !== undefined)
                    {
                        if(!tabularDataParser.binaryMatrix)
                            summaryString += qsTr("Estimated Pre-Transform Graph Size: ");
                        else
                            summaryString += qsTr("Estimated Graph Size: ");

                        let warningThreshold = 5e6;

                        let numNodes = tabularDataParser.adjustedGraphSizeEstimate.numNodes[0];
                        let numEdges = ignoreDuplicateEdgesCheckbox.checked ?
                            tabularDataParser.adjustedGraphSizeEstimate.numUniqueEdges[0] :
                            tabularDataParser.adjustedGraphSizeEstimate.numEdges[0];

                        let nodesFont = normalFont;
                        if(numNodes > warningThreshold)
                            nodesFont = warningFont;

                        let edgesFont = normalFont;
                        if(numEdges > warningThreshold)
                            edgesFont = warningFont;

                        summaryString +=
                            nodesFont + QmlUtils.formatNumberSIPostfix(numNodes) + qsTr(" Nodes") + "</font>" +
                            ", " +
                            edgesFont + QmlUtils.formatNumberSIPostfix(numEdges) + qsTr(" Edges") + "</font>";

                        if(numNodes > warningThreshold || numEdges > warningThreshold)
                        {
                            summaryString += "<br><br>" + warningFont +
                                qsTr("WARNING: This is a very large graph which has the potential " +
                                "to exhaust system resources and lead to instability " +
                                "or freezes.");

                            if(!tabularDataParser.binaryMatrix)
                            {
                                summaryString +=
                                    qsTr(" Increasing the Minimum Correlation Value will " +
                                    "usually reduce the graph size.");
                            }

                            summaryString += "</font>";
                        }
                    }

                    return summaryString;
                }
            }
        }

        RowLayout
        {
            Layout.alignment: Qt.AlignRight
            Layout.topMargin: Constants.spacing

            Button
            {
                Layout.alignment: Qt.AlignRight
                text: qsTr("OK")
                onClicked:
                {
                    parameters.filterEdges = filterEdgesCheckbox.checked && !tabularDataParser.binaryMatrix;

                    accepted();
                    root.close();
                }
            }

            Button
            {
                Layout.alignment: Qt.AlignRight
                text: qsTr("Cancel")
                onClicked:
                {
                    rejected();
                    root.close();
                }
            }
        }
    }

    Component.onCompleted: { initialise(); }
    function initialise()
    {
        parameters =
        {
            minimumThreshold: 0.0,
            initialThreshold: 0.0,
            filterEdges: false,
            skipDuplicates: false
        };
    }

    Connections
    {
        target: tabularDataParser

        function onGraphSizeEstimateChanged()
        {
            if(root._graphEstimatePerformed)
                return;

            root._graphEstimatePerformed = true;
            graphSizeEstimatePlot.threshold =
                (initialThresholdSpinBox.maximumValue - initialThresholdSpinBox.minimumValue) * 0.5;
            minimumThresholdSpinBox.value = initialThresholdSpinBox.minimumValue;
        }
    }

    onVisibleChanged:
    {
        if(visible)
        {
            root._graphEstimatePerformed = false;
            ignoreDuplicateEdgesCheckbox.checked = false;
            filterEdgesCheckbox.checked = false;

            if(root.fileUrl.length !== 0 && root.fileType.length !== 0)
                tabularDataParser.parse(root.fileUrl, root.fileType);
            else
                console.log("ERROR: fileUrl or fileType is empty");
        }
    }
}
