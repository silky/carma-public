ko.sorted = ({kvms, filters, sorters}) ->
  active_sorter  = ko.observable()
  active_filters = ko.observableSet()

  result = ko.computed
    read: ->
      u = ko.utils.unwrapObservable kvms
      content = if _.isObject u then _.values u else u

      fltd = _.filter content,
                      (e) -> _.all active_filters(),
                                   (f) -> filters[f](e)

      if active_sorter()?
        if _.isFunction active_sorter()
          fltd = _.sortBy fltd, active_sorter()
        else if active_sorter().reverse
          fltd = (_.sortBy fltd, active_sorter().fn).reverse()

      return fltd

    deferEvaluation: true

  result.extend({rateLimit: {timeout: 200, method: "notifyWhenChangesStop"}})
  result.sorters = sorters
  result.filters = filters
  result.active_sorter  = active_sorter
  result.active_filters = active_filters

  result.add_sorters = (name, sorter) ->
    if _.isObject name
      _.extend sorters, name
    else
      sorters['name'] = sorter
    active_sorter(null)

  result.add_filters = (name, filter) ->
    if _.isObject name
      _.extend filter, name
    else
      filters[name] = filters
    active_filters.truncate()

  result.change_filters = (filter, del) ->
    active_filters(filter, del)

  result.set_sorter = (name, ord) ->
    if sorters[name][ord]?
      active_sorter(sorters[name][ord])
    else
      throw new Error "Unknown sorter: #{name}"

  result.clean = ->
    kvms.removeAll?()
    result.dispose()


  return result
