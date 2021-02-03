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

#include "adjacencymatrixfileparser.h"

#include "shared/graph/edgelist.h"

#include "shared/loading/graphsizeestimate.h"
#include "shared/loading/tabulardata.h"
#include "shared/loading/userelementdata.h"

#include "shared/utils/string.h"

#include <QString>

#include <map>

namespace
{
bool parseAdjacencyMatrix(const TabularData& tabularData, Progressable& progressable,
    IGraphModel* graphModel, UserNodeData* userNodeData, UserEdgeData* userEdgeData,
    double minimumAbsEdgeWeight)
{
    progressable.setProgress(-1);

    if(tabularData.numRows() == 0 || tabularData.numColumns() == 0)
        return false;

    bool hasColumnHeaders = false;
    bool hasRowHeaders = false;

    // Check first column for row headers
    for(size_t rowIndex = 0; rowIndex < tabularData.numRows(); rowIndex++)
    {
        const auto& value = tabularData.valueAt(0, rowIndex);
        if(rowIndex > 0 && !value.isEmpty() && !u::isNumeric(value))
        {
            hasRowHeaders = true;
            break;
        }
    }

    // Check first row for column headers
    for(size_t columnIndex = 0; columnIndex < tabularData.numColumns(); columnIndex++)
    {
        const auto& value = tabularData.valueAt(columnIndex, 0);
        if(columnIndex > 0 && !value.isEmpty() && !u::isNumeric(value))
        {
            hasColumnHeaders = true;
            break;
        }
    }

    size_t dataStartRow = hasColumnHeaders ? 1 : 0;
    size_t dataStartColumn = hasRowHeaders ? 1 : 0;

    // Check datarect is square
    auto dataHeight = tabularData.numRows() - dataStartRow;
    auto dataWidth = tabularData.numColumns() - dataStartColumn;
    if(dataWidth != dataHeight)
        return false;

    auto totalIterations = static_cast<uint64_t>(tabularData.numColumns() * tabularData.numRows());
    uint64_t progress = 0;

    std::map<size_t, NodeId> rowToNodeId;
    std::map<size_t, NodeId> columnToNodeId;

    for(size_t rowIndex = dataStartRow; rowIndex < tabularData.numRows(); rowIndex++)
    {
        QString rowHeader = hasRowHeaders ? tabularData.valueAt(0, rowIndex) : QString();

        for(size_t columnIndex = dataStartColumn; columnIndex < tabularData.numColumns(); columnIndex++)
        {
            QString columnHeader = hasColumnHeaders ? tabularData.valueAt(columnIndex, 0) : QString();

            const auto& value = tabularData.valueAt(columnIndex, rowIndex);
            double edgeWeight = u::toNumber(value);

            if(std::isnan(edgeWeight) || !std::isfinite(edgeWeight))
                edgeWeight = 0.0;

            auto absEdgeWeight = std::abs(edgeWeight);

            if(absEdgeWeight <= minimumAbsEdgeWeight)
                continue;

            NodeId sourceNodeId;
            if(!u::contains(columnToNodeId, columnIndex))
            {
                sourceNodeId = graphModel->mutableGraph().addNode();
                userNodeData->setValueBy(sourceNodeId, QObject::tr("Node Name"),
                    !columnHeader.isEmpty() ? columnHeader :
                    QObject::tr("Node %1").arg(columnIndex + 1));

                columnToNodeId[columnIndex] = sourceNodeId;
            }
            else
                sourceNodeId = columnToNodeId[columnIndex];

            NodeId targetNodeId;
            if(!u::contains(rowToNodeId, rowIndex))
            {
                targetNodeId = graphModel->mutableGraph().addNode();
                userNodeData->setValueBy(targetNodeId, QObject::tr("Node Name"),
                    !rowHeader.isEmpty() ? rowHeader :
                    QObject::tr("Node %1").arg(rowIndex + 1));

                rowToNodeId[rowIndex] = targetNodeId;
            }
            else
                targetNodeId = rowToNodeId[rowIndex];

            auto edgeId = graphModel->mutableGraph().addEdge(sourceNodeId, targetNodeId);
            userEdgeData->setValueBy(edgeId, QObject::tr("Edge Weight"), QString::number(edgeWeight));
            userEdgeData->setValueBy(edgeId, QObject::tr("Absolute Edge Weight"), QString::number(absEdgeWeight));

            progressable.setProgress(static_cast<int>((progress++ * 100) / totalIterations));
        }
    }

    progressable.setProgress(-1);

    return true;
}

bool parseEdgeList(const TabularData& tabularData, Progressable& progressable,
    IGraphModel* graphModel, UserNodeData* userNodeData, UserEdgeData* userEdgeData,
    double minimumAbsEdgeWeight)
{
    std::map<QString, NodeId> nodeIdMap;

    size_t progress = 0;
    progressable.setProgress(-1);

    for(size_t rowIndex = 0; rowIndex < tabularData.numRows(); rowIndex++)
    {
        const auto& firstCell = tabularData.valueAt(0, rowIndex);
        const auto& secondCell = tabularData.valueAt(1, rowIndex);

        auto edgeWeight = u::toNumber(tabularData.valueAt(2, rowIndex));
        if(std::isnan(edgeWeight) || !std::isfinite(edgeWeight))
            edgeWeight = 0.0;

        auto absEdgeWeight = std::abs(edgeWeight);

        if(absEdgeWeight <= minimumAbsEdgeWeight)
            continue;

        NodeId firstNodeId;
        NodeId secondNodeId;

        if(!u::contains(nodeIdMap, firstCell))
        {
            firstNodeId = graphModel->mutableGraph().addNode();
            nodeIdMap.emplace(firstCell, firstNodeId);

            auto nodeName = QObject::tr("Node %1").arg(static_cast<int>(firstNodeId + 1));
            userNodeData->setValueBy(firstNodeId, QObject::tr("Node Name"), nodeName);
            graphModel->setNodeName(firstNodeId, nodeName);
        }
        else
            firstNodeId = nodeIdMap[firstCell];

        if(!u::contains(nodeIdMap, secondCell))
        {
            secondNodeId = graphModel->mutableGraph().addNode();
            nodeIdMap.emplace(secondCell, secondNodeId);

            auto nodeName = QObject::tr("Node %1").arg(static_cast<int>(secondNodeId + 1));
            userNodeData->setValueBy(secondNodeId, QObject::tr("Node Name"), nodeName);
            graphModel->setNodeName(secondNodeId, nodeName);
        }
        else
            secondNodeId = nodeIdMap[secondCell];

        auto edgeId = graphModel->mutableGraph().addEdge(firstNodeId, secondNodeId);

        userEdgeData->setValueBy(edgeId, QObject::tr("Edge Weight"), QString::number(edgeWeight));
        userEdgeData->setValueBy(edgeId, QObject::tr("Absolute Edge Weight"),
            QString::number(absEdgeWeight));

        progressable.setProgress(static_cast<int>((progress++ * 100) / tabularData.numRows()));
    }

    progressable.setProgress(-1);

    return true;
}
}

