#ifndef LAYOUTSETTINGS_H
#define LAYOUTSETTINGS_H

#include "shared/utils/utils.h"

#include <QObject>
#include <QString>

#include <vector>
#include <utility>
#include <algorithm>

enum class LayoutSettingScaleType { Linear, Log };

class LayoutSetting
{
public:
    LayoutSetting(QString name, QString displayName,
                  float minimumValue, float maximumValue, float defaultValue,
                  LayoutSettingScaleType scaleType = LayoutSettingScaleType::Linear) :
        _name(std::move(name)),
        _displayName(std::move(displayName)),
        _minimumValue(minimumValue),
        _maximumValue(maximumValue),
        _defaultValue(defaultValue),
        _value(defaultValue),
        _scaleType(scaleType)
    {}

    float value() const { return _value; }
    float normalisedValue() const;
    float minimumValue() const { return _minimumValue; }
    float maximumValue() const { return _maximumValue; }
    float range() const { return _maximumValue - _minimumValue; }
    void setValue(float value) { _value = std::clamp(value, _minimumValue, _maximumValue); }
    void setNormalisedValue(float normalisedValue);
    void resetValue() { _value = _defaultValue; }
    const QString& name() const { return _name; }
    const QString& displayName() const { return _displayName; }

private:
    QString _name;
    QString _displayName;

    float _minimumValue = 0.0f;
    float _maximumValue = 1.0f;
    float _defaultValue = 0.0f;
    float _value = 0.0f;

    LayoutSettingScaleType _scaleType = LayoutSettingScaleType::Linear;
};

class LayoutSettings : public QObject
{
    Q_OBJECT

private:
    std::vector<LayoutSetting> _settings;

public:
    float value(const QString& name) const;
    float normalisedValue(const QString& name) const;
    void setValue(const QString& name, float value);
    void setNormalisedValue(const QString& name, float normalisedValue);
    void resetValue(const QString& name);

    const LayoutSetting* setting(const QString& name) const;
    LayoutSetting* setting(const QString& name);

    std::vector<LayoutSetting>& vector() { return _settings; }

    template<typename... Args>
    void registerSetting(Args&&... args)
    {
        _settings.emplace_back(args...);
    }

signals:
    void settingChanged();
};

#endif // LAYOUTSETTINGS_H
