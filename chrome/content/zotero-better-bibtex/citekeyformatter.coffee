class Zotero.BetterBibTeX.CitekeyFormatter
  constructor: (@patterns) ->
    if !Zotero.BetterBibTeX.CitekeyFormatter::unsafechars
      safechars = /[-:a-z0-9_!\$\*\+\.\/;\?\[\]]/g
      # not  "@',\#{}%
      unsafechars = '' + safechars
      unsafechars = unsafechars.substring(unsafechars.indexOf('/') + 1, unsafechars.lastIndexOf('/'))
      unsafechars = unsafechars.substring(0, 1) + '^' + unsafechars.substring(1, unsafechars.length)
      Zotero.BetterBibTeX.CitekeyFormatter::unsafechars = new RegExp(unsafechars, 'ig')

      Zotero.BetterBibTeX.CitekeyFormatter::punct = Zotero.Utilities.XRegExp('\\p{Pc}|\\p{Pd}|\\p{Pe}|\\p{Pf}|\\p{Pi}|\\p{Po}|\\p{Ps}', 'g')

      Zotero.BetterBibTeX.CitekeyFormatter::caseNotUpperTitle = Zotero.Utilities.XRegExp('[^\\p{Lu}\\p{Lt}]', 'g')
      Zotero.BetterBibTeX.CitekeyFormatter::caseNotUpper = Zotero.Utilities.XRegExp('[^\\p{Lu}]', 'g')

  format: (@item) ->
    @item = Zotero.BetterBibTeX.serialize(@item) if @item.getField

    for pattern in @patterns
      citekey = @clean(@concat(pattern))
      return citekey if citekey != ''
    return

  concat: (pattern) ->
    pattern = [pattern] unless Array.isArray(pattern)
    result = ''
    for part in pattern
      result += @reduce(part)
    return result

  reduce: (steps) ->
    steps = [steps] unless Array.isArray(steps)
    value = ''

    for step in steps
      if step.method
        value = @methods[step.method].apply(@, step.arguments)
      else
        value = @filters[step.filter].apply(@, [value].concat(step.arguments))
    return value

  clean: (str) ->
    Zotero.Utilities.removeDiacritics(str || '').replace(@unsafechars, '').trim()

  words: (str) ->
    return (@clean(word) for word in @stripHTML(str).split(/[\+\.,-\/#!$%\^&\*;:{}=\-\s`~()]+/) when word != '')

  # three-letter month abbreviations. I assume these are the same ones that the
  # docs say are defined in some appendix of the LaTeX book. (i don't have the
  # LaTeX book.)
  months: [ 'jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec' ]

  skipWords: [
    'a'
    'aboard'
    'about'
    'above'
    'across'
    'after'
    'against'
    'al'
    'along'
    'amid'
    'among'
    'an'
    'and'
    'anti'
    'around'
    'as'
    'at'
    'before'
    'behind'
    'below'
    'beneath'
    'beside'
    'besides'
    'between'
    'beyond'
    'but'
    'by'
    'd'
    'das'
    'de'
    'del'
    'der'
    'des'
    'despite'
    'die'
    'do'
    'down'
    'during'
    'ein'
    'eine'
    'einem'
    'einen'
    'einer'
    'eines'
    'el'
    'except'
    'for'
    'from'
    'in'
    'is'
    'inside'
    'into'
    'l'
    'la'
    'las'
    'le'
    'les'
    'like'
    'los'
    'near'
    'nor'
    'of'
    'off'
    'on'
    'onto'
    'or'
    'over'
    'past'
    'per'
    'plus'
    'round'
    'save'
    'since'
    'so'
    'some'
    'than'
    'the'
    'through'
    'to'
    'toward'
    'towards'
    'un'
    'una'
    'unas'
    'under'
    'underneath'
    'une'
    'unlike'
    'uno'
    'unos'
    'until'
    'up'
    'upon'
    'versus'
    'via'
    'while'
    'with'
    'within'
    'without'
    'yet'
    'zu'
    'zum'
  ]

  titleWords: (title, options = {}) ->
    return null unless title
    words = @words(title)

    words = (word.replace(/[^ -~]/g, '') for word in words) if options.asciiOnly
    words = (word for word in words when word != '')
    words = (word for word in words when @skipWords.indexOf(word.toLowerCase()) < 0) if options.skipWords
    return null if words.length == 0
    return words

  stripHTML: (str) ->
    return ('' + str).replace(/<\/?(sup|sub|i|b|p|span|br|break)\/?>/g, '').replace(/\s+/, ' ').trim()

  creators: (onlyEditors, withInitials) ->
    return [] unless @item.creators?.length
    kind = if onlyEditors then 'editors' else 'authors'
    kind += '+initials' if withInitials

    # because it gets set by the inheriting object!
    if typeof @creators[kind] == 'undefined'
      creators = {}
      primaryCreatorType = Zotero.Utilities.getCreatorsForType(@item.itemType)[0]
      for creator in @item.creators
        name = @stripHTML(creator.lastName)

        if name != ''
          if withInitials and creator.firstName
            initials = Zotero.Utilities.XRegExp.replace(creator.firstName, @caseNotUpperTitle, '', 'all')
            initials = Zotero.Utilities.removeDiacritics(initials)
            initials = Zotero.Utilities.XRegExp.replace(initials, @caseNotUpper, '', 'all')
            name += initials
        else
          name = @stripHTML(creator.firstName)

        continue if name == ''

        switch creator.creatorType
          when 'editor', 'seriesEditor'
            creators.editors ||= []
            creators.editors.push(name)

          when 'translator'
            creators.translators ||= []
            creators.translators.push(name)

          when primaryCreatorType
            creators.authors ||= []
            creators.authors.push(name)

          else
            creators.collaborators ||= []
            creators.collaborators.push(name)

      if onlyEditors
        @creators[kind] = creators.editors || []
      else
        @creators[kind] = creators.authors || creators.editors || creators.collaborators || creators.translators || []

    return @creators[kind]

  methods:
    literal: (text) -> return text

    id: -> return @item.itemID

    key: -> return @item.key

    auth: (onlyEditors, withInitials, n, m) ->
      authors = @creators(onlyEditors, withInitials)
      return ''  unless authors
      author = authors[m || 0]
      author = author.substring(0, n)  if author and n
      return author ? ''

    authorLast: (onlyEditors, withInitials) ->
      authors = @creators(onlyEditors, withInitials)
      return '' unless authors
      return authors[authors.length - 1] ? ''

    journal: ->
      return Zotero.BetterBibTeX.keymanager.journalAbbrev(@item)

    authors: (onlyEditors, withInitials, n) ->
      authors = @creators(onlyEditors, withInitials)
      return '' unless authors

      if n
        etal = (authors.length > n)
        authors = authors.slice(0, n)
        authors.push('EtAl') if etal

      authors = authors.join('')
      return authors

    authorsAlpha: (onlyEditors, withInitials) ->
      authors = @creators(onlyEditors, withInitials)
      return '' unless authors

      return switch authors.length
        when 1
          return authors[0].substring(0, 3)

        when 2, 3, 4
          return (author.substring(0, 1) for author in authors).join('')

        else
          return (author.substring(0, 1) for author in authors.slice(0, 3)).join('') + '+'

    authIni: (onlyEditors, withInitials, n) ->
      authors = @creators(onlyEditors, withInitials)
      return '' unless authors
      return (author.substring(0, n) for author in authors).join('.')

    authorIni: (onlyEditors, withInitials) ->
      authors = @creators(onlyEditors, withInitials)
      return ''  unless authors
      firstAuthor = authors.shift()
      return [firstAuthor.substring(0, 5)].concat(((name.substring(0, 1) for name in auth).join('.') for auth in authors)).join('.')

    'auth.auth.ea': (onlyEditors, withInitials) ->
      authors = @creators(onlyEditors, withInitials)
      return '' unless authors
      return authors.slice(0, 2).concat((if authors.length > 2 then ['ea'] else [])).join('.')

    'auth.etal': (onlyEditors, withInitials) ->
      authors = @creators(onlyEditors, withInitials)
      return '' unless authors

      return authors.join('.') if authors.length == 2
      return authors.slice(0, 1).concat((if authors.length > 1 then ['etal'] else [])).join('.')

    authshort: (onlyEditors, withInitials) ->
      authors = @creators(onlyEditors, withInitials)
      return '' unless authors

      switch authors.length
        when 0
          return ''

        when 1
          return authors[0]

        else
          return (author.substring(0, 1) for author in authors).join('.') + (if authors.length > 3 then '+' else '')

    firstpage: ->
      return '' unless @item.pages
      firstpage = ''
      @item.pages.replace(/^([0-9]+)/g, (match, fp) -> firstpage = fp)
      return firstpage

    keyword: (n) ->
      return '' if not @item.tags?[n]
      return @item.tags[n].tag

    lastpage: ->
      return '' unless @item.pages
      lastpage = ''
      @item.pages.replace(/([0-9]+)[^0-9]*$/g, (match, lp) -> lastpage = lp)
      return lastpage

    shorttitle: ->
      words = @titleWords(@item.title, { skipWords: true, asciiOnly: true})
      return ''  unless words
      words.slice(0, 3).join('')

    veryshorttitle: ->
      words = @titleWords(@item.title, { skipWords: true, asciiOnly: true})
      return '' unless words
      words.slice(0, 1).join('')

    shortyear: ->
      return '' unless @item.date
      date = Zotero.Date.strToDate(@item.date)
      return '' if typeof date.year == 'undefined'
      year = date.year % 100
      return "0#{year}"  if year < 10
      return '' + year

    year: ->
      return '' unless @item.date
      date = Zotero.Date.strToDate(@item.date)
      return @item.date if typeof date.year == 'undefined'
      return date.year

    month: ->
      return '' unless @item.date
      date = Zotero.Date.strToDate(@item.date)
      return '' if typeof date.year == 'undefined'
      return @months[date.month] ? ''

    title: ->
      return @titleWords(@item.title).join('')

  filters:
    ifempty: (value, dflt) ->
      return dflt if (value || '') == ''
      return value

    condense: (value, sep) ->
      sep = '' if typeof sep == 'undefined'
      return (value || '').replace(/\s/g, sep)

    abbr: (value) ->
      return (word.substring(0, 1) for word in (value || '').split(/\s+/)).join('')

    lower: (value) ->
      return (value || '').toLowerCase()

    upper: (value) ->
      return (value || '').toUpperCase()

    skipwords: (value) ->
      return (word for word in (value || '').split(/\s+/) when @skipWords.indexOf(word.toLowerCase()) < 0).join(' ').trim()

    select: (value, start, n) ->
      value = (value || '').split(/\s+/)
      end = value.length
      start = 1 if typeof start == 'undefined'
      start = parseInt(start) - 1
      end = start + parseInt(n) if typeof n != 'undefined'
      return value.slice(start, end).join(' ')

    ascii: (value) ->
      return (value || '').replace(/[^ -~]/g, '').split(/\s+/).join(' ').trim()

    fold: (value) ->
      return Zotero.Utilities.removeDiacritics(value || '').split(/\s+/).join(' ').trim()

    capitalize: (value) ->
      return (value || '').replace(/((^|\s)[a-z])/g, (m) -> m.toUpperCase())

    nopunct: (value) ->
      return Zotero.Utilities.XRegExp.replace(value || '', @punct, '', 'all')

