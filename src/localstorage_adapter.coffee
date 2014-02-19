#global Ember

#global DS
  "use strict"
  DS.LSSerializer = DS.JSONSerializer.extend(
    serializeHasMany: (record, json, relationship) ->
      key = relationship.key
      relationshipType = DS.RelationshipChange.determineRelationshipType(record.constructor, relationship)
      json[key] = record.get(key).mapBy("id")  if relationshipType is "manyToNone" or relationshipType is "manyToMany" or relationshipType is "manyToOne"
      return


    # TODO support for polymorphic manyToNone and manyToMany relationships

    ###
    Extracts whatever was returned from the adapter.

    If the adapter returns relationships in an embedded way, such as follows:

    ```js
    {
    "id": 1,
    "title": "Rails Rambo",

    "_embedded": {
    "comment": [{
    "id": 1,
    "comment_title": "FIRST"
    }, {
    "id": 2,
    "comment_title": "Rails is unagi"
    }]
    }
    }

    this method will create separated JSON for each resource and then push
    them individually to the Store.

    In the end, only the main resource will remain, containing the ids of its
    relationships. Given the relations are already in the Store, we will
    return a JSON with the main resource alone. The Store will sort out the
    associations by itself.

    @method extractSingle
    @private
    @param {DS.Store} store the returned store
    @param {DS.Model} type the type/model
    @param {Object} payload returned JSON
    ###
    extractSingle: (store, type, payload) ->
      if payload and payload._embedded
        for relation of payload._embedded
          typeName = Ember.String.singularize(relation)
          embeddedPayload = payload._embedded[relation]
          if embeddedPayload
            if Ember.isArray(embeddedPayload)
              store.pushMany typeName, embeddedPayload
            else
              store.push typeName, embeddedPayload
        delete payload._embedded
      @normalize type, payload


    ###
    This is exactly the same as extractSingle, but used in an array.

    @method extractSingle
    @private
    @param {DS.Store} store the returned store
    @param {DS.Model} type the type/model
    @param {Array} payload returned JSONs
    ###
    extractArray: (store, type, payload) ->
      serializer = this
      payload.map (record) ->
        extracted = serializer.extractSingle(store, type, record)
        serializer.normalize type, record

  )
  DS.LSAdapter = DS.Adapter.extend(Ember.Evented,

    ###
    This is the main entry point into finding records. The first parameter to
    this method is the model's name as a string.

    @method find
    @param {DS.Model} type
    @param {Object|String|Integer|null} id
    ###
    find: (store, type, id, opts) ->
      adapter = this
      allowRecursive = true
      namespace = @_namespaceForType(type)

      ###
      In the case where there are relationships, this method is called again
      for each relation. Given the relations have references to the main
      object, we use allowRecursive to avoid going further into infinite
      recursiveness.

      Concept from ember-indexdb-adapter
      ###
      allowRecursive = opts.allowRecursive  if opts and typeof opts.allowRecursive isnt "undefined"
      new Ember.RSVP.Promise((resolve, reject) ->
        namespace.then (value) ->
          record = Ember.A(value.records[id])
          if allowRecursive and not Ember.isEmpty(record)
            adapter.loadRelationships(type, record).then (finalRecord) ->
              Ember.run null, resolve, finalRecord
              return

          else
            if Ember.isEmpty(record)
              Ember.run null, reject
            else
              Ember.run null, resolve, record
          return

        return
      )

    findMany: (store, type, ids) ->
      adapter = this
      namespace = @_namespaceForType(type)
      new Ember.RSVP.Promise((resolve, reject) ->
        namespace.then((value) ->
          results = []
          i = 0

          while i < ids.length
            results.push Ember.copy(value.records[ids[i]])
            i++
          Ember.run null, resolve, results
          return
        ).then (records) ->
          if records.get("length")
            adapter.loadRelationshipsForMany type, records
          else
            records

        return
      )


    # Supports queries that look like this:
    #
    #   {
    #     <property to query>: <value or regex (for strings) to match>,
    #     ...
    #   }
    #
    # Every property added to the query is an "AND" query, not "OR"
    #
    # Example:
    #
    #  match records with "complete: true" and the name "foo" or "bar"
    #
    #    { complete: true, name: /foo|bar/ }
    findQuery: (store, type, query, recordArray) ->
      namespace = @_namespaceForType(type)
      adapter = this
      new Ember.RSVP.Promise((resolve, reject) ->
        namespace.then (value) ->
          results = adapter.query(value.records, query)
          results = adapter.loadRelationshipsForMany(type, results)  if results.get("length")
          Ember.run null, resolve, results
          return

        return
      )

    query: (records, query) ->
      results = []
      id = undefined
      record = undefined
      property = undefined
      test = undefined
      push = undefined
      for id of records
        record = records[id]
        for property of query
          test = query[property]
          push = false
          if Object::toString.call(test) is "[object RegExp]"
            push = test.test(record[property])
          else
            push = record[property] is test
        results.push record  if push
      results

    findAll: (store, type) ->
      namespace = @_namespaceForType(type)
      results = []
      new Ember.RSVP.Promise((resolve, reject) ->
        namespace.then (value) ->
          for id of value.records
            results.push Ember.copy(value.records[id])
          Ember.run null, resolve, results
          return

        return
      )

    createRecord: (store, type, record) ->
      namespace = @_namespaceForType(type)
      adapter = this
      new Ember.RSVP.Promise((resolve, reject) ->
        namespace.then (value) ->
          recordHash = record.serialize(includeId: true)
          value.records[recordHash.id] = recordHash
          adapter.persistData(type, value).then (record) ->
            console.log record
            Ember.run null, resolve
            return

          return

        return
      )

    updateRecord: (store, type, record) ->
      namespace = @_namespaceForType(type)
      id = record.get("id")
      adapter = this
      new Ember.RSVP.Promise((resolve, reject) ->
        namespace.then (value) ->
          value.records[id] = record.serialize(includeId: true)
          adapter.persistData(type, value).then (value) ->
            Ember.run null, resolve
            return

          return

        return
      )

    deleteRecord: (store, type, record) ->
      namespaceRecords = @_namespaceForType(type)
      id = record.get("id")
      adapter = this
      new Ember.RSVP.Promise((resolve, reject) ->
        namespaceRecords.then (value) ->
          delete value.records[id]

          adapter.persistData(type, value).then (value) ->
            Ember.run null, resolve
            return

          return

        return
      )

    generateIdForRecord: ->
      Math.random().toString(32).slice(2).substr 0, 5


    # private
    adapterNamespace: ->
      @namespace or "DS.LSAdapter"

    loadData: ->
      storage = @_adapter().getItem(@adapterNamespace())
      (if storage then storage else {})

    persistData: (type, data) ->
      modelNamespace = @modelNamespace(type)
      localStorageData = @loadData()
      adapter = this
      localStorageData.then (value) ->
        value[modelNamespace] = data
        adapter._adapter().setItem adapter.adapterNamespace(), value


    _namespaceForType: (type) ->
      namespace = @modelNamespace(type)
      storage = @_adapter().getItem(@adapterNamespace())
      storage.then (value) ->
        (if value then value[namespace] or records: {} else records: {})



    # return thing;
    _adapter: ->

      # return localStorage;
      localforage

    modelNamespace: (type) ->
      type.url or type.toString()


    ###
    This takes a record, then analyzes the model relationships and replaces
    ids with the actual values.

    Stolen from ember-indexdb-adapter

    Consider the following JSON is entered:

    ```js
    {
    "id": 1,
    "title": "Rails Rambo",
    "comments": [1, 2]
    }

    This will return:

    ```js
    {
    "id": 1,
    "title": "Rails Rambo",
    "comments": [1, 2]

    "_embedded": {
    "comment": [{
    "_id": 1,
    "comment_title": "FIRST"
    }, {
    "_id": 2,
    "comment_title": "Rails is unagi"
    }]
    }
    }

    This way, whenever a resource returned, its relationships will be also
    returned.

    @method loadRelationships
    @private
    @param {DS.Model} type
    @param {Object} record
    ###
    loadRelationships: (type, record) ->
      adapter = this
      new Ember.RSVP.Promise((resolve, reject) ->
        resultJSON = {}
        typeKey = type.typeKey
        relationshipNames = undefined
        relationships = undefined
        relationshipPromises = []
        relationshipNames = Ember.get(type, "relationshipNames")
        relationships = relationshipNames.belongsTo
        relationships = relationships.concat(relationshipNames.hasMany)
        relationships.forEach (relationName) ->
          relationModel = type.typeForRelationship(relationName)
          relationEmbeddedId = record[relationName]
          relationProp = adapter.relationshipProperties(type, relationName)
          relationType = relationProp.kind
          promise = undefined
          embedPromise = undefined

          ###
          This is the relationship field.
          ###
          opts = allowRecursive: false

          ###
          embeddedIds are ids of relations that are included in the main
          payload, such as:

          {
          cart: {
          id: "s85fb",
          customer: "rld9u"
          }
          }

          In this case, cart belongsTo customer and its id is present in the
          main payload. We find each of these records and add them to _embedded.
          ###
          if relationEmbeddedId
            if relationType is "belongsTo" or relationType is "hasOne"
              promise = adapter.find(null, relationModel, relationEmbeddedId, opts)
            else promise = adapter.findMany(null, relationModel, relationEmbeddedId, opts)  if relationType is "hasMany"
            embedPromise = new Ember.RSVP.Promise((resolve, reject) ->
              promise.then (relationRecord) ->
                finalPayload = adapter.addEmbeddedPayload(record, relationName, relationRecord)
                resolve finalPayload
                return

              return
            )
            relationshipPromises.push embedPromise
          return

        Ember.RSVP.all(relationshipPromises).then ->
          resolve record
          return

        return
      )


    ###
    Given the following payload,

    {
    cart: {
    id: "1",
    customer: "2"
    }
    }

    With `relationshipName` being `customer` and `relationshipRecord`

    {id: "2", name: "Rambo"}

    This method returns the following payload:

    {
    cart: {
    id: "1",
    customer: "2"
    },
    _embedded: {
    customer: {
    id: "2",
    name: "Rambo"
    }
    }
    }

    which is then treated by the serializer later.

    @method addEmbeddedPayload
    @private
    @param {Object} payload
    @param {String} relationshipName
    @param {Object} relationshipRecord
    ###
    addEmbeddedPayload: (payload, relationshipName, relationshipRecord) ->
      objectHasId = (relationshipRecord and relationshipRecord.id)
      arrayHasIds = (relationshipRecord.length and relationshipRecord.everyBy("id"))
      isValidRelationship = (objectHasId or arrayHasIds)
      if isValidRelationship
        payload["_embedded"] = {}  unless payload["_embedded"]
        payload["_embedded"][relationshipName] = relationshipRecord
        if relationshipRecord.length
          payload[relationshipName] = relationshipRecord.mapBy("id")
        else
          payload[relationshipName] = relationshipRecord.id
      if @isArray(payload[relationshipName])
        payload[relationshipName] = payload[relationshipName].filter((id) ->
          id
        )
      payload

    isArray: (value) ->
      Object::toString.call(value) is "[object Array]"


    ###
    Same as `loadRelationships`, but for an array of records.

    @method loadRelationshipsForMany
    @private
    @param {DS.Model} type
    @param {Object} recordsArray
    ###
    loadRelationshipsForMany: (type, recordsArray) ->
      adapter = this
      new Ember.RSVP.Promise((resolve, reject) ->
        recordsWithRelationships = []
        recordsToBeLoaded = []
        promises = []

        ###
        Some times Ember puts some stuff in arrays. We want to clean it so
        we know exactly what to iterate over.
        ###
        for i of recordsArray
          recordsToBeLoaded.push recordsArray[i]  if recordsArray.hasOwnProperty(i)
        loadNextRecord = (record) ->

          ###
          Removes the first item from recordsToBeLoaded
          ###
          recordsToBeLoaded = recordsToBeLoaded.slice(1)
          promise = adapter.loadRelationships(type, record)
          promise.then (recordWithRelationships) ->
            recordsWithRelationships.push recordWithRelationships
            if recordsToBeLoaded[0]
              loadNextRecord recordsToBeLoaded[0]
            else
              resolve recordsWithRelationships
            return

          return


        ###
        We start by the first record
        ###
        loadNextRecord recordsToBeLoaded[0]
        return
      )


    ###
    @method relationshipProperties
    @private
    @param {DS.Model} type
    @param {String} relationName
    ###
    relationshipProperties: (type, relationName) ->
      relationships = Ember.get(type, "relationshipsByName")
      if relationName
        relationships.get relationName
      else
        relationships
  )