bool AdjacencyMatrixTabularDataParser::onParseComplete()
{
    const auto& data = tabularData();
    QPoint topLeft;
    EdgeList edgeList;

    setProgress(-1);

    if(isEdgeList(data))
    {
        for(size_t rowIndex = 0; rowIndex < data.numRows(); rowIndex++)
        {
            NodeId source = data.valueAt(0, rowIndex).toInt();
            NodeId target = data.valueAt(1, rowIndex).toInt();
            double weight = data.valueAt(2, rowIndex).toDouble();
            EdgeListEdge edge{source, target, weight};

            edgeList.emplace_back(edge);

            setProgress(static_cast<int>((rowIndex * 100) / data.numRows()));
        }
    }
    else if(isAdjacencyMatrix(data, &topLeft))
    {
        for(size_t rowIndex = static_cast<size_t>(topLeft.y()); rowIndex < data.numRows(); rowIndex++)
        {
            for(size_t columnIndex = static_cast<size_t>(topLeft.x()); columnIndex < data.numColumns(); columnIndex++)
            {
                double weight = data.valueAt(columnIndex, rowIndex).toDouble();

                if(weight == 0.0)
                    continue;

                edgeList.emplace_back(EdgeListEdge{NodeId(rowIndex), NodeId(columnIndex), weight});
            }

            setProgress(static_cast<int>((rowIndex * 100) / data.numRows()));
        }
    }

    setProgress(-1);

    _binaryMatrix = true;
    double lastSeenWeight = 0.0;
    for(const auto& edge : edgeList)
    {
        if(lastSeenWeight != 0.0 && edge._weight != lastSeenWeight)
        {
            _binaryMatrix = false;
            break;
        }

        lastSeenWeight = edge._weight;
    }

    emit binaryMatrixChanged();

    _graphSizeEstimate = graphSizeEstimate(edgeList);
    emit graphSizeEstimateChanged();

    return true;
}

