fs = require 'fs'
should = require 'should'
powerfs = require 'powerfs'
assert = require 'assert'
build = require('../setup.js').requireSource('build.js')
parse = require('../setup.js').requireSource('parse.js')



describe 'build.filetype', ->

  it 'should find the filetype from the suffix and the compiler', () ->
    build.filetype('test.foo', {
      foo: { target: 'bar' }
    }).should.equal('bar')

  it 'should "other" if no none is found', () ->
    build.filetype('test.foo', {
      bar: { target: 'bar' }
    }).should.equal('other')



describe 'build.whichIE', ->

  it 'should find ie7', () ->
    build.whichIE(['a', 'b', 'ie7']).should.equal('ie7')

  it 'should not return if anything if no IEs', () ->
    assert(build.whichIE(['a', 'b', 'c']) == undefined)



describe 'build.wrappIE', ->

  it 'should wrapp ie7', () ->
    build.wrappIE(['a', 'ie7'], 'foobar').should.equal("<!--[if IE 7]>foobar<![endif]-->")

  it 'should return the original string if no IEs', () ->
    build.wrappIE(['a', 'b'], 'foobar').should.equal("foobar")



describe 'build.paramsToMediaType', ->

  it 'should find screen', () ->
    build.paramsToMediaType(['a', 'screen', 'b']).should.equal('screen')

  it 'should find print', () ->
    build.paramsToMediaType(['a', 'b', 'print']).should.equal('print')

  it 'should prefer screen over print', () ->
    build.paramsToMediaType(['screen', 'b', 'print']).should.equal('screen')
    build.paramsToMediaType(['print', 'b', 'screen']).should.equal('screen')

  it 'should not return if anything if no media types', () ->
    assert(build.paramsToMediaType(['a', 'b', 'c']) == undefined)




describe 'parse.getMatches', ->

  it 'should parse input data for filenames, spaces, params and files', () ->
    res = parse.getMatches """
      <html>
        <!--apa a b   c

          x.js d e   f
          /y.css file.ext i j k
          /z.foobar l m data.something n
        -->
        test
        <!--apa banan
        -->

      </html>
    """, '<!--apa', '-->'

    res.should.eql([{
      match: '  <!--apa a b   c\n\n    x.js d e   f\n    /y.css file.ext i j k\n    /z.foobar l m data.something n\n  -->'
      filename: undefined
      spaces: '  '
      params: ['a', 'b', 'c']
      files: [{
        name: 'x.js'
        params: ['d', 'e', 'f']
        spaces: '    '
      }, {
        name: '/y.css'
        params: ['file.ext', 'i', 'j', 'k']
        spaces: '    '
      }, {
        name: '/z.foobar'
        params: ['l', 'm', 'data.something', 'n']
        spaces: '    '
      }]
    }, {
      match: '  <!--apa banan\n  -->'
      filename: undefined
      spaces: '  '
      params: ['banan']
      files: []
    }])



describe 'parse.flagMatches', ->

  it 'should default to no global object and no files and no params', ->
    parse.flagMatches([{
      foo: 'bar'
      params: ['inline', 'concat']
    }, {
      foo: 'bar'
      files: [{
        foo: 'bar'
      }]
    }]).should.eql [{
      foo: 'bar'
      params: ['concat', 'inline'] # these are sorted in alphabetic order
      files: []
    }, {
      foo: 'bar'
      params: []
      files: [{
        foo: 'bar'
        params: []
      }]
    }]

  it 'should filter params', ->
    parse.flagMatches([{
      unknown: 'x',
      params: ['a', 'b', 'c', 'inline', 'concat']
      files: [{
        foo: 'y',
        params: ['escape', 'y', 'screen', 'x']
      }]
    }, {
      bar: 'x',
      params: ['a', 'inline', 'concat-wrong']
      files: []
    }], {}).should.eql [{
      unknown: 'x',
      params: ['concat', 'inline']
      files: [{
        foo: 'y',
        params: ['escape', 'screen']
      }]
    }, {
      bar: 'x',
      params: ['inline']
      files: []
    }]

  it 'should let global params take precedence', ->
    parse.flagMatches([{
      params: ['inline']
      files: [{
        params: ['screen', 'escape']
      }]
    }], {
      concat: true,
      screen: false
    }).should.eql([{
      params: ['concat', 'inline']
      files: [{
        params: ['escape']
      }]
    }])

  it 'should translate always-params and never-params', ->
    parse.flagMatches([{
      params: ['always-inline', 'concat', 'never-concat']
      files: [{
        params: ['always-escape', 'screen', 'never-screen']
      }]
    }]).should.eql([{
      params: ['inline']
      files: [{
        params: ['escape']
      }]
    }])

  it 'should let always- and never-params take precedence over global params', ->
    parse.flagMatches([{
      params: ['inline', 'never-concat']
      files: [{
        params: ['always-screen', 'escape']
      }]
    }], {
      concat: true,
      screen: false
    }).should.eql([{
      params: ['inline']
      files: [{
        params: ['escape', 'screen']
      }]
    }])

  it 'should throw if a parameter is specified as both always and never for a block', ->
    wrapper = () ->
      parse.flagMatches([{
        params: ['always-concat', 'never-concat']
      }])
    wrapper.should.throw('"always" and "never" assigned to the same block')

  it 'should throw if a parameter is specified as both always and never for a file', ->
    wrapper = () ->
      parse.flagMatches([{
        files: [{
          params: ['always-compress', 'never-compress']
        }]
      }])
    wrapper.should.throw('"always" and "never" assigned to the same file')

  it 'should allow a certain set of params for files and one for blocks', ->
    parse.flagMatches([{
      params: ['inline', 'concat']
      files: [{
        params: ['compress', 'paths', 'ids', 'escape', 'screen', 'ie7', 'print', 'npm']
      }]
    }]).should.eql([{
      params: ['concat', 'inline']
      files: [{
        params: ['compress', 'escape', 'ids', 'ie7', 'npm', 'paths', 'print', 'screen']
      }]
    }])

  it 'should propagate file-level params assigned to blocks', ->
    parse.flagMatches([{
      params: ['inline', 'compress', 'paths']
      files: [{
        params: ['print']
      }, {

      }]
    }]).should.eql([{
      params: ['inline']
      files: [{
        params: ['compress', 'paths', 'print']
      }, {
        params: ['compress', 'paths']
      }]
    }])

  it 'should propagate file-level params assigned to blocks, except when the file has a never-param', ->
    parse.flagMatches([{
      params: ['inline', 'compress', 'paths']
      files: [{
        params: ['print', 'never-compress']
      }, {

      }]
    }]).should.eql([{
      params: ['inline']
      files: [{
        params: ['paths', 'print']
      }, {
        params: ['compress', 'paths']
      }]
    }])

  it 'should propagate file-level always-params assigned to blocks', ->
    parse.flagMatches([{
      params: ['inline', 'always-compress', 'paths']
      files: [{
        params: ['print']
      }, {

      }]
    }], {
      compress: false
    }).should.eql([{
      params: ['inline']
      files: [{
        params: ['compress', 'paths', 'print']
      }, {
        params: ['compress', 'paths']
      }]
    }])

  it 'should propagate block-level never-params assigned to blocks', ->
    parse.flagMatches([{
      params: ['inline', 'never-compress', 'paths']
      files: [{
        params: ['print']
      }, {

      }]
    }], {
      compress: true
    }).should.eql([{
      params: ['inline']
      files: [{
        params: ['paths', 'print']
      }, {
        params: ['paths']
      }]
    }])

