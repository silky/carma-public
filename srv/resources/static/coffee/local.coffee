#/ Everything local to the customer resides here

localScreens = ->
  "case":
    "template": "case-screen-template"
    "views":
      "case-form":
        constructor: setupCaseMain
  "search":
    "template": "search-screen-template"
    "views":
      "tableView":
         constructor: setupSearchTable
  "back":
    "template": "back-screen-template"
    "views":
      "back-form":
        constructor: setupBackOffice
        destructor:  removeBackOffice
  "vin":
    "template": "vin-screen-template"
    "views":
      "vin-form":
        constructor: setupVinForm
  "call":
    "template": "call-screen-template"
    "views":
      "call-form":
        constructor: setupCallForm
  "partner":
    "template": "partner-screen-template"
    "views":
      "partner-form":
        constructor: setupPartnersForm
  "reports":
    "template": "reports-screen-template"
    "views":
      "reports":
        constructor: setupReports

# Setup routing
localRouter = Backbone.Router.extend
  # Must _not_ end with trailing slashes
  routes:
    "case/:id"    : "loadCase"
    "case"        : "newCase"
    "search"      : "search"
    "vin"         : "vin"
    "back"        : "back"
    "call/:id"    : "loadCall"
    "call"        : "call"
    "reports"     : "reports"
    "partner"     : "newPartner"
    "partner/:id" : "loadPartner"

  loadCase    : (id) -> renderScreen("case", {"id": id})
  newCase     :      -> renderScreen("case", {"id": null})
  search      :      -> renderScreen("search")
  back        :      -> renderScreen("back")
  vin         :      -> renderScreen("vin")
  newPartner  :      -> renderScreen("partner", {"id": null})
  loadPartner : (id) -> renderScreen("partner", {"id": id})
  loadCall    : (id) -> renderScreen("call", {"id": id})
  call        :      -> renderScreen("call")
  reports     :      -> renderScreen("reports")

hooks = ->
  model:
      "*"    : [stdElCb]
      "case" : [candiboberHook]
  observable:
      "*"    : [regexpKbHook, dictionaryKbHook, filesKbHook]
      "case" : [caseDescsKbHook, caseWeaterKbHook, caseEventsHistoryKbHook]

# here is entry point
$( ->
  $.getJSON "/cfg/dictionaries",              (dicts)  ->
    $.getJSON "/_whoami/",                    (user)   ->
      $.getJSON "/s/js/data/conditions.json", (checks) ->
        $.getJSON "/cfg/models",              (models) ->
          mainSetup(localScreens(), localRouter, dicts, hooks(), user, models)
          global.checks = checks
          global.keys = {}
          global.keys.arrows = {left: 37, up: 38, right: 39, down: 40 }
          if window.location.hash == ""
            redirectToHomePage user)

this.redirectToHomePage = (user) ->
  mainRole = user.roles[0]
  if mainRole == "front"
    homePage = "call"
  else if mainRole == "back"
    homePage = "back"
  global.router.navigate(homePage, {trigger: true})


# Model method HTTP access point wrt redson location
this.modelMethod = (modelName, method) -> "/_/#{modelName}/#{method}"

dictionaryKbHook = (instance, knockVM) ->
  for n of instance.dictionaryFields
    fieldName = instance.dictionaryFields[n]
    dict      = instance.fieldHash[fieldName].meta.dictionaryName
    parent    = instance.fieldHash[fieldName].meta.dictionaryParent

    # Perform label-value transformation
    ((f, d) ->
      knockVM[f + "Local"] =
        kb.observable instance,
                      key: f
                      read: (k) ->
                        # Read label by real value
                        val = instance.get(k)
                        lab = global.dictValueCache[d][val]
                        return (lab || val)
                      write: (lab) ->
                        # Set real value by label
                        val = global.dictLabelCache[d][lab]
                        instance.set(f, val || lab)
                      ,
                      knockVM
      )(fieldName, dict)

