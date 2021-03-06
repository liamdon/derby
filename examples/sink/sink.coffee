{get, view, ready} = sink = require('derby').createApp module

## Routing ##

pages = [
  {name: 'home', text: 'Home', url: '/'}
  {name: 'liveCss', text: 'Live CSS', url: '/live-css'}
  {name: 'tableEditor', text: 'Table editor', url: '/table'}
  {name: 'submit', text: 'Submit form', url: '/submit'}
  {name: 'back', text: 'Back redirect', url: '/back'}
  {name: 'error', text: 'Error test', url: '/error'}
]
ctxFor = (name, ctx = {}) ->
  ctx[name + 'Visible'] = true
  last = pages.length - 1
  ctx.pages = for page, i in pages
    page = Object.create page
    if page.name is name
      page.current = true
      ctx.title = page.text
    page.last = i is last
    page
  return ctx

get '/', (page) ->
  page.render ctxFor 'home'

get '/live-css', (page, model) ->
  model.subscribe 'liveCss', ->
    model.setNull 'liveCss.styles', [
      {prop: 'color', value: '#c00', active: true}
      {prop: 'font-weight', value: 'bold', active: true}
      {prop: 'font-size', value: '18px', active: false}
    ]
    model.setNull 'liveCss.outputText', 'Edit this text...'
    page.render ctxFor 'liveCss'

get '/table', (page, model) ->
  model.subscribe 'rows', 'cols', ->
    unless model.get 'rows'
      model.set 'rows', [
        {cells: [{header: 'A'}, {}, {}, {}, {controls: true}]}
        {cells: [{header: 'B'}, {}, {}, {}, {controls: true}]}
      ]
      model.set 'cols', [
        {}
        {name: 1}
        {name: 2}
        {name: 3}
        {}
      ]
    page.render ctxFor 'tableEditor'

['get', 'post', 'put', 'del'].forEach (method) ->
  sink[method] '/submit', (page, model, {body, query}) ->
    args = JSON.stringify {method, body, query}, null, '  '
    page.render ctxFor 'submit', {args}

get '/error', ->
  throw new Error 500

get '/back', (page) ->
  page.redirect 'back'

## Views ##

view.make 'Title', '''Derby demo: {{title}}'''

view.make 'Head', '''
  <style>
    p{margin:0;padding:0}
    body{margin:10px}
    body,select{font:13px/normal arial,sans-serif}
    ins{text-decoration:none}
    .css{list-style:none;padding-left:1em;margin:0}
  </style>
  '''

view.make 'Body', '''
  <p>
  {{#pages}}
    {{#current}}
      <b>{{text}}</b>{{^last}} | {{/}}
    {{^}}
      <a href={{url}}>{{text}}</a>{{^last}} | {{/}}
    {{/}}
  {{/}}
  <hr>
  {{#homeVisible}}{{> home}}{{/}}
  {{#liveCssVisible}}{{> liveCss}}{{/}}
  {{#tableEditorVisible}}{{> tableEditor}}{{/}}
  {{#submitVisible}}{{> submit}}{{/}}
  '''

view.make 'home', '''
  <h1>Welcome!</h1>
  <p>This is a collection of random demos. Check 'em out! <a href=#jump>Test jump link</a>
  <p style=margin-top:1000px>
  <a name=jump>Jumped!</a>
  '''

# Option tags & contenteditable must only contain a variable with no additional text
# For validation, non-closed p elements must be wrapped in a div instead of the
# default ins. Closed p's are fine in an ins element.
view.make 'liveCss', '''
  <select multiple><optgroup label="CSS properties">
    ((#liveCss.styles))<option selected=((.active))>((.prop))((/))
  </select>
  <div>
    ((#liveCss.styles))
      <p><input type=checkbox checked=((.active))> 
      <input value=((.prop)) disabled=!((.active))> 
      <input value=((.value)) disabled=!((.active))> 
      <button x-bind=click:deleteStyle>Delete</button>
    ((/))
  </div>
  <button x-bind=click:addStyle>Add</button>
  <h3>Currently applied:</h3>
  <p>{
  <ul class=css>
    ((#liveCss.styles :style))
      <li x-displayed=((:style.active))>((> cssProperty))
    ((/))
  </ul>
  <p>}
  <h3>Output:</h3>
  <p style="((liveCss.styles :style > cssProperty))" contenteditable>
    (((liveCss.outputText)))
  </p>
  '''

view.make 'cssProperty', '''((#:style.active))((:style.prop)): ((:style.value));((/))'''

view.make 'tableEditor', '''
  <table>
    <thead>
      <tr>
        ((#cols))
          <th>((.name))
        ((/))
    <tbody>
      ((#rows))
        <tr>
          ((#.cells :cell))
              {{#:cell.header}}
                <th>((.))
              {{^}}
                {{#:cell.controls}}
                  <td><button x-bind=click:deleteRow>Delete</button>
                {{^}}
                  <th><input value=((:cell.text))>
                {{/}}
              {{/}}
          ((/))
      ((/))
    <tfoot>
      <tr>
        ((#cols))
          <th>
            ((#.name))
              <button x-bind=click:deleteCol>Delete</button>
            ((/))
        ((/))
  </table>
'''

view.make 'submit', '''
  <form action=submit method=post>
    <input type=hidden name=_method value=put>
    <p><label>Name: <input type=text name=user[name]></label>
    <p><label>Email: <input type=text name=user[email]></label>
    <p><input type=submit>
  </form>
  <h3>Arguments:</h3>
  <pre><code>{{args}}</code></pre>
  '''


## Controller functions ##

ready (model) ->
  exports.addStyle = ->
    model.push 'liveCss.styles', {}

  targetIndex = (e, levels = 1) ->
    item = e.target
    item = item.parentNode while levels--
    for child, i in item.parentNode.childNodes
      return i if child == item

  exports.deleteStyle = (e) ->
    model.remove 'liveCss.styles', targetIndex(e)

  exports.deleteRow = (e) ->
    model.remove 'rows', targetIndex(e, 2)

  exports.deleteCol = (e) ->
    i = targetIndex e
    row = model.get('rows').length
    while row--
      model.remove "rows.#{row}.cells", i
    return model.remove 'cols', i
