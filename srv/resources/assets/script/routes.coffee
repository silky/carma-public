define ["render/screen"
        "finch"
        "search/routes"
        "kpi/routes"
       ], (r, Finch, Search, KPI) ->

  # wrapper which will abort execution when user on a brake
  addRoute = (url, fn) ->
    Finch.route url,
      setup: (bind) ->
        if _.contains(['rest', 'serviceBreak', 'na'], Finch.navigate())
          return Finch.abort()
        fn(bind)

  addRoute "back", (bind) ->
    require ["screens/backoffice"], (bo) ->
      bo.screen =
        name : "back"
        template: "back-screen-template"
        views:
          "back-form": bo
      r.renderScreen bo, bind

  addRoute "call/:id", (bind) ->
    require ["screens/call"], (call) ->
      call.screen =
        name : "Call"
        template: "call-screen-template"
        views:
          "call-view": call
      r.renderScreen call, bind

  addRoute "case/:id/:svc", (bind) ->
    require ["screens/case"], (kase) ->
      kase.screen =
        name : "case"
        template: "case-screen-template"
        views:
          "case-form": kase
      r.renderScreen kase, bind

  addRoute "dict/:dict/:id", (bind) ->
    require ["screens/dictionaries"], (dictionaries) ->
      dictionaries.screen =
        name : "dictionaries"
        template: "dictionaries-screen-template"
        views:
          "dictionaries-view": dictionaries
      r.renderScreen dictionaries, bind

  addRoute "partner/:id", (bind) ->
    require ["screens/partners"], (partner) ->
      partner.screen =
        name : "partner"
        template: "partner-screen-template"
        views:
          "Partner-view": partner
      r.renderScreen partner, bind

  addRoute "processingConfig", (bind) ->
    require ["screens/processingConfig"], (procCfg) ->
      procCfg.screen =
        name : "processingConfig"
        views:
          "config-view": procCfg
      r.renderScreen procCfg, bind

  addRoute "usermeta/:id", (bind) ->
    require ["screens/dictionaries"], (user) ->
      user.screen =
        name : "dictionaries"
        template: "dictionaries-screen-template"
        views:
          "dictionaries-view": user

      bind.dict = 45
      r.renderScreen user, bind

  addRoute "uploads", (bind) ->
    require ["screens/uploads"], (uploads) ->
      uploads.screen =
        name : "uploads"
        views:
          "uploads-view": uploads
      r.renderScreen uploads, bind

  addRoute "printSrv/:id", (bind) ->
    require ["screens/printService"], (print) ->
      print.screen =
        name : "printSrv"
        template: "printSrv-screen-template"
        views:
          "print-table": print
      r.renderScreen print, bind

  addRoute "rkc", (bind) ->
    require ["screens/rkc"], (rkc) ->
      rkc.screen =
        name : "rkc"
        template: "rkc-screen-template"
        views:
          "rkc-form": rkc
      r.renderScreen rkc, bind

  addRoute "supervisor", (bind) ->
    require ["screens/supervisor"], (supervisor) ->
      supervisor.screen =
        name : "supervisor"
        template: "supervisor-screen-template"
        views:
          "action-form": supervisor
      r.renderScreen supervisor, bind

  addRoute "vin", (bind) ->
    require ["screens/vin"], (vin) ->
      vin.screen =
        name : "vin"
        views:
          "vin-form": vin
      r.renderScreen vin, bind

  addRoute "contract/:sub/:id", (bind) ->
    require ["screens/contract"], (contract) ->
      contract.screen =
        name : "contract"
        template: "contract-screen-template"
        views:
          "contract-form": contract
      # Do not update screen if we stay in the same subprogram. This
      # prevents screen reloading when table rows are clicked on
      # portal screen.
      unless global.previousHash?.match "contract/#{bind.sub}/?"
        global.previousHash = window.location.hash
        r.renderScreen contract, bind

  addRoute "timeline", (bind) ->
    require ["screens/timeline"], (timeline) ->
      timeline.screen =
        name : "timeline"
        template: "timeline-screen-template"
        views:
          "timeline-view": timeline
      r.renderScreen timeline, bind

  Finch.route "rest", (bind) ->
    require ["screens/rest"], (scr) ->
      scr.screen =
        name: "rest"
        views:
          'rest-view': scr
      r.renderScreen scr, bind

  Finch.route "serviceBreak", (bind) ->
    require ["screens/serviceBreak"], (scr) ->
      scr.screen =
        name: "serviceBreak"
        views:
          'break-view': scr
      r.renderScreen scr, bind

  Finch.route "na", (bind) ->
    require ["screens/na"], (scr) ->
      scr.screen =
        name: "na"
        views:
          'na-view': scr
      r.renderScreen scr, bind

  addRoute "search", =>
  Search.attachTo("search")

  addRoute "kpi", =>
  KPI.attachTo("kpi")

  addRoute "diag/edit", =>
    r.renderScreen
      screen:
        name: "diag-edit"
        component: React.createElement CarmaComponents.DiagTree.Editor

  addRoute "diag/show/:caseId", (args) =>
    r.renderScreen
      screen:
        name: "diag-show"
        component: React.createElement CarmaComponents.DiagTree.Show, args

  Finch