regexpKbHook = (instance, knockVM) ->
  # Set observable with name <fieldName>Regexp for inverse of
  # result of regexp checking for every field with meta.regexp
  # annotation. Observable is True when regexp fails.
  for n of instance.regexpFields
    fieldName = instance.regexpFields[n]
    regexp = instance.fieldHash[fieldName].meta.regexp
    ((f, r) ->
      knockVM[fieldName + "Regexp"] =
            kb.observable instance,
                          key: f
                          read: (k) -> not r.test instance.get(k)
    )(fieldName, new RegExp(global.dictLabelCache["_regexps"][regexp]))

filesKbHook = (instance, knockVM) ->
  for n in instance.filesFields
    u = "/upload"
    d = "/s/fileupload"
    knockVM["#{n}UploadUrl"] = ko.computed
      read: ->
        return unless knockVM['id']
        path = "#{instance.model.name}/#{knockVM['id']()}/#{n}"
        "#{u}/#{path}"
    knockVM["#{n}Info"] = ko.computed
      read: ->
        return unless knockVM['id']
        path = "#{instance.model.name}/#{knockVM['id']()}/#{n}"
        fs = knockVM[n]()
        return [] unless fs
        for i in fs.split(',')
          do (i) ->
            url: "#{d}/#{path}/#{i.trim()}"
            name: i.trim()
            ctrl: "#{u}/#{path}/#{i.trim()}"

caseDescsKbHook = (instance, knockVM) ->
  knockVM['servicesDescs'] = ko.computed
    read: ->
      p = knockVM['program']()
      s = knockVM['servicesReference']()
      return [] unless p?
      _.chain(s).map((x) -> mkServicesDescs(p,x)).compact().value()
  knockVM['programDesc'] = ko.computed
    read: ->
      global.dictionaries['ProgramInfo'][knockVM['program']()]

caseWeaterKbHook = (instance, knockVM) ->
  knockVM['city'].subscribe (newVal) ->
    getWeather newVal, (weather) ->
      knockVM['temperature'](weather.tempC)

caseEventsHistoryKbHook = (instance, knockVM) ->
  knockVM['caller_phone1'].subscribe fillEventsHistory(knockVM)
  knockVM['actions'].subscribe fillEventsHistory(knockVM)

fillEventsHistory = (knockVM) -> ->
  t = $("#call-searchtable")
  st = t.dataTable()
  # return if table template is not yet rendered
  return unless $("#call-searchtable")[0]

  phone = knockVM['caller_phone1']()
  $.getJSON "/ix/callsByPhone/#{phone}", (calls) ->
    $.getJSON "/actionsFor/#{knockVM.id()}", (actions) ->
      st.fnClearTable()
      dict = global.dictValueCache

      for i of calls
        obj = calls[i]
        continue if obj.id.length > 10
        wazzup  = dict.Wazzup[obj.wazzup] || obj.wazzup || ''
        wazzupMsg  = "Что случилось: #{wazzup}"
        whocall = dict.CallerTypes[obj.callerType] || obj.callerType || ''
        whocallMsg = "Кто звонил: #{whocall}"
        callDate = if obj.callDate
            new Date(obj.callDate * 1000).toString("dd.MM.yyyy HH:mm")
          else
            ''
        callType = dict.CallerTypes[obj.callType] || obj.callType || ''
        callTypeMsg = "Тип звонка: #{callType}"
        row = [ callDate
              , obj.callTaker || ''
              , "звонок"
              , "#{wazzupMsg}, #{whocallMsg}, #{callTypeMsg}"
              , ''
              ]

        st.fnAddData(row)

      for r in actions
        duetime = if r.duetime
            new Date(r.duetime * 1000).toString("dd.MM.yyyy HH:mm")
          else
            ''
        result = dict.ActionResults[r.result] or ''
        name = dict.ActionNames[r.name] or ''
        row = [ duetime , r.assignedTo or '', name , r.comment or '', result ]
        st.fnAddData(row)

mkServicesDescs = (p, s) ->
  d = getServiceDesc(p ,s.modelName())
  t = s.modelTitle
  return { title: t, description: d }


