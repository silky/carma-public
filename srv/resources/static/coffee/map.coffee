# TODO Use city in reverse geocoding routines!

# Default marker icon size
this.iconSize = new OpenLayers.Size(50, 50)

# Default map zoom level
this.zoomLevel = 16

# Low zoom level (partner map overview)
this.beyondTheClouds = 10


# Trailing slash included
this.nominatimHost = "http://nominatim.openstreetmap.org/"
#this.nominatimHost = "http://192.168.10.2/"


this.nominatimRevQuery = (lon, lat) ->
  return this.nominatimHost +
    "reverse.php?format=json&accept-language=ru-RU,ru&lon=#{lon}&lat=#{lat}"


this.nominatimQuery = (addr) ->
  fixed_addr = addr.replace(/Москва/g, "Московская область")
  return this.nominatimHost +
    "search?format=json&accept-language=ru-RU,ru&q=#{fixed_addr}"


this.wsgProj = new OpenLayers.Projection("EPSG:4326")

this.osmProj = new OpenLayers.Projection("EPSG:900913")


this.carIcon = "/s/img/car-icon.png"

this.towIcon = "/s/img/tow-icon.png"

this.partnerIcon = "/s/img/partner-icon.png"

this.dealerIcon = "/s/img/dealer-icon.png"


# Build readable address from reverse Nominatim JSON response
this.buildReverseAddress = (res) ->
  if (res.error)
    return null

  addr = (res.address.road || res.address.pedestrian)

  if (_.isUndefined(res.address.house_number))
    return addr
  else
    return addr +  ", " + res.address.house_number


# Erase existing marker layer and install a new one of the same name
this.reinstallMarkers = (osmap, layerName) ->
  layers = osmap.getLayersByName(layerName)
  if (!_.isEmpty(layers))
    osmap.removeLayer(layers[0])
  new_layer = new OpenLayers.Layer.Markers(layerName)
  osmap.addLayer(new_layer)

  return new_layer

