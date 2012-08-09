_ = require 'underscore'
helpers = require '../helpers'

module.exports = (hooks) ->
  hooks.concatable = (file, content) -> file.type

  hooks.preventContent = (file, opraBlock) -> _(opraBlock.params).contains('concat') && opraBlock.filename

  hooks.data = (data, opraBlock, concatable, callback) ->
    if _(opraBlock.params).contains('concat')
      areAllEqual = concatable.every (hook, i) ->
        objs = data.map (d) ->
          hook d.file, d.content
        helpers.allEqual objs

      unless areAllEqual
        callback "Concatenation failed; make sure file types, media types and ie-constraints are equivalent within all blocks"
        return
      if data.length is 0
        callback null,
          tags: ""
      else
        dd =
          content: _(data).pluck("content").join((if data[0].file.type is "js" then ";\n" else "\n"))
          file:
            name: opraBlock.filename
            params: data[0].file.params
            spaces: data[0].file.spaces
            absolutePath: opraBlock.absolutePath
            encoding: "utf8"
            type: data[0].file.type

        if _(opraBlock.params).contains("concat") and opraBlock.filename and not _(dd.file.params).contains("inline")
          callback(null, {
            tags: [{ file: dd.file }]
            outfiles: [
              name: dd.file.absolutePath
              content: dd.content
            ]
          })
        else
          callback null, { tags: [dd] }
    else
      callback()