#ifndef CONTAINER_H
#define CONTAINER_H

#include "pair_iterator.h"
#include "random.h"

#include <algorithm>
#include <vector>
#include <random>

#include <QtGlobal>

namespace u
{
    template<typename C, typename T> void removeByValue(C& container, const T& value)
    {
        container.erase(std::remove(container.begin(), container.end(), value), container.end());
    }

    template<typename C, typename T> int indexOf(C& container, const T& value)
    {
        auto it = std::find(container.begin(), container.end(), value);
        return it != container.end() ? std::distance(container.begin(), it) : -1;
    }

    template<typename C, typename T>
    auto contains(const C& container, const T& value, int)
    -> decltype(container.find(value), bool())
    {
        return container.find(value) != container.end();
    }

    template<typename C, typename T>
    auto contains(const C& container, const T& value, char)
    -> decltype(std::find(container.begin(), container.end(), value), bool())
    {
        return std::find(container.begin(), container.end(), value) != container.end();
    }

    template<typename C, typename T> bool contains(const C& container, const T& value)
    {
        return contains(container, value, 0);
    }

    template<typename C, typename T> bool containsAnyOf(const C& container, std::initializer_list<T>&& values)
    {
        return std::any_of(values.begin(), values.end(), [&](const auto& value)
        {
           return contains(container, value, 0);
        });
    }

    template<typename C, typename T> bool containsAllOf(const C& container, std::initializer_list<T>&& values)
    {
        return std::all_of(values.begin(), values.end(), [&](const auto& value)
        {
           return contains(container, value, 0);
        });
    }

    template<typename C, typename T> bool containsKey(const C& container, const T& key)
    {
        return contains(make_key_wrapper(container), key, 0);
    }

    template<typename C, typename T> bool containsValue(const C& container, const T& value)
    {
        return contains(make_value_wrapper(container), value, 0);
    }

    template<typename T,
             template<typename, typename...> class C1, typename... Args1,
             template<typename, typename...> class C2, typename... Args2>
    std::vector<T> setDifference(const C1<T, Args1...>& a, const C2<T, Args2...>& b)
    {
        std::vector<T> result;

        for(const auto& value : a)
        {
            if(!contains(b, value))
                result.emplace_back(value);
        }

        return result;
    }

    template<typename T,
             template<typename, typename...> class C1, typename... Args1,
             template<typename, typename...> class C2, typename... Args2>
    bool setsDiffer(const C1<T, Args1...>& a, const C2<T, Args2...>& b)
    {
        if(a.size() != b.size())
            return true;

        for(const auto& value : a)
        {
            if(!contains(b, value))
                return true;
        }

        return false;
    }

    template<typename T,
             template<typename, typename...> class C1, typename... Args1,
             template<typename, typename...> class C2, typename... Args2>
    bool setsEqual(const C1<T, Args1...>& a, const C2<T, Args2...>& b)
    {
        return !setsDiffer(a, b);
    }

    template<typename T,
             template<typename, typename...> class C1, typename... Args1,
             template<typename, typename...> class C2, typename... Args2>
    std::vector<T> setIntersection(const C1<T, Args1...>& a, const C2<T, Args2...>& b)
    {
        std::vector<T> result;

        for(const auto& value : a)
        {
            if(contains(b, value))
                result.emplace_back(value);
        }

        return result;
    }

    template<typename T, template<typename, typename...> typename C, typename... Args>
    std::vector<T> keysFor(const C<T, Args...>& container)
    {
        std::vector<T> keys;
        for(const auto& key : make_key_wrapper(container))
            keys.emplace_back(key);
        return keys;
    }

    template<typename T, template<typename, typename...> typename C, typename... Args>
    std::vector<T> valuesFor(const C<T, Args...>& container)
    {
        std::vector<T> values;
        for(const auto& value : make_value_wrapper(container))
            values.emplace_back(value);
        return values;
    }

    template<typename T, template<typename, typename...> typename C, typename... Args>
    C<T, Args...> randomSample(const C<T, Args...>& container, size_t numSamples)
    {
        if(numSamples > container.size())
            return container;

        auto sample = container;

        std::default_random_engine dre;

        for(size_t i = 0; i < numSamples; i++)
        {
            int high = static_cast<int>(sample.size() - i) - 1;
            std::uniform_int_distribution uid(0, high);
            std::swap(sample[i], sample[i + uid(dre)]);
        }

        sample.resize(numSamples);

        return sample;
    }

    template<typename T, template<typename, typename...> typename C, typename... Args>
    std::vector<T> vectorFrom(const C<T, Args...>& container)
    {
        std::vector<T> values;
        std::copy(container.begin(), container.end(), std::back_inserter(values));
        return values;
    }

    template<typename T> struct reversing_wrapper { T& container; };
    template<typename T> auto begin(reversing_wrapper<T> wrapper) { return std::rbegin(wrapper.container); }
    template<typename T> auto end(reversing_wrapper<T> wrapper) { return std::rend(wrapper.container); }

    template<typename T>
    reversing_wrapper<T> reverse(T&& container) { return {container}; }

    template<typename T, template<typename, typename...> typename C, typename... Args>
    std::vector<size_t> rankingOf(const C<T, Args...>& container)
    {
        std::vector<size_t> ranking(container.size());

        std::iota(std::begin(ranking), std::end(ranking), 0);
        std::sort(std::begin(ranking), std::end(ranking),
        [&container](size_t a, size_t b)
        {
            return container[a] < container[b];
        });

        // Give duplicates the same rank
        auto it = ranking.begin();
        while((it = std::adjacent_find(it, ranking.end(),
            [&](size_t a, size_t b)
            {
                return a != b && container[a] == container[b];
            })) != ranking.end())
        {
            *std::next(it) = *it;
        }

        return ranking;
    }

} // namespace u

#endif // CONTAINER_H