this.getServiceDesc = (program, service) ->
  si  = global.dictionaries['ServiceInfo'][program]?[service]
  si ?= global.dictionaries['ServiceInfo']['default']?[service]

servicesDescsKbHook = (instance, knockVM) ->
  knockVM['servicesDescs'] = ko.computed
    read: ->
      p = knockVM['program']()
      s = knockVM['servicesReference']()
      programs = global.dictionaries.Programs.entries
      descs    = _.find(programs, (x) -> x.value == p)?.servicesDescs
      _.chain(s).map((x) -> descs?[x.modelName()]).compact().value()

# Clear dependant dictionary fields when parent is changed
dictionaryHook = (elName) ->
  instance = global.viewsWare[elName].bbInstance
  for n of instance.dictionaryFields
    fieldName = instance.dictionaryFields[n]
    parent    = instance.fieldHash[fieldName].meta.dictionaryParent

    if parent
      ((f) ->
        instance.bind("change:" + parent, (v) -> instance.set(f, ""))
      )(fieldName)

# jquery -> html(as string) conversion, with selected element
jQuery.fn.outerHTML = () -> jQuery("<div>").append(this.clone()).html()

# like _.has but for list
hasL = (lst, e) -> _.find(lst, (x) -> x == e)

# render checkboxes, trueChecks contains list with names,
# tha should be rendered as checked
renderChecks = (name, trueChecks) ->
  str = ""
  tpl = $("#check-list-item-template").html()
  if _.has(global.checks, name)
    for n of global.checks[name]["checks"]
      check = global.checks[name]["checks"][n]
      v = $(Mustache.render(tpl, check))
      if hasL(trueChecks, check.name)
        v.find('input:checkbox').attr('checked', true)
      str += v.outerHTML()
  return str


# try to render checkboxes, if check is found, then
# make request to candibober, and render checkboxes
# with 'renderChecks'
maybeRenderChecks = (e, instance) ->
  str = ""
  tpl = $("#check-list-item-template").html()
  name = instance.get(e.data('depends'))
  if _.has(global.checks, name)
    h = {}
    h[instance.name] =
      'model' : instance.name
      'id'    : instance.id

    $.ajax
      'dataType' : 'json'
      'type'     : 'POST'
      'url'      : '/candibober/check/' + name
      'data'     : JSON.stringify(h)
      'success'  : (data) -> e.html(renderChecks(name, data.true))
      'error'    : -> e.html(renderChecks(name, []))

# Update checks information when parent fields change
candiboberHook = (elName) ->
  instance = global.viewsWare[elName].bbInstance
  $el(elName).find("[data-provide=checklist]").each(
    (i) ->
      ((e) ->
        # Grab value of instance field specified in
        # data-depends and render associated checks
        instance.bind("change:" + e.data("depends"),
                      ((v) -> maybeRenderChecks(e, instance)))
       )($(this))
      )

# Standard element callback which will scroll model into view and
# focus on first field
stdElCb = (elName) ->
  e = $el(elName)
  # Scroll group to the top of the screen
  if e.hasClass("accordion-inner")
    e.parents(".accordion-group")[0].scrollIntoView()
  f = e.find(".focusable")[0]
  f and f.focus()

# Scroll case field into view and focus
this.focusField = (name) ->
  e = $("#case-form").find("[name=" + name + "]")[0]
  e.scrollIntoView()
  e.focus()

