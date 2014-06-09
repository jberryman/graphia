#ifndef GRAPH_H
#define GRAPH_H

#include <QObject>
#include <QList>
#include <QDebug>

#include <vector>
#include <deque>
#include <unordered_set>
#include <type_traits>
#include <functional>

class ResizableGraphArray;
class GraphComponent;
class ComponentManager;

template<typename T> class ElementId;
template<typename T> QDebug operator<<(QDebug d, const ElementId<T>& id);
//namespace std { template<typename T> struct hash<ElementId<T>> }

template<typename T> class ElementId
{
    friend std::hash<ElementId<T>>;
private:
    static const int NullValue = -1;
    int _value;

public:
    explicit ElementId(int value = NullValue) :
        _value(value)
    {
        static_assert(sizeof(ElementId) == sizeof(_value), "ElementId should not be larger than an int");
    }

    inline operator int() const { return _value; }

    ElementId& operator=(const ElementId<T>& other)
    {
        _value = other._value;
        return *this;
    }

    inline T& operator++()
    {
        ++_value;
        return static_cast<T&>(*this);
    }

    inline T operator++(int)
    {
        T previous = static_cast<T&>(*this);
        operator++();
        return previous;
    }

    inline bool operator==(const ElementId<T>& other) const
    {
        return _value == other._value;
    }

    inline bool operator<(const ElementId<T>& other) const
    {
        return _value < other._value;
    }

    inline bool isNull() const
    {
        return _value == NullValue;
    }

    inline void setToNull()
    {
        _value = NullValue;
    }

    friend QDebug operator<< <T>(QDebug d, const ElementId<T>& id);
};

template<typename T> QDebug operator<<(QDebug d, const ElementId<T>& id)
{
    if(id.isNull())
        d << "Null";
    else
        d << id._value;

    return d;
}

class NodeId : public ElementId<NodeId>
{
#if __cplusplus == 201103L
    using ElementId::ElementId;
#else
    explicit NodeId() : ElementId() {}
    explicit NodeId(int value) : ElementId(value) {}
#endif
};

class EdgeId : public ElementId<EdgeId>
{
#if __cplusplus == 201103L
    using ElementId::ElementId;
#else
    explicit EdgeId() : ElementId() {}
    explicit EdgeId(int value) : ElementId(value) {}
#endif
};

namespace std
{
    template<typename T> struct hash<ElementId<T>>
    {
    public:
        size_t operator()(const ElementId<T>& x) const
        {
            return x._value;
        }
    };
}

template<typename T> using ElementIdSet = std::unordered_set<T, std::hash<ElementId<T>>>;

class ComponentId : public ElementId<ComponentId>
{
#if __cplusplus == 201103L
    using ElementId::ElementId;
#else
    explicit ComponentId() : ElementId() {}
    explicit ComponentId(int value) : ElementId(value) {}
#endif
};

class Node
{
    friend class Graph;

private:
    NodeId _id;
    ElementIdSet<EdgeId> _inEdges;
    ElementIdSet<EdgeId> _outEdges;
    ElementIdSet<EdgeId> _edges;

public:
    Node() {}
    Node(const Node& other) :
        _id(other._id),
        _inEdges(other._inEdges),
        _outEdges(other._outEdges)
    {}

    const ElementIdSet<EdgeId> inEdges() const { return _inEdges; }
    int inDegree() const { return _inEdges.size(); }
    const ElementIdSet<EdgeId> outEdges() const { return _outEdges; }
    int outDegree() const { return _outEdges.size(); }
    const ElementIdSet<EdgeId> edges() const { return _edges; }
    int degree() const { return _edges.size(); }

    NodeId id() const { return _id; }
};

class Edge
{
    friend class Graph;

private:
    EdgeId _id;
    NodeId _sourceId;
    NodeId _targetId;

public:
    Edge() {}
    Edge(const Edge& other) :
        _id(other._id),
        _sourceId(other._sourceId),
        _targetId(other._targetId)
    {}

    NodeId sourceId() const { return _sourceId; }
    NodeId targetId() const { return _targetId; }
    NodeId oppositeId(NodeId nodeId) const
    {
        if(nodeId == _sourceId)
            return _targetId;
        else if(nodeId == _targetId)
            return _sourceId;

        return NodeId();
    }

    bool isLoop() const { return sourceId() == targetId(); }

    EdgeId id() const { return _id; }
};

class ReadOnlyGraph
{
public:
    virtual const std::vector<NodeId>& nodeIds() const = 0;
    virtual int numNodes() const = 0;
    virtual const Node& nodeById(NodeId nodeId) const = 0;
    NodeId firstNodeId() const { return nodeIds().size() > 0 ? nodeIds().at(0) : NodeId(); }

    virtual const std::vector<EdgeId>& edgeIds() const = 0;
    virtual int numEdges() const = 0;
    virtual const Edge& edgeById(EdgeId edgeId) const = 0;
    EdgeId firstEdgeId() const { return edgeIds().size() > 0 ? edgeIds().at(0) : EdgeId(); }

