define [ "sync/metaq"
       , "sync/datamap"
       , "lib/messenger"
       ], (metaq, m, Messenger) ->
  class CrudQueue extends metaq
    constructor: (@kvm, @model, @options = {}) ->
      @url = "/_/#{@model.name}"
      @q       = {}
      @qbackup = {}
      @ftypes  = {}
      @persisted = @kvm.id()?
      @ftypes[f.name] = f.type for f in @model.fields
      @debounced_save = _.debounce((-> @save()), 1300)
      # lastfetch is keeping data from model previous state
      # last push, it is used to prevent immediate pushback of just fetched
      # fields
      @lastFetch = {}
      # when we have id, first fetch data and only after that subscribe
      # to changes, fetch will block, so we won't get fetched data to the save
      # queue
      @fetch() if @persisted and not @options?.dontFetch
      @subscribe()

      # use ws crud notifications
      if @options.useWS?
        if @persisted
          @ws = Messenger.subscribeKVM @kvm, @saveSuccessCb(_.identity)
        else
          @kvm.id.subscribe =>
            @ws = Messenger.subscribeKVM @kvm, @saveSuccessCb(_.identity)
      @

    subscribe: =>
      for f in @model.fields
        do (f) =>
          @kvm[f.name].subscribe (v) =>
            # Silently skip saving case.program=null.
            # This is used when searching contract with program field cleared.
            if @model.name == 'Case' and f.name == 'program' and not v
              return
            # Substitute Action.deferBy with computed value (see #2617).
            if @model.name == 'Action' and f.name == 'deferBy' and v == '$expectedSvcStart$+5m'
              sid = @kvm.serviceId()
              @kvm._parent.servicesReference().forEach((svc) =>
                if String(svc.id()) == String(sid)
                  fmt = 'DD.MM.YYYY HH:mm:ss'
                  newDate = moment(svc.times_expectedServiceStart(), fmt).add(5, 'minutes')
                  diffDur = moment.duration(newDate.diff(moment()))
                  v = Math.floor(diffDur.asHours()) + ':' + Math.abs(Math.floor(diffDur.asMinutes() % 60))
              )
            @q[f.name] = v
            @._save() unless @options?.manual_save

    fetch: =>
      $.bgetJSON "#{@url}/#{@kvm.id()}", (o) => @updateKvm m.s2cObj(o, @ftypes)

    _save: => @debounced_save()

    save: (cb, force = false) =>
      cb ?= _.identity # just to be sure we have something to call
      @saveKvm() unless @persisted
      delete @q[k] for k, v of @q when _.isEqual(@lastFetch[k], v)
      _.extend @lastFetch, $.extend(true, {}, (@q))
      method = if @persisted then "PUT" else "POST"
      url    = if @persisted then "#{@url}/#{@kvm.id()}" else @url
      return cb(@kvm, @model) if (_.isEmpty @q) and not force
      @qbackup = $.extend @qbackup, _.clone(@q)
      @q       = {}
      $.ajax
        type     : method
        url      : url
        dataType : 'json'
        contentType:'application/json; charset=utf-8'
        success  : @saveSuccessCb(cb)
        error    : @saveErrorCb
        data     : JSON.stringify m.c2sObj(@qbackup, @ftypes)
        beforeSend : @showSyncAnim

    showSyncAnim: =>
      _.each (_.keys @qbackup), (fname) =>
        @kvm["#{fname}Sync"] true

    hideSyncAnim: (jqXHR, status) =>
      if status
        $.notify "Данные не были сохранены. Попробуйте сохранить изменения
         ещё раз."
      else
        _.each (_.keys @qbackup), (fname) =>
          @kvm["#{fname}Sync"] false

    updateKvm: (obj) =>
      # Hope This won't break anything, erasing last fetch don't work
      # with ws notifications because we may receive 2 updates after
      # put first from crud second from ws queue and second update
      # will be immediately put back
      # @lastFetch = {}
      a = {}
      for k, v of obj
        a[k] = v
        @kvm[k]?(v)
      _.extend(@lastFetch, $.extend(true, {},  a))

    saveSuccessCb: (cb) => (json) =>
      @persisted ||= true
      @updateKvm(m.s2cObj(json, @ftypes))
      @hideSyncAnim()
      @qbackup = {}
      @kvm._saveSuccessCb?(@kvm, @model, json)
      cb(@kvm, @model)

    saveErrorCb: (x, status) =>
      @q = _.defaults(@q, @qbackup)
      @hideSyncAnim(x, status)
      console.error "CRUD sync: save of '#{@model.name}:#{@kvm.id()}' failed
 with '#{x.status}: #{x.statusText}'"

    # push all non empty kvm fields to the save queue, on first post for example
    saveKvm: =>
      for f in @model.fields when @kvm[f.name]()
        @q[f.name] = @kvm[f.name]()

    # sync new model, if it's not persisted(have no id), then just save it
    # in other case first save all that we have and then fetch data from backend
    sync: (cb) =>
      cb ?= _.identity
      unless @persisted
        @safeKvm
        return @save(cb)
      @save => @fetch(); cb(@kvm, @model)

    destructor: =>
      @ws.close

  CrudQueue: CrudQueue
