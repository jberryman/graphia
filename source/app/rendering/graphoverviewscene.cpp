#include "graphoverviewscene.h"
#include "graphrenderer.h"
#include "graphcomponentrenderer.h"

#include "graph/graph.h"
#include "graph/graphmodel.h"

#include "layout/nodepositions.h"
#include "layout/powerof2gridcomponentlayout.h"
#include "layout/circlepackcomponentlayout.h"

#include "commands/commandmanager.h"

#include "ui/graphquickitem.h"

#include "shared/utils/utils.h"
#include "shared/utils/container.h"
#include "shared/utils/preferences.h"
#include "shared/utils/scope_exit.h"

#include <QPoint>

#include <stack>
#include <algorithm>
#include <functional>
#include <vector>

GraphOverviewScene::GraphOverviewScene(CommandManager* commandManager, GraphRenderer* graphRenderer) :
    Scene(graphRenderer),
    _graphRenderer(graphRenderer),
    _commandManager(commandManager),
    _graphModel(graphRenderer->graphModel()),
    _previousComponentAlpha(_graphModel->graph(), 1.0f),
    _componentAlpha(_graphModel->graph(), 1.0f),
    _nextComponentLayoutDataChanged(false),
    _nextComponentLayoutData(_graphModel->graph()),
    _componentLayoutData(_graphModel->graph()),
    _previousZoomedComponentLayoutData(_graphModel->graph()),
    _zoomedComponentLayoutData(_graphModel->graph()),
    _componentLayout(std::make_unique<CirclePackComponentLayout>())
{
    connect(&_graphModel->graph(), &Graph::componentAdded, this, &GraphOverviewScene::onComponentAdded, Qt::DirectConnection);
    connect(&_graphModel->graph(), &Graph::componentWillBeRemoved, this, &GraphOverviewScene::onComponentWillBeRemoved, Qt::DirectConnection);
    connect(&_graphModel->graph(), &Graph::componentSplit, this, &GraphOverviewScene::onComponentSplit, Qt::DirectConnection);
    connect(&_graphModel->graph(), &Graph::componentsWillMerge, this, &GraphOverviewScene::onComponentsWillMerge, Qt::DirectConnection);
    connect(&_graphModel->graph(), &Graph::graphWillChange, this, &GraphOverviewScene::onGraphWillChange, Qt::DirectConnection);
    connect(&_graphModel->graph(), &Graph::graphChanged, this, &GraphOverviewScene::onGraphChanged, Qt::DirectConnection);

    connect(&_zoomTransition, &Transition::started, _graphRenderer, &GraphRenderer::rendererStartedTransition, Qt::DirectConnection);
    connect(&_zoomTransition, &Transition::finished, _graphRenderer, &GraphRenderer::rendererFinishedTransition, Qt::DirectConnection);

    connect(S(Preferences), &Preferences::preferenceChanged, this, &GraphOverviewScene::onPreferenceChanged, Qt::DirectConnection);
}

void GraphOverviewScene::update(float t)
{
    _zoomTransition.update(t);

    for(auto componentId : _componentIds)
    {
        auto* renderer = _graphRenderer->componentRendererForId(componentId);
        Q_ASSERT(renderer->initialised());
        renderer->setDimensions(_zoomedComponentLayoutData[componentId].boundingBox());
        renderer->setAlpha(_componentAlpha[componentId]);
        renderer->update(t);
    }
}

void GraphOverviewScene::onShow()
{
    for(auto componentId : _componentIds)
    {
        auto renderer = _graphRenderer->componentRendererForId(componentId);
        renderer->setVisible(true);
    }

    _graphRenderer->onVisibilityChanged();
}

void GraphOverviewScene::onHide()
{
    for(auto componentId : _componentIds)
    {
        auto renderer = _graphRenderer->componentRendererForId(componentId);
        renderer->setVisible(false);
    }

    _graphRenderer->onVisibilityChanged();
}

void GraphOverviewScene::resetView(bool doTransition)
{
    setZoomFactor(minZoomFactor());
    setOffset(0.0f, 0.0f);

    if(doTransition)
        startZoomTransition();
    else
        updateZoomedComponentLayoutData();
}

bool GraphOverviewScene::viewIsReset() const
{
    return _autoZooming;
}

void GraphOverviewScene::pan(float dx, float dy)
{
    float scaledDx = dx / (_zoomFactor);
    float scaledDy = dy / (_zoomFactor);

    setOffset(static_cast<float>(_offset.x()) - scaledDx,
              static_cast<float>(_offset.y()) - scaledDy);

    updateZoomedComponentLayoutData();
}

