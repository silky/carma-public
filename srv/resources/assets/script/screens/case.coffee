define [ "utils"
       , "hotkeys"
       , "text!tpl/screens/case.html"
       , "text!tpl/fields/form.html"
       , "model/utils"
       , "model/main"
       , "components/contract"
       ],
  (utils, hotkeys, tpl, Flds, mu, main, Contract) ->
    utils.build_global_fn 'pickPartnerBlip', ['map']

    # Case view (renders to #left, #center and #right as well)
    setupCaseMain = (viewName, args) -> setupCaseModel viewName, args

    setupCaseModel = (viewName, args) ->
      kaze = {}
      # Bootstrap case data to load proper view for Case model
      # depending on the program
      if args.id
        $.bgetJSON "/_/Case/#{args.id}", (rsp) -> kaze = rsp

      kvm = main.modelSetup("Case") viewName, args,
                         permEl       : "case-permissions"
                         focusClass   : "focusable"
                         slotsee      : ["case-number",
                                         "case-program-description",
                                         "case-car-description"]
                         groupsForest : "center"
                         defaultGroup : "default-case"
                         modelArg     : "ctr:full:#{kaze.program}"

      ctx = {fields: (f for f in kvm._meta.model.fields when f.meta?.required)}
      setCommentsHandler()

      Contract.setup "contract", kvm

      $("#empty-fields-placeholder").html(
          Mustache.render($("#empty-fields-template").html(), ctx))

      ko.applyBindings(kvm, el("empty-fields"))


      # Render service picker
      #
      # We use Bootstrap's glyphs if "icon" key is set in dictionary
      # entry.
      $("#service-picker-container").html(
        Mustache.render(
          $("#service-picker-template").html(),
            {dictionary: utils.newComputedDict("iconizedServiceTypes")
            ,drop: 'up'
            }))

      # Redirect to backoffice when an action result changes
      $("body").on("change.input", ".redirectOnChange", () ->
          window.location.hash = "back"

      utils.mkDataTable $('#call-searchtable')
      hotkeys.setup()
      kvm = global.viewsWare[viewName].knockVM

      # True if any of of required fields are missing a value
      do (kvm) ->
        kvm['hasMissingRequireds'] = ko.computed ->
          nots = (i for i of kvm when /.*Not$/.test i)
          disable = _.any nots, (e) -> kvm[e]()
          disable

      renderActions()

      # make colored services and actions a little bit nicer
      $('.accordion-toggle:has(> .alert)').css 'padding', 0

    setCommentsHandler = ->
      $("#case-comments-b").on 'click', ->
        i = $("#case-comments-i")
        return if _.isEmpty i.val()
        comment =
          date: (new Date()).toString('dd.MM.yyyy HH:mm')
          user: global.user.login
          comment: i.val()
        k = global.viewsWare['case-form'].knockVM
        if _.isEmpty k['comments']()
          k['comments'] [comment]
        else
          k['comments'] k['comments']().concat comment
        i.val("")

    # Manually re-render a list of case actions
    renderActions = ->
      kvm = global.viewsWare["case-form"].knockVM
      caseId = kvm.id()

      refCounter = 0
      # TODO Add garbage collection
      mkSubname = -> "case-#{caseId}-actions-view-#{refCounter++}"
      subclass = "case-#{caseId}-actions-views"

      # Pick reference template
      cont = $("#case-actions-list")
      flds =  $('<div/>').append($(Flds))
      tpl = flds.find("#actions-reference-template").html()

      $.getJSON "/backoffice/caseActions/#{caseId}", (aids) ->
        for aid in aids
          # Generate reference container
          view = mkSubname()
          tpl = Mustache.render tpl, {refView: view, refClass: subclass}
          cont.append tpl
          avm = main.modelSetup("Action") view, {id: aid}, {}
          # Disable action results if any of required case fields is
          # not set
          kvm['hasMissingRequireds'].subscribe (dis) ->
            avm.resultDisabled?(dis)

    # Top-level wrapper for storeService
    addService = (name) ->
      kvm = global.viewsWare["case-form"].knockVM
      modelArg = "ctr:full:#{kvm.program()}"
      mu.addReference kvm,
        'services',
        {modelName : name, options:
         {newStyle: true, parentField: 'parentId', modelArg: modelArg, hooks: ['*']}},
        (k) ->
          e = $('#' + k['view'])
          e.parent().prev()[0]?.scrollIntoView()
          e.find('input')[0]?.focus()
          # make colored service a little bit nicer even if it is just created
          $('.accordion-toggle:has(> .alert)').css 'padding', 0
          e.parent().collapse 'show'

    utils.build_global_fn 'addService', ['screens/case']


    removeCaseMain = ->
      $("body").off "change.input"
      $('.navbar').css "-webkit-transform", ""


    { constructor       : setupCaseMain
    , destructor        : removeCaseMain
    , template          : tpl
    , addService        : addService
    }
