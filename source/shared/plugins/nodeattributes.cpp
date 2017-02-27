#include "nodeattributes.h"

#include "shared/graph/imutablegraph.h"
#include "shared/graph/igraphmodel.h"

void NodeAttributes::initialise(IMutableGraph& mutableGraph)
{
    _indexes = std::make_unique<NodeArray<int>>(mutableGraph, -1);
}

void NodeAttributes::addNodeId(NodeId nodeId)
{
    _indexes->set(nodeId, numValues());
    _rowToNodeIdMap[numValues()] = nodeId;
}

void NodeAttributes::setNodeIdForRowIndex(NodeId nodeId, int row)
{
    _indexes->set(nodeId, row);
    _rowToNodeIdMap[row] = nodeId;
}

int NodeAttributes::rowIndexForNodeId(NodeId nodeId) const
{
    int rowIndex = _indexes->get(nodeId);
    Q_ASSERT(rowIndex >= 0);
    return rowIndex;
}

NodeId NodeAttributes::nodeIdForRowIndex(int row) const
{
    return _rowToNodeIdMap.at(row);
}

void NodeAttributes::setValueByNodeId(NodeId nodeId, const QString& name, const QString& value)
{
    setValue(rowIndexForNodeId(nodeId), name, value);
}

QString NodeAttributes::valueByNodeId(NodeId nodeId, const QString& name) const
{
    return value(rowIndexForNodeId(nodeId), name);
}

void NodeAttributes::setNodeNamesToFirstAttribute(IGraphModel& graphModel)
{
    if(empty())
        return;

    // We must use the mutable version of the graph here as the transformed one
    // probably won't contain all of the node ids
    for(NodeId nodeId : graphModel.mutableGraph().nodeIds())
         graphModel.setNodeName(nodeId, valueByNodeId(nodeId, firstAttributeName()));
}

void NodeAttributes::exposeToGraphModel(IGraphModel& graphModel)
{
    for(const auto& nodeAttribute : *this)
    {
        QString nodeAttributeName = nodeAttribute.name();

        switch(nodeAttribute.type())
        {
        case Attribute::Type::Float:
            graphModel.dataField(nodeAttributeName)
                    .setFloatValueFn([this, nodeAttributeName](NodeId nodeId)
                    {
                        return valueByNodeId(nodeId, nodeAttributeName).toFloat();
                    })
                    .setFloatMin(static_cast<float>(nodeAttribute.floatMin()))
                    .setFloatMax(static_cast<float>(nodeAttribute.floatMax()))
                    .setSearchable(true);
            break;

        case Attribute::Type::Integer:
            graphModel.dataField(nodeAttributeName)
                    .setIntValueFn([this, nodeAttributeName](NodeId nodeId)
                    {
                        return valueByNodeId(nodeId, nodeAttributeName).toInt();
                    })
                    .setIntMin(nodeAttribute.intMin())
                    .setIntMax(nodeAttribute.intMax())
                    .setSearchable(true);
            break;

        case Attribute::Type::String:
            graphModel.dataField(nodeAttributeName)
                    .setStringValueFn([this, nodeAttributeName](NodeId nodeId)
                    {
                        return valueByNodeId(nodeId, nodeAttributeName);
                    })
                    .setSearchable(true);
            break;

        default: break;
        }

        graphModel.dataField(nodeAttributeName)
                .setDescription(QString(tr("%1 is a user defined attribute.")).arg(nodeAttributeName));
    }
}
