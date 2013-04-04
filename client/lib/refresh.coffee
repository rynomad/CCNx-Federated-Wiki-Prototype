util = require('./util.coffee')
pageHandler = require('./pageHandler.coffee')
plugin = require('./plugin.coffee')
state = require('./state.coffee')
neighborhood = require('./neighborhood.coffee')
addToJournal = require('./addToJournal.coffee')
wiki = require('./wiki.coffee')

plugin.get 'favicon', (favicon) ->
  favicon.create()

server = location.host.split(':')[0]
twinNdn = new NDN({host: server})

handleDragging = (evt, ui) ->
  itemElement = ui.item

  item = wiki.getItem(itemElement)
  thisPageElement = $(this).parents('.page:first')
  sourcePageElement = itemElement.data('pageElement')
  sourceSite = sourcePageElement.data('site')

  destinationPageElement = itemElement.parents('.page:first')
  equals = (a, b) -> a and b and a.get(0) == b.get(0)

  moveWithinPage = not sourcePageElement or equals(sourcePageElement, destinationPageElement)
  moveFromPage = not moveWithinPage and equals(thisPageElement, sourcePageElement)
  moveToPage = not moveWithinPage and equals(thisPageElement, destinationPageElement)

  if moveFromPage
    if sourcePageElement.hasClass('ghost') or
      sourcePageElement.attr('id') == destinationPageElement.attr('id')
        # stem the damage, better ideas here:
        # http://stackoverflow.com/questions/3916089/jquery-ui-sortables-connect-lists-copy-items
        return

  action = if moveWithinPage
    order = $(this).children().map((_, value) -> $(value).attr('data-id')).get()
    {type: 'move', order: order}
  else if moveFromPage
    wiki.log 'drag from', sourcePageElement.find('h1').text()
    {type: 'remove'}
  else if moveToPage
    itemElement.data 'pageElement', thisPageElement
    beforeElement = itemElement.prev('.item')
    before = wiki.getItem(beforeElement)
    {type: 'add', item: item, after: before?.id}
  action.id = item.id
  pageHandler.put thisPageElement, action

initDragging = ($page) ->
  $story = $page.find('.story')
  $story.sortable(connectWith: '.page .story').on("sortupdate", handleDragging)


initAddButton = ($page) ->
  $page.find(".add-factory").live "click", (evt) ->
    return if $page.hasClass 'ghost'
    evt.preventDefault()
    createFactory($page)

createFactory = ($page) ->
  item =
    type: "factory"
    id: util.randomBytes(8)
  itemElement = $("<div />", class: "item factory").data('item',item).attr('data-id', item.id)
  itemElement.data 'pageElement', $page
  $page.find(".story").append(itemElement)
  plugin.do itemElement, item
  beforeElement = itemElement.prev('.item')
  before = wiki.getItem(beforeElement)
  pageHandler.put $page, {item: item, id: item.id, type: "add", after: before?.id}

buildPageHeader = ({title,tooltip,header_href,favicon_src,favicon_id})->
  """<h1 title="#{tooltip}"><a href="#{header_href}"><img src="#{favicon_src}" height="32px" class="favicon"></a> #{title}</h1>"""

emitHeader = ($header, $page, page) ->
  site = $page.data('site')
  isRemotePage = site? and site != 'local' and site != 'origin' and site != 'view'
  header = ''

  viewHere = if wiki.asSlug(page.title) is 'welcome-visitors' then ""
  else "/view/#{wiki.asSlug(page.title)}"
  pageHeader = if isRemotePage
    buildPageHeader
      tooltip: site
      header_href: "//#{site}/view/welcome-visitors#{viewHere}"
      favicon_src: "#{page.publisher.favicon}"
      title: page.title
  else
    buildPageHeader
      tooltip: location.host
      header_href: "/view/welcome-visitors#{viewHere}"
      favicon_src: "#{page.publisher.favicon}"
      title: page.title

  $header.append( pageHeader )
  
  unless isRemotePage
    $('#favicon').attr('href', page.publisher.favicon)

  if $page.attr('id').match /_rev/
    rev = page.journal.length-1
    date = page.journal[rev].date
    $page.addClass('ghost').data('rev',rev)
    $header.append $ """
      <h2 class="revision">
        <span>
          #{if date? then util.formatDate(date) else "Revision #{rev}"}
        </span>
      </h2>
    """