void GraphOverviewScene::zoom(GraphOverviewScene::ZoomType zoomType, float x, float y, bool doTransition)
{
    const float ZOOM_INCREMENT = 0.2f;

    switch(zoomType)
    {
    case ZoomType::In:  zoom( ZOOM_INCREMENT, x, y, doTransition); break;
    case ZoomType::Out: zoom(-ZOOM_INCREMENT, x, y, doTransition); break;
    default: break;
    }
}

void GraphOverviewScene::zoom(float delta, float x, float y, bool doTransition)
{
    float nx = x / _width;
    float ny = y / _height;

    float oldCentreX = (nx * _width) / _zoomFactor;
    float oldCentreY = (ny * _height) / _zoomFactor;

    if(!setZoomFactor(_zoomFactor + (delta * _zoomFactor)))
        return;

    float newCentreX = (nx * _width) / _zoomFactor;
    float newCentreY = (ny * _height) / _zoomFactor;

    setOffset(static_cast<float>(_offset.x()) + (oldCentreX - newCentreX),
              static_cast<float>(_offset.y()) + (oldCentreY - newCentreY));

    _zoomCentre.setX(newCentreX);
    _zoomCentre.setY(newCentreY);

    if(doTransition)
        startZoomTransition();
    else
        updateZoomedComponentLayoutData();
}

Circle GraphOverviewScene::zoomedLayoutData(const Circle& data)
{
    Circle newData(data);

    newData.translate(-_offset - _zoomCentre);
    newData.scale(_zoomFactor);
    newData.translate(_zoomCentre * _zoomFactor);

    return newData;
}

float GraphOverviewScene::minZoomFactor() const
{
    if(_componentLayout->boundingWidth() <= 0.0f && _componentLayout->boundingHeight() <= 0.0f)
        return 1.0f;

    float minWidthZoomFactor = _width / _componentLayout->boundingWidth();
    float minHeightZoomFactor = _height / _componentLayout->boundingHeight();

    return std::min(minWidthZoomFactor, minHeightZoomFactor);
}

bool GraphOverviewScene::setZoomFactor(float zoomFactor)
{
    zoomFactor = std::max(minZoomFactor(), zoomFactor);
    bool changed = _zoomFactor != zoomFactor;
    _zoomFactor = zoomFactor;
    _autoZooming = (_zoomFactor == minZoomFactor());

    return changed;
}

void GraphOverviewScene::setOffset(float x, float y)
{
    float scaledBoundingWidth = _componentLayout->boundingWidth() * _zoomFactor;
    float scaledBoundingHeight = _componentLayout->boundingHeight() * _zoomFactor;

    float xDiff = (scaledBoundingWidth - _width) / _zoomFactor;
    float xMin = std::min(xDiff, 0.0f);
    float xMax = std::max(xDiff, 0.0f);

    if(scaledBoundingWidth > _width)
        x = std::clamp(x, xMin, xMax);
    else
        x = (xMin + xMax) * 0.5f;

    float yDiff = (scaledBoundingHeight - _height) / _zoomFactor;
    float yMin = std::min(yDiff, 0.0f);
    float yMax = std::max(yDiff, 0.0f);

    if(scaledBoundingHeight > _height)
        y = std::clamp(y, yMin, yMax);
    else
        y = (yMin + yMax) * 0.5f;

    _offset.setX(x);
    _offset.setY(y);
}

void GraphOverviewScene::startTransitionFromComponentMode(ComponentId focusComponentId,
                                                          std::function<void()> finishedFunction,
                                                          float duration,
                                                          Transition::Type transitionType)
{
    Q_ASSERT(!focusComponentId.isNull());

    float halfWidth = _width * 0.5f;
    float halfHeight = _height * 0.5f;
    Circle focusComponentLayout(halfWidth, halfHeight, std::min(halfWidth, halfHeight));

    // If the component that has focus isn't in the overview scene's component list then it's
    // going away, in which case we need to deal with it
    if(!u::contains(_componentIds, focusComponentId))
    {
        _removedComponentIds.emplace_back(focusComponentId);
        _componentIds.emplace_back(focusComponentId);

        // Target display properties
        _zoomedComponentLayoutData[focusComponentId] = focusComponentLayout;
        _componentAlpha[focusComponentId] = 0.0f;

        // The renderer should have already been frozen by GraphComponentScene::onComponentWillBeRemoved,
        // but let's make sure
        auto renderer = _graphRenderer->componentRendererForId(focusComponentId);
        renderer->freeze();
    }

    startTransition(std::move(finishedFunction), duration, transitionType);
    _previousZoomedComponentLayoutData = _zoomedComponentLayoutData;
    _previousComponentAlpha.fill(0.0f);

    // The focus component always starts covering the viewport and fully opaque
    _previousZoomedComponentLayoutData[focusComponentId] = focusComponentLayout;
    _previousComponentAlpha[focusComponentId] = 1.0f;
}

