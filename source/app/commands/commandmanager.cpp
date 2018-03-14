#include "commandmanager.h"

#include "shared/utils/thread.h"

#include <QDebug>

#include <thread>

CommandManager::CommandManager() :
    _busy(false),
    _graphChanged(false)
{
    connect(this, &CommandManager::commandQueued, this, &CommandManager::update);
    connect(this, &CommandManager::commandCompleted, this, &CommandManager::onCommandCompleted);

    _debug = qEnvironmentVariableIntValue("COMMAND_DEBUG");
}

CommandManager::~CommandManager()
{
    if(_thread.joinable())
    {
        if(_currentCommand != nullptr)
            _currentCommand->cancel();

        _thread.join();
    }
}

void CommandManager::execute(std::unique_ptr<ICommand> command)
{
    std::unique_lock<std::recursive_mutex> lock(_mutex);
    _pendingCommands.emplace_back(CommandAction::Execute, std::move(command));
    emit commandQueued();
}

void CommandManager::executeOnce(std::unique_ptr<ICommand> command)
{
    std::unique_lock<std::recursive_mutex> lock(_mutex);
    _pendingCommands.emplace_back(CommandAction::ExecuteOnce, std::move(command));
    emit commandQueued();
}

void CommandManager::undo()
{
    std::unique_lock<std::recursive_mutex> lock(_mutex);
    _pendingCommands.emplace_back(CommandAction::Undo);
    emit commandQueued();
}

void CommandManager::redo()
{
    std::unique_lock<std::recursive_mutex> lock(_mutex);
    _pendingCommands.emplace_back(CommandAction::Redo);
    emit commandQueued();
}

void CommandManager::executeReal(std::unique_ptr<ICommand> command, bool irreversible)
{
    if(_debug > 0)
        qDebug() << "Command started" << command->description();

    auto commandPtr = command.get();
    auto verb = command->verb();
    doCommand(commandPtr, verb, [this, command = std::move(command), irreversible]() mutable
    {
        std::unique_lock<std::recursive_mutex> lock(_mutex);

        QString threadName = command->description().length() > 0 ?
            command->description() : QStringLiteral("Anon Command");
        u::setCurrentThreadName(threadName);

        _graphChanged = false;

        QString description;
        QString pastParticiple;
        bool success = false;

        if(command->execute() && !command->cancelled())
        {
            description = command->description();
            pastParticiple = command->pastParticiple();
            success = true;

            if(!irreversible)
            {
                // There are commands on the stack ahead of us; throw them away
                while(canRedoNoLocking())
                    _stack.pop_back();

                _stack.push_back(std::move(command));
                _lastExecutedIndex = static_cast<int>(_stack.size()) - 1;
            }
            else if(_graphChanged)
            {
                // The graph changed during an irreversible command, so throw
                // away our redo history as it is likely no longer coherent with
                // the current state
                clearCommandStackNoLocking();
            }
        }

        clearCurrentCommand();

        emit commandCompleted(success, description, pastParticiple);
    });
}

void CommandManager::undoReal()
{
    if(!canUndoNoLocking())
        return;

    auto command = _stack.at(_lastExecutedIndex).get();

    QString undoVerb = !command->description().isEmpty() ?
                QObject::tr("Undoing ") + command->description() :
                QObject::tr("Undoing");

    doCommand(command, undoVerb, [this, command]
    {
        std::unique_lock<std::recursive_mutex> lock(_mutex);

        u::setCurrentThreadName("(u) " + command->description());

        command->undo();
        _lastExecutedIndex--;

        clearCurrentCommand();

        emit commandCompleted(true, command->description(), QString());
    });
}

void CommandManager::redoReal()
{
    if(!canRedoNoLocking())
        return;

    auto command = _stack.at(++_lastExecutedIndex).get();

    QString redoVerb = !command->description().isEmpty() ?
                QObject::tr("Redoing ") + command->description() :
                QObject::tr("Redoing");

    doCommand(command, redoVerb, [this, command]
    {
        std::unique_lock<std::recursive_mutex> lock(_mutex);

        u::setCurrentThreadName("(r) " + command->description());

        command->execute();

        clearCurrentCommand();

        emit commandCompleted(true, command->description(), command->pastParticiple());
    });
}

bool CommandManager::canUndo() const
{
    std::unique_lock<std::recursive_mutex> lock(_mutex, std::try_to_lock);

    if(lock.owns_lock())
        return canUndoNoLocking();

    return false;
}

bool CommandManager::canRedo() const
{
    std::unique_lock<std::recursive_mutex> lock(_mutex, std::try_to_lock);

    if(lock.owns_lock())
        return canRedoNoLocking();

    return false;
}

bool CommandManager::commandIsCancellable() const
{
    std::unique_lock<std::mutex> lock(_currentCommandMutex);

    if(_currentCommand != nullptr)
        return _currentCommand->cancellable();

    return false;
}

