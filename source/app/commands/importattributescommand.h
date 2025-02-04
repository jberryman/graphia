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

#ifndef IMPORTATTRIBUTESCOMMAND_H
#define IMPORTATTRIBUTESCOMMAND_H

#include "shared/commands/icommand.h"

#include "shared/loading/tabulardata.h"

#include <QString>

#include <vector>
#include <set>

class GraphModel;

class ImportAttributesCommand : public ICommand
{
private:
    GraphModel* _graphModel = nullptr;

    QString _keyAttributeName;
    TabularData _data;
    int _keyColumnIndex;
    std::vector<int> _importColumnIndices;

    bool _multipleAttributes = false;

    std::set<QString> _createdVectorNames;
    std::vector<QString> _createdAttributeNames;

public:
    ImportAttributesCommand(GraphModel* graphModel, const QString& keyAttributeName,
        TabularData* data, int keyColumnIndex, std::vector<int> importColumnIndices);

    QString description() const override;
    QString verb() const override;
    QString pastParticiple() const override;

    QString debugDescription() const override;

    bool execute() override;
    void undo() override;
};

#endif // IMPORTATTRIBUTESCOMMAND_H