# Case view (renders to #left, #center and #right as well)
setupCaseMain = (viewName, args) ->

  # Default values
  # FIXME: User's name and creation date are better to be assigned by
  # the server.


  # Render list of required fields in right pane
  #
  # bbInstance is available only after model has been loaded. The
  # only way to execute custom code inside modelSetup is using
  # fetchCb option. By the time slotsee's are bound, fetchCb may
  # not have been called yet, thus we explicitly use applyBindings
  # here.
  fetchCb =  () ->
    instance = global.viewsWare[viewName].bbInstance
    ctx =
      "fields": _.map(instance.requiredFields, (f) -> instance.fieldHash[f])

    $("#empty-fields-placeholder").html(
      Mustache.render($("#empty-fields-template").html(), ctx))

    ko.applyBindings(global.viewsWare[viewName].knockVM,
                     el("empty-fields"))

  modelSetup("case") viewName, args,
                     permEl       : "case-permissions"
                     focusClass   : "focusable"
                     slotsee      : ["case-number"]
                     groupsForest : "center"
                     fetchCb      : fetchCb

  # Render service picker
  #
  # We use Bootstrap's glyphs if "icon" key is set in dictionary
  # entry.
  $("#service-picker-container").html(
    Mustache.render($("#service-picker-template").html(),
                    {dictionary: global.dictionaries["Services"]}))

  $("body").on("change.input", ".redirectOnChange", () ->
      setTimeout(( -> window.location.hash = "back"), 500))

  mkDataTable $('#call-searchtable')
  setupHotkeys()

# Hide all views on center pane and show view for first reference
# stored in <fieldName> of model loaded into <parentView> there
this.showComplex = (parentView, fieldName) ->
  depViewName = global.viewsWare[parentView].depViews[fieldName][0]
  view = $el(depViewName)

  return if view.is(':visible')
  $(".complex-field").hide()

  view.show -> initOSM e for e in view.find(".osMap")

this.hideComplex = ->
  $(".complex-field").hide()
  $(".default-complex-field").show()

# Top-level wrapper for storeService
this.addService = (name) ->
  addReference global.viewsWare["case-form"].knockVM,
               'services',
               { modelName : name },
               (k) ->
                  e = $('#' + k['view'])
                  e.parent().prev()[0].scrollIntoView()
                  e.find('input')[0].focus()

setupCallForm = (viewName, args) ->
  knockVM = modelSetup("call") viewName, args,
                     permEl     : "case-permissions"
                     focusClass : "focusable"
                     groupsForest : "center"
  knockVM['callTaker'](global.user.meta.realName)
  $('input[name="callDate"]').parents('.control-group').hide()
  $('input[name="callTaker"]').parents('.control-group').hide()
  searchTable = $("#call-searchtable")
  st = mkDataTable(searchTable)
  searchTable.on("click.datatable", "tr", ->
    id = this.children[0].innerText
    window.location.hash = "case/" + id
  )
  st.fnSort [[2, "desc"]]
  fields = "id,caller_name,callDate,caller_phone1,car_plateNum,car_vin,program,comment"
  $.getJSON("/all/case?orderby=callDate&limit=70&fields=#{fields}", (objs) ->
    st.fnClearTable()
    dict = global.dictValueCache
    for i of objs
      obj = objs[i]
      continue if obj.id.length > 10
      plateNum = if obj.car_plateNum?
              obj.car_plateNum.toUpperCase()
          else
              ""
      carVin = if obj.car_vin?
              obj.car_vin.toUpperCase()
          else
              ""
      row = [obj.id.split(":")[1]
            ,obj.caller_name || ''
            ,new Date(obj.callDate * 1000).toString("dd.MM.yyyy HH:mm:ss")
            ,obj.caller_phone1 || ''
            ,plateNum, carVin
            ,dict.Programs[obj.program] || obj.program || ''
            ,dict.Wazzup[obj.comment] || obj.comment || ''
            ]
      st.fnAddData(row)
  )
  setupHotkeys()


initOSM = (el) ->
  return if $(el).hasClass("olMap")

  osmap = new OpenLayers.Map(el.id)
  osmap.addLayer(new OpenLayers.Layer.OSM())
  osmap.setCenter(
    new OpenLayers.LonLat(37.617874,55.757549)
      .transform(
        new OpenLayers.Projection("EPSG:4326"),
        osmap.getProjectionObject()
      ),
    16 # Zoom level
  )
  $(el).data("osmap", osmap)


