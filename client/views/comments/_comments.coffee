Handlebars.registerHelper "commentDate", (date) ->
  if date
    dateObj = new Date(date)
    return $.timeago(dateObj)
  "some time ago"

Editor = {}


#
#  Commenting Widget
#
Template._comments.rendered = ->
  commentable = @data
  _.each commentable.comments(), (comment) ->
    comment.clearNotification()

    Editor = ace.edit 'editor'
    Editor.setTheme 'ace/theme/chrome'
    Editor.getSession().setMode 'ace/mode/markdown'
    Editor.setFontSize 16
    Editor.renderer.setShowPrintMargin false
    Editor.renderer.setShowGutter false
    Editor.setHighlightActiveLine true
    Editor.on 'change', (e) ->
      Session.set 'comments.new.value', Editor.getValue()

    #Session.set 'comments.new.editor', editor
    
Template._comments.helpers
  comments: ->
    @comments()

  newComment: ->
    Session.get 'comments.new.value'

  previewing: ->
    Session.get 'comments.new.previewing'

Template._comments.events
  'click .toggle-preview': (e) ->
    preview = Session.get 'comments.new.previewing'
    preview = !preview
    Session.set 'comments.new.previewing', preview

  'click .add-comment': (e) ->
    comment = 
      associationId: @id
      userId: Meteor.userId()
      username: Meteor.user().username || Meteor.user().emails[0].address
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



#
#  Unread Widget
#
getOpts = ->
  defaults =
    tags: []
    align: 'left'
  opts = Session.get 'comments.unread.options'
  _.extend defaults, opts

Template._unreadWidget.rendered = ->
  # Set options hash
  Session.set 'comments.unread.options', @data

  # Set the width of the dropdown to the computed value so the slide works correctly
  $('.unread-widget').on 'shown.bs.dropdown', (e) ->
    $('.comments-dropdown').css 'width', $('.comments-dropdown').width()

Template._unreadWidget.helpers
  count: ->
    Comment.unread(getOpts().tags).length

  countLabelClass: ->
    if Comment.unread(getOpts().tags).length > 0 then 'label-danger' else 'label-default'

  unreadComments: ->
    Comment.unread(getOpts().tags)

  align: ->
    getOpts().align

Template._unreadWidget.events  
  'click .clear-comments': (e) ->
    e.preventDefault()
    e.stopPropagation()
    
    count = Comment.unread(getOpts().tags).length

    $('.comments-dropdown li.comment').each (i, e) ->
      # Slide each item out to right
      $e = $(e)
      $e.delay(i*80).animate
        marginLeft: (if parseInt($e.css("marginLeft"), 10) is 0 then $e.outerWidth() else 0)
      , ->
        # After the last one slides out, slide the menu up to close
        if i+1 is count
          $('.comments-dropdown').slideUp 300, ->
            # Finally, actually clear the notification in the database
            _.each Comment.unread(getOpts().tags), (comment) ->
              comment.clearNotification()