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

#ifndef ICOMMAND_H
#define ICOMMAND_H

#include <QString>
#include <QDebug>
#include <QtGlobal>

#include <atomic>
#include <cassert>
#include <memory>
#include <vector>

#include "shared/utils/progressable.h"
#include "shared/utils/cancellable.h"

class ICommand : virtual public Progressable, virtual public Cancellable
{
public:
    ~ICommand() override = default;

    virtual QString description() const = 0;
    virtual QString verb() const { return description(); }
    virtual QString pastParticiple() const { return {}; }

    // A more detailed description for the purposes of debugging
    virtual QString debugDescription() const { return description(); }

    // Return false if the command failed, or did nothing
    virtual bool execute() = 0;
    virtual void undo() { Q_ASSERT(!"undo() not implemented for this ICommand"); }

    // ICommandManager has an interface that allows for the most recently executed
    // command to be replaced by another. When this happens it will normally be
    // necessary that some state is transferred from the replacee command. Most
    // commands will not need to implement this.
    virtual void replaces(const ICommand*) { Q_ASSERT(!"replaces() not implemented for this ICommand"); }

    void setProgress(int progress) override
    {
        Progressable::setProgress(progress);
        _progress = progress;
    }

    virtual int progress() const { return _progress; }

    virtual void initialise()
    {
        _progress = -1;
        uncancel();
    }

    virtual bool cancellable() const { return false; }

private:
    std::atomic<int> _progress{-1};
};

using ICommandPtr = std::unique_ptr<ICommand>;
using ICommandPtrsVector = std::vector<ICommandPtr>;

#endif // ICOMMAND_H