# Dispatch on some picker type
#
# Available picks:
#
# - vinFiller
this.doPick = (pickType, args, el) ->
  pickers =

    callPlease: (modelName) ->
      bb = global.viewsWare["case-form"].bbInstance
      phoneNumber = bb.get(modelName)
      $.post(
        "/avaya/call",
        number: phoneNumber,
        -> alert ("Calling " + phoneNumber))

    nominatimPicker: (fieldName, el) ->
      bb = global.viewsWare["case-form"].bbInstance
      addr = bb.get(fieldName)
      $.getJSON("/nominatim?addr=#{addr}", (res) ->
        if res.length > 0
          form = $(el).parents("form")
          osmap = form.find(".olMap")
          res1 = JSON.parse(res)
          osmap.data().osmap.setCenter(
            new OpenLayers.LonLat(res1[0].lon, res1[0].lat)
              .transform(
                new OpenLayers.Projection("EPSG:4326"),
                new OpenLayers.Projection("EPSG:900913")
              )
            , 16))
  pickers[pickType](args, el)

this.kdoPick = (pickType, args, k, e) ->
  doPick pickType, args, e.srcElement if e.ctrlKey and e.keyCode == k

setupVinForm = (viewName, args) ->
  $el(viewName).html($el("vin-form-template").html())
  global.viewsWare[viewName] = {}

  setInterval(getVinAlerts, 1000)

getVinAlerts = ->
  $.getJSON("/vin/state", null, (data) ->
    $("#vin-alert-container").html(
      Mustache.render($("#vin-alert-template").html(), data)))

mkDataTable = (t, opts) ->
  defaults =
    sScrollY  : "500px"
    bPaginate : false
    oLanguage :
      sSearch      : "Фильтр"
      sInfoEmpty   : ""
      sZeroRecords : "Ничего не найдено"
      sInfo        : "Показаны записи с _START_ по _END_ (всего _TOTAL_)"

  defaults = $.extend(defaults, opts) if opts?

  t.dataTable defaults

setupPartnersForm = (viewName, args) ->
  refs = [field: "services"
         ,forest: "partner-service-references"
         ]
  modelSetup("partner") viewName, args,
                        permEl: "partner-permissions"
                        focusClass: "focusable"
                        refs: refs

  setTimeout(->
    $.fn.dataTableExt.oStdClasses.sLength = "dataTables_length form-inline"
    $.fn.dataTableExt.oStdClasses.sFilter = "dataTables_filter form-inline"

    t = $("#partner-table");
    return if t.hasClass("dataTable")
    mkDataTable(t)

    t.on("click.datatable", "tr", ->
      id = this.children[0].innerText
      modelSetup("partner") viewName, {"id": id},
                            permEl: "partner-permissions"
                            focusClass: "focusable"
                            refs: refs
    )

    $.getJSON("/all/partner?fields=id,name,city,comment",
        (objs) ->
            dt = t.dataTable()
            dt.fnClearTable()
            rows = for obj in objs
                [obj.id.split(':')[1]
                ,obj.name || ''
                ,obj.city || ''
                ,obj.comment || ''
                ]
            dt.fnAddData(rows)
    ))

this.addNewServiceToPartner = (name) ->
  instance = global.viewsWare["partner-form"].bbInstance
  book = addReference instance,
                 field     : "services"
                 modelName : "partner_service"
                 forest    : "partner-service-references",
                 "center"
  service = global.dictionaries.Services


this.doVin = ->
  form     = $el("vin-import-form")[0]
  formData = new FormData(form)

  $.ajax(
    type        : "POST"
    url         : "/vin/upload"
    data        : formData
    contentType : false
    processData : false
    ).done((msg)-> alert( "Result: " + msg))

setupBackOffice = ->
  setTimeout((->
      tables = mkBoTable()
      global.boData = { started: new Date, r: {} }
      global.boData.iHandler =
        setInterval((-> $.getJSON("/ix/actionsForUser", setupBoTable)), 7000)
      $.getJSON("/ix/actionsForUser", setupBoTable)
      # non polling version for debug purposes
      # $.getJSON("/all/action", setupBoTable tables)
    ), 200)

removeBackOffice = ->
  h = global.boData.iHandler
  clearInterval h if h?