# Setup OpenLayers map
#
# - parentView: parent view this map belongs to. This is used to set
#               partner data in the parent VM when clicking partner
#               blips.
#
# Supported meta annotations for a map field:
#
# - targetAddr: if set, map will be clickable, enabled for reverse
#               geocoding and clicking the map will write address to
#               this field of model. If the annotation has the form of
#               `view_name/field_name`, then the field `field_name` in
#               `view_name` view will be used instead of parent view.
#
# - targetCoords: read initial position & blip from this field of
#                 model; write geocoding results here (only if it's
#                 enabled with `targetAddr` meta!). Metas of form
#                 `case-view/field` are treated as in `targetAddr`.
#
# - moreCoords: this meta is a list of field names (possibly prefixed
#               with view names as in `targetAddr`), where every field
#               stores coordinates. Static blips for every field will
#               be placed on the map.
#
# - targetPartner: if set, map will show partner blips from table set
#                  in `partnerTable` annotation on the same model. The
#                  table must be present in the same view. Clicking a
#                  blip will write partner information to fields of
#                  the model as set in metas:
#
#                  partner id → targetPartnerId
#                  partner name → targetPartner
#                  partner addres → targetPartnerAddr
#                  partner coords → targetPartnerCoords
#
this.initOSM = (el, parentView) ->
  return if $(el).hasClass("olMap")

  fieldName = $(el).attr("name")
  view = $(elementView($(el)))
  modelName = elementModel($(el))

  osmap = new OpenLayers.Map(el.id)
  osmap.addLayer(new OpenLayers.Layer.OSM())

  # Default location
  osmap.setCenter(new OpenLayers.LonLat(37.617874,55.757549)
                  .transform(wsgProj, osmProj),
                  zoomLevel)


  coord_field = modelField(modelName, fieldName).meta["targetCoords"]
  addr_field = modelField(modelName, fieldName).meta["targetAddr"]

  ## Bind the map to geocode address & coordinates

  # Place a blip and recenter if coordinates are already known
  if coord_field?
    chunks = coord_field.split('/')
    if chunks.length > 1
      coord_view_name = chunks[0]
      coord_field_name = chunks[1]
    else
      coord_view_name = parentView
      coord_field_name = chunks[0]

    coords = global.viewsWare[coord_view_name].knockVM[coord_field_name]()
    if coords?
      coords = lonlatFromShortString(coords)
      osmap.setCenter(coords.transform(wsgProj, osmProj), zoomLevel)
      carBlip(osmap, coords)

  # Setup handler to update address and coordinates if the map is
  # clickable
  if addr_field?
    chunks = addr_field.split('/')
    if chunks.length > 1
      addr_view_name = chunks[0]
      addr_field_name = chunks[1]
    else
      addr_view_name = parentView
      addr_field_name = chunks[0]

    osmap.events.register("click", osmap, (e) ->
      coords = osmap.getLonLatFromViewPortPx(e.xy)
               .transform(osmProj, wsgProj)

      if coord_field?
        # coord_view_name and coord_field are already known as per
        # coord_field? branch in geocoding setup
        global.viewsWare[coord_view_name]
        .knockVM[coord_field_name](coords.toShortString())

      $.getJSON(nominatimRevQuery(coords.lon, coords.lat),
      (res) ->
        addr = buildReverseAddress(res)

        global.viewsWare[addr_view_name].knockVM[addr_field_name](addr)

        carBlip(osmap, osmap.getLonLatFromViewPortPx(e.xy))
      )
    )

  ## Static coordinate blips
  more_coord_field = modelField(modelName, fieldName).meta["moreCoords"]

  ## Bind map to partner list

  partner_field = modelField(modelName, fieldName).meta["targetPartner"]

  if partner_field?
    partner_id_field = modelField(modelName, fieldName).meta["targetPartnerId"]
    partner_addr_field = modelField(modelName, fieldName).meta["targetPartnerAddr"]
    partner_coords_field = modelField(modelName, fieldName).meta["targetPartnerCoords"]

    table_field = modelField(modelName, fieldName).meta["partnerTable"]
    table = view.find("table##{table_field}")

    # Redraw partner blips on map when dragging or zooming
    osmap.events.register("moveend", osmap, (e) ->
      # Calculate new bounding box
      bounds = osmap.getExtent()
      pts = bounds.toArray()
      a = new OpenLayers.LonLat(pts[0], pts[1])
      b = new OpenLayers.LonLat(pts[2], pts[3])
      a.transform(osmProj, wsgProj)
      b.transform(osmProj, wsgProj)
      $.getJSON("/geo/partners/#{a.lon},#{a.lat}/#{b.lon},#{b.lat}/", (pres) ->
        # Use cache from table beneath a map for partner metadata
        partnerBlips(
          osmap, pres, table.data("cache"),
          parentView,
          partner_id_field, partner_field, partner_addr_field, partner_coords_field)
      )
    )
    # This is a workaround to make sure table cache is loaded prior to
    # partner markers rendering.
    _.delay(
      () ->
       osmap.setCenter(osmap.getCenter(), beyondTheClouds, false, true)
      500)

  $(el).data("osmap", osmap)


# Move the car crash blip on the map
this.carBlip = (osmap, coords) ->
  ico = new OpenLayers.Icon(carIcon, iconSize)
  markers = reinstallMarkers(osmap, "Car")
  markers.addMarker(
    new OpenLayers.Marker(coords, ico))


# Render list of partner markers on the map
#
# Arguments:
#
# - osmap: map to render on
#
# - partners: a list of [id, lon, lat] triples
#
# - tableCache: a hash of all partners, where key is id and value is
#               an object with fields "name", "addrDeFacto", "phone1",
#               "workingTime", "isMobile"
#
# - parentView: parentView for contractor
#
# - partnerField: clicking a button in marker popup will set this
#                 value in given VM to partner name
#
# - partnerAddrField: same as partnerField, but for partner address
# - partnerCoordsField: ... but for partner coordinates
this.partnerBlips = (osmap, partners, tableCache,
                     parentView,
                     partnerIdField, partnerField,
                     partnerAddrField, partnerCoordsField) ->
  markers = do (osmap) -> reinstallMarkers(osmap, "Partners")
  tpl = $("#partner-popup-template").html()

  for blip in partners
    do (blip) ->
      # Skip partners not in table
      return if not tableCache[blip[0]]

      partner = tableCache[blip[0]]

      coords = new OpenLayers.LonLat(blip[1], blip[2])

      # Readable coords in WSG
      string_coords = coords.toShortString()
      # Coords to use for map blip
      coords = coords.transform(wsgProj, osmProj)

      if partner.isMobile
        mrk = new OpenLayers.Marker(
          coords, new OpenLayers.Icon(towIcon, iconSize))
      else
        if (partner.isDealer == "1")
          mrk = new OpenLayers.Marker(
            coords, new OpenLayers.Icon(dealerIcon, iconSize))
        else
          mrk = new OpenLayers.Marker(
            coords, new OpenLayers.Icon(partnerIcon, iconSize))

      # Show partner info from table cache when clicking marker
      mrk.events.register("click", mrk, (e) ->

        # Let popup know where to put new partner data
        extra_ctx =
          numid: blip[0]
          parentView: parentView
          partnerField: partnerField
          partnerIdField: partnerIdField
          partnerAddrField: partnerAddrField
          partnerCoordsField: partnerCoordsField
          coords: string_coords
        ctx =_.extend(partner, extra_ctx)

        popup = new OpenLayers.Popup.FramedCloud(
          partner.id, mrk.lonlat,
          new OpenLayers.Size(200, 200),
          Mustache.render(tpl, ctx),
          null, true)

        osmap.addPopup(popup))
      markers.addMarker(mrk)


