#global Ember

#global DS
"use strict"
DS.LSSerializer = DS.JSONSerializer.extend(
  serializeHasMany: (record, json, relationship) ->
    key = relationship.key
    relationshipType = DS.RelationshipChange.determineRelationshipType(record.constructor, relationship)
    json[key] = record.get(key).mapBy("id")  if relationshipType in ["manyToNone", "manyToMany", "manyToOne"]


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
