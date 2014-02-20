App.User = DS.Model.extend
  name: DS.attr("string")
  email:  DS.attr("string")
  role:   DS.attr("string")
  password: DS.attr("string")
  color: DS.attr("string")
  authToken: DS.attr("string")

  isAdmin: (->
    @get("role") == "admin"
  ).property("role")


  borderStyle: (->
    "border-left: 0.2em solid #{@get("color")};"
  ).property("color")

  fontColor: (->
    "color: #{@get("color")};"
  ).property("color")


DS.ArrayTransform = DS.Transform.extend
  deserialize: (serialized)-> []
  serialize: (deserialized)-> []

App.register("transform:array", DS.ArrayTransform)

App.Room = DS.Model.extend
  name: DS.attr("string")
  roomUserState: DS.belongsTo("room_user_state")
  messages: DS.attr("array")
  users: DS.attr("array")
  isHistoryAvailable: DS.attr("boolean")


App.RoomUserState = DS.Model.extend Em.Evented,
  user: DS.belongsTo("user")
  joined:  DS.attr("boolean")
  room:  DS.belongsTo("room")
  lastPingedAt: DS.attr("date")
  beforeMessageId: DS.attr("number")
  afterMessageId: DS.attr("number")
  active: DS.attr("boolean", {defaultValue: false})
  notification: DS.attr("boolean", {defaultValue: false})

  addUsers: (users)->
    users = for userAttributes in users
      if @store.recordIsLoaded("user", userAttributes.id)
        user = @store.getById("user", userAttributes.id)
      else
        user = @store.push("user",
          id: userAttributes.id
          name: userAttributes.name
          role: userAttributes.role
          color: App.paintBox.getColor()
        )
    @set("room.users", users)


  addMessages: (data)->
    messages = data.messages

    if data.before
      if data.before == true && messages
        messages = messages.reverse()
      addAction = "unshiftObject"
    else
      addAction = "pushObject"

    for messageAttrs in messages
      if @store.recordIsLoaded("message", messageAttrs.id)
        message = @store.getById("message", messageAttrs.id)

        #TODO this can be optimized I think. Computed property?
        existingKeys = []
        for existingMsg in @get("room.messages")
          existingKeys.push(existingMsg.get("id"))

        if existingKeys.indexOf(message.get("id")) == -1
          @get("room.messages")[addAction](message)
      else
        message = @store.push("message", {
          id: messageAttrs.id,
          type: messageAttrs.type,
          body: messageAttrs.body,
          formattedBody: App.plugins.processMessageBody(
            messageAttrs.body,
            messageAttrs.type,
            (if data.before then true else false)
          ),
          createdAt: messageAttrs.created_at
        })
        @get("room.messages")[addAction](message)

      message.set("room", @get("room"))

      if @store.recordIsLoaded("user", messageAttrs.user.id)
        user = @store.getById("user", messageAttrs.user.id)
      else
        userParams =
          id: messageAttrs.user.id
          name: messageAttrs.user.name
          role: messageAttrs.user.role
          color: App.paintBox.getColor()
        user = @store.push("user", userParams)

      message.set("user", user)

      if message.get("body").match(@get("user.name")) && addAction == "pushObject" && @get("afterMessageId")
        @set("notification", true)
        App.notifyBySound()

      if @get("room.messages.length") == (MogoChat.config.messagesPerLoad + 1) && addAction == "pushObject"
        @get("room.messages").shiftObject()
        @set("room.isHistoryAvailable", true)

    if messages.length > 0 && !data.before
      @set("afterMessageId", messages[messages.length - 1].id)


App.Message = DS.Model.extend
  body: DS.attr("string")
  formattedBody: DS.attr("string")
  type: DS.attr("string")
  createdAt: DS.attr("string")
  errorPosting: DS.attr("boolean", defaultValue: false)
  user: DS.belongsTo("user")
  room: DS.belongsTo("room")

  condensedBody: (->
    splitMsg = @get("body").split("\n")
    if splitMsg.length > 5
      newMsg = splitMsg.slice(0, 4)
      newMsg.push("...")
      newMsg.join("\n")
    else
      splitMsg.join("\n")
  ).property("body")

  link: (->
    "/rooms/#{@get("room.id")}/messages/#{@get("id")}"
  ).property(["id", "roomId"])
