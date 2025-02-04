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

#ifndef ADJACENCYMATRIXFILEPARSER_H
#define ADJACENCYMATRIXFILEPARSER_H

#include "shared/loading/iparser.h"

#include "shared/loading/qmltabulardataparser.h"
#include "shared/loading/xlsxtabulardataparser.h"
#include "shared/loading/matlabfileparser.h"

#include "shared/utils/is_detected.h"

#include <QQmlEngine>
#include <QCoreApplication>
#include <QVariantMap>
#include <QPoint>

#include <type_traits>

class TabularData;

template<typename> class UserElementData;
using UserNodeData = UserElementData<NodeId>;
using UserEdgeData = UserElementData<EdgeId>;

class AdjacencyMatrixTabularDataParser : public QmlTabularDataParser
{
    Q_OBJECT

    Q_PROPERTY(QVariantMap graphSizeEstimate MEMBER _graphSizeEstimate NOTIFY graphSizeEstimateChanged)
    Q_PROPERTY(bool binaryMatrix MEMBER _binaryMatrix NOTIFY binaryMatrixChanged)

private:
    QVariantMap _graphSizeEstimate;
    bool _binaryMatrix = true;
    double _minimumAbsEdgeWeight = 0.0;
    bool _skipDuplicates = false;

    bool onParseComplete() override;

public:
    static bool isAdjacencyMatrix(const TabularData& tabularData, QPoint* topLeft = nullptr, size_t maxRows = 5);
    static bool isEdgeList(const TabularData& tabularData, size_t maxRows = 5);

    bool parse(const TabularData& tabularData, Progressable& progressable,
        IGraphModel* graphModel, UserNodeData* userNodeData, UserEdgeData* userEdgeData);

    double minimumAbsEdgeWeight() const { return _minimumAbsEdgeWeight; }
    bool skipDuplicates() const { return _skipDuplicates; }

    void setMinimumAbsEdgeWeight(double minimumAbsEdgeWeight) { _minimumAbsEdgeWeight = minimumAbsEdgeWeight; }
    void setSkipDuplicates(bool skipDuplicates) { _skipDuplicates = skipDuplicates; }

    static void registerQmlType()
    {
        static bool initialised = false;
        if(initialised)
            return;
        initialised = true;

        qmlRegisterType<AdjacencyMatrixTabularDataParser>(APP_URI, APP_MAJOR_VERSION,
            APP_MINOR_VERSION, "AdjacencyMatrixTabularDataParser");
    }

signals:
    void graphSizeEstimateChanged();
    void binaryMatrixChanged();
};

template<typename TabularDataParser>
class AdjacencyMatrixParser : public IParser, public AdjacencyMatrixTabularDataParser
{
private:
    UserNodeData* _userNodeData;
    UserEdgeData* _userEdgeData;
    TabularData _tabularData;

public:
    AdjacencyMatrixParser(UserNodeData* userNodeData, UserEdgeData* userEdgeData,
        TabularData* tabularData = nullptr) :
        _userNodeData(userNodeData), _userEdgeData(userEdgeData)
    {
        if(tabularData != nullptr)
            _tabularData = std::move(*tabularData);
    }

    bool parse(const QUrl& url, IGraphModel* graphModel) override
    {
        if(_tabularData.empty())
        {
            TabularDataParser parser(this);

            if(!parser.parse(url, graphModel))
                return false;

            _tabularData = std::move(parser.tabularData());
        }

        return AdjacencyMatrixTabularDataParser::parse(_tabularData, *this,
            graphModel, _userNodeData, _userEdgeData);
    }

    QString log() const override
    {
        QString text;

        if(minimumAbsEdgeWeight() > 0.0)
        {
            text.append(tr("Minimum Absolute Edge Weight: %1").arg(
                u::formatNumberScientific(minimumAbsEdgeWeight())));
        }

        if(skipDuplicates())
        {
            if(!text.isEmpty()) text.append("\n");
            text.append(tr("Duplicate Edges Filtered"));
        }

        return text;
    }

    template<typename Parser>
    using setRowLimit_t = decltype(std::declval<Parser>().setRowLimit(0));

    static bool canLoad(const QUrl& url)
    {
        if(!TabularDataParser::canLoad(url))
            return false;

        constexpr bool TabularDataParserHasSetRowLimit =
            std::experimental::is_detected_v<setRowLimit_t, TabularDataParser>;

        // If TabularDataParser has ::setRowLimit, do some additional checks
        if constexpr(TabularDataParserHasSetRowLimit)
        {
            TabularDataParser parser;
            parser.setRowLimit(5);
            parser.parse(url);
            const auto& tabularData = parser.tabularData();

            return AdjacencyMatrixTabularDataParser::isEdgeList(tabularData) ||
                AdjacencyMatrixTabularDataParser::isAdjacencyMatrix(tabularData);
        }

        return true;
    }
};

using AdjacencyMatrixTSVFileParser =    AdjacencyMatrixParser<TsvFileParser>;
using AdjacencyMatrixSSVFileParser =    AdjacencyMatrixParser<SsvFileParser>;
using AdjacencyMatrixCSVFileParser =    AdjacencyMatrixParser<CsvFileParser>;
using AdjacencyMatrixXLSXFileParser =   AdjacencyMatrixParser<XlsxTabularDataParser>;
using AdjacencyMatrixMatLabFileParser = AdjacencyMatrixParser<MatLabFileParser>;

static void adjacencyMatrixTabularDataParserInitialiser()
{
    AdjacencyMatrixTabularDataParser::registerQmlType();
}

Q_COREAPP_STARTUP_FUNCTION(adjacencyMatrixTabularDataParserInitialiser)

#endif // ADJACENCYMATRIXFILEPARSER_H
