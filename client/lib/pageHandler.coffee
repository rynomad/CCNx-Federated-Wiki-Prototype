util = require('./util.coffee')
state = require('./state.coffee')
revision = require('./revision.coffee')
addToJournal = require('./addToJournal.coffee')
plugin = require('./plugin.coffee')

module.exports = pageHandler = {}

pageFromTwinStorage = (slug, whenGotten)->
  NeighborNetDB = sdb.req(NeighborNetDBschema, (nndb) ->
    console.log 'testings'
    NeighborNetDB.tr(nndb, ['pageTwinContentObjects'], 'readonly').store('pageTwinContentObjects').index('fullName').get(slug, (content)  ->
      console.log content
      if content?
        page = content.page
        whenGotten(page, 'remote')        
    )
  )



recursiveGet = ({pageInformation, whenGotten, whenNotGotten, localContext, ndn}) ->
  {slug,rev,site} = pageInformation
  getCallback = (json, version) ->
    if json != undefined
      console.log('calling',json)
      page = JSON.parse(json)
      page.version = version
      whenGotten(page, site) 
      slug = wiki.asSlug(page.title)
      indexName = '/sfw/' + slug
      action = {type: 'fork'}
      publishToIndexedDB(page, indexName, action)
    else
      console.log ('json == null')
      whenNotGotten()
  
  name = new Name(slug)
  console.log 'localContext, ', localContext[0]
  
  if localContext[0] == 'twin'
    console.log 'console long name', name
    pageFromTwinStorage(slug, whenGotten)

  else
    name = new Name("/sfw/#{slug}")
    interest = new Interest(name)
    template = {}
    getClosure = new ContentClosure(ndn, name, interest, getCallback)

  
    NeighborNetDB = sdb.req(NeighborNetDBschema, (nndb) ->

      NeighborNetDB.tr(nndb, ['pageContentObjects'], 'readonly').store('pageContentObjects').index('name').get(('/sfw/' + slug), (content) ->
        console.log content
        if content?
          page = content.page
          console.log page
          whenGotten(page, site)
          ###
          repoNdn = ndn
          repoName = new Name(content.fullName + '/%C1.R.sw/%C1.N%00%11%01%01%01%01%11%10')
          repoName.addSegment(0)
          repoInterest = new Interest(repoName)
          console.log repoInterest
          repoClosure = new ContentClosure(repoNdn, repoName, repoInterest, (contentobj) -> 
            console.log contentobj
          )
          repoNdn.expressInterest(repoName, repoClosure)
          ###

        else if navigator.onLine == true
          ndn.expressInterest(name, getClosure, template)
        else
          whenNotGotten()
          console.log '_____________ # ndn ELSE', ndn
      )
    )
  

#  ndn.expressInterest(name, getClosure, template)


pageHandler.get = ({whenGotten,whenNotGotten,pageInformation,ndn}) ->

#  unless pageInformation.site
#    pageFromTwinStorage(pageInformation.slug, whenGotten)

  pageHandler.context = ['view'] unless pageHandler.context.length
  recursiveGet
    pageInformation: pageInformation
    whenGotten: whenGotten
    whenNotGotten: whenNotGotten
    localContext: _.clone(pageHandler.context)
    ndn: ndn


pageHandler.context = []

pushToLocal = (pageElement, pagePutInfo, action) ->
  page = pageFromLocalStorage pagePutInfo.slug
  page = {title: action.item.title} if action.type == 'create'
  page ||= pageElement.data("data")
  page.journal = [] unless page.journal?
  if (site=action['fork'])?
    page.journal = page.journal.concat({'type':'fork','site':site})
    delete action['fork']
  page.journal = page.journal.concat(action)
  page.story = $(pageElement).find(".item").map(-> $(@).data("item")).get()
  localStorage[pagePutInfo.slug] = JSON.stringify(page)
  addToJournal pageElement.find('.journal'), action


  