void GraphOverviewScene::startTransitionToComponentMode(ComponentId focusComponentId,
                                                        std::function<void()> finishedFunction,
                                                        float duration,
                                                        Transition::Type transitionType)
{
    Q_ASSERT(!focusComponentId.isNull());

    _previousZoomedComponentLayoutData = _zoomedComponentLayoutData;
    _previousComponentAlpha = _componentAlpha;

    for(auto componentId : _componentIds)
    {
        if(componentId != focusComponentId)
            _componentAlpha[componentId] = 0.0f;
    }

    float halfWidth = _width * 0.5f;
    float halfHeight = _height * 0.5f;
    _zoomedComponentLayoutData[focusComponentId].set(halfWidth, halfHeight,
                                                     std::min(halfWidth, halfHeight));

    startTransition(std::move(finishedFunction), duration, transitionType);
}

void GraphOverviewScene::updateZoomedComponentLayoutData()
{
    for(auto componentId : _componentIds)
        _zoomedComponentLayoutData[componentId] = zoomedLayoutData(_componentLayoutData[componentId]);
}

void GraphOverviewScene::applyComponentLayout()
{
    if(_nextComponentLayoutDataChanged.exchange(false))
        _componentLayoutData = _nextComponentLayoutData;

    setZoomFactor(_autoZooming ? minZoomFactor() : _zoomFactor);
    setOffset(_offset.x(), _offset.y());

    updateZoomedComponentLayoutData();

    for(auto componentId : _componentIds)
    {
        _componentAlpha[componentId] = 1.0f;

        // If the component is fading in, keep it in a fixed position
        if(_previousComponentAlpha[componentId] == 0.0f)
            _previousZoomedComponentLayoutData[componentId] = _zoomedComponentLayoutData[componentId];
    }

    // Give the mergers the same layout as the new component
    for(const auto& componentMergeSet : _componentMergeSets)
    {
        auto newComponentId = componentMergeSet.newComponentId();

        for(const auto& merger : componentMergeSet.mergers())
        {
            _zoomedComponentLayoutData[merger] = _zoomedComponentLayoutData[newComponentId];
            _componentAlpha[merger] = _componentAlpha[newComponentId];
        }
    }
}

void GraphOverviewScene::setViewportSize(int width, int height)
{
    _width = width;
    _height = height;

    applyComponentLayout();

    for(auto componentId : _componentIds)
    {
        auto renderer = _graphRenderer->componentRendererForId(componentId);
        renderer->setViewportSize(_width, _height);
        renderer->setDimensions(_zoomedComponentLayoutData[componentId].boundingBox());
    }
}

bool GraphOverviewScene::transitionActive() const
{
    if(_zoomTransition.active())
        return true;

    for(auto componentId : _componentIds)
    {
        auto renderer = _graphRenderer->componentRendererForId(componentId);

        if(renderer->transitionActive())
            return true;
    }

    return false;
}

static Circle interpolateCircle(const Circle& a, const Circle& b, float f)
{
    return {
        u::interpolate(a.x(),       b.x(),      f),
        u::interpolate(a.y(),       b.y(),      f),
        u::interpolate(a.radius(),  b.radius(), f)
        };
}

