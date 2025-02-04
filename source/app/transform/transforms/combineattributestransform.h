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

#ifndef COMBINEATTRIBUTESTRANSFORM_H
#define COMBINEATTRIBUTESTRANSFORM_H

#include "transform/graphtransform.h"

class CombineAttributesTransform : public GraphTransform
{
public:
    explicit CombineAttributesTransform(GraphModel& graphModel) :
        _graphModel(&graphModel)
    {}

    void apply(TransformedGraph& target) const override;

private:
    GraphModel* _graphModel = nullptr;
};

class CombineAttributesTransformFactory : public GraphTransformFactory
{
public:
    explicit CombineAttributesTransformFactory(GraphModel* graphModel) :
        GraphTransformFactory(graphModel)
    {}

    QString description() const override
    {
        return QObject::tr("Create a new attribute by combining "
            "two other attributes.");
    }

    QString category() const override { return QObject::tr("Attributes"); }

    GraphTransformAttributeParameters attributeParameters() const override
    {
        return
        {
            {
                "First Attribute",
                ElementType::NodeAndEdge, ValueType::All,
                QObject::tr("The first attribute from which the new attribute is created.")
            },
            {
                "Second Attribute",
                ElementType::NodeAndEdge, ValueType::All,
                QObject::tr("The second attribute from which the new attribute is created.")
            }
        };
    }

    GraphTransformParameters parameters() const override
    {
        return
        {
            {
                "Name",
                ValueType::String,
                QObject::tr("The name of the new attribute."),
                QObject::tr("New Attribute")
            },
            {
                "Attribute Value",
                ValueType::String,
                QObject::tr("The value to assign to the attribute. \\1 and \\2 will be substituted "
                    "by the first and second attributes, respectively."),
                R"(\1 \2)"
            }
        };
    }

    bool configIsValid(const GraphTransformConfig& graphTransformConfig) const override;
    std::unique_ptr<GraphTransform> create(const GraphTransformConfig& graphTransformConfig) const override;
};

#endif // COMBINEATTRIBUTESTRANSFORM_H