publishToIndexedDB = ( page, indexName, action) ->
  server = location.host.split(':')[0]
  #console.log NDNs[page.title]

  if NDNs[page.title] == undefined
    NDNs[page.title] = new NDN({host: server})
  
  ndn = NDNs[page.title]
  
  signedInfo = new SignedInfo()
  signedInfo.freshnessSeconds = 5
  timestamp = signedInfo.timestamp.msec
  #console.log(signedInfo.timestamp.msec)

  
  prefix = new Name(indexName)
  fullname = indexName + '/' + timestamp 
  name = new Name(fullname)
  ccnName = new Name(fullname)
  #console.log('name: ', name)


  #console.log(prefix)

  page.version = timestamp

  page.story = switch action.type
    when 'move'
      action.order.map (id) ->
        page.story.filter((para) ->
          id == para.id
        )[0] or throw('Ignoring move. Try reload.')

    when 'add'
      idx = page.story.map((para) -> para.id).indexOf(action.after) + 1
      page.story.splice(idx, 0, action.item)
      page.story

    when 'remove'
      page.story.filter (para) ->
        para?.id != action.id

    when 'edit'
      page.story.map (para) ->
        if para.id is action.id
          action.item
        else
          para

    when 'create', 'fork'
      page.story or []

    else
      log "Unfamiliar action:", action
      page.story

  putClosure = new AsyncPutClosure(ndn, name, JSON.stringify(page), signedInfo)
  publishClosure = new PublishClosure(ndn)
  i = 0
  #console.log page

  ### Rather than registering new prefixes per page, just package the page and the paragraphs into content objects and put into the proper indexedDB ###
 
  pageItem = {name: indexName , fullName: fullname, signedInfo: signedInfo, page: page}
  #console.log pageItem
  NeighborNetDB = sdb.req(NeighborNetDBschema, (nndb) ->  
    NeighborNetDB.tr(nndb, ['LocalID'], 'readonly').store('LocalID').index('name').get('anonymous', (content) ->
      pageItem.page.publisher = content
      pageItem.page.slug = pageItem.name
      pageItem.page.isLocal = true
     
      NeighborNetDB.tr(nndb, ['pageContentObjects'], 'readwrite').store('pageContentObjects').put(pageItem)
      
    )
  )
  for item in NDN.CSTable
    #console.log NDN.CSTable
    #console.log pageItem.name, item.name
    if pageItem.name == item.name
      item.closure.content = JSON.stringify(pageItem.page)
      item.closure.name = new Name(fullname)
      #console.log 'closure content replaced'
      contentPublished = true      

      break
  if contentPublished != true
    ndn.registerPrefix(prefix, putClosure)


    


pushToServer = (pageElement, pagePutInfo, action) ->
  #console.log('pageElement:',pageElement.attr('id'))
  #console.log('pagePutInfo:', pagePutInfo)
  #console.log('action:', action)
  page = pageElement.data('data')

  indexName = '/sfw/' + pagePutInfo.slug  
  publishToIndexedDB(page, indexName, action)
 


pageHandler.put = (pageElement, action) ->
  #console.log action
  checkedSite = () ->
    switch site = pageElement.data('site')
      when 'origin', 'local', 'view' then null
      when location.host then null
      else site

  # about the page we have
  pagePutInfo = {
    slug: pageElement.attr('id').split('_rev')[0]
    rev: pageElement.attr('id').split('_rev')[1]
    site: checkedSite()
    local: pageElement.hasClass('local')
  }
  forkFrom = pagePutInfo.site
  wiki.log 'pageHandler.put', action, pagePutInfo

  # detect when fork to local storage
  if wiki.useLocalStorage()
    if pagePutInfo.site?
      wiki.log 'remote => local'
    else if !pagePutInfo.local
      wiki.log 'origin => local'
      action.site = forkFrom = location.host
    # else if !pageFromLocalStorage(pagePutInfo.slug)
    #   wiki.log ''
    #   action.site = forkFrom = pagePutInfo.site
    #   wiki.log 'local storage first time', action, 'forkFrom', forkFrom

  # tweek action before saving
  action.date = (new Date()).getTime()
  delete action.site if action.site == 'origin'

  # update dom when forking
  if forkFrom
    # pull remote site closer to us
    pageElement.find('h1 img').attr('src', page.publisher.favicon)
    pageElement.find('h1 a').attr('href', '/')
    pageElement.data('site', null)
    pageElement.removeClass('remote')
    state.setUrl()
    if action.type != 'fork'
      # bundle implicit fork with next action
      action.fork = forkFrom
      addToJournal pageElement.find('.journal'),
        type: 'fork'
        site: forkFrom
        date: action.date

  # store as appropriate
  if wiki.useLocalStorage() or pagePutInfo.site == 'local'
    pushToLocal(pageElement, pagePutInfo, action)
    pageElement.addClass("local")
  else
    pushToServer(pageElement, pagePutInfo, action)

