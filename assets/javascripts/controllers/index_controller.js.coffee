App.IndexController = Ember.ArrayController.extend
  needs: ["application"]
  currentUser: Ember.computed.alias("controllers.application.currentUser")
  isLeftMenuOpen: Ember.computed.alias("controllers.application.isLeftMenuOpen")
  isRightMenuOpen: Ember.computed.alias("controllers.application.isRightMenuOpen")

  itemController: "RoomUserStateItem"


  detectTypeAndFormatBody: (body)->
    if body.match("\n")
      {type: "paste", body: body}
    else if matches = (/\/me (.*)/g).exec(body)
      {type: "me", body: matches[1]}
    else
      {type: "text", body: body}


  actions:
    loadHistory: ->
      activeState = @get("activeState")
      room = activeState.get("room")
      if room.get("messages")[0]
        beforeId = room.get("messages")[0].get("id")
      else
        beforeId = true

      activeState.messagePoller.fetchMessages(beforeId)


    postMessage: (msgTxt)->
      msgTxt = msgTxt.replace(/\s*$/g, "")
      room = @get("activeState").get("room")
      currentUser = @get("currentUser")
      formatted = @detectTypeAndFormatBody(msgTxt)
      messageParams =
        room: room
        body: msgTxt
        type: formatted.type
        createdAt: new Date()
        user: currentUser

      if messageParams.type != "paste"
        messageParams.formattedBody = App.plugins.processMessageBody(formatted.body, formatted.type)

      msg = @store.createRecord("message", messageParams)
      console.log "backup", msg.get("formattedBody")

      if room.get("messages.length") == (MogoChat.config.messagesPerLoad + 1)
        room.get("messages").shiftObject()

      console.log "backup again", msg.get("formattedBody")
      successCallback = =>
        room.get("messages").pushObject(msg)
      errorCallback   = =>
        msg.set("errorPosting", true)
        room.get("messages").pushObject(msg)
      msg.save().then(successCallback, errorCallback)