const std::vector<QString> CommandManager::undoableCommandDescriptions() const
{
    std::unique_lock<std::recursive_mutex> lock(_mutex, std::try_to_lock);
    std::vector<QString> commandDescriptions;
    commandDescriptions.reserve(_lastExecutedIndex);

    if(lock.owns_lock() && canUndoNoLocking())
    {
        for(int index = _lastExecutedIndex; index >= 0; index--)
            commandDescriptions.push_back(_stack.at(index)->description());
    }

    return commandDescriptions;
}

const std::vector<QString> CommandManager::redoableCommandDescriptions() const
{
    std::unique_lock<std::recursive_mutex> lock(_mutex, std::try_to_lock);
    std::vector<QString> commandDescriptions;
    commandDescriptions.reserve(_stack.size());

    if(lock.owns_lock() && canRedoNoLocking())
    {
        for(int index = _lastExecutedIndex + 1; index < static_cast<int>(_stack.size()); index++)
            commandDescriptions.push_back(_stack.at(index)->description());
    }

    return commandDescriptions;
}

QString CommandManager::nextUndoAction() const
{
    std::unique_lock<std::recursive_mutex> lock(_mutex, std::try_to_lock);

    if(lock.owns_lock() && canUndoNoLocking())
    {
        auto& command = _stack.at(_lastExecutedIndex);
        if(!command->description().isEmpty())
            return QObject::tr("Undo ") + command->description();
    }

    return tr("Undo");
}

QString CommandManager::nextRedoAction() const
{
    std::unique_lock<std::recursive_mutex> lock(_mutex, std::try_to_lock);

    if(lock.owns_lock() && canRedoNoLocking())
    {
        auto& command = _stack.at(static_cast<size_t>(_lastExecutedIndex) + 1);
        if(!command->description().isEmpty())
            return QObject::tr("Redo ") + command->description();
    }

    return tr("Redo");
}

bool CommandManager::busy() const
{
    return _busy;
}

void CommandManager::clearCommandStack()
{
    std::unique_lock<std::recursive_mutex> lock(_mutex);

    // If a command is still in progress, wait until it's finished
    if(_thread.joinable())
        _thread.join();

    clearCommandStackNoLocking();
}

void CommandManager::clearCommandStackNoLocking()
{
    _stack.clear();
    _lastExecutedIndex = -1;

    // Force a UI update
    emit commandStackCleared();
}

void CommandManager::clearCurrentCommand()
{
    // _currentCommand is a raw pointer, so we must ensure it is reset to null
    // when the underlying unique_ptr is destroyed
    std::unique_lock<std::mutex> lock(_currentCommandMutex);
    _currentCommand = nullptr;

    bool wasCancelling = _cancelling;
    _cancelling = false;

    if(wasCancelling)
        emit commandIsCancellingChanged();
}


void CommandManager::cancel()
{
    std::unique_lock<std::mutex> lock(_currentCommandMutex);

    if(_currentCommand != nullptr)
    {
        _cancelling = true;
        emit commandIsCancellingChanged();
        _currentCommand->cancel();

        if(_debug > 0)
            qDebug() << "Command cancel request" << _currentCommand->description();
    }
}

void CommandManager::timerEvent(QTimerEvent*)
{
    std::unique_lock<std::mutex> lock(_currentCommandMutex);

    if(_currentCommand == nullptr)
        return;

    int newCommandProgress = _currentCommand->progress();

    if(newCommandProgress != _commandProgress)
    {
        _commandProgress = newCommandProgress;
        emit commandProgressChanged();
    }
}

bool CommandManager::canUndoNoLocking() const
{
    return _lastExecutedIndex >= 0;
}

bool CommandManager::canRedoNoLocking() const
{
    return _lastExecutedIndex < static_cast<int>(_stack.size()) - 1;
}

bool CommandManager::commandsArePending() const
{
    std::unique_lock<std::recursive_mutex> lock(_mutex);

    return !_pendingCommands.empty();
}

void CommandManager::onCommandCompleted(bool success, QString description, QString)
{
    killTimer(_commandProgressTimerId);
    _commandProgressTimerId = -1;

    if(_thread.joinable())
        _thread.join();

    if(_debug > 0)
    {
        if(success)
        {
            if(!description.isEmpty())
                qDebug() << "Command completed" << description;
            else
                qDebug() << "Command completed";
        }
        else
            qDebug() << "Command failed/cancelled";
    }

    if(commandsArePending())
        update();
    else
    {
        _busy = false;
        emit busyChanged();
        emit commandIsCancellableChanged();
    }
}

void CommandManager::update()
{
    std::unique_lock<std::recursive_mutex> lock(_mutex);

    if(!_thread.joinable() && commandsArePending())
    {
        auto pendingCommand = std::move(_pendingCommands.front());
        _pendingCommands.pop_front();

        switch(pendingCommand._action)
        {
        case CommandAction::Execute:      executeReal(std::move(pendingCommand._command), false); break;
        case CommandAction::ExecuteOnce:  executeReal(std::move(pendingCommand._command), true); break;
        case CommandAction::Undo:         undoReal(); break;
        case CommandAction::Redo:         redoReal(); break;
        default: break;
        }
    }
}
