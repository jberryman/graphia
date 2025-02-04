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

#include "visualisationconfig.h"

#include "shared/utils/container.h"

bool VisualisationConfig::Parameter::operator==(const VisualisationConfig::Parameter& other) const
{
    return _name == other._name &&
            _value == other._value;
}

QString VisualisationConfig::Parameter::valueAsString(bool addQuotes) const
{
    struct Visitor
    {
        bool _addQuotes;

        explicit Visitor(bool addQuotes_) : _addQuotes(addQuotes_) {}

        QString operator()(double d) const { return QString::number(d); }
        QString operator()(const QString& s) const
        {
            if(_addQuotes)
            {
                QString escapedString = s;
                escapedString.replace(QStringLiteral(R"(")"), QStringLiteral(R"(\")"));

                return QStringLiteral(R"("%1")").arg(escapedString);
            }

            return s;
        }
    };

    return std::visit(Visitor(addQuotes), _value);
}

QVariantMap VisualisationConfig::asVariantMap() const
{
    QVariantMap map;

    QVariantList flags;
    flags.reserve(static_cast<int>(_flags.size()));
    for(const auto& flag : _flags)
        flags.append(flag);
    map.insert(QStringLiteral("flags"), flags);

    map.insert(QStringLiteral("attribute"), _attributeName);
    map.insert(QStringLiteral("channel"), _channelName);

    QVariantMap parameters;
    for(const auto& parameter : _parameters)
        parameters.insert(parameter._name, parameter.valueAsString(true));
    map.insert(QStringLiteral("parameters"), parameters);

    return map;
}

QString VisualisationConfig::asString() const
{
    QString s;

    if(!_flags.empty())
    {
        s += QStringLiteral("[");
        for(const auto& flag : _flags)
        {
            if(s[s.length() - 1] != '[')
                s += QStringLiteral(", ");

            s += flag;
        }
        s += QStringLiteral("] ");
    }

    s += QStringLiteral(R"("%1" "%2")").arg(_attributeName, _channelName);

    if(!_parameters.empty())
    {
        s += QStringLiteral(" with ");

        for(const auto& parameter : _parameters)
        {
            // cppcheck-suppress useStlAlgorithm
            s += QStringLiteral(" %1 = %2").arg(parameter._name, parameter.valueAsString(true));
        }
    }

    return s;
}

QString VisualisationConfig::parameterValue(const QString& name) const
{
    for(const auto& parameter : _parameters)
    {
        if(parameter._name == name)
            return parameter.valueAsString();
    }

    return {};
}

bool VisualisationConfig::operator==(const VisualisationConfig& other) const
{
    return _attributeName == other._attributeName &&
           _channelName == other._channelName &&
           !u::setsDiffer(_parameters, other._parameters) &&
           !u::setsDiffer(_flags, other._flags);
}

bool VisualisationConfig::operator!=(const VisualisationConfig& other) const
{
    return !operator==(other);
}

bool VisualisationConfig::isFlagSet(const QString& flag) const
{
    return u::contains(_flags, flag);
}
