define [
  'jquery'
  'backbone'
  './Document'
], ($, Backbone, Document) ->
  DOCUMENTCLOUD_BASE = "//www.documentcloud.org/documents"

  Backbone.Model.extend
    documentCloudUrl: (id) ->
      prefs = @get('preferences')
      sidebar = prefs?.get('sidebar') && 'true' || 'false'
      "#{DOCUMENTCLOUD_BASE}/#{id}?sidebar=#{sidebar}"

    findDocumentFromJson: (json) ->
      if json.heading?
        $.Deferred().resolve(new Document(json))
      else if json.documentcloud_id
        $.Deferred().resolve(new Document({
          heading: json.title || json.description
          documentCloudUrl: @documentCloudUrl(json.documentcloud_id)
        }))
      else
        $.getJSON("#{json.id}.json").pipe((data) -> new Document(data))