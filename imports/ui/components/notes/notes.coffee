{ Meteor } = require 'meteor/meteor'
{ Mongo } = require 'meteor/mongo'
{ ReactiveDict } = require 'meteor/reactive-dict'
{ Tracker } = require 'meteor/tracker'
{ $ } = require 'meteor/jquery'
{ FlowRouter } = require 'meteor/kadira:flow-router'
import SimpleSchema from 'simpl-schema'
{ TAPi18n } = require 'meteor/tap:i18n'
sanitizeHtml = require('sanitize-html')

{ Notes } = require '/imports/api/notes/notes.coffee'
{ Files } = require '/imports/api/files/files.coffee'

require './notes.jade'

import '/imports/ui/components/breadcrumbs/breadcrumbs.coffee'
import '/imports/ui/components/footer/footer.coffee'
import '/imports/ui/components/note/note.coffee'

import {
  updateTitle,
  makePublic,
  makePrivate,
  remove,
  insert,
  makeChild
} from '/imports/api/notes/methods.coffee'

import {
  upload
} from '/imports/api/files/methods.coffee'

{ displayError } = '../../lib/errors.js'

# URLs starting with http://, https://, or ftp://
Template.notes.urlPattern1 =
  /(\b(https?|ftp):\/\/[-A-Z0-9+&@#\/%?=~_|!:,.;]*[-A-Z0-9+&@#\/%=~_|])/gim

# URLs starting with "www." (without // before it
# or it'd re-link the ones done above).
Template.notes.urlPattern2 =
  /(^|[^\/])(www\.[\S]+(\b|$))/gim

Template.notes.onCreated ->
  if @data.note()
    @noteId = @data.note()._id
  else
    @noteId = null
  @state = new ReactiveDict
  @state.setDefault
    editing: false
    editingNote: false
    notesReady: false

  @favoriteNote = =>
    Meteor.call 'notes.favorite',
      noteId: @data.note()._id

  @deleteNote = =>
    note = @data.note()
    title = sanitizeHtml note.title,
      allowedTags: []
    message = "#{TAPi18n.__('notes.remove.confirm')} “"+title+"”?"
    if confirm(message)
      remove.call { noteId: note._id }, displayError

      FlowRouter.go 'App.home'
      return yes
    return no

Template.notes.helpers
  notes: ->
    NProgress.done()
    parentId = null
    if @note()
      parentId = @note()._id

    if FlowRouter.getParam 'searchTerm'
      Notes.search FlowRouter.getParam 'searchTerm'
    else if parentId
      Notes.find { parent: parentId }, sort: rank: 1
    else
      Notes.find { parent: null }, sort: rank: 1

  focusedNote: ->
    Notes.findOne Template.currentData().note()

  focusedNoteFiles: () ->
    if Template.currentData().note()
      Meteor.subscribe 'files.note', Template.currentData().note()._id
      Files.find { noteId: Template.currentData().note()._id }

  notesReady: ->
    Template.instance().subscriptionsReady()

  favorited: ->
    if Template.currentData().note().favorite
      'favorited'

  progress: ->
    setTimeout ->
      $('[data-toggle="tooltip"]').tooltip()
    , 100
    note = Notes.findOne(Template.currentData().note())
    if note
      note.progress

  progressClass: ->
    note = Notes.findOne(Template.currentData().note())
    Template.notes.getProgressClass note

  childNoteCount: ->
    if Template.currentData().note()
      Notes.find({parent:Template.currentData().note()._id}).count()
    else
      Notes.find({parent:null}).count()

Template.notes.events
  'click .js-cancel': (event, instance) ->
    instance.state.set 'editing', false

  'keydown input[type=text]': (event) ->
    # ESC
    if event.which == 27
      event.preventDefault()
      $(event.target).blur()

  'mousedown .js-cancel, click .js-cancel': (event, instance) ->
    event.preventDefault()
    instance.state.set 'editing', false

  'click .favorite': (event, instance) ->
    instance.favoriteNote()

  'click .uploadHeaderBtn': (event, instance) ->
    input = $(document.createElement('input'))
    input.attr("type", "file")
    input.trigger('click')
    input.change (submitEvent) ->
      console.log "Upload file"
      # console.log submitEvent.originalEvent.dataTransfer.files[0]
      console.log instance
      console.log submitEvent
      file = submitEvent.currentTarget.files[0]
      name = file.name
      Template.note.encodeImageFileAsURL (res) ->
        upload.call {
          noteId: instance.data.note()._id
          data: res
          name: name
        }, (err, res) ->
          console.log err, res
          $(event.currentTarget).closest('.noteContainer').removeClass 'dragging'
      , file

  'click .newNote': (event, instance) ->
    note = Notes.findOne Template.currentData().note()
    if note
      children = Notes.find { parent: note._id }
      parent = note._id
    else
      children = Notes.find { parent: null }
      parent = null
    console.log "Got note", note
    if children
      # Overkill, but, meh. It'll get sorted. Literally.
      rank = (children.count() * 40)
    else
      rank = 1
    console.log children.count()+" "+rank
    Meteor.call 'notes.insert', {
      title: ''
      rank: rank
      parent: parent
      shareKey: FlowRouter.getParam('shareKey')
    }

  'change .note-edit': (event, instance) ->
    target = event.target
    console.log event, instance
    if $(target).val() == 'edit'
      instance.editNote()
    else if $(target).val() == 'delete'
      instance.deleteNote()
    else if $(target).val() == 'favorite'
      instance.favoriteNote()
    else if $(target).val() == 'calendar'
      FlowRouter.go('/calendar/'+instance.data.note()._id)
    target.selectedIndex = 0

  'blur .title-wrapper': (event, instance) ->
    event.stopPropagation()
    title = Template.note.stripTags(event.target.innerHTML)
    if title != @title
      Meteor.call 'notes.updateTitle', {
        noteId: instance.data.note()._id
        title: title
        # FlowRouter.getParam 'shareKey',
      }, (err, res) ->
        $(event.target).html Template.notes.formatText title

Template.notes.formatText = (inputText, createLinks = true) ->
  if !inputText
    return
  if createLinks
    element = 'a'
  else
    element = 'span'

  replacedText = undefined
  replacePattern1 = undefined
  replacePattern2 = undefined
  replacePattern3 = undefined

  replacedText = inputText.replace(/&nbsp;/gim, ' ')
  replacedText = replacedText.replace Template.notes.urlPattern1,
    '<'+element+' href="$1" target="_blank" class="previewLink">$1</'+element+'>'
  replacedText = replacedText.replace Template.notes.urlPattern2,
    '<'+element+' href="http://$2" target="_blank" class="previewLink">$2</'+element+'>'

  # Change email addresses to mailto:: links.
  replacePattern3 = /(([a-zA-Z0-9\-\_\.])+@[a-zA-Z\_]+?(\.[a-zA-Z]{2,6})+)/gim
  replacedText = replacedText.replace replacePattern3,
    '<'+element+' href="mailto:$1">$1</'+element+'>'

  # Highlight Search Terms
  # searchTerm = new RegExp(FlowRouter.getParam('searchTerm'),"gi")
  # replacedText = replacedText.replace searchTerm,
  #   '<span class=\'searchResult\'>$&</span>'

  hashtagPattern = /(([#])([a-z\d-]+))/gim
  replacedText = replacedText.replace hashtagPattern,
    ' <'+element+' href="/search/%23$3" class="tagLink tag-$3">#$3</'+element+'>'

  namePattern = /(([@])([a-z\d-]+))/gim
  replacedText = replacedText.replace namePattern,
    ' <'+element+' href="/search/%40$3" class="atLink at-$3">@$3</'+element+'>'

  return replacedText

Template.notes.rendered = ->
  NProgress.done()
  $('.sortable').nestedSortable
    handle: '.handle'
    items: 'li.note-item'
    placeholder: 'placeholder'
    opacity: .6
    toleranceElement: '> div.noteContainer'
    stop: (event, ui) ->
      parent = $(event.toElement).closest('ol').closest('li').data('id')
      if !parent
        parent = FlowRouter.getParam 'noteId'
      upperSibling = $(event.toElement).closest('li').prev('li').data('id')
      makeChild.call
        noteId: $(event.toElement).closest('li').data('id')
        shareKey: FlowRouter.getParam('shareKey')
        upperSibling: upperSibling
        parent: parent

Template.notes.getProgressClass = (note) ->
  if (note.progress < 25)
    return 'danger'
  else if (note.progress > 74)
    return 'success'
  else
    return 'warning'
