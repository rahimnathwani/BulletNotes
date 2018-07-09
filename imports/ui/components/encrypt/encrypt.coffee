{ Template } = require 'meteor/templating'
# import {
#   encrypt,
#   stopSharing
# } from '/imports/api/notes/methods.coffee'

{ Notes } = require '/imports/api/notes/notes.coffee'

require './encrypt.jade'

Template.encrypt.onRendered ->
  checkeventcount = 1
  prevTarget = undefined

Template.encrypt.helpers
    'decrypting': ->
        if @encryptedRoot || @encrypted
            true

Template.encrypt.events

  'click .encryptBtn': (event, instance) ->
    event.preventDefault()
    event.stopImmediatePropagation()
    
    password = $('.encryptPassword').val()

    if password.length < 3
        alert "Password too short"
        return

    if $('.encryptPassword').val() != $('.encryptPasswordVerify').val()
        alert "Passwords do not match!"
        return

    if $('.encryptRoot').first().hasClass('is-checked')
        Template.encrypt.encryptNote this, password
        Meteor.call 'notes.setEncrypted', {
          noteId: @_id
          encrypted: true
          encryptedRoot: true
        }
    else
        notes = Notes.find { parent: this._id }, sort: rank: 1
        notes.forEach (note) ->
            Template.encrypt.encryptNote note, password 

        Meteor.call 'notes.setEncrypted', {
            noteId: @_id
            encrypted: false
            encryptedRoot: true
        }

    Blaze.getView($('#menuItem_'+@_id)[0]).templateInstance().state.set('showEncrypt', false)
    $('.modal-backdrop.in').fadeOut()

  'click .decryptBtn': (event, instance) ->
    event.preventDefault()
    event.stopImmediatePropagation()

    password = $('.decryptPassword').val()

    if this.encrypted
        Template.encrypt.decryptNote this, password
    else
        # The note is not encrypted, which means it is a root note with encrypted children, so skip this note
        notes = Notes.find { parent: this._id }, sort: rank: 1
        badPass = false
        notes.forEach (note) ->
            if badPass || !Template.encrypt.decryptNote note, password
                badPass = true
                false

        if !badPass
            Meteor.call 'notes.setEncrypted', {
                noteId: @_id
                encrypted: false
                encryptedRoot: false
            }

    Blaze.getView($('#menuItem_'+@_id)[0]).templateInstance().state.set('showEncrypt', false)
    $('.modal-backdrop.in').fadeOut()

Template.encrypt.encryptNote = (note, password) ->
    encrypted = CryptoJS.AES.encrypt(note.title, password).toString()
    encryptedBody = CryptoJS.AES.encrypt(note.body, password).toString()

    Meteor.call 'notes.updateTitle', {
      noteId: note._id
      title: encrypted
      shareKey: FlowRouter.getParam 'shareKey'
    }

    Meteor.call 'notes.updateBody', {
      noteId: note._id
      body: encryptedBody
      shareKey: FlowRouter.getParam 'shareKey'
    }

    Meteor.call 'notes.setEncrypted', {
      noteId: note._id
      encrypted: true
    }

    # Get and encrypt child notes
    notes = Notes.find { parent: note._id }, sort: rank: 1
    notes.forEach (note) ->
        if !Template.encrypt.encryptNote note, password
            false
        else
            true

Template.encrypt.decryptNote = (note, password) ->
    try 
        crypt = CryptoJS.AES.decrypt(note.title, password)
        cryptBody = CryptoJS.AES.decrypt(note.body, password)
    catch e
        Template.App_body.showSnackbar
          message: "Bad password"
        return false
        
    decrypted = crypt.toString(CryptoJS.enc.Utf8)
    decryptedBody = cryptBody.toString(CryptoJS.enc.Utf8)
    if !crypt || decrypted.length < 1
        Template.App_body.showSnackbar
          message: "Bad password"
        return false

    

    Meteor.call 'notes.updateTitle', {
      noteId: note._id
      title: decrypted
      shareKey: FlowRouter.getParam 'shareKey'
    }

    Meteor.call 'notes.updateBody', {
      noteId: note._id
      body: decryptedBody
    }

    Meteor.call 'notes.setEncrypted', {
      noteId: note._id
      encrypted: false
    }

    # Get and decrypt child notes
    notes = Notes.find { parent: note._id }, sort: rank: 1
    notes.forEach (note) ->
        if !Template.encrypt.decryptNote note, password
            return false
        else
            return true
    
    return true