mkBoTable = ->
  groupTable = $("#back-group-table")
  gt = mkDataTable(groupTable)
  gt.fnSort [[2, "desc"]]
  groupTable.on("click.datatable", "tr", ->
    id = this.children[0].innerText.split('/');
    $.ajax
        type        : "PUT"
        url         : "/_/action/"+ id[1]
        contentType : "application/json"
        data        : '{"assignedTo":"'+global.user.login+'"}'
        processData : false
    window.location.hash = "case/" + id[0])
  userTable = $("#back-user-table")
  ut = mkDataTable(userTable)
  ut.fnSort [[2, "desc"]]
  userTable.on("click.datatable", "tr", ->
     id = this.children[0].innerText.split('/')
     window.location.hash = "case/" + id[0]
  )
  return [userTable, groupTable]

setupBoTable = (actions) ->
    userTable = $("#back-user-table")
    groupTable = $("#back-group-table")
    addActions(actions.user,  userTable.dataTable())
    addActions(actions.group, groupTable.dataTable())
    handleBoUpdate(groupTable)
    boNotify handleBoUpdate(userTable)



addActions = (actions, table) ->
  table.fnClearTable()
  for i of actions
    act = actions[i]
    continue if not act.caseId
    continue if not act.id
    continue if not act.duetime

    id = act.caseId.replace(/\D/g,'') + "/" + act.id.replace(/\D/g,'')
    duetime = new Date(act.duetime * 1000).toString("dd.MM.yyyy HH:mm:ss")
    row = [id
          ,act.priority || '3'
          ,duetime
          ,act.description || ''
          ,act.comment || '']
    table.fnAddData(row)


# mark expired entries and notify with alert of just expired rows
handleBoUpdate = (table) ->
  toNotify = []
  table.find('.odd, .even').each (i,e) ->
    row     = global.boData.r
    started = global.boData.started
    [id, _, d] = $(e).children().map (i,e)-> $(e).text()
    date = new Date.parse(d)
    now  = new Date
    $(e).attr('id', id)
    row[id] = { date: date } unless row[id]?
    $(e).children().css('background-color', '#ff6060') if now > date
    # last check to not notify about rows, that expired before
    # we open page
    if now > date and not row[id].checked and row[id].date > started
      toNotify.push e.id
      row[id].checked = true
  return toNotify

boNotify = (elems) ->
  alert "Измененные строки: #{elems.join(', ')}" unless _.isEmpty elems

this.removeVinAlert = (val) -> $.post "/vin/state", { id: val }

# FIXME: This could be a callback for main.js:saveInstance
this.successfulSave = ->
  $span = $(this).siblings(".save-result")
  setTimeout((->
    $span.text("Сохранено успешно")
    $span.show()
    $span.fadeOut(2000))
  , 500)

this.makeCase = () ->
  v = global.viewsWare['call-form'].knockVM
  args =
    caller_name:   v['callerName_name']()
    caller_phone1: v['callerName_phone1']()
    caller_phone2: v['callerName_phone2']()
    caller_phone3: v['callerName_phone3']()
    caller_phone4: v['callerName_phone4']()
    caller_email:  v['callerName_email']()
    comment:       v['wazzup']()
    callTaker: global.user.meta.realName
  buildNewModel 'case', args, {},
    (a, b, k) ->
      global.router.navigate("case/#{k.id()}", { trigger: true })

this.datetimeFieldHandler = (el) ->
  return if $(el).val()
  date = (new Date).toString("dd.MM.yyyy HH:mm")
  $(el).val(date)
  $(el).off 'blur.default.dt'
  $(el).on  'blur.default.dt', -> $(el).val("") if date == $(el).val()

this.uploadFile = (e) ->
        form = $(e).parent('form')
        data = form.data()
        url  = form.attr('action')
        fd   = new FormData(form[0])
        xhr  = new XMLHttpRequest()
        # xhr.upload.addEventListener("progress", uploadProgress, false)
        xhr.addEventListener("load", uploadComplete(data), false)
        xhr.addEventListener("error", uploadError, false)
        xhr.addEventListener("abort", uploadError, false)
        xhr.open("POST", url)
        xhr.send(fd)
        form.find('input:file').val("")