    virtual void dumpToQDebug(int detail) const
    {
        qDebug() << numNodes() << "nodes" << numEdges() << "edges";

        if(detail > 1)
        {
            for(NodeId nodeId : nodeIds())
                qDebug() << "Node" << nodeId;

            for(EdgeId edgeId : edgeIds())
            {
                const Edge& edge = edgeById(edgeId);
                qDebug() << "Edge" << edgeId << "(" << edge.sourceId() << "->" << edge.targetId() << ")";
            }
        }
    }
};

class Graph : public QObject, public ReadOnlyGraph
{
    Q_OBJECT
public:
    Graph();
    virtual ~Graph();

private:
    std::vector<bool> _nodeIdsInUse;
    std::vector<NodeId> _nodeIdsVector;
    std::deque<NodeId> _unusedNodeIdsDeque;
    std::vector<Node> _nodesVector;
    NodeId _lastNodeId;

    std::vector<bool> _edgeIdsInUse;
    std::vector<EdgeId> _edgeIdsVector;
    std::deque<EdgeId> _unusedEdgeIdsDeque;
    std::vector<Edge> _edgesVector;
    EdgeId _lastEdgeId;

    template<typename> friend class NodeArray;
    QList<ResizableGraphArray*> _nodeArrayList;
    int nodeArrayCapacity() const { return _lastNodeId; }

    template<typename> friend class EdgeArray;
    QList<ResizableGraphArray*> _edgeArrayList;
    int edgeArrayCapacity() const { return _lastEdgeId; }

    template<typename> friend class ComponentArray;
    ComponentManager* _componentManager;

    void updateElementIdData();

public:
    void clear();
    void setComponentManager(ComponentManager* _componentManager);

    const std::vector<NodeId>& nodeIds() const { return _nodeIdsVector; }
    int numNodes() const { return _nodeIdsVector.size(); }
    const Node& nodeById(NodeId nodeId) const { return _nodesVector[nodeId]; }

    NodeId addNode();
    NodeId addNode(NodeId nodeId);
    NodeId addNode(const Node& node);
    void addNodes(const ElementIdSet<NodeId>& nodeIds);

    void removeNode(NodeId nodeId);
    void removeNodes(const ElementIdSet<NodeId>& nodeIds);

    const std::vector<EdgeId>& edgeIds() const { return _edgeIdsVector; }
    int numEdges() const { return _edgeIdsVector.size(); }
    const Edge& edgeById(EdgeId edgeId) const { return _edgesVector[edgeId]; }

    EdgeId addEdge(NodeId sourceId, NodeId targetId);
    EdgeId addEdge(EdgeId edgeId, NodeId sourceId, NodeId targetId);
    EdgeId addEdge(const Edge& edge);
    void addEdges(const std::vector<Edge>& edges);

    void removeEdge(EdgeId edgeId);
    void removeEdges(const ElementIdSet<EdgeId>& edgeIds);

    const std::vector<ComponentId>* componentIds() const;
    ComponentId firstComponentId() const { return *componentIds()->begin(); }
    int numComponents() const;
    const ReadOnlyGraph* componentById(ComponentId componentId) const;
    const ReadOnlyGraph* firstComponent() const { return componentById(firstComponentId()); }
    ComponentId componentIdOfNode(NodeId nodeId) const;
    ComponentId componentIdOfEdge(EdgeId edgeId) const;

    const ElementIdSet<EdgeId> edgeIdsForNodes(const ElementIdSet<NodeId>& nodeIds);
    const std::vector<Edge> edgesForNodes(const ElementIdSet<NodeId>& nodeIds);

    void dumpToQDebug(int detail) const;

private:
    int _graphChangeDepth;
    void beginTransaction();
    void endTransaction();

public:
    class ScopedTransaction
    {
    public:
        ScopedTransaction(Graph& graph) :
            _graph(graph)
        {
            _graph.beginTransaction();
        }

        ~ScopedTransaction()
        {
            _graph.endTransaction();
        }

    private:
        Graph& _graph;
    };

    void performTransaction(std::function<void(Graph& graph)> transaction)
    {
        ScopedTransaction lock(*this);
        transaction(*this);
    }

signals:
    void graphWillChange(const Graph*) const;
    void graphChanged(const Graph*) const;
    void nodeAdded(const Graph*, NodeId) const;
    void nodeWillBeRemoved(const Graph*, NodeId) const;
    void edgeAdded(const Graph*, EdgeId) const;
    void edgeWillBeRemoved(const Graph*, EdgeId) const;
    void componentAdded(const Graph*, ComponentId) const;
    void componentWillBeRemoved(const Graph*, ComponentId) const;
    void componentSplit(const Graph*, ComponentId, const ElementIdSet<ComponentId>&) const;
    void componentsWillMerge(const Graph*, const ElementIdSet<ComponentId>&, ComponentId) const;
};

#endif // GRAPH_H
