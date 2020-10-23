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

#ifndef AVAILABLEATTRIBUTESMODEL_H
#define AVAILABLEATTRIBUTESMODEL_H

#include "shared/graph/elementtype.h"
#include "shared/attributes/iattribute.h"
#include "shared/attributes/valuetype.h"

#include <QAbstractItemModel>
#include <QList>
#include <QVariant>

#include <set>

class GraphModel;
class Attribute;

class AvailableAttributesModel : public QAbstractItemModel
{
    Q_OBJECT

private:
    class Item
    {
    private:
        // Either the attribute name, or a parameter to the parent attribute
        QString _value;
        const Attribute* _attribute = nullptr;

        QList<Item*> _children;
        Item* _parent = nullptr;

    public:
        explicit Item(QString value, const Attribute* attribute = nullptr);
        virtual ~Item();

        void addChild(Item* child);

        Item* child(int row) const;
        int childCount() const;
        const QString& value() const;
        int row() const;
        Item* parent() const;
        const Attribute* attribute() const;
    };

    Item* _root = nullptr;

    // When listing edge attributes, we want their source and target node attributes too
    // cppcheck-suppress unsafeClassCanLeak
    Item* _sourceNode = nullptr;
    // cppcheck-suppress unsafeClassCanLeak
    Item* _targetNode = nullptr;

    std::set<Item*> _attributeItemsWithParameters;

    static Item* parentItem(const QModelIndex& index);

    enum Roles
    {
        ElementTypeRole = Qt::UserRole + 1,
        ValueTypeRole,
        HasSharedValuesRole,
        SearchableRole,
        UserDefinedRole,
        HasChildrenRole,
    };

    const GraphModel* _graphModel = nullptr;

public:
    AvailableAttributesModel() = default;
    explicit AvailableAttributesModel(const GraphModel& graphModel,
        QObject* parent = nullptr, ElementType elementTypes = ElementType::All,
        ValueType valueTypes = ValueType::All, AttributeFlag skipFlags = AttributeFlag::None,
        const QStringList& skipAttributeNames = {});
    ~AvailableAttributesModel() override;

    QVariant data(const QModelIndex& index, int role) const override;
    Qt::ItemFlags flags(const QModelIndex& index) const override;
    QVariant headerData(int section, Qt::Orientation orientation,
                        int role = Qt::DisplayRole) const override;
    QModelIndex index(int row, int column,
                      const QModelIndex& parentIndex = QModelIndex()) const override;
    QModelIndex parent(const QModelIndex& index) const override;
    int rowCount(const QModelIndex& parentIndex = QModelIndex()) const override;
    int columnCount(const QModelIndex& parent = QModelIndex()) const override;

    Q_INVOKABLE QString get(const QModelIndex& index, int depth = 0) const;

    Q_INVOKABLE QModelIndex find(const QString& name) const;

    QHash<int, QByteArray> roleNames() const override;
};

#endif // AVAILABLEATTRIBUTESMODEL_H
