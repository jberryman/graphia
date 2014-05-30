#include "simplecomponentmanager.h"

#include <QQueue>

static QSet<ComponentId> assignConnectedElementsComponentId(NodeId rootId, ComponentId componentId,
                                                            const Graph& graph,
                                                            NodeArray<ComponentId>& nodesComponentId,
                                                            EdgeArray<ComponentId>& edgesComponentId,
                                                            EdgeId skipEdgeId = EdgeId())
{
    QQueue<NodeId> nodeIdSearchList;
    QSet<ComponentId> oldComponentIdsAffected;

    nodeIdSearchList.enqueue(rootId);

    while(!nodeIdSearchList.isEmpty())
    {
        NodeId nodeId = nodeIdSearchList.dequeue();
        oldComponentIdsAffected.insert(nodesComponentId[nodeId]);
        nodesComponentId[nodeId] = componentId;

        const QSet<EdgeId> edgeIds = graph.nodeById(nodeId).edges();

        for(EdgeId edgeId : edgeIds)
        {
            if(edgeId == skipEdgeId)
                continue;

            edgesComponentId[edgeId] = componentId;
            NodeId oppositeNodeId = graph.edgeById(edgeId).oppositeId(nodeId);

            if(nodesComponentId[oppositeNodeId] != componentId)
            {
                nodeIdSearchList.enqueue(oppositeNodeId);
                nodesComponentId[oppositeNodeId] = componentId;
            }
        }
    }

    oldComponentIdsAffected.remove(ComponentId());

    return oldComponentIdsAffected;
}

void SimpleComponentManager::updateComponents()
{
    QMap<ComponentId, QSet<ComponentId>> splitComponents;
    QList<ComponentId> newComponentIds;

    NodeArray<ComponentId> newNodesComponentId(graph());
    EdgeArray<ComponentId> newEdgesComponentId(graph());
    QList<ComponentId> newComponentIdsList;

    const QVector<NodeId>& nodeIdsList = graph().nodeIds();

    // Search for mergers and splitters
    for(NodeId nodeId : nodeIdsList)
    {
        ComponentId oldComponentId = _nodesComponentId[nodeId];

        if(newNodesComponentId[nodeId].isNull() && !oldComponentId.isNull())
        {
            if(newComponentIdsList.contains(oldComponentId))
            {
                // We have already used this ID so this is a component that has split
                ComponentId newComponentId = generateComponentId();
                newComponentIdsList.append(newComponentId);
                assignConnectedElementsComponentId(nodeId, newComponentId, graph(),
                                                   newNodesComponentId, newEdgesComponentId);

                queueGraphComponentUpdate(oldComponentId);
                queueGraphComponentUpdate(newComponentId);

                QSet<ComponentId> splitters;
                splitters.insert(oldComponentId);
                splitters.insert(newComponentId);
                splitComponents[oldComponentId].unite(splitters);
            }
            else
            {
                newComponentIdsList.append(oldComponentId);
                QSet<ComponentId> componentIdsAffected =
                        assignConnectedElementsComponentId(nodeId, oldComponentId, graph(),
                                                           newNodesComponentId, newEdgesComponentId);
                queueGraphComponentUpdate(oldComponentId);

                if(componentIdsAffected.size() > 1)
                {
                    // More than one old component IDs were observed so components have merged
                    emit componentsWillMerge(&graph(), componentIdsAffected, oldComponentId);
                    componentIdsAffected.remove(oldComponentId);

                    for(ComponentId removedComponentId : componentIdsAffected)
                    {
                        emit componentWillBeRemoved(&graph(), removedComponentId);
                        removeGraphComponent(removedComponentId);
                    }
                }
            }
        }
    }

    // Search for entirely new components
    for(NodeId nodeId : nodeIdsList)
    {
        if(newNodesComponentId[nodeId].isNull() && _nodesComponentId[nodeId].isNull())
        {
            ComponentId newComponentId = generateComponentId();
            newComponentIdsList.append(newComponentId);
            assignConnectedElementsComponentId(nodeId, newComponentId, graph(), newNodesComponentId, newEdgesComponentId);
            queueGraphComponentUpdate(newComponentId);

            newComponentIds.append(newComponentId);
        }
    }

    // Search for removed components
    QSet<ComponentId> removedComponentIds = _componentIdsList.toSet().subtract(newComponentIdsList.toSet());
    for(ComponentId removedComponentId : removedComponentIds)
    {
        // Component removed
        emit componentWillBeRemoved(&graph(), removedComponentId);

        removeGraphComponent(removedComponentId);
    }

    _nodesComponentId = newNodesComponentId;
    _edgesComponentId = newEdgesComponentId;

    // Notify all the splits
    for(ComponentId splitee : splitComponents.keys())
    {
        QSet<ComponentId>& splitters = splitComponents[splitee];
        emit componentSplit(&graph(), splitee, splitters);

        for(ComponentId splitter : splitters)
        {
            if(splitter != splitee)
                emit componentAdded(&graph(), splitter);
        }
    }

    // Notify all the new components
    for(ComponentId newComponentId : newComponentIds)
        emit componentAdded(&graph(), newComponentId);
}