emitTwins = wiki.emitTwins = ($page, twinNdn) ->
  page = $page.data 'data'
  site = $page.data('site') or window.location.host
  site = window.location.host if site in ['view', 'origin']
  slug = wiki.asSlug page.title
  server = location.host.split(':')[0]
  indexName = '/sfw/' + slug
  
  
  name = new Name(indexName)
  interest = new Interest(name)
  i = 0
  template = {}
  exclusions = []
  
  NeighborNetDB = sdb.req(NeighborNetDBschema, (nndb) ->
    NeighborNetDB.tr(nndb, ['pageTwinContentObjects'], 'readwrite').store('pageTwinContentObjects').cursor((content, cursor) ->
      console.log cursor
      if cursor? && (cursor.value.name == indexName)
        NeighborNetDB.tr(nndb, ['pageTwinContentObjects'], 'readwrite').store('pageTwinContentObjects').del(cursor.value.fullName)
      cursor.continue
    )
  )
  
  
  twinCallback = (json, version) ->
    if json != undefined
      twinPage = JSON.parse(json)
      console.log twinPage.title
      twinPage.version = version
      twinPage.remote = true
      bin = if version > viewing then bins.newer
      else if version < viewing then bins.older
      else bins.same
      if twinPage.publisher.favicon != page.publisher.favicon
        bin.push twinPage
      exclusions.push DataUtils.toNumbersFromString(twinPage.version)
      console.log('exclusions ',exclusions)

      template.exclude = new Exclude(exclusions)
      interest = new Interest(name)
      interest.exclude = template.exclude
      twinClosure = new ContentClosure(twinNdn, name, interest, twinCallback)
      console.log('bins  ',bins)
      
      console.log slug
      fullName = slug + '#' + twinPage.version
      signedInfo = new SignedInfo()
      indexName = '/sfw/' + slug
      pageItem = {name: indexName , fullName: fullName, signedInfo: signedInfo, page: twinPage}
      
      NeighborNetDB = sdb.req(NeighborNetDBschema, (nndb) ->
        NeighborNetDB.tr(nndb, ['pageTwinContentObjects'], 'readwrite').store('pageTwinContentObjects').add(pageItem)
        NeighborNetDB.tr(nndb, ['LocalID'], 'readonly').store('LocalID').index('name').get('anonymous',(ident) ->
          console.log 'ident, ', ident, twinPage.publisher
          twins = []

          for legend, bin of bins
            console.log legend, bin
            continue unless bin.length
            bin.sort (a,b) ->
              a.version < b.version
            flags = for twinPage, i in bin
              break if i >= 8
              if ident.favicon != twinPage.publisher.favicon
                context = 'twin'
              else
                context = 'view'
              """<img class="remote"
                src="#{twinPage.publisher.favicon}"
                data-slug="#{slug}"
                title="#{twinPage.title}"
                data-localContext="#{context}"
                data-ccnName="/sfw/#{slug}/#{twinPage.version}"
                data-page='#{json}'>
              """
            twins.push "#{flags.join '&nbsp;'} #{legend}"
          $page.find('.twins').html """<p>#{twins.join ", "}</p>""" if twins
          console.log('twins',twins)
          twinNdn.expressInterest(name, twinClosure, template)
          console.log 'twinPage.title', twinPage.title
        )
      
      
        
      )
    else
      i++
      console.log ('json == null for twins')


  twinClosure = new ContentClosure(twinNdn, name, interest, twinCallback)    

  

  if (viewing = page.version)?
    bins = {newer:[], same:[], older:[]}
    twinNdn.expressInterest(name, twinClosure, template)



renderPageIntoPageElement = (pageData,$page, siteFound) ->
  page = $.extend(util.emptyPage(), pageData)
  $page.data("data", page)
  slug = $page.attr('id')
  site = $page.data('site')

  context = ['view']
  context.push site if site?
  addContext = (site) -> context.push site if site? and not _.include context, site
  addContext action.site for action in page.journal.slice(0).reverse()

  wiki.resolutionContext = context

  [$twins, $header, $story, $journal, $footer] = ['twins', 'header', 'story', 'journal', 'footer'].map (className) ->
    $("<div />").addClass(className).appendTo($page)

  emitHeader $header, $page, page

  emitItem = (i) ->
    return if i >= page.story.length
    item = page.story[i]
    if item?.type and item?.id
      $item = $ """<div class="item #{item.type}" data-id="#{item.id}">"""
      $story.append $item
      plugin.do $item, item, -> emitItem i+1
    else
      $story.append $ """<div><p class="error">Can't make sense of story[#{i}]</p></div>"""
      emitItem i+1
  emitItem 0

  for action in page.journal
    addToJournal $journal, action

  emitTwins $page, twinNdn

  $journal.append """
    <div class="control-buttons">
      <a href="#" class="button fork-page" title="fork this page">#{util.symbols['fork']}</a>
      <a href="#" class="button add-factory" title="add paragraph">#{util.symbols['add']}</a>
    </div>
  """

  $footer.append """
    <a id="license" href="http://creativecommons.org/licenses/by-sa/3.0/">CC BY-SA 3.0</a> .
    <a class="show-page-source" href="/#{slug}.json?random=#{util.randomBytes(4)}" title="source">JSON</a> .
    <a>#{siteFound || 'origin'}</a>
  """


