#/ Everything local to the customer resides here

localScreens = ->
  "case":
    "template": "case-screen-template"
    "views":
      "case-form": setupCaseMain
  "search":
    "template": "search-screen-template"
    "views":
      "tableView": setupSearchTable
  "back":
    "template": "back-screen-template"
    "views":
      "back-form": setupBackOffice
  "vin":
    "template": "vin-screen-template"
    "views":
      "vin-form": setupVinForm
  "call":
    "template": "call-screen-template"
    "views":
      "call-form": setupCallForm
  "partner":
    "template": "partner-screen-template"
    "views":
      "partner-form": setupPartnersForm

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

  loadCase    : (id) -> renderScreen("case", {"id": id})
  newCase     :      -> renderScreen("case", {"id": null})
  search      :      -> renderScreen("search")
  back        :      -> renderScreen("back")
  vin         :      -> renderScreen("vin")
  newPartner  :      -> renderScreen("partner", {"id": null})
  loadPartner : (id) -> renderScreen("partner", {"id": id})
  loadCall    : (id) -> renderScreen("call", {"id": id})
  call        :      -> renderScreen("call")

hooks = ->
  model:
      "*"    : [stdElCb, dictionaryHook]
      "case" : [candiboberHook]
  observable:
      "*"    : [regexpKbHook, dictionaryKbHook]
      "case" : [caseDescsKbHook]

# here is entry point
$( ->
  $.getJSON "/cfg/dictionaries",              (dicts)  ->
    $.getJSON "/_whoami/",                    (user)   ->
      $.getJSON "/s/js/data/conditions.json", (checks) ->
        $.getJSON "/cfg/models",              (models) ->
          mainSetup(localScreens(), localRouter, dicts, hooks(), user, models)
          global.checks = checks
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
  _.extend args,
           callTaker: global.user.meta.realName
           callDate : (new Date).toString ("dd.MM.yyyy HH:mm:ss")


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
                  e = $('#' + k['view']).find('input')[0]
                  e.scrollIntoView()
                  e.focus()

setupCallForm = (viewName, args) ->
  modelSetup("call") viewName, args,
                     permEl     : "case-permissions"
                     focusClass : "focusable"
                     groupsForest : "center"

initOSM = (el) ->
  return if el.className.contains("olMap")

  osmap = new OpenLayers.Map(el.id)
  osmap.addLayer(new OpenLayers.Layer.OSM())
  osmap.setCenter(
    new OpenLayers.LonLat(37.617874,55.757549)
      .transform( # from WGS 1984 to Spherical Mercator Projection
        new OpenLayers.Projection("EPSG:4326"),
        new OpenLayers.Projection("EPSG:900913")
      ),
    16 # Zoom level
  )

# Dispatch on some picker type
#
# Available picks:
#
# - vinFiller
doPick = (pickType, args) ->
  pickers =

    # Get car_vin field from case and try to fill some of its fields
    # with data stored under this VIN in database.
    vinFiller: ->
      # How vin fields map to case fields
      vinMap =
        "program"         : "program"
        "make"            : "car_make"
        "model"           : "car_model"
        "plateNumber"     : "car_plateNum"
        "mileageTO"       : "car_checkupMileage"
        "serviceInterval" : "car_checkPeriod"

      bb = global.viewsWare["case-form"].bbInstance
      vin = bb.get('car_vin')

      vinGroup = $("[name=car_vin]").closest(".control-group")

      $.ajax("/_/vin/" + vin,
             error: ->
               vinGroup.removeClass("success")
               vinGroup.addClass("error")
             success: (data) ->
               vinGroup.removeClass("error");
               vinGroup.addClass("success");
               for k of vinMap
                 bb.set(vinMap[k], data[k]) if !_.isUndefined(data[k]))

    callPlease: (modelName) ->
      bb = global.viewsWare["case-form"].bbInstance
      phoneNumber = bb.get(modelName)
      alert ("Calling " + phoneNumber)

  pickers[pickType](args)

setupVinForm = (viewName, args) ->
  $el(viewName).html($el("vin-form-template").html())
  global.viewsWare[viewName] = {}

  setInterval(getVinAlerts, 1000)

getVinAlerts = ->
  $.getJSON("/vin/state", null, (data) ->
    $("#vin-alert-container").html(
      Mustache.render($("#vin-alert-template").html(), data)))

mkDataTable = (t) ->
  t.dataTable
    sScrollY  : "500px"
    bPaginate : false
    oLanguage :
      sSearch      : "Фильтр"
      sInfoEmpty   : ""
      sZeroRecords : "Ничего не найдено"
      sInfo        : "Показаны записи с _START_ по _END_ (всего _TOTAL_)"



setupPartnersForm = (viewName, args) ->
  refs =
    [
      field: "services"
      forest: "partner-service-references"
    ]
  modelSetup("partner") viewName, args,
                        permEl: "partner-permissions"
                        focusClass: "focusable"
                        refs: refs
  $el(viewName).html($el("partner-form-template").html())

  global.viewsWare[viewName] = {}

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

     $.getJSON(modelMethod(
            "partner",
            "search?q=*&_limit=1000&_fields=id,name,city,comment"),
          ((rows) ->
            dt = t.dataTable()
            dt.fnClearTable()
            dt.fnAddData(rows))
          , 100)))