ComponentId SimpleComponentManager::generateComponentId()
{
    ComponentId newComponentId;

    if(!_vacatedComponentIdQueue.isEmpty())
        newComponentId = _vacatedComponentIdQueue.dequeue();
    else
        newComponentId = _nextComponentId++;

    _componentIdsList.append(newComponentId);

    for(ResizableGraphArray* componentArray : _componentArrayList)
        componentArray->resize(componentArrayCapacity());

    return newComponentId;
}

void SimpleComponentManager::releaseComponentId(ComponentId componentId)
{
    _componentIdsList.removeOne(componentId);
    _vacatedComponentIdQueue.enqueue(componentId);
}

void SimpleComponentManager::queueGraphComponentUpdate(ComponentId componentId)
{
    _updatesRequired.insert(componentId);

    if(!_componentsMap.contains(componentId))
    {
        GraphComponent* graphComponent = new GraphComponent(this->graph());
        _componentsMap.insert(componentId, graphComponent);
    }
}

void SimpleComponentManager::updateGraphComponent(ComponentId componentId)
{
    GraphComponent* graphComponent = _componentsMap[componentId];

    QVector<NodeId>& nodeIdsList = graphComponentNodeIdsList(graphComponent);
    QVector<EdgeId>& edgeIdsList = graphComponentEdgeIdsList(graphComponent);

    nodeIdsList.clear();
    const QVector<NodeId>& nodeIds = graph().nodeIds();
    for(NodeId nodeId : nodeIds)
    {
        if(_nodesComponentId[nodeId] == componentId)
            nodeIdsList.append(nodeId);
    }

    edgeIdsList.clear();
    const QVector<EdgeId>& edgeIds = graph().edgeIds();
    for(EdgeId edgeId : edgeIds)
    {
        if(_edgesComponentId[edgeId] == componentId)
            edgeIdsList.append(edgeId);
    }
}

void SimpleComponentManager::removeGraphComponent(ComponentId componentId)
{
    if(_componentsMap.contains(componentId))
    {
        GraphComponent* graphComponent = _componentsMap[componentId];
        delete graphComponent;

        _componentsMap.remove(componentId);
        _componentIdsList.removeOne(componentId);
        releaseComponentId(componentId);
        _updatesRequired.remove(componentId);
    }
}

void SimpleComponentManager::graphChanged(const Graph*)
{
    updateComponents();

    for(ComponentId componentId : _updatesRequired)
        updateGraphComponent(componentId);

    _updatesRequired.clear();
}

const QList<ComponentId>& SimpleComponentManager::componentIds() const
{
    return _componentIdsList;
}

const GraphComponent* SimpleComponentManager::componentById(ComponentId componentId)
{
    if(_componentsMap.contains(componentId))
        return _componentsMap[componentId];

    return nullptr;
}

ComponentId SimpleComponentManager::componentIdOfNode(NodeId nodeId) const
{
    if(nodeId.isNull())
        return ComponentId();

    ComponentId componentId = _nodesComponentId[nodeId];
    return _componentIdsList.contains(componentId) ? componentId : ComponentId();
}

ComponentId SimpleComponentManager::componentIdOfEdge(EdgeId edgeId) const
{
    if(edgeId.isNull())
        return ComponentId();

    ComponentId componentId = _edgesComponentId[edgeId];
    return _componentIdsList.contains(componentId) ? componentId : ComponentId();
}

