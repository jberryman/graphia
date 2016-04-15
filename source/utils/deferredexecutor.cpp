#include "deferredexecutor.h"

#include "../utils/utils.h"

#include <QDebug>
#include <QtGlobal>

DeferredExecutor::DeferredExecutor() :
    _executing(false)
{
    _debug = qgetenv("DEFERREDEXECUTOR_DEBUG").toInt();
}

DeferredExecutor::~DeferredExecutor()
{
    cancel();
}

void DeferredExecutor::enqueue(TaskFn function, const QString& description)
{
    std::unique_lock<std::recursive_mutex> lock(_mutex);

    Task task;
    task._function = function;
    task._description = description;

    if(_debug > 1)
        qDebug() << "enqueue(...) thread:" << u::currentThreadName() << description;

    _tasks.emplace_back(task);
}

void DeferredExecutor::execute()
{
    std::unique_lock<std::recursive_mutex> lock(_mutex);

    if(!_tasks.empty() && _debug > 0)
    {
        qDebug() << "execute() thread" << u::currentThreadName();

        for(auto& task : _tasks)
            qDebug() << "\t" << task._description;
    }

    while(!_tasks.empty())
        executeOne();
}

void DeferredExecutor::executeOne()
{
    std::unique_lock<std::recursive_mutex> lock(_mutex);

    auto& task = _tasks.front();

    if(_debug > 2)
        qDebug() << "Executing" << task._description;

    _executing = true;
    task._function();
    _executing = false;
    _tasks.pop_front();
}

void DeferredExecutor::cancel()
{
    std::unique_lock<std::recursive_mutex> lock(_mutex);

    while(!_tasks.empty())
        _tasks.pop_front();
}

bool DeferredExecutor::hasTasks() const
{
    std::unique_lock<std::recursive_mutex> lock(_mutex);

    return !_tasks.empty();
}