void GraphOverviewScene::startTransition(std::function<void()> finishedFunction, float duration,
                                         Transition::Type transitionType)
{
    auto targetComponentLayoutData = _zoomedComponentLayoutData;
    auto targetComponentAlpha = _componentAlpha;

    _graphRenderer->transition().start(duration, transitionType,
    [this, targetComponentLayoutData = std::move(targetComponentLayoutData),
           targetComponentAlpha = std::move(targetComponentAlpha)](float f)
    {
        auto interpolate = [&](const ComponentId componentId)
        {
            _zoomedComponentLayoutData[componentId] = interpolateCircle(_previousZoomedComponentLayoutData[componentId],
                                                                        targetComponentLayoutData[componentId], f);
            _componentAlpha[componentId] = u::interpolate(_previousComponentAlpha[componentId],
                                                          targetComponentAlpha[componentId], f);

            _graphRenderer->componentRendererForId(componentId)->updateTransition(f);
        };

        for(auto componentId : _componentIds)
            interpolate(componentId);
    },
    [this]
    {
        _previousZoomedComponentLayoutData = _zoomedComponentLayoutData;
        _previousComponentAlpha = _componentAlpha;

        for(auto componentId : _removedComponentIds)
        {
            auto renderer = _graphRenderer->componentRendererForId(componentId);
            renderer->thaw();
        }

        for(const auto& componentMergeSet : _componentMergeSets)
        {
            auto renderer = _graphRenderer->componentRendererForId(componentMergeSet.newComponentId());
            renderer->thaw();
        }

        // Subtract the removed ComponentIds, as we no longer need to render them
        std::vector<ComponentId> postTransitionComponentIds;
        std::sort(_componentIds.begin(), _componentIds.end());
        std::sort(_removedComponentIds.begin(), _removedComponentIds.end());
        std::set_difference(_componentIds.begin(), _componentIds.end(),
                            _removedComponentIds.begin(), _removedComponentIds.end(),
                            std::inserter(postTransitionComponentIds, postTransitionComponentIds.begin()));

        _componentIds = std::move(postTransitionComponentIds);

        _removedComponentIds.clear();
        _componentMergeSets.clear();

        _graphRenderer->sceneFinishedTransition();
    },
    std::move(finishedFunction));

    // Reset all components by default
    for(auto componentId : _componentIds)
    {
        auto renderer = _graphRenderer->componentRendererForId(componentId);
        renderer->resetView();
    }

    for(const auto& componentMergeSet : _componentMergeSets)
    {
        auto mergedComponent = _graphModel->graph().componentById(componentMergeSet.newComponentId());
        auto& mergedNodeIds = mergedComponent->nodeIds();
        auto mergedFocusPosition = NodePositions::centreOfMassScaledAndSmoothed(_graphModel->nodePositions(),
                                                                                mergedNodeIds);

        // Use the rotation of the new component
        auto renderer = _graphRenderer->componentRendererForId(componentMergeSet.newComponentId());
        QQuaternion rotation = renderer->camera()->rotation();
        auto maxDistance = GraphComponentRenderer::maxNodeDistanceFromPoint(*_graphModel,
                                                                            mergedFocusPosition,
                                                                            mergedNodeIds);

        for(auto merger : componentMergeSet.mergers())
        {
            renderer = _graphRenderer->componentRendererForId(merger);
            renderer->moveFocusToPositionAndRadius(mergedFocusPosition, maxDistance, rotation);
        }
    }
}

void GraphOverviewScene::startZoomTransition(float duration)
{
    ComponentLayoutData targetZoomedComponentLayoutData(_graphModel->graph());

    _previousZoomedComponentLayoutData = _zoomedComponentLayoutData;

    for(auto componentId : _componentIds)
        targetZoomedComponentLayoutData[componentId] = zoomedLayoutData(_componentLayoutData[componentId]);

    _zoomTransition.start(duration, Transition::Type::InversePower,
    [this, targetZoomedComponentLayoutData](float f)
    {
        for(auto componentId : _componentIds)
        {
            _zoomedComponentLayoutData[componentId] =
                    interpolateCircle(_previousZoomedComponentLayoutData[componentId],
                                      targetZoomedComponentLayoutData[componentId], f);
        }
    });
}

void GraphOverviewScene::onComponentAdded(const Graph*, ComponentId componentId, bool hasSplit)
{
    if(!hasSplit)
    {
        _graphRenderer->executeOnRendererThread([this, componentId]
        {
            if(visible())
                _previousComponentAlpha[componentId] = 0.0f;
        }, QStringLiteral("GraphOverviewScene::onComponentAdded (set source alpha to 0)"));
    }
}

void GraphOverviewScene::onComponentWillBeRemoved(const Graph*, ComponentId componentId, bool hasMerged)
{
    if(!visible())
        return;

    if(!hasMerged)
    {
        _graphRenderer->executeOnRendererThread([this, componentId]
        {
            auto renderer = _graphRenderer->componentRendererForId(componentId);
            renderer->freeze();

            _removedComponentIds.emplace_back(componentId);
            _componentAlpha[componentId] = 0.0f;
        }, QStringLiteral("GraphOverviewScene::onComponentWillBeRemoved (freeze renderer, set target alpha to 0)"));
    }
}