uploadComplete = (data) -> (e) ->
  {knockVM, acc} = data
  val = acc()()
  files = JSON.parse e.target.response
  if val
    result = _.union val.split(','), files
    acc() result.join(',')
  else
    acc()(files.join(','))
  knockVM.model().save()

uploadError = (e) ->
  console.log e
  alert "Загрузка завершилась неудачно"

this.deleteFile = (e) ->
  pdata = $(e).parents('ul').data()
  d     = $(e).data()

  deleteCb = (data) ->
    fs = pdata.acc()().split(',')
    fs1 = _.without(fs, data)
    pdata.acc()(fs1.join(','))
    # some strange magic happens here, bb model is changed
    # but not synced, I do not see any reason for that
    pdata.knockVM.model().save()

  return unless confirm "Вы уверены, что хотите удалить #{d.acc()}"

  $.ajax
    'type'     : 'DELETE'
    'url'      : "#{d.knockVM.ctrl}"
    'success'  : deleteCb
    'error'    : (xhr) ->
      if xhr.status == 404
        deleteCb(d.acc())
      else
        alert 'error'

this.setupHotkeys = ->
  $('#left').on('keydown.hotkeys', handleLeftHotkey)
  $('#center').on('keydown.hotkeys', handleCenterHotkey)

  # set focus hystory for hotkey navigation
  global.nav = {}
  $('#left'  ).on 'focus.nav', 'input', (e) ->
    global.nav.lastLeft = $(e.currentTarget)
  $('#center').on 'focus.nav', 'input', (e) ->
    global.nav.lastCenter = $(e.currentTarget)

  # set global hotkeys
  $(document).off 'keydown.closecomp'
  $(document).on  'keydown.closecomp', (e) ->
    # close center on C-m
    hideComplex() if e.ctrlKey and e.keyCode == 77 # m key

this.handleLeftHotkey = (e) ->
  arrs = global.keys.arrows
  if e.ctrlKey and e.keyCode == arrs.right
    c = global.nav.lastCenter
    if c and c.is(':visible')
      c.focus()
    else if f = $('#center fieldset:visible input')
      f.first().focus()

this.handleCenterHotkey = (e) ->
  arrs = global.keys.arrows
  l = global.nav.lastLeft
  if e.ctrlKey and e.keyCode == arrs.left and l
    checkAccordion(l)
    l.focus()

checkAccordion = (e) ->
  acc = e.parents('.accordion-body') #.hasClass('in')
  return if acc.hasClass('in')
  acc.collapse('show')

this.getWeather = (city, cb) ->
  url = "/#{city}"
  $.getJSON "/weather/#{city}", (data) -> cb(data)


this.setupReports = (viewName, args) ->
  $.getJSON "/all/report", (reports) ->
    for r in reports
      r.name = '' unless r.name?
      r.templates = '' unless r.templates?
      r.id = (r.id.split ':')[1]
    global.reports = reports
    ko.applyBindings(global.reports, el "layout" )

this.deleteReport = (e) ->
  return unless confirm "Вы уверены, что хотите удалить отчет?"
  objId = $(e).parents('tr').attr('id')
  $.ajax
    'type'     : 'DELETE'
    'url'      : "/_/report/#{objId}"
    'success'  : -> forgetScreen(); renderScreen("reports")
    'error'    : (xhr) -> console.log xhr; alert 'error'

this.checkReportUniq = (ev) ->
  ev.preventDefault()
  name = $('#add-report input[name=name]').val()
  tpl  = $('#add-report input[name=templates]').val()
  if _.find(global.reports, (e) -> e.name == name)
    alert "Отчет с таким именем уже существует."
  else if not name
    alert "Необходимо ввести название отчета!"
  else if not tpl
    alert "Необходимо добавить шаблон!"
  else
    $('#add-report').submit()
