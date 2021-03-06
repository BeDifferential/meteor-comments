UI.registerHelper "commentDate", (date) ->
  if date
    dateObj = new Date(date)
    return $.timeago(dateObj)
  "some time ago"

Editor = {}

Template.comments.created = ->
  Session.set 'comments.new.value', ''
  Session.set 'comments.new.previewing', false

#
#  Commenting Widget
#
Template.comments.rendered = ->
  commentable = @data
  _.each commentable.comments(), (comment) ->
    comment.clearNotification()

  setup = ->
    Editor = ace.edit 'editor'
    Editor.setTheme 'ace/theme/chrome'
    Editor.getSession().setMode 'ace/mode/markdown'
    Editor.setFontSize 16
    Editor.renderer.setShowPrintMargin false
    Editor.renderer.setShowGutter false
    Editor.setHighlightActiveLine true
    Editor.on 'change', (e) ->
      Session.set 'comments.new.value', Editor.getValue()

  if Meteor.user() then setTimeout setup, 300

  $('.toggle-preview').tooltip title: 'Click to toggle markdown preview mode.'
    
Template.comments.helpers
  comments: ->
    _.sortBy @comments(), 'createdAt'

  newComment: ->
    Session.get 'comments.new.value'

  previewing: ->
    Session.get 'comments.new.previewing'

Template.comments.events
  'click .toggle-preview': (e) ->
    preview = Session.get 'comments.new.previewing'
    preview = !preview
    Session.set 'comments.new.previewing', preview

  'click .add-comment': (e) ->
    username = "Unknown"
    user = Meteor.user()
    if user.emails then username = user.emails[0].address
    if user.username then username = user.username
    if user.profile and user.profile.name then username = user.profile.name
    if user.profile and user.profile.firstName then username = user.profile.firstName + " " + Meteor.user().profile.lastName

    comment = 
      associationId: @id
      userId: Meteor.userId()
      username: username
      comment: Session.get 'comments.new.value'
      path: Router.current().path
      notify: []
      tags: []

    # Allow custom modification
    comment = @before_comment comment

    # Add every other commentor above to notify list
    _.each @comments(), (e) ->
      comment.notify.push e.userId

    # Remove duplicates
    comment.notify = _.uniq comment.notify

    # Remove this user
    comment.notify = _.reject comment.notify, (e) ->
      e is Meteor.userId()

    # Add the comment
    Comment.create comment

    # Clear values
    Session.set('comments.new.value', '')
    Editor.setValue('')