wiki.buildPage = (data,siteFound,$page) ->

  if siteFound == 'local'
    $page.addClass('local')
  else if siteFound
    siteFound = 'origin' if siteFound is window.location.host
    $page.addClass('remote') unless siteFound in ['view', 'origin']
    $page.data('site', siteFound)

  #TODO: avoid passing siteFound
  renderPageIntoPageElement( data, $page, siteFound )

  state.setUrl()

  initDragging $page
  initAddButton $page
  $page


module.exports = refresh = wiki.refresh = ->
  server = location.host.split(':')[0]
  if NDNs['getndn'] == undefined
    NDNs['getndn'] = new NDN({host: server})
  $page = $(this)
  console.log '$page',$page
  
  ### Register the /NeighborNet/ prefix with one closure that handles all page requests (may run into race conditions, explore queueing) and another that handles content requests ###
  NeighborNetDB = sdb.req(NeighborNetDBschema, (nndb) ->
    NeighborNetDB.tr(nndb, ['pageContentObjects'], 'readonly').store('pageContentObjects').cursor((content, cursor) ->
      ndnId = content.page.title
      if NDNs[ndnId] == undefined
        NDNs[ndnId] = new NDN({host: server})
      pubndn = NDNs[ndnId]
      console.log 'refresh cursor content', cursor.value.name
      prefix = new Name(cursor.value.name)
      si = new SignedInfo()
      si.freshnessSeconds = 5
      pubClosure = new AsyncPutClosure(pubndn, new Name(cursor.value.fullName), JSON.stringify(cursor.value.page), si)
      pubndn.registerPrefix(new Name(cursor.value.name), pubClosure)
      console.log 'published on pubndn', NDNs["#{ndnId}"]
      cursor.continue()
    )
  )
  ### ###
  
  

  [slug, rev] = $page.attr('id').split('_rev')
  pageInformation = {
    slug: slug
    rev: rev
    site: $page.data('site')
  }

  createGhostPage = ->
 
    title = $("""a[href="/#{slug}.html"]:last""").text() or slug
    page =
      'title': title
      'story': [
        'id': util.randomBytes 8
        'type': 'future'
        'text': 'We could not find this page.'
        'title': title
      ]
    heading =
      'type': 'paragraph'
      'id': util.randomBytes(8)
      'text': "We did find the page in your current neighborhood."
    hits = []
    for site, info of wiki.neighborhood
      if info.sitemap?
        result = _.find info.sitemap, (each) ->
          each.slug == slug
        if result?
          hits.push
            "type": "reference"
            "id": util.randomBytes(8)
            "site": site
            "slug": slug
            "title": result.title || slug
            "text": result.synopsis || ''
    if hits.length > 0
      page.story.push heading, hits...
      page.story[0].text = 'We could not find this page in the expected context.'
      
    NeighborNetDB = sdb.req(NeighborNetDBschema, (nndb) ->  
      NeighborNetDB.tr(nndb, ['LocalID'], 'readonly').store('LocalID').index('name').get('anonymous', (content) ->
        page.publisher = content
        wiki.buildPage( page, undefined, $page ).addClass('ghost')
      )
    )

    

  registerNeighbors = (data, site) ->
    if _.include ['local', 'origin', 'view', null, undefined], site
      neighborhood.registerNeighbor location.host
    else
      neighborhood.registerNeighbor site
    for item in (data.story || [])
      neighborhood.registerNeighbor item.site if item.site?
    for action in (data.journal || [])
      neighborhood.registerNeighbor action.site if action.site?

  whenGotten = (data,siteFound) ->
    if data.remote?
      wiki.buildPage( data, siteFound, $page ).addClass('remote').addClass('ghost')
    else
      wiki.buildPage(data, siteFound, $page)
    registerNeighbors( data, siteFound )

  pageHandler.get
    whenGotten: whenGotten
    whenNotGotten: createGhostPage
    pageInformation: pageInformation
    ndn: NDNs['getndn']