# Splice partner data into specified fields of a reference
#
# TODO We have to store all data in the associated HTML because
# partner table is in a different view and thus is inaccessible.
this.pickPartnerBlip = (referenceView,
                        partnerId, partnerName, partnerAddr, partnerCoords,
                        partnerIdField, partnerField, partnerAddrField, partnerCoordsField) ->
  vm = findReferenceVM(referenceView)
  vm[partnerIdField](partnerId)
  vm[partnerField](partnerName)
  vm[partnerAddrField](partnerAddr)
  vm[partnerCoordsField](partnerCoords)


# Read "32.54, 56.21" (the way coordinates are stored in model fields)
# into LonLat object
this.lonlatFromShortString = (coords) ->
  parts = coords.split(", ")
  return new OpenLayers.LonLat(parts[0], parts[1])


# Forward geocoding picker (address -> coordinates)
#
# For field with this picker type, following metas are recognized:
#
# - targetMap: name of map field to write geocoding results into
#              (recenter & set new blip on map)
#
# - targetCoords: name of field to write geocoding results into
#                 (coordinates in "lon, lat" format). If this meta is
#                 set, map will be recenter upon map setup using value
#                 stored in the referenced field.
#
# - cityField: used with field value for geocoder query
#
# TODO: Currently geoPicker fills fields of the `case` model. View for
# this model is hardcoded.
#
# Arguments are picker field name and picker element.
this.geoPicker = (fieldName, el) ->
  addr = $(el).parents('.input-append')
              .children("input[name=#{fieldName}]")
              .val()

  view = $(elementView($(el)))
  modelName = elementModel($(el))

  coord_field = modelField(modelName, fieldName).meta['targetCoords']
  map_field = modelField(modelName, fieldName).meta['targetMap']
  city_field = modelField(modelName, fieldName).meta['cityField']

  # TODO Drop hardcoded name of the «real» parent view (case-form)
  if city_field?
    addr = addr + ", " + global.viewsWare['case-form'].knockVM[city_field]()

  $.getJSON(nominatimQuery(addr), (res) ->
    if res.length > 0
      lonlat = new OpenLayers.LonLat(res[0].lon, res[0].lat)

      if coord_field?
        global.viewsWare['case-form'].knockVM[coord_field](lonlat.toShortString())

      if map_field?
        osmap = view.find("[name=#{map_field}]").data("osmap")
        osmap.setCenter(
              lonlat.transform(wsgProj, osmProj),
              zoomLevel)
        carBlip(osmap, osmap.getCenter()))


# Reverse geocoding picker (coordinates -> address)
#
# Recognized field metas:
#
# - targetMap
#
# - targetAddr
this.reverseGeoPicker = (fieldName, el) ->
  coords =
    lonlatFromShortString(
      $(el).parents('.input-append')
           .children("input[name=#{fieldName}]")
           .val())
  view = $(elementView($(el)))
  modelName = elementModel($(el))

  osmCoords = coords.clone().transform(wsgProj, osmProj)

  addr_field = modelField(modelName, fieldName).meta['targetAddr']
  map_field = modelField(modelName, fieldName).meta['targetMap']

  if map_field?
    osmap = view.find("[name=#{map_field}]").data("osmap")
    osmap.setCenter(osmCoords, zoomLevel)
    carBlip(osmap, osmap.getCenter())

  if addr_field?
    $.getJSON(nominatimRevQuery + "lon=#{coords.lon}&lat=#{coords.lat}",
      (res) ->
        addr = buildReverseAddress(res)

        global.viewsWare['case-form'].knockVM[addr_field](addr)
    )