void GraphOverviewScene::onComponentSplit(const Graph*, const ComponentSplitSet& componentSplitSet)
{
    if(!visible())
        return;

    _graphRenderer->executeOnRendererThread([this, componentSplitSet]
    {
        if(visible())
        {
            auto oldComponentId = componentSplitSet.oldComponentId();
            auto oldGraphComponentRenderer = _graphRenderer->componentRendererForId(oldComponentId);

            for(auto splitter : componentSplitSet.splitters())
            {
                auto renderer = _graphRenderer->componentRendererForId(splitter);
                renderer->cloneViewDataFrom(*oldGraphComponentRenderer);
                _previousZoomedComponentLayoutData[splitter] = _zoomedComponentLayoutData[oldComponentId];
                _previousComponentAlpha[splitter] = _componentAlpha[oldComponentId];
            }
        }
    }, QStringLiteral("GraphOverviewScene::onComponentSplit (cloneCameraDataFrom, component layout)"));
}

void GraphOverviewScene::onComponentsWillMerge(const Graph*, const ComponentMergeSet& componentMergeSet)
{
    if(!visible())
        return;

    _graphRenderer->executeOnRendererThread([this, componentMergeSet]
    {
        _componentMergeSets.emplace_back(componentMergeSet);

        for(auto merger : componentMergeSet.mergers())
        {
            auto renderer = _graphRenderer->componentRendererForId(merger);
            renderer->freeze();

            if(merger != componentMergeSet.newComponentId())
                _removedComponentIds.emplace_back(merger);
        }
    }, QStringLiteral("GraphOverviewScene::onComponentsWillMerge (freeze renderers)"));
}

void GraphOverviewScene::onGraphWillChange(const Graph*)
{
    // Take a copy of the existing layout before the graph is changed
    _previousZoomedComponentLayoutData = _zoomedComponentLayoutData;
}

void GraphOverviewScene::startComponentLayoutTransition()
{
    if(visible())
    {
        bool componentLayoutDataChanged = _componentLayoutData != _nextComponentLayoutData;
        float duration = !componentLayoutDataChanged ? 0.0f : u::pref("visuals/transitionTime").toFloat();

        onShow();
        setViewportSize(_width, _height);

        startTransition([this]
        {
            // If a graph change has resulted in a single component, switch
            // to component mode once the transition had completed
            if(_graphModel->graph().numComponents() == 1)
            {
                _graphRenderer->transition().willBeImmediatelyReused();
                _graphRenderer->switchToComponentMode();
            }
        }, duration, Transition::Type::EaseInEaseOut);
    }
}

void GraphOverviewScene::onGraphChanged(const Graph* graph, bool changed)
{
    std::experimental::make_scope_exit([this] { _graphRenderer->resumeRendererThreadExecution(); });

    if(!changed)
        return;

    graph->setPhase(tr("Component Layout"));
    _componentLayout->execute(*graph, graph->componentIds(), _nextComponentLayoutData);
    graph->clearPhase();

    _nextComponentLayoutDataChanged = true;

    _graphRenderer->executeOnRendererThread([this, graph]
    {
        _componentIds = graph->componentIds();

        startComponentLayoutTransition();

        // We still need to render any components that have been removed, while they
        // transition away
        _componentIds.insert(_componentIds.end(),
                             _removedComponentIds.begin(),
                             _removedComponentIds.end());
    }, QStringLiteral("GraphOverviewScene::onGraphChanged"));
}

void GraphOverviewScene::onPreferenceChanged(const QString& key, const QVariant&)
{
    if(visible() && (key == QLatin1String("visuals/minimumComponentRadius") ||
                     key == QLatin1String("visuals/defaultNodeSize")))
    {
        _commandManager->executeOnce(
        [this](Command&)
        {
            auto* graph = &_graphModel->graph();

            _previousZoomedComponentLayoutData = _zoomedComponentLayoutData;

            _componentLayout->execute(*graph, graph->componentIds(), _nextComponentLayoutData);
            _nextComponentLayoutDataChanged = true;

            _graphRenderer->executeOnRendererThread([this]
            {
                this->startComponentLayoutTransition();
            }, QStringLiteral("GraphOverviewScene::onPreferenceChanged"));
        }, {tr("Component Layout")});
    }
}