addNewServiceToPartner = (name) ->
  instance = global.viewsWare["partner-form"].bbInstance
  book = addReference instance,
                 field     : "services"
                 modelName : "partner_service"
                 forest    : "partner-service-references",
                 "center"
  service = global.dictionaries.Services


doVin = ->
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
      $.getJSON("/all/action", setupBoTable tables)
    ), 200)

mkBoTable = ->
  groupTable = $("#back-group-table")
  mkDataTable(groupTable)
  groupTable.on("click.datatable", "tr", ->
    id = this.children[0].innerText.split('/');
    $.ajax
        type        : "PUT"
        url         : "/_/action/"+ id[1]
        contentType : "application/json"
        data        : '{"assignedTo": "#{global.user.login}"}'
        processData : false
    window.location.hash = "case/" + id[0])
  userTable = $("#back-user-table")
  mkDataTable(userTable)
  userTable.on("click.datatable", "tr", ->
     id = this.children[0].innerText.split('/')
     window.location.hash = "case/" + id[0]
  )
  return [userTable, groupTable]


setupBoTable = (tables) ->
  [userTable, groupTable] = tables
  (objs) ->
    ut = userTable.dataTable()
    ut.fnClearTable()
    gt = groupTable.dataTable()
    gt.fnClearTable()
    mainRole = global.user.roles[0]

    for i of objs
      obj = objs[i]
      continue if obj.closed and obj.closed != "false"

      id = obj.caseId.replace(/\D/g,'') + "/" + obj.id
      duetime =
        if obj.duetime
          new Date(obj.duetime * 1000).toString("dd.MM.yyyy HH:mm:ss")
        else
          ''
      row = [id
            ,obj.priority || '3'
            ,duetime
            ,obj.description || ''
            ,obj.comment || '']

      obj.assignedTo ?= ""
      if obj.assignedTo == global.user.login
        ut.fnAddData(row)
      else if obj.assignedTo == "" and obj.targetGroup == mainRole
        gt.fnAddData(row)


removeVinAlert = (val) -> $.post "/vin/state", { id: val }

# FIXME: This could be a callback for main.js:saveInstance
successfulSave = ->
  $span = $(this).siblings(".save-result")
  setTimeout((->
    $span.text("Сохранено успешно")
    $span.show()
    $span.fadeOut(2000))
  , 500)

this.makeCase = () ->
  v = global.viewsWare['call-form'].knockVM
  args =
    caller_name: v['callerName_name']()
    caller_phone1: v['callerName_phone1']()
    caller_phone2: v['callerName_phone2']()
    caller_phone3: v['callerName_phone3']()
    caller_phone4: v['callerName_phone4']()
    caller_email: v['callerName_email']()
    comment: v['wazzup']()
  buildNewModel 'case', args, {},
    (a, b, k) ->
      global.router.navigate("case/#{k.id()}", { trigger: true })
