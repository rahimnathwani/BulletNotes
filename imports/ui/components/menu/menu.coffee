{ Template } = require 'meteor/templating'
{ ReactiveDict } = require 'meteor/reactive-dict'
{ Notes } = require '/imports/api/notes/notes.coffee'

import filesize from 'filesize'

require './menu.jade'

Template.menu.onRendered ->
  setInterval ->
    notesPercentFull = Counter.get('notes.count.user') / Template.App_body.getTotalNotesAllowed() * 100
    if document.querySelector('#noteSpaceUsedBar')
      document.querySelector('#noteSpaceUsedBar').MaterialProgress.setProgress(notesPercentFull);

    if Meteor.user()
      filesPercentFull = Meteor.user().uploadedFilesSize / Template.App_body.getUploadBitsAllowed() * 100 
      if document.querySelector('#fileSpaceUsedBar')
        document.querySelector('#fileSpaceUsedBar').MaterialProgress.setProgress(filesPercentFull);

      # THis is hacky. Should be somewhere else.
      if Meteor.user().language
        T9n.setLanguage(Meteor.user().language)
        TAPi18n.setLanguage(Meteor.user().language)

      if Session.get 'referral'
        Meteor.call 'users.referral', {
          referral: Session.get 'referral' 
        }
        Session.set 'referral', null
  , 1000
  

Template.menu.helpers
  displayName: ->
    displayName = ''
    if Meteor.user().emails
      email = Meteor.user().emails[0].address
      displayName = email.substring(0, email.indexOf('@'))
    else
      displayName = Meteor.user().profile.name
    displayName

  totalNotesAllowed: ->
    Template.App_body.getTotalNotesAllowed()

  referralCount: ->
    Meteor.user().referralCount

  notes: ->
    Notes.find { favorite: true }, sort: favoritedAt: -1

  activeNoteClass: (note) ->
    active = ActiveRoute.name('Notes.show') and FlowRouter.getParam('_id') == note._id
    active and 'active'

  hideUndoButton: ->
    if tx.Transactions.find(
      user_id: Meteor.userId()
      $or: [
        { undone: null }
        { undone: $exists: false }
      ]
      expired: $exists: false).count() then true

  hideRedoButton: ->
    undoneRedoConditions = ->
      'var undoneRedoConditions'
      undoneRedoConditions =
        $exists: true
        $ne: null
      lastAction = tx.Transactions.findOne({
        user_id: Meteor.userId()
        $or: [
          { undone: null }
          { undone: $exists: false }
        ]
        expired: $exists: false
      }, sort: lastModified: -1)
      if lastAction
        undoneRedoConditions['$gt'] = lastAction.lastModified
      undoneRedoConditions

    if tx.Transactions.find(
      user_id: Meteor.userId()
      undone: undoneRedoConditions()
      expired: $exists: false).count() then true

  action: (type) ->
    sel =
      user_id: Meteor.userId()
      expired: $exists: false
    # This is for autopublish scenarios
    existsOrNot = if type == 'redo' then undone: undoneRedoConditions() else $or: [
      { undone: null }
      { undone: $exists: false }
    ]
    sorter = {}
    sorter[if type == 'redo' then 'undone' else 'lastModified'] = -1
    transaction = tx.Transactions.findOne(_.extend(sel, existsOrNot), sort: sorter)
    transaction and transaction.description

  ready: ->
    Session.get 'ready'

  menuPin: ->
    if Meteor.user()
      Meteor.user().menuPin
    else
      true

  menuPinIcon: ->
    if Meteor.user().menuPin
      'chevron_left'
    else
      'chevron_right'

  muteIcon: ->
    if Meteor.user().muted
      'volume_off'
    else
      'volume_up'

  muteClass: ->
    if !Meteor.user().muted
      'mdl-button--colored'

  maxFileUpload: ->
    filesize Template.App_body.getUploadBitsAllowed()

  getFileSize: (number) ->
    if number
      filesize number
    else
      '0'
  
  avatar: ->
    if Meteor.user().emails
      Gravatar.imageUrl Meteor.user().emails[0].address,
        secure: true
    else if Meteor.user()
      Avatar.getUrl Meteor.user()

Template.menu.events
  'click .menuToggle': (event, instance) ->
    event.stopImmediatePropagation()

    Meteor.call('users.setMenuPin', {menuPin:false}, ->
      $( 'div[class^="mdl-layout__obfuscator"]' ).trigger( "click" )
    )

  'click .js-logout': (event) ->
    event.stopImmediatePropagation()

    Meteor.logout()
    FlowRouter.go '/intro'

  'click #menuPin': (event) ->
    event.stopImmediatePropagation()

    if Meteor.user().menuPin
      Meteor.call('users.setMenuPin', {menuPin:false})
    else
      Meteor.call('users.setMenuPin', {menuPin:true})

  'click .homeLink': (event) ->
    event.stopImmediatePropagation()
    $('#searchForm input').val('')

  'click #undo': (event) ->
    event.stopImmediatePropagation()
    tx.undo()

  'click #redo': (event) ->
    event.stopImmediatePropagation()
    tx.redo()

  'click a': (event) ->
    $('.mdl-layout__obfuscator.is-visible').trigger( "click" )
    $('.mdl-layout__content').animate({ scrollTop: 0 }, 200)

Template.registerHelper 'increment', (count) ->
  return count + 1

Template.registerHelper 'emoji', (argument) ->
  emojione.shortnameToUnicode argument