bool AdjacencyMatrixTabularDataParser::isAdjacencyMatrix(const TabularData& tabularData, QPoint* topLeft, size_t maxRows)
{
    // A matrix can optionally have column or row headers. Or none.
    // A matrix data rect must be square.
    std::vector<QString> potentialColumnHeaders;

    bool headerMatch = true;
    bool firstColumnAllDouble = true;
    bool firstRowAllDouble = true;

    if(tabularData.numColumns() < 2)
        return false;

    for(size_t rowIndex = 0; rowIndex < std::min(tabularData.numRows(), maxRows); rowIndex++)
    {
        for(size_t columnIndex = 0; columnIndex < tabularData.numColumns(); columnIndex++)
        {
            const auto& value = tabularData.valueAt(columnIndex, rowIndex);

            if(rowIndex == 0)
            {
                if(!u::isNumeric(value) && !value.isEmpty() && columnIndex > 0)
                    firstRowAllDouble = false;

                potentialColumnHeaders.push_back(value);
            }

            if(columnIndex == 0)
            {
                if(rowIndex >= potentialColumnHeaders.size() ||
                        potentialColumnHeaders[rowIndex] != value)
                {
                    headerMatch = false;
                }

                // The first entry could be headers so don't enforce check for a double
                if(rowIndex > 0)
                {
                    if(!u::isNumeric(value) && !value.isEmpty())
                        firstColumnAllDouble = false;
                }
            }
            else if(rowIndex > 0)
            {
                // Check non header elements are doubles
                // This will prevent loading obviously non-matrix files
                // We could handle non-double matrix symbols in future (X, -, I, O etc)
                if(!u::isNumeric(value) && !value.isEmpty())
                    return false;
            }
        }
    }

    auto numDataColumns = tabularData.numColumns() - (firstColumnAllDouble ? 1 : 0);
    auto numDataRows = tabularData.numRows() - (firstRowAllDouble ? 1 : 0);

    // Note we can't test for equality as we may not be seeing all the rows (due to a row limit)
    if(numDataColumns < numDataRows)
        return false;

    if(topLeft != nullptr)
    {
        topLeft->setX(firstColumnAllDouble ? 1 : 0);
        topLeft->setY(firstRowAllDouble ? 1 : 0);
    }

    return headerMatch || firstColumnAllDouble || firstRowAllDouble;
}

bool AdjacencyMatrixTabularDataParser::isEdgeList(const TabularData& tabularData, size_t maxRows)
{
    if(tabularData.numColumns() != 3)
        return false;

    for(size_t rowIndex = 0; rowIndex < std::min(tabularData.numRows(), maxRows); rowIndex++)
    {
        if(!u::isInteger(tabularData.valueAt(0, rowIndex)))
            return false;

        if(!u::isInteger(tabularData.valueAt(1, rowIndex)))
            return false;

        if(!u::isNumeric(tabularData.valueAt(2, rowIndex)))
            return false;
    }

    return true;
}

bool AdjacencyMatrixTabularDataParser::parse(const TabularData& tabularData, Progressable& progressable,
    IGraphModel* graphModel, UserNodeData* userNodeData, UserEdgeData* userEdgeData)
{
    if(isEdgeList(tabularData))
    {
        return parseEdgeList(tabularData, progressable,
            graphModel, userNodeData, userEdgeData, _minimumAbsEdgeWeight);
    }
    else if(isAdjacencyMatrix(tabularData))
    {
        return parseAdjacencyMatrix(tabularData, progressable,
            graphModel, userNodeData, userEdgeData, _minimumAbsEdgeWeight);
    }

    return false;
}
