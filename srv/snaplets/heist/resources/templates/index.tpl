<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <title><addLocalName>CaRMa</addLocalName></title>
    <link rel="stylesheet" href="/s/3p/bootstrap/css/bootstrap.min.css" />
    <link rel="stylesheet" href="/s/css/datepicker.css" />

    <!-- Additional set of icons -->
    <link rel="stylesheet" href="/s/css/stolen-icons.css" />

    <link rel="stylesheet" href="/s/css/local.css" title="local" />

    <!-- Date Range Picker for Bootstrap -->
    <link rel="stylesheet" href="/s/css/daterangepicker-bs2.css" />

    <!-- DOM manipulation -->
    <script src="/s/3p/jquery.js" />

    <!-- Rich UI -->
    <script src="/s/3p/bootstrap/js/bootstrap.min.js" />
    <script src="/s/3p/bootstrap-datepicker.js" />
    <script src="/s/3p/bootstrap-tagautocomplete.js" />

    <!-- WYSIWYG -->
    <link rel="stylesheet" href="/s/3p/wysihtml5/bootstrap-wysihtml5.css" />
    <link rel="stylesheet" href="/s/3p/wysihtml5/wysiwyg-color.css" />
    <script src="/s/3p/wysihtml5/wysihtml5-0.3.0.min.js" />
    <script src="/s/3p/wysihtml5/bootstrap-wysihtml5.js" />
    <script src="/s/3p/wysihtml5/locales/bootstrap-wysihtml5.ru-RU.js" />

    <!-- Date Range Picker for Bootstrap -->
    <script src="/s/3p/moment/moment.min.js" />
    <script src="/s/3p/moment/ru.js" />
    <script src="/s/3p/daterangepicker.js" />

    <!-- Spinner -->
    <script src="/s/3p/spin.js" />
    <script src="/s/3p/jquery.spin.js" />

    <!-- Tabular display -->
    <link rel="stylesheet" href="/s/3p/datatables/css/jquery.dataTables.min.css" />
    <script src="/s/3p/datatables/js/jquery.dataTables.min.js" />

    <!-- Responsive UI javascript library -->
    <script src="/s/3p/knockout.js" />

    <!-- Utility library, Backbone dependency -->
    <script src="/s/3p/underscore.js" />

    <!-- Simple templates -->
    <script src="/s/3p/mustache.js" />

    <!-- OpenLayers library allows map rendering -->
    <script src="/s/3p/OpenLayers/OpenLayers.js" />

    <!-- 25Kb of date parsing and formatting -->
    <script src="/s/3p/date/core.js" />
    <script src="/s/3p/date/ru-RU.js" />
    <script src="/s/3p/date/extras.js" />
    <script src="/s/3p/date/parser.js" />
    <script src="/s/3p/date/sugarpak.js" />

    <!-- masked input for datetime fields -->
    <script src="/s/3p/jquery.maskedinput.js" />

    <script src="/s/3p/jquery.knob.min.js" />

    <script src="/s/3p/md5.min.js" />

    <script src="/s/3p/d3.min.js" />

    <script src="/s/3p/notify-combined.min.js" />

    <!-- global libs, that is not handled by require js -->
    <!-- typeahead menu -->
    <script src="/s/js/gen/globallibs/th-menu.js" />

    <script src="/s/js/gen/globallibs/observableSet.js" />
    <script src="/s/js/gen/globallibs/sorted.js" />

    <script src="/s/js/gen/globallibs/customKoHandlers.js" />
    <script src="/s/js/gen/globallibs/utils.js" />

    <script src="/s/js/gen/avaya.js" />

    <script src="/s/3p/require.js" />
    <script src="/s/js/gen/requireCfg.js" />
    <script src="/s/js/gen/local.js" />

  </head>
  <body>
    <!-- Navigation bar on top -->
    <div class="navbar navbar-fixed-top">
      <div class="navbar-inner">
          <ul class="nav pull-left" id="nav">
            <a class="brand" href="/">
              <addLocalName>CaRMa</addLocalName>
            </a>
            <li class="divider-vertical" />
            <li id="avaya-panel" class="dropdown" style="display: none">
              <form class="navbar-search pull-left">
                <input type="text" class="search-query" placeholder="Avaya">
                <button id="avaya-call" class="btn">
                  <i class="icon stolen-icon-phone"></i>
                </button>
              </form>
              <ul class="dropdown-menu">
                <li id="avaya-info" class="nav-header"></li>
                <li><a id="avaya-accept" href="#">Принять звонок</a></li>
              </ul>
            </li>
            <!-- ko template: { name: 'nav-li-template' }-->
            <!-- /ko -->
            <li>
              <a id="send-bug-report">
                <i class="icon icon-fire icon-white"></i>
              </a>
            </li>
          </ul>
          <ifLoggedIn>
            <ul class="nav pull-right" id="current-user">
              <li class="divider-vertical" />
              <li class="dropdown">
                <a href="#"
                   class="dropdown-toggle"
                   data-toggle="dropdown">
                  <i id="icon-user" class="icon-user icon-white" />&nbsp;
                  <span data-bind="text: safelyGet('login')" />
                  <b class="caret"></b>
                </a>
                <ul class="dropdown-menu">
                  <li>
                    <a href="/logout/">
                      <i class="icon-off icon-black" />&nbsp;Выход
                    </a>
                  </li>
                </ul>
              </li>
              <li class=dropdown>
                <a class="nav-block dropdown-toggle"
                   data-toggle="dropdown"
                   data-bind="text: safelyGet('currentStateLocal')"/>
                  <ul class="dropdown-menu">
                    <li class="current-user-menu">
                      Текущий статус:
                      <span data-bind="text: safelyGet('currentStateLocal')" />
                      <span data-bind="text: safelyGet('timeInCurrentState')" />
                      <div class="btn-group btn-group-xs"
                           id="user-state-btngroup">
                        <button type="button"
                                class="btn btn-default btn-small"
                                data-bind="css: {
                                           'btn-success': safelyGet('delayedState') == 'Rest'
                                           },
                                           disable: inSBreak(),
                                           click: function () {
                                           toggleDelayed('Rest')
                                           }">
                          Перерыв
                        </button>
                        <button type="button"
                              class="btn btn-default btn-small"
                                data-bind="css: {
                                           'btn-success': safelyGet('delayedState') == 'Dinner'
                                           },
                                           disable: inSBreak(),
                                           click: function () {
                                           toggleDelayed('Dinner')
                                           }">
                          Обед
                        </button>
                      </div>
                    </li>
                  </ul>
              </li>
            </ul>
          </ifLoggedIn>
      </div>
    </div>

    <!-- Main container for dynamically rendered layouts -->
    <div class="container-fluid" id="main-container">
      <div class="row-fluid" id="layout" />
    </div>

    <!-- SMS send form -->
    <div id="sms-send-modal" class="modal hide fade">
      <div class="modal-header">
        <button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>
        <h3>Отправка СМС</h3>
      </div>
      <div id="sms-send-form" class="modal-body"/>
      <div class="modal-footer">
        <button id="do-send-sms" class="btn btn-primary">Отправить</button>
      </div>
    </div>

    <!-- Form controls wrt user permissions -->
    <script type="text/template"
            id="permission-template">
        {{# readonly }}
        <button class="btn disabled" type="button">
          <i class="icon-ban-circle" /> Только для чтения</button>
        {{/ readonly }}
        {{^ readonly }}
        <button class="btn btn-success" type="button"
                onClick="saveInstance('{{ viewName }}');successfulSave.call(this);">
          <i class="icon-pencil icon-white" /> Сохранить</button>
          <span class="save-result"/>
        {{/ readonly }}
    </script>

    <!-- List of empty required fields on case screen -->
    <script type="text/template"
            id="empty-fields-template">
      <ul id="empty-fields">
      {{# fields }}
      <li onclick="focusField('{{name}}'); return false;"
          data-bind="css: { lierror: {{name}}Not }, visible: {{name}}Not">{{meta.label}}</li>
      {{/ fields }}
      </ul>
    </script>

    <!-- Render service picker with services dictionary -->
    <script type="text/template"
            id="service-picker-template">
      <ul class="nav nav-pills">
        <li class="drop{{drop}}">
          <button class="dropdown-toggle btn btn-action"
                  type="button"
                  data-toggle="dropdown">
            <i style="vertical-align:baseline" class="icon icon-plus" />
            Добавить услугу
          </button>
          <ul class="dropdown-menu">
            {{# dictionary.source }}
            <li>
              <a href="#"
                 onclick="addService('{{model}}'); return false;">
                <i class="icon-{{icon}} icon-black" />
                {{ label }}
              </a>
            </li>
            {{/ dictionary.source }}
          </ul>
        </li>
      </ul>
    </script>

    <script type="text/template"
            id="check-list-item-template">
      <li><input type="checkbox" /> {{ label }}</li>
    </script>

    <script type="text/template"
            id="add-ref-button-template">
      <button class="dropdown-toggle btn btn-action"
              onclick="{{ fn }}"
              type="button">
        <i class="icon icon-plus"></i>{{ label }}
      </button>
    </script>

    <!-- navigation menu templates -->
    <script type="text/html" id="nav-li-template">
      <!-- ko if: $data -->
        <!-- ko foreach: $data -->
          <!-- ko if: type == 'li' -->
            <li data-bind="attr: { id: name + '-screen-nav' }">
              <a data-bind="attr: { href: '#' + name}, text: label"/>
            </li>
          <!-- /ko -->
          <!-- ko if: type == 'link' -->
            <li data-bind="attr: { id: name + '-screen-nav-link' }">
              <a target="_blank" data-bind="attr: { href: name}, text: label"/>
            </li>
          <!-- /ko -->
          <!-- ko if: type == 'hack' -->
          <li data-bind="attr: { id: name + '-hack-link' }">
            <a onClick="switchHack(this);"
               data-bind="attr: { 'data-hack': name },
                          text: label"/>
          </li>
          <!-- /ko -->
          <!-- ko if: type == 'sms' -->
            <li>
              <a href="#sms-send-modal" data-toggle="modal">
                <i class="icon icon-envelope icon-white"></i>
              </a>
            </li>
          <!-- /ko -->
          <!-- ko if: type == 'dropdown' -->
            <li class="dropdown"
                data-bind="attr: { id: name + '-screen-nav-menu' }">
              <a href="#"
                 class="dropdown-toggle"
                 data-toggle="dropdown"
                 data-bind="html: label + '<b class=\'caret\'></b>'">
                <b class="caret"></b>
              </a>
              <ul class="dropdown-menu"
                  data-bind="template: { name: 'nav-li-template', data: screens }">
              </ul>
            </li>
          <!-- /ko -->
        <!-- /ko -->
      <!-- /ko -->
    </script>

    <script type="text/html" id="alert-template">
      <div class="alert">
        <button type="button" class="close" data-dismiss="alert">&times;</button>
        <strong>Внимание!</strong>
        {{message}}
      </div>
    </script>

    <!-- Case screen contract pane container -->
    <script type="text/html" id="contract-content-template">
      <div id="contract-content"
           data-bind="renderContract: '{{ title }}'">
      </div>
    </script>

    <script type="text/template"
            id="dictionary-many-table-template">
      <span>
        <div class="input-append">
          <input type="text"
             class="focusable
                    {{# meta.addClass }}{{meta.addClass}}{{/ meta.addClass }}
                    {{# readonly }}disabled{{/ readonly }}"
             {{# readonly }}readonly{{/ readonly }}
             autocomplete="off"
             name="{{ name }}"
             data-bind="value: {{ name }}Many,
                        valueUpdate: 'change',
                        disabled: {{ name }}Disabled,
                        pickerDisable: {{ name }}Disabled,
                        bindDict: '{{ name }}'"/>
          <span class="add-on" style="padding: 4px;">
            <i class="icon icon-chevron-down"></i>
          </span>
        </div>
        <!-- ko if: {{ name }}Locals().length -->
        <ul class="unstyled" data-bind="foreach: {{ name }}Locals">
          <li>
            <span data-bind="text: $data.label" />
            <a href=""
              class="close"
              style="float: none"
              data-bind="click: $parent.{{ name }}Remove">&times;</a>
          </li>
        </ul>
        <!-- /ko -->
      </span>
    </script>

    <script type="text/template"
            class="field-template"
            id="dictionary-table-template">
      <span>
        <div class="input-append">
          <input type="text"
                 class="focusable
                        {{# meta.addClass }}{{meta.addClass}}{{/ meta.addClass }}
                        {{# readonly }}disabled{{/ readonly }}"
                 {{# readonly }}readonly{{/ readonly }}
                 autocomplete="off"
                 name="{{ name }}"
                 data-bind="value: {{ name }}Local,
                            valueUpdate: 'change',
                            disabled: {{ name }}Disabled,
                            pickerDisable: {{ name }}Disabled,
                            bindDict: '{{ name }}'"
                 />
          <span class="add-on" style="padding: 4px;">
            <i class="icon icon-chevron-down" />
          </span>
        </div>
      </span>
    </script>


    <script type="text/template"
            class="field-template"
            id="text-table-template">
      <span data-bind="text: {{ name }}" />
    </script>

    <script type="text/template"
            class="field-template"
            id="onlyServiceBreak-table-template">
      <button type="button"
              class="btn btn-default btn-small"
              data-bind="css: { 'btn-success': inSBreak },
                         click: toggleServiceBreak
                         ">
        Служебный перерыв
      </button>
    </script>


    <script type="text/html" id="table-template">
      <div class="row-fluid">
        <div class="bs-docs-example-after">
          Пользователи
        </div>
        <div class="row-fluid">
          <p>
            <input type="text"
                   class="input-large search-query"
                   placeholder="Поиск"
                   data-bind="value: $data.typeahead">
          </p>
        </div>
        <div class="row-fluid">
          <table class="table table-hover table-bordered table-striped table-condensed">
            <thead>
              <tr>
                <!-- ko foreach: {data: $data.columns, as: 'column'} -->
                <th>
                  <button class="btn btn-link"
                          data-bind="{text: column.meta.label
                            , sort: column.name}">
                  </button>
                </th>
                <!-- /ko -->
              </tr>
            </thead>
            <tbody data-bind="foreach: {data: $data.rows, as: 'row'}">
              <tr data-bind="{renderRow: row
                    , event: {dblclick: $parent.rowClick(row)}}">
              </tr>
            </tbody>
          </table>
        </div>
        <div class="row-fluid">
          <div class="pager">
            <ul>
              <li style="cursor: pointer"
                  data-bind="css: {fade: !_.isNumber($data.prev())}">
                <button class="btn btn-link" data-bind="click: $data.prevPage">
                  &larr;
                </button>
              </li>
              <li>
                <a data-bind="text: $data.page()">
                </a>
              </li>
              <li style="cursor: pointer"
                  data-bind="css: {fade: !_.isNumber($data.next())}">
                <button class="btn btn-link" data-bind="click: $data.nextPage">
                  &rarr;
                </button>
              </li>
            </ul>
          </div>
        </div>
      </div>
    </script>
  </body>
</html>
