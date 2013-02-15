define ["model/main", "render/screen"], (main, render) ->
  # Find view for this element
  elementView = (elt) -> _.last($(elt).parents("[id*=view]"))

  # Save instance loaded in view
  saveInstance = (viewName) -> global.viewsWare[viewName].bbInstance.save()

  addReference: (knockVM, field, ref, cb) ->
    field = field + 'Reference' unless /Reference$/.test(field)
    thisId = knockVM.modelName() + ":" + knockVM.id()
    ref.args = _.extend({"parentId":thisId}, ref.args)
    main.buildNewModel ref.modelName, ref.args, ref.options or {},
      (mkBackboneModel, instance, refKVM) ->
        newVal = knockVM[field]().concat refKVM
        knockVM[field](newVal)
        cb(_.last knockVM[field]()) if _.isFunction(cb)

  removeReference: (knockVM, field, ref) ->
    field = field + 'Reference' unless /Reference$/.test(field)
    knockVM[field] _.without(knockVM[field](), ref)

  # Load existing model instance
  createInstance: (viewName, id) ->
    saveInstance(viewName)
    render.forgetView(viewName)
    global.activeScreen.views[viewName](viewName, {})

  # Load existing model instance
  restoreInstance: (viewName, id) ->
    render.forgetView(viewName)
    global.activeScreen.views[viewName](viewName, {"id": id})

  # Remove instance currently loaded in view from storage and render
  # that view from scratch (if possible)
  removeInstance: (viewName) ->
    global.viewsWare[viewName].knockVM.model().destroy()
    render.forgetView(viewName)
    setup = global.activeScreen.views[viewName]
    setup(viewName, {}) if not _.isNull(setup)

  elementView: elementView

  # Find out which model this element belongs to
  elementModel: (elt) ->
    elementView(elt).id.split("-")[0]

  # Get field object for named model and field
  modelField: (modelName, fieldName) ->
    _.find(
      global.models[modelName].fields,
      (f) -> return f.name == fieldName